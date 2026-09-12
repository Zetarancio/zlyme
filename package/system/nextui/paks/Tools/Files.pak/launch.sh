#!/bin/sh
msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" 3
	else
		sleep 2
	fi
}
if [ ! -x /usr/bin/vtree ]; then
	msg "vtree is not installed"
	exit 1
fi
sleep 0.4
exec /usr/bin/vtree
