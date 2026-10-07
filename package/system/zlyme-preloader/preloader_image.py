#!/usr/bin/env python3
"""Structural checks for a 2 MiB my355 preloader image.

The layout matches apommel's patch-preloader.sh: two RKNS IDB copies,
each with two entries whose stored SHA-256 matches the payload.
Entry 0 is the DDR blob. Entry 1 is the SPL. The /pinctrl repair
changes the SPL and must leave the DDR payload byte-identical.
"""

import hashlib
import sys

SIZE = 2097152
COPIES = (131072, 524288)
ENTRY = 0x58
ENTRIES = 2
DDR_INDEX = 0


def _u16le(blob, off):
    return int.from_bytes(blob[off:off + 2], "little")


def _entries(data):
    if len(data) != SIZE:
        raise SystemExit(f"size {len(data)} is not {SIZE}")
    found = []
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
            blob = data[start:start + length]
            want = data[entry + 0x18:entry + 0x18 + 32]
            if hashlib.sha256(blob).digest() != want:
                raise SystemExit(f"IDB entry {i} at {base} fails its SHA-256")
            found.append((i, blob))
    return found


def validate(path):
    _entries(open(path, "rb").read())
    return 0


def _ddr(path):
    blobs = [blob for index, blob in _entries(open(path, "rb").read()) if index == DDR_INDEX]
    if len(blobs) != len(COPIES) or blobs[0] != blobs[1]:
        raise SystemExit(f"DDR copies disagree in {path}")
    return blobs[0]


def ddr_same(left, right):
    if _ddr(left) != _ddr(right):
        raise SystemExit("DDR payload differs")
    return 0


def main(argv):
    if len(argv) == 2:
        return validate(argv[1])
    if len(argv) == 4 and argv[1] == "ddr":
        return ddr_same(argv[2], argv[3])
    raise SystemExit("usage: preloader_image.py IMAGE | preloader_image.py ddr IMAGE IMAGE")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
