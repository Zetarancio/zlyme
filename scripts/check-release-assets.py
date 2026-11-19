#!/usr/bin/env python3
"""Fail closed before a GitHub release is published.

The OTA VERSION member is the packer's source identity and image date.
The product name is ZLYME_VERSION and the manifest version, not that
member. This script checks the files the release job is about to upload.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zlyme_release as rel  # noqa: E402

OTA_NAME = re.compile(r"^zlyme-my355-(\d{8})-(.+)\.tar$")
DTB = "rk3566-miyoo-flip.dtb"
OTA_FILES = ("zlyme", "Image.gz", DTB, "idbloader.img", "u-boot.itb", "VERSION")
IMAGES = (
    "zlyme.img",
    "miyoo355_fw.img",
    "miyoo355_fw-multiboot.img",
    "miyoo355_fw-maskrom.img",
    "miyoo355_fw-restore.img",
)


def fail(msg):
    print("release-assets: %s" % msg, file=sys.stderr)
    raise SystemExit(1)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_sidecar(path):
    side = path + ".sha256"
    if not os.path.isfile(side) or os.path.getsize(side) == 0:
        fail("missing checksum %s" % side)
    text = open(side, encoding="utf-8").read().strip().split()
    if not text or not rel._hex64(text[0].lower()):
        fail("bad checksum %s" % side)
    return text[0].lower()


def require_file(path):
    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        fail("missing or empty %s" % path)
    digest = sha256_file(path)
    if read_sidecar(path) != digest:
        fail("checksum mismatch %s" % path)
    return digest


def full_otas(images_dir):
    found = []
    for name in sorted(os.listdir(images_dir)):
        if not name.startswith("zlyme-my355-") or not name.endswith(".tar"):
            continue
        if name.startswith("zlyme-my355-delta-"):
            continue
        path = os.path.join(images_dir, name)
        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            continue
        try:
            with tarfile.open(path, "r:") as archive:
                names = archive.getnames()
        except tarfile.TarError:
            continue
        if "zlyme" in names:
            found.append(path)
    return found


def member_size(archive, name):
    try:
        info = archive.getmember(name)
    except KeyError:
        fail("OTA missing %s" % name)
    if not info.isfile() or info.size <= 0:
        fail("OTA member %s is empty" % name)
    return info.size


def git_text(repo, args):
    result = subprocess.run(
        ["git", "-C", repo, *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail("git %s" % " ".join(args))
    return result.stdout.strip()


def names_this_commit(repo, described, head):
    """True when a describe result, including tag-N-gABBREV, is this commit."""
    if described.endswith("-dirty") or described == "unknown":
        return False
    probe = subprocess.run(
        ["git", "-C", repo, "rev-parse", "--verify", described + "^{commit}"],
        check=False,
        capture_output=True,
        text=True,
    )
    if probe.returncode == 0 and probe.stdout.strip() == head:
        return True
    marker = described.rfind("-g")
    if marker < 0:
        return False
    abbrev = described[marker + 2 :]
    if len(abbrev) < 12 or any(ch not in "0123456789abcdef" for ch in abbrev.lower()):
        return False
    if not head.lower().startswith(abbrev.lower()):
        return False
    probe = subprocess.run(
        ["git", "-C", repo, "rev-parse", "--verify", abbrev + "^{commit}"],
        check=False,
        capture_output=True,
        text=True,
    )
    return probe.returncode == 0 and probe.stdout.strip() == head


def packed_source(filename, version_text):
    """VERSION is the packer's describe line, then the image-date stamp."""
    if version_text.count(b"\n") != 2 or not version_text.endswith(b"\n"):
        fail("VERSION member is not two lines")
    described, stamp = version_text.decode("utf-8").splitlines()
    if not described or not stamp:
        fail("VERSION member is empty")
    if described == "unknown" or described.endswith("-dirty"):
        fail("OTA source is unknown or dirty")
    if not re.fullmatch(r"\d{8}", stamp):
        fail("VERSION image date")
    match = OTA_NAME.fullmatch(os.path.basename(filename))
    if not match or match.group(1) != stamp or match.group(2) != described:
        fail("OTA filename does not match VERSION")
    return described


def matches_checkout(repo, described, source_sha):
    head = git_text(repo, ["rev-parse", "HEAD"])
    if head.lower() != source_sha.lower():
        fail("checkout is not the release source")
    current = git_text(repo, ["describe", "--always", "--dirty", "--abbrev=12"])
    if current != described:
        fail("OTA git description is not this checkout")
    if not names_this_commit(repo, described, head):
        fail("OTA git description does not name this commit")


def check(images_dir, version, source_sha, notes_path, repo):
    rel.parse_version(version)
    if len(source_sha) != 40 or any(ch not in "0123456789abcdef" for ch in source_sha.lower()):
        fail("source sha")
    fulls = full_otas(images_dir)
    if len(fulls) != 1:
        fail("expected one full OTA, found %d" % len(fulls))
    full = fulls[0]
    full_digest = require_file(full)
    full_size = os.path.getsize(full)
    with tarfile.open(full, "r:") as archive:
        for name in OTA_FILES:
            member_size(archive, name)
        version_info = archive.extractfile(archive.getmember("VERSION"))
        version_text = version_info.read() if version_info is not None else b""
    described = packed_source(full, version_text)
    matches_checkout(repo, described, source_sha)
    for name in IMAGES:
        require_file(os.path.join(images_dir, name))
    manifest_path = os.path.join(images_dir, "release-manifest.json")
    if not os.path.isfile(manifest_path) or os.path.getsize(manifest_path) == 0:
        fail("missing release-manifest.json")
    data = json.load(open(manifest_path, encoding="utf-8"))
    rel.validate_manifest(data)
    if data["version"] != version:
        fail("manifest version is %s" % data["version"])
    if data["source_sha"].lower() != source_sha.lower():
        fail("manifest source sha")
    if data["full"]["file"] != os.path.basename(full):
        fail("manifest full name")
    if data["full"]["size"] != full_size or data["full"]["sha256"].lower() != full_digest:
        fail("manifest full artifact")
    root = tempfile.NamedTemporaryFile(prefix="zlyme-root-", delete=False)
    root.close()
    try:
        rel.extract_member(full, "zlyme", root.name)
        if os.path.getsize(root.name) != data["root"]["size"]:
            fail("manifest root size")
        if sha256_file(root.name) != data["root"]["sha256"].lower():
            fail("manifest root hash")
    finally:
        os.remove(root.name)
    for item in data["deltas"]:
        path = os.path.join(images_dir, item["file"])
        digest = require_file(path)
        if os.path.getsize(path) != item["size"] or digest != item["sha256"].lower():
            fail("delta %s" % item["file"])
    notes = open(notes_path, encoding="utf-8").read()
    if not notes.strip():
        fail("empty release notes")
    heading = "## [%s]" % version
    if heading not in notes.splitlines()[0]:
        fail("release notes do not start with %s" % heading)
    for line in notes.splitlines():
        if line.startswith("## [") and not line.startswith(heading):
            fail("release notes include %s" % line)
    print("release assets ok")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images-dir", required=True)
    parser.add_argument("--version-file", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--notes", required=True)
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()
    version = open(args.version_file, encoding="utf-8").read().strip()
    try:
        check(args.images_dir, version, args.source_sha, args.notes, args.repo)
    except rel.ReleaseError as exc:
        fail(str(exc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
