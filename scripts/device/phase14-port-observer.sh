#!/bin/sh
# Passive, bounded observer for one normal NextUI/PortMaster launch.
# It does not start, signal, mount, unmount, or inject input.
set -eu

duration=${1:-120}
interval=${2:-1}
case "$duration:$interval" in
	*[!0-9:]* | :* | *:) echo "usage: $0 [duration-seconds [interval-seconds]]" >&2; exit 2 ;;
esac
if [ "$duration" -lt 1 ] || [ "$duration" -gt 300 ]; then
	echo "phase14 observer: duration must be 1..300 seconds" >&2
	exit 2
fi
if [ "$interval" -lt 1 ] || [ "$interval" -gt 10 ]; then
	echo "phase14 observer: interval must be 1..10 seconds" >&2
	exit 2
fi

stamp() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

proc_snapshot() {
	observed_pids=
	for stat in /proc/[0-9]*/stat; do
		[ -r "$stat" ] || continue
		pid=${stat#/proc/}
		pid=${pid%/stat}
		cmd=
		if [ -r "/proc/$pid/cmdline" ]; then
			cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
		fi
		cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
		case "$cmd:$cwd" in
			*nextui* | *PortMaster* | *harbourmaster* | *gptokeyb* | \
			*zlyme-pak* | *box86* | *box64* | *wine* | *weston* | \
			*love.* | *ags* | *frt* | *mkxp* | *gmloader* | *openal* | \
			*abombniball* | *retroarch* | */roms/ports/* | */Roms/Ports/* | \
			*/var/port/*)
				observed_pids="$observed_pids $pid"
				# comm can contain spaces and ')'; parse fields after its last ')'.
				line=$(cat "$stat" 2>/dev/null || true)
				rest=${line##*) }
				[ "$rest" != "$line" ] || continue
				# state ppid pgrp session ... starttime is field 20 here.
				# shellcheck disable=SC2086
				set -- $rest
				[ "$#" -ge 20 ] || continue
				printf 'PROC pid=%s state=%s ppid=%s pgid=%s sid=%s start=%s cwd=%s cmd=%s\n' \
					"$pid" "$1" "$2" "$3" "$4" "${20}" "$cwd" "$cmd"
				;;
		esac
	done
}

drm_snapshot() {
	if [ -r /sys/kernel/debug/dri/0/clients ]; then
		awk '{ print "DRM_CLIENT " $0 }' /sys/kernel/debug/dri/0/clients
		client_pids=$(awk 'NR > 1 && $3 ~ /^[0-9]+$/ { print $3 }' \
			/sys/kernel/debug/dri/0/clients | sort -u)
	else
		echo "DRM_CLIENTS unavailable"
		client_pids=$observed_pids
	fi
	for pid in $client_pids; do
		for fd in /proc/"$pid"/fd/*; do
		[ -L "$fd" ] || continue
		target=$(readlink "$fd" 2>/dev/null || true)
		case "$target" in
			/dev/dri/card* | /dev/dri/render*)
				pid=${fd#/proc/}
				pid=${pid%%/*}
				printf 'DRM pid=%s fd=%s node=%s\n' "$pid" "${fd##*/}" "$target"
				;;
		esac
		done
	done
}

mount_snapshot() {
	[ -r /proc/self/mountinfo ] || {
		echo "MOUNTINFO unreadable"
		return
	}
	awk '
		/ - squashfs / ||
		$0 ~ /\/var\/port(\/| )/ ||
		$0 ~ /\/roms(\/| )/ ||
		$0 ~ /\/PortMaster(\/| )/ ||
		$0 ~ /\/weston(\/| )/ {
			print "MOUNT " $0
		}
	' /proc/self/mountinfo
}

printf 'PHASE14_OBSERVER format=1 start=%s duration=%s interval=%s\n' \
	"$(stamp)" "$duration" "$interval"
if [ -r /etc/os-release ]; then
	(
		# shellcheck disable=SC1091
		. /etc/os-release
		printf 'IDENTITY name=%s version=%s device=%s\n' \
			"${NAME:-}" "${VERSION:-}" "${HW_DEVICE:-}"
	)
fi
printf 'IDENTITY kernel=%s boot_id=' "$(uname -r)"
cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown
if [ -r /boot/zlyme ]; then
	printf 'IDENTITY squashfs_sha256='
	sha256sum /boot/zlyme | awk '{print $1}'
fi

start_epoch=$(date +%s)
end_epoch=$((start_epoch + duration))
while :; do
	now=$(date +%s)
	elapsed=$((now - start_epoch))
	printf 'SAMPLE elapsed=%s time=%s\n' "$elapsed" "$(stamp)"
	proc_snapshot
	drm_snapshot
	mount_snapshot
	if [ -r /sys/kernel/debug/dri/0/state ]; then
		awk '
			/^[[:space:]]*crtc\[/ ||
			/^[[:space:]]*enable=/ ||
			/^[[:space:]]*active=/ ||
			/^[[:space:]]*mode:/ ||
			/^[[:space:]]*clock=/ ||
			/^[[:space:]]*connector\[/ {
				print "KMS " $0
			}
		' /sys/kernel/debug/dri/0/state
	else
		echo "KMS state-unavailable"
	fi
	now=$(date +%s)
	[ "$now" -ge "$end_epoch" ] && break
	sleep_for=$interval
	if [ $((now + sleep_for)) -gt "$end_epoch" ]; then
		sleep_for=$((end_epoch - now))
	fi
	sleep "$sleep_for"
done
printf 'PHASE14_OBSERVER end=%s\n' "$(stamp)"
