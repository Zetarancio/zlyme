#!/bin/sh
EMU_EXE=mame078plus
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$BIOS_PATH/mame2003-plus"
HOME="$USERDATA_PATH"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
if command -v zlyme-arcade-stage >/dev/null 2>&1; then
	ROM=$(zlyme-arcade-stage "$EMU_TAG" "$ROM")
fi
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
