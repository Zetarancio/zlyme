#!/bin/sh
# Zlyme-owned Settings must not reboot or power off by itself.
set -eu
src=${1:-}
if [ -z "$src" ]; then
	echo "usage: $0 SETTINGS_DIR" >&2
	exit 2
fi
if grep -n -E 'reboot -f|poweroff -f|system\("reboot|system\("poweroff' \
	"$src"/zlymemenu.cpp "$src"/zlymeupdate.cpp
then
	echo "direct reboot or poweroff in Settings" >&2
	exit 1
fi
echo "settings reboot path ok"
