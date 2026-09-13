#!/bin/sh
# Spruce-like profiles for the Flip (RK3566).
#   smart        NextUI + light emus: schedutil, cores 01, DMC 324M
#   performance  PSP/NDS/DC/N64/SATURN/PORTS: 1800, cores 0123, DMC 1056M
#   overclock    same as performance at 1992 when CPU boost is on
#   idle         screen off: conservative, cores 01, DMC 324M
#   auto         smart (NextUI CPU_SPEED_AUTO)
#   powersave    idle
#   emu <tag>    pick smart vs performance from the core/pak name
#
# GPU sysfs is /sys/class/devfreq/*.gpu (panfrost or mali). DMC is not the GPU.

boost_on() {
	val=""
	if command -v zlyme-ctl >/dev/null 2>&1; then
		val=$(zlyme-ctl get boost 2>/dev/null | tr -d ' \t\r\n')
	fi
	[ "$val" = "on" ] || [ "$val" = "1" ] || [ "$val" = "yes" ]
}

sys_write() {
	path=$1
	val=$2
	[ -w "$path" ] || return 0
	printf '%s\n' "$val" > "$path" 2>/dev/null || true
}

online_all() {
	sys_write /sys/devices/system/cpu/cpu1/online 1
	sys_write /sys/devices/system/cpu/cpu2/online 1
	sys_write /sys/devices/system/cpu/cpu3/online 1
}

cores_two() {
	sys_write /sys/devices/system/cpu/cpu1/online 1
	sys_write /sys/devices/system/cpu/cpu3/online 0
	sys_write /sys/devices/system/cpu/cpu2/online 0
}

set_cpu_gov() {
	gov=$1
	for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
		sys_write "$c" "$gov"
		if [ "$(tr -d ' \n' < "$c" 2>/dev/null)" != "$gov" ]; then
			# conservative is new this kernel; fall back so idle still sips.
			case "$gov" in
				conservative) sys_write "$c" powersave ;;
				*) sys_write "$c" schedutil ;;
			esac
		fi
	done
}

set_cpu_minmax() {
	min=$1
	max=$2
	for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
		[ -d "$c" ] || continue
		curmax=$(tr -d ' \n' < "$c/scaling_max_freq" 2>/dev/null)
		curmin=$(tr -d ' \n' < "$c/scaling_min_freq" 2>/dev/null)
		# Raise max before min when going up; drop min before max when going down.
		if [ -n "$curmax" ] && [ "$max" -gt "$curmax" ] 2>/dev/null; then
			sys_write "$c/scaling_max_freq" "$max"
			sys_write "$c/scaling_min_freq" "$min"
		else
			sys_write "$c/scaling_min_freq" "$min"
			sys_write "$c/scaling_max_freq" "$max"
		fi
	done
}

set_boost() {
	on=$1
	for p in /sys/devices/system/cpu/cpufreq/boost \
		/sys/devices/system/cpu/cpu0/cpufreq/boost; do
		[ -w "$p" ] || continue
		sys_write "$p" "$on"
		return 0
	done
}

set_gpu() {
	gov=$1
	for g in /sys/class/devfreq/*.gpu /sys/class/devfreq/*gpu*; do
		[ -w "$g/governor" ] || continue
		sys_write "$g/governor" "$gov"
	done
}

set_dmc() {
	gov=$1
	min=$2
	max=$3
	for d in /sys/class/devfreq/dmc /sys/class/devfreq/*dmc*; do
		[ -d "$d" ] || continue
		[ -w "$d/governor" ] || continue
		curmax=$(tr -d ' \n' < "$d/max_freq" 2>/dev/null)
		if [ -n "$curmax" ] && [ "$max" -gt "$curmax" ] 2>/dev/null; then
			sys_write "$d/max_freq" "$max"
			sys_write "$d/min_freq" "$min"
		else
			sys_write "$d/min_freq" "$min"
			sys_write "$d/max_freq" "$max"
		fi
		sys_write "$d/governor" "$gov"
	done
}

profile_smart() {
	set_boost 0
	online_all
	set_cpu_minmax 408000 1800000
	set_cpu_gov schedutil
	cores_two
	set_dmc powersave 324000000 324000000
	set_gpu simple_ondemand
}

profile_idle() {
	set_boost 0
	online_all
	set_cpu_minmax 408000 1104000
	set_cpu_gov conservative
	cores_two
	set_dmc powersave 324000000 324000000
	set_gpu powersave
}

profile_performance() {
	online_all
	set_boost 0
	set_cpu_minmax 408000 1800000
	set_cpu_gov performance
	set_dmc simple_ondemand 324000000 1056000000
	set_gpu performance
}

profile_overclock() {
	online_all
	set_boost 1
	set_cpu_minmax 408000 1992000
	set_cpu_gov performance
	set_dmc simple_ondemand 324000000 1056000000
	set_gpu performance
}

is_heavy() {
	tag=$(printf '%s' "$*" | tr 'A-Z' 'a-z')
	case "$tag" in
		*ppsspp*|*psp*|*flycast*|*dreamcast*|*drastic*|*nds*|*melonds*|\
		*mupen*|*n64*|*yaba*|*saturn*|*ports*|*moonlight*)
			return 0
			;;
	esac
	return 1
}

mode=${1:-smart}
case "$mode" in
	auto) mode=smart ;;
	powersave) mode=idle ;;
	emu)
		shift
		if is_heavy "$@"; then
			if boost_on; then
				mode=overclock
			else
				mode=performance
			fi
		else
			mode=smart
		fi
		;;
	performance)
		if boost_on; then
			mode=overclock
		fi
		;;
esac

case "$mode" in
	smart) profile_smart ;;
	idle) profile_idle ;;
	performance) profile_performance ;;
	overclock) profile_overclock ;;
	*) profile_smart ;;
esac
exit 0
