# Mounts created by one PortMaster launch.
#
# zlyme-portmaster-exec records a mount only when its mount command
# adds exactly one new /proc/self/mountinfo id at the target. The
# registry line is that id, a tab, and the path. A remount does not
# add an id. A successful umount drops a line only when that id is
# gone. nextui-session runs zlyme-portmaster-cleanup outside the pak
# process group. Cleanup unmounts a line only when that id is the
# visible mount at the path. proc_pid_mountinfo(5) identifies it: the
# mount at that path which is not the parent of any other mount there,
# and whose ancestors include the top mount of every shorter prefix.
# Line order and numeric id order are not that relation. Linux 7.2.10
# prints mnt_parent as the parent id (fs/proc_namespace.c) and sets
# overmount when the new mount covers the parent's root
# (fs/namespace.c make_visible). A missing id is dropped and nothing
# is unmounted. A covered id, a hidden id, an ambiguous table, an
# unreadable mount table, or a line with no id is left mounted and
# reported. A layer that merely appears under /storage is not owned.
# Library roots stay mounted.
#
# A mount id may be reused after umount(2). The visibility check and
# the later path umount are not one operation. A mount that becomes
# the visible one in that window, or a reused id, can detach a
# different filesystem or leave a stale registry line. Those limits
# stay; this is not a second mount manager.
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

# Field 5 of mountinfo is the mountpoint. Optional fields follow it
# and do not move the id, the parent id, or the mountpoint.
# Modes, set by the caller for the awk process only:
#   ids      print ids at the path; fail if a line cannot be parsed
#   role     visible, covered, hidden, absent, or ambiguous
#   visible  print the visible id, or fail
#   parent   print the parent id a new mount at the path would use
pm_mountinfo_awk() {
	_mi_mode=$1
	_mi_want=$2
	_mi_id=$3
	_mi_file=$4
	ZLYME_MOUNTINFO_MODE=$_mi_mode \
	ZLYME_MOUNTINFO_WANT=$_mi_want \
	ZLYME_MOUNTINFO_ID=$_mi_id \
	awk '
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
function is_prefix(pre, path,    n) {
	if (pre == path)
		return 0
	if (pre == "/")
		return 1
	n = length(pre)
	if (length(path) <= n)
		return 0
	return substr(path, 1, n) == pre && substr(path, n + 1, 1) == "/"
}
function split_ids(s, arr,    n, i, k, tmp) {
	n = split(s, tmp, " ")
	k = 0
	for (i = 1; i <= n; i++) {
		if (tmp[i] != "") {
			k++
			arr[k] = tmp[i]
		}
	}
	return k
}
function top_count(path,    n, i, j, id, ids, parented, nt) {
	n = split_ids(at[path], ids)
	nt = 0
	top_only = ""
	for (i = 1; i <= n; i++) {
		id = ids[i]
		parented = 0
		for (j = 1; j <= n; j++) {
			if (ids[j] != id && parent_of[ids[j]] == id)
				parented = 1
		}
		if (!parented) {
			nt++
			top_only = id
		}
	}
	return nt
}
function ancestor(from, target,    p, par, guard, seen) {
	if (from == target)
		return 1
	delete seen
	seen[from] = 1
	p = from
	for (guard = 0; guard < 64; guard++) {
		if (!(p in parent_of))
			return 0
		par = parent_of[p]
		if (par == target)
			return 1
		if (par == p)
			return 0
		if (par in seen)
			return -1
		seen[par] = 1
		p = par
	}
	return -1
}
function role_of(idq, want,    nt, q, ar, held) {
	if (!(idq in mp_of))
		return "absent"
	if (mp_of[idq] != want)
		return "ambiguous"
	nt = top_count(want)
	if (nt != 1)
		return "ambiguous"
	if (top_only != idq)
		return "covered"
	held = idq
	for (q in paths) {
		if (!is_prefix(q, want))
			continue
		nt = top_count(q)
		if (nt != 1)
			return "ambiguous"
		ar = ancestor(held, top_only)
		if (ar < 0)
			return "ambiguous"
		if (ar == 0)
			return "hidden"
	}
	return "visible"
}
NF == 0 { next }
NF < 5 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ { bad = 1; next }
{
	if ($1 in parent_of) {
		bad = 1
		next
	}
	parent_of[$1] = $2
	mp_of[$1] = decode($5)
	at[mp_of[$1]] = at[mp_of[$1]] " " $1
	paths[mp_of[$1]] = 1
}
END {
	mode = ENVIRON["ZLYME_MOUNTINFO_MODE"]
	want = ENVIRON["ZLYME_MOUNTINFO_WANT"]
	if (bad) {
		if (mode == "role") {
			print "ambiguous"
			exit 0
		}
		exit 1
	}
	if (mode == "ids") {
		n = split_ids(at[want], ids)
		for (i = 1; i <= n; i++)
			print ids[i]
		exit 0
	}
	if (mode == "role") {
		print role_of(ENVIRON["ZLYME_MOUNTINFO_ID"], want)
		exit 0
	}
	nt = top_count(want)
	if (mode == "parent" && nt == 0) {
		best = ""
		for (q in paths) {
			if (!is_prefix(q, want))
				continue
			if (best == "" || length(q) > length(best))
				best = q
		}
		if (best == "") {
			print "1"
			exit 0
		}
		nt = top_count(best)
		if (nt != 1)
			exit 1
		print top_only
		exit 0
	}
	if (nt != 1)
		exit 1
	held = top_only
	if (mode == "parent") {
		print held
		exit 0
	}
	for (q in paths) {
		if (!is_prefix(q, want))
			continue
		nt = top_count(q)
		if (nt != 1)
			exit 1
		ar = ancestor(held, top_only)
		if (ar < 0 || ar == 0)
			exit 1
	}
	print held
	exit 0
}
' "$_mi_file"
}

# Ids at one path. Their order is not which mount is visible.
pm_ids_at() {
	_ia_path=$(pm_norm "$1") || return 1
	_ia_info=$(pm_mountinfo_file)
	[ -r "$_ia_info" ] || return 1
	pm_mountinfo_awk ids "$_ia_path" "" "$_ia_info"
}

# One word: visible, covered, hidden, absent, or ambiguous.
# 1 when mountinfo cannot be read.
pm_mount_role() {
	_mr_path=$(pm_norm "$1") || return 1
	_mr_id=$2
	case "$_mr_id" in
		''|*[!0-9]*)
			printf '%s\n' ambiguous
			return 0
			;;
	esac
	_mr_info=$(pm_mountinfo_file)
	[ -r "$_mr_info" ] || return 1
	pm_mountinfo_awk role "$_mr_path" "$_mr_id" "$_mr_info"
}

# Id of the visible mount at this path. 1 when it cannot be proved.
pm_visible_id() {
	_vi_path=$(pm_norm "$1") || return 1
	_vi_info=$(pm_mountinfo_file)
	[ -r "$_vi_info" ] || return 1
	pm_mountinfo_awk visible "$_vi_path" "" "$_vi_info"
}

# Parent id a new mount at this path records. 1 when no mount covers it.
pm_new_parent() {
	_np_path=$(pm_norm "$1") || return 1
	_np_info=$(pm_mountinfo_file)
	[ -r "$_np_info" ] || return 1
	pm_mountinfo_awk parent "$_np_path" "" "$_np_info"
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

# Deepest path first. Mount id numbers are not an order. A pass
# unmounts only a recorded id that is the visible mount, then repeats
# so a recorded mount uncovered by that unmount can leave too. A
# protected path is never unmounted. A missing id is dropped. Anything
# that is not proven visible stays mounted, and its registry line stays.
pm_cleanup_owned() {
	pm_load_decode || return 1
	_co_reg=$(pm_registry)
	[ -f "$_co_reg" ] || return 0
	_co_info=$(pm_mountinfo_file)
	_co_blocked=$(mktemp) || return 1
	_co_rc=0
	_co_guard=0
	while [ "$_co_guard" -lt 64 ]; do
		_co_guard=$((_co_guard + 1))
		_co_progress=0
		_co_ranked=$(mktemp) || {
			_co_rc=1
			break
		}
		while IFS= read -r _co_line || [ -n "$_co_line" ]; do
			[ -n "$_co_line" ] || continue
			_co_path=$(pm_entry_path "$_co_line")
			printf '%08d %s\n' "${#_co_path}" "$_co_line"
		done < "$_co_reg" > "$_co_ranked"
		sort -k1,1nr -o "$_co_ranked" "$_co_ranked"
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
				continue
			fi
			if [ ! -r "$_co_info" ]; then
				continue
			fi
			_co_key=$(printf '%s\t%s' "$_co_id" "$_co_path")
			if grep -qxF -- "$_co_key" "$_co_blocked"; then
				continue
			fi
			if ! _co_role=$(pm_mount_role "$_co_path" "$_co_id"); then
				continue
			fi
			case "$_co_role" in
			absent)
				echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is gone" >&2
				pm_drop_exact "$_co_line"
				_co_progress=1
				;;
			visible)
				if command umount "$_co_path" 2>/dev/null; then
					if pm_id_still "$_co_id" "$_co_path"; then
						echo "zlyme-portmaster-cleanup: umount left mount id $_co_id at $_co_path" >&2
						_co_rc=1
						printf '%s\n' "$_co_key" >> "$_co_blocked"
					else
						pm_drop_exact "$_co_line"
						_co_progress=1
					fi
				else
					echo "zlyme-portmaster-cleanup: umount $_co_path failed" >&2
					_co_rc=1
					printf '%s\n' "$_co_key" >> "$_co_blocked"
				fi
				;;
			esac
		done < "$_co_ranked"
		rm -f "$_co_ranked"
		[ "$_co_progress" -eq 1 ] || break
	done
	_co_left=$(mktemp) || {
		rm -f "$_co_blocked"
		return 1
	}
	if [ -f "$_co_reg" ]; then
		cp -f "$_co_reg" "$_co_left"
	else
		: > "$_co_left"
	fi
	while IFS= read -r _co_line || [ -n "$_co_line" ]; do
		[ -n "$_co_line" ] || continue
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
		_co_key=$(printf '%s\t%s' "$_co_id" "$_co_path")
		if grep -qxF -- "$_co_key" "$_co_blocked"; then
			continue
		fi
		if [ ! -r "$_co_info" ]; then
			echo "zlyme-portmaster-cleanup: cannot read mountinfo; leaving $_co_path" >&2
			_co_rc=1
			continue
		fi
		if ! _co_role=$(pm_mount_role "$_co_path" "$_co_id"); then
			echo "zlyme-portmaster-cleanup: cannot read mountinfo; leaving $_co_path" >&2
			_co_rc=1
			continue
		fi
		case "$_co_role" in
		absent)
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is gone" >&2
			pm_drop_exact "$_co_line"
			;;
		covered)
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is covered; leaving it" >&2
			_co_rc=1
			;;
		hidden)
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path is hidden; leaving it" >&2
			_co_rc=1
			;;
		ambiguous)
			echo "zlyme-portmaster-cleanup: mount id $_co_id at $_co_path has ambiguous topology; leaving it" >&2
			_co_rc=1
			;;
		esac
	done < "$_co_left"
	rm -f "$_co_blocked" "$_co_left"
	return "$_co_rc"
}
