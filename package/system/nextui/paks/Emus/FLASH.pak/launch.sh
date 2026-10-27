#!/bin/sh
# Ruffle Handheld v4.2. The runtime stays on the read-only image.
# The ROM root is the library that holds the SWF, the same root the
# accepted launcher used. Companion data is the runtime's flash_data
# tree, stored with the library's other saves. The flash directory is
# the folder that already contains the SWF.
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

data=$library/Saves/FLASH/flash_data
flash=$(dirname "$ROM")
# Profiles stay in the config directory. The auxiliary log follows
# the system-logs switch and is not save data.
os=${ZLYME_STATE_ROOT:-/storage}
cfg=${ZLYME_RUFFLE_CONFIG:-$os/.config/ruffle}

export RUFFLE_PERFORMANCE=0
export RUFFLE_CFW_NAME=nextui
export RUFFLE_ROM_ROOT=$library
export RUFFLE_DATA_DIR=$data
export RUFFLE_FLASH_DIR=$flash
# Saves stay in RUFFLE_DATA_DIR. The auxiliary log is a diagnostic.
# Logs off keeps it on tmpfs so the config directory is not a log.
if [ -n "${ZLYME_PAK_LOG:-}" ]; then
	export RUFFLE_AUX_LOG_DIR=$cfg/logs
else
	export RUFFLE_AUX_LOG_DIR=${ZLYME_RUFFLE_LOG:-/tmp/zlyme-ruffle/logs}
fi
export RUFFLE_BASH=/bin/bash
unset WAYLAND_DISPLAY
unset DISPLAY

if [ "${ZLYME_RUFFLE_DRY:-}" = 1 ]; then
	printf 'library=%s\n' "$library"
	printf 'rom=%s\n' "$ROM"
	printf 'romroot=%s\n' "$RUFFLE_ROM_ROOT"
	printf 'flash=%s\n' "$RUFFLE_FLASH_DIR"
	printf 'data=%s\n' "$data"
	exit 0
fi

# The image links rufflehandheld/logs at $cfg/logs. The runtime
# mkdir's that path and exits if the symlink is dangling. Create the
# directory either way. The auxiliary files follow RUFFLE_AUX_LOG_DIR,
# which is tmpfs while system logs are off.
mkdir -p "$data" "$cfg/logs" "$RUFFLE_AUX_LOG_DIR"
# Previous run's auxiliary logs. The save tree is RUFFLE_DATA_DIR.
if [ -n "${ZLYME_PAK_LOG:-}" ]; then
	for _rf in "$RUFFLE_AUX_LOG_DIR"/*; do
		[ -f "$_rf" ] || continue
		[ ! -L "$_rf" ] || continue
		_rfsz=$(wc -c < "$_rf" 2>/dev/null) || continue
		_rfsz=$(printf '%s\n' "$_rfsz" | tr -d ' ')
		if [ "$_rfsz" -gt 1048576 ]; then
			_rftmp=$(mktemp "${_rf}.trim.XXXXXX") || continue
			if tail -c 1048576 "$_rf" > "$_rftmp"; then
				mv -f "$_rftmp" "$_rf"
			else
				rm -f "$_rftmp"
			fi
		fi
	done
	unset _rf _rfsz _rftmp
fi
/bin/bash "$APP/runtime/entrypoint.sh" --rom-root "$library" "$ROM"
rc=$?
# The frozen save helper used to mkdir $ROMROOT/flash_data. If that
# directory was created empty, drop it. Never delete a directory that
# still has contents.
rmdir "$library/flash_data" 2>/dev/null || true
if [ "$library" != /storage ]; then
	rmdir /storage/flash_data 2>/dev/null || true
fi
exit "$rc"
