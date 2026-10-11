#!/usr/bin/env python3
"""Print one changelog entry for a GitHub release body.

The entry is the `## [version]` section in CHANGELOG.md. Version is a
baseline (`zlyme44`) or a point release (`zlyme44.2`). Unreleased text,
the following release, and the compare-link footer are not included.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VERSION = re.compile(r"zlyme[0-9]+(?:\.[0-9]+)?\Z")
HEADING = re.compile(r"^## \[([^\]]+)\](.*)\Z")
DATE = re.compile(r"- \d{4}-\d{2}-\d{2}\Z")
REFERENCE = re.compile(r"^\[[^\]]+\]:\s+\S")


def fail(msg: str) -> None:
    print(f"changelog-release-notes: {msg}", file=sys.stderr)
    raise SystemExit(1)


def version_text(args: argparse.Namespace) -> str:
    if args.version and args.version_file:
        fail("pass a version or a version file, not both")
    if args.version_file:
        raw = Path(args.version_file).read_text(encoding="utf-8")
        text = "".join(raw.split())
    elif args.version:
        text = "".join(args.version.split())
    else:
        fail("a version is required")
    if not VERSION.fullmatch(text):
        fail(f"unsupported version {text!r}")
    return text


def extract(changelog: str, version: str) -> str:
    lines = changelog.splitlines()
    starts: list[int] = []
    for index, line in enumerate(lines):
        match = HEADING.match(line)
        if not match or match.group(1) != version:
            continue
        rest = match.group(2).strip()
        if rest and not DATE.fullmatch(rest):
            fail(f"malformed heading for {version}")
        starts.append(index)
    if not starts:
        fail(f"no changelog entry for {version}")
    if len(starts) != 1:
        fail(f"more than one changelog entry for {version}")
    body = [lines[starts[0]]]
    for line in lines[starts[0] + 1 :]:
        if line.startswith("## ") or REFERENCE.match(line):
            break
        body.append(line)
    while body and body[-1].strip() == "":
        body.pop()
    if len(body) <= 1:
        fail(f"changelog entry for {version} is empty")
    return "\n".join(body) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changelog", required=True)
    parser.add_argument("--version")
    parser.add_argument("--version-file")
    args = parser.parse_args()
    version = version_text(args)
    text = Path(args.changelog).read_text(encoding="utf-8")
    sys.stdout.write(extract(text, version))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
