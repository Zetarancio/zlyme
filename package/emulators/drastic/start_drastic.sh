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
# One-time. The old seed used the physical pad's button numbers
# (A=1025, B=1024, d-pad buttons 13-16). Leave a cfg that no longer
# matches that signature alone.
if [ -f "$CFGDIR/drastic.cfg" ] && ! grep -q '^zlyme_pad_abi = xb360' "$CFGDIR/drastic.cfg"; then
	if grep -q '^controls_b\[CONTROL_INDEX_A\] = 1025$' "$CFGDIR/drastic.cfg" && \
		grep -q '^controls_b\[CONTROL_INDEX_B\] = 1024$' "$CFGDIR/drastic.cfg" && \
		grep -q '^controls_b\[CONTROL_INDEX_UP\] = 1037$' "$CFGDIR/drastic.cfg"; then
		sed -i \
			-e 's/^controls_b\[CONTROL_INDEX_UP\] = 1037$/controls_b[CONTROL_INDEX_UP] = 2049/' \
			-e 's/^controls_b\[CONTROL_INDEX_DOWN\] = 1038$/controls_b[CONTROL_INDEX_DOWN] = 2052/' \
			-e 's/^controls_b\[CONTROL_INDEX_LEFT\] = 1039$/controls_b[CONTROL_INDEX_LEFT] = 2056/' \
			-e 's/^controls_b\[CONTROL_INDEX_RIGHT\] = 1040$/controls_b[CONTROL_INDEX_RIGHT] = 2050/' \
			-e 's/^controls_b\[CONTROL_INDEX_A\] = 1025$/controls_b[CONTROL_INDEX_A] = 1024/' \
			-e 's/^controls_b\[CONTROL_INDEX_B\] = 1024$/controls_b[CONTROL_INDEX_B] = 1025/' \
			-e 's/^controls_b\[CONTROL_INDEX_START\] = 1033$/controls_b[CONTROL_INDEX_START] = 1031/' \
			-e 's/^controls_b\[CONTROL_INDEX_SELECT\] = 1032$/controls_b[CONTROL_INDEX_SELECT] = 1030/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_UP\] = 1037$/controls_b[CONTROL_INDEX_UI_UP] = 2049/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_DOWN\] = 1038$/controls_b[CONTROL_INDEX_UI_DOWN] = 2052/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_LEFT\] = 1039$/controls_b[CONTROL_INDEX_UI_LEFT] = 2056/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_RIGHT\] = 1040$/controls_b[CONTROL_INDEX_UI_RIGHT] = 2050/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_SELECT\] = 1025$/controls_b[CONTROL_INDEX_UI_SELECT] = 1024/' \
			-e 's/^controls_b\[CONTROL_INDEX_UI_EXIT\] = 1024$/controls_b[CONTROL_INDEX_UI_EXIT] = 1025/' \
			-e 's/^controls_b\[CONTROL_INDEX_SWAP_ORIENTATION_A\] = 1030$/controls_b[CONTROL_INDEX_SWAP_ORIENTATION_A] = 65535/' \
			-e 's/^controls_b\[CONTROL_INDEX_SWAP_ORIENTATION_B\] = 1031$/controls_b[CONTROL_INDEX_SWAP_ORIENTATION_B] = 65535/' \
			"$CFGDIR/drastic.cfg"
		printf '%s\n' 'zlyme_pad_abi = xb360' | cat - "$CFGDIR/drastic.cfg" > "$CFGDIR/drastic.cfg.new"
		mv "$CFGDIR/drastic.cfg.new" "$CFGDIR/drastic.cfg"
	fi
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
