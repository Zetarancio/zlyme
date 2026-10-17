#!/bin/sh
# Host decisions for the selector linked into NextUI. This does not open DRM.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
SRC=$ROOT/package/system/zlyme-hdmi/hdmi_mode.c
HDR=$ROOT/package/system/zlyme-hdmi
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
if [ -e "$ROOT/board/my355/hdmi-mode.c" ] || [ -e "$NEXT/workspace/my355/platform/hdmi_mode.c" ]; then
	fail "a second HDMI selector is still in the tree"
fi
grep -q 'PLAT_hdmi_after_window' "$NEXT/workspace/all/common/generic_video.c" \
	|| fail "NextUI startup does not call the HDMI hook"
grep -q 'PLAT_hdmi_note_present' "$NEXT/workspace/all/common/generic_video.c" \
	|| fail "scanout is not checked after present"
grep -q 'ZLYME_HDMI_SCANOUT' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	|| fail "scanout log is missing"
grep -q 'SDL_SetWindowFullscreen' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	&& fail "NextUI still modesets after the GL resources exist"
grep -q 'drmDropMaster\|drmModeGetResources' "$NEXT/workspace/my355/platform/hdmi_apply.c" \
	&& fail "NextUI still opens DRM itself"
grep -q 'DRM_MODE_CONNECTOR_HDMIA' "$ROOT/board/my355/patches/sdl2/0001-kmsdrm-honor-zlyme-hdmi-mode.patch" \
	|| fail "SDL patch does not require an HDMI-A connector"
grep -q 'connector_id' "$ROOT/board/my355/patches/sdl2/0001-kmsdrm-honor-zlyme-hdmi-mode.patch" \
	|| fail "SDL patch matches by size alone"
echo "hdmi mode script ok"
