#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
# The stock file is copied by zlyme-stock-seed when this cfg is missing.
# An existing cfg is the user's. This launcher does not edit it.
SEED=/usr/share/zlyme/emu-defaults/flycast/emu.cfg
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/flycast/emu.cfg"
if [ -f "$SEED" ] && [ ! -s "$CFG" ]; then
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
# exec replaces this shell, so an EXIT trap would not run. The bind
# stays up while Flycast exits, which is when it writes its autosave.
# pak-launch is outside the process group and unmounts the recorded
# path after wait, including when MENU+START has killed the group.
if [ -d "$SAVES_PATH/$EMU_TAG" ]; then
	if mount --bind "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast"; then
		_fly_bind=/tmp/zlyme-flycast-bind
		rm -f "$_fly_bind"
		printf '%s\n' "$XDG_DATA_HOME/flycast" > "$_fly_bind"
		unset _fly_bind
	fi
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
exec flycast "$ROM"
