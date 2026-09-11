#!/bin/sh
EMU_EXE=nestopia
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
exec retroarch -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
