#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$USERDATA_PATH/OpenBOR/Paks"
HOME="$USERDATA_PATH"
romdir=$(dirname "$ROM")
cd "$romdir" 2>/dev/null || cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec OpenBOR "$ROM"
