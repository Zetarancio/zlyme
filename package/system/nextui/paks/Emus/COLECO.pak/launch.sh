#!/bin/sh
EMU_EXE=gearcoleco
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
# Gearcoleco wants colecovision.rom in system_directory (Bios/).
if [ -f "$BIOS_PATH/coleco.rom" ] && [ ! -e "$BIOS_PATH/colecovision.rom" ]; then
	ln -s coleco.rom "$BIOS_PATH/colecovision.rom"
fi
HOME="$USERDATA_PATH"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
