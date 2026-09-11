#!/bin/sh
# NextUI calls this with auto|performance|powersave.
mode=${1:-auto}
gov=schedutil
case "$mode" in
	performance) gov=performance ;;
	powersave) gov=powersave ;;
esac
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
	[ -w "$c" ] || continue
	echo "$gov" > "$c" 2>/dev/null || echo ondemand > "$c" 2>/dev/null || true
done
