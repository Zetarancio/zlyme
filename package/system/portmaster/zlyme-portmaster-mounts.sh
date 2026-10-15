# Mounts created by one PortMaster launch.
#
# zlyme-portmaster-exec appends a target only when mount succeeds and
# the number of mounts at that target increases by one layer. A remount
# does not. A matching successful umount removes one line. nextui-session runs
# zlyme-portmaster-cleanup outside the pak process group, and that
# cleanup unmounts paths this file can prove the launch owns: a
# recorded wrapper mount, and a layer nested under /storage that was
# not in the pre-launch snapshot. Library roots stay mounted.
# Sourced, not executed.

pm_mounts_file() {
	printf '%s\n' "${ZLYME_PM_MOUNTS:-/proc/mounts}"
}

pm_registry() {
	printf '%s\n' "${ZLYME_PM_REGISTRY:-/run/zlyme-portmaster/owned-mounts}"
}

# Decoded targets nested under /storage before the port runs.
# One line per mount-table layer. /proc/mounts already lists a stack
# as more than one line at the same target.
pm_snapshot_file() {
	printf '%s\n' "${ZLYME_PM_SNAPSHOT:-/run/zlyme-portmaster/storage-before}"
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

pm_register() {
	path=$(pm_norm "$1") || return 0
	if pm_protected "$path"; then
		return 0
	fi
	pm_load_decode || return 0
	reg=$(pm_registry)
	mkdir -p "$(dirname "$reg")" || return 0
	printf '%s\n' "$path" >> "$reg"
}

# Drop one matching line. A second registration of the same path stays
# until a second successful umount.
pm_unregister_one() {
	path=$(pm_norm "$1") || return 0
	reg=$(pm_registry)
	[ -f "$reg" ] || return 0
	tmp=$(mktemp "${reg}.XXXXXX") || return 0
	removed=0
	while IFS= read -r line || [ -n "$line" ]; do
		if [ "$removed" = 0 ] && [ "$line" = "$path" ]; then
			removed=1
			continue
		fi
		[ -n "$line" ] || continue
		printf '%s\n' "$line"
	done < "$reg" > "$tmp"
	mv -f "$tmp" "$reg"
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

# Paths strictly under /storage, one decoded line per layer.
# /storage itself, a library root, and every other mount stay out.
pm_storage_nested() {
	pm_load_decode || return 1
	_sn_out=$1
	_sn_tmp=$(mktemp) || return 1
	if ! mounts_targets "$(pm_mounts_file)" > "$_sn_tmp"; then
		rm -f "$_sn_tmp"
		return 1
	fi
	: > "$_sn_out"
	while IFS= read -r _sn_target || [ -n "$_sn_target" ]; do
		[ -n "$_sn_target" ] || continue
		case "$_sn_target" in
			/storage/*) ;;
			*) continue ;;
		esac
		if pm_protected "$_sn_target"; then
			continue
		fi
		printf '%s\n' "$_sn_target"
	done < "$_sn_tmp" >> "$_sn_out"
	rm -f "$_sn_tmp"
}

# Written after the pre-launch cleanup and before the port starts.
pm_snapshot_storage() {
	_ss_file=$(pm_snapshot_file)
	_ss_dir=$(dirname "$_ss_file")
	mkdir -p "$_ss_dir" || return 1
	_ss_tmp=$(mktemp "$_ss_dir/storage-before.XXXXXX") || return 1
	if ! pm_storage_nested "$_ss_tmp"; then
		rm -f "$_ss_tmp"
		return 1
	fi
	mv -f "$_ss_tmp" "$_ss_file"
}

# A layer nested under /storage that was not in the snapshot is owned
# by this launch, including a mount that called mount(8) directly.
# Layers already registered are not added again. A busy umount stays
# registered for a later pass. This does not unmount by directory name.
pm_adopt_storage_delta() {
	_ad_snap=$(pm_snapshot_file)
	[ -f "$_ad_snap" ] || return 0
	_ad_now=$(mktemp) || return 1
	if ! pm_storage_nested "$_ad_now"; then
		rm -f "$_ad_now"
		return 1
	fi
	_ad_paths=$(mktemp) || {
		rm -f "$_ad_now"
		return 1
	}
	sort -u "$_ad_snap" "$_ad_now" > "$_ad_paths"
	_ad_reg=$(pm_registry)
	while IFS= read -r _ad_path || [ -n "$_ad_path" ]; do
		[ -n "$_ad_path" ] || continue
		_ad_before=$(grep -Fx -c -- "$_ad_path" "$_ad_snap" || true)
		_ad_after=$(grep -Fx -c -- "$_ad_path" "$_ad_now" || true)
		_ad_held=0
		if [ -f "$_ad_reg" ]; then
			_ad_held=$(grep -Fx -c -- "$_ad_path" "$_ad_reg" || true)
		fi
		_ad_extra=$((_ad_after - _ad_before - _ad_held))
		while [ "$_ad_extra" -gt 0 ]; do
			echo "zlyme-portmaster-cleanup: adopting $_ad_path" >&2
			pm_register "$_ad_path"
			_ad_extra=$((_ad_extra - 1))
		done
	done < "$_ad_paths"
	rm -f "$_ad_now" "$_ad_paths"
}

# Deepest target first. A path that is already gone is dropped.
# A failed umount stays registered. A protected path is never unmounted.
pm_cleanup_owned() {
	pm_load_decode || return 1
	reg=$(pm_registry)
	[ -f "$reg" ] || return 0
	snap=$(mktemp) || return 1
	ranked=$(mktemp) || {
		rm -f "$snap"
		return 1
	}
	cp -f "$reg" "$snap"
	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue
		printf '%08d %s\n' "${#line}" "$line"
	done < "$snap" > "$ranked"
	sort -nr -o "$ranked" "$ranked"
	rc=0
	while IFS= read -r rec || [ -n "$rec" ]; do
		[ -n "$rec" ] || continue
		path=${rec#???????? }
		path=${path# }
		[ -n "$path" ] || continue
		if pm_protected "$path"; then
			echo "zlyme-portmaster-cleanup: refusing $path" >&2
			pm_unregister_one "$path"
			continue
		fi
		if ! mounts_has "$(pm_mounts_file)" "$path"; then
			pm_unregister_one "$path"
			continue
		fi
		if command umount "$path" 2>/dev/null; then
			pm_unregister_one "$path"
		else
			echo "zlyme-portmaster-cleanup: umount $path failed" >&2
			rc=1
		fi
	done < "$ranked"
	rm -f "$snap" "$ranked"
	return "$rc"
}
