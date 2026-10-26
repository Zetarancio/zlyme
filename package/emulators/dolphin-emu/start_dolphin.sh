#!/bin/sh
# Dolphin nogui on KMS/DRM. IPL is /storage/Bios/GC/{USA,EUR,JAP}/IPL.bin
ROM="$1"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
USERDATA="${USERDATA_PATH:-$SDCARD/.config/nextui/${PLATFORM:-my355}}"

if [ -z "$ROM" ] || [ ! -e "$ROM" ]; then
	echo "dolphin: missing ROM" >&2
	exit 1
fi

mkdir -p "$BIOS/GC/USA" "$BIOS/GC/EUR" "$BIOS/GC/JAP" "$BIOS/WII" \
	"$USERDATA/.local/share/dolphin-emu" \
	"${SAVES_PATH:-$SDCARD/Saves}/GC" \
	"${SAVES_PATH:-$SDCARD/Saves}/WII"

export HOME="$USERDATA"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$USERDATA/.local/share}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi
export EGL_PLATFORM="${EGL_PLATFORM:-drm}"
# Dolphin opens the first connected connector and can index that
# connector's mode list from a file under /var/run. The panel is first
# when HDMI is also connected, so that index is not the HDMI policy.
mkdir -p "$XDG_DATA_HOME/dolphin-emu" "$XDG_CONFIG_HOME/dolphin-emu" \
	"$XDG_DATA_HOME/dolphin-emu/GC" "$XDG_DATA_HOME/dolphin-emu/Wii" \
	"${SAVES_PATH:-$SDCARD/Saves}/GC" "${SAVES_PATH:-$SDCARD/Saves}/WII"

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
# First-run GameCube port 1. A later edit of GCPadNew.ini is kept.
# Dolphin calls SDL A "Button S". On this pad SDL A is east, SDL B
# is south, SDL X is north, and SDL Y is west. GameCube A is south.
pad="$XDG_CONFIG_HOME/dolphin-emu/GCPadNew.ini"
if [ ! -f "$pad" ]; then
	cat > "$pad" <<'EOF'
# zlyme-pad-abi=xb360
[GCPad1]
Device = SDL/0/Xbox 360 Controller
Buttons/A = `Button E`
Buttons/B = `Button N`
Buttons/Start = `Start`
Buttons/X = `Button S`
Buttons/Y = `Button W`
Buttons/Z = `Trigger R`
D-Pad/Down = `Pad S`
D-Pad/Left = `Pad W`
D-Pad/Right = `Pad E`
D-Pad/Up = `Pad N`
Main Stick/Dead Zone = 25.0
Main Stick/Down = `Left Y-`
Main Stick/Left = `Left X-`
Main Stick/Right = `Left X+`
Main Stick/Up = `Left Y+`
C-Stick/Dead Zone = 25.0
C-Stick/Down = `Right Y-`
C-Stick/Left = `Right X-`
C-Stick/Right = `Right X+`
C-Stick/Up = `Right Y+`
Triggers/Dead Zone = 0.
Triggers/Threshold = 90.
Triggers/L = `Shoulder L`
Triggers/R = `Shoulder R`
Triggers/L-Analog = `Shoulder L`
Triggers/R-Analog = `Shoulder R`
Rumble/Motor = Motor
EOF
fi

# exec replaces this shell. pak-launch releases the recorded mount
# ids outside this process group, including after MENU+START.
_dolphin_binds=${ZLYME_DOLPHIN_BINDS_SH:-/usr/share/zlyme/dolphin-binds.sh}
if [ ! -r "$_dolphin_binds" ]; then
	echo "dolphin: bind helper is missing" >&2
	exit 1
fi
# shellcheck disable=SC1090
. "$_dolphin_binds"
if ! dolphin_prepare \
	"${SAVES_PATH:-$SDCARD/Saves}/GC" \
	"$XDG_DATA_HOME/dolphin-emu/GC" \
	"${SAVES_PATH:-$SDCARD/Saves}/WII" \
	"$XDG_DATA_HOME/dolphin-emu/Wii"
then
	echo "dolphin: save binds are not ready" >&2
	exit 1
fi
unset _dolphin_binds

[ -x /usr/bin/zlyme-drm-release ] && /usr/bin/zlyme-drm-release
exec dolphin-emu-nogui -p drm -v OGL -C Dolphin.Core.GFXBackend=OGL -e "$ROM"
