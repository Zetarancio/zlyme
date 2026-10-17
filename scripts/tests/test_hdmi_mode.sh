#!/bin/sh
# Host decisions for an HDMI mode list. This does not open DRM.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "hdmi-mode-test: $*" >&2; exit 1; }
S16=$ROOT/board/my355/fsoverlay/etc/init.d/S16display
cc -std=c11 -Wall -Wextra -Werror -I "$ROOT/board/my355" \
	-o "$ROOT/scripts/tests/hdmi-mode-test" \
	"$ROOT/board/my355/hdmi-mode.c" \
	"$ROOT/scripts/tests/test_hdmi_mode.c"
"$ROOT/scripts/tests/hdmi-mode-test"
rm -f "$ROOT/scripts/tests/hdmi-mode-test"
grep -q '50|40|60' "$S16" || fail "panel refresh values changed"
grep -q '640x480@' "$S16" || fail "DSI mode string changed"
grep -q 'card\*-DSI-' "$S16" || fail "DSI connector walk changed"
grep -q 'card\*-HDMI-A-1' "$S16" || fail "HDMI sysfs replay was removed"
echo "hdmi mode script ok"
