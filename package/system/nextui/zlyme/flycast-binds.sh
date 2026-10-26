# Flycast save bind. Sourced by DC.pak and pak-launch.sh.
#
# The bind stays mounted until Flycast has exited, because Flycast
# writes its autosave on the way out. pak-launch releases it outside
# that process group. A destination that is already mounted is not reused.

flycast_binds_file() {
	printf '%s\n' "${ZLYME_FLYCAST_BINDS:-/tmp/zlyme-flycast-binds}"
}

flycast_unresolved_file() {
	printf '%s\n' "${ZLYME_FLYCAST_UNRESOLVED:-/tmp/zlyme-flycast-unresolved}"
}

flycast_session_blocked() {
	[ -e "$(flycast_unresolved_file)" ]
}

flycast_mark_unresolved() {
	_fu=$(flycast_unresolved_file)
	mkdir -p "$(dirname "$_fu")" || return 1
	: > "$_fu"
}

flycast_clear_unresolved() {
	rm -f "$(flycast_unresolved_file)"
}

flycast_load_pm() {
	if command -v pm_cleanup_owned >/dev/null 2>&1; then
		return 0
	fi
	_fl=${ZLYME_PORTMASTER_MOUNTS:-/usr/share/zlyme/portmaster-mounts.sh}
	if [ ! -r "$_fl" ]; then
		echo "flycast: mount identity helper is missing" >&2
		return 1
	fi
	# shellcheck disable=SC1090
	. "$_fl"
}

flycast_pm() {
	ZLYME_PM_REGISTRY=$(flycast_binds_file) \
		ZLYME_PM_MOUNTINFO=${ZLYME_FLYCAST_MOUNTINFO:-${ZLYME_PM_MOUNTINFO:-/proc/self/mountinfo}} \
		ZLYME_MOUNTS_LIB=${ZLYME_MOUNTS_LIB:-/usr/share/zlyme/mounts.sh} \
		"$@"
}

flycast_dest_ok() {
	case "$1" in
		""|*..*|*//*|*\ *) return 1 ;;
		*/.local/share/flycast) ;;
		*) return 1 ;;
	esac
	case "$1" in
		/|/boot|/storage|/mnt/sd2|/mnt/media) return 1 ;;
	esac
	return 0
}

flycast_scrub() {
	_fs_reg=$(flycast_binds_file)
	[ -f "$_fs_reg" ] || return 0
	[ ! -L "$_fs_reg" ] || {
		echo "flycast: bind record is a symlink; leaving it" >&2
		return 1
	}
	_fs_tmp=$(mktemp "${TMPDIR:-/tmp}/zlyme-flycast-binds.XXXXXX") || return 1
	while IFS= read -r _fs_line || [ -n "$_fs_line" ]; do
		[ -n "$_fs_line" ] || continue
		_fs_id=$(pm_entry_id "$_fs_line" 2>/dev/null) || {
			echo "flycast: dropping unprovable bind record" >&2
			continue
		}
		_fs_path=$(pm_entry_path "$_fs_line")
		if ! flycast_dest_ok "$_fs_path"; then
			echo "flycast: dropping bind record for $_fs_path" >&2
			continue
		fi
		printf '%s\t%s\n' "$_fs_id" "$_fs_path"
	done < "$_fs_reg" > "$_fs_tmp"
	mv -f "$_fs_tmp" "$_fs_reg"
}

flycast_path_owned_visible() {
	_fv_path=$1
	_fv_reg=$(flycast_binds_file)
	[ -f "$_fv_reg" ] || return 1
	while IFS= read -r _fv_line || [ -n "$_fv_line" ]; do
		[ -n "$_fv_line" ] || continue
		_fv_id=$(pm_entry_id "$_fv_line" 2>/dev/null) || continue
		_fv_got=$(pm_entry_path "$_fv_line")
		[ "$_fv_got" = "$_fv_path" ] || continue
		_fv_role=$(flycast_pm pm_mount_role "$_fv_path" "$_fv_id") || return 1
		[ "$_fv_role" = visible ] && return 0
	done < "$_fv_reg"
	return 1
}

flycast_bind_one() {
	_fo_src=$1
	_fo_dst=$2
	if ! flycast_dest_ok "$_fo_dst"; then
		echo "flycast: refusing $_fo_dst" >&2
		return 1
	fi
	if [ ! -d "$_fo_src" ]; then
		echo "flycast: save directory $_fo_src is missing" >&2
		return 1
	fi
	_fo_before=$(mktemp "${TMPDIR:-/tmp}/zlyme-flycast-before.XXXXXX") || {
		echo "flycast: cannot record a mount id for $_fo_dst" >&2
		return 1
	}
	if ! flycast_pm pm_ids_at "$_fo_dst" > "$_fo_before"; then
		rm -f "$_fo_before"
		echo "flycast: cannot read mountinfo for $_fo_dst" >&2
		return 1
	fi
	if [ -s "$_fo_before" ]; then
		rm -f "$_fo_before"
		echo "flycast: $_fo_dst is still mounted; not starting" >&2
		return 1
	fi
	if ! mount --bind "$_fo_src" "$_fo_dst"; then
		rm -f "$_fo_before"
		echo "flycast: bind failed for $_fo_dst" >&2
		return 1
	fi
	# Host tests set this to exercise rollback. Runtime never sets it.
	if [ "${ZLYME_FLYCAST_REGISTER_FAIL:-}" != 1 ]; then
		flycast_pm pm_register_new "$_fo_dst" "$_fo_before" || true
	fi
	if flycast_path_owned_visible "$_fo_dst"; then
		rm -f "$_fo_before"
		return 0
	fi
	_fo_after=$(mktemp "${TMPDIR:-/tmp}/zlyme-flycast-after.XXXXXX") || _fo_after=
	_fo_n=0
	_fo_id=
	if [ -n "$_fo_after" ]; then
		flycast_pm pm_ids_at "$_fo_dst" > "$_fo_after" 2>/dev/null || : > "$_fo_after"
		_fo_new=$(awk -v before="$_fo_before" '
			FILENAME == before { seen[$0] = 1; next }
			$0 ~ /^[0-9]+$/ && !seen[$0] { print }
		' "$_fo_before" "$_fo_after")
		rm -f "$_fo_after"
		while IFS= read -r _fo_one || [ -n "$_fo_one" ]; do
			[ -n "$_fo_one" ] || continue
			_fo_n=$((_fo_n + 1))
			_fo_id=$_fo_one
		done << EOF
$_fo_new
EOF
	fi
	rm -f "$_fo_before"
	if [ "$_fo_n" -eq 1 ]; then
		_fo_role=$(flycast_pm pm_mount_role "$_fo_dst" "$_fo_id" 2>/dev/null || true)
		if [ "$_fo_role" = visible ]; then
			if umount "$_fo_dst" 2>/dev/null; then
				echo "flycast: bind at $_fo_dst was not recorded; removed it" >&2
				return 1
			fi
			flycast_pm pm_store_id "$_fo_id" "$_fo_dst" || true
			if flycast_path_owned_visible "$_fo_dst"; then
				echo "flycast: bind at $_fo_dst stayed mounted; record kept" >&2
			else
				echo "flycast: bind at $_fo_dst stayed mounted and was not recorded" >&2
			fi
			return 1
		fi
	fi
	echo "flycast: bind at $_fo_dst was not recorded; not starting" >&2
	return 1
}

flycast_prepare() {
	flycast_load_pm || return 1
	if flycast_session_blocked; then
		echo "flycast: previous session was not proved; not starting" >&2
		return 1
	fi
	_fp_reg=$(flycast_binds_file)
	if [ -L "$_fp_reg" ] || [ -d "$_fp_reg" ]; then
		echo "flycast: cannot create the bind record" >&2
		return 1
	fi
	mkdir -p "$(dirname "$_fp_reg")" || {
		echo "flycast: cannot create the bind record" >&2
		return 1
	}
	if [ ! -e "$_fp_reg" ] && ! touch "$_fp_reg"; then
		echo "flycast: cannot create the bind record" >&2
		return 1
	fi
	flycast_scrub || return 1
	flycast_bind_one "$1" "$2"
}

flycast_bind_release() {
	flycast_load_pm || return 1
	if flycast_session_blocked; then
		echo "flycast: not releasing an unproved session" >&2
		return 1
	fi
	_fb_reg=$(flycast_binds_file)
	if [ -L "$_fb_reg" ]; then
		echo "flycast: bind record is a symlink; leaving it" >&2
		return 1
	fi
	[ -e "$_fb_reg" ] || return 0
	if [ ! -f "$_fb_reg" ]; then
		echo "flycast: bind record is not a file; leaving it" >&2
		return 1
	fi
	flycast_scrub || return 1
	flycast_pm pm_cleanup_owned
}
