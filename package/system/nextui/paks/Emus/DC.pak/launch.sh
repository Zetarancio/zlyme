#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
SEED=
for s in /usr/share/zlyme/emu-defaults/flycast/emu.cfg /storage/.config/zlyme/emu-defaults/flycast/emu.cfg; do
	[ -f "$s" ] && SEED=$s && break
done
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/flycast/emu.cfg"
if [ -n "$SEED" ] && [ ! -e "$CFG" ]; then
	mkdir -p "$(dirname "$CFG")"
	cp "$SEED" "$CFG"
fi
exec flycast "$ROM"
