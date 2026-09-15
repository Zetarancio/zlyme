#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu AMIGA >/dev/null 2>&1 || true
HOME="$USERDATA_PATH"
cd "$HOME"
exec amiberry "$ROM"
