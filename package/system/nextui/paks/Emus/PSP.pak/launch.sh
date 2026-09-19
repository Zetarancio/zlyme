#!/bin/sh
# PPSSPP 1.19 SDL has no --memstick. Config is $XDG_CONFIG_HOME/ppsspp
# (Knulli). Passing --memstick made PPSSPP treat the config dir as a ROM.
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
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
