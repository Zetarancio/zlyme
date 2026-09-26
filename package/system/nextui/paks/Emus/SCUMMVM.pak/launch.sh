#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
mkdir -p "$SAVES_PATH/SCUMMVM"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi
# The physical pad is hidden, so joystick 0 is the virtual target.
joy=0
if [ -d "$ROM" ]; then
	exec scummvm --fullscreen --joystick="$joy" --auto-detect --savepath="$SAVES_PATH/SCUMMVM" -p "$ROM"
fi
dir=$(dirname "$ROM")
mkdir -p "$SAVES_PATH/SCUMMVM"
exec scummvm --fullscreen --joystick="$joy" --auto-detect --savepath="$SAVES_PATH/SCUMMVM" -p "$dir"
