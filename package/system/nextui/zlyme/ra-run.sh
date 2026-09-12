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
MINUI_RA=/tmp/zlyme-minui-ra.cfg
MINUI_SETTINGS="${SHARED_USERDATA_PATH:-/storage/.userdata/shared}/minuisettings.txt"

mkdir -p "$CFGDIR"
if [ ! -s "$CFG" ]; then
	rm -f "$CFG"
	[ -f "$ETC" ] && cp "$ETC" "$CFG"
fi

# First-run core options from spruce Flip (frameskip/dynarec/resolution).
# Never overwrite a file the user already has.
if [ -d "$SEED_OPTS" ]; then
	for dir in "$SEED_OPTS"/*; do
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

# Map MinUI In-Game (minuisettings.txt) onto RetroArch. Minarch is not
# built yet; this is what makes Notifications / RetroAchievements apply
# when a pak execs ra-run.
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
		echo "notification_show_save_state = \"$show_state\""
		echo "notification_show_screenshot = \"$(ra_bool "$notify_shot")\""
		echo "notification_show_screenshot_duration = \"$shot_dur\""
		echo "video_font_enable = \"$font\""
	} > "$MINUI_RA"
}

write_minui_ra

APPEND="$ETC"
[ -s "$MINUI_RA" ] && APPEND="$ETC,$MINUI_RA"

if [ -n "$ZLYME_RA_DRY_RUN" ]; then
	echo "APPEND=$APPEND"
	exit 0
fi

# MENU (button 10) exits, matching NextUI. Select opens the RetroArch menu.
exec retroarch --appendconfig "$APPEND" "$@"
