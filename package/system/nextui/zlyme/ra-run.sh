#!/bin/sh
# NextUI sets HOME to userdata and XDG_CONFIG_HOME to /storage/.config.
# The user configuration is $XDG_CONFIG_HOME/retroarch/retroarch.cfg.
# zlyme-stock-seed copies the stock file when that file is missing or
# zero bytes, and when the RetroArch configuration reset runs.
# This script does not create or edit that file.
#
# --appendconfig is session data only: NextUI achievements, the ROM
# card's save and BIOS directories, joypad routing, and a content
# overlay. Theme, automatic savestates, quit-on-close, and
# config_save_on_exit stay in the user file. The stock file sets
# config_save_on_exit false so a quit does not write those session
# values back. Save Current Configuration still writes the running
# settings, including the session paths.

CFGDIR="${XDG_CONFIG_HOME:-/storage/.config}/retroarch"
MINUI_RA=${ZLYME_RA_MINUI:-/tmp/zlyme-minui-ra.cfg}
MINUI_SETTINGS="${SHARED_USERDATA_PATH:-/storage/.config/nextui/shared}/minuisettings.txt"

[ -r /etc/zlyme-gpu-env.sh ] && . /etc/zlyme-gpu-env.sh

# Spruce Flip: sdl2 + GameController. Export Flip + Linux Pro GUIDs so
# MENU is GUIDE (5) and a Switch Pro is the same pad NextUI already sees.
# Session CONFIG is Flip-only; replace it with the full file.
export SDL_GAMECONTROLLERCONFIG_FILE=/usr/lib/gamecontrollerdb.txt
if [ -f "$SDL_GAMECONTROLLERCONFIG_FILE" ]; then
	export SDL_GAMECONTROLLERCONFIG="$(grep -v '^#' "$SDL_GAMECONTROLLERCONFIG_FILE" | grep -v '^$')"
fi

mkdir -p "$CFGDIR/assets"

# Cores read system_directory (/storage/Bios). MinUI launchers also
# mkdir Bios/TAG. Link one level of those files into Bios/ so a dump
# in Bios/PS/ still counts. Never copy into Roms/.
BIOS_PATH="${BIOS_PATH:-/storage/Bios}"
# The runtime BIOS view already contains these aliases. Repeating the
# glob walks every BIOS file again and can abort the shell.
if [ -d "$BIOS_PATH" ] && [ ! -f "$BIOS_PATH/.zlyme-ready" ]; then
	for f in "$BIOS_PATH"/*/*; do
		[ -f "$f" ] || continue
		bn=$(basename "$f")
		[ -e "$BIOS_PATH/$bn" ] && continue
		rel=${f#"$BIOS_PATH/"}
		ln -s "$rel" "$BIOS_PATH/$bn" 2>/dev/null || true
	done
fi
if [ -d "$BIOS_PATH" ]; then
	mkdir -p "$BIOS_PATH/fbneo" "$BIOS_PATH/neocd"
	for f in neogeo.zip neocdz.zip; do
		if [ -f "$BIOS_PATH/$f" ] && [ ! -e "$BIOS_PATH/fbneo/$f" ]; then
			ln -s "../$f" "$BIOS_PATH/fbneo/$f" 2>/dev/null || true
		fi
	done
	for f in neocd.bin uni-bioscd.rom neocd_z.rom; do
		if [ -f "$BIOS_PATH/$f" ] && [ ! -e "$BIOS_PATH/neocd/$f" ]; then
			ln -s "../$f" "$BIOS_PATH/neocd/$f" 2>/dev/null || true
		fi
	done
	if [ -f "$BIOS_PATH/ST/tos.img" ] && [ ! -e "$BIOS_PATH/tos.img" ]; then
		ln -s "ST/tos.img" "$BIOS_PATH/tos.img" 2>/dev/null || true
	fi
	if [ -f "$BIOS_PATH/coleco.rom" ] && [ ! -e "$BIOS_PATH/colecovision.rom" ]; then
		ln -s coleco.rom "$BIOS_PATH/colecovision.rom" 2>/dev/null || true
	fi
fi

ra_bool() {
	case "$1" in
		1|true|True|TRUE|yes|on) echo true ;;
		*) echo false ;;
	esac
}

ra_quote() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Map MinUI In-Game (minuisettings.txt) onto RetroArch. Cheevos stay
# enabled from Settings even with no WAN so rcheevos can load a cached
# game hash; token and password both go in so login or cache still works.
write_minui_ra() {
	ra_enable=0
	ra_user=
	ra_pass=
	ra_token=
	ra_hardcore=0
	ra_notify=1
	ra_notify_dur=3
	ra_progress_dur=1
	notify_save=1
	notify_load=1
	notify_shot=1
	notify_dur=1

	if [ -f "$MINUI_SETTINGS" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
				raEnable=*) ra_enable=${line#*=} ;;
				raUsername=*) ra_user=${line#*=} ;;
				raPassword=*) ra_pass=${line#*=} ;;
				raToken=*) ra_token=${line#*=} ;;
				raHardcoreMode=*) ra_hardcore=${line#*=} ;;
				raShowNotifications=*) ra_notify=${line#*=} ;;
				raNotificationDuration=*) ra_notify_dur=${line#*=} ;;
				raProgressNotificationDuration=*) ra_progress_dur=${line#*=} ;;
				notifyManualSave=*) notify_save=${line#*=} ;;
				notifyLoad=*) notify_load=${line#*=} ;;
				notifyScreenshot=*) notify_shot=${line#*=} ;;
				notifyDuration=*) notify_dur=${line#*=} ;;
			esac
		done < "$MINUI_SETTINGS"
	fi

	show_state=false
	if [ "$(ra_bool "$notify_save")" = true ] || [ "$(ra_bool "$notify_load")" = true ]; then
		show_state=true
	fi

	font=false
	if [ "$show_state" = true ] || [ "$(ra_bool "$notify_shot")" = true ]; then
		font=true
	fi
	if [ "$(ra_bool "$ra_enable")" = true ] && [ "$(ra_bool "$ra_notify")" = true ]; then
		font=true
	fi

	progress=false
	if [ "$(ra_bool "$ra_enable")" = true ]; then
		case "$ra_progress_dur" in
			''|0) ;;
			*) progress=true ;;
		esac
	fi

	shot_dur=0
	case "$notify_dur" in
		4|5) shot_dur=2 ;;
		3) shot_dur=1 ;;
		*) shot_dur=0 ;;
	esac

	umask 077
	{
		echo "cheevos_enable = \"$(ra_bool "$ra_enable")\""
		echo "cheevos_username = \"$(ra_quote "$ra_user")\""
		echo "cheevos_password = \"$(ra_quote "$ra_pass")\""
		echo "cheevos_token = \"$(ra_quote "$ra_token")\""
		echo "cheevos_hardcore_mode_enable = \"$(ra_bool "$ra_hardcore")\""
		echo "cheevos_verbose_enable = \"$(ra_bool "$ra_notify")\""
		echo "cheevos_visibility_unlock = \"$(ra_bool "$ra_notify")\""
		echo "cheevos_visibility_mastery = \"$(ra_bool "$ra_notify")\""
		echo "cheevos_visibility_progress_tracker = \"$progress\""
		echo "cheevos_badges_enable = \"$(ra_bool "$ra_enable")\""
		echo "cheevos_richpresence_enable = \"$(ra_bool "$ra_enable")\""
		echo "cheevos_start_active = \"$(ra_bool "$ra_enable")\""
		echo "notification_show_save_state = \"$show_state\""
		echo "notification_show_screenshot = \"$(ra_bool "$notify_shot")\""
		echo "notification_show_screenshot_duration = \"$shot_dur\""
		echo "video_font_enable = \"$font\""
	} > "$MINUI_RA"
}

write_minui_ra

# Saves follow the ROM's volume. pak-log already called zlyme_library_for.
_ra_rom=
for _a in "$@"; do
	case "$_a" in
		-*) ;;
		*) _ra_rom="$_a" ;;
	esac
done
unset _a
if [ -n "$_ra_rom" ] && [ "${ZLYME_RESOLVED_ROM:-}" != "$_ra_rom" ] \
	&& [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/nextui/bin/zlyme-library.sh
	zlyme_library_for "$_ra_rom" || exit 1
fi
_ra_tag=${EMU_TAG:-}
if [ -z "$_ra_tag" ] && [ -n "$_ra_rom" ]; then
	tr=$(zlyme_library_tag_rel "$_ra_rom" 2>/dev/null) || tr=
	_ra_tag=${tr%%	*}
fi
if [ -n "$_ra_tag" ]; then
	mkdir -p "${SAVES_PATH:-/storage/Saves}/$_ra_tag"
	RA_SAVES=${ZLYME_RA_SAVES:-/tmp/zlyme-ra-saves.cfg}
	{
		printf 'savefile_directory = "%s/%s"\n' "${SAVES_PATH:-/storage/Saves}" "$_ra_tag"
		printf 'savestate_directory = "%s/%s"\n' "${SAVES_PATH:-/storage/Saves}" "$_ra_tag"
		printf 'system_directory = "%s"\n' "${BIOS_PATH:-/storage/Bios}"
	} > "$RA_SAVES"
fi

# Packaged cores are copied to the writable directory by zlyme-core-sync.
# This launch does not copy them and does not build a link directory.
# A launcher may still pass /usr/lib/libretro/<name>_libretro.so.
# The writable file with that name wins. The packaged file is the fallback.
RA_USER_CORES=${ZLYME_RA_USER_CORES:-$CFGDIR/cores}
RA_SYS_CORES=${ZLYME_RA_SYSTEM_CORES:-/usr/lib/libretro}

core_name_ok() {
	case "$1" in
		''|.*|*/*|*'..'*) return 1 ;;
	esac
	case "$1" in
		*_libretro.so) return 0 ;;
	esac
	return 1
}

ra_core_file() {
	_dir=$1
	_name=$2
	core_name_ok "$_name" || return 1
	_path=$_dir/$_name
	[ -f "$_path" ] && [ ! -L "$_path" ] || return 1
	printf '%s\n' "$_path"
}

if [ "${1:-}" = "-L" ] && [ -n "${2:-}" ]; then
	_req=$2
	_base=$(basename "$_req")
	if [ -n "${ZLYME_EMU_CORE:-}" ]; then
		_alt=${ZLYME_EMU_CORE}_libretro.so
		if core_name_ok "$_alt"; then
			_base=$_alt
		fi
	fi
	_alias=
	case "$_base" in
		mupen64plus_next_libretro.so) _alias=mupen64plus-next_libretro.so ;;
		mupen64plus-next_libretro.so) _alias=mupen64plus_next_libretro.so ;;
	esac
	_pick=
	_pick=$(ra_core_file "$RA_USER_CORES" "$_base" || true)
	if [ -z "$_pick" ] && [ -n "$_alias" ]; then
		_pick=$(ra_core_file "$RA_USER_CORES" "$_alias" || true)
	fi
	if [ -z "$_pick" ]; then
		_pick=$(ra_core_file "$RA_SYS_CORES" "$_base" || true)
	fi
	if [ -z "$_pick" ] && [ -n "$_alias" ]; then
		_pick=$(ra_core_file "$RA_SYS_CORES" "$_alias" || true)
	fi
	if [ -z "$_pick" ]; then
		_pick=$_req
	fi
	shift 2
	set -- -L "$_pick" "$@"
	unset _req _base _alt _alias _pick
fi

AC=/usr/share/retroarch/autoconfig
if [ ! -f "$AC/sdl2/Microsoft X-Box 360 pad.cfg" ]; then
	if [ -f "/usr/share/zlyme/retroarch/autoconfig/sdl2/Microsoft X-Box 360 pad.cfg" ]; then
		AC=/usr/share/zlyme/retroarch/autoconfig
	fi
fi
RA_AC=/tmp/zlyme-ra-ac.cfg
# One InputPlumber virtual pad uses the udev joypad driver. The
# physical Flip pad is a different name. A second pad with the same
# Xbox name, virtual or not, cannot be told apart by that name, so
# that session keeps the SDL2 joypad driver. The SDL device filter
# does not apply to udev. The virtual input node itself lives under
# /devices/virtual/input. This kernel does not add a device symlink.
_ra_virt=0
_ra_same=0
_ra_sys=${ZLYME_INPUT_SYS:-/sys/class/input}
_ra_db=${ZLYME_UDEV_DATA:-/run/udev/data}
for _ra_d in "$_ra_sys"/input*; do
	[ -r "$_ra_d/name" ] || continue
	_ra_name=$(tr -d '\r\n' < "$_ra_d/name")
	[ "$_ra_name" = "Microsoft X-Box 360 pad" ] || continue
	_ra_same=$((_ra_same + 1))
	_ra_node=$(readlink -f "$_ra_d" 2>/dev/null || true)
	case "$_ra_node" in
		*/devices/virtual/input/*) _ra_virt=$((_ra_virt + 1)) ;;
	esac
done
# eudev 3.2.14 sorts enumerate results with memcmp of the syspath.
# RetroArch opens ID_INPUT_JOYSTICK devnodes in that order and keeps
# a slot only when the node speaks EV_KEY. js nodes fail that open.
# A path that is a prefix of another makes strcmp and memcmp disagree,
# so that case does not guess a slot.
_ra_slot=
_ra_list=$(mktemp "${TMPDIR:-/tmp}/zlyme-ra-joy.XXXXXX") || _ra_list=
if [ -n "$_ra_list" ]; then
	for _ra_ev in "$_ra_sys"/event*; do
		[ -e "$_ra_ev" ] || continue
		[ -r "$_ra_ev/dev" ] || continue
		_ra_dev=$(tr -d '\r\n' < "$_ra_ev/dev")
		_ra_major=${_ra_dev%%:*}
		_ra_minor=${_ra_dev#*:}
		[ -n "$_ra_major" ] && [ -n "$_ra_minor" ] && [ "$_ra_major" != "$_ra_dev" ] || continue
		[ -r "$_ra_db/c${_ra_major}:${_ra_minor}" ] || continue
		grep -q 'ID_INPUT_JOYSTICK=1' "$_ra_db/c${_ra_major}:${_ra_minor}" || continue
		_ra_parent=$(readlink -f "$_ra_ev/device" 2>/dev/null || true)
		if [ -z "$_ra_parent" ] || [ ! -r "$_ra_parent/name" ]; then
			continue
		fi
		_ra_evpath=$(readlink -f "$_ra_ev" 2>/dev/null || true)
		[ -n "$_ra_evpath" ] || continue
		_ra_name=$(tr -d '\r\n' < "$_ra_parent/name")
		printf '%s\t%s\n' "$_ra_evpath" "$_ra_name" >> "$_ra_list"
	done
	_ra_prefix=0
	if [ -s "$_ra_list" ]; then
		while IFS=$(printf '\t') read -r _ra_evpath _ra_name; do
			while IFS=$(printf '\t') read -r _ra_other _ra_skip; do
				[ "$_ra_evpath" = "$_ra_other" ] && continue
				case "$_ra_other" in
					"$_ra_evpath"/*) _ra_prefix=1 ;;
				esac
				case "$_ra_evpath" in
					"$_ra_other"/*) _ra_prefix=1 ;;
				esac
			done < "$_ra_list"
		done < "$_ra_list"
	fi
	if [ "$_ra_prefix" = 0 ] && [ -s "$_ra_list" ]; then
		_ra_sorted=$(mktemp "${TMPDIR:-/tmp}/zlyme-ra-joy.XXXXXX") || _ra_sorted=
		if [ -n "$_ra_sorted" ]; then
			LC_ALL=C sort "$_ra_list" > "$_ra_sorted"
			_ra_i=0
			while IFS=$(printf '\t') read -r _ra_evpath _ra_name; do
				[ -n "$_ra_evpath" ] || continue
				case "$_ra_evpath" in
					*/devices/virtual/input/*)
						if [ "$_ra_name" = "Microsoft X-Box 360 pad" ]; then
							_ra_slot=$_ra_i
						fi
						;;
				esac
				_ra_i=$((_ra_i + 1))
			done < "$_ra_sorted"
			rm -f "$_ra_sorted"
		fi
	fi
	rm -f "$_ra_list"
fi
printf 'joypad_autoconfig_dir = "%s"\ninput_autodetect_enable = "true"\n' "$AC" > "$RA_AC"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
else
	export SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT="${SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:-0x045e/0x028e}"
fi
# No slot means the virtual pad was not found in the joystick list.
# Udev without an index leaves player 1 on slot 0, the physical pad.
if [ "$_ra_virt" -eq 1 ] && [ "$_ra_same" -eq 1 ] && [ -n "$_ra_slot" ]; then
	{
		printf 'input_driver = "sdl2"\ninput_joypad_driver = "udev"\n'
		printf 'input_player1_reserved_device = "Microsoft X-Box 360 pad"\n'
		printf 'input_player1_device_reservation_type = "2"\n'
		printf 'input_player1_joypad_index = "%s"\n' "$_ra_slot"
	} >> "$RA_AC"
else
	{
		printf 'input_driver = "sdl2"\ninput_joypad_driver = "sdl2"\n'
		printf 'input_player1_joypad_index = "0"\n'
		printf 'input_player1_device_reservation_type = "0"\n'
	} >> "$RA_AC"
fi
unset _ra_virt _ra_same _ra_sys _ra_db _ra_d _ra_name _ra_node \
	_ra_slot _ra_list _ra_ev _ra_dev _ra_major _ra_minor _ra_parent \
	_ra_evpath _ra_prefix _ra_other _ra_skip _ra_sorted _ra_i
printf 'notification_show_autoconfig = "false"\nnotification_show_autoconfig_fails = "false"\n' >> "$RA_AC"

# Session-only output size. A non-zero video_fullscreen_x in the user
# file is left alone, and this does not write that file.
ra_user_mode() {
	_cfg=$CFGDIR/retroarch.cfg
	[ -f "$_cfg" ] || return 1
	awk '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*video_fullscreen_x[[:space:]]*=/ {
			v=$0
			sub(/^[^=]*=[[:space:]]*/, "", v)
			gsub(/["[:space:]]/, "", v)
			if (v ~ /^[0-9]+$/ && v+0 > 0)
				found=1
		}
		END { exit found ? 0 : 1 }
	' "$_cfg"
}
HDMI_RA=${ZLYME_HDMI_RA_CFG:-/tmp/zlyme-hdmi-ra.cfg}
rm -f "$HDMI_RA"
if [ "${ZLYME_HDMI_720P:-}" = 1 ]; then
	_hdmi_sh=${ZLYME_HDMI_SESSION:-/usr/share/zlyme/hdmi-session.sh}
	if [ -r "$_hdmi_sh" ]; then
		# shellcheck disable=SC1090
		. "$_hdmi_sh"
		zlyme_hdmi_apply || true
	fi
	if [ "${ZLYME_HDMI_ACTIVE:-}" = 1 ] && ! ra_user_mode; then
		{
			printf 'video_monitor_index = "%s"\n' "${ZLYME_HDMI_MONITOR}"
			printf 'video_fullscreen = "true"\n'
			printf 'video_fullscreen_x = "%s"\n' "${ZLYME_HDMI_WIDTH}"
			printf 'video_fullscreen_y = "%s"\n' "${ZLYME_HDMI_HEIGHT}"
			printf 'video_refresh_rate = "%s"\n' "${ZLYME_HDMI_REFRESH_HZ}"
		} > "$HDMI_RA"
	fi
fi

# RA 1.22 splits --appendconfig on '|', not comma.
APPEND=$RA_AC
[ -s "$MINUI_RA" ] && APPEND="$MINUI_RA|$APPEND"
[ -s "${HDMI_RA:-}" ] && APPEND="$APPEND|$HDMI_RA"
[ -s "${RA_SAVES:-}" ] && APPEND="$APPEND|$RA_SAVES"
if [ -n "${_ra_rom:-}" ] && [ -x /usr/sbin/zlyme-overlay ]; then
	_ov=$(/usr/sbin/zlyme-overlay for-rom "$_ra_rom" 2>/dev/null || true)
	if [ -n "$_ov" ] && [ -f "$_ov" ]; then
		APPEND="$APPEND|$_ov"
	fi
	unset _ov
fi

if [ -n "$ZLYME_RA_DRY_RUN" ]; then
	echo "APPEND=$APPEND"
	if [ "${1:-}" = "-L" ] && [ -n "${2:-}" ]; then
		echo "CORE=$2"
	fi
	exit 0
fi

command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true

if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi

/usr/bin/zlyme-drm-release

# MENU/Home (SDL GUIDE) opens RGUI. MENU+START is zlyme-pak-hotkey,
# which asks zlyme-pak-spawn to perform bounded TERM/KILL cleanup.
# RetroArch 1.22.2's Unix handler does not turn one SIGTERM into a quit, so that
# chord does not run retroarch_main_quit. Quit from the menu does.
if [ -n "$ZLYME_PAK_LOG" ]; then
	mkdir -p "$(dirname "$ZLYME_PAK_LOG")"
	exec retroarch -v --log-file "$ZLYME_PAK_LOG" --appendconfig "$APPEND" "$@"
fi
if [ -n "$ZLYME_RA_DEBUG" ]; then
	exec retroarch -v --log-file /tmp/ra-debug.log --appendconfig "$APPEND" "$@"
fi
exec retroarch --appendconfig "$APPEND" "$@"
