# Dolphin save binds. Sourced by start_dolphin and pak-launch.sh.
#
# Each bind is owned only when this attempt adds exactly one mountinfo
# id, stored as "id<TAB>path". Cleanup uses the PortMaster identity
# helper and unmounts only when that id is still the visible mount.
# A destination that is already mounted is not reused.

dolphin_binds_file() {
	printf '%s\n' "${ZLYME_DOLPHIN_BINDS:-/tmp/zlyme-dolphin-binds}"
}

dolphin_unresolved_file() {
	printf '%s\n' "${ZLYME_DOLPHIN_UNRESOLVED:-/tmp/zlyme-dolphin-unresolved}"
}

dolphin_session_blocked() {
	[ -e "$(dolphin_unresolved_file)" ]
}

dolphin_mark_unresolved() {
	_du=$(dolphin_unresolved_file)
	mkdir -p "$(dirname "$_du")" || return 1
	: > "$_du"
}

dolphin_clear_unresolved() {
	rm -f "$(dolphin_unresolved_file)"
}

dolphin_load_pm() {
	if command -v pm_cleanup_owned >/dev/null 2>&1; then
		return 0
	fi
	_dl=${ZLYME_PORTMASTER_MOUNTS:-/usr/share/zlyme/portmaster-mounts.sh}
	if [ ! -r "$_dl" ]; then
		echo "dolphin: mount identity helper is missing" >&2
		return 1
	fi
	# shellcheck disable=SC1090
	. "$_dl"
}

dolphin_pm() {
	ZLYME_PM_REGISTRY=$(dolphin_binds_file) \
		ZLYME_PM_MOUNTINFO=${ZLYME_DOLPHIN_MOUNTINFO:-${ZLYME_PM_MOUNTINFO:-/proc/self/mountinfo}} \
		ZLYME_MOUNTS_LIB=${ZLYME_MOUNTS_LIB:-/usr/share/zlyme/mounts.sh} \
		"$@"
}

dolphin_dest_ok() {
	case "$1" in
		""|*..*|*//*|*\ *) return 1 ;;
		*/dolphin-emu/GC|*/dolphin-emu/Wii) ;;
		*) return 1 ;;
	esac
	case "$1" in
		/|/boot|/storage|/mnt/sd2|/mnt/media) return 1 ;;
	esac
	return 0
}

dolphin_scrub() {
	_ds_reg=$(dolphin_binds_file)
	[ -f "$_ds_reg" ] || return 0
	[ ! -L "$_ds_reg" ] || {
		echo "dolphin: bind record is a symlink; leaving it" >&2
		return 1
	}
	_ds_tmp=$(mktemp "${TMPDIR:-/tmp}/zlyme-dolphin-binds.XXXXXX") || return 1
	while IFS= read -r _ds_line || [ -n "$_ds_line" ]; do
		[ -n "$_ds_line" ] || continue
		_ds_id=$(pm_entry_id "$_ds_line" 2>/dev/null) || {
			echo "dolphin: dropping unprovable bind record" >&2
			continue
		}
		_ds_path=$(pm_entry_path "$_ds_line")
		if ! dolphin_dest_ok "$_ds_path"; then
			echo "dolphin: dropping bind record for $_ds_path" >&2
			continue
		fi
		printf '%s\t%s\n' "$_ds_id" "$_ds_path"
	done < "$_ds_reg" > "$_ds_tmp"
	mv -f "$_ds_tmp" "$_ds_reg"
}

dolphin_path_owned_visible() {
	_dv_path=$1
	_dv_reg=$(dolphin_binds_file)
	[ -f "$_dv_reg" ] || return 1
	while IFS= read -r _dv_line || [ -n "$_dv_line" ]; do
		[ -n "$_dv_line" ] || continue
		_dv_id=$(pm_entry_id "$_dv_line" 2>/dev/null) || continue
		_dv_got=$(pm_entry_path "$_dv_line")
		[ "$_dv_got" = "$_dv_path" ] || continue
		_dv_role=$(dolphin_pm pm_mount_role "$_dv_path" "$_dv_id") || return 1
		[ "$_dv_role" = visible ] && return 0
	done < "$_dv_reg"
	return 1
}

dolphin_bind_one() {
	_do_src=$1
	_do_dst=$2
	if ! dolphin_dest_ok "$_do_dst"; then
		echo "dolphin: refusing $_do_dst" >&2
		return 1
	fi
	if [ ! -d "$_do_src" ]; then
		echo "dolphin: save directory $_do_src is missing" >&2
		return 1
	fi
	_do_before=$(mktemp "${TMPDIR:-/tmp}/zlyme-dolphin-before.XXXXXX") || {
		echo "dolphin: cannot record a mount id for $_do_dst" >&2
		return 1
	}
	if ! dolphin_pm pm_ids_at "$_do_dst" > "$_do_before"; then
		rm -f "$_do_before"
		echo "dolphin: cannot read mountinfo for $_do_dst" >&2
		return 1
	fi
	if [ -s "$_do_before" ]; then
		rm -f "$_do_before"
		echo "dolphin: $_do_dst is still mounted; not starting" >&2
		return 1
	fi
	if ! mount --bind "$_do_src" "$_do_dst"; then
		rm -f "$_do_before"
		echo "dolphin: bind failed for $_do_dst" >&2
		return 1
	fi
	# Host tests set this to exercise rollback. Runtime never sets it.
	if [ "${ZLYME_DOLPHIN_REGISTER_FAIL:-}" != 1 ]; then
		dolphin_pm pm_register_new "$_do_dst" "$_do_before" || true
	fi
	if dolphin_path_owned_visible "$_do_dst"; then
		rm -f "$_do_before"
		return 0
	fi
	_do_after=$(mktemp "${TMPDIR:-/tmp}/zlyme-dolphin-after.XXXXXX") || _do_after=
	_do_n=0
	_do_id=
	if [ -n "$_do_after" ]; then
		dolphin_pm pm_ids_at "$_do_dst" > "$_do_after" 2>/dev/null || : > "$_do_after"
		_do_new=$(awk -v before="$_do_before" '
			FILENAME == before { seen[$0] = 1; next }
			$0 ~ /^[0-9]+$/ && !seen[$0] { print }
		' "$_do_before" "$_do_after")
		rm -f "$_do_after"
		while IFS= read -r _do_one || [ -n "$_do_one" ]; do
			[ -n "$_do_one" ] || continue
			_do_n=$((_do_n + 1))
			_do_id=$_do_one
		done << EOF
$_do_new
EOF
	fi
	rm -f "$_do_before"
	if [ "$_do_n" -eq 1 ]; then
		_do_role=$(dolphin_pm pm_mount_role "$_do_dst" "$_do_id" 2>/dev/null || true)
		if [ "$_do_role" = visible ]; then
			if umount "$_do_dst" 2>/dev/null; then
				echo "dolphin: bind at $_do_dst was not recorded; removed it" >&2
				return 1
			fi
			dolphin_pm pm_store_id "$_do_id" "$_do_dst" || true
			if dolphin_path_owned_visible "$_do_dst"; then
				echo "dolphin: bind at $_do_dst stayed mounted; record kept" >&2
			else
				echo "dolphin: bind at $_do_dst stayed mounted and was not recorded" >&2
			fi
			return 1
		fi
	fi
	echo "dolphin: bind at $_do_dst was not recorded; not starting" >&2
	return 1
}

dolphin_release_path() {
	_dr_path=$1
	_dr_reg=$(dolphin_binds_file)
	[ -f "$_dr_reg" ] || return 0
	while IFS= read -r _dr_line || [ -n "$_dr_line" ]; do
		[ -n "$_dr_line" ] || continue
		_dr_got=$(pm_entry_path "$_dr_line")
		[ "$_dr_got" = "$_dr_path" ] || continue
		_dr_id=$(pm_entry_id "$_dr_line" 2>/dev/null) || continue
		_dr_role=$(dolphin_pm pm_mount_role "$_dr_path" "$_dr_id") || return 1
		if [ "$_dr_role" = visible ]; then
			if umount "$_dr_path" 2>/dev/null; then
				dolphin_pm pm_drop_exact "$_dr_line"
			fi
		fi
	done < "$_dr_reg"
}

dolphin_prepare() {
	dolphin_load_pm || return 1
	if dolphin_session_blocked; then
		echo "dolphin: previous session was not proved; not starting" >&2
		return 1
	fi
	_dp_reg=$(dolphin_binds_file)
	if [ -L "$_dp_reg" ] || [ -d "$_dp_reg" ]; then
		echo "dolphin: cannot create the bind record" >&2
		return 1
	fi
	mkdir -p "$(dirname "$_dp_reg")" || {
		echo "dolphin: cannot create the bind record" >&2
		return 1
	}
	if [ ! -e "$_dp_reg" ] && ! touch "$_dp_reg"; then
		echo "dolphin: cannot create the bind record" >&2
		return 1
	fi
	dolphin_scrub || return 1
	if ! dolphin_bind_one "$1" "$2"; then
		return 1
	fi
	if ! dolphin_bind_one "$3" "$4"; then
		dolphin_release_path "$2" || true
		return 1
	fi
	return 0
}

dolphin_bind_release() {
	dolphin_load_pm || return 1
	if dolphin_session_blocked; then
		echo "dolphin: not releasing an unproved session" >&2
		return 1
	fi
	_db_reg=$(dolphin_binds_file)
	if [ -L "$_db_reg" ]; then
		echo "dolphin: bind record is a symlink; leaving it" >&2
		return 1
	fi
	[ -e "$_db_reg" ] || return 0
	if [ ! -f "$_db_reg" ]; then
		echo "dolphin: bind record is not a file; leaving it" >&2
		return 1
	fi
	dolphin_scrub || return 1
	dolphin_pm pm_cleanup_owned
}
