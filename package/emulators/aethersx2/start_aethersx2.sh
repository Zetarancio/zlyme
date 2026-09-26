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
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi
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
# zlyme-pad-abi=xb360
[InputSources]
SDL = true
SDLControllerEnhancedMode = false
XInput = false
RawInput = false
[Pad]
MultitapPort1 = false
MultitapPort2 = false
[Pad1]
Type = DualShock2
Up = SDL-0/DPadUp
Right = SDL-0/DPadRight
Down = SDL-0/DPadDown
Left = SDL-0/DPadLeft
Triangle = SDL-0/Y
Circle = SDL-0/B
Cross = SDL-0/A
Square = SDL-0/X
Select = SDL-0/Back
Start = SDL-0/Start
L1 = SDL-0/LeftShoulder
L2 = SDL-0/+LeftTrigger
R1 = SDL-0/RightShoulder
R2 = SDL-0/+RightTrigger
L3 = SDL-0/LeftStick
R3 = SDL-0/RightStick
LUp = SDL-0/-LeftY
LRight = SDL-0/+LeftX
LDown = SDL-0/+LeftY
LLeft = SDL-0/-LeftX
RUp = SDL-0/-RightY
RRight = SDL-0/+RightX
RDown = SDL-0/+RightY
RLeft = SDL-0/-RightX
LargeMotor = SDL-0/LargeMotor
SmallMotor = SDL-0/SmallMotor
[Pad2]
Type = None
EOF
fi
# One-time. An ini that already has Pad1 keeps the user's binds.
# Guide is not bound: MENU+START is the session hotkey.
if [ -f "$INI" ] && ! grep -q '^\[Pad1\]' "$INI"; then
	cat >> "$INI" <<'EOF'
# zlyme-pad-abi=xb360
[InputSources]
SDL = true
SDLControllerEnhancedMode = false
XInput = false
RawInput = false
[Pad]
MultitapPort1 = false
MultitapPort2 = false
[Pad1]
Type = DualShock2
Up = SDL-0/DPadUp
Right = SDL-0/DPadRight
Down = SDL-0/DPadDown
Left = SDL-0/DPadLeft
Triangle = SDL-0/Y
Circle = SDL-0/B
Cross = SDL-0/A
Square = SDL-0/X
Select = SDL-0/Back
Start = SDL-0/Start
L1 = SDL-0/LeftShoulder
L2 = SDL-0/+LeftTrigger
R1 = SDL-0/RightShoulder
R2 = SDL-0/+RightTrigger
L3 = SDL-0/LeftStick
R3 = SDL-0/RightStick
LUp = SDL-0/-LeftY
LRight = SDL-0/+LeftX
LDown = SDL-0/+LeftY
LLeft = SDL-0/-LeftX
RUp = SDL-0/-RightY
RRight = SDL-0/+RightX
RDown = SDL-0/+RightY
RLeft = SDL-0/-RightX
LargeMotor = SDL-0/LargeMotor
SmallMotor = SDL-0/SmallMotor
[Pad2]
Type = None
EOF
fi

if [ -f "$INI" ]; then
	sed -i \
		-e "s|^Bios = .*|Bios = $BIOS/PS2|" \
		-e "s|^Savestates = .*|Savestates = ${SAVES_PATH:-$SDCARD/Saves}/PS2|" \
		-e "s|^MemoryCards = .*|MemoryCards = ${SAVES_PATH:-$SDCARD/Saves}/PS2|" \
		"$INI" 2>/dev/null || true
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
