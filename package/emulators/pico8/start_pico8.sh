#!/bin/sh
# PICO-8 is not redistributable. MinUI layout is Bios/PICO/pico8_64
# plus pico8.dat (also accepted next to carts).
#
# A path whose name contains "splore" starts Splore instead of -run.
# The NextUI dummy Splore.p8 must not be on -root_path: pico8 then
# run_carts that PNG stub and the pad does nothing.

STATIC_BIN="pico8_64"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
SHARED="${SHARED_USERDATA_PATH:-$SDCARD/.userdata/shared}"
HOME_DIR="${SHARED}/Pico-8-native"
ROM="$1"
DB="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"

# Older cards dropped the binary in Bios/. MinUI is Bios/PICO/.
mkdir -p "$BIOS/PICO"
for f in pico8_64 pico8.dat pico8_dyn; do
	if [ -e "$BIOS/$f" ] && [ ! -e "$BIOS/PICO/$f" ]; then
		mv "$BIOS/$f" "$BIOS/PICO/$f" 2>/dev/null || true
	fi
done

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
	"$BIOS" \
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
	echo "pico8: put ${STATIC_BIN} and pico8.dat in ${BIOS}/PICO" >&2
	exit 1
fi

chmod 0755 "$LAUNCH_DIR/$STATIC_BIN" 2>/dev/null || true
mkdir -p "$HOME_DIR/carts"

export SDL_GAMECONTROLLERCONFIG_FILE="$DB"
if [ -z "${SDL_GAMECONTROLLERCONFIG:-}" ] && [ -f "$DB" ]; then
	SDL_GAMECONTROLLERCONFIG=$(grep -v '^#' "$DB" | grep 'retrogame_joypad' | head -n 1)
	export SDL_GAMECONTROLLERCONFIG
fi

# ROCKNIX: pico8 reads sdl_controllers.txt next to the binary and under -home.
if [ -f "$DB" ]; then
	for dest in "$HOME_DIR/sdl_controllers.txt" "$LAUNCH_DIR/sdl_controllers.txt"; do
		cmp -s "$DB" "$dest" 2>/dev/null && continue
		cp -f "$DB" "$dest" 2>/dev/null || true
	done
fi

if [ -z "$GAME_DIR" ] || [ ! -d "$GAME_DIR" ]; then
	GAME_DIR="$SDCARD/Roms/Pico-8 (PICO)"
	mkdir -p "$GAME_DIR"
fi

cd "$LAUNCH_DIR" || exit 1
if echo "$ROM" | grep -qi splore; then
	# Splore wants mouse/keys. Mapper is the pak process so a NextUI
	# kill ungrabs the Flip pad. Do not pass -joystick (dpad is buttons).
	killall -9 pico8-splore-pad 2>/dev/null || true
	if command -v pico8-splore-pad >/dev/null 2>&1; then
		exec pico8-splore-pad "./${STATIC_BIN}" \
			-home "$HOME_DIR" -root_path "$HOME_DIR/carts" -splore
	fi
	exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$HOME_DIR/carts" -splore
fi
exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick 0 -run "$ROM"
