#!/bin/sh
export LD_PRELOAD="/usr/lib/libdrastouch.so"
export SDL_TOUCH_MOUSE_EVENTS="${SDL_TOUCH_MOUSE_EVENTS:-0}"
SEED=/usr/share/drastic/config/drastic.cfg
CFGDIR="${XDG_CONFIG_HOME:-${HOME:-/storage/.config/nextui/my355}/.config}/drastic"
mkdir -p "$CFGDIR"
if [ -f "$SEED" ] && [ ! -e "$CFGDIR/drastic.cfg" ]; then
	cp "$SEED" "$CFGDIR/drastic.cfg"
fi
if [ -x /usr/bin/drastic ]; then
	exec /usr/bin/drastic "$@"
fi
if [ -x /usr/share/drastic/drastic ]; then
	cd /usr/share/drastic || exit 1
	exec ./drastic "$@"
fi
echo "drastic: binary missing" >&2
exit 1
