#!/bin/sh
# PICO-8 binary is not redistributable. Look for pico8_64 next to carts.
GAME_DIR="/mnt/SDCARD/Roms/PICO-8"
STATIC_BIN="pico8_64"

if [ -x "${GAME_DIR}/aarch64/${STATIC_BIN}" ]; then
	LAUNCH_DIR="${GAME_DIR}/aarch64"
elif [ -x "${GAME_DIR}/${STATIC_BIN}" ]; then
	LAUNCH_DIR="${GAME_DIR}"
else
	echo "pico8: put ${STATIC_BIN} in ${GAME_DIR}" >&2
	exit 1
fi

chmod 0755 "${LAUNCH_DIR}/${STATIC_BIN}" 2>/dev/null || true

if echo "$1" | grep -qi splore; then
	OPTIONS="-splore"
	CART=""
else
	OPTIONS="-run"
	CART="$1"
fi

exec "${LAUNCH_DIR}/${STATIC_BIN}" -home -root_path "${GAME_DIR}" -joystick 0 ${OPTIONS} "${CART}"
