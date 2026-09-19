#!/bin/sh
# Dolphin nogui on KMS/DRM. IPL is /storage/Bios/GC/{USA,EUR,JAP}/IPL.bin
ROM="$1"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
USERDATA="${USERDATA_PATH:-$SDCARD/.config/nextui/${PLATFORM:-my355}}"

mkdir -p "$BIOS/GC/USA" "$BIOS/GC/EUR" "$BIOS/GC/JAP" "$BIOS/WII" \
	"$USERDATA/.local/share/dolphin-emu" \
	"${SAVES_PATH:-$SDCARD/Saves}/GC" \
	"${SAVES_PATH:-$SDCARD/Saves}/WII"

export HOME="$USERDATA"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$USERDATA/.local/share}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export EGL_PLATFORM="${EGL_PLATFORM:-drm}"
mkdir -p "$XDG_DATA_HOME/dolphin-emu" "$XDG_CONFIG_HOME/dolphin-emu"

# Card dumps often sit at Bios/IPL.bin. Dolphin only looks under GC/<region>/.
for region in USA EUR JAP; do
	if [ -f "$BIOS/IPL.bin" ] && [ ! -e "$BIOS/GC/$region/IPL.bin" ]; then
		ln -s "../../IPL.bin" "$BIOS/GC/$region/IPL.bin" 2>/dev/null || true
	fi
	if [ -f "$BIOS/GC/IPL.bin" ] && [ ! -e "$BIOS/GC/$region/IPL.bin" ]; then
		ln -s "../IPL.bin" "$BIOS/GC/$region/IPL.bin" 2>/dev/null || true
	fi
done

# Vulkan is compiled in (loader is on the image) but Mali GLES is OGL.
ini="$XDG_CONFIG_HOME/dolphin-emu/Dolphin.ini"
if [ ! -f "$ini" ]; then
	printf '%s\n' '[Core]' 'GFXBackend = OGL' > "$ini"
fi

if [ -z "$ROM" ] || [ ! -e "$ROM" ]; then
	echo "dolphin: missing ROM" >&2
	exit 1
fi

[ -x /usr/bin/zlyme-drm-release ] && /usr/bin/zlyme-drm-release
exec dolphin-emu-nogui -p drm -v OGL -C Dolphin.Core.GFXBackend=OGL -e "$ROM"
