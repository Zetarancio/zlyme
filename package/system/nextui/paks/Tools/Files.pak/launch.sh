#!/bin/sh
if [ ! -x /usr/bin/vtree ]; then
	echo "vtree is not installed"
	sleep 2
	exit 1
fi
exec /usr/bin/vtree
