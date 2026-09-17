#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
export WINEPREFIX="${WINEPREFIX:-$USERDATA_PATH/wine}"
mkdir -p "$WINEPREFIX"
cd "$HOME"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu WINE >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec wine "$ROM"
