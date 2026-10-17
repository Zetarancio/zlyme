# Sourced by nextui-session. The file /tmp/next is a ZLYME1 launch
# record. This script turns that record into an argv. It does not
# evaluate the executable path or the ROM as shell source.
#
# A path that contains a newline cannot be one field of this record.
# The reader rejects a split or truncated file instead of running a
# piece of it. The writer in NextUI refuses those paths before exit.

# $1 is the launch.sh path. A ROM is never an argument of these checks.
launch_is_ports() {
	case "$1" in
		*/PORTS.pak/launch.sh) return 0 ;;
	esac
	return 1
}

launch_is_wine() {
	case "$1" in
		*/WINE.pak/launch.sh) return 0 ;;
	esac
	return 1
}

launch_skip_bt() {
	case "$1" in
		*/Tools/*|*settings.elf*) return 0 ;;
	esac
	return 1
}

launch_skip_filter() {
	case "$1" in
		*Settings.pak*|*settings.elf*) return 0 ;;
	esac
	return 1
}

# ASCII controls except tab are not a field. High bytes stay data.
field_text_ok() {
	if printf '%s' "$1" | LC_ALL=C tr -cd '\000-\010\013-\037\177' | grep -q .; then
		return 1
	fi
	return 0
}

# minui-list B/menu is 2/3. 143/137 is MENU+START (TERM then KILL).
pak_exit_ok() {
	case "$1" in
		0|2|3|137|143) return 0 ;;
	esac
	return 1
}

read_launch() {
	_lf_file=${1:-}
	LAUNCH_EXE=
	LAUNCH_ROM=
	if [ -z "$_lf_file" ] || [ ! -f "$_lf_file" ]; then
		echo "launch rejected: missing" >&2
		return 1
	fi
	_lf_sz=$(wc -c < "$_lf_file" | tr -d ' ')
	if [ "$_lf_sz" -eq 0 ]; then
		echo "launch rejected: empty" >&2
		return 1
	fi
	if [ "$_lf_sz" -gt 9000 ]; then
		echo "launch rejected: too long" >&2
		return 1
	fi
	_lf_nz=$(tr -d '\000' < "$_lf_file" | wc -c | tr -d ' ')
	if [ "$_lf_sz" != "$_lf_nz" ]; then
		echo "launch rejected: nul" >&2
		return 1
	fi
	_lf_err=
	_lf_magic=
	_lf_argc=
	_lf_exe=
	_lf_rom=
	_lf_extra=
	{
		IFS= read -r _lf_magic || _lf_err=truncated
		if [ -z "$_lf_err" ]; then
			IFS= read -r _lf_argc || _lf_err=truncated
		fi
		if [ -z "$_lf_err" ]; then
			IFS= read -r _lf_exe || _lf_err=truncated
		fi
		if [ -z "$_lf_err" ] && [ "$_lf_argc" = 2 ]; then
			IFS= read -r _lf_rom || _lf_err=truncated
		fi
		# The record ends at the last field's newline. A further newline
		# and a fragment that stops at EOF are both extra bytes.
		if [ -z "$_lf_err" ]; then
			_lf_extra=
			if IFS= read -r _lf_extra; then
				_lf_err=trailing
			elif [ -n "$_lf_extra" ]; then
				_lf_err=trailing
			fi
		fi
	} < "$_lf_file" || true
	if [ -z "$_lf_err" ] && [ "$_lf_magic" != ZLYME1 ]; then
		_lf_err=magic
	fi
	if [ -z "$_lf_err" ]; then
		case "$_lf_argc" in
			1|2) ;;
			*) _lf_err=argc ;;
		esac
	fi
	if [ -z "$_lf_err" ] && ! field_text_ok "$_lf_exe"; then
		_lf_err=control
	fi
	if [ -z "$_lf_err" ] && [ "${#_lf_exe}" -gt 4095 ]; then
		_lf_err="too long"
	fi
	if [ -z "$_lf_err" ]; then
		case "$_lf_exe" in
			/*/launch.sh) ;;
			*) _lf_err=executable ;;
		esac
	fi
	if [ -z "$_lf_err" ] && [ "$_lf_argc" = 2 ]; then
		if [ -z "$_lf_rom" ] || [ "${#_lf_rom}" -gt 4095 ]; then
			_lf_err=rom
		elif ! field_text_ok "$_lf_rom"; then
			_lf_err=control
		fi
	fi
	if [ -n "$_lf_err" ]; then
		echo "launch rejected: $_lf_err" >&2
		return 1
	fi
	# nextui-session reads these. They stay shell variables, not the pak environment.
	# shellcheck disable=SC2034
	LAUNCH_EXE="$_lf_exe"
	if [ "$_lf_argc" = 2 ]; then
		# shellcheck disable=SC2034
		LAUNCH_ROM="$_lf_rom"
	else
		# shellcheck disable=SC2034
		LAUNCH_ROM=
	fi
	return 0
}

proxy_host_ok() {
	_h=$1
	[ -n "$_h" ] || return 1
	[ "${#_h}" -le 253 ] || return 1
	case "$_h" in
		\[*\])
			_inner=${_h#\[}
			_inner=${_inner%\]}
			[ -n "$_inner" ] || return 1
			case "$_inner" in
				*[!0-9A-Fa-f:.]*) return 1 ;;
			esac
			;;
		*[!A-Za-z0-9._-]*) return 1 ;;
	esac
	return 0
}

proxy_port_ok() {
	case "$1" in
		''|*[!0-9]*) return 1 ;;
	esac
	_n=$1
	while [ "${_n#0}" != "$_n" ]; do
		_n=${_n#0}
	done
	[ -n "$_n" ] || _n=0
	[ "$_n" -ge 1 ] && [ "$_n" -le 65535 ]
}

# zlyme-proxy get is key=value text. It is not evaluated.
launch_apply_proxy() {
	_bin=${ZLYME_PROXY_BIN:-/usr/sbin/zlyme-proxy}
	unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY \
		no_proxy NO_PROXY
	[ -x "$_bin" ] || return 0
	_pf=$(mktemp /tmp/zlyme-proxy.XXXXXX) || return 0
	"$_bin" get > "$_pf" 2>/dev/null || true
	_enabled=
	_protocol=
	_host=
	_port=
	_valid=
	while IFS= read -r _line || [ -n "$_line" ]; do
		case "$_line" in
			enabled=*) _enabled=${_line#enabled=} ;;
			protocol=*) _protocol=${_line#protocol=} ;;
			host=*) _host=${_line#host=} ;;
			port=*) _port=${_line#port=} ;;
			valid=*) _valid=${_line#valid=} ;;
		esac
	done < "$_pf"
	rm -f "$_pf"
	[ "$_valid" = 1 ] && [ "$_enabled" = 1 ] || return 0
	case "$_protocol" in
		http|socks5) ;;
		*) return 0 ;;
	esac
	proxy_host_ok "$_host" || return 0
	proxy_port_ok "$_port" || return 0
	case "$_protocol" in
		http) _url="http://${_host}:${_port}" ;;
		socks5) _url="socks5h://${_host}:${_port}" ;;
	esac
	export http_proxy="$_url" https_proxy="$_url" \
		HTTP_PROXY="$_url" HTTPS_PROXY="$_url" \
		all_proxy="$_url" ALL_PROXY="$_url"
	export no_proxy="localhost,127.0.0.1,::1"
	export NO_PROXY="localhost,127.0.0.1,::1"
}

# Runs inside the setsid child. $1 is launch.sh. $2 is the ROM or empty.
exec_pak() {
	if ! launch_skip_filter "$1"; then
		_in=${ZLYME_PAK_INPUT:-/usr/share/zlyme/pak-input.sh}
		if [ -r "$_in" ]; then
			# shellcheck disable=SC1090
			. "$_in" || true
		fi
	fi
	launch_apply_proxy
	_hdmi_sh=${ZLYME_HDMI_SESSION:-/usr/share/zlyme/hdmi-session.sh}
	if [ -r "$_hdmi_sh" ]; then
		# shellcheck disable=SC1090
		. "$_hdmi_sh"
		zlyme_hdmi_apply || true
	fi
	_drm=${ZLYME_DRM_RELEASE:-/usr/bin/zlyme-drm-release}
	if [ -x "$_drm" ]; then
		"$_drm" || true
	fi
	if [ ! -f "$1" ]; then
		echo "launch rejected: missing launcher" >&2
		exit 127
	fi
	if [ -n "${2:-}" ]; then
		exec "$1" "$2"
	fi
	exec "$1"
}

spawn_pak() {
	_exe=$1
	_rom=${2-}
	_helper=${ZLYME_PAK_LAUNCH_SH:-/usr/share/nextui/bin/pak-launch.sh}
	_log=${SESSION_LOG:-/tmp/nextui-session.txt}
	# The single quotes are the program. Paths stay positional parameters.
	if [ "${LOGS_ON:-0}" = 1 ]; then
		# shellcheck disable=SC2016
		setsid sh -c '. "$0" || exit 126
exec_pak "$1" "$2"' "$_helper" "$_exe" "$_rom" &
	else
		# shellcheck disable=SC2016
		setsid sh -c '. "$0" || exit 126
exec_pak "$1" "$2"' "$_helper" "$_exe" "$_rom" >> "$_log" 2>&1 &
	fi
	_pak_pid=$!
}

# PORTS.pak execs the port, so its EXIT trap cannot unmount WestonPack.
# MENU+START can kill that process group. This session is outside it.
# Recorded wrapper mounts are what that cleanup releases.
portmaster_cleanup() {
	_bin=${ZLYME_PORTMASTER_CLEANUP:-/usr/sbin/zlyme-portmaster-cleanup}
	[ -x "$_bin" ] || return 0
	"$_bin" || true
}

# WINE.pak execs zlyme-weston-run, which stays in this pak group.
# wineserver can still outlive the group.
wine_prefix_cleanup() {
	_bin=${ZLYME_WINE_PREFIX:-/usr/sbin/zlyme-wine-prefix}
	[ -x "$_bin" ] || return 0
	"$_bin" cleanup || true
}

# DC.pak execs flycast, so that shell cannot unmount its save bind.
# The record is one path on tmpfs. This session is outside the pak
# group, so it still runs after a normal exit and after MENU+START.
flycast_bind_mounted() {
	if command -v mountpoint >/dev/null 2>&1; then
		mountpoint -q "$1"
		return $?
	fi
	awk -v p="$1" '$2 == p { found = 1 } END { exit found ? 0 : 1 }' /proc/mounts
}

flycast_bind_release() {
	_fb_rec=/tmp/zlyme-flycast-bind
	if [ ! -e "$_fb_rec" ] && [ ! -L "$_fb_rec" ]; then
		return 0
	fi
	if [ -L "$_fb_rec" ] || [ ! -f "$_fb_rec" ]; then
		rm -f "$_fb_rec"
		return 0
	fi
	_fb_mp=
	IFS= read -r _fb_mp < "$_fb_rec" || true
	case "$_fb_mp" in
		/*/flycast) ;;
		*)
			rm -f "$_fb_rec"
			return 0
			;;
	esac
	case "$_fb_mp" in
		*..*|*//*|*\ *)
			rm -f "$_fb_rec"
			return 0
			;;
	esac
	if ! flycast_bind_mounted "$_fb_mp"; then
		rm -f "$_fb_rec"
		return 0
	fi
	# A busy mount stays, and the record stays, so a later session can retry.
	if umount "$_fb_mp" 2>/dev/null; then
		rm -f "$_fb_rec"
	fi
}

# setsid so MENU+START can SIGTERM the pak group. BlueZ work stays in
# this shell so a hung bluetoothctl cannot become the session leader.
# ZLYME_PAK_BT=0 is a host-test seam. nextui-session unsets it.
run_pak_cmd() {
	_exe=$1
	_rom=${2-}
	skip_bt=0
	launch_skip_bt "$_exe" && skip_bt=1
	if launch_is_ports "$_exe"; then
		portmaster_cleanup
	fi
	if launch_is_wine "$_exe"; then
		wine_prefix_cleanup
	fi
	flycast_bind_release
	spawn_pak "$_exe" "$_rom"
	_hk=
	_hotkey=${ZLYME_PAK_HOTKEY:-/usr/sbin/zlyme-pak-hotkey}
	if [ -x "$_hotkey" ]; then
		"$_hotkey" "$_pak_pid" >> "${SESSION_LOG:-/tmp/nextui-session.txt}" 2>&1 &
		_hk=$!
	fi
	if [ "$skip_bt" = 0 ] && [ "${ZLYME_PAK_BT:-1}" = 1 ]; then
		bt_stop_scan
		sleep 0.3
		modprobe hid-nintendo >/dev/null 2>&1 || true
		# bluetoothctl connect on an already-live HID drops
		# the 8733bu link (status 0x04). Skip pads NextUI is using.
		run_timed_to 3 /tmp/zlyme-bt-paired bluetoothctl devices Paired
		while read -r _ mac rest; do
			[ -n "$mac" ] || continue
			_inf=/tmp/zlyme-bt-$mac
			run_timed_to 2 "$_inf" bluetoothctl info "$mac"
			grep -q 'UUID: Human Interface Device' "$_inf" 2>/dev/null || continue
			grep -q 'Connected: yes' "$_inf" 2>/dev/null && continue
			run_timed 2 bluetoothctl connect "$mac"
			rm -f "$_inf"
		done < /tmp/zlyme-bt-paired
		rm -f /tmp/zlyme-bt-paired
		sleep 0.6
	fi
	# nextui-session reads st after launch_with_reload returns.
	st=0
	# shellcheck disable=SC2034
	wait "$_pak_pid" || st=$?
	if [ -n "$_hk" ]; then
		kill "$_hk" 2>/dev/null || true
		wait "$_hk" 2>/dev/null || true
	fi
	if launch_is_ports "$_exe"; then
		portmaster_cleanup
	fi
	if launch_is_wine "$_exe"; then
		wine_prefix_cleanup
	fi
	flycast_bind_release
}

# zlyme-audio export prints one whitelisted sink id.
launch_with_reload() {
	_lr_exe=$1
	_lr_rom=${2-}
	_lr_flag=${ZLYME_SINK_RELOAD:-/tmp/zlyme-sink-reload}
	run_pak_cmd "$_lr_exe" "$_lr_rom"
	while [ -f "$_lr_flag" ]; do
		rm -f "$_lr_flag"
		if command -v zlyme-audio >/dev/null 2>&1; then
			eval "$(zlyme-audio export 2>/dev/null)" || true
		fi
		run_pak_cmd "$_lr_exe" "$_lr_rom"
	done
}
