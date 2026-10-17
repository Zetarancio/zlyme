#!/bin/sh
# Read-only Phase 14H observations. Safe on a live SSH session:
# no Wi-Fi change, no modeset, no process kill, no /boot remount.
set -eu

say() {
	printf '%s\n' "$*"
}

say "-- identity"
if [ -r /etc/os-release ]; then
	. /etc/os-release
	say "name=${NAME:-} version=${VERSION:-} device=${HW_DEVICE:-}"
fi
say "kernel=$(uname -r)"
if [ -r /proc/device-tree/chosen/u-boot,version ]; then
	printf 'uboot='
	tr -d '\0' < /proc/device-tree/chosen/u-boot,version
	printf '\n'
fi
say "-- boot"
grep ' /boot ' /proc/mounts || say "boot not mounted"
if [ -f /boot/zlyme ]; then
	sha256sum /boot/zlyme
fi
ls /boot/*.dtb 2>/dev/null || true
say "-- processes"
ps | awk '/nextui|inputplumber|sshd|smbd|syncthing/ && !/awk/ { print }'
say "-- gpu and display files"
if [ -f /storage/.config/zlyme/gpu ]; then
	printf 'gpu='; cat /storage/.config/zlyme/gpu; printf '\n'
else
	say "gpu file absent"
fi
if [ -f /storage/.config/zlyme/display_mode ]; then
	printf 'display_mode='; cat /storage/.config/zlyme/display_mode; printf '\n'
else
	say "display_mode absent"
fi
say "-- drm"
for dir in /sys/class/drm/card*-*; do
	[ -d "$dir" ] || continue
	name=$(basename "$dir")
	printf '%s status=%s enabled=%s mode=' "$name" \
		"$(cat "$dir/status" 2>/dev/null)" \
		"$(cat "$dir/enabled" 2>/dev/null)"
	cat "$dir/mode" 2>/dev/null || true
	printf '\n'
	say "modes:"
	cat "$dir/modes" 2>/dev/null || true
done
if [ -r /sys/kernel/debug/dri/0/state ]; then
	say "-- debugfs"
	awk '/clock|mode|crtc|connector/ { print }' /sys/kernel/debug/dri/0/state | head -40
else
	say "debugfs dri state not mounted"
fi
say "-- session hdmi"
pid=$(pidof nextui.elf 2>/dev/null || true)
if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
	tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(ZLYME_HDMI|SDL_VIDEODRIVER)=' || say "no hdmi env"
fi
if [ -x /usr/bin/zlyme-hdmi ]; then
	say "-- policy query, no modeset"
	ZLYME_HDMI_720P=1 /usr/bin/zlyme-hdmi export || say "hdmi query failed"
fi
say "-- artbook"
if [ -d /usr/share/nextui/artbook ]; then
	find /usr/share/nextui/artbook -name '*.png' | wc -l
	ls /usr/share/nextui/artbook/special 2>/dev/null || true
fi
say "-- armhf"
ls -l /lib/ld-linux-armhf.so.3 /usr/lib/zlyme-armhf/libc.so.6 2>&1 || true
say "-- libraries"
ls /usr/lib/libSDL2-2.0.so.0 /usr/lib/libSDL3.so.0 2>&1 || true
say "done"
