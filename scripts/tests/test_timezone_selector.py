#!/usr/bin/env python3
"""Canonical zone.tab order and a representative daylight-saving transition.

The Settings list may be shorter. This file is the index PLAT_getCurrentTimezone
still uses, so its order stays put.
"""
import pathlib
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from timezone_representatives import fingerprint, load_zone, representatives

ROOT = pathlib.Path(__file__).resolve().parents[2]
ZONE_TAB = ROOT / "package" / "system" / "nextui" / "zlyme" / "zone.tab"
REPS = ROOT / "package" / "system" / "nextui" / "zlyme" / "timezone-representatives.txt"

# Indexes from the platform parser: skip comments, take field 3, drop
# duplicates, append UTC when absent, then strcmp order.
EXPECTED = {
    "Africa/Cairo": 12,
    "America/Los_Angeles": 134,
    "America/New_York": 153,
    "America/Sao_Paulo": 177,
    "Antarctica/Troll": 205,
    "Asia/Shanghai": 271,
    "Asia/Tokyo": 279,
    "Australia/Sydney": 310,
    "Europe/London": 336,
    "Europe/Mariehamn": 340,
    "Europe/Paris": 345,
    "Europe/Rome": 349,
    "Pacific/Auckland": 381,
    "Pacific/Kiritimati": 396,
    "UTC": 418,
}


def fail(msg):
    print("timezone-selector: " + msg, file=sys.stderr)
    return 1


def canonical(text):
    zones = []
    seen = set()
    for line in text.splitlines():
        if not line or line[0] == "#" or len(line) < 3:
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        token = parts[2]
        if token in seen:
            continue
        seen.add(token)
        zones.append(token)
    if "UTC" not in seen:
        zones.append("UTC")
    zones.sort()
    return zones


def local_time(zone, utc_text):
    utc = datetime.strptime(utc_text, "%Y-%m-%d %H:%M").replace(tzinfo=ZoneInfo("UTC"))
    return utc.astimezone(ZoneInfo(zone)).strftime("%Y-%m-%d %H:%M")


def choose(zones, saved, choice):
    if choice not in zones:
        return saved
    return choice


def shown(reps, zones, saved):
    row = [name for name in reps if name in zones]
    if saved in zones and saved not in row:
        row.append(saved)
    return row


def zone_root():
    target = ROOT / "output/target/usr/share/zoneinfo"
    host = pathlib.Path("/usr/share/zoneinfo")
    if (target / "Europe/Berlin").is_file():
        return target
    if (host / "Europe/Berlin").is_file():
        return host
    return None


def main():
    zones = canonical(ZONE_TAB.read_text())
    if len(zones) != 419:
        return fail("canonical count is %s" % len(zones))
    for name, index in EXPECTED.items():
        if index >= len(zones) or zones[index] != name:
            got = zones[index] if index < len(zones) else "missing"
            return fail("index %s is %s, not %s" % (index, got, name))
    if "Not/AZone" in zones:
        return fail("an invalid zone was accepted")
    reps = [line for line in REPS.read_text().splitlines() if line and line[0] != "#"]
    if len(reps) != len(set(reps)):
        return fail("a representative is listed twice")
    if len(reps) >= len(zones):
        return fail("the representative list is not shorter than zone.tab")
    for name in reps:
        if name not in zones:
            return fail("representative %s is not canonical" % name)
    for name in ("UTC", "Europe/Berlin", "America/Phoenix", "America/Denver",
                 "Asia/Kathmandu", "Pacific/Chatham", "Australia/Lord_Howe"):
        if name not in reps:
            return fail("%s is missing from the representative list" % name)
    for name in ("Europe/Rome", "Europe/Paris", "Europe/Amsterdam"):
        if name in reps:
            return fail("%s is listed beside Berlin" % name)
    row = shown(reps, zones, "Europe/Rome")
    if row[-1] != "Europe/Rome":
        return fail("a saved uncommon zone is not offered")
    if "Europe/Berlin" not in row:
        return fail("the representative left the row")
    if choose(zones, "Europe/Rome", "Not/AZone") != "Europe/Rome":
        return fail("an invalid choice replaced the saved zone")
    if choose(zones, "Europe/Rome", "Europe/Berlin") != "Europe/Berlin":
        return fail("a representative choice did not save its canonical name")
    if choose(zones, "Europe/Rome", "Europe/Rome") != "Europe/Rome":
        return fail("reopening the list changed the saved zone")
    root = zone_root()
    if root is None:
        return fail("no zoneinfo tree is available")
    target = ROOT / "output/target/usr/share/zoneinfo/Europe/Berlin"
    if target.is_file():
        generated, _groups = representatives(root, zones)
        if generated != reps:
            return fail("the representative file does not match tzdata 2026b")
    marks = {}
    for name in ("Europe/Berlin", "Europe/Rome", "Europe/Paris", "Europe/Amsterdam",
                 "America/Phoenix", "America/Denver", "Asia/Kathmandu",
                 "Pacific/Chatham", "Australia/Lord_Howe"):
        times, which, offsets = load_zone(root / name)
        marks[name] = fingerprint(times, which, offsets)
    for name in ("Europe/Rome", "Europe/Paris", "Europe/Amsterdam"):
        if marks[name] != marks["Europe/Berlin"]:
            return fail("%s is not the Berlin civil-time pattern" % name)
    if marks["America/Phoenix"] == marks["America/Denver"]:
        return fail("Phoenix was treated as Denver")
    for name in ("Asia/Kathmandu", "Pacific/Chatham", "Australia/Lord_Howe"):
        if marks[name] == marks["Europe/Berlin"]:
            return fail("%s collapsed into Berlin" % name)
    if "UTC" not in zones or zones[EXPECTED["UTC"]] != "UTC":
        return fail("UTC is not the canonical fallback name")
    if local_time("Europe/Rome", "2026-01-15 12:00") != "2026-01-15 13:00":
        return fail("Rome standard time moved")
    if local_time("Europe/Rome", "2026-07-15 12:00") != "2026-07-15 14:00":
        return fail("Rome summer time moved")
    if local_time("America/New_York", "2026-01-15 12:00") != "2026-01-15 07:00":
        return fail("New York standard time moved")
    if local_time("America/New_York", "2026-07-15 12:00") != "2026-07-15 08:00":
        return fail("New York summer time moved")
    if local_time("UTC", "2026-07-15 12:00") != "2026-07-15 12:00":
        return fail("UTC was shifted")
    print("timezone selector ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
