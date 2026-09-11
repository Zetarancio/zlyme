#!/bin/sh
# NextUI settings.elf calls $SYSTEM_PATH/etc/bluetooth/bt_init.sh.
# RTL8733BU is btusb after WiFi, not stock rtk_btusb / hciattach ttyS1.
. /etc/zlyme.conf

start_bt() {
	zlyme-ctl set bluetooth on >/dev/null 2>&1 || true
	[ -x /etc/init.d/S35btusb ] && /etc/init.d/S35btusb start
	[ -x /etc/init.d/S40bluetoothd ] && /etc/init.d/S40bluetoothd start
	[ -x /etc/init.d/S45bluealsa ] && /etc/init.d/S45bluealsa start
	if command -v bluetoothctl >/dev/null 2>&1; then
		timeout 5 bluetoothctl power on >/dev/null 2>&1 || true
		timeout 5 bluetoothctl pairable on >/dev/null 2>&1 || true
		timeout 5 bluetoothctl agent NoInputNoOutput >/dev/null 2>&1 || true
		timeout 5 bluetoothctl default-agent >/dev/null 2>&1 || true
		timeout 5 bluetoothctl system-alias "Miyoo Flip" >/dev/null 2>&1 || true
	fi
}

stop_bt() {
	if command -v bluetoothctl >/dev/null 2>&1; then
		timeout 5 bluetoothctl power off >/dev/null 2>&1 || true
	fi
	[ -x /etc/init.d/S45bluealsa ] && /etc/init.d/S45bluealsa stop
	[ -x /etc/init.d/S40bluetoothd ] && /etc/init.d/S40bluetoothd stop
	zlyme-ctl set bluetooth off >/dev/null 2>&1 || true
}

case "$1" in
	start) start_bt ;;
	stop) stop_bt ;;
	restart) stop_bt; start_bt ;;
	*) echo "Usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
