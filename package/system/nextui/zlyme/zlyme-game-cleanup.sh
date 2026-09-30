#!/bin/sh
# Settings → Game housekeeping. Walk /run/zlyme/libraries.
# First line of stdout is COUNT=n. Rest is a short summary.
#
# ZLYME_LIBRARIES_FILE and ZLYME_CLEANUP_ROOT are test seams.
# Production leaves both unset.

set -u

DRY=0
ACTION=${1:-}
ROM_PATH=
[ "${2:-}" = "--dry-run" ] && DRY=1
[ "${1:-}" = "--dry-run" ] && DRY=1 && ACTION=${2:-}
if [ "$ACTION" = rom ]; then
	ROM_PATH=${2:-}
	[ "${3:-}" = "--dry-run" ] && DRY=1
fi

LIBRARIES=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
STORAGE=${ZLYME_CLEANUP_ROOT:-/storage}

list_roots() {
	if [ -f "$LIBRARIES" ]; then
		cat "$LIBRARIES"
	else
		echo "$STORAGE"
	fi
}

remove_listed() {
	list=$1
	miss=0
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		rm -rf -- "$f" || miss=1
	done < "$list"
	return "$miss"
}

do_junk() {
	n=0
	: > /tmp/zlyme-junk.list || return 1
	list_roots | while IFS= read -r root; do
		[ -d "$root" ] || continue
		find "$root" \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' \
			-o -name '._*' -o -name '__MACOSX' -o -name '.Trash' -o -name '.Trash-*' \
			-o -name '$RECYCLE.BIN' -o -name '$Recycle.Bin' \) 2>/dev/null
	done > /tmp/zlyme-junk.list
	n=$(wc -l < /tmp/zlyme-junk.list | tr -d ' ')
	miss=0
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		remove_listed /tmp/zlyme-junk.list || miss=1
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

rom_stems() {
	root=$1
	roms=
	if [ -d "$root/Roms" ]; then
		roms=$root/Roms
	elif [ -d "$root/roms" ]; then
		roms=$root/roms
	else
		return 0
	fi
	# One awk process. A shell basename per ROM is what made large libraries stall.
	find "$roms" -type f ! -path '*/.media/*' ! -name '.*' 2>/dev/null |
	awk '
	function base(p) { n = split(p, a, "/"); return a[n] }
	function strip(s) { sub(/\.[^.]*$/, "", s); return s }
	{
		s1 = strip(base($0))
		print s1
		s2 = strip(s1)
		if (s2 != s1)
			print s2
	}
	' | sort -u
}

is_save_name() {
	b=$1
	case "$b" in
		*.sav|*.srm|*.state|*.state[0-9]|*.state.[0-9]|*.st[0-9]|*.auto) return 0 ;;
		*.rtc|*.mcr|*.eep|*.fla|*.nv) return 0 ;;
	esac
	return 1
}

# Candidates are stem, second stem, path, separated by ASCII unit separator.
# Stems are loaded once. An empty stem file matches nothing, so every
# candidate is an orphan. That is the same rule as an empty ROM set.
filter_unmatched() {
	stems=$1
	cands=$2
	[ -s "$cands" ] || return 0
	awk -F '\037' -v stems="$stems" '
	BEGIN {
		while ((getline line < stems) > 0) {
			if (line != "")
				have[line] = 1
		}
		close(stems)
	}
	{
		if (!($1 in have) && !($2 in have))
			print $3
	}
	' "$cands"
}

note_save() {
	f=$1
	b=$(basename "$f")
	stem=${b%.*}
	stem2=${stem%.*}
	printf '%s\037%s\037%s\n' "$stem" "$stem2" "$f"
}

do_orphan_saves() {
	n=0
	command -v awk >/dev/null 2>&1 || return 1
	: > /tmp/zlyme-orph.list || return 1
	stems=/tmp/zlyme-stems.$$
	cands=/tmp/zlyme-cands.$$
	: > "$stems" || return 1
	: > "$cands" || return 1
	# Stems from every mounted library. A save is not an orphan when
	# its ROM is on a different active card.
	list_roots | while IFS= read -r root; do
		[ -d "$root" ] || continue
		rom_stems "$root"
	done > "$stems"
	list_roots | while IFS= read -r root; do
		[ -d "$root" ] || continue
		: > "$cands"
		if [ -d "$root/Saves" ]; then
			find "$root/Saves" -type f 2>/dev/null |
			awk -v stems="$stems" '
			BEGIN {
				while ((getline line < stems) > 0) {
					if (line != "")
						have[line] = 1
				}
				close(stems)
			}
			function base(p) { n = split(p, a, "/"); return a[n] }
			function strip(s) { sub(/\.[^.]*$/, "", s); return s }
			function is_save(name) {
				return name ~ /\.(sav|srm|state|state[0-9]|state\.[0-9]|st[0-9]|auto|rtc|mcr|eep|fla|nv)$/
			}
			{
				name = base($0)
				if (!is_save(name))
					next
				s1 = strip(name)
				s2 = strip(s1)
				if (!(s1 in have) && !(s2 in have))
					print
			}
			'
		fi
		# DraStic slots (paks bind Saves/NDS/{backup,savestates})
		for d in "$root/Saves/NDS/backup" "$root/Saves/NDS/savestates" "$root/Saves/NDS"; do
			[ -d "$d" ] || continue
			find "$d" -maxdepth 1 -type f \( -name '*.dsv' -o -name '*.dst' -o -name '*.dsv.*' \) 2>/dev/null |
			while IFS= read -r f; do
				note_save "$f"
			done >> "$cands"
		done
		# OpenBOR .sav next to the pak (launch.sh cds to the ROM dir)
		for roms in "$root/Roms" "$root/roms"; do
			[ -d "$roms" ] || continue
			find "$roms" -type d \( -name '*OPENBOR*' -o -name '*OpenBOR*' \) 2>/dev/null |
			while IFS= read -r od; do
				find "$od" -maxdepth 2 -type f -name '*.sav' 2>/dev/null |
				while IFS= read -r f; do
					note_save "$f"
				done >> "$cands"
			done
		done
		filter_unmatched "$stems" "$cands"
		# PortMaster savedata: sibling of a missing .sh
		for ports in "$root/Roms/Ports (PORTS)" "$root/Roms/ports" "$root/roms/ports"; do
			[ -d "$ports" ] || continue
			find "$ports" -type d \( -name savedata -o -name saves \) 2>/dev/null |
			while IFS= read -r sd; do
				parent=$(dirname "$sd")
				sh=
				for c in "$parent"/*.sh "$parent"/*.SH; do
					[ -f "$c" ] && sh=$c && break
				done
				[ -n "$sh" ] && continue
				printf '%s\n' "$sd"
			done
		done
	done >> /tmp/zlyme-orph.list
	rm -f "$stems" "$cands"
	n=$(wc -l < /tmp/zlyme-orph.list | tr -d ' ')
	miss=0
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		remove_listed /tmp/zlyme-orph.list || miss=1
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

do_orphan_media() {
	: > /tmp/zlyme-media.list || return 1
	list_roots | while IFS= read -r root; do
		roms=
		[ -d "$root/Roms" ] && roms=$root/Roms
		[ -d "$root/roms" ] && roms=$root/roms
		[ -n "$roms" ] || continue
		find "$roms" -type d -name '.media' 2>/dev/null |
		while IFS= read -r md; do
			parent=$(dirname "$md")
			find "$md" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) 2>/dev/null |
			while IFS= read -r img; do
				stem=$(basename "$img")
				stem=${stem%.*}
				found=0
				for f in "$parent/$stem".*; do
					[ -f "$f" ] || continue
					case "$f" in
						*/.media/*) continue ;;
					esac
					found=1
					break
				done
				[ "$found" = 0 ] && printf '%s\n' "$img"
			done
		done
	done >> /tmp/zlyme-media.list
	n=$(wc -l < /tmp/zlyme-media.list | tr -d ' ')
	miss=0
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		remove_listed /tmp/zlyme-media.list || miss=1
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

do_recents() {
	f=$STORAGE/.config/nextui/shared/.minui/recent.txt
	if [ -f "$f" ]; then
		n=$(wc -l < "$f" | tr -d ' ')
		miss=0
		if [ "$DRY" = 0 ]; then
			: > "$f" || miss=1
		fi
		printf '%s\n' "$n"
		[ "$miss" = 0 ] || return 1
	else
		printf '0\n'
	fi
}

do_ra_cores() {
	d=$STORAGE/.config/retroarch/config
	n=0
	if [ -d "$d" ]; then
		n=$(find "$d" -type f | wc -l | tr -d ' ')
		miss=0
		if [ "$DRY" = 0 ]; then
			rm -rf -- "$d" || miss=1
		fi
		printf '%s\n' "$n"
		[ "$miss" = 0 ] || return 1
		return 0
	fi
	printf '%s\n' "$n"
}

# Settings only. User carts, saves, prefixes, and soundfonts are not listed.
standalone_targets() {
	plat=my355
	conf=${ZLYME_DEVICE_CONF-/usr/share/zlyme/device.conf}
	if [ -n "$conf" ] && [ -f "$conf" ]; then
		# shellcheck disable=SC1091
		. "$conf"
		plat=${ZLYME_NEXTUI_PLATFORM:-my355}
	fi
	printf '%s\n' \
		"$STORAGE/.config/ppsspp/PSP/SYSTEM" \
		"$STORAGE/.config/flycast" \
		"$STORAGE/.config/nextui/${plat}/.config/flycast" \
		"$STORAGE/.config/dolphin-emu" \
		"$STORAGE/.config/drastic/drastic.cfg" \
		"$STORAGE/.config/aethersx2/inis" \
		"$STORAGE/.config/nextui/shared/configs/gzdoom/gzdoom.ini" \
		"$STORAGE/.config/nextui/shared/Pico-8-native/config" \
		"$STORAGE/.config/nextui/shared/Pico-8-native/sdl_controllers.txt"
}

do_standalones() {
	: > /tmp/zlyme-sa.list || return 1
	standalone_targets | while IFS= read -r p; do
		[ -e "$p" ] || continue
		printf '%s\n' "$p"
	done > /tmp/zlyme-sa.list
	n=$(wc -l < /tmp/zlyme-sa.list | tr -d ' ')
	miss=0
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		remove_listed /tmp/zlyme-sa.list || miss=1
	fi
	printf '%s\n' "$n"
	if [ "$n" -gt 0 ]; then
		tr '\n' ',' < /tmp/zlyme-sa.list | sed 's/,$/\n/'
	fi
	[ "$miss" = 0 ] || return 1
}

do_ra_rom_cfg() {
	d=$STORAGE/.config/retroarch/config
	command -v awk >/dev/null 2>&1 || return 1
	: > /tmp/zlyme-racfg.list || return 1
	stems=/tmp/zlyme-stems.$$
	cands=/tmp/zlyme-cands.$$
	: > "$stems" || return 1
	: > "$cands" || return 1
	list_roots | while IFS= read -r root; do
		rom_stems "$root"
	done > "$stems"
	if [ -d "$d" ]; then
		find "$d" -type f -name '*.cfg' ! -name '*libretro.cfg' 2>/dev/null |
		while IFS= read -r f; do
			b=$(basename "$f" .cfg)
			printf '%s\037%s\037%s\n' "$b" "$b" "$f"
		done > "$cands"
		filter_unmatched "$stems" "$cands" >> /tmp/zlyme-racfg.list
	fi
	rm -f "$stems" "$cands"
	n=$(wc -l < /tmp/zlyme-racfg.list | tr -d ' ')
	miss=0
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		remove_listed /tmp/zlyme-racfg.list || miss=1
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

rom_library() {
	p=$1
	libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
	best=
	if [ -f "$libs" ]; then
		while IFS= read -r root; do
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
		/mnt/sd2|/mnt/sd2/*) printf '%s\n' /mnt/sd2 ;;
		/mnt/media/*/*) printf '%s\n' "$(printf '%s' "$p" | awk -F/ '{ print "/" $2 "/" $3 "/" $4 }')" ;;
		/storage|/storage/*) printf '%s\n' /storage ;;
		*) return 1 ;;
	esac
}

plan_rom() {
	rom=$1
	plan=$2
	[ -n "$rom" ] || return 1
	case "$rom" in
		/*) ;;
		*) echo "rom path must be absolute" >&2; return 1 ;;
	esac
	[ -f "$rom" ] || return 1
	lib=$(rom_library "$rom") || return 1
	case "$rom" in
		"$lib"/*) ;;
		*) return 1 ;;
	esac
	: > "$plan" || return 1
	printf '%s\n' "$rom" >> "$plan"
	stem=$(basename "$rom")
	stem=${stem%.*}
	stem2=${stem%.*}
	sroot=$lib
	libsh=${ZLYME_LIBRARY_SH:-/usr/share/nextui/bin/zlyme-library.sh}
	if [ -r "$libsh" ]; then
		# shellcheck disable=SC1090
		. "$libsh"
		tag=$(basename "$(dirname "$rom")")
		case "$tag" in
			*'('*')')
				tag=${tag##*(}
				tag=${tag%%)*}
				;;
		esac
		sroot=$(zlyme_save_root "$rom" "$tag")
	fi
	if [ -d "$sroot/Saves" ]; then
		find "$sroot/Saves" -type f 2>/dev/null |
		while IFS= read -r f; do
			b=$(basename "$f")
			is_save_name "$b" || continue
			s1=${b%.*}
			s2=${s1%.*}
			if [ "$s1" = "$stem" ] || [ "$s1" = "$stem2" ] || \
				[ "$s2" = "$stem" ] || [ "$s2" = "$stem2" ]; then
				printf '%s\n' "$f"
			fi
		done >> "$plan"
	fi
	parent=$(dirname "$rom")
	if [ -d "$parent/.media" ]; then
		for img in "$parent/.media/$stem".* "$parent/.media/$stem2".*; do
			[ -f "$img" ] || continue
			printf '%s\n' "$img"
		done >> "$plan"
	fi
	case "$(basename "$rom")" in
		*[Ss]plore*)
			marker=$STORAGE/.config/nextui/shared/Pico-8-native/splore-installed
			[ -f "$marker" ] && printf '%s\n' "$marker" >> "$plan"
			;;
	esac
	sort -u "$plan" -o "$plan"
}

apply_plan() {
	list=$1
	miss=0
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		case "$f" in
			/*) ;;
			*) miss=1; continue ;;
		esac
		[ -e "$f" ] || continue
		if [ ! -f "$f" ]; then
			miss=1
			continue
		fi
		rm -f -- "$f" || miss=1
	done < "$list"
	recent=${ZLYME_RECENT_FILE:-$STORAGE/.config/nextui/shared/.minui/recent.txt}
	if [ -f "$recent" ]; then
		tmp=$(mktemp) || return 1
		grep -Fvx -f "$list" "$recent" > "$tmp" || true
		mv -f "$tmp" "$recent" || miss=1
	fi
	return "$miss"
}

st=0
case "$ACTION" in
	rom)
		plan=${ZLYME_ROM_PLAN:-/tmp/zlyme-rom.plan}
		plan_rom "$ROM_PATH" "$plan" || exit 1
		n=$(wc -l < "$plan" | tr -d ' ')
		echo "COUNT=$n"
		cat "$plan"
		if [ "$DRY" = 0 ]; then
			apply_plan "$plan" || exit 1
		fi
		exit 0
		;;
	rom-apply)
		[ -f "${2:-}" ] || exit 1
		apply_plan "$2" || exit 1
		exit 0
		;;
	junk) n=$(do_junk) || st=$?; echo "COUNT=$n"; echo "junk files" ;;
	orphan-saves) n=$(do_orphan_saves) || st=$?; echo "COUNT=$n"; echo "orphan saves" ;;
	orphan-media) n=$(do_orphan_media) || st=$?; echo "COUNT=$n"; echo "orphan boxart" ;;
	recents) n=$(do_recents) || st=$?; echo "COUNT=$n"; echo "recents" ;;
	ra-cores) n=$(do_ra_cores) || st=$?; echo "COUNT=$n"; echo "RetroArch core options" ;;
	standalones) n=$(do_standalones) || st=$?; echo "COUNT=$n" ;;
	ra-rom-cfg) n=$(do_ra_rom_cfg) || st=$?; echo "COUNT=$n"; echo "per-ROM RetroArch configs" ;;
	*)
		echo "usage: $0 {junk|orphan-saves|orphan-media|recents|ra-cores|standalones|ra-rom-cfg|rom PATH|rom-apply PLAN} [--dry-run]" >&2
		exit 1
		;;
esac
exit "$st"
