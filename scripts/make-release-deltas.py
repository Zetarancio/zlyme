#!/usr/bin/env python3
"""Publish release-manifest.json and optional same-major zstd deltas.

Local builds do not run this. The GitHub Actions release job does.
A baseline version writes a manifest with an empty delta list and does
not download older releases.
"""

import argparse
import json
import os
import sys
import tarfile
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zlyme_release as rel  # noqa: E402


def _die(msg):
    print("make-release-deltas: %s" % msg, file=sys.stderr)
    raise SystemExit(1)


def _full_tar(images_dir):
    found = []
    for name in sorted(os.listdir(images_dir)):
        path = os.path.join(images_dir, name)
        if not name.endswith(".tar") or "-delta-" in name or not os.path.isfile(path):
            continue
        with tarfile.open(path, "r:") as archive:
            names = archive.getnames()
        if "zlyme" in names:
            found.append(path)
    if len(found) != 1:
        _die("expected one full OTA tar, found %d" % len(found))
    return found[0]


def _github_json(url, token):
    request = urllib.request.Request(url, headers={"User-Agent": "zlyme-release", "Accept": "application/vnd.github+json"})
    if token:
        request.add_header("Authorization", "Bearer %s" % token)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def _download(url, dest, token):
    request = urllib.request.Request(url, headers={"User-Agent": "zlyme-release"})
    if token:
        request.add_header("Authorization", "Bearer %s" % token)
    with urllib.request.urlopen(request, timeout=120) as response, open(dest, "wb") as handle:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            handle.write(chunk)


def _releases(repo, token):
    out = []
    for page in range(1, 6):
        url = "https://api.github.com/repos/%s/releases?per_page=100&page=%d" % (repo, page)
        batch = _github_json(url, token)
        if not batch:
            break
        out.extend(batch)
        if len(batch) < 100:
            break
    return [item for item in out if isinstance(item, dict) and not item.get("draft")]


def _asset(release, name):
    for asset in release.get("assets") or []:
        if asset.get("name") == name:
            return asset
    return None


def _load_historical_bases(repo, token, target_version, work):
    """Return verified base records. Missing manifests are skipped.

    A release that publishes a manifest but fails its own hashes fails
    the job. An unverified delta is never returned.
    """
    published = []
    manifests = []
    for release in _releases(repo, token):
        asset = _asset(release, "release-manifest.json")
        if not asset:
            print("skip %s: no release-manifest.json" % (release.get("tag_name") or "?"), file=sys.stderr)
            continue
        path = os.path.join(work, "manifest-%s.json" % (release.get("id") or len(manifests)))
        _download(asset["browser_download_url"], path, token)
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        try:
            rel.validate_manifest(data)
        except rel.ReleaseError as exc:
            _die("corrupt manifest on %s (%s)" % (release.get("tag_name"), exc))
        published.append(data["version"])
        manifests.append((release, data))
    wanted = set(rel.eligible_base_versions(target_version, published))
    bases = []
    for release, data in manifests:
        if data["version"] not in wanted:
            continue
        full_name = data["full"]["file"]
        asset = _asset(release, full_name)
        if not asset:
            _die("manifest on %s names missing full OTA %s" % (data["version"], full_name))
        tar_path = os.path.join(work, os.path.basename(full_name))
        _download(asset["browser_download_url"], tar_path, token)
        digest = rel.sha256_file(tar_path)
        if digest != data["full"]["sha256"]:
            _die("full OTA hash mismatch for %s" % data["version"])
        root_path = os.path.join(work, "root-%s" % data["version"])
        rel.extract_member(tar_path, "zlyme", root_path)
        root_digest = rel.sha256_file(root_path)
        if root_digest != data["root"]["sha256"]:
            _die("root hash mismatch for %s" % data["version"])
        bases.append(
            {
                "version": data["version"],
                "root_path": root_path,
                "root_sha256": root_digest,
            }
        )
    return bases


def _write_release(images_dir, version, source_sha, bases):
    full_tar = _full_tar(images_dir)
    full_name = os.path.basename(full_tar)
    full_sha = rel.sha256_file(full_tar)
    full_size = os.path.getsize(full_tar)
    root_path = os.path.join(images_dir, ".release-root")
    rel.extract_member(full_tar, "zlyme", root_path)
    root_sha = rel.sha256_file(root_path)
    root_size = os.path.getsize(root_path)
    deltas = []
    if not rel.is_baseline(version):
        for base in bases:
            fields = {
                "TYPE": "delta",
                "SCHEMA": "1",
                "DEVICE": "my355",
                "FROM_VERSION": base["version"],
                "TARGET_VERSION": version,
                "BASE_SHA256": base["root_sha256"],
                "TARGET_SHA256": root_sha,
                "TARGET_SIZE": str(root_size),
                "PATCH": "zlyme.patch.zst",
            }
            delta_name = "zlyme-my355-delta-%s.tar" % base["version"]
            delta_path = os.path.join(images_dir, delta_name)
            try:
                size = rel.build_delta_tar(full_tar, base["root_path"], root_path, delta_path, fields)
            except rel.ReleaseError as exc:
                _die("delta from %s failed (%s)" % (base["version"], exc))
            if not rel.under_cutoff(size, full_size):
                os.remove(delta_path)
                print(
                    "omit delta from %s: %d bytes is at least %.0f%% of the full OTA"
                    % (base["version"], size, rel.DELTA_SIZE_RATIO * 100),
                    file=sys.stderr,
                )
                continue
            digest = rel.sha256_file(delta_path)
            rel.write_sha256(delta_path, digest)
            deltas.append(
                {
                    "from_version": base["version"],
                    "from_sha256": base["root_sha256"],
                    "file": delta_name,
                    "sha256": digest,
                    "size": size,
                }
            )
    manifest = rel.make_manifest(
        version, source_sha, root_sha, root_size, full_name, full_sha, full_size, deltas
    )
    dest = os.path.join(images_dir, "release-manifest.json")
    with open(dest, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    os.remove(root_path)
    print("make-release-deltas: %s (%d deltas)" % (dest, len(deltas)))
    return dest


def main():
    parser = argparse.ArgumentParser(description="Zlyme release manifest and deltas")
    parser.add_argument("--images-dir", required=True)
    parser.add_argument("--version-file", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--repo", default="")
    args = parser.parse_args()
    with open(args.version_file, "r", encoding="utf-8") as handle:
        version = handle.read().strip()
    try:
        rel.parse_version(version)
    except rel.ReleaseError as exc:
        _die(str(exc))
    bases = []
    if not rel.is_baseline(version):
        if not args.repo:
            _die("point release needs --repo to find earlier manifests")
        token = os.environ.get("GITHUB_TOKEN", "")
        work = os.path.join(args.images_dir, ".delta-bases")
        os.makedirs(work, exist_ok=True)
        bases = _load_historical_bases(args.repo, token, version, work)
    _write_release(args.images_dir, version, args.source_sha, bases)


if __name__ == "__main__":
    main()
