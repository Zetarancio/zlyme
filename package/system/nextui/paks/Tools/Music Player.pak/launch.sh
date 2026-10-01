#!/bin/sh
# Music Player v1.17.0. The binary stays on the read-only image.
# Clocks belong to zlyme-governor. The restart flag is ignored so an
# in-app download cannot replace the shipped player.
PAK_DIR="$(dirname "$0")"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=/usr/lib/zlyme/music-player/musicplayer.elf
SDCARD_PATH="${SDCARD_PATH:-/storage}"
LIB=/usr/lib/zlyme/music-player

if [ ! -x "$APP" ]; then
	echo "music-player: missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "Music Player is not installed" 3
	exit 1
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true

if [ ! -e /mnt/SDCARD ]; then
	mkdir -p /mnt
	ln -sfn "$SDCARD_PATH" /mnt/SDCARD
fi

cfg=$SDCARD_PATH/.userdata/shared/music-player/settings.cfg
mkdir -p "$(dirname "$cfg")" "$SDCARD_PATH/Music" \
	"$SDCARD_PATH/.userdata/shared/music-player/playlists"
if [ -f "$cfg" ]; then
	grep -v '^auto_update=' "$cfg" > "$cfg.zlyme" || true
else
	: > "$cfg.zlyme"
fi
printf '%s\n' 'auto_update=0' >> "$cfg.zlyme"
mv -f "$cfg.zlyme" "$cfg"
rm -f /tmp/nextui-music-player.restart

export LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SDCARD_PATH
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
exec "$APP"
