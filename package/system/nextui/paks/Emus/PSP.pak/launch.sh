#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
SEED=/usr/share/zlyme/emu-defaults/ppsspp.ini
INI="${XDG_CONFIG_HOME:-$HOME/.config}/ppsspp/PSP/SYSTEM/ppsspp.ini"
if [ -f "$SEED" ] && [ ! -e "$INI" ]; then
	mkdir -p "$(dirname "$INI")"
	cp "$SEED" "$INI"
fi
exec PPSSPPSDL "$ROM"
