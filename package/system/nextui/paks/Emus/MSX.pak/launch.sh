#!/bin/sh
EMU_EXE=bluemsx
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
# blueMSX wants Machines/ and Databases/ in system_directory, not Bios/MSX.
for d in Machines Databases; do
	if [ ! -e "$BIOS_PATH/$d" ] && [ -d "/usr/share/batocera/datainit/bios/$d" ]; then
		ln -s "/usr/share/batocera/datainit/bios/$d" "$BIOS_PATH/$d"
	fi
done
HOME="$USERDATA_PATH"
cd "$HOME"
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
