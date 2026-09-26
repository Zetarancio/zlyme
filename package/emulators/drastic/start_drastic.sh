#!/bin/sh
# Config stays on the OS card. Backup / savestate slots follow $library.
# Do not export LD_PRELOAD for mkdir/cp: libdrastouch needs SDL and
# breaks BusyBox if it is loaded for the setup commands.
export SDL_TOUCH_MOUSE_EVENTS="${SDL_TOUCH_MOUSE_EVENTS:-0}"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi

SDCARD="${SDCARD_PATH:-/storage}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD/.config}"
CFGDIR="$XDG_CONFIG_HOME/drastic"
SAVES="${SAVES_PATH:-$SDCARD/Saves}/NDS"
SEED=/usr/share/drastic/config/drastic.cfg
WORKDIR=/tmp/drastic-run

mkdir -p "$CFGDIR" "$SAVES/backup" "$SAVES/savestates"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/backup" "$WORKDIR/savestates"

if [ -f "$SEED" ] && [ ! -e "$CFGDIR/drastic.cfg" ]; then
	cp "$SEED" "$CFGDIR/drastic.cfg"
fi
if [ -f "$CFGDIR/drastic.cfg" ]; then
	cp "$CFGDIR/drastic.cfg" "$WORKDIR/drastic.cfg"
elif [ -f "$SEED" ]; then
	cp "$SEED" "$WORKDIR/drastic.cfg"
fi

BIN=
if [ -x /usr/bin/drastic ]; then
	BIN=/usr/bin/drastic
elif [ -x /usr/share/drastic/drastic ]; then
	BIN=/usr/share/drastic/drastic
fi
if [ -z "$BIN" ]; then
	echo "drastic: binary missing" >&2
	exit 1
fi
cp -f "$BIN" "$WORKDIR/drastic"
chmod 0755 "$WORKDIR/drastic"

mount --bind "$SAVES/backup" "$WORKDIR/backup" 2>/dev/null || ln -sfn "$SAVES/backup" "$WORKDIR/backup"
mount --bind "$SAVES/savestates" "$WORKDIR/savestates" 2>/dev/null || ln -sfn "$SAVES/savestates" "$WORKDIR/savestates"
cd "$WORKDIR" || exit 1
LD_PRELOAD="/usr/lib/libdrastouch.so" ./drastic "$@"
st=$?
cp -f "$WORKDIR/drastic.cfg" "$CFGDIR/drastic.cfg" 2>/dev/null || true
umount "$WORKDIR/backup" 2>/dev/null || true
umount "$WORKDIR/savestates" 2>/dev/null || true
exit $st
