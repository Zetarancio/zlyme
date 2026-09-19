#!/bin/sh
# Which library root a ROM lives on. Sourced by paks (via pak-log.sh)
# or invoked as: zlyme-library {root|for} <path>
#
# Sets: library, BIOS_PATH, SAVES_PATH, ZLYME_GOVERNOR, ZLYME_EMU_CORE
# HOME / XDG stay whatever the session exported (OS card).

ZLYME_PREFS="${SHARED_USERDATA_PATH:-/storage/.config/nextui/shared}/zlyme-prefs.txt"

zlyme_library_root() {
	p=$1
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
		work=$rel
		while [ -z "$gov" ] && [ -z "$emu" ] && [ -n "$work" ]; do
			gov=$(zlyme_pref_field folder "$tag" "$work" gov)
			emu=$(zlyme_pref_field folder "$tag" "$work" emu)
			case "$work" in
				*/*) work=${work%/*} ;;
				*) work= ;;
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
	library=$(zlyme_library_root "$rom")
	export library

	if [ -d "$library/Bios" ]; then
		BIOS_PATH=$library/Bios
	else
		BIOS_PATH=/storage/Bios
	fi
	export BIOS_PATH

	SAVES_PATH=$library/Saves
	mkdir -p "$SAVES_PATH" "$BIOS_PATH" 2>/dev/null || true
	export SAVES_PATH

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
	[ -n "${ZLYME_GOVERNOR:-}" ] && export ZLYME_GOVERNOR
	[ -n "${ZLYME_EMU_CORE:-}" ] && export ZLYME_EMU_CORE
	return 0
}

# Image /roms/ports used to be a symlink to OS Roms. mount --bind follows
# that and overlays /storage/Roms/Ports (PORTS), so NextUI lists every
# port twice (OS path + SD2 path). Cover /roms with a tmpfs when needed.
zlyme_ports_unbind() {
	if mountpoint -q /roms/ports 2>/dev/null; then
		umount /roms/ports 2>/dev/null || umount -l /roms/ports 2>/dev/null || true
	fi
	if [ -f /run/zlyme/roms-covered ] && mountpoint -q /roms 2>/dev/null; then
		umount /roms 2>/dev/null || umount -l /roms 2>/dev/null || true
		rm -f /run/zlyme/roms-covered
	fi
	# Leftover from the symlink-follow bug.
	if mountpoint -q "/storage/Roms/Ports (PORTS)" 2>/dev/null; then
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

if [ "${0##*/}" != "zlyme-library" ]; then
	return 0
fi

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
