#!/bin/sh
# Format UI lives in Settings. The backend is still zlyme-storage-format.
# No block device is used here.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ui=/home/ale/zlyme-nextui/workspace/all/settings/zlymemenu.cpp
if [ -e "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-format-ui" ]; then
	echo "format wrapper still present" >&2
	exit 1
fi
if grep -q 'zlyme-format-ui' "$ui"; then
	echo "settings still launches the format wrapper" >&2
	exit 1
fi
if grep -q minui-list "$ui" || grep -q minui-presenter "$ui"; then
	echo "settings format path uses minui helpers" >&2
	exit 1
fi
grep -q 'FormatDeviceMenu' "$ui"
grep -q 'exFAT' "$ui"
grep -q 'ext4' "$ui"
grep -q 'ALL DATA WILL BE LOST' "$ui"
grep -q 'device disappeared' "$ui"
grep -q 'Format finished' "$ui"
grep -q 'Format failed' "$ui"
grep -q 'execl("/usr/sbin/zlyme-storage-format"' "$ui"
grep -q '"format"' "$ui"
grep -q 'ZLYME-LIB' "$ui"
if grep -q 'system(".*zlyme-storage-format' "$ui"; then
	echo "format backend is invoked through a shell" >&2
	exit 1
fi
# Backend safety tests stay in test_storage_format.sh.
echo "format native ok"
