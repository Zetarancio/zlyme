#!/bin/sh
EMU_EXE=fake08
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
if [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/nextui/bin/zlyme-library.sh
	zlyme_library_for "$ROM"
fi
HOME="$USERDATA_PATH"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
if [ "${ZLYME_EMU_CORE:-}" = native ]; then
	exec pico8 "$ROM"
fi
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
