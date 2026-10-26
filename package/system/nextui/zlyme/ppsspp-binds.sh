# PPSSPP save binds. Sourced by PSP.pak and pak-launch.sh.
#
# A bind is owned only when this launcher's mount adds exactly one
# mountinfo id and that id is stored as "id<TAB>path". Cleanup uses the
# PortMaster mount-identity helper and unmounts only when that id is the
# visible mount. An already-mounted destination is not adopted.

ppsspp_binds_file() {
	printf '%s\n' "${ZLYME_PPSSPP_BINDS:-/tmp/zlyme-ppsspp-binds}"
}

ppsspp_load_pm() {
	if command -v pm_cleanup_owned >/dev/null 2>&1; then
		return 0
	fi
	_pb_lib=${ZLYME_PORTMASTER_MOUNTS:-/usr/share/zlyme/portmaster-mounts.sh}
	if [ ! -r "$_pb_lib" ]; then
		echo "ppsspp: mount identity helper is missing" >&2
		return 1
	fi
	# shellcheck disable=SC1090
	. "$_pb_lib"
}

ppsspp_pm() {
	ZLYME_PM_REGISTRY=$(ppsspp_binds_file) \
		ZLYME_PM_MOUNTINFO=${ZLYME_PPSSPP_MOUNTINFO:-${ZLYME_PM_MOUNTINFO:-/proc/self/mountinfo}} \
		ZLYME_MOUNTS_LIB=${ZLYME_MOUNTS_LIB:-/usr/share/zlyme/mounts.sh} \
		"$@"
}

ppsspp_dest_ok() {
	case "$1" in
		""|*..*|*//*|*\ *) return 1 ;;
		*/.config/ppsspp/PSP/SAVEDATA|*/.config/ppsspp/PSP/PPSSPP_STATE) ;;
		*) return 1 ;;
	esac
	case "$1" in
		/|/boot|/storage|/mnt/sd2|/mnt/media) return 1 ;;
	esac
	return 0
}

# Drop a path-only or otherwise unprovable line. Do not unmount it.
ppsspp_scrub() {
	_ps_reg=$(ppsspp_binds_file)
	[ -f "$_ps_reg" ] || return 0
	[ ! -L "$_ps_reg" ] || {
		echo "ppsspp: bind record is a symlink; leaving it" >&2
		return 1
	}
	_ps_tmp=$(mktemp "${TMPDIR:-/tmp}/zlyme-ppsspp-binds.XXXXXX") || return 1
	while IFS= read -r _ps_line || [ -n "$_ps_line" ]; do
		[ -n "$_ps_line" ] || continue
		_ps_id=$(pm_entry_id "$_ps_line" 2>/dev/null) || {
			echo "ppsspp: dropping unprovable bind record" >&2
			continue
		}
		_ps_path=$(pm_entry_path "$_ps_line")
		if ! ppsspp_dest_ok "$_ps_path"; then
			echo "ppsspp: dropping bind record for $_ps_path" >&2
			continue
		fi
		printf '%s\t%s\n' "$_ps_id" "$_ps_path"
	done < "$_ps_reg" > "$_ps_tmp"
	mv -f "$_ps_tmp" "$_ps_reg"
}

ppsspp_path_owned_visible() {
	_pv_path=$1
	_pv_reg=$(ppsspp_binds_file)
	[ -f "$_pv_reg" ] || return 1
	while IFS= read -r _pv_line || [ -n "$_pv_line" ]; do
		[ -n "$_pv_line" ] || continue
		_pv_id=$(pm_entry_id "$_pv_line" 2>/dev/null) || continue
		_pv_got=$(pm_entry_path "$_pv_line")
		[ "$_pv_got" = "$_pv_path" ] || continue
		_pv_role=$(ppsspp_pm pm_mount_role "$_pv_path" "$_pv_id") || return 1
		[ "$_pv_role" = visible ] && return 0
	done < "$_pv_reg"
	return 1
}

ppsspp_bind_one() {
	_bo_src=$1
	_bo_dst=$2
	if ! ppsspp_dest_ok "$_bo_dst"; then
		echo "ppsspp: refusing $_bo_dst" >&2
		return 1
	fi
	if [ ! -d "$_bo_src" ]; then
		echo "ppsspp: save directory $_bo_src is missing" >&2
		return 1
	fi
	if ppsspp_path_owned_visible "$_bo_dst"; then
		return 0
	fi
	_bo_ids=$(ppsspp_pm pm_ids_at "$_bo_dst") || {
		echo "ppsspp: cannot read mountinfo for $_bo_dst" >&2
		return 1
	}
	if [ -n "$_bo_ids" ]; then
		echo "ppsspp: $_bo_dst is already mounted and is not an owned PPSSPP bind" >&2
		return 1
	fi
	_bo_before=$(mktemp "${TMPDIR:-/tmp}/zlyme-ppsspp-before.XXXXXX") || {
		echo "ppsspp: cannot record a mount id for $_bo_dst" >&2
		return 1
	}
	: > "$_bo_before"
	if ! mount --bind "$_bo_src" "$_bo_dst"; then
		rm -f "$_bo_before"
		echo "ppsspp: bind failed for $_bo_dst" >&2
		return 1
	fi
	ppsspp_pm pm_register_new "$_bo_dst" "$_bo_before" || true
	if ppsspp_path_owned_visible "$_bo_dst"; then
		rm -f "$_bo_before"
		return 0
	fi
	_bo_after=$(mktemp "${TMPDIR:-/tmp}/zlyme-ppsspp-after.XXXXXX") || _bo_after=
	if [ -n "$_bo_after" ]; then
		ppsspp_pm pm_ids_at "$_bo_dst" > "$_bo_after" 2>/dev/null || : > "$_bo_after"
		_bo_new=$(awk -v before="$_bo_before" '
			FILENAME == before { seen[$0] = 1; next }
			$0 ~ /^[0-9]+$/ && !seen[$0] { print }
		' "$_bo_before" "$_bo_after")
		rm -f "$_bo_after"
		_bo_n=0
		_bo_id=
		while IFS= read -r _bo_one || [ -n "$_bo_one" ]; do
			[ -n "$_bo_one" ] || continue
			_bo_n=$((_bo_n + 1))
			_bo_id=$_bo_one
		done << EOF
$_bo_new
EOF
		if [ "$_bo_n" -eq 1 ]; then
			_bo_role=$(ppsspp_pm pm_mount_role "$_bo_dst" "$_bo_id" 2>/dev/null || true)
			if [ "$_bo_role" = visible ]; then
				umount "$_bo_dst" 2>/dev/null || true
			fi
		fi
	fi
	rm -f "$_bo_before"
	echo "ppsspp: bind at $_bo_dst was not recorded; not starting" >&2
	return 1
}

# 0 when this call created a new owned mount. 2 when an older owned
# mount was reused. 1 on failure.
ppsspp_bind_needed() {
	_bn_dst=$2
	if ppsspp_path_owned_visible "$_bn_dst"; then
		return 2
	fi
	ppsspp_bind_one "$1" "$2"
}

ppsspp_prepare() {
	ppsspp_load_pm || return 1
	_pp_reg=$(ppsspp_binds_file)
	if [ -L "$_pp_reg" ] || [ -d "$_pp_reg" ]; then
		echo "ppsspp: cannot create the bind record" >&2
		return 1
	fi
	mkdir -p "$(dirname "$_pp_reg")" || {
		echo "ppsspp: cannot create the bind record" >&2
		return 1
	}
	if [ ! -e "$_pp_reg" ] && ! touch "$_pp_reg"; then
		echo "ppsspp: cannot create the bind record" >&2
		return 1
	fi
	ppsspp_scrub || return 1
	_pp_made=
	for _pp_pair in \
		"$1|$3" \
		"$2|$4"
	do
		_pp_src=${_pp_pair%%|*}
		_pp_dst=${_pp_pair#*|}
		_pp_rc=0
		ppsspp_bind_needed "$_pp_src" "$_pp_dst" || _pp_rc=$?
		if [ "$_pp_rc" -eq 1 ]; then
			for _pp_undo in $_pp_made; do
				ppsspp_release_path "$_pp_undo" || true
			done
			return 1
		fi
		if [ "$_pp_rc" -eq 0 ]; then
			_pp_made="$_pp_made $_pp_dst"
		fi
	done
	return 0
}

ppsspp_release_path() {
	_rp_path=$1
	_rp_reg=$(ppsspp_binds_file)
	[ -f "$_rp_reg" ] || return 0
	while IFS= read -r _rp_line || [ -n "$_rp_line" ]; do
		[ -n "$_rp_line" ] || continue
		_rp_got=$(pm_entry_path "$_rp_line")
		[ "$_rp_got" = "$_rp_path" ] || continue
		_rp_id=$(pm_entry_id "$_rp_line" 2>/dev/null) || continue
		_rp_role=$(ppsspp_pm pm_mount_role "$_rp_path" "$_rp_id") || return 1
		if [ "$_rp_role" = visible ]; then
			if umount "$_rp_path" 2>/dev/null; then
				ppsspp_pm pm_drop_exact "$_rp_line"
			fi
		fi
	done < "$_rp_reg"
}

ppsspp_bind_release() {
	ppsspp_load_pm || return 1
	_br_reg=$(ppsspp_binds_file)
	if [ -L "$_br_reg" ]; then
		echo "ppsspp: bind record is a symlink; leaving it" >&2
		return 1
	fi
	[ -e "$_br_reg" ] || return 0
	if [ ! -f "$_br_reg" ]; then
		echo "ppsspp: bind record is not a file; leaving it" >&2
		return 1
	fi
	ppsspp_scrub || return 1
	ppsspp_pm pm_cleanup_owned
}
