#!/bin/sh
# Read-only Phase 14H observations. Safe on a live SSH session:
# no Wi-Fi change, no modeset, no process kill, no /boot remount.
set -eu

say() {
	printf '%s\n' "$*"
}

say "-- identity"
if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
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
	awk '/clock|mode|crtc|connector/ {
		print
		shown++
		if (shown == 40)
			exit
	}' /sys/kernel/debug/dri/0/state
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
for file in /usr/bin/box86 /usr/bin/box64; do
	[ -x "$file" ] || continue
	if command -v readelf >/dev/null 2>&1; then
		readelf -h "$file" 2>/dev/null |
			awk -v file="$file" '/Class:|Machine:|Flags:/ { print file ": " $0 }'
		readelf -l "$file" 2>/dev/null |
			awk -v file="$file" '/Requesting program interpreter/ { print file ": " $0 }'
	else
		class=$(od -An -t u1 -j 4 -N 1 "$file" 2>/dev/null | tr -d ' ')
		machine=$(od -An -t u2 -j 18 -N 2 "$file" 2>/dev/null | tr -d ' ')
		printf '%s: elf_class=%s machine=%s\n' "$file" "$class" "$machine"
	fi
done
say "-- libraries"
ls /usr/lib/libSDL2-2.0.so.0 /usr/lib/libSDL3.so.0 \
	/usr/lib/portmaster/gl4es/aarch64/libGL.so.1 \
	/usr/lib/zlyme-armhf/gl4es/libGL.so.1 2>&1 || true
say "-- portmaster"
if [ -x /usr/sbin/zlyme-portmaster-root ]; then
	root=$(/usr/sbin/zlyme-portmaster-root get 2>/dev/null || true)
	printf 'selected_root=%s\n' "$root"
	if [ -n "$root" ]; then
		pm="$root/Roms/.portmaster"
		for file in "$pm"/version "$pm"/control.txt "$pm"/device_info.txt; do
			[ -r "$file" ] || continue
			printf 'file=%s\n' "$file"
			case "$file" in
				*/control.txt | */device_info.txt)
					grep -E '^(CFW_NAME|DEVICE_ARCH|DEVICE_HAS_ARMHF|PORTMASTER_VERSION)=' \
						"$file" 2>/dev/null || true
					;;
				*) cat "$file" ;;
			esac
		done
		find "$pm/runtimes" "$pm/libs" -maxdepth 2 -type f \
			2>/dev/null | sort
	fi
fi
say "-- compatibility mounts"
awk '
	/ - squashfs / ||
	$0 ~ /\/var\/port(\/| )/ ||
	$0 ~ /\/roms(\/| )/ ||
	$0 ~ /\/PortMaster(\/| )/ ||
	$0 ~ /\/weston(\/| )/ { print }
' /proc/self/mountinfo
say "done"
