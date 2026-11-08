#!/bin/sh
# DSperate. Battery saves and states are its own directories.
# DraStic's NDS backup and savestate trees are not mounted or rewritten.
export SDL_TOUCH_MOUSE_EVENTS="${SDL_TOUCH_MOUSE_EVENTS:-0}"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi

ROM=${1-}
if [ -z "$ROM" ] || [ ! -f "$ROM" ] || [ -L "$ROM" ]; then
	echo "dsperate: rom missing" >&2
	exit 1
fi

card=${SDCARD_PATH:-/storage}
saves_root=${SAVES_PATH:-$card/Saves}
save_dir=$saves_root/NDS/dsperate
state_dir=$save_dir/states
cfg_home=${XDG_CONFIG_HOME:-$card/.config}
cfg_dir=$cfg_home/dsperate
cfg=$cfg_dir/dsperate.ini
bios=${BIOS_PATH:-$card/Bios}/NDS

mkdir -p "$save_dir" "$state_dir" "$cfg_dir" || exit 1

# An existing file is the user's. This seeds the upstream defaults once.
if [ ! -s "$cfg" ]; then
	dsperate --write-config "$cfg" || exit 1
fi

# --no-mic keeps capture off plughw:0,0. A guest that reads AUX would
# otherwise open that device beside SDL playback.
set -- --config "$cfg" --saves "$save_dir" --states "$state_dir" \
	--sink kms --no-gpu-present --no-gpu3d --no-mic
if [ -f "$bios/bios9.bin" ] && [ ! -L "$bios/bios9.bin" ]; then
	set -- "$@" --bios9 "$bios/bios9.bin"
fi
if [ -f "$bios/bios7.bin" ] && [ ! -L "$bios/bios7.bin" ]; then
	set -- "$@" --bios7 "$bios/bios7.bin"
fi
if [ -f "$bios/firmware.bin" ] && [ ! -L "$bios/firmware.bin" ]; then
	set -- "$@" --firmware "$bios/firmware.bin"
fi

exec dsperate "$ROM" "$@"
