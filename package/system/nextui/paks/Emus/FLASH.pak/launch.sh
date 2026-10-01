#!/bin/sh
# Ruffle Handheld v4.2. The runtime stays on the read-only image.
# The library that holds the SWF owns companion data.
PAK_DIR="$(dirname "$0")"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=/usr/share/zlyme/rufflehandheld

if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
	echo "ruffle: no swf" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "No SWF selected" 3
	exit 1
fi
if [ "${ZLYME_RUFFLE_DRY:-}" != 1 ] && [ ! -f "$APP/runtime/entrypoint.sh" ]; then
	echo "ruffle: runtime missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "Ruffle is not installed" 3
	exit 1
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true

if [ -z "${library:-}" ]; then
	libsh=${ZLYME_LIBRARY_SH:-/usr/share/nextui/bin/zlyme-library.sh}
	if [ -r "$libsh" ]; then
		# shellcheck disable=SC1090
		. "$libsh"
		library=$(zlyme_library_root "$ROM")
	fi
fi
[ -n "${library:-}" ] || library=/storage
state=$library/.config/zlyme/ruffle
export RUFFLE_PERFORMANCE=0
export RUFFLE_CFW_NAME=nextui
export RUFFLE_ROM_ROOT=$library
export RUFFLE_DATA_DIR=$state/data
export RUFFLE_FLASH_DIR=$state/flash
export RUFFLE_AUX_LOG_DIR=$state/logs
export RUFFLE_BASH=/bin/bash
unset WAYLAND_DISPLAY
unset DISPLAY

if [ "${ZLYME_RUFFLE_DRY:-}" = 1 ]; then
	printf 'library=%s\n' "$library"
	printf 'data=%s\n' "$RUFFLE_DATA_DIR"
	exit 0
fi

mkdir -p "$state/logs" "$state/data" "$state/flash" \
	/storage/.config/zlyme/ruffle/logs
exec /bin/bash "$APP/runtime/entrypoint.sh" --rom-root "$library" "$ROM"
