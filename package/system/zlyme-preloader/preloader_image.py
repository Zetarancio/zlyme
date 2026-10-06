#!/usr/bin/env python3
"""Structural checks for a 2 MiB my355 preloader image.

The layout matches apommel's patch-preloader.sh: two RKNS IDB copies,
each with two entries whose stored SHA-256 matches the payload.
"""

import hashlib
import sys

SIZE = 2097152
COPIES = (131072, 524288)
ENTRY = 0x58
ENTRIES = 2


def _u16le(blob, off):
    return int.from_bytes(blob[off:off + 2], "little")


def validate(path):
    data = open(path, "rb").read()
    if len(data) != SIZE:
        raise SystemExit(f"size {len(data)} is not {SIZE}")
    for base in COPIES:
        if data[base:base + 4] != b"RKNS":
            raise SystemExit(f"no RKNS magic at {base}")
        for i in range(ENTRIES):
            entry = base + 0x78 + i * ENTRY
            off = _u16le(data, entry)
            count = _u16le(data, entry + 2)
            if count <= 0:
                raise SystemExit(f"empty IDB entry {i} at {base}")
            start = base + off * 512
            length = count * 512
            if start < 0 or start + length > len(data):
                raise SystemExit(f"IDB entry {i} at {base} is out of range")
            want = data[entry + 0x18:entry + 0x18 + 32].hex()
            got = hashlib.sha256(data[start:start + length]).hexdigest()
            if want != got:
                raise SystemExit(f"IDB entry {i} at {base} fails its SHA-256")
    return 0


def main(argv):
    if len(argv) != 2:
        raise SystemExit("usage: preloader_image.py IMAGE")
    return validate(argv[1])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
