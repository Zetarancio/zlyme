#!/bin/sh
# Music Player v1.17.0. The binary stays on the read-only image.
# Application state is /storage/.config/music-player. Music and podcasts
# stay user media. Clocks belong to zlyme-governor. The in-app updater
# stays off; Zlyme OTA owns this binary.
PAK_DIR="$(dirname "$0")"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=/usr/lib/zlyme/music-player/musicplayer.elf
root=${ZLYME_STATE_ROOT:-${SDCARD_PATH:-/storage}}
SDCARD_PATH=$root
state=$root/.config/music-player

if [ "${ZLYME_MUSIC_DRY:-}" != 1 ] && [ ! -x "$APP" ]; then
	echo "music-player: missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "Music Player is not installed" 3
	exit 1
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true

mkdir -p "$state" "$root/Music" "$root/Podcasts" "$state/helpers"
cfg=$state/settings.cfg
if [ -f "$cfg" ]; then
	grep -v '^auto_update=' "$cfg" > "$cfg.zlyme" || true
else
	: > "$cfg.zlyme"
fi
printf '%s\n' 'auto_update=0' >> "$cfg.zlyme"
mv -f "$cfg.zlyme" "$cfg"
rm -f /tmp/nextui-music-player.restart

if [ "${ZLYME_MUSIC_DRY:-}" = 1 ]; then
	printf 'state=%s\n' "$state"
	exit 0
fi

if [ ! -e /mnt/SDCARD ]; then
	mkdir -p /mnt
	ln -sfn "$SDCARD_PATH" /mnt/SDCARD
fi

export SDCARD_PATH
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
exec "$APP"
