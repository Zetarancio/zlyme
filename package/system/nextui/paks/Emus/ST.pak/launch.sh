#!/bin/sh
EMU_EXE=hatari
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
# Hatari only looks at Bios/tos.img. EmuTOS is the legal stand-in.
if [ ! -e "$BIOS_PATH/tos.img" ]; then
	for c in "$BIOS_PATH/ST/"etos*.img "$BIOS_PATH/"etos*.img \
		"$BIOS_PATH/ST/tos.img"; do
		[ -f "$c" ] || continue
		ln -sf "$c" "$BIOS_PATH/tos.img" 2>/dev/null || cp -f "$c" "$BIOS_PATH/tos.img"
		break
	done
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
exec ra-run -L "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM"
