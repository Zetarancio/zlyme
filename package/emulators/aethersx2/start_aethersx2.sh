#!/bin/sh
# AetherSX2 on EGLFS. BIOS is /storage/Bios/PS2 (not the ROM folder).
ROM="$1"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
USERDATA="${USERDATA_PATH:-$SDCARD/.config/nextui/${PLATFORM:-my355}}"
CFG="$SDCARD/.config/aethersx2"
BIN=/usr/share/aethersx2/aethersx2

mkdir -p "$BIOS/PS2" "$CFG/inis" \
	"${SAVES_PATH:-$SDCARD/Saves}/PS2"

if [ -f /usr/share/aethersx2/patches.zip ] && [ ! -e "$BIOS/PS2/patches.zip" ]; then
	cp -f /usr/share/aethersx2/patches.zip "$BIOS/PS2/patches.zip"
fi

export HOME="$USERDATA"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD/.config}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
export QT_PLUGIN_PATH="${QT_PLUGIN_PATH:-/usr/lib/qt6/plugins}"
# Prebuilt binary needs libaio (and may grow more). Card extras win.
for extra in \
	"$SDCARD/.config/zlyme/lib" \
	/usr/share/aethersx2/lib
do
	[ -d "$extra" ] || continue
	export LD_LIBRARY_PATH="$extra${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
done

INI="$CFG/inis/PCSX2.ini"
if [ ! -f "$INI" ]; then
	cat > "$INI" <<EOF
[Folders]
Bios = $BIOS/PS2
Savestates = ${SAVES_PATH:-$SDCARD/Saves}/PS2
MemoryCards = ${SAVES_PATH:-$SDCARD/Saves}/PS2
Cheats = $SDCARD/Cheats/PS2
Logs = /tmp
Cache = $CFG/cache
[EmuCore]
EnableCheats = false
[EmuCore/GS]
Renderer = 14
upscale_multiplier = 1
VsyncEnable = true
AspectRatio = 4:3
EOF
fi

if [ ! -x "$BIN" ]; then
	echo "aethersx2: missing $BIN" >&2
	exit 1
fi
if [ -z "$ROM" ] || [ ! -e "$ROM" ]; then
	echo "aethersx2: missing ROM" >&2
	exit 1
fi

cd /usr/share/aethersx2 || true
[ -x /usr/bin/zlyme-drm-release ] && /usr/bin/zlyme-drm-release
exec "$BIN" -batch "$ROM"
