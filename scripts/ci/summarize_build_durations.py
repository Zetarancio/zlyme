#!/usr/bin/env python3
"""Print the longest timestamped Buildroot Building steps."""

import os
import re
import sys
from datetime import datetime


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: summarize_build_durations.py LOG")
    if not os.path.exists(argv[1]):
        print("no build log")
        return
    line_re = re.compile(
        r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) >>> (.+) Building\s*$"
    )
    any_re = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) ")
    rows = []
    previous = None
    last_stamp = None
    with open(argv[1], encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stamp = any_re.match(line)
            if not stamp:
                continue
            last_stamp = stamp.group(1)
            if ">>>" not in line:
                continue
            when = stamp.group(1)
            if previous is not None:
                start = datetime.strptime(previous[0], "%Y-%m-%dT%H:%M:%SZ")
                end = datetime.strptime(when, "%Y-%m-%dT%H:%M:%SZ")
                rows.append(((end - start).total_seconds(), previous[1]))
                previous = None
            building = line_re.match(line)
            if building:
                previous = (building.group(1), building.group(2))
    if previous is not None and last_stamp is not None:
        start = datetime.strptime(previous[0], "%Y-%m-%dT%H:%M:%SZ")
        end = datetime.strptime(last_stamp, "%Y-%m-%dT%H:%M:%SZ")
        rows.append(((end - start).total_seconds(), previous[1]))
    rows.sort(reverse=True)
    if not rows:
        print("no timestamped Building steps")
        return
    print("longest Building steps")
    for seconds, name in rows[:12]:
        print("%8.1f min  %s" % (seconds / 60.0, name))


if __name__ == "__main__":
    main(sys.argv)
