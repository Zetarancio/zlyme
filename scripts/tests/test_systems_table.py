#!/usr/bin/env python3
"""The user-guide systems table stays alphabetical and matches rom-dirs.txt."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
GUIDE = ROOT / "docs/USER_GUIDE.md"
DIRS = ROOT / "package/system/nextui/rom-dirs.txt"


def fail(msg: str) -> None:
    print(f"systems table: {msg}", file=sys.stderr)
    raise SystemExit(1)


def table_rows(text: str) -> list[str]:
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("| System"):
            start = i + 2
            break
    if start is None:
        fail("systems table heading row is missing")
    rows = []
    for line in lines[start:]:
        if not line.startswith("|"):
            break
        rows.append(line)
    if not rows:
        fail("systems table has no rows")
    return rows


def system_name(row: str) -> str:
    parts = row.split("|")
    if len(parts) < 3:
        fail(f"short row: {row}")
    return parts[1].strip()


def folder_name(row: str) -> str:
    parts = row.split("|")
    cell = parts[3]
    start = cell.find("`Roms/")
    end = cell.find("/`", start)
    if start < 0 or end < 0:
        fail(f"folder cell has no Roms path: {row}")
    return cell[start + len("`Roms/") : end]


def main() -> None:
    rows = table_rows(GUIDE.read_text(encoding="utf-8"))
    names = [system_name(row) for row in rows]
    folded = [name.casefold() for name in names]
    if folded != sorted(folded):
        fail("systems are not in case-insensitive alphabetical order")
    if len(folded) != len(set(folded)):
        fail("a system name is listed twice")
    folders = {folder_name(row) for row in rows}
    listed = {
        line.strip()
        for line in DIRS.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }
    if folders != listed:
        fail(
            "folder set differs from rom-dirs.txt: "
            f"only table {sorted(folders - listed)} "
            f"only rom-dirs {sorted(listed - folders)}"
        )
    print(f"systems table ok ({len(rows)} rows)")


if __name__ == "__main__":
    main()
