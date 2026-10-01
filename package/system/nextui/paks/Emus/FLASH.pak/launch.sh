#!/bin/sh
# Ruffle Handheld v4.2. The runtime stays on the read-only image.
# Companion data follows the SWF's library. The runtime stores it at
# $RUFFLE_ROM_ROOT/flash_data, so the rom root is the library Saves tree.
PAK_DIR="$(dirname "$0")"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=/usr/share/zlyme/rufflehandheld
mig=${ZLYME_MIGRATE_SH:-/usr/share/nextui/bin/zlyme-migrate-tree.sh}
if [ ! -r "$mig" ]; then
	_pak=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
	mig=$_pak/../../../zlyme/zlyme-migrate-tree.sh
fi
# shellcheck disable=SC1090
[ -r "$mig" ] && . "$mig"

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

saves=$library/Saves/FLASH
data=$saves/flash_data
# Game companion files stay on the library. Profiles and logs are app state.
cfg=${ZLYME_RUFFLE_CONFIG:-/storage/.config/ruffle}
if command -v zlyme_migrate_tree >/dev/null 2>&1; then
	zlyme_migrate_tree "$library/flash_data" "$data" || true
	zlyme_migrate_tree "$library/.config/zlyme/ruffle/data" "$data" || true
	zlyme_migrate_tree "$library/.config/zlyme/ruffle/flash" "$saves/flash" || true
fi

export RUFFLE_PERFORMANCE=0
export RUFFLE_CFW_NAME=nextui
export RUFFLE_ROM_ROOT=$saves
export RUFFLE_DATA_DIR=$data
export RUFFLE_FLASH_DIR=$saves/flash
export RUFFLE_AUX_LOG_DIR=$cfg/logs
export RUFFLE_BASH=/bin/bash
unset WAYLAND_DISPLAY
unset DISPLAY

if [ "${ZLYME_RUFFLE_DRY:-}" = 1 ]; then
	printf 'library=%s\n' "$library"
	printf 'data=%s\n' "$data"
	exit 0
fi

mkdir -p "$data" "$saves/flash" "$cfg/logs"
exec /bin/bash "$APP/runtime/entrypoint.sh" --rom-root "$saves" "$ROM"
