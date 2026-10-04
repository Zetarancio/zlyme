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
#   overclock    1992 when ZLYME_CPU_BOOST=1 (serial debug only)
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

# The product boost setting is gone. An old flag file is ignored.
# ZLYME_CPU_BOOST=1 remains a serial-debug request for the 1992 profile.
boost_on() {
	[ "${ZLYME_CPU_BOOST:-}" = 1 ]
}

# One apply at a time, so a late DMC resume cannot land Smart over a
# profile the launcher just wrote. The lock is a regular file. The
# owner PID is written privately and published with ln, so another
# caller cannot see an empty lock and delete it. Resume re-execs this
# script; the new image trusts the lock only when it still names this
# PID. A signal exits instead of dropping the lock and applying further.
gov_role=none
gov_lock=${ZLYME_GOVERNOR_LOCK:-/run/zlyme/governor.lock}

gov_lock_owner() {
	[ -f "$gov_lock" ] || return 1
	[ -d "$gov_lock" ] && return 1
	pid=$(tr -d ' \t\r\n' < "$gov_lock" 2>/dev/null) || return 1
	[ -n "$pid" ] || return 1
	printf '%s\n' "$pid"
}

gov_numeric_pid() {
	case "$1" in
		''|*[!0-9]*) return 1 ;;
	esac
	return 0
}

gov_owner_alive() {
	gov_numeric_pid "$1" || return 1
	kill -0 "$1" 2>/dev/null
}

gov_reclaim_dead() {
	want=$1
	gov_numeric_pid "$want" || return 1
	aside="${gov_lock}.stale.$$"
	rm -f "$aside"
	mv "$gov_lock" "$aside" 2>/dev/null || return 1
	cur=$(tr -d ' \t\r\n' < "$aside" 2>/dev/null || true)
	if [ "$cur" = "$want" ] && ! gov_owner_alive "$want"; then
		rm -f "$aside"
		return 0
	fi
	if [ ! -e "$gov_lock" ]; then
		mv "$aside" "$gov_lock" 2>/dev/null || rm -f "$aside"
	else
		rm -f "$aside"
	fi
	return 1
}

gov_lock_cleanup() {
	status=$?
	trap - EXIT INT TERM HUP
	if [ "$gov_role" != owner ]; then
		exit "$status"
	fi
	gov_role=closed
	cur=$(gov_lock_owner || true)
	if [ "$cur" = "$$" ]; then
		rm -f "$gov_lock"
	fi
	exit "$status"
}

gov_lock_traps() {
	trap gov_lock_cleanup EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'exit 129' HUP
}

gov_lock_fail() {
	echo "zlyme-governor: $*" >&2
	exit 1
}

gov_lock_acquire() {
	gov_lock=${ZLYME_GOVERNOR_LOCK:-/run/zlyme/governor.lock}
	export ZLYME_GOVERNOR_LOCK=$gov_lock
	if [ "${ZLYME_GOVERNOR_LOCKED:-}" = 1 ]; then
		cur=$(gov_lock_owner || true)
		if [ "$cur" != "$$" ]; then
			gov_lock_fail "inherited lock is not pid $$"
		fi
		gov_role=owner
		gov_lock_traps
		return 0
	fi
	if [ -d "$gov_lock" ]; then
		gov_lock_fail "lock is not a PID file"
	fi
	mkdir -p "$(dirname "$gov_lock")" 2>/dev/null || true
	n=0
	limit=${ZLYME_GOVERNOR_LOCK_TRIES:-50}
	while true; do
		if [ -d "$gov_lock" ]; then
			gov_lock_fail "lock is not a PID file"
		fi
		tmp="${gov_lock}.$$"
		rm -f "$tmp"
		if ! printf '%s\n' "$$" > "$tmp"; then
			rm -f "$tmp"
			gov_lock_fail "could not record the lock owner"
		fi
		if ln "$tmp" "$gov_lock" 2>/dev/null && [ -f "$gov_lock" ]; then
			owned=$(gov_lock_owner || true)
			rm -f "$tmp"
			if [ "$owned" = "$$" ]; then
				export ZLYME_GOVERNOR_LOCKED=1
				gov_role=owner
				gov_lock_traps
				return 0
			fi
		fi
		rm -f "$tmp"
		op=$(gov_lock_owner || true)
		if ! gov_numeric_pid "$op"; then
			gov_lock_fail "lock is malformed"
		fi
		if ! gov_owner_alive "$op"; then
			gov_reclaim_dead "$op" || true
			n=$((n + 1))
			if [ "$n" -gt "$limit" ]; then
				gov_lock_fail "lock is stale and could not be cleared"
			fi
			continue
		fi
		n=$((n + 1))
		if [ "$n" -gt "$limit" ]; then
			gov_lock_fail "lock busy"
		fi
		sleep 0.1
	done
}

remember_profile() {
	case "$1" in
		idle|resume|"") return 0 ;;
	esac
	file=${ZLYME_GOVERNOR_PROFILE:-/run/zlyme/governor.profile}
	mkdir -p "$(dirname "$file")" 2>/dev/null || true
	printf '%s\n' "$1" > "$file" 2>/dev/null || true
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

gov_lock_acquire

mode=${ZLYME_GOVERNOR:-${1:-smart}}
case "$mode" in
	auto) mode=smart ;;
	powersave) mode=idle ;;
	resume)
		# Keep the space in "emu <tag>". Stripping all whitespace
		# would turn that record into a single token and fall back
		# to smart over a running game.
		profile=${ZLYME_GOVERNOR_PROFILE:-/run/zlyme/governor.profile}
		saved=
		if [ -f "$profile" ]; then
			IFS= read -r saved < "$profile" || saved=
		fi
		case "$saved" in
			smart|play|heavy|performance|overclock|auto|powersave)
				exec "$0" "$saved"
				;;
			emu\ *)
				tag=${saved#emu }
				case "$tag" in
					*[!A-Za-z0-9]*|"") exec "$0" smart ;;
					*) exec "$0" emu "$tag" ;;
				esac
				;;
			*)
				exec "$0" smart
				;;
		esac
		;;
	emu)
		shift
		tag=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
		remember_profile "emu $tag"
		if [ "${ZLYME_GOVERNOR_DRY:-}" = 1 ]; then
			printf '%s\n' "emu $tag"
			exit 0
		fi
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

remember_profile "$mode"
# Test seam. A signal during this hold must exit with the lock still
# covering the apply, not drop the lock and continue into the profile.
if [ -n "${ZLYME_GOVERNOR_HOLD:-}" ]; then
	sleep "$ZLYME_GOVERNOR_HOLD"
fi
if [ -n "${ZLYME_GOVERNOR_MARK:-}" ]; then
	printf '%s\n' "$mode" >> "$ZLYME_GOVERNOR_MARK"
fi
if [ "${ZLYME_GOVERNOR_DRY:-}" = 1 ]; then
	printf '%s\n' "$mode"
	exit 0
fi

case "$mode" in
	smart) profile_smart ;;
	play) profile_play ;;
	idle) profile_idle ;;
	heavy) profile_heavy ;;
	overclock) profile_overclock ;;
	*) profile_smart ;;
esac
exit 0
