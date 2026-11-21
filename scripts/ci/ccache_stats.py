#!/usr/bin/env python3
"""Print one stage's ccache counters from `ccache -s` text."""

import re
import sys


def field(text, pattern):
    match = re.search(pattern, text)
    if not match:
        return None
    return int(match.group(1).replace(",", ""))


def parse(text):
    direct = field(text, r"Direct:\s+([0-9,]+)")
    preprocessed = field(text, r"Preprocessed:\s+([0-9,]+)")
    misses = field(text, r"Misses:\s+([0-9,]+)")
    uncacheable = field(text, r"Uncacheable calls:\s+([0-9,]+)")
    cleanups = field(text, r"Cleanups:\s+([0-9,]+)")
    size = re.search(
        r"Cache size \(G[i]?B\):\s+([0-9.]+)\s*/\s*([0-9.]+)", text
    )
    values = {
        "direct_hits": direct,
        "preprocessed_hits": preprocessed,
        "misses": misses,
        "uncacheable": uncacheable,
        "cleanups": cleanups,
    }
    if size:
        values["cache_size"] = size.group(1)
        values["cache_max_shown"] = size.group(2)
    return values


def main(argv):
    if len(argv) != 4:
        sys.exit("usage: ccache_stats.py begin|end MAX_SIZE STATS_FILE")
    mode, max_size, path = argv[1:]
    if mode not in ("begin", "end"):
        sys.exit("mode must be begin or end")
    text = open(path, encoding="utf-8", errors="replace").read()
    values = parse(text)
    prefix = "restored" if mode == "begin" else "stage"
    print("%s_max_size=%s" % (prefix, max_size))
    for key in (
        "cache_size",
        "cache_max_shown",
        "direct_hits",
        "preprocessed_hits",
        "misses",
        "uncacheable",
        "cleanups",
    ):
        if key in values and values[key] is not None:
            print("%s_%s=%s" % (prefix, key, values[key]))
    direct = values.get("direct_hits")
    preprocessed = values.get("preprocessed_hits")
    misses = values.get("misses")
    if None not in (direct, preprocessed, misses):
        cacheable = direct + preprocessed + misses
        print("%s_cacheable=%d" % (prefix, cacheable))
        if cacheable:
            rate = 100.0 * (direct + preprocessed) / cacheable
            print("%s_hit_rate=%.2f" % (prefix, rate))
        else:
            print("%s_hit_rate=none" % prefix)


if __name__ == "__main__":
    main(sys.argv)
