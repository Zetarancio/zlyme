#!/bin/sh
# Phase 9N contracts: editor background, button indices, PPSSPP path, PortMaster identity.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ui=/home/ale/zlyme-nextui/workspace/all/nextui/nextui.c
plat=/home/ale/zlyme-nextui/workspace/my355/platform/platform.h
awk '
	/currentScreen == SCREEN_EDITPREFS/ { on = 1 }
	on && /THEME_COLOR7/ { bg = 1 }
	on && /editprefs_blit_row/ { if (!bg) bad = 1 }
	on && /currentScreen == SCREEN_QUICKMENU/ { on = 0 }
	END { exit bad ? 1 : 0 }
' "$ui"
awk '/define JOY_A/ { print $3 }' "$plat" | grep -qx 0
awk '/define JOY_B/ { print $3 }' "$plat" | grep -qx 1
grep -q 'workspace/$(MINUI_LIST_PLATFORM)/platform' "$ROOT/package/system/minui-list/minui-list.mk"
grep -q 'workspace/$(MINUI_PRESENTER_PLATFORM)/platform' "$ROOT/package/system/minui-presenter/minui-presenter.mk"
grep -q 'USE_WAYLAND_WSI=ON' "$ROOT/package/emulators/ppsspp/ppsspp.mk"
grep -q 'zlyme-weston-run PPSSPPSDL' "$ROOT/package/system/nextui/paks/Emus/PSP.pak/launch.sh"
grep -F -q 'GraphicsBackend *= *3' "$ROOT/package/system/nextui/paks/Emus/PSP.pak/launch.sh"
grep -q 'exec PPSSPPSDL' "$ROOT/package/system/nextui/paks/Emus/PSP.pak/launch.sh"
grep -q 'export CFW_NAME=Zlyme' "$ROOT/package/system/portmaster/control.txt"
grep -q 'zlyme-drm-release' "$ROOT/package/system/nextui/paks/Emus/PORTS.pak/launch.sh"
echo "phase9n ok"
