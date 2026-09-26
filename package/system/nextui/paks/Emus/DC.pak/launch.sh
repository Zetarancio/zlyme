#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
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
mkdir -p "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast"
for f in dc_boot.bin dc_flash.bin; do
	for src in "$BIOS_PATH/DC/$f" "$BIOS_PATH/$f"; do
		[ -f "$src" ] || continue
		[ -e "$SAVES_PATH/$EMU_TAG/$f" ] || ln -s "$src" "$SAVES_PATH/$EMU_TAG/$f" 2>/dev/null || cp -n "$src" "$SAVES_PATH/$EMU_TAG/$f" 2>/dev/null || true
		break
	done
done
if [ -d "$SAVES_PATH/$EMU_TAG" ]; then
	mount --bind "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast" 2>/dev/null || true
	trap 'umount "$XDG_DATA_HOME/flycast" 2>/dev/null' EXIT
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor heavy >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec flycast "$ROM"
