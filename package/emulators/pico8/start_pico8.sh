#!/bin/sh
# PICO-8 is not redistributable. Look for pico8_64 + pico8.dat next to
# carts or under Bios/PICO (minui-pico-8-pak layout).
#
# A path whose name contains "splore" starts Splore instead of -run.

STATIC_BIN="pico8_64"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
SHARED="${SHARED_USERDATA_PATH:-$SDCARD/.userdata/shared}"
HOME_DIR="${SHARED}/Pico-8-native"
ROM="$1"

GAME_DIR=""
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
	GAME_DIR=$(dirname "$ROM")
fi

LAUNCH_DIR=""
set --
[ -n "$GAME_DIR" ] && set -- "$GAME_DIR" "$GAME_DIR/aarch64"
set -- "$@" \
	"$BIOS/PICO" \
	"$BIOS/PICO/aarch64" \
	"$BIOS/PICO-8" \
	"$SDCARD/Roms/Pico-8 (PICO)" \
	"$SDCARD/Roms/Pico-8 (PICO)/aarch64" \
	"$SDCARD/Roms/PICO-8" \
	"$SDCARD/Roms/PICO-8/aarch64" \
	"/mnt/SDCARD/Roms/PICO-8" \
	"/mnt/SDCARD/Roms/PICO-8/aarch64"
for d in "$@"; do
	[ -n "$d" ] || continue
	if [ -x "$d/$STATIC_BIN" ] || [ -f "$d/$STATIC_BIN" ]; then
		LAUNCH_DIR=$d
		break
	fi
done

if [ -z "$LAUNCH_DIR" ]; then
	echo "pico8: put ${STATIC_BIN} and pico8.dat in ${BIOS}/PICO or the Pico-8 roms folder" >&2
	exit 1
fi

chmod 0755 "$LAUNCH_DIR/$STATIC_BIN" 2>/dev/null || true
mkdir -p "$HOME_DIR"

if [ -z "$GAME_DIR" ] || [ ! -d "$GAME_DIR" ]; then
	GAME_DIR="$SDCARD/Roms/Pico-8 (PICO)"
	mkdir -p "$GAME_DIR"
fi

cd "$LAUNCH_DIR" || exit 1
if echo "$ROM" | grep -qi splore; then
	exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick 0 -splore
else
	exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick 0 -run "$ROM"
fi
