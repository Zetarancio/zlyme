#!/bin/sh
# Which library root a ROM lives on. Sourced by paks (via pak-log.sh)
# or invoked as: zlyme-library {root|for} <path>
#
# Sets: library, BIOS_PATH, SAVES_PATH, ZLYME_GOVERNOR, ZLYME_EMU_CORE
# HOME / XDG stay whatever the session exported (OS card).

ZLYME_PREFS="${SHARED_USERDATA_PATH:-/storage/.config/nextui/shared}/zlyme-prefs.txt"

zlyme_library_root() {
	p=$1
	libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
	best=
	if [ -r "$libs" ]; then
		while IFS= read -r root || [ -n "$root" ]; do
			[ -n "$root" ] || continue
			case "$p" in
				"$root"|"$root"/*)
					if [ "${#root}" -gt "${#best}" ]; then
						best=$root
					fi
					;;
			esac
		done < "$libs"
	fi
	if [ -n "$best" ]; then
		printf '%s\n' "$best"
		return 0
	fi
	case "$p" in
		/mnt/sd2|/mnt/sd2/*)
			printf '%s\n' /mnt/sd2
			;;
		/mnt/media/*)
			printf '%s\n' "$(printf '%s' "$p" | awk -F/ '{ print "/" $2 "/" $3 "/" $4 }')"
			;;
		*)
			printf '%s\n' /storage
			;;
	esac
}

# Active library roots. Missing registry means the main card only.
zlyme_each_library() {
	libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
	if [ -r "$libs" ]; then
		while IFS= read -r root || [ -n "$root" ]; do
			[ -n "$root" ] || continue
			printf '%s\n' "$root"
		done < "$libs"
		return 0
	fi
	printf '%s\n' /storage
}

# One cached view per generation, library list, and winning card.
# zlyme-storage bumps the generation when membership changes and does
# not delete a view another launch is building. The same mount path
# with a different card is a new generation, so the old view is not reused.
zlyme_bios_key() {
	romlib=$1
	run=${ZLYME_RUN_DIR:-/run/zlyme}
	gen=0
	if [ -r "$run/bios-generation" ]; then
		gen=$(tr -cd '0-9' < "$run/bios-generation")
		[ -n "$gen" ] || gen=0
	fi
	libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
	if [ -r "$libs" ]; then
		sum=$(cksum "$libs" | awk '{ print $1 }')
	else
		sum=main
	fi
	printf '%s %s %s\n' "$gen" "$sum" "$romlib"
}

zlyme_bios_id() {
	printf '%s' "$1" | tr '/ ' '__'
}

# Union of every library Bios directory. The ROM library is applied
# last so a duplicate relative path resolves to that card. Only /run
# is written. Directory symlinks are not walked.
zlyme_bios_view() {
	romlib=$1
	run=${ZLYME_RUN_DIR:-/run/zlyme}
	py=${ZLYME_BIOS_PY:-/usr/share/zlyme/bios-union.py}
	mkdir -p "$run/bios-cache" || return 1
	lock=$run/bios.lock
	mkdir -p "$(dirname "$lock")"
	# flock serializes publish. A rescan only bumps the generation, so
	# it cannot remove this staging directory or the cache parent.
	if command -v flock >/dev/null 2>&1; then
		exec 9>>"$lock"
		flock 9
	fi
	key=$(zlyme_bios_key "$romlib")
	id=$(zlyme_bios_id "$key")
	view=$run/bios-cache/$id
	if [ -d "$view" ] && [ -f "$view/.zlyme-ready" ]; then
		rm -f "$run/bios"
		ln -s "$view" "$run/bios"
		BIOS_PATH=$view
		export BIOS_PATH
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 0
	fi
	if [ ! -f "$py" ] || ! command -v python3 >/dev/null 2>&1; then
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 1
	fi
	ZLYME_BIOS_SCANS=$(( ${ZLYME_BIOS_SCANS:-0} + 1 ))
	export ZLYME_BIOS_SCANS
	stage=$(mktemp -d "$run/bios.XXXXXX") || {
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 1
	}
	{
		zlyme_each_library | while IFS= read -r root; do
			[ -n "$root" ] || continue
			[ "$root" = "$romlib" ] && continue
			printf '%s\n' "$root/Bios"
		done
		printf '%s\n' "$romlib/Bios"
	} | python3 "$py" "$stage" || {
		rm -rf "$stage"
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 1
	}
	mkdir -p "$run/bios-cache" || {
		rm -rf "$stage"
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 1
	}
	rm -rf "$view"
	mv "$stage" "$view" || {
		rm -rf "$stage"
		if command -v flock >/dev/null 2>&1; then
			flock -u 9
		fi
		return 1
	}
	rm -f "$run/bios"
	ln -s "$view" "$run/bios"
	BIOS_PATH=$view
	export BIOS_PATH
	if command -v flock >/dev/null 2>&1; then
		flock -u 9
	fi
}

zlyme_save_matches_rom() {
	b=$1
	stem=$2
	stem2=$3
	case "$b" in
		*.sav|*.srm|*.state|*.state[0-9]|*.state.[0-9]|*.st[0-9]|*.auto) ;;
		*.rtc|*.mcr|*.eep|*.fla|*.nv|*.dsv|*.dst) ;;
		*) return 1 ;;
	esac
	s1=${b%.*}
	s2=${s1%.*}
	[ "$s1" = "$stem" ] || [ "$s1" = "$stem2" ] || \
		[ "$s2" = "$stem" ] || [ "$s2" = "$stem2" ]
}

zlyme_dir_has_files() {
	[ -d "$1" ] || return 1
	# Stop at the first file. Do not walk an entire save tree.
	n=$(find "$1" -maxdepth 2 -type f 2>/dev/null | head -n 1)
	[ -n "$n" ]
}

zlyme_dir_exact() {
	dir=$1
	stem=$2
	stem2=$3
	[ -d "$dir" ] || return 1
	for base in "$stem" "$stem2"; do
		[ -n "$base" ] || continue
		for f in \
			"$dir/$base".sav "$dir/$base".srm "$dir/$base".state \
			"$dir/$base".state[0-9] "$dir/$base".state.[0-9] \
			"$dir/$base".st[0-9] "$dir/$base".auto \
			"$dir/$base".rtc "$dir/$base".mcr "$dir/$base".eep \
			"$dir/$base".fla "$dir/$base".nv \
			"$dir/$base".dsv "$dir/$base".dst \
			"$dir"/*/"$base".sav "$dir"/*/"$base".srm \
			"$dir"/*/"$base".state "$dir"/*/"$base".dsv \
			"$dir"/*/"$base".dst
		do
			[ -f "$f" ] || continue
			zlyme_save_matches_rom "$(basename "$f")" "$stem" "$stem2" && return 0
		done
	done
	return 1
}

# Writable save library for this ROM. Exact game files win over
# unrelated files in the same system folder. The ROM library wins
# when it is one of the matches. An empty Saves/<tag> does not count.
# Prints the library root. Does not copy or create the directory.
zlyme_save_root() {
	rom=$1
	tag=$2
	romlib=$(zlyme_library_root "$rom")
	base=$(basename "$rom")
	stem=${base%.*}
	stem2=${stem%.*}
	other_exact=
	other_loose=
	# A temp file keeps the loop out of a pipeline so the hits survive.
	hits=$(mktemp) || return 1
	: > "$hits"
	zlyme_each_library | while IFS= read -r root; do
		[ -n "$root" ] || continue
		[ "$root" = "$romlib" ] && continue
		if zlyme_dir_exact "$root/Saves/$tag" "$stem" "$stem2"; then
			printf 'exact|%s\n' "$root"
		elif zlyme_dir_has_files "$root/Saves/$tag"; then
			printf 'loose|%s\n' "$root"
		fi
	done > "$hits"
	while IFS= read -r line; do
		kind=${line%%|*}
		root=${line#*|}
		if [ "$kind" = exact ] && [ -z "$other_exact" ]; then
			other_exact=$root
		fi
		if [ "$kind" = loose ] && [ -z "$other_loose" ]; then
			other_loose=$root
		fi
	done < "$hits"
	rm -f "$hits"
	if zlyme_dir_exact "$romlib/Saves/$tag" "$stem" "$stem2"; then
		printf '%s\n' "$romlib"
		return 0
	fi
	if [ -n "$other_exact" ]; then
		printf '%s\n' "$other_exact"
		return 0
	fi
	if zlyme_dir_has_files "$romlib/Saves/$tag"; then
		printf '%s\n' "$romlib"
		return 0
	fi
	if [ -n "$other_loose" ]; then
		printf '%s\n' "$other_loose"
		return 0
	fi
	printf '%s\n' "$romlib"
}

zlyme_library_tag_rel() {
	# stdout: TAG<TAB>rel  (rel empty if the path is the console folder)
	p=$1
	rest=
	case "$p" in
		*/Roms/*) rest=${p#*/Roms/} ;;
		*/roms/*) rest=${p#*/roms/} ;;
		*/ROMS/*) rest=${p#*/ROMS/} ;;
		*) return 1 ;;
	esac
	console=${rest%%/*}
	if [ "$rest" = "$console" ]; then
		rel=
	else
		rel=${rest#*/}
	fi
	tag=$console
	case "$console" in
		*'('*')')
			tag=${console##*(}
			tag=${tag%%)*}
			;;
	esac
	printf '%s\t%s\n' "$tag" "$rel"
}

zlyme_pref_field() {
	kind=$1
	tag=$2
	rel=$3
	want=$4
	[ -f "$ZLYME_PREFS" ] || return 0
	awk -F '\t' -v k="$kind" -v t="$tag" -v r="$rel" -v w="$want" '
		tolower($1) == tolower(k) && tolower($2) == tolower(t) && $3 == r {
			if (w == "gov") print $4
			else print $5
			exit
		}
	' "$ZLYME_PREFS"
}

zlyme_pref_lookup() {
	tag=$1
	rel=$2
	rom_key=${3:-$rel}
	gov=
	emu=
	if [ -n "$rom_key" ]; then
		gov=$(zlyme_pref_field rom "$tag" "$rom_key" gov)
		emu=$(zlyme_pref_field rom "$tag" "$rom_key" emu)
	fi
	if [ -n "$rel" ]; then
		pref_work=$rel
		while [ -z "$gov" ] && [ -z "$emu" ] && [ -n "$pref_work" ]; do
			gov=$(zlyme_pref_field folder "$tag" "$pref_work" gov)
			emu=$(zlyme_pref_field folder "$tag" "$pref_work" emu)
			case "$pref_work" in
				*/*) pref_work=${pref_work%/*} ;;
				*) pref_work= ;;
			esac
		done
	fi
	if [ -z "$gov" ] && [ -z "$emu" ]; then
		gov=$(zlyme_pref_field tag "$tag" "" gov)
		emu=$(zlyme_pref_field tag "$tag" "" emu)
	fi
	ZLYME_GOVERNOR=$gov
	ZLYME_EMU_CORE=$emu
}

zlyme_library_for() {
	rom=$1
	[ -n "$rom" ] || return 0
	if [ "${ZLYME_RESOLVED_ROM:-}" = "$rom" ] && [ -n "${BIOS_PATH:-}" ] \
		&& [ -n "${SAVES_PATH:-}" ]; then
		return 0
	fi
	library=$(zlyme_library_root "$rom")
	export library

	# BIOS is a runtime union of every mounted library. The ROM
	# library wins duplicate relative paths. Card trees are not copied.
	if ! zlyme_bios_view "$library"; then
		echo "zlyme: could not build the BIOS view for $rom" >&2
		return 1
	fi

	tr=$(zlyme_library_tag_rel "$rom") || tr=
	if [ -n "$tr" ]; then
		tag=${tr%%	*}
		rel=${tr#*	}
		rom_key=$rel
		case "$library" in
			/mnt/sd2) [ -n "$rel" ] && rom_key="SD2/$rel" ;;
			/mnt/media/*)
				if [ -n "$rel" ]; then
					rom_key="$(basename "$library")/$rel"
				fi
				;;
		esac
		zlyme_pref_lookup "$tag" "$rel" "$rom_key"
		[ -n "${EMU_TAG:-}" ] || EMU_TAG=$tag
		export EMU_TAG
	fi
	stag=${EMU_TAG:-}
	if [ -n "$stag" ]; then
		sroot=$(zlyme_save_root "$rom" "$stag")
	else
		sroot=$library
	fi
	SAVES_PATH=$sroot/Saves
	mkdir -p "$SAVES_PATH" 2>/dev/null || {
		echo "zlyme: could not create $SAVES_PATH" >&2
		return 1
	}
	export SAVES_PATH
	[ -n "${ZLYME_GOVERNOR:-}" ] && export ZLYME_GOVERNOR
	[ -n "${ZLYME_EMU_CORE:-}" ] && export ZLYME_EMU_CORE
	ZLYME_RESOLVED_ROM=$rom
	export ZLYME_RESOLVED_ROM
	ZLYME_RESOLVE_COUNT=$(( ${ZLYME_RESOLVE_COUNT:-0} + 1 ))
	export ZLYME_RESOLVE_COUNT
	return 0
}

# Image /roms/ports used to be a symlink to OS Roms. mount --bind follows
# that and overlays /storage/Roms/Ports (PORTS), so NextUI lists every
# port twice (OS path + SD2 path). Cover /roms with a tmpfs when needed.
# ZLYME_PM_MOUNTS is a test seam. Production uses mountpoint(1).
zlyme_path_mounted() {
	target=$1
	if [ -n "${ZLYME_PM_MOUNTS:-}" ]; then
		if ! command -v mounts_has >/dev/null 2>&1; then
			lib=${ZLYME_MOUNTS_LIB:-/usr/share/zlyme/mounts.sh}
			[ -r "$lib" ] || return 1
			# shellcheck disable=SC1090
			. "$lib"
		fi
		mounts_has "$ZLYME_PM_MOUNTS" "$target"
		return $?
	fi
	mountpoint -q "$target" 2>/dev/null
}

zlyme_ports_unbind() {
	if zlyme_path_mounted /roms/ports; then
		umount /roms/ports 2>/dev/null || umount -l /roms/ports 2>/dev/null || true
	fi
	if [ -f /run/zlyme/roms-covered ] && zlyme_path_mounted /roms; then
		umount /roms 2>/dev/null || umount -l /roms 2>/dev/null || true
		rm -f /run/zlyme/roms-covered
	fi
	# Leftover from the symlink-follow bug.
	if zlyme_path_mounted "/storage/Roms/Ports (PORTS)"; then
		umount "/storage/Roms/Ports (PORTS)" 2>/dev/null || umount -l "/storage/Roms/Ports (PORTS)" 2>/dev/null || true
	fi
}

zlyme_ports_bind() {
	rom=$1
	zlyme_library_for "$rom"
	ports=
	if [ -d "$library/Roms/Ports (PORTS)" ]; then
		ports="$library/Roms/Ports (PORTS)"
	elif [ -d "$library/Roms/ports" ]; then
		ports="$library/Roms/ports"
	elif [ -d "$library/roms/ports" ]; then
		ports="$library/roms/ports"
	fi
	[ -n "$ports" ] || return 0
	zlyme_ports_unbind
	mkdir -p /roms
	if [ -L /roms/ports ]; then
		mkdir -p /run/zlyme/roms/ports
		if mount --bind /run/zlyme/roms /roms 2>/dev/null; then
			: >/run/zlyme/roms-covered
		fi
	fi
	mkdir -p /roms/ports
	if [ -L /roms/ports ]; then
		# Still a symlink (cover failed). Do not bind onto OS Roms.
		export HM_PORTS_DIR="$ports"
		return 0
	fi
	mount --bind "$ports" /roms/ports 2>/dev/null || true
	export HM_PORTS_DIR="$ports"
}

case "${0##*/}" in
zlyme-library)
	case "${1:-}" in
		root)
			zlyme_library_root "$2"
			;;
		for)
			zlyme_library_for "$2"
			printf 'library=%s\nBIOS_PATH=%s\nSAVES_PATH=%s\nZLYME_GOVERNOR=%s\nZLYME_EMU_CORE=%s\n' \
				"${library:-}" "${BIOS_PATH:-}" "${SAVES_PATH:-}" \
				"${ZLYME_GOVERNOR:-}" "${ZLYME_EMU_CORE:-}"
			;;
		*)
			echo "usage: $0 {root|for} <path>" >&2
			exit 1
			;;
	esac
	;;
esac
