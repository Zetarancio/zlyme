#!/bin/sh
if [ ! -x /usr/bin/moonlight ]; then
	echo "Moonlight is not installed"
	sleep 2
	exit 1
fi
exec moonlight
