#!/bin/sh
# Host decisions for the selector linked into NextUI. This does not open DRM.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
SRC=$NEXT/workspace/my355/platform/hdmi_mode.c
HDR=$NEXT/workspace/my355/platform
fail() { echo "hdmi-mode-test: $*" >&2; exit 1; }
[ -f "$SRC" ] || {
	echo "hdmi-mode-test blocked: $SRC is missing" >&2
	exit 2
}
S16=$ROOT/board/my355/fsoverlay/etc/init.d/S16display
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc -std=c11 -Wall -Wextra -Werror -I "$HDR" \
	-o "$work/hdmi-mode-test" \
	"$SRC" \
	"$ROOT/scripts/tests/test_hdmi_mode.c"
"$work/hdmi-mode-test"
grep -q '50|40|60' "$S16" || fail "panel refresh values changed"
grep -q '640x480@' "$S16" || fail "DSI mode string changed"
grep -q 'card\*-DSI-' "$S16" || fail "DSI connector walk changed"
grep -q 'card\*-HDMI-A-1' "$S16" || fail "HDMI sysfs replay was removed"
if [ -e "$ROOT/board/my355/hdmi-mode.c" ] || [ -e "$ROOT/board/my355/hdmi-mode.h" ]; then
	fail "Zlyme still has a second HDMI selector"
fi
grep -q 'PLAT_hdmi_after_window' "$NEXT/workspace/all/common/generic_video.c" \
	|| fail "NextUI startup does not call the HDMI hook"
grep -q 'PLAT_hdmi_map_output' "$NEXT/workspace/all/common/generic_video.c" \
	|| fail "GL output does not use the HDMI viewport"
grep -q 'ZLYME_HDMI_720P' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "HDMI modeset has no gate"
grep -q 'SDL_WINDOWPOS_CENTERED_DISPLAY' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "window is not moved onto the HDMI display"
grep -q 'SDL_SetWindowDisplayMode' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "SDL display mode is not requested"
grep -q 'SDL_GetWindowDisplayMode' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "SDL selected mode is not checked"
grep -q 'drmDropMaster' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "DRM fd is closed without dropping an accidental master"
grep -q 'drmSetMaster' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	&& fail "HDMI path takes DRM master"
echo "hdmi mode script ok"
