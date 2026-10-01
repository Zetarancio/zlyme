#!/bin/sh
# Ruffle Handheld v4.2. The runtime under /usr/share/zlyme is the
# pinned appliance. This script only sets paths, input, and clocks.
PAK_DIR="$(dirname "$0")"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=/usr/share/zlyme/rufflehandheld
SDCARD_PATH="${SDCARD_PATH:-/storage}"

if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
	echo "ruffle: no swf" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "No SWF selected" 3
	exit 1
fi
if [ ! -x "$APP/runtime/entrypoint.sh" ] && [ ! -f "$APP/runtime/entrypoint.sh" ]; then
	echo "ruffle: runtime missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "Ruffle is not installed" 3
	exit 1
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true

# Library root: .../Roms/Flash (RUFFLE)/game.swf -> the card root.
lib=$(CDPATH= cd -- "$(dirname -- "$ROM")/../.." && pwd)
state=$SDCARD_PATH/.config/zlyme/ruffle
mkdir -p "$state/logs" "$state/data" "$state/flash"

export RUFFLE_PERFORMANCE=0
export RUFFLE_CFW_NAME=nextui
export RUFFLE_DATA_DIR=$state/data
export RUFFLE_FLASH_DIR=$state/flash
export RUFFLE_AUX_LOG_DIR=$state/logs
export RUFFLE_BASH=/bin/bash
unset WAYLAND_DISPLAY
unset DISPLAY

exec /bin/bash "$APP/runtime/entrypoint.sh" --rom-root "$lib" "$ROM"
