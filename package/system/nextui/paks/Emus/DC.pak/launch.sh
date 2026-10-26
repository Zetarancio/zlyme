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
if [ -z "$ROM" ] || [ ! -e "$ROM" ]; then
	echo "flycast: missing ROM" >&2
	exit 1
fi
# exec replaces this shell. The bind stays up while Flycast exits,
# which is when it writes its autosave. pak-launch is outside the
# process group and releases the recorded mount id after wait,
# including when MENU+START has killed the group.
_flycast_binds=${ZLYME_FLYCAST_BINDS_SH:-/usr/share/nextui/bin/flycast-binds.sh}
if [ ! -r "$_flycast_binds" ]; then
	echo "flycast: bind helper is missing" >&2
	exit 1
fi
# shellcheck disable=SC1090
. "$_flycast_binds"
if ! flycast_prepare "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast"; then
	echo "flycast: save bind is not ready" >&2
	exit 1
fi
unset _flycast_binds
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
exec flycast "$ROM"
