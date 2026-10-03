"""Release versions, manifests, and zstd root deltas.

Local image builds do not import this module. The GitHub Actions release
job is the caller. A delta is a transport: the device still commits a
complete squashfs through the existing initramfs path.
"""

import hashlib
import json
import os
import re
import subprocess
import tarfile
import tempfile

# A delta package at or above this fraction of the full OTA is not published.
DELTA_SIZE_RATIO = 0.70
STAGING_SLACK_BYTES = 64 * 1024 * 1024

_VERSION = re.compile(r"^zlyme([1-9][0-9]*)(?:\.([1-9][0-9]*))?$")
_HEX64 = re.compile(r"^[0-9a-f]{64}$")


class ReleaseError(ValueError):
    pass


def parse_version(text):
    """Return (major, minor). minor is None for a baseline such as zlyme43."""
    raw = (text or "").strip()
    match = _VERSION.fullmatch(raw)
    if not match:
        raise ReleaseError("invalid version %r" % raw)
    major = int(match.group(1))
    minor = int(match.group(2)) if match.group(2) else None
    return major, minor


def is_baseline(text):
    _major, minor = parse_version(text)
    return minor is None


def version_sort_key(text):
    major, minor = parse_version(text)
    return (major, 0 if minor is None else minor)


def eligible_base_versions(target, published):
    """Same-major baseline plus the last three earlier point releases.

    A baseline target publishes no deltas. Versions that do not parse are
    ignored. Other majors are ignored.
    """
    major, minor = parse_version(target)
    if minor is None:
        return []
    baseline = None
    points = []
    for item in published:
        try:
            got_major, got_minor = parse_version(item)
        except ReleaseError:
            continue
        if got_major != major:
            continue
        if got_minor is None:
            baseline = item
        elif got_minor < minor:
            points.append((got_minor, item))
    points.sort()
    chosen = [item for _minor, item in points[-3:]]
    out = []
    if baseline:
        out.append(baseline)
    out.extend(chosen)
    return out


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def _hex64(value):
    return isinstance(value, str) and _HEX64.fullmatch(value) is not None


def validate_manifest(data, device="my355"):
    if not isinstance(data, dict):
        raise ReleaseError("manifest is not an object")
    if data.get("schema") != 1:
        raise ReleaseError("manifest schema")
    if data.get("device") != device:
        raise ReleaseError("manifest device")
    parse_version(data.get("version") or "")
    if not isinstance(data.get("source_sha"), str) or not data.get("source_sha"):
        raise ReleaseError("manifest source_sha")
    root = data.get("root")
    if not isinstance(root, dict) or not _hex64(root.get("sha256")):
        raise ReleaseError("manifest root")
    if not isinstance(root.get("size"), int) or root["size"] < 0:
        raise ReleaseError("manifest root size")
    full = data.get("full")
    if not isinstance(full, dict) or not full.get("file") or not _hex64(full.get("sha256")):
        raise ReleaseError("manifest full")
    if not isinstance(full.get("size"), int) or full["size"] < 0:
        raise ReleaseError("manifest full size")
    deltas = data.get("deltas")
    if not isinstance(deltas, list):
        raise ReleaseError("manifest deltas")
    for item in deltas:
        if not isinstance(item, dict):
            raise ReleaseError("manifest delta")
        parse_version(item.get("from_version") or "")
        if not _hex64(item.get("from_sha256")) or not item.get("file"):
            raise ReleaseError("manifest delta identity")
        if not _hex64(item.get("sha256")):
            raise ReleaseError("manifest delta sha")
        if not isinstance(item.get("size"), int) or item["size"] < 0:
            raise ReleaseError("manifest delta size")
    return data


def choose_transport(manifest, installed_sha256):
    """Pick the smallest exact-base delta, otherwise the full OTA."""
    validate_manifest(manifest)
    installed = (installed_sha256 or "").lower()
    matches = []
    for item in manifest["deltas"]:
        if item["from_sha256"].lower() == installed and installed:
            matches.append(item)
    if matches:
        matches.sort(key=lambda item: item["size"])
        return "delta", matches[0]
    return "full", manifest["full"]


def need_bytes(kind, transport, root):
    """Bytes to have free before the download starts.

    The tar stays on /storage while the pending tree or reconstructed
    root is written, so both sizes count. Slack covers the other boot files.
    """
    return int(transport["size"]) + int(root["size"]) + STAGING_SLACK_BYTES


def under_cutoff(delta_size, full_size, ratio=DELTA_SIZE_RATIO):
    if full_size <= 0:
        raise ReleaseError("full OTA size")
    return delta_size < int(full_size * ratio)


def zstd_patch(old_path, new_path, patch_path):
    subprocess.run(
        ["zstd", "--patch-from=%s" % old_path, new_path, "-o", patch_path, "-f"],
        check=True,
        capture_output=True,
    )


def zstd_apply(old_path, patch_path, out_path):
    """Return the zstd exit code. Non-zero means the patch was rejected.

    A root-sized patch window sits just above zstd's default decoder cap,
    so the apply allows a 2 GiB window. The frame still allocates only the
    window it was compressed with.
    """
    result = subprocess.run(
        [
            "zstd", "-d", "--memory=2048MB",
            "--patch-from=%s" % old_path, patch_path, "-o", out_path, "-f",
        ],
        capture_output=True,
    )
    return result.returncode


def round_trip_ok(old_path, new_path, patch_path):
    directory = tempfile.mkdtemp(prefix="zlyme-delta-")
    try:
        decoded = os.path.join(directory, "decoded")
        if zstd_apply(old_path, patch_path, decoded) != 0:
            return False
        return sha256_file(decoded) == sha256_file(new_path)
    finally:
        for name in os.listdir(directory):
            os.remove(os.path.join(directory, name))
        os.rmdir(directory)


_DELTA_KEYS = (
    "TYPE",
    "SCHEMA",
    "DEVICE",
    "FROM_VERSION",
    "TARGET_VERSION",
    "BASE_SHA256",
    "TARGET_SHA256",
    "TARGET_SIZE",
    "PATCH",
)


def render_delta_manifest(fields):
    missing = [key for key in _DELTA_KEYS if key not in fields]
    if missing:
        raise ReleaseError("delta manifest missing %s" % ",".join(missing))
    if fields["TYPE"] != "delta" or str(fields["SCHEMA"]) != "1":
        raise ReleaseError("delta manifest type")
    if fields["DEVICE"] != "my355":
        raise ReleaseError("delta manifest device")
    parse_version(fields["FROM_VERSION"])
    parse_version(fields["TARGET_VERSION"])
    if not _hex64(fields["BASE_SHA256"]) or not _hex64(fields["TARGET_SHA256"]):
        raise ReleaseError("delta manifest hash")
    if not str(fields["TARGET_SIZE"]).isdigit():
        raise ReleaseError("delta manifest size")
    if fields["PATCH"] != "zlyme.patch.zst":
        raise ReleaseError("delta manifest patch")
    lines = ["%s=%s" % (key, fields[key]) for key in _DELTA_KEYS]
    return "\n".join(lines) + "\n"


def parse_delta_manifest_text(text, device="my355"):
    """Parse DELTA-MANIFEST text. Unknown keys and bad values are errors."""
    found = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ReleaseError("delta manifest syntax")
        key, value = line.split("=", 1)
        if key not in _DELTA_KEYS:
            raise ReleaseError("delta manifest key %s" % key)
        if key in found:
            raise ReleaseError("delta manifest duplicate %s" % key)
        if not value or any(ch in value for ch in "\t $`'\"\\"):
            raise ReleaseError("delta manifest value")
        found[key] = value
    return render_delta_manifest(found) and _fields_from_render(found, device)


def _fields_from_render(found, device):
    rendered = {
        "TYPE": found.get("TYPE"),
        "SCHEMA": found.get("SCHEMA"),
        "DEVICE": found.get("DEVICE"),
        "FROM_VERSION": found.get("FROM_VERSION"),
        "TARGET_VERSION": found.get("TARGET_VERSION"),
        "BASE_SHA256": found.get("BASE_SHA256"),
        "TARGET_SHA256": found.get("TARGET_SHA256"),
        "TARGET_SIZE": found.get("TARGET_SIZE"),
        "PATCH": found.get("PATCH"),
    }
    if rendered["DEVICE"] != device:
        raise ReleaseError("delta manifest device")
    render_delta_manifest(rendered)
    rendered["TARGET_SIZE"] = int(rendered["TARGET_SIZE"])
    rendered["BASE_SHA256"] = rendered["BASE_SHA256"].lower()
    rendered["TARGET_SHA256"] = rendered["TARGET_SHA256"].lower()
    return rendered


def extract_member(tar_path, member, dest):
    with tarfile.open(tar_path, "r:") as archive:
        info = archive.getmember(member)
        source = archive.extractfile(info)
        if source is None:
            raise ReleaseError("missing %s" % member)
        with open(dest, "wb") as handle:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                handle.write(chunk)


def build_delta_tar(full_tar, old_root, new_root, out_path, fields):
    """Full OTA members, with zlyme replaced by a verified zstd patch."""
    new_sha = sha256_file(new_root)
    old_sha = sha256_file(old_root)
    if new_sha != fields["TARGET_SHA256"] or old_sha != fields["BASE_SHA256"]:
        raise ReleaseError("root hash does not match delta fields")
    directory = tempfile.mkdtemp(prefix="zlyme-delta-tar-")
    try:
        patch = os.path.join(directory, "zlyme.patch.zst")
        zstd_patch(old_root, new_root, patch)
        if not round_trip_ok(old_root, new_root, patch):
            raise ReleaseError("delta round trip failed")
        with tarfile.open(full_tar, "r:") as archive:
            for info in archive.getmembers():
                if info.name == "zlyme" or info.name.endswith("/zlyme"):
                    continue
                if not (info.isfile() or info.isdir()):
                    continue
                archive.extract(info, directory)
        manifest = render_delta_manifest(fields)
        manifest_path = os.path.join(directory, "DELTA-MANIFEST")
        with open(manifest_path, "w", encoding="utf-8") as handle:
            handle.write(manifest)
        with tarfile.open(out_path, "w:") as out:
            for name in sorted(os.listdir(directory)):
                out.add(os.path.join(directory, name), arcname=name)
        return os.path.getsize(out_path)
    finally:
        for root, dirs, files in os.walk(directory, topdown=False):
            for name in files:
                os.remove(os.path.join(root, name))
            for name in dirs:
                os.rmdir(os.path.join(root, name))
        os.rmdir(directory)


def make_manifest(version, source_sha, root_sha, root_size, full_name, full_sha, full_size, deltas):
    data = {
        "schema": 1,
        "device": "my355",
        "version": version,
        "source_sha": source_sha,
        "root": {"sha256": root_sha, "size": root_size},
        "full": {"file": full_name, "sha256": full_sha, "size": full_size},
        "deltas": deltas,
    }
    return validate_manifest(data)


def write_sha256(path, digest):
    name = os.path.basename(path)
    with open(path + ".sha256", "w", encoding="utf-8") as handle:
        handle.write("%s  %s\n" % (digest, name))
