#!/bin/sh
EMU_EXE=bluemsx
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
# blueMSX wants Machines/ and Databases/ in system_directory, not Bios/MSX.
# The core recipe still installs them under the Knulli datainit path.
for d in Machines Databases; do
	src="/usr/share/batocera/datainit/bios/$d"
	dst="$BIOS_PATH/$d"
	if [ -L "$dst" ] && [ ! -e "$dst" ]; then
		rm -f "$dst"
	fi
	if [ ! -e "$dst" ] && [ -d "$src" ]; then
		ln -s "$src" "$dst"
	fi
done
HOME="$USERDATA_PATH"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
