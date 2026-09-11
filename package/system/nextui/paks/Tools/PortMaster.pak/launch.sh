#!/bin/sh
if [ ! -x /usr/bin/portmaster ]; then
	echo "PortMaster is not installed"
	sleep 1
	exit 0
fi
exec /usr/bin/portmaster
