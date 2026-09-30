#!/bin/sh
# RK3566 Flip. Spruce smart stays on the NextUI list (2 cores, DMC 324).
# Light paks used to inherit that; GB + A2DP then underruns on USB/DDR.
# Games get play or heavy. NextUI calls smart again on return.
#
#   smart        NextUI list: 2 cores, schedutil 408-1800, DMC 324
#   play         Ports/GB/GBA/FC/Pico-8/Moonlight/most RA:
#                4 cores, schedutil 408-1800, DMC 528-1056
#   heavy        PSP/NDS/DC/N64/Saturn/PS2/GC/Wii: 4c, schedutil 1104-1800
#   performance  same as heavy (NextUI CPU_SPEED_PERFORMANCE)
#   overclock    1992 when zlyme-ctl boost is on (serial debug only)
#   idle         lid: 2 cores, conservative 408-1104, DMC 324
#   auto         smart
#   powersave    idle
#   emu <tag>    Spruce per-system CPU floor on the play profile.
#                No Spruce row: PS2/GC/Wii stay heavy; others stay play.
#
# CPU never uses ondemand. GPU/DMC stay simple_ondemand in-game.
# GPU sysfs is /sys/class/devfreq/*.gpu (panfrost or mali). DMC is not the GPU.
# Spruce scaling_min_freq is the requested minimum. The applied minimum is
# the lowest mainline OPP that is not below that request. ZLYME_GOVERNOR
# still replaces the whole mode, including emu.

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

# In-game. 4 cores + DMC headroom for combo USB / A2DP.
# $1 is the CPU minimum. Default 408000 is the old generic play floor.
profile_play() {
	min=${1:-408000}
	max=1800000
	if [ "$min" -gt "$max" ]; then
		min=$max
	fi
	set_boost 0
	online_all
	set_cpu_minmax "$min" "$max"
	set_cpu_gov schedutil
	set_dmc simple_ondemand 528000000 1056000000
	set_gpu simple_ondemand
}

# Known my355 OPPs. Used when sysfs does not list frequencies.
zlyme_known_freqs() {
	printf '%s\n' 408000 600000 816000 1104000 1416000 1608000 1800000 1992000
}

cpu_freq_list() {
	if [ -n "${ZLYME_CPU_FREQS:-}" ]; then
		printf '%s\n' $ZLYME_CPU_FREQS
		return 0
	fi
	avail=/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
	if [ -r "$avail" ]; then
		tr ' ' '\n' < "$avail"
		return 0
	fi
	zlyme_known_freqs
}

# Lowest listed frequency that is >= the Spruce request. Never rounds down.
resolve_floor() {
	req=$1
	best=
	for f in $(cpu_freq_list); do
		[ "$f" -ge "$req" ] 2>/dev/null || continue
		if [ -z "$best" ] || [ "$f" -lt "$best" ]; then
			best=$f
		fi
	done
	if [ -n "$best" ]; then
		printf '%s\n' "$best"
		return 0
	fi
	printf '%s\n' 1992000
}

# SpruceOS 2b7bc4a Emu/*/config.json scaling_min_freq, keyed by Zlyme tag.
# Names that differ: A26=ATARI, A5200=FIFTYTWOHUNDRED, A78=SEVENTYEIGHTHUNDRED,
# A800=EIGHTHUNDRED, INTV=INTELLIVISION, O2=ODYSSEY, P8=FAKE08, PICO=PICO8,
# PKM=POKE, SG1000=SEGASGONE, SGX=SGFX, ST=ATARIST, 32X=THIRTYTWOX, MAME=ARCADE.
spruce_floor() {
	tag=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
	case "$tag" in
		gb) printf '%s\n' 240000 ;;
		gbc|fc|a5200) printf '%s\n' 312000 ;;
		ms|gg|pce|ngp|a26|sg1000|vec|pkm|msx) printf '%s\n' 408000 ;;
		coleco|intv|lynx|o2|st|a78|a800|doom|easyrpg|p8) printf '%s\n' 480000 ;;
		md|ws|mkxpz|ports) printf '%s\n' 648000 ;;
		gba|sfc|vb|dos|pico|nds|scummvm|fbneo|mame|amiga|32x|sgx|tic) printf '%s\n' 816000 ;;
		ps|psp|n64|dc|saturn|openbor|neocd) printf '%s\n' 1008000 ;;
		*) return 1 ;;
	esac
}

# Systems Spruce does not ship. Keep the previous Zlyme class.
legacy_game_profile() {
	tag=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
	case "$tag" in
		ps2|gc|wii|gamecube) printf '%s\n' heavy ;;
		*) printf '%s\n' play ;;
	esac
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

# Heavy consoles. Floor 1104, not a locked performance governor.
profile_heavy() {
	online_all
	set_boost 0
	set_cpu_minmax 1104000 1800000
	set_cpu_gov schedutil
	set_dmc simple_ondemand 528000000 1056000000
	set_gpu simple_ondemand
}

profile_overclock() {
	online_all
	set_boost 1
	set_cpu_minmax 408000 1992000
	set_cpu_gov schedutil
	set_dmc simple_ondemand 324000000 1056000000
	set_gpu simple_ondemand
}

if [ "${1:-}" = "--resolve-floor" ]; then
	resolve_floor "${2:?floor}"
	exit 0
fi
if [ "${1:-}" = "--policy" ]; then
	tag=$(printf '%s' "${2:?tag}" | tr 'A-Z' 'a-z')
	if spruce=$(spruce_floor "$tag"); then
		printf 'spruce=%s effective=%s profile=spruce\n' \
			"$spruce" "$(resolve_floor "$spruce")"
	else
		printf 'spruce= effective= profile=%s\n' "$(legacy_game_profile "$tag")"
	fi
	exit 0
fi

mode=${ZLYME_GOVERNOR:-${1:-smart}}
case "$mode" in
	auto) mode=smart ;;
	powersave) mode=idle ;;
	emu)
		shift
		tag=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
		if spruce=$(spruce_floor "$tag"); then
			profile_play "$(resolve_floor "$spruce")"
			exit 0
		fi
		mode=$(legacy_game_profile "$tag")
		;;
esac
case "$mode" in
	performance|heavy)
		if boost_on; then
			mode=overclock
		else
			mode=heavy
		fi
		;;
esac

case "$mode" in
	smart) profile_smart ;;
	play) profile_play ;;
	idle) profile_idle ;;
	heavy) profile_heavy ;;
	overclock) profile_overclock ;;
	*) profile_smart ;;
esac
exit 0
