#!/bin/sh
msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" 3
	else
		sleep 2
	fi
}
if [ ! -x /usr/bin/portmaster ]; then
	msg "PortMaster is not installed"
	exit 1
fi
exec /usr/bin/portmaster
