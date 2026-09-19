#!/bin/sh
# Save the kernel's Miyoo UART stick calibration to /storage and show it.
# The driver auto-cals ~10s after probe; sysfs is ROCKNIX 0003 (miyoo_cal_*).

# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" "${2:-3}"
	else
		sleep "${2:-2}"
	fi
}

SYS=/sys/devices/platform/rocknix-singleadc-joypad
if [ ! -f "$SYS/miyoo_cal_left" ]; then
	i=0
	while [ "$i" -lt 15 ]; do
		[ -f "$SYS/miyoo_cal_left" ] && break
		msg "Waiting for stick driver..." 1
		i=$((i + 1))
	done
fi

if [ ! -f "$SYS/miyoo_cal_left" ]; then
	msg "No cal sysfs (rebuild joypad)" 4
	exit 1
fi

if ! /usr/sbin/zlyme-joypad-cal save; then
	msg "Save failed" 3
	exit 1
fi

vals=$(/usr/sbin/zlyme-joypad-cal show 2>/dev/null || true)
msg "Saved ${vals:-ok}" 4
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
