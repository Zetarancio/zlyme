#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
SEED=/usr/share/zlyme/emu-defaults/flycast/emu.cfg
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/flycast/emu.cfg"
if [ -f "$SEED" ] && [ ! -e "$CFG" ]; then
	mkdir -p "$(dirname "$CFG")"
	cp "$SEED" "$CFG"
fi
exec flycast "$ROM"
