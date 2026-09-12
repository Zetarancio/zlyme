#!/bin/sh
# NextUI calls this with auto|performance|powersave.
# auto uses the Settings governors (cpu_gov / gpu_gov), ROCKNIX-style.
mode=${1:-auto}
cpu_gov=schedutil
gpu_gov=simple_ondemand
case "$mode" in
	performance)
		cpu_gov=performance
		gpu_gov=performance
		;;
	powersave)
		cpu_gov=powersave
		gpu_gov=powersave
		;;
	auto)
		if command -v zlyme-ctl >/dev/null 2>&1; then
			c=$(zlyme-ctl get cpu_gov 2>/dev/null | tr -d ' \t\r\n')
			g=$(zlyme-ctl get gpu_gov 2>/dev/null | tr -d ' \t\r\n')
			case "$c" in
				performance|powersave|schedutil|ondemand) cpu_gov=$c ;;
			esac
			case "$g" in
				performance|powersave|simple_ondemand) gpu_gov=$g ;;
			esac
		fi
		;;
esac
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
	[ -w "$c" ] || continue
	echo "$cpu_gov" > "$c" 2>/dev/null || echo schedutil > "$c" 2>/dev/null || true
done
for g in /sys/class/devfreq/*.gpu/governor /sys/class/devfreq/*gpu*/governor; do
	[ -w "$g" ] || continue
	echo "$gpu_gov" > "$g" 2>/dev/null || echo simple_ondemand > "$g" 2>/dev/null || true
done
