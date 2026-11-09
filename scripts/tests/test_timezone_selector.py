#!/usr/bin/env python3
"""Canonical zone.tab order and a representative daylight-saving transition.

The Settings list may be shorter. This file is the index PLAT_getCurrentTimezone
still uses, so its order stays put.
"""
import pathlib
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parents[2]
ZONE_TAB = ROOT / "package" / "system" / "nextui" / "zlyme" / "zone.tab"

# Same names as common_src in the NextUI 18E settings row. A name
# that is not in zone.tab must not be offered.
COMMON = (
    "UTC",
    "Europe/London", "Europe/Dublin", "Europe/Lisbon",
    "Europe/Paris", "Europe/Madrid", "Europe/Rome",
    "Europe/Berlin", "Europe/Amsterdam", "Europe/Warsaw",
    "Europe/Athens", "Europe/Helsinki", "Europe/Moscow",
    "America/New_York", "America/Chicago", "America/Denver",
    "America/Los_Angeles", "America/Mexico_City", "America/Sao_Paulo",
    "Asia/Dubai", "Asia/Kolkata", "Asia/Shanghai", "Asia/Hong_Kong",
    "Asia/Singapore", "Asia/Tokyo", "Asia/Seoul",
    "Australia/Sydney", "Pacific/Auckland",
    "Africa/Cairo", "Africa/Johannesburg",
)

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


def common_row(zones, saved):
    row = []
    have = False
    for name in COMMON:
        if name not in zones:
            continue
        if name == saved:
            have = True
        row.append(name)
    if saved in zones and not have:
        row.append(saved)
    return row


def choose(zones, saved, choice):
    if choice not in zones:
        return saved
    return choice


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
    for name in COMMON:
        if name not in zones:
            return fail("common zone %s is not canonical" % name)
    if "Antarctica/Troll" not in zones:
        return fail("an uncommon zone left the full list")
    row = common_row(zones, "Antarctica/Troll")
    if row[-1] != "Antarctica/Troll":
        return fail("a saved uncommon zone is not offered")
    if "Pacific/Kiritimati" not in row:
        row = row + ["Pacific/Kiritimati"]
    if row[-1] != "Pacific/Kiritimati":
        return fail("a later uncommon choice left the short list")
    if row[0] == "UTC" and row[1] != "Europe/London":
        return fail("the later choice became the short list's first zone")
    if choose(zones, "Europe/Rome", "Not/AZone") != "Europe/Rome":
        return fail("an invalid choice replaced the saved zone")
    if choose(zones, "Europe/Rome", "Asia/Tokyo") != "Asia/Tokyo":
        return fail("a common choice did not save its canonical name")
    saved = "Pacific/Kiritimati"
    if choose(zones, saved, saved) != saved:
        return fail("reopening the list changed the saved zone")
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
