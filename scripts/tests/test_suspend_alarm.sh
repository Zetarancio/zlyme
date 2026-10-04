#!/bin/sh
# The production suspend helper clears a stale RTC alarm and does not
# arm a new relative one. Kernel RTC support stays.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
helper=$ROOT/package/system/nextui/zlyme/suspend
grep -q 'echo 0 > /sys/class/rtc/rtc0/wakealarm' "$helper"
if grep -E 'echo[[:space:]]+\+[0-9]+[[:space:]]*>[[:space:]]*/sys/class/rtc/rtc0/wakealarm' "$helper"; then
	echo "suspend helper programs a relative RTC alarm" >&2
	exit 1
fi
if grep -q 86400 "$helper"; then
	echo "suspend helper still mentions the 24-hour test alarm" >&2
	exit 1
fi
echo "suspend alarm ok"
