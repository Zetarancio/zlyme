#!/usr/bin/env python3
"""Copy the pinned ROCKNIX compat allowlist into a destination directory.

Refuse absolute paths, parent segments, links, and any non-regular member.
Only compat/<allowlisted-name> is copied, and only when its SHA-256 matches.
"""
import hashlib
import sys
import tarfile
from pathlib import Path


def load_allowlist(path):
    allow = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        digest, name = line.split()
        if "/" in name or name in (".", ".."):
            raise SystemExit(f"unsafe allowlist name {name}")
        allow[name] = digest
    if not allow:
        raise SystemExit("empty allowlist")
    return allow


def main():
    allow_path, tar_path, dest = sys.argv[1:]
    allow = load_allowlist(allow_path)
    out = Path(dest)
    out.mkdir(parents=True, exist_ok=True)
    found = set()
    with tarfile.open(tar_path) as archive:
        for member in archive.getmembers():
            parts = Path(member.name).parts
            if member.name.startswith("/") or ".." in parts:
                raise SystemExit(f"unsafe path {member.name}")
            if member.issym() or member.islnk():
                raise SystemExit(f"refusing link {member.name}")
            if not (member.isdir() or member.isfile()):
                raise SystemExit(f"refusing special member {member.name}")
            if not member.isfile():
                continue
            if len(parts) != 2 or parts[0] != "compat":
                raise SystemExit(f"unexpected layout {member.name}")
            name = parts[1]
            if name not in allow:
                continue
            payload = archive.extractfile(member).read()
            digest = hashlib.sha256(payload).hexdigest()
            if digest != allow[name]:
                raise SystemExit(f"hash mismatch {name}")
            target = out / name
            target.write_bytes(payload)
            target.chmod(0o644)
            found.add(name)
    missing = sorted(set(allow) - found)
    if missing:
        raise SystemExit("missing " + ", ".join(missing))


if __name__ == "__main__":
    main()
