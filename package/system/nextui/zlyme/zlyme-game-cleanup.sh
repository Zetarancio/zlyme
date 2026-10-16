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
		# OpenBOR saves live in Saves/OPENBOR. Files left in the ROM
		# folder are not collected and not deleted.
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
	miss=0
	if [ -d "$d" ]; then
		n=$(find "$d" -type f | wc -l | tr -d ' ')
		if [ "$DRY" = 0 ]; then
			rm -rf -- "$d" || miss=1
		fi
	fi
	if [ "$DRY" = 0 ] && [ "$miss" = 0 ]; then
		stock_seed options || miss=1
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

do_ra_cfg() {
	# The settings menu treats a count of 0 as nothing to do. Restoring
	# the stock file is still the action when the copy is missing.
	n=1
	miss=0
	if [ "$DRY" = 0 ]; then
		bin=${ZLYME_STOCK_SEED:-/usr/sbin/zlyme-stock-seed}
		if [ ! -f "$bin" ]; then
			miss=1
		else
			stock_seed reset-ra || miss=1
		fi
	fi
	printf '%s\n' "$n"
	[ "$miss" = 0 ] || return 1
}

# Missing stock files are copied again. A missing seed tool leaves the
# delete in place so a host run without the image still reports it.
stock_seed() {
	bin=${ZLYME_STOCK_SEED:-/usr/sbin/zlyme-stock-seed}
	[ -f "$bin" ] || return 0
	ZLYME_STOCK_ROOT=$STORAGE sh "$bin" "$1"
}

# Settings only. User carts, saves, prefixes, and soundfonts are not listed.
# GZDoom g4.14.2 writes $HOME/.config/gzdoom/gzdoom.ini. DOOM.pak sets
# HOME to the storage root. Soundfonts, FM banks, and autoexec.cfg in
# that directory are not the settings file.
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
		"$STORAGE/.config/gzdoom/gzdoom.ini" \
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
	if [ "$DRY" = 0 ] && [ "$miss" = 0 ]; then
		stock_seed standalones || miss=1
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

# Delete Game builds its own file list from the selected ROM.
# It does not read a plan another process could replace.

prefs_path() {
	printf '%s\n' "${ZLYME_PREFS_FILE:-$STORAGE/.config/nextui/shared/zlyme-prefs.txt}"
}

lib_is_present() {
	_lp_root=$1
	[ -n "$_lp_root" ] || return 1
	[ -d "$_lp_root" ] || return 1
	if [ ! -f "$LIBRARIES" ]; then
		[ "$_lp_root" = "$STORAGE" ]
		return
	fi
	while IFS= read -r _lp_row || [ -n "$_lp_row" ]; do
		_lp_row=$(printf '%s' "$_lp_row" | tr -d '\r')
		[ "$_lp_row" = "$_lp_root" ] && return 0
	done < "$LIBRARIES"
	return 1
}

fold_text() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

tag_of_console() {
	base=$(basename "$1")
	case "$base" in
		*'('*) ;;
		*) return 1 ;;
	esac
	t=${base##*(}
	t=${t%%)*}
	[ -n "$t" ] || return 1
	printf '%s\n' "$t"
}

rom_file_here() {
	_rf_root=$1
	_rf_tag=$2
	_rf_inner=$3
	case "$_rf_inner" in
		""|*..*|//*|*/) return 1 ;;
	esac
	for _rf_roms in "$_rf_root/Roms" "$_rf_root/roms"; do
		[ -d "$_rf_roms" ] || continue
		for _rf_dir in "$_rf_roms"/*; do
			[ -d "$_rf_dir" ] || continue
			_rf_got=$(tag_of_console "$_rf_dir") || continue
			[ "$(fold_text "$_rf_got")" = "$(fold_text "$_rf_tag")" ] || continue
			[ -f "$_rf_dir/$_rf_inner" ] && return 0
		done
	done
	return 1
}

# 0 when the per-ROM row should be removed.
rom_pref_is_orphan() {
	tag=$1
	rel=$2
	[ -n "$tag" ] || return 1
	[ -n "$rel" ] || return 1
	badge=
	inner=$rel
	case "$rel" in
		SD2/*)
			badge=SD2
			inner=${rel#SD2/}
			;;
		*/*)
			first=${rel%%/*}
			media=${ZLYME_MEDIA_ROOT:-/mnt/media}/$first
			if lib_is_present "$media" || { [ ! -f "$LIBRARIES" ] && [ -d "$media" ]; }; then
				badge=$first
				inner=${rel#*/}
			fi
			;;
	esac
	undecided=0
	found=0
	if lib_is_present "$STORAGE"; then
		rom_file_here "$STORAGE" "$tag" "$rel" && found=1
	else
		undecided=1
	fi
	if [ "$badge" = SD2 ]; then
		root=${ZLYME_SD2_ROOT:-/mnt/sd2}
		if lib_is_present "$root"; then
			rom_file_here "$root" "$tag" "$inner" && found=1
		else
			undecided=1
		fi
	elif [ -n "$badge" ]; then
		root=${ZLYME_MEDIA_ROOT:-/mnt/media}/$badge
		if lib_is_present "$root"; then
			rom_file_here "$root" "$tag" "$inner" && found=1
		else
			undecided=1
		fi
	fi
	# A missing parent folder on every present card can be an unplugged
	# volume whose name is the first path component. SD2 is already
	# undecided above when that card is out.
	if [ "$found" = 0 ] && [ -z "$badge" ]; then
		case "$rel" in
			*/*)
				top=${rel%%/*}
				if ! rom_file_here "$STORAGE" "$tag" "$top" && \
					! dir_under_console "$STORAGE" "$tag" "$top"; then
					undecided=1
				fi
				;;
		esac
	fi
	[ "$found" = 0 ] && [ "$undecided" = 0 ]
}

dir_under_console() {
	_du_root=$1
	_du_tag=$2
	_du_name=$3
	for _du_roms in "$_du_root/Roms" "$_du_root/roms"; do
		[ -d "$_du_roms" ] || continue
		for _du_dir in "$_du_roms"/*; do
			[ -d "$_du_dir" ] || continue
			_du_got=$(tag_of_console "$_du_dir") || continue
			[ "$(fold_text "$_du_got")" = "$(fold_text "$_du_tag")" ] || continue
			[ -d "$_du_dir/$_du_name" ] && return 0
		done
	done
	return 1
}

# One exclusive lock for a whole read–modify–write. The caller holds it.
# fd 7 stays open until prefs_release. Do not call prefs_hold twice.
# The image check requires BusyBox flock. Without it, do not write.
prefs_locked=0
prefs_hold() {
	_ph_dir=$1
	if [ "$prefs_locked" = 1 ]; then
		return 0
	fi
	if ! command -v flock >/dev/null 2>&1; then
		return 1
	fi
	# shellcheck disable=SC3023
	exec 7>>"$_ph_dir/.zlyme-prefs.lock" || return 1
	if ! flock 7; then
		exec 7>&-
		return 1
	fi
	prefs_locked=1
}

prefs_release() {
	if [ "$prefs_locked" != 1 ]; then
		return 0
	fi
	flock -u 7 2>/dev/null || true
	exec 7>&-
	prefs_locked=0
}

# fsync one file or its directory.
# Linux 7.2 exfat_dir_operations uses exfat_file_fsync, which flushes
# the block device. EINVAL means the file operations have no fsync
# (vfs_fsync_range). That is not a failed write. ENOTSUP is the same.
# A different errno after the rename is a durability failure. The new
# file stays, matching zlyme_prefs.c.
fsync_path() {
	_fs_path=$1
	_fs_kind=$2
	python3 - "$_fs_path" "$_fs_kind" << 'PY'
import errno
import os
import sys

path, kind = sys.argv[1], sys.argv[2]
if kind not in ("file", "dir"):
    sys.exit(2)
flags = os.O_RDONLY
if kind == "dir":
    flags |= os.O_DIRECTORY
try:
    fd = os.open(path, flags)
except OSError:
    sys.exit(0 if kind == "dir" else 1)
allowed = {errno.EINVAL, errno.EOPNOTSUPP}
enotsup = getattr(errno, "ENOTSUP", None)
if enotsup is not None:
    allowed.add(enotsup)
try:
    try:
        os.fsync(fd)
    except OSError as exc:
        if exc.errno not in allowed:
            sys.exit(1)
finally:
    os.close(fd)
sys.exit(0)
PY
}

# BusyBox 1.38 dd has no conv=fsync. Python is on the image.
# The rename stays in this directory, so it stays on this filesystem.
same_fs_replace() {
	_sr_dest=$1
	_sr_tmp=$2
	_sr_dir=$(dirname "$_sr_dest")
	case "$_sr_tmp" in
		"$_sr_dir"/*) ;;
		*)
			rm -f "$_sr_tmp"
			return 1
			;;
	esac
	if ! command -v python3 >/dev/null 2>&1; then
		rm -f "$_sr_tmp"
		return 1
	fi
	if ! fsync_path "$_sr_tmp" file; then
		rm -f "$_sr_tmp"
		return 1
	fi
	if ! mv -f "$_sr_tmp" "$_sr_dest"; then
		rm -f "$_sr_tmp"
		return 1
	fi
	fsync_path "$_sr_dir" dir
}

# Caller holds prefs_hold for this directory.
rewrite_prefs() {
	_rw_file=$1
	_rw_body=$2
	_rw_dir=$(dirname "$_rw_file")
	_rw_tmp=$(mktemp "$_rw_dir/.zlyme-prefs.XXXXXX") || return 1
	if ! cat "$_rw_body" > "$_rw_tmp"; then
		rm -f "$_rw_tmp"
		return 1
	fi
	same_fs_replace "$_rw_file" "$_rw_tmp"
}

# Read one preference file into body. Prints the orphan count.
# Caller holds the lock when this will be written back.
filter_orphan_prefs() {
	_fo_file=$1
	_fo_body=$2
	_fo_n=0
	: > "$_fo_body" || return 1
	while IFS= read -r _fo_line || [ -n "$_fo_line" ]; do
		case "$_fo_line" in
			''|'#'*)
				printf '%s\n' "$_fo_line" >> "$_fo_body"
				continue
				;;
		esac
		_fo_fields=$(printf '%s' "$_fo_line" | awk -F '\t' '{ print NF }')
		if [ "$_fo_fields" -lt 4 ]; then
			printf '%s\n' "$_fo_line" >> "$_fo_body"
			continue
		fi
		_fo_kind=${_fo_line%%	*}
		_fo_rest=${_fo_line#*	}
		_fo_tag=${_fo_rest%%	*}
		_fo_rest=${_fo_rest#*	}
		_fo_rel=${_fo_rest%%	*}
		case "$_fo_kind" in
			rom) ;;
			*)
				printf '%s\n' "$_fo_line" >> "$_fo_body"
				continue
				;;
		esac
		if rom_pref_is_orphan "$_fo_tag" "$_fo_rel"; then
			_fo_n=$((_fo_n + 1))
			continue
		fi
		printf '%s\n' "$_fo_line" >> "$_fo_body"
	done < "$_fo_file"
	printf '%s\n' "$_fo_n"
}

do_orphan_prefs() {
	file=$(prefs_path)
	[ -f "$file" ] || {
		printf '%s\n' 0
		return 0
	}
	if [ "$DRY" = 1 ]; then
		body=$(mktemp) || return 1
		n=$(filter_orphan_prefs "$file" "$body") || {
			rm -f "$body"
			return 1
		}
		rm -f "$body"
		printf '%s\n' "$n"
		return 0
	fi
	prefs_hold "$(dirname "$file")" || return 1
	body=$(mktemp) || {
		prefs_release
		return 1
	}
	n=$(filter_orphan_prefs "$file" "$body") || {
		rm -f "$body"
		prefs_release
		return 1
	}
	printf '%s\n' "$n"
	if [ "$n" -gt 0 ]; then
		rewrite_prefs "$file" "$body" || {
			rm -f "$body"
			prefs_release
			return 1
		}
	fi
	rm -f "$body"
	prefs_release
}

path_parts_safe() {
	_pp=$1
	case "$_pp" in
		/*) ;;
		*) return 1 ;;
	esac
	case "$_pp" in
		*'//'*) return 1 ;;
	esac
	_pp_rest=${_pp#/}
	while [ -n "$_pp_rest" ]; do
		_pp_part=${_pp_rest%%/*}
		[ "$_pp_part" = . ] && return 1
		[ "$_pp_part" = .. ] && return 1
		[ "$_pp_rest" = "$_pp_part" ] && break
		_pp_rest=${_pp_rest#*/}
	done
	return 0
}

path_walk_file() {
	_pw_root=$1
	_pw_full=$2
	_pw_cur=$_pw_root
	_pw_rest=${_pw_full#"$_pw_root"/}
	while [ -n "$_pw_rest" ]; do
		_pw_part=${_pw_rest%%/*}
		_pw_cur="$_pw_cur/$_pw_part"
		[ -L "$_pw_cur" ] && return 1
		[ "$_pw_rest" = "$_pw_part" ] && break
		_pw_rest=${_pw_rest#*/}
	done
	[ -f "$_pw_cur" ] || return 1
	[ -L "$_pw_cur" ] && return 1
	return 0
}

file_mark() {
	_fm_in=$(ls -id "$1" 2>/dev/null | awk '{ print $1 }') || return 1
	_fm_sz=$(wc -c < "$1" | tr -d ' ') || return 1
	[ -n "$_fm_in" ] || return 1
	printf '%s:%s\n' "$_fm_in" "$_fm_sz"
}

# ROM_TAG and ROM_REL match editprefs_open: tag from the console folder,
# relative path under it, SD2 or removable badge when that library is one.
rom_scope() {
	_rs_rom=$1
	_rs_lib=$2
	case "$_rs_rom" in
		"$_rs_lib"/Roms/*) _rs_roms=$_rs_lib/Roms ;;
		"$_rs_lib"/roms/*) _rs_roms=$_rs_lib/roms ;;
		*) return 1 ;;
	esac
	case "$_rs_rom" in
		*/.media/*|*/.config/*) return 1 ;;
	esac
	_rs_rest=${_rs_rom#"$_rs_roms"/}
	_rs_console=${_rs_rest%%/*}
	[ "$_rs_console" != "$_rs_rest" ] || return 1
	ROM_TAG=$(tag_of_console "$_rs_console") || return 1
	_rs_inner=${_rs_rest#*/}
	ROM_BADGE=
	_rs_sd2=${ZLYME_SD2_ROOT:-/mnt/sd2}
	_rs_media=${ZLYME_MEDIA_ROOT:-/mnt/media}
	if [ "$_rs_lib" = "$_rs_sd2" ]; then
		ROM_BADGE=SD2
	else
		case "$_rs_lib" in
			"$_rs_media"/*) ROM_BADGE=$(basename "$_rs_lib") ;;
		esac
	fi
	if [ -n "$ROM_BADGE" ]; then
		ROM_REL=$ROM_BADGE/$_rs_inner
	else
		ROM_REL=$_rs_inner
	fi
	return 0
}

art_is_shared() {
	_as_dir=$1
	_as_stem=$2
	_as_self=$3
	_as_list=$(mktemp) || return 1
	find "$_as_dir" -maxdepth 1 -type f ! -name '.*' > "$_as_list" 2>/dev/null || true
	_as_yes=0
	while IFS= read -r _as_f; do
		[ "$_as_f" = "$_as_self" ] && continue
		_as_b=$(basename "$_as_f")
		_as_s=${_as_b%.*}
		if [ "$_as_s" = "$_as_stem" ]; then
			_as_yes=1
			break
		fi
	done < "$_as_list"
	rm -f "$_as_list"
	[ "$_as_yes" = 1 ]
}

drop_rom_pref() {
	_dp_tag=$1
	_dp_rel=$2
	_dp_file=$(prefs_path)
	[ -f "$_dp_file" ] || return 0
	prefs_hold "$(dirname "$_dp_file")" || return 1
	_dp_body=$(mktemp) || {
		prefs_release
		return 1
	}
	_dp_hit=0
	while IFS= read -r _dp_line || [ -n "$_dp_line" ]; do
		case "$_dp_line" in
			''|'#'*)
				printf '%s\n' "$_dp_line" >> "$_dp_body"
				continue
				;;
		esac
		_dp_nf=$(printf '%s' "$_dp_line" | awk -F '\t' '{ print NF }')
		if [ "$_dp_nf" -lt 4 ]; then
			printf '%s\n' "$_dp_line" >> "$_dp_body"
			continue
		fi
		_dp_kind=${_dp_line%%	*}
		_dp_rest=${_dp_line#*	}
		_dp_rowtag=${_dp_rest%%	*}
		_dp_rest=${_dp_rest#*	}
		_dp_rowrel=${_dp_rest%%	*}
		if [ "$_dp_kind" = rom ] && \
			[ "$(fold_text "$_dp_rowtag")" = "$(fold_text "$_dp_tag")" ] && \
			[ "$_dp_rowrel" = "$_dp_rel" ]; then
			_dp_hit=1
			continue
		fi
		printf '%s\n' "$_dp_line" >> "$_dp_body"
	done < "$_dp_file"
	if [ "$_dp_hit" = 0 ]; then
		rm -f "$_dp_body"
		prefs_release
		return 0
	fi
	rewrite_prefs "$_dp_file" "$_dp_body" || {
		rm -f "$_dp_body"
		prefs_release
		return 1
	}
	rm -f "$_dp_body"
	prefs_release
}

# 0 when another ROM of this tag on the save-root library uses the same stem.
# A same-named ROM on a different card does not share this card's save file.
save_stem_taken() {
	_ss_stem=$1
	_ss_tag=$2
	_ss_self=$3
	_ss_root=$4
	[ -d "$_ss_root" ] || return 1
	_ss_yes=0
	for _ss_roms in "$_ss_root/Roms" "$_ss_root/roms"; do
		[ -d "$_ss_roms" ] || continue
		for _ss_dir in "$_ss_roms"/*; do
			[ -d "$_ss_dir" ] || continue
			_ss_got=$(tag_of_console "$_ss_dir") || continue
			[ "$(fold_text "$_ss_got")" = "$(fold_text "$_ss_tag")" ] || continue
			_ss_files=$(mktemp) || return 1
			find "$_ss_dir" -type f ! -path '*/.media/*' ! -name '.*' > "$_ss_files" 2>/dev/null || true
			while IFS= read -r _ss_f; do
				[ "$_ss_f" = "$_ss_self" ] && continue
				_ss_b=$(basename "$_ss_f")
				_ss_s=${_ss_b%.*}
				if [ "$_ss_s" = "$_ss_stem" ]; then
					_ss_yes=1
					break
				fi
			done < "$_ss_files"
			rm -f "$_ss_files"
			[ "$_ss_yes" = 1 ] && break
		done
		[ "$_ss_yes" = 1 ] && break
	done
	[ "$_ss_yes" = 1 ]
}

drop_recent() {
	_rc_rom=$1
	_rc_file=${ZLYME_RECENT_FILE:-$STORAGE/.config/nextui/shared/.minui/recent.txt}
	[ -f "$_rc_file" ] || return 0
	_rc_short=
	case "$_rc_rom" in
		"$STORAGE"/*) _rc_short=${_rc_rom#"$STORAGE"} ;;
	esac
	_rc_dir=$(dirname "$_rc_file")
	mkdir -p "$_rc_dir" || return 1
	_rc_tmp=$(mktemp "$_rc_dir/.zlyme-recent.XXXXXX") || return 1
	while IFS= read -r _rc_line || [ -n "$_rc_line" ]; do
		_rc_path=${_rc_line%%	*}
		[ "$_rc_path" = "$_rc_rom" ] && continue
		[ -n "$_rc_short" ] && [ "$_rc_path" = "$_rc_short" ] && continue
		printf '%s\n' "$_rc_line" >> "$_rc_tmp"
	done < "$_rc_file"
	same_fs_replace "$_rc_file" "$_rc_tmp"
}

delete_allowed() {
	_da_f=$1
	_da_rom=$2
	_da_tag=$3
	_da_sroot=$4
	_da_parent=$5
	_da_stem=$6
	_da_marker=$7
	[ -f "$_da_f" ] || return 1
	[ -L "$_da_f" ] && return 1
	[ "$_da_f" = "$_da_rom" ] && return 0
	[ -n "$_da_marker" ] && [ "$_da_f" = "$_da_marker" ] && return 0
	# Same directory the planner uses: Saves/<tag>/, not the library root.
	case "$_da_f" in
		"$_da_sroot"/Saves/"$_da_tag"/*) return 0 ;;
		"$_da_parent"/.media/*)
			_da_base=$(basename "$_da_f")
			case "$_da_base" in
				"$_da_stem".png|"$_da_stem".jpg|"$_da_stem".jpeg) return 0 ;;
			esac
			return 1
			;;
	esac
	return 1
}

delete_rom() {
	_del=$1
	path_parts_safe "$_del" || {
		echo "zlyme-game-cleanup: not a game file" >&2
		return 1
	}
	_del_lib=$(rom_library "$_del") || {
		echo "zlyme-game-cleanup: not a game file" >&2
		return 1
	}
	lib_is_present "$_del_lib" || {
		echo "zlyme-game-cleanup: library is not available" >&2
		return 1
	}
	path_walk_file "$_del_lib" "$_del" || {
		echo "zlyme-game-cleanup: not a game file" >&2
		return 1
	}
	rom_scope "$_del" "$_del_lib" || {
		echo "zlyme-game-cleanup: not a game file" >&2
		return 1
	}
	_del_mark=$(file_mark "$_del") || return 1
	_del_stem=$(basename "$_del")
	_del_stem=${_del_stem%.*}
	_del_parent=$(dirname "$_del")
	_del_list=$(mktemp) || return 1
	printf '%s\n' "$_del" >> "$_del_list"
	_del_sroot=$_del_lib
	_del_libsh=${ZLYME_LIBRARY_SH:-/usr/share/nextui/bin/zlyme-library.sh}
	if [ -r "$_del_libsh" ]; then
		# shellcheck disable=SC1090
		. "$_del_libsh"
		_del_sroot=$(zlyme_save_root "$_del" "$ROM_TAG") || _del_sroot=$_del_lib
	fi
	# Only this system's save folder. Another system's same basename stays.
	# A second ROM of this system with the same stem keeps the shared save.
	if [ -d "$_del_sroot/Saves/$ROM_TAG" ] && ! save_stem_taken "$_del_stem" "$ROM_TAG" "$_del" "$_del_sroot"; then
		find "$_del_sroot/Saves/$ROM_TAG" -type f 2>/dev/null |
		while IFS= read -r _del_f; do
			_del_b=$(basename "$_del_f")
			is_save_name "$_del_b" || continue
			_del_s1=${_del_b%.*}
			_del_s2=${_del_s1%.*}
			if [ "$_del_s1" = "$_del_stem" ] || [ "$_del_s2" = "$_del_stem" ]; then
				printf '%s\n' "$_del_f"
			fi
		done >> "$_del_list"
	fi
	if [ -d "$_del_parent/.media" ] && ! art_is_shared "$_del_parent" "$_del_stem" "$_del"; then
		for _del_ext in png jpg jpeg; do
			_del_img="$_del_parent/.media/$_del_stem.$_del_ext"
			[ -f "$_del_img" ] && [ ! -L "$_del_img" ] && printf '%s\n' "$_del_img"
		done >> "$_del_list"
	fi
	_del_marker=
	case "$(basename "$_del")" in
		*[Ss]plore*)
			_del_marker=$STORAGE/.config/nextui/shared/Pico-8-native/splore-installed
			[ -f "$_del_marker" ] && [ ! -L "$_del_marker" ] && printf '%s\n' "$_del_marker" >> "$_del_list"
			;;
	esac
	sort -u "$_del_list" -o "$_del_list"
	_del_n=$(wc -l < "$_del_list" | tr -d ' ')
	echo "COUNT=$_del_n"
	cat "$_del_list"
	if [ "$DRY" = 1 ]; then
		rm -f "$_del_list"
		return 0
	fi
	_del_now=$(file_mark "$_del") || {
		rm -f "$_del_list"
		return 1
	}
	if [ "$_del_now" != "$_del_mark" ]; then
		echo "zlyme-game-cleanup: game changed" >&2
		rm -f "$_del_list"
		return 1
	fi
	while IFS= read -r _del_f; do
		[ -n "$_del_f" ] || continue
		[ "$_del_f" = "$_del" ] && continue
		delete_allowed "$_del_f" "$_del" "$ROM_TAG" "$_del_sroot" "$_del_parent" "$_del_stem" "$_del_marker" || {
			echo "zlyme-game-cleanup: refused $_del_f" >&2
			rm -f "$_del_list"
			return 1
		}
	done < "$_del_list"
	drop_rom_pref "$ROM_TAG" "$ROM_REL" || {
		rm -f "$_del_list"
		return 1
	}
	drop_recent "$_del" || {
		rm -f "$_del_list"
		return 1
	}
	_del_now=$(file_mark "$_del") || {
		rm -f "$_del_list"
		return 1
	}
	if [ "$_del_now" != "$_del_mark" ]; then
		echo "zlyme-game-cleanup: game changed" >&2
		rm -f "$_del_list"
		return 1
	fi
	while IFS= read -r _del_f; do
		[ -n "$_del_f" ] || continue
		[ "$_del_f" = "$_del" ] && continue
		delete_allowed "$_del_f" "$_del" "$ROM_TAG" "$_del_sroot" "$_del_parent" "$_del_stem" "$_del_marker" || {
			echo "zlyme-game-cleanup: refused $_del_f" >&2
			rm -f "$_del_list"
			return 1
		}
		rm -f -- "$_del_f" || {
			rm -f "$_del_list"
			return 1
		}
	done < "$_del_list"
	_del_now=$(file_mark "$_del") || {
		rm -f "$_del_list"
		return 1
	}
	if [ "$_del_now" != "$_del_mark" ]; then
		echo "zlyme-game-cleanup: game changed" >&2
		rm -f "$_del_list"
		return 1
	fi
	rm -f -- "$_del" || {
		rm -f "$_del_list"
		return 1
	}
	rm -f "$_del_list"
	return 0
}

st=0
case "$ACTION" in
	rom)
		[ -n "$ROM_PATH" ] || exit 1
		delete_rom "$ROM_PATH" || exit 1
		exit 0
		;;
	rom-apply)
		echo "zlyme-game-cleanup: rom-apply is not used" >&2
		exit 1
		;;
	junk) n=$(do_junk) || st=$?; echo "COUNT=$n"; echo "junk files" ;;
	orphan-saves) n=$(do_orphan_saves) || st=$?; echo "COUNT=$n"; echo "orphan saves" ;;
	orphan-media) n=$(do_orphan_media) || st=$?; echo "COUNT=$n"; echo "orphan boxart" ;;
	recents) n=$(do_recents) || st=$?; echo "COUNT=$n"; echo "recents" ;;
	ra-cores) n=$(do_ra_cores) || st=$?; echo "COUNT=$n"; echo "RetroArch core options" ;;
	ra-cfg) n=$(do_ra_cfg) || st=$?; echo "COUNT=$n"; echo "RetroArch configuration" ;;
	standalones) n=$(do_standalones) || st=$?; echo "COUNT=$n" ;;
	ra-rom-cfg) n=$(do_ra_rom_cfg) || st=$?; echo "COUNT=$n"; echo "per-ROM RetroArch configs" ;;
	orphan-prefs) n=$(do_orphan_prefs) || st=$?; echo "COUNT=$n"; echo "orphan game preferences" ;;
	*)
		echo "usage: $0 {junk|orphan-saves|orphan-media|recents|ra-cores|ra-cfg|standalones|ra-rom-cfg|orphan-prefs|rom PATH} [--dry-run]" >&2
		exit 1
		;;
esac
exit "$st"
