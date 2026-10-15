#!/usr/bin/env python3
"""LOGBOOK stays newest-first, and recorded entries keep their text."""
import hashlib
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOG = os.path.join(ROOT, "docs", "LOGBOOK.md")
MANIFEST = os.path.join(os.path.dirname(__file__), "logbook_entries.sha256")
DATE = re.compile(r"^## (\d{4}-\d{2}-\d{2}) ")
INTRO_SHA256 = "a637cf82c1b2a34bb1b215b3ddd7f8f167d1c78eb7f53c62f027a93014d4a9e5"


def entries(text):
    lines = text.splitlines(keepends=True)
    idxs = [i for i, line in enumerate(lines) if DATE.match(line)]
    if not idxs:
        return "", []
    intro = "".join(lines[: idxs[0]])
    found = []
    for n, start in enumerate(idxs):
        end = idxs[n + 1] if n + 1 < len(idxs) else len(lines)
        body = "".join(lines[start:end])
        heading = lines[start].rstrip("\n")
        date = DATE.match(lines[start]).group(1)
        found.append((date, heading, body))
    return intro, found


def main():
    text = open(LOG, encoding="utf-8").read()
    intro, found = entries(text)
    if hashlib.sha256(intro.encode()).hexdigest() != INTRO_SHA256:
        print("logbook introduction changed", file=sys.stderr)
        return 1
    dates = [item[0] for item in found]
    for earlier, later in zip(dates, dates[1:]):
        if later > earlier:
            print("logbook dates go forward: %s then %s" % (earlier, later), file=sys.stderr)
            return 1
    by_heading = {}
    for _date, heading, body in found:
        if heading in by_heading:
            print("duplicate logbook heading: %s" % heading, file=sys.stderr)
            return 1
        by_heading[heading] = hashlib.sha256(body.encode()).hexdigest()
    missing = []
    for line in open(MANIFEST, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        digest, heading = line.split("  ", 1)
        if by_heading.get(heading) != digest:
            missing.append(heading)
    if missing:
        print("logbook entries changed or missing:", file=sys.stderr)
        print("\n".join(missing), file=sys.stderr)
        return 1
    print("logbook order ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
