#!/usr/bin/env python3
"""One representative name for each civil-time pattern in zone.tab.

Two zones match when their UTC offset is the same at 2025-01-01 UTC and
after every transition of either zone through 2035-01-01 UTC. A single
clock reading is not enough: America/Phoenix stays separate from
America/Denver, and a half-hour or 45-minute offset stays separate too.

The preference list only chooses which member of a matched group is
shown. It does not decide that two groups are the same.
"""
import struct
import sys
from pathlib import Path

START = 1735689600  # 2025-01-01 00:00:00 UTC
END = 2051222400    # 2035-01-01 00:00:00 UTC

# Earlier names win inside one matched group.
PREFERENCE = (
    "UTC",
    "Africa/Abidjan",
    "Africa/Lagos",
    "Africa/Cairo",
    "Africa/Johannesburg",
    "Europe/Moscow",
    "Africa/Nairobi",
    "Africa/Maputo",
    "Africa/Windhoek",
    "America/St_Johns",
    "America/Halifax",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Phoenix",
    "America/Los_Angeles",
    "America/Anchorage",
    "America/Adak",
    "Pacific/Honolulu",
    "America/Bogota",
    "America/Lima",
    "America/Mexico_City",
    "America/Cancun",
    "America/Tijuana",
    "America/Caracas",
    "America/La_Paz",
    "America/Santiago",
    "America/Sao_Paulo",
    "America/Argentina/Buenos_Aires",
    "America/Noronha",
    "America/Godthab",
    "America/Nuuk",
    "Atlantic/Azores",
    "Atlantic/Cape_Verde",
    "Atlantic/Reykjavik",
    "Europe/London",
    "Europe/Dublin",
    "Europe/Lisbon",
    "Europe/Berlin",
    "Europe/Madrid",
    "Europe/Rome",
    "Europe/Paris",
    "Europe/Amsterdam",
    "Europe/Warsaw",
    "Europe/Athens",
    "Europe/Helsinki",
    "Europe/Bucharest",
    "Europe/Istanbul",
    "Europe/Kyiv",
    "Europe/Minsk",
    "Asia/Jerusalem",
    "Asia/Beirut",
    "Asia/Tehran",
    "Asia/Dubai",
    "Asia/Kabul",
    "Asia/Karachi",
    "Asia/Kolkata",
    "Asia/Kathmandu",
    "Asia/Dhaka",
    "Asia/Yangon",
    "Asia/Bangkok",
    "Asia/Jakarta",
    "Asia/Shanghai",
    "Asia/Hong_Kong",
    "Asia/Singapore",
    "Asia/Taipei",
    "Asia/Manila",
    "Asia/Tokyo",
    "Asia/Seoul",
    "Australia/Perth",
    "Australia/Eucla",
    "Australia/Darwin",
    "Australia/Adelaide",
    "Australia/Brisbane",
    "Australia/Sydney",
    "Australia/Lord_Howe",
    "Australia/Hobart",
    "Pacific/Guam",
    "Pacific/Port_Moresby",
    "Pacific/Noumea",
    "Pacific/Auckland",
    "Pacific/Chatham",
    "Pacific/Fiji",
    "Pacific/Tongatapu",
    "Pacific/Apia",
    "Pacific/Kiritimati",
    "Pacific/Pago_Pago",
    "Pacific/Marquesas",
    "Pacific/Gambier",
    "Antarctica/Troll",
    "Antarctica/Casey",
    "Antarctica/Davis",
    "Antarctica/Mawson",
)


def canonical_names(zone_tab_text):
    zones = []
    seen = set()
    for line in zone_tab_text.splitlines():
        if not line or line[0] == "#" or len(line) < 3:
            continue
        parts = line.split("\t")
        if len(parts) < 3 or parts[2] in seen:
            continue
        seen.add(parts[2])
        zones.append(parts[2])
    if "UTC" not in seen:
        zones.append("UTC")
    zones.sort()
    return zones


def _block(data, offset, wide):
    counts = struct.unpack_from(">6I", data, offset + 20)
    leapcnt, timecnt, typecnt, charcnt = counts[2:]
    pos = offset + 44
    step = 8 if wide else 4
    fmt = ">q" if wide else ">i"
    times = [struct.unpack_from(fmt, data, pos + i * step)[0] for i in range(timecnt)]
    pos += timecnt * step
    which = list(data[pos:pos + timecnt])
    pos += timecnt
    offsets = []
    for _ in range(typecnt):
        utoff = struct.unpack_from(">i", data, pos)[0]
        offsets.append(utoff)
        pos += 6
    pos += charcnt + leapcnt * (step + 4) + counts[1] + counts[0]
    return times, which, offsets, pos


def load_zone(path):
    data = Path(path).read_bytes()
    if data[:4] != b"TZif":
        raise ValueError("not a TZif file: %s" % path)
    version = data[4:5]
    _times, which, offsets, pos = _block(data, 0, False)
    if version in (b"2", b"3", b"4"):
        _times, which, offsets, _pos = _block(data, pos, True)
    return _times, which, offsets


def offset_at(times, which, offsets, instant):
    lo = 0
    hi = len(times)
    while lo < hi:
        mid = (lo + hi) // 2
        if times[mid] <= instant:
            lo = mid + 1
        else:
            hi = mid
    if lo == 0:
        return offsets[0]
    return offsets[which[lo - 1]]


def fingerprint(times, which, offsets):
    marks = [offset_at(times, which, offsets, START)]
    for index, instant in enumerate(times):
        if START < instant < END:
            marks.append((instant, offsets[which[index]]))
    return tuple(marks)


def choose(members):
    rank = {name: index for index, name in enumerate(PREFERENCE)}

    def key(name):
        if name in rank:
            return (0, rank[name])
        return (1, name)

    return min(members, key=key)


def representatives(zone_root, names):
    root = Path(zone_root)
    groups = {}
    order = []
    for name in names:
        path = root / name
        if not path.is_file():
            raise FileNotFoundError(path)
        times, which, offsets = load_zone(path)
        mark = fingerprint(times, which, offsets)
        if mark not in groups:
            groups[mark] = []
            order.append(mark)
        groups[mark].append(name)
    chosen = [choose(groups[mark]) for mark in order]
    chosen.sort()
    return chosen, groups


def main(argv):
    if len(argv) != 3:
        print("usage: timezone_representatives.py zoneinfo-dir zone.tab", file=sys.stderr)
        return 2
    names = canonical_names(Path(argv[2]).read_text())
    chosen, _groups = representatives(argv[1], names)
    sys.stdout.write("".join(name + "\n" for name in chosen))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
