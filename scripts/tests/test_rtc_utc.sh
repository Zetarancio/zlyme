#!/bin/sh
# RTC writes are UTC. Applying a timezone must not touch the RTC.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ntp=$ROOT/board/my355/fsoverlay/etc/init.d/S49ntp
api=/home/ale/zlyme-nextui/workspace/all/common/api.c
grep -q 'hwclock -u -w' "$ntp"
if grep -E 'hwclock (-w|--systohc)( |$)' "$ntp" | grep -v -- '-u'; then
	echo "S49ntp writes the RTC without -u" >&2
	exit 1
fi
grep -q 'date -u -s' "$ntp"
grep -q 'hwclock -u -w' "$api"
if find "$ROOT/board/my355/fsoverlay" -type f -print0 |
	xargs -0 grep -n hwclock | grep -v S49ntp; then
	echo "another rootfs script writes the RTC" >&2
	exit 1
fi
echo "rtc utc ok"
