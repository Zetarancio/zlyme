#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
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
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$XDG_DATA_HOME/flycast"
for f in dc_boot.bin dc_flash.bin; do
	for src in "$BIOS_PATH/DC/$f" "$BIOS_PATH/$f"; do
		[ -f "$src" ] || continue
		[ -e "$XDG_DATA_HOME/flycast/$f" ] || ln -s "$src" "$XDG_DATA_HOME/flycast/$f"
		break
	done
done
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor heavy >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec flycast "$ROM"
