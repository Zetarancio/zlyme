#!/bin/sh
# NextUI settings.elf calls $SYSTEM_PATH/etc/wifi/wifi_init.sh.
# Drive Zlyme wifi, not stock Miyoo RTL8189 / dhcpcd.
. /etc/zlyme.conf

case "$1" in
	start)
		zlyme-ctl set wifi on >/dev/null 2>&1 || true
		/etc/init.d/S30wifi start
		;;
	stop)
		/etc/init.d/S30wifi stop
		zlyme-ctl set wifi off >/dev/null 2>&1 || true
		;;
	*)
		echo "Usage: $0 {start|stop}" >&2
		exit 1
		;;
esac
