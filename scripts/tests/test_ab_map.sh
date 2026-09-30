#!/bin/sh
# The selectable A/B swap is gone. One built-in map remains.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
if [ -e "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ab-map" ]; then
	echo "zlyme-ab-map still installed" >&2
	exit 1
fi
if [ -e "$ROOT/package/system/inputplumber/zlyme_miyoo_flip_ab.yaml" ]; then
	echo "alternate capability map still present" >&2
	exit 1
fi
if grep -n ab_swap "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-bootcfg" \
	"$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl" \
	"$ROOT/package/system/inputplumber/S31inputplumber" \
	"$ROOT/package/system/inputplumber/inputplumber.mk"; then
	echo "ab_swap consumer remains" >&2
	exit 1
fi
map=$ROOT/package/system/inputplumber/zlyme_miyoo_flip.yaml
awk '
	/event_code: BTN_EAST/ { east = 1; south = 0 }
	/event_code: BTN_SOUTH/ { south = 1; east = 0 }
	east && /button: South/ { print "east-south"; east = 0 }
	south && /button: East/ { print "south-east"; south = 0 }
' "$map" > /tmp/zlyme-ab-map.$$
grep -qx east-south /tmp/zlyme-ab-map.$$
grep -qx south-east /tmp/zlyme-ab-map.$$
rm -f /tmp/zlyme-ab-map.$$
grep -q 'a:b0,b:b1' "$ROOT/package/system/nextui/zlyme/gamecontrollerdb.txt"
echo "ab feature removed"
