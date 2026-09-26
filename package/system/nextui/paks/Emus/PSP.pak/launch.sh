#!/bin/sh
# PPSSPP 1.19 SDL has no --memstick. Config is $XDG_CONFIG_HOME/ppsspp
# (Knulli). Passing --memstick made PPSSPP treat the config dir as a ROM.
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
SDCARD_PATH="${SDCARD_PATH:-/storage}"
USERDATA_PATH="${USERDATA_PATH:-$SDCARD_PATH/.config/nextui/${PLATFORM:-my355}}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD_PATH/.config}"
export USERDATA_PATH XDG_CONFIG_HOME
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
export HOME
SEED=
for s in /usr/share/zlyme/emu-defaults/ppsspp.ini /storage/.config/zlyme/emu-defaults/ppsspp.ini; do
	[ -f "$s" ] && SEED=$s && break
done
INI="$XDG_CONFIG_HOME/ppsspp/PSP/SYSTEM/ppsspp.ini"
mkdir -p "$XDG_CONFIG_HOME/ppsspp/PSP/SYSTEM" \
	"$SAVES_PATH/PSP/SAVEDATA" "$SAVES_PATH/PSP/PPSSPP_STATE" \
	"$XDG_CONFIG_HOME/ppsspp/PSP/SAVEDATA" "$XDG_CONFIG_HOME/ppsspp/PSP/PPSSPP_STATE"
if [ -n "$SEED" ] && [ ! -e "$INI" ]; then
	cp "$SEED" "$INI"
fi
# One-time: an ini created before the xb360 map has no ControlMapping.
# A file that already has that section is a user map and stays.
if [ -f "$INI" ] && ! grep -q '^\[ControlMapping\]' "$INI"; then
	cat >> "$INI" <<'EOF'
# zlyme-pad-abi=xb360
[ControlMapping]
Up = 10-19
Down = 10-20
Left = 10-21
Right = 10-22
Circle = 10-190
Cross = 10-189
Square = 10-191
Triangle = 10-188
Start = 10-197
Select = 10-196
L = 10-193
R = 10-192
An.Up = 10-4003
An.Down = 10-4002
An.Left = 10-4001
An.Right = 10-4000
RightAn.Up = 10-4007
RightAn.Down = 10-4006
RightAn.Left = 10-4005
RightAn.Right = 10-4004
EOF
fi
if [ -d "$SAVES_PATH/PSP/SAVEDATA" ]; then
	mount --bind "$SAVES_PATH/PSP/SAVEDATA" "$XDG_CONFIG_HOME/ppsspp/PSP/SAVEDATA" 2>/dev/null || true
	mount --bind "$SAVES_PATH/PSP/PPSSPP_STATE" "$XDG_CONFIG_HOME/ppsspp/PSP/PPSSPP_STATE" 2>/dev/null || true
	trap 'umount "$XDG_CONFIG_HOME/ppsspp/PSP/SAVEDATA" 2>/dev/null; umount "$XDG_CONFIG_HOME/ppsspp/PSP/PPSSPP_STATE" 2>/dev/null' EXIT
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor heavy >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
# Assets live next to this prefix; cwd USERDATA_PATH has none.
if [ -d /usr/share/ppsspp/assets ]; then
	cd /usr/share/ppsspp || true
fi
exec PPSSPPSDL --fullscreen --dpi 0.5 "$ROM"
