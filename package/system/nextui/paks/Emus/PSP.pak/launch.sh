#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
SEED=
for s in /usr/share/zlyme/emu-defaults/ppsspp.ini /storage/.config/zlyme/emu-defaults/ppsspp.ini; do
	[ -f "$s" ] && SEED=$s && break
done
INI="${XDG_CONFIG_HOME:-$HOME/.config}/ppsspp/PSP/SYSTEM/ppsspp.ini"
if [ -n "$SEED" ] && [ ! -e "$INI" ]; then
	mkdir -p "$(dirname "$INI")"
	cp "$SEED" "$INI"
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu PSP >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec PPSSPPSDL "$ROM"
