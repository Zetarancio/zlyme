# Mounts created by one PortMaster launch.
#
# zlyme-portmaster-exec records a mount only when its mount command
# adds exactly one new /proc/self/mountinfo id at the target. The
# registry line is that id, a tab, and the path. A remount does not
# add an id. A successful umount drops a line only when that id is
# gone. nextui-session runs zlyme-portmaster-cleanup outside the pak
# process group. Cleanup unmounts a line only when its id is still the
# top mount at that path. A missing id is dropped and nothing is
# unmounted. A covered id, an unreadable mount table, or a line with
# no id is left mounted and reported. A layer that merely appears
# under /storage is not owned. Library roots stay mounted.
# Sourced, not executed.

pm_mounts_file() {
	printf '%s\n' "${ZLYME_PM_MOUNTS:-/proc/mounts}"
}

pm_registry() {
	printf '%s\n' "${ZLYME_PM_REGISTRY:-/run/zlyme-portmaster/owned-mounts}"
}

pm_mountinfo_file() {
	printf '%s\n' "${ZLYME_PM_MOUNTINFO:-/proc/self/mountinfo}"
}

pm_load_decode() {
	if command -v mounts_has >/dev/null 2>&1; then
		return 0
	fi
	lib=${ZLYME_MOUNTS_LIB:-/usr/share/zlyme/mounts.sh}
	if [ ! -r "$lib" ]; then
		echo "zlyme-portmaster: mount table helper is missing" >&2
		return 1
	fi
	# shellcheck disable=SC1090
	. "$lib"
}

# Exact path. A directory that merely contains a library is not a root.
pm_protected() {
	path=$1
	case "$path" in
		/|/boot|/storage|/mnt/sd2|/mnt/media) return 0 ;;
	esac
	libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
	if [ -f "$libs" ] && grep -Fxq -- "$path" "$libs"; then
		return 0
	fi
	return 1
}

pm_norm() {
	p=$1
	[ -n "$p" ] || return 1
	case "$p" in
		/*) ;;
		*) return 1 ;;
	esac
	while [ "$p" != "/" ] && [ "$p" != "${p%/}" ]; do
		p=${p%/}
	done
	case "$p" in
		*"
"*|*"$(printf '\t')"*|*"$(printf '\r')"*) return 1 ;;
	esac
	printf '%s\n' "$p"
}

# Ids at one path, oldest first. The last line is the top mount.
# Field 5 of mountinfo is the mountpoint; optional fields follow it.
pm_ids_at() {
	_ia_path=$(pm_norm "$1") || return 1
	_ia_info=$(pm_mountinfo_file)
	[ -r "$_ia_info" ] || return 1
	ZLYME_MOUNTINFO_WANT=$_ia_path awk '
function decode(s,    out, i, n, chunk, a, b, c, oct) {
	out = ""
	n = length(s)
	i = 1
	while (i <= n) {
		if (substr(s, i, 1) == "\\" && i + 3 <= n) {
			chunk = substr(s, i + 1, 3)
			if (chunk ~ /^[0-7][0-7][0-7]$/) {
				a = index("01234567", substr(chunk, 1, 1)) - 1
				b = index("01234567", substr(chunk, 2, 1)) - 1
				c = index("01234567", substr(chunk, 3, 1)) - 1
				oct = a * 64 + b * 8 + c
				out = out sprintf("%c", oct)
				i += 4
				continue
			}
		}
		out = out substr(s, i, 1)
		i++
	}
	return out
}
NF < 5 || $1 !~ /^[0-9]+$/ { next }
{
	if (decode($5) == ENVIRON["ZLYME_MOUNTINFO_WANT"])
		print $1
}
' "$_ia_info"
}

pm_entry_path() {
	_ep_line=$1
	_ep_tab=$(printf '\t')
	case "$_ep_line" in
		*"$_ep_tab"*)
			printf '%s\n' "${_ep_line#*"$_ep_tab"}"
			;;
		*)
			printf '%s\n' "$_ep_line"
			;;
	esac
}

pm_entry_id() {
	_ei_line=$1
	_ei_tab=$(printf '\t')
	case "$_ei_line" in
		*"$_ei_tab"*)
			_ei_id=${_ei_line%%"$_ei_tab"*}
			;;
		*)
			return 1
			;;
	esac
	case "$_ei_id" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s\n' "$_ei_id"
}

pm_store_id() {
	_si_id=$1
	_si_path=$(pm_norm "$2") || return 0
	case "$_si_id" in
		''|*[!0-9]*) return 0 ;;
	esac
	if pm_protected "$_si_path"; then
		return 0
	fi
	_si_reg=$(pm_registry)
	mkdir -p "$(dirname "$_si_reg")" || return 0
	printf '%s\t%s\n' "$_si_id" "$_si_path" >> "$_si_reg"
}

# $2 is the id list captured before the mount. Exactly one new id is
# recorded. Anything else stays mounted and unrecorded.
pm_register_new() {
	_rn_path=$(pm_norm "$1") || return 0
	_rn_before=$2
	if [ -z "$_rn_before" ] || [ ! -f "$_rn_before" ]; then
		echo "zlyme-portmaster-exec: no mount-id snapshot for $_rn_path; leaving it unrecorded" >&2
		return 0
	fi
	_rn_after=$(mktemp) || return 0
	if ! pm_ids_at "$_rn_path" > "$_rn_after"; then
		echo "zlyme-portmaster-exec: cannot read mountinfo for $_rn_path; leaving it unrecorded" >&2
		rm -f "$_rn_after"
		return 0
	fi
	_rn_new=$(mktemp) || {
		rm -f "$_rn_after"
		return 0
	}
	# An empty before-file still has to count as the first file. NR==FNR
	# does not, and would hide the new id.
	awk -v before="$_rn_before" '
		FILENAME == before { seen[$0] = 1; next }
		$0 ~ /^[0-9]+$/ && !seen[$0] { print }
	' "$_rn_before" "$_rn_after" > "$_rn_new"
	rm -f "$_rn_after"
	_rn_n=0
	_rn_id=
	while IFS= read -r _rn_one || [ -n "$_rn_one" ]; do
		[ -n "$_rn_one" ] || continue
		_rn_n=$((_rn_n + 1))
		_rn_id=$_rn_one
	done < "$_rn_new"
	rm -f "$_rn_new"
	if [ "$_rn_n" -eq 1 ]; then
		pm_store_id "$_rn_id" "$_rn_path"
		return 0
	fi
	echo "zlyme-portmaster-exec: mount at $_rn_path did not add one mount id; leaving it unrecorded" >&2
}

pm_drop_exact() {
	_de_want=$1
	_de_reg=$(pm_registry)
	[ -f "$_de_reg" ] || return 0
	_de_tmp=$(mktemp "${_de_reg}.XXXXXX") || return 0
	_de_removed=0
	while IFS= read -r _de_line || [ -n "$_de_line" ]; do
		if [ "$_de_removed" = 0 ] && [ "$_de_line" = "$_de_want" ]; then
			_de_removed=1
			continue
		fi
		[ -n "$_de_line" ] || continue
		printf '%s\n' "$_de_line"
	done < "$_de_reg" > "$_de_tmp"
	mv -f "$_de_tmp" "$_de_reg"
}

# Drop registry lines for this path whose ids are no longer mounted.
# A line for a different path, or an id that is still present, stays.
# An unreadable mount table drops nothing.
pm_release_gone() {
	_rg_path=$(pm_norm "$1") || return 0
	_rg_reg=$(pm_registry)
	[ -f "$_rg_reg" ] || return 0
	_rg_ids=$(mktemp) || return 0
	if ! pm_ids_at "$_rg_path" > "$_rg_ids"; then
		echo "zlyme-portmaster-exec: cannot read mountinfo for $_rg_path; leaving its registry lines" >&2
		rm -f "$_rg_ids"
		return 0
	fi
	_rg_tmp=$(mktemp "${_rg_reg}.XXXXXX") || {
		rm -f "$_rg_ids"
		return 0
	}
	_rg_tab=$(printf '\t')
	while IFS= read -r _rg_line || [ -n "$_rg_line" ]; do
		[ -n "$_rg_line" ] || continue
		case "$_rg_line" in
			*"$_rg_tab"*)
				_rg_id=${_rg_line%%"$_rg_tab"*}
				_rg_lp=${_rg_line#*"$_rg_tab"}
				;;
			*)
				printf '%s\n' "$_rg_line"
				continue
				;;
		esac
		if [ "$_rg_lp" = "$_rg_path" ] && ! grep -qxF -- "$_rg_id" "$_rg_ids"; then
			continue
		fi
		printf '%s\n' "$_rg_line"
	done < "$_rg_reg" > "$_rg_tmp"
	mv -f "$_rg_tmp" "$_rg_reg"
	rm -f "$_rg_ids"
}

# 0 when the id is still mounted, or when that cannot be shown.
pm_id_still() {
	_is_id=$1
	_is_path=$2
	_is_tmp=$(mktemp) || return 0
	if ! pm_ids_at "$_is_path" > "$_is_tmp"; then
		rm -f "$_is_tmp"
		return 0
	fi
	if grep -qxF -- "$_is_id" "$_is_tmp"; then
		rm -f "$_is_tmp"
		return 0
	fi
	rm -f "$_is_tmp"
	return 1
}

# Last real operand. Values of -o and -t are not operands, so
# "mount -o remount,rw /some/path" names /some/path and not remount,rw.
pm_mount_dest() {
	dest=
	n=0
	take=
	for arg in "$@"; do
		if [ -n "$take" ]; then
			take=
			continue
		fi
		case "$arg" in
			-o|-t|--options|--types)
				take=1
				continue
				;;
			-*)
				continue
				;;
		esac
		dest=$arg
		n=$((n + 1))
	done
	[ "$n" -ge 1 ] || return 1
	[ -n "$dest" ] || return 1
	printf '%s\n' "$dest"
}

pm_umount_target() {
	dest=
	for arg in "$@"; do
		case "$arg" in
			-*) continue ;;
		esac
		dest=$arg
	done
	[ -n "$dest" ] || return 1
	printf '%s\n' "$dest"
}

# Deepest path first, then the higher mount id. A protected path is
# never unmounted. A missing id is dropped. Anything that is not proven
# to be the top mount stays mounted, and its registry line stays.
pm_cleanup_owned() {
	pm_load_decode || return 1
	_co_reg=$(pm_registry)
	[ -f "$_co_reg" ] || return 0
	_co_info=$(pm_mountinfo_file)
	_co_snap=$(mktemp) || return 1
	_co_ranked=$(mktemp) || {
		rm -f "$_co_snap"
		return 1
	}
	cp -f "$_co_reg" "$_co_snap"
	while IFS= read -r _co_line || [ -n "$_co_line" ]; do
		[ -n "$_co_line" ] || continue
		_co_path=$(pm_entry_path "$_co_line")
		_co_id=0
		if _co_got=$(pm_entry_id "$_co_line"); then
			_co_id=$_co_got
		fi
		printf '%08d%010d %s\n' "${#_co_path}" "$_co_id" "$_co_line"
	done < "$_co_snap" > "$_co_ranked"
	sort -nr -o "$_co_ranked" "$_co_ranked"
	_co_rc=0
	while IFS= read -r _co_rec || [ -n "$_co_rec" ]; do
		[ -n "$_co_rec" ] || continue
		_co_line=${_co_rec#* }
		_co_path=$(pm_entry_path "$_co_line")
		[ -n "$_co_path" ] || continue
		if pm_protected "$_co_path"; then
			echo "zlyme-portmaster-cleanup: refusing $_co_path" >&2
			pm_drop_exact "$_co_line"
			continue
		fi
		if ! _co_id=$(pm_entry_id "$_co_line"); then
			echo "zlyme-portmaster-cleanup: ambiguous registry entry: $_co_line" >&2
			_co_rc=1
			continue
		fi
		if [ ! -r "$_co_info" ]; then
			echo "zlyme-portmaster-cleanup: cannot read mountinfo; leaving $_co_path" >&2
			_co_rc=1
			continue
		fi
		_co_ids=$(mktemp) || {
			_co_rc=1
			continue
		}
		if ! pm_ids_at "$_co_path" > "$_co_ids"; then
			echo "zlyme-portmaster-cleanup: cannot read mountinfo; leaving $_co_path" >&2
			rm -f "$_co_ids"
			_co_rc=1
			continue
		fi
		if ! grep -qxF -- "$_co_id" "$_co_ids"; then
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is gone" >&2
			rm -f "$_co_ids"
			pm_drop_exact "$_co_line"
			continue
		fi
		_co_top=
		while IFS= read -r _co_one || [ -n "$_co_one" ]; do
			[ -n "$_co_one" ] || continue
			_co_top=$_co_one
		done < "$_co_ids"
		rm -f "$_co_ids"
		if [ "$_co_id" != "$_co_top" ]; then
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is covered; leaving it" >&2
			_co_rc=1
			continue
		fi
		if command umount "$_co_path" 2>/dev/null; then
			if pm_id_still "$_co_id" "$_co_path"; then
				echo "zlyme-portmaster-cleanup: umount left mount id $_co_id at $_co_path" >&2
				_co_rc=1
			else
				pm_drop_exact "$_co_line"
			fi
		else
			echo "zlyme-portmaster-cleanup: umount $_co_path failed" >&2
			_co_rc=1
		fi
	done < "$_co_ranked"
	rm -f "$_co_snap" "$_co_ranked"
	return "$_co_rc"
}
