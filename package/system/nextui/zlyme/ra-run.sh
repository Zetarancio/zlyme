#!/bin/sh
# NextUI sets HOME to userdata and XDG_CONFIG_HOME to /storage/.config.
# RetroArch then creates an empty retroarch.cfg that drops /etc hotkeys
# and looks for BIOS under ~/.config/retroarch/system.
#
# --appendconfig merges /etc (KMSDRM + MENU hotkeys + spruce performance)
# and a generated MinUI snippet (cheevos + OSD notifications).

CFGDIR="${XDG_CONFIG_HOME:-/storage/.config}/retroarch"
CFG=$CFGDIR/retroarch.cfg
# ZLYME_RA_ETC is a host-test override. The device uses /etc/retroarch.cfg.
ETC=${ZLYME_RA_ETC:-/etc/retroarch.cfg}
# RetroArch 1.22.2 menu/menu_defines.h: RGUI_THEME_CLASSIC_ORANGE is 2.
# The menu shows that number as "Classic Orange". The words are not a
# value this pin reads. Upstream's own default is Classic Green.
ZLYME_RGUI_CLASSIC_ORANGE='rgui_menu_color_theme = "2"'
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

# Exact line match. A changed color or preset is a user theme and stays.
cfg_has_exact() {
	_file=$1
	_want=$2
	[ -f "$_file" ] || return 1
	while IFS= read -r _line || [ -n "$_line" ]; do
		[ "$_line" = "$_want" ] && return 0
	done < "$_file"
	return 1
}

cfg_theme_count() {
	_file=$1
	_n=0
	while IFS= read -r _line || [ -n "$_line" ]; do
		case "$_line" in
			'rgui_menu_color_theme = "'*) _n=$((_n + 1)) ;;
		esac
	done < "$_file"
	printf '%s\n' "$_n"
}

# The old seed wrote theme "custom" plus this preset and these colors.
# "0" is the same enum if RetroArch rewrote the word. Anything else stays.
migrate_zlyme_rgui_theme() {
	_cfg=$1
	[ -f "$_cfg" ] || return 0
	cfg_has_exact "$_cfg" 'rgui_theme_preset = "/usr/share/retroarch/assets/rgui/zlyme.cfg"' || return 0
	for _need in \
		'rgui_entry_normal_color = "0xFFF2F3F5"' \
		'rgui_entry_hover_color = "0xFFFA7C08"' \
		'rgui_title_color = "0xFFFA7C08"' \
		'rgui_bg_dark_color = "0xFF050608"' \
		'rgui_bg_light_color = "0xFF050608"' \
		'rgui_border_dark_color = "0xFFEC2A01"' \
		'rgui_border_light_color = "0xFFFA7C08"'
	do
		cfg_has_exact "$_cfg" "$_need" || return 0
	done
	[ "$(cfg_theme_count "$_cfg")" = 1 ] || return 0
	if ! cfg_has_exact "$_cfg" 'rgui_menu_color_theme = "custom"' \
		&& ! cfg_has_exact "$_cfg" 'rgui_menu_color_theme = "0"'; then
		return 0
	fi
	_tmp=$(mktemp)
	_placed=0
	while IFS= read -r _line || [ -n "$_line" ]; do
		case "$_line" in
			'rgui_menu_color_theme = "custom"'|'rgui_menu_color_theme = "0"')
				if [ "$_placed" -eq 0 ]; then
					printf '%s\n' "$ZLYME_RGUI_CLASSIC_ORANGE"
					_placed=1
				fi
				;;
			'rgui_theme_preset = "/usr/share/retroarch/assets/rgui/zlyme.cfg"'|\
			'rgui_entry_normal_color = "0xFFF2F3F5"'|\
			'rgui_entry_hover_color = "0xFFFA7C08"'|\
			'rgui_title_color = "0xFFFA7C08"'|\
			'rgui_bg_dark_color = "0xFF050608"'|\
			'rgui_bg_light_color = "0xFF050608"'|\
			'rgui_border_dark_color = "0xFFEC2A01"'|\
			'rgui_border_light_color = "0xFFFA7C08"')
				;;
			*)
				printf '%s\n' "$_line"
				;;
		esac
	done < "$_cfg" > "$_tmp"
	mv "$_tmp" "$_cfg"
}

mkdir -p "$CFGDIR" "$CFGDIR/assets"
_ra_fresh=0
if [ ! -s "$CFG" ]; then
	rm -f "$CFG"
	[ -f "$ETC" ] && cp "$ETC" "$CFG"
	_ra_fresh=1
fi
# Theme is not part of --appendconfig. Those files used to force the
# Zlyme preset on every launch, which hid a theme saved in this cfg.
migrate_zlyme_rgui_theme "$CFG"
if [ "$_ra_fresh" = 1 ] && [ -f "$CFG" ] && [ "$(cfg_theme_count "$CFG")" = 0 ]; then
	printf '%s\n' "$ZLYME_RGUI_CLASSIC_ORANGE" >> "$CFG"
fi
unset _ra_fresh

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
	RA_SAVES=/tmp/zlyme-ra-saves.cfg
	{
		printf 'savefile_directory = "%s/%s"\n' "${SAVES_PATH:-/storage/Saves}" "$_ra_tag"
		printf 'savestate_directory = "%s/%s"\n' "${SAVES_PATH:-/storage/Saves}" "$_ra_tag"
		printf 'system_directory = "%s"\n' "${BIOS_PATH:-/storage/Bios}"
	} > "$RA_SAVES"
fi
if [ -n "${ZLYME_EMU_CORE:-}" ] && [ "$1" = "-L" ] && [ -n "$2" ]; then
	_core_dir=$(dirname "$2")
	_core_hit=$_core_dir/${ZLYME_EMU_CORE}_libretro.so
	if [ -f "$_core_hit" ]; then
		shift 2
		set -- -L "$_core_hit" "$@"
	fi
	unset _core_dir _core_hit
fi

AC=/usr/share/retroarch/autoconfig
if [ ! -f "$AC/sdl2/Microsoft X-Box 360 pad.cfg" ]; then
	if [ -f "/usr/share/zlyme/retroarch/autoconfig/sdl2/Microsoft X-Box 360 pad.cfg" ]; then
		AC=/usr/share/zlyme/retroarch/autoconfig
	fi
fi
RA_AC=/tmp/zlyme-ra-ac.cfg
printf 'joypad_autoconfig_dir = "%s"\ninput_autodetect_enable = "true"\n' "$AC" > "$RA_AC"

# RA 1.22's driver named "sdl" is SDL3 (libSDL3.so.0). We ship SDL2.
# pak-input.sh hides the physical pad. The virtual target is then SDL
# index 0. A saved player index of 1 was the kernel js number and
# pointed at nothing once the physical pad was hidden.
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
else
	export SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT="${SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:-0x045e/0x028e}"
fi
printf 'input_driver = "sdl2"\ninput_joypad_driver = "sdl2"\ninput_menu_toggle_btn = "5"\n' >> "$RA_AC"
printf 'input_player1_joypad_index = "0"\n' >> "$RA_AC"
# The physical pad used to log "not configured" and that string is the
# on-screen banner when notification_show_autoconfig_fails is true.
printf 'notification_show_autoconfig = "false"\nnotification_show_autoconfig_fails = "false"\n' >> "$RA_AC"

# RA 1.22 splits --appendconfig on '|', not comma.
APPEND="$ETC"
for extra in /usr/share/zlyme/emu-defaults/ra-perf.cfg /storage/.config/zlyme/ra-perf.cfg; do
	[ -s "$extra" ] && APPEND="$APPEND|$extra"
done
[ -s "$MINUI_RA" ] && APPEND="$APPEND|$MINUI_RA"
APPEND="$APPEND|$RA_AC"
[ -s "${RA_SAVES:-}" ] && APPEND="$APPEND|$RA_SAVES"
# Content-directory overlay. The map is keyed by the absolute folder,
# so the same system name on another card is a different entry.
if [ -n "${_ra_rom:-}" ] && [ -x /usr/sbin/zlyme-overlay ]; then
	_ov=$(/usr/sbin/zlyme-overlay for-rom "$_ra_rom" 2>/dev/null || true)
	if [ -n "$_ov" ] && [ -f "$_ov" ]; then
		APPEND="$APPEND|$_ov"
	fi
	unset _ov
fi

if [ -n "$ZLYME_RA_DRY_RUN" ]; then
	echo "APPEND=$APPEND"
	exit 0
fi

# Governor is owned by each pak's launch.sh so editing that file is enough.
# Modeset from NextUI can drop VOP2 TV props; re-apply before RA takes DRM.
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true

if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi

/usr/bin/zlyme-drm-release

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
if [ -n "$ZLYME_PAK_LOG" ]; then
	mkdir -p "$(dirname "$ZLYME_PAK_LOG")"
	exec retroarch -v --log-file "$ZLYME_PAK_LOG" --appendconfig "$APPEND" "$@"
fi
# ZLYME_RA_DEBUG is a manual switch, not the system log flag.
# Keep it on tmpfs so the session's LOGS_PATH export cannot
# turn it into a file on the card.
if [ -n "$ZLYME_RA_DEBUG" ]; then
	exec retroarch -v --log-file /tmp/ra-debug.log --appendconfig "$APPEND" "$@"
fi
exec retroarch --appendconfig "$APPEND" "$@"
