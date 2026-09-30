#!/usr/bin/env python3
"""Build a symlink union of Bios trees. Later roots win duplicate paths.

Paths are read from stdin, one Bios directory per line. Directory symlinks
are linked as a single entry and are not walked, so a cycle cannot recurse.
"""

import os
import sys


def link(src, dest):
    parent = os.path.dirname(dest)
    if parent:
        os.makedirs(parent, exist_ok=True)
    if os.path.lexists(dest):
        os.remove(dest)
    os.symlink(src, dest)


def add_tree(bios, dest):
    if not os.path.isdir(bios):
        return
    for dirpath, dirnames, filenames in os.walk(bios, followlinks=False):
        rel = os.path.relpath(dirpath, bios)
        kept = []
        for name in dirnames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                out_rel = name if rel == "." else os.path.join(rel, name)
                if ".." in out_rel.split(os.sep):
                    continue
                link(path, os.path.join(dest, out_rel))
            else:
                kept.append(name)
        dirnames[:] = kept
        for name in filenames:
            path = os.path.join(dirpath, name)
            out_rel = name if rel == "." else os.path.join(rel, name)
            if ".." in out_rel.split(os.sep):
                continue
            link(path, os.path.join(dest, out_rel))


def alias_roots(dest):
    """Match the old ra-run one-level aliases without a shell glob."""
    for name in os.listdir(dest):
        sub = os.path.join(dest, name)
        if os.path.islink(sub) or not os.path.isdir(sub):
            continue
        for fn in os.listdir(sub):
            root = os.path.join(dest, fn)
            if os.path.lexists(root):
                continue
            link(os.path.join(name, fn), root)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: bios-union.py DEST\n")
        return 1
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    for line in sys.stdin:
        bios = line.rstrip("\n")
        if bios:
            add_tree(bios, dest)
    alias_roots(dest)
    ready = os.path.join(dest, ".zlyme-ready")
    with open(ready, "w", encoding="utf-8") as fh:
        fh.write("ok\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
