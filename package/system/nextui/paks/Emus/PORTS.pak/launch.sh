#!/bin/sh
# PortMaster ports are scripts (or bins) under Roms/Ports (PORTS)/.
# Stock launchers source /roms/ports/PortMaster/control.txt (directory=roms)
# or /opt/system/Tools/PortMaster. Both are squashfs symlinks; refresh the
# lowercase fallback if that is the only folder on the card.
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
if [ -z "$ROM" ]; then
	echo "no port" >&2
	exit 1
fi
ports_dir="/storage/Roms/Ports (PORTS)"
if [ ! -d "$ports_dir" ] && [ -d /storage/Roms/ports ]; then
	ports_dir=/storage/Roms/ports
	ln -sfn "$ports_dir" /roms/ports 2>/dev/null || true
fi
export HM_PORTS_DIR="$ports_dir"
export CFW_NAME="${CFW_NAME:-ROCKNIX}"
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
