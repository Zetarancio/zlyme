#!/bin/sh
EMU_EXE=easyrpg
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$BIOS_PATH/rtp/2000" "$BIOS_PATH/rtp/2003"
HOME="$USERDATA_PATH"
cd "$HOME"
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
