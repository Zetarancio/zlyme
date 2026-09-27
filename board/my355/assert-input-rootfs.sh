#!/usr/bin/env bash
# Verify the packed application input path, not just output/target. Local
# Buildroot packages can keep old compiled objects after a source edit.
set -euo pipefail

image=${1:?expected rootfs.squashfs}
host=${HOST_DIR:?HOST_DIR is required}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

files=(
	usr/sbin/zlyme-pak-hotkey
	usr/sbin/zlyme-keylidmon
	usr/sbin/nextui-session
	usr/share/zlyme/pak-input.sh
	usr/lib/gamecontrollerdb.txt
	usr/bin/ra-run
	usr/bin/pico8
	usr/bin/start_drastic
	usr/bin/start_dolphin
	usr/bin/aethersx2
	usr/share/drastic/config/drastic.cfg
	usr/share/zlyme/emu-defaults/ppsspp.ini
	usr/share/zlyme/emu-defaults/flycast/emu.cfg
	usr/share/nextui/paks/Emus/PSP.pak/launch.sh
	usr/share/nextui/paks/Emus/DC.pak/launch.sh
	usr/share/nextui/paks/Emus/OPENBOR.pak/launch.sh
	usr/share/nextui/paks/Emus/PORTS.pak/launch.sh
	usr/share/nextui/paks/Emus/WINE.pak/launch.sh
)
"$host/bin/unsquashfs" -no-progress -match -d "$tmp" "$image" \
	"${files[@]}" >/dev/null

check_copy() {
	local source=$1 target=$2
	if ! cmp -s "$repo/$source" "$tmp/$target"; then
		echo "input-rootfs: stale or missing $target (source $source)" >&2
		exit 1
	fi
}

check_copy package/system/nextui/nextui-session usr/sbin/nextui-session
check_copy package/system/nextui/zlyme/pak-input.sh usr/share/zlyme/pak-input.sh
check_copy package/system/nextui/zlyme/gamecontrollerdb.txt usr/lib/gamecontrollerdb.txt
check_copy package/system/nextui/zlyme/ra-run.sh usr/bin/ra-run
check_copy package/emulators/pico8/start_pico8.sh usr/bin/pico8
check_copy package/emulators/drastic/start_drastic.sh usr/bin/start_drastic
check_copy package/emulators/dolphin-emu/start_dolphin.sh usr/bin/start_dolphin
check_copy package/emulators/aethersx2/start_aethersx2.sh usr/bin/aethersx2
check_copy package/emulators/drastic/config/drastic.cfg usr/share/drastic/config/drastic.cfg
check_copy board/my355/fsoverlay/usr/share/zlyme/emu-defaults/ppsspp.ini usr/share/zlyme/emu-defaults/ppsspp.ini
check_copy board/my355/fsoverlay/usr/share/zlyme/emu-defaults/flycast/emu.cfg usr/share/zlyme/emu-defaults/flycast/emu.cfg
check_copy package/system/nextui/paks/Emus/PSP.pak/launch.sh usr/share/nextui/paks/Emus/PSP.pak/launch.sh
check_copy package/system/nextui/paks/Emus/DC.pak/launch.sh usr/share/nextui/paks/Emus/DC.pak/launch.sh
check_copy package/system/nextui/paks/Emus/OPENBOR.pak/launch.sh usr/share/nextui/paks/Emus/OPENBOR.pak/launch.sh
check_copy package/system/nextui/paks/Emus/PORTS.pak/launch.sh usr/share/nextui/paks/Emus/PORTS.pak/launch.sh
check_copy package/system/nextui/paks/Emus/WINE.pak/launch.sh usr/share/nextui/paks/Emus/WINE.pak/launch.sh

for binary in zlyme-pak-hotkey zlyme-keylidmon; do
	file="$tmp/usr/sbin/$binary"
	if ! grep -aqF 'Microsoft X-Box 360 pad' "$file"; then
		echo "input-rootfs: $binary is not the virtual-controller implementation" >&2
		exit 1
	fi
	if grep -aqE 'Miyoo Flip Gamepad|/dev/input/js0|/dev/js0' "$file"; then
		echo "input-rootfs: $binary contains an old physical-controller path" >&2
		exit 1
	fi
done

echo "input-rootfs: packed application input path verified"
