#!/bin/sh
# NextUI sets HOME to userdata and XDG_CONFIG_HOME to /storage/.config.
# RetroArch then creates an empty retroarch.cfg that drops /etc hotkeys
# and looks for BIOS under ~/.config/retroarch/system.
#
# --appendconfig merges /etc (KMSDRM + MENU hotkeys + spruce performance)
# and a generated MinUI snippet (cheevos + OSD notifications).

CFGDIR="${XDG_CONFIG_HOME:-/storage/.config}/retroarch"
CFG=$CFGDIR/retroarch.cfg
ETC=/etc/retroarch.cfg
SEED_OPTS=/usr/share/zlyme/retroarch/config
CARD_OPTS=/storage/.config/zlyme/retroarch/config
MINUI_RA=/tmp/zlyme-minui-ra.cfg
MINUI_SETTINGS="${SHARED_USERDATA_PATH:-/storage/.config/nextui/shared}/minuisettings.txt"

[ -r /etc/zlyme-gpu-env.sh ] && . /etc/zlyme-gpu-env.sh

# Spruce Flip: sdl2 + GameController. Export Flip + Linux Pro GUIDs so
# MENU is GUIDE (5) and a Switch Pro is the same pad NextUI already sees.
# Session CONFIG is Flip-only; replace it with the full file.
export SDL_GAMECONTROLLERCONFIG_FILE=/usr/lib/gamecontrollerdb.txt
if [ -f "$SDL_GAMECONTROLLERCONFIG_FILE" ]; then
	export SDL_GAMECONTROLLERCONFIG="$(grep -v '^#' "$SDL_GAMECONTROLLERCONFIG_FILE" | grep -v '^$')"
fi

mkdir -p "$CFGDIR" "$CFGDIR/assets"
if [ ! -s "$CFG" ]; then
	rm -f "$CFG"
	[ -f "$ETC" ] && cp "$ETC" "$CFG"
fi

# First-run core options from spruce Flip (frameskip/dynarec/resolution).
# Never overwrite a file the user already has. Card copy is for a live
# unit before the next image ships /usr/share.
seed_ra_opts() {
	src=$1
	[ -d "$src" ] || return 0
	for dir in "$src"/*; do
		[ -d "$dir" ] || continue
		name=${dir##*/}
		mkdir -p "$CFGDIR/config/$name"
		for f in "$dir"/*; do
			[ -f "$f" ] || continue
			bn=${f##*/}
			[ -e "$CFGDIR/config/$name/$bn" ] && continue
			cp "$f" "$CFGDIR/config/$name/$bn"
		done
	done
}
seed_ra_opts "$SEED_OPTS"
seed_ra_opts "$CARD_OPTS"

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

AC=/usr/share/zlyme/retroarch/autoconfig
if [ ! -f "$AC/sdl2/retrogame_joypad.cfg" ]; then
	if [ -f /storage/.config/retroarch/autoconfig/sdl2/retrogame_joypad.cfg ]; then
		AC=/storage/.config/retroarch/autoconfig
	elif [ -f /tmp/autoconfig/sdl2/retrogame_joypad.cfg ]; then
		AC=/tmp/autoconfig
	fi
fi
RA_AC=/tmp/zlyme-ra-ac.cfg
printf 'joypad_autoconfig_dir = "%s"\ninput_autodetect_enable = "true"\n' "$AC" > "$RA_AC"

# sdl2 follows /dev/input/js* (IMU is event-only). Flip is js0; a
# connected Switch Pro is otherwise P2, so GB/etc. ignore it. Prefer
# it as P1 (same assignment ES/Knulli does). Last appendconfig wins
# over a stale card ra-perf.cfg that still says udev.
printf 'input_driver = "sdl"\ninput_joypad_driver = "sdl2"\ninput_menu_toggle_btn = "5"\n' >> "$RA_AC"
pro_idx=
idx=0
for js in /dev/input/js*; do
	[ -c "$js" ] || continue
	sysname=$(cat /sys/class/input/${js##*/}/device/name 2>/dev/null) || continue
	case "$sysname" in
		*IMU*|*Accel*|*Gyro*) continue ;;
		*Pro\ Controller*|Nintendo\ Switch\ Pro*|Nintendo\ Co.*)
			pro_idx=$idx
			;;
	esac
	idx=$((idx + 1))
done
if [ -n "$pro_idx" ]; then
	printf 'input_player1_joypad_index = "%s"\n' "$pro_idx" >> "$RA_AC"
fi

APPEND="$ETC"
for extra in /usr/share/zlyme/emu-defaults/ra-perf.cfg /storage/.config/zlyme/ra-perf.cfg; do
	[ -s "$extra" ] && APPEND="$APPEND,$extra"
done
[ -s "$MINUI_RA" ] && APPEND="$APPEND,$MINUI_RA"
APPEND="$APPEND,$RA_AC"
THEME=/usr/share/zlyme/retroarch/rgui-theme.cfg
[ -s "$THEME" ] && APPEND="$APPEND,$THEME"

if [ -n "$ZLYME_RA_DRY_RUN" ]; then
	echo "APPEND=$APPEND"
	exit 0
fi

# Heavy cores (PPSSPP/Flycast/Mupen/Yaba/DraStic) take heavy; others play.
if command -v zlyme-governor >/dev/null 2>&1; then
	zlyme-governor emu "$@" >/dev/null 2>&1 || true
elif [ -x /usr/share/nextui/bin/governor.sh ]; then
	/usr/share/nextui/bin/governor.sh emu "$@" >/dev/null 2>&1 || true
fi
# Modeset from NextUI can drop VOP2 TV props; re-apply before RA takes DRM.
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true

if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi

# MENU/Home (SDL GUIDE) opens RGUI; MENU+Start is zlyme-pak-hotkey.
# Knulli installs mupen64plus-next_libretro.so; NextUI used underscore.
if [ "$1" = "-L" ] && [ -n "$2" ] && [ ! -f "$2" ]; then
	_core_dir=$(dirname "$2")
	_core_bn=$(basename "$2")
	_core_hit=
	case "$_core_bn" in
		mupen64plus_next_libretro.so)
			_core_hit=$_core_dir/mupen64plus-next_libretro.so
			;;
		mupen64plus-next_libretro.so)
			_core_hit=$_core_dir/mupen64plus_next_libretro.so
			;;
	esac
	if [ -n "$_core_hit" ] && [ -f "$_core_hit" ]; then
		shift 2
		set -- -L "$_core_hit" "$@"
	fi
	unset _core_dir _core_bn _core_hit
fi
if [ -n "$ZLYME_RA_DEBUG" ]; then
	exec retroarch -v --log-file "$LOGS_PATH/ra-debug.log" --appendconfig "$APPEND" "$@"
fi
exec retroarch --appendconfig "$APPEND" "$@"
