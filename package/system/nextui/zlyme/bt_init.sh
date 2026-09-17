#!/bin/sh
# NextUI settings.elf calls $SYSTEM_PATH/etc/bluetooth/bt_init.sh.
# RTL8733BU is btusb after WiFi, not stock rtk_btusb / hciattach ttyS1.
# No timeout applet: dbus-send for Powered/Pairable, persistent agent.
. /etc/zlyme.conf

start_bt() {
	zlyme-ctl set bluetooth on >/dev/null 2>&1 || true
	[ -x /etc/init.d/S35btusb ] && /etc/init.d/S35btusb start
	[ -x /etc/init.d/S40bluetoothd ] && /etc/init.d/S40bluetoothd start
	[ -x /etc/init.d/S45bluealsa ] && /etc/init.d/S45bluealsa start
	[ -x /etc/init.d/S46btsink ] && /etc/init.d/S46btsink start
	[ -x /usr/sbin/zlyme-bluetooth ] && /usr/sbin/zlyme-bluetooth adapter-on
	[ -x /usr/sbin/zlyme-bluetooth ] && /usr/sbin/zlyme-bluetooth agent
}

stop_bt() {
	killall -9 bluetoothctl >/dev/null 2>&1 || true
	[ -x /usr/sbin/zlyme-bluetooth ] && /usr/sbin/zlyme-bluetooth adapter-off
	[ -x /usr/sbin/zlyme-bluetooth ] && /usr/sbin/zlyme-bluetooth save
	[ -x /etc/init.d/S45bluealsa ] && /etc/init.d/S45bluealsa stop
	[ -x /etc/init.d/S40bluetoothd ] && /etc/init.d/S40bluetoothd stop
	[ -x /etc/init.d/S35btusb ] && /etc/init.d/S35btusb stop
	zlyme-ctl set bluetooth off >/dev/null 2>&1 || true
}

case "$1" in
	start) start_bt ;;
	stop) stop_bt ;;
	restart) stop_bt; start_bt ;;
	*) echo "Usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
