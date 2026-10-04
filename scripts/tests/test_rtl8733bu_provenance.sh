#!/bin/sh
# The power driver records its archived-fork origin. GPL-2.0-only stays.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
lic=$ROOT/package/drivers/rtl8733bu-power/LICENSE
src=$ROOT/package/drivers/rtl8733bu-power/src/rtl8733bu_power.c
mk=$ROOT/package/drivers/rtl8733bu-power/rtl8733bu-power.mk

grep -q 'fbd8dd1545309950b0e13a495c659501549a957c' "$lic"
grep -q 'Zetarancio' "$lic"
grep -q 'GPL-2.0-only' "$lic"
if grep -q 'Original Zlyme source' "$lic"; then
	echo "LICENSE still claims original Zlyme source" >&2
	exit 1
fi
grep -q 'MODULE_AUTHOR("Zetarancio")' "$src"
grep -q 'MODULE_LICENSE("GPL v2")' "$src"
grep -q 'fbd8dd154530' "$src"
if grep -q 'MODULE_AUTHOR("ROCKNIX")' "$src"; then
	echo "module still names ROCKNIX as the author" >&2
	exit 1
fi
grep -q 'RTL8733BU_POWER_LICENSE = GPL-2.0-only' "$mk"

echo "rtl8733bu provenance ok"
