#!/bin/sh
# PortMaster ports are scripts (or bins) under Roms/Ports (PORTS)/.
# Bind /roms/ports to that volume for this launch only. HOME/XDG stay OS.
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
if [ -z "$ROM" ]; then
	echo "no port" >&2
	exit 1
fi
if [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
	. /usr/share/nextui/bin/zlyme-library.sh
	zlyme_ports_bind "$ROM"
	trap zlyme_ports_unbind EXIT
fi
export CFW_NAME=Zlyme
export DEVICE_NAME="${DEVICE_NAME:-Miyoo Flip}"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
case "$ROM" in
	*.sh)
		if command -v bash >/dev/null 2>&1; then
			exec bash "$ROM"
		fi
		exec sh "$ROM"
		;;
	*) exec "$ROM" ;;
esac
