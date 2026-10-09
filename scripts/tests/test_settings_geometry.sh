#!/bin/sh
# my355 Settings list rectangle versus the hint pill.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
UI=${ZLYME_SETTINGS_DIR:-$ROOT/../zlyme-nextui/workspace/all/settings}
bin=$ROOT/output/host/test-settings-geometry
mkdir -p "$ROOT/output/host"
g++ -std=c++17 -Wall -Wextra -I "$UI" -o "$bin" "$ROOT/scripts/tests/test_settings_geometry.cpp"
"$bin"
rm -f "$bin"

settings=$UI/settings.cpp
notes=$UI/zlymeupdate.cpp
picker=$UI/colorpickermenu.cpp
menu=$UI/menu.cpp
wifi=$UI/wifimenu.cpp
bt=$UI/btmenu.cpp

grep -q 'zlyme_settings_content' "$settings"
grep -q 'SCALE1(PILL_SIZE), SCALE1(PILL_SIZE)' "$settings"
if grep -q 'listRect.h -= SCALE1(BUTTON_SIZE)' "$settings"; then
	echo "settings still reserves BUTTON_SIZE for the hint pill" >&2
	exit 1
fi
if grep -q 'hint_reserve' "$notes"; then
	echo "release notes still reserve the hint band a second time" >&2
	exit 1
fi
if grep -q 'dst.h - SCALE1(BUTTON_SIZE)' "$picker"; then
	echo "color picker still reserves BUTTON_SIZE inside the content rect" >&2
	exit 1
fi
grep -q 'performLayout(dst)' "$menu"
if grep -F -q 'title == "WiFi"' "$wifi" "$bt" "$settings" || grep -F -q 'title == "Bluetooth"' "$wifi" "$bt" "$settings"; then
	echo "layout special-cases a menu title" >&2
	exit 1
fi
grep -q 'ownsHints' "$settings"
echo "settings geometry ok"
