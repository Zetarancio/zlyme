#!/bin/sh
# Phase 13B: RetroArch menu mapping, Classic Orange, resume, user cores,
# the Tools launcher, FBNeo BIOS order, and the README lockup.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

fail() {
	echo "phase 13b: $*" >&2
	exit 1
}

RA=$ROOT/package/system/nextui/zlyme/ra-run.sh
STAGE=$ROOT/package/system/nextui/zlyme/arcade-stage.sh
LAUNCH=$ROOT/package/system/nextui/paks/Tools/RetroArch.pak/launch.sh
ETC=$ROOT/board/my355/fsoverlay/etc/retroarch.cfg
SEED=$ROOT/board/my355/fsoverlay/usr/share/zlyme/retroarch/retroarch.cfg
PERF=$ROOT/board/my355/fsoverlay/usr/share/zlyme/emu-defaults/ra-perf.cfg
PAD=$ROOT/package/emulators/retroarch/zlyme/autoconfig/sdl2/Microsoft\ X-Box\ 360\ pad.cfg
MK=$ROOT/package/emulators/retroarch/retroarch.mk

grep -q 'input_a_btn = "0"' "$PAD" || fail "RetroPad A is not SDL button 0"
grep -q 'input_b_btn = "1"' "$PAD" || fail "RetroPad B is not SDL button 1"
if grep -q 'input_a_btn = "1"' "$PAD" || grep -q 'input_b_btn = "0"' "$PAD"; then
	fail "autoconfig swaps A and B"
fi
for cfg in "$ETC" "$SEED" "$PERF"; do
	grep -q 'input_menu_swap_ok_cancel_buttons = "false"' "$cfg" \
		|| fail "menu swap is not false in $cfg"
	if grep -q 'input_menu_swap_ok_cancel_buttons = "true"' "$cfg"; then
		fail "menu swap is true in $cfg"
	fi
done

if grep -q '^rgui_menu_color_theme ' "$ETC" "$PERF"; then
	fail "an append config still sets the theme"
fi
seed_theme=$(grep '^rgui_menu_color_theme ' "$SEED")
[ "$seed_theme" = 'rgui_menu_color_theme = "2"' ] || fail "seed theme is $seed_theme"
if grep -q 'rgui_menu_color_theme = "Classic Orange"' "$ETC" "$SEED" "$PERF" "$RA"; then
	fail "Classic Orange was written as a config value"
fi
if grep -q 'rgui_menu_color_theme = "custom"' "$ETC" "$SEED" "$PERF"; then
	fail "shipped config still forces the Zlyme theme"
fi
if grep -q 'rgui-theme.cfg' "$RA" "$MK"; then
	fail "rgui-theme.cfg is still referenced"
fi
if grep -q 'assets-rgui-zlyme' "$MK"; then
	fail "retroarch.mk still installs the Zlyme palette"
fi
for gone in \
	"$ROOT/package/emulators/retroarch/zlyme/rgui-theme.cfg" \
	"$ROOT/package/emulators/retroarch/zlyme/assets-rgui-zlyme.cfg" \
	"$ROOT/board/my355/fsoverlay/usr/share/zlyme/retroarch/rgui-theme.cfg"
do
	[ ! -e "$gone" ] || fail "theme file still exists: $gone"
done
if grep -R -q 'menu_rgui_internal_upscale_level\|menu_scale_factor' \
	"$ETC" "$SEED" "$PERF" "$RA"; then
	fail "an unsupported RGUI scale key was added"
fi

work=$(mktemp -d)
view_live=/tmp/zlyme-ra-cores
bind_live=/tmp/zlyme-flycast-bind
view_aside=
bind_aside=
if [ -e "$view_live" ] || [ -L "$view_live" ]; then
	view_aside=$work/aside-view
	mv "$view_live" "$view_aside"
fi
if [ -e "$bind_live" ] || [ -L "$bind_live" ]; then
	bind_aside=$work/aside-bind
	mv "$bind_live" "$bind_aside"
fi
cleanup_13b() {
	if [ -L "$view_live" ]; then
		rm -f "$view_live"
	elif [ -d "$view_live" ]; then
		rm -rf "$view_live"
	fi
	if [ -n "$view_aside" ]; then
		mv "$view_aside" "$view_live"
	fi
	if [ -L "$bind_live" ] || [ -e "$bind_live" ]; then
		rm -f "$bind_live"
	fi
	if [ -n "$bind_aside" ]; then
		mv "$bind_aside" "$bind_live"
	fi
	rm -rf "$work"
}
trap cleanup_13b EXIT

stock_cfg() {
	cat > "$1" << 'EOF'
video_driver = "vulkan"
input_player1_a_btn = "9"
input_player1_b_btn = "8"
rgui_menu_color_theme = "custom"
rgui_theme_preset = "/usr/share/retroarch/assets/rgui/zlyme.cfg"
rgui_entry_normal_color = "0xFFF2F3F5"
rgui_entry_hover_color = "0xFFFA7C08"
rgui_title_color = "0xFFFA7C08"
rgui_bg_dark_color = "0xFF050608"
rgui_bg_light_color = "0xFF050608"
rgui_border_dark_color = "0xFFEC2A01"
rgui_border_light_color = "0xFFFA7C08"
EOF
}

run_ra() {
	xdg=$1
	etc=$2
	fault=${3:-}
	if [ $# -ge 3 ]; then
		shift 3
	else
		shift 2
	fi
	mkdir -p "$xdg" "$work/bios" "$work/shared" "$work/sys-cores"
	: > "$work/bios/.zlyme-ready"
	# A missing TMPDIR proves the cfg rewrite does not use mktemp's default.
	XDG_CONFIG_HOME=$xdg \
		ZLYME_RA_ETC=$etc \
		BIOS_PATH=$work/bios \
		SHARED_USERDATA_PATH=$work/shared \
		ZLYME_RA_DRY_RUN=1 \
		ZLYME_RA_MIGRATE_FAULT=$fault \
		ZLYME_RA_CORES_CFG=${ZLYME_RA_CORES_CFG:-$work/ra-cores.cfg} \
		ZLYME_RA_SYSTEM_CORES=${ZLYME_RA_SYSTEM_CORES:-$work/sys-cores} \
		ZLYME_RA_USER_CORES=${ZLYME_RA_USER_CORES:-$xdg/retroarch/cores} \
		ZLYME_RA_MINUI=${ZLYME_RA_MINUI:-$work/minui.cfg} \
		ZLYME_RA_SAVES=${ZLYME_RA_SAVES:-$work/ra-saves.cfg} \
		SAVES_PATH="${SAVES_PATH:-}" \
		EMU_TAG="${EMU_TAG:-}" \
		ZLYME_RESOLVED_ROM="${ZLYME_RESOLVED_ROM:-}" \
		ZLYME_EMU_CORE="${ZLYME_EMU_CORE:-}" \
		TMPDIR=$work/missing-tmp \
		sh "$RA" "$@"
}

# A new cfg gets Classic Orange and keeps the copied keys.
printf '%s\n' 'video_fullscreen = "true"' > "$work/etc-fresh"
run_ra "$work/xdg-fresh" "$work/etc-fresh" >/dev/null
fresh=$work/xdg-fresh/retroarch/retroarch.cfg
grep -qx 'video_fullscreen = "true"' "$fresh" || fail "fresh cfg dropped /etc"
grep -qx 'rgui_menu_color_theme = "2"' "$fresh" || fail "fresh cfg missed Classic Orange"
theme_n=$(grep -c '^rgui_menu_color_theme ' "$fresh")
[ "$theme_n" = 1 ] || fail "fresh cfg has $theme_n theme lines"
grep -qx 'savestate_auto_save = "true"' "$fresh" || fail "fresh cfg missed auto save"
grep -qx 'savestate_auto_load = "true"' "$fresh" || fail "fresh cfg missed auto load"
grep -qx 'quit_on_close_content = "2"' "$fresh" || fail "fresh cfg missed quit on close"
for cfg in "$ETC" "$PERF"; do
	if grep -q '^savestate_auto_save \|^savestate_auto_load \|^quit_on_close_content ' "$cfg"; then
		fail "append config forces a user resume key: $cfg"
	fi
done

# The original Zlyme block becomes 2. A saved game remap stays.
stock_cfg "$work/user-stock"
mkdir -p "$work/xdg-stock/retroarch"
cp "$work/user-stock" "$work/xdg-stock/retroarch/retroarch.cfg"
printf '%s\n' 'video_fullscreen = "true"' > "$work/etc-stock"
run_ra "$work/xdg-stock" "$work/etc-stock" >/dev/null
stock=$work/xdg-stock/retroarch/retroarch.cfg
grep -qx 'rgui_menu_color_theme = "2"' "$stock" || fail "stock theme was not migrated"
grep -qx 'video_driver = "vulkan"' "$stock" || fail "migration dropped video_driver"
grep -qx 'input_player1_a_btn = "9"' "$stock" || fail "migration rewrote A"
grep -qx 'input_player1_b_btn = "8"' "$stock" || fail "migration rewrote B"
if grep -q 'zlyme.cfg' "$stock" || grep -q 'rgui_entry_hover_color' "$stock"; then
	fail "migration left the Zlyme palette"
fi
touch -d '2020-01-01 00:00:00' "$stock"
before=$(stat -c %Y "$stock")
run_ra "$work/xdg-stock" "$work/etc-stock" >/dev/null
theme_n=$(grep -c '^rgui_menu_color_theme ' "$stock")
[ "$theme_n" = 1 ] || fail "second launch duplicated the theme"
after=$(stat -c %Y "$stock")
[ "$before" = "$after" ] || fail "second launch rewrote an already migrated cfg"
left=$(find "$work/xdg-stock/retroarch" -type f | wc -l)
[ "$left" = 1 ] || fail "migration left a temporary file"

# An incomplete write keeps the original cfg and removes the temp.
mkdir -p "$work/xdg-short/retroarch"
cp "$work/user-stock" "$work/xdg-short/retroarch/retroarch.cfg"
short=$work/xdg-short/retroarch/retroarch.cfg
cp "$short" "$work/short-before"
touch -d '2020-01-01 00:00:00' "$short"
before=$(stat -c %Y "$short")
run_ra "$work/xdg-short" "$work/etc-stock" write >/dev/null
cmp -s "$short" "$work/short-before" || fail "incomplete write replaced the cfg"
after=$(stat -c %Y "$short")
[ "$before" = "$after" ] || fail "incomplete write changed the cfg mtime"
left=$(find "$work/xdg-short/retroarch" -type f | wc -l)
[ "$left" = 1 ] || fail "incomplete write left a temporary file"

# A failed rename keeps the original cfg and removes the temp.
mkdir -p "$work/xdg-ren/retroarch"
cp "$work/user-stock" "$work/xdg-ren/retroarch/retroarch.cfg"
ren=$work/xdg-ren/retroarch/retroarch.cfg
cp "$ren" "$work/ren-before"
run_ra "$work/xdg-ren" "$work/etc-stock" rename >/dev/null
cmp -s "$ren" "$work/ren-before" || fail "failed rename replaced the cfg"
left=$(find "$work/xdg-ren/retroarch" -type f | wc -l)
[ "$left" = 1 ] || fail "failed rename left a temporary file"

# The fault seam is dry-run only. The same request still migrates.
mkdir -p "$work/xdg-live/retroarch"
cp "$work/user-stock" "$work/xdg-live/retroarch/retroarch.cfg"
live=$work/xdg-live/retroarch/retroarch.cfg
mkdir -p "$work/stub-path"
cat > "$work/stub-path/retroarch" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$work/stub-path/retroarch"
ZLYME_RA_MIGRATE_FAULT=rename \
	XDG_CONFIG_HOME=$work/xdg-live \
	ZLYME_RA_ETC=$work/etc-stock \
	BIOS_PATH=$work/bios \
	SHARED_USERDATA_PATH=$work/shared \
	TMPDIR=$work/missing-tmp \
	ZLYME_RA_CORES_CFG=$work/ra-cores.cfg \
	ZLYME_RA_SYSTEM_CORES=$work/sys-cores \
	PATH=$work/stub-path:/usr/bin:/bin \
	sh "$RA" >/dev/null 2>&1 || true
grep -qx 'rgui_menu_color_theme = "2"' "$live" \
	|| fail "fault seam ran without a dry run"
left=$(find "$work/xdg-live/retroarch" -type f | wc -l)
[ "$left" = 1 ] || fail "live migration left a temporary file"

# RetroArch's numeric rewrite of the same default migrates too.
sed 's/rgui_menu_color_theme = "custom"/rgui_menu_color_theme = "0"/' \
	"$work/user-stock" > "$work/xdg-zero.cfg"
mkdir -p "$work/xdg-zero/retroarch"
cp "$work/xdg-zero.cfg" "$work/xdg-zero/retroarch/retroarch.cfg"
run_ra "$work/xdg-zero" "$work/etc-stock" >/dev/null
grep -qx 'rgui_menu_color_theme = "2"' "$work/xdg-zero/retroarch/retroarch.cfg" \
	|| fail "theme 0 was not migrated"

# A changed color is a user theme.
sed 's/0xFFFA7C08/0xFF112233/' "$work/user-stock" > "$work/user-own"
mkdir -p "$work/xdg-own/retroarch"
cp "$work/user-own" "$work/xdg-own/retroarch/retroarch.cfg"
run_ra "$work/xdg-own" "$work/etc-stock" >/dev/null
own=$work/xdg-own/retroarch/retroarch.cfg
grep -qx 'rgui_menu_color_theme = "custom"' "$own" || fail "custom theme was replaced"
grep -qx 'rgui_entry_hover_color = "0xFF112233"' "$own" || fail "custom color was replaced"
grep -qx 'input_player1_a_btn = "9"' "$own" || fail "custom cfg lost the remap"

# A saved built-in theme stays, including its remap.
mkdir -p "$work/xdg-user/retroarch"
cat > "$work/xdg-user/retroarch/retroarch.cfg" << 'EOF'
rgui_menu_color_theme = "4"
input_player1_a_btn = "9"
input_player1_b_btn = "8"
EOF
run_ra "$work/xdg-user" "$work/etc-stock" >/dev/null
user=$work/xdg-user/retroarch/retroarch.cfg
grep -qx 'rgui_menu_color_theme = "4"' "$user" || fail "user theme 4 was replaced"
if grep -qx 'rgui_menu_color_theme = "2"' "$user"; then
	fail "Classic Orange was appended over a user theme"
fi
grep -qx 'input_player1_a_btn = "9"' "$user" || fail "user remap was rewritten"

# Two theme lines are not the exact Zlyme default.
cat "$work/user-stock" > "$work/xdg-two.cfg"
printf '%s\n' 'rgui_menu_color_theme = "4"' >> "$work/xdg-two.cfg"
mkdir -p "$work/xdg-two/retroarch"
cp "$work/xdg-two.cfg" "$work/xdg-two/retroarch/retroarch.cfg"
run_ra "$work/xdg-two" "$work/etc-stock" >/dev/null
two=$work/xdg-two/retroarch/retroarch.cfg
grep -qx 'rgui_menu_color_theme = "custom"' "$two" || fail "mixed theme lost custom"
grep -qx 'rgui_menu_color_theme = "4"' "$two" || fail "mixed theme lost 4"

# An explicit resume choice stays. A missing key is filled in once.
mkdir -p "$work/xdg-pref/retroarch"
cat > "$work/xdg-pref/retroarch/retroarch.cfg" << 'EOF'
savestate_auto_save = "false"
savestate_auto_load = "false"
quit_on_close_content = "0"
input_player1_a_btn = "9"
EOF
pref=$work/xdg-pref/retroarch/retroarch.cfg
run_ra "$work/xdg-pref" "$work/etc-stock" >/dev/null
grep -qx 'savestate_auto_save = "false"' "$pref" || fail "auto save preference was overwritten"
grep -qx 'savestate_auto_load = "false"' "$pref" || fail "auto load preference was overwritten"
grep -qx 'quit_on_close_content = "0"' "$pref" || fail "quit preference was overwritten"
grep -qx 'input_player1_a_btn = "9"' "$pref" || fail "preference cfg lost the remap"
if grep -qx 'quit_on_close_content = "1"' "$pref"; then
	fail "quit on close was forced on"
fi
touch -d '2020-01-01 00:00:00' "$pref"
before=$(stat -c %Y "$pref")
run_ra "$work/xdg-pref" "$work/etc-stock" >/dev/null
after=$(stat -c %Y "$pref")
[ "$before" = "$after" ] || fail "second launch rewrote a settled preference"

mkdir -p "$work/xdg-half/retroarch"
printf '%s\n' 'savestate_auto_save = "false"' > "$work/xdg-half/retroarch/retroarch.cfg"
half=$work/xdg-half/retroarch/retroarch.cfg
run_ra "$work/xdg-half" "$work/etc-stock" >/dev/null
grep -qx 'savestate_auto_save = "false"' "$half" || fail "partial preference lost auto save"
grep -qx 'savestate_auto_load = "true"' "$half" || fail "missing auto load was not added"
grep -qx 'quit_on_close_content = "2"' "$half" || fail "missing quit on close was not added"

# Hardcore is applied from NextUI on each launch. The automatic load
# key stays; RetroArch skips the load while hardcore is active.
printf '%s\n' 'raEnable=1' 'raHardcoreMode=1' > "$work/shared/minuisettings.txt"
run_ra "$work/xdg-half" "$work/etc-stock" >/dev/null
grep -qx 'cheevos_hardcore_mode_enable = "true"' "$work/minui.cfg" \
	|| fail "hardcore was not passed to RetroArch"
grep -qx 'savestate_auto_load = "true"' "$half" \
	|| fail "hardcore rewrote automatic load"
out=$(run_ra "$work/xdg-half" "$work/etc-stock")
printf '%s\n' "$out" | grep -q "APPEND=.*$work/minui.cfg" \
	|| fail "hardcore snippet is not appended"

# Save RAM and savestates follow the card that holds the ROM.
rom=$work/same.gb
: > "$rom"
syscore=$work/sys-cores/mgba_libretro.so
printf '%s\n' system > "$syscore"
SAVES_PATH=$work/card1/Saves EMU_TAG=GB ZLYME_RESOLVED_ROM=$rom \
	ZLYME_RA_SAVES=$work/saves-card1.cfg \
	run_ra "$work/xdg-card" "$work/etc-stock" '' -L "$syscore" "$rom" >/dev/null
grep -qx "savefile_directory = \"$work/card1/Saves/GB\"" "$work/saves-card1.cfg" \
	|| fail "card 1 save RAM path"
grep -qx "savestate_directory = \"$work/card1/Saves/GB\"" "$work/saves-card1.cfg" \
	|| fail "card 1 savestate path"
SAVES_PATH=$work/card2/Saves EMU_TAG=GB ZLYME_RESOLVED_ROM=$rom \
	ZLYME_RA_SAVES=$work/saves-card2.cfg \
	run_ra "$work/xdg-card" "$work/etc-stock" '' -L "$syscore" "$rom" >/dev/null
grep -qx "savefile_directory = \"$work/card2/Saves/GB\"" "$work/saves-card2.cfg" \
	|| fail "card 2 save RAM path"
grep -qx "savestate_directory = \"$work/card2/Saves/GB\"" "$work/saves-card2.cfg" \
	|| fail "card 2 savestate path"
if grep -q 'card1' "$work/saves-card2.cfg"; then
	fail "card 2 reused card 1 saves"
fi

# The tool execs ra-run and passes no content.
stub=$work/bin
mkdir -p "$stub"
cat > "$stub/ra-run" << 'EOF'
#!/bin/sh
printf '%s\n' "$#" > "$OUT/argc"
i=1
for a in "$@"; do
	printf '%s\n' "$a" > "$OUT/arg-$i"
	i=$((i + 1))
done
EOF
chmod 0755 "$stub/ra-run"
OUT=$work/launch
export OUT
mkdir -p "$OUT"
PATH=$stub:/usr/bin:/bin sh "$LAUNCH"
[ "$(cat "$OUT/argc")" = 0 ] || fail "RetroArch tool passed arguments"
[ ! -e "$OUT/arg-1" ] || fail "RetroArch tool passed a ROM"
grep -q 'exec ra-run$' "$LAUNCH" || fail "tool does not exec ra-run"
if grep -q 'retroarch' "$LAUNCH"; then
	fail "tool launches retroarch on its own"
fi
grep -q 'paks/Tools' "$ROOT/package/system/nextui/nextui.mk" \
	|| fail "Tools paks are not installed from the package"

# FBNeo BIOS order. The game archive wins. MAME's order stays.
bios=$work/bios-arc
roms=$work/roms
mkdir -p "$roms"
printf '%s\n' 'game' > "$roms/game.zip"

reset_bios() {
	rm -rf "$bios"
	mkdir -p "$bios/fbneo" "$bios/FBNEO" "$bios/mame2003-plus" "$bios/MAME"
}

linked() {
	tag=$1
	rom=$2
	name=$3
	out=$(BIOS_PATH=$bios sh "$STAGE" "$tag" "$rom")
	dest=$(dirname "$out")
	readlink "$dest/$name"
}

reset_bios
printf '%s\n' 'fb' > "$bios/fbneo/neogeo.zip"
printf '%s\n' 'up' > "$bios/FBNEO/neogeo.zip"
printf '%s\n' 'root' > "$bios/neogeo.zip"
got=$(linked FBNEO "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/fbneo/neogeo.zip" ] || fail "FBNeo preferred $got"

reset_bios
rmdir "$bios/fbneo"
printf '%s\n' 'up' > "$bios/FBNEO/neogeo.zip"
printf '%s\n' 'root' > "$bios/neogeo.zip"
got=$(linked FBNEO "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/FBNEO/neogeo.zip" ] || fail "FBNeo fallback preferred $got"

reset_bios
rmdir "$bios/fbneo" "$bios/FBNEO"
printf '%s\n' 'root' > "$bios/neogeo.zip"
got=$(linked FBNEO "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/neogeo.zip" ] || fail "FBNeo Bios/ fallback preferred $got"

reset_bios
printf '%s\n' 'game' > "$roms/neogeo.zip"
printf '%s\n' 'fb' > "$bios/fbneo/neogeo.zip"
got=$(linked FBNEO "$roms/neogeo.zip" neogeo.zip)
[ "$got" = "$roms/neogeo.zip" ] || fail "game archive lost to $got"

reset_bios
printf '%s\n' 'fb' > "$bios/fbneo/neogeo.zip"
printf '%s\n' 'root' > "$bios/neogeo.zip"
got=$(linked MAME "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/neogeo.zip" ] || fail "MAME order changed to $got"

reset_bios
printf '%s\n' 'tag' > "$bios/MAME/neogeo.zip"
printf '%s\n' 'plus' > "$bios/mame2003-plus/neogeo.zip"
got=$(linked MAME "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/MAME/neogeo.zip" ] || fail "MAME tag dir lost to $got"

reset_bios
rmdir "$bios/MAME"
printf '%s\n' 'plus' > "$bios/mame2003-plus/neogeo.zip"
got=$(linked MAME "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/mame2003-plus/neogeo.zip" ] || fail "MAME dropped mame2003-plus ($got)"

reset_bios
rmdir "$bios/fbneo" "$bios/FBNEO"
printf '%s\n' 'mame' > "$bios/MAME/neogeo.zip"
got=$(linked FBNEO "$roms/game.zip" neogeo.zip)
[ "$got" = "$bios/MAME/neogeo.zip" ] || fail "FBNeo dropped a MAME-only BIOS ($got)"

reset_bios
printf '%s\n' 'z' > "$bios/fbneo/foo.7z"
got=$(linked FBNEO "$roms/game.zip" foo.7z)
[ "$got" = "$bios/fbneo/foo.7z" ] || fail "FBNeo missed a 7z BIOS ($got)"

# Close Content is CLI mode. A game passes -L and a ROM. The tool does not.
# Quit from the menu is RetroArch's own exit. MENU+START stays SIGTERM
# then SIGKILL for every pak.
grep -q 'exec retroarch --appendconfig' "$RA" || fail "ra-run no longer execs retroarch"
if grep -q 'retroarch' "$ROOT/package/system/nextui/zlyme/zlyme-pak-hotkey.c"; then
	fail "the emergency hotkey special-cases RetroArch"
fi
grep -q 'kill(-pgid, SIGTERM);' "$ROOT/package/system/nextui/zlyme/zlyme-pak-hotkey.c" \
	|| fail "emergency exit no longer sends SIGTERM"
grep -q 'kill(-pgid, SIGKILL);' "$ROOT/package/system/nextui/zlyme/zlyme-pak-hotkey.c" \
	|| fail "emergency exit no longer sends SIGKILL"
grep -q 'exec ra-run -L' "$ROOT/package/system/nextui/paks/Emus/GB.pak/launch.sh" \
	|| fail "a game launcher no longer passes a core and ROM"
out=$(run_ra "$work/xdg-quit" "$work/etc-stock" '' -L "$work/sys-cores/mgba_libretro.so" "$work/same.gb")
printf '%s\n' "$out" | grep -q '^CORE=' || fail "game launch did not report a core"
grep -qx 'quit_on_close_content = "2"' "$work/xdg-quit/retroarch/retroarch.cfg" \
	|| fail "game launch did not keep CLI close behavior"

# User cores. The tmpfs view links packaged names, then user names.
# A same-name user file wins. Removing it restores the packaged link
# on the next launch. The file itself is not inspected.
if grep -q 'core_elf_ok\|hexdump\|ZLYME_RA_CORE_UNION\|rm -rf' "$RA"; then
	fail "ra-run still has the old core validator or an inherited delete"
fi
cores_fn=$(awk '/^do_ra_cores\(\)/,/^}/' \
	"$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh")
printf '%s\n' "$cores_fn" | grep -q 'retroarch/config' \
	|| fail "core-option reset no longer targets retroarch/config"
printf '%s\n' "$cores_fn" | grep -q 'retroarch/cores' \
	&& fail "core-option reset removes user core libraries"
sysc=$work/sys-cores
userc=$work/user-cores
view=/tmp/zlyme-ra-cores
rm -rf "$view"
mkdir -p "$sysc" "$userc"
printf '%s\n' system-mgba > "$sysc/mgba_libretro.so"
printf '%s\n' system-fake > "$sysc/fake08_libretro.so"
printf '%s\n' system-mupen > "$sysc/mupen64plus-next_libretro.so"
sys_mgba_ino=$(stat -c %i "$sysc/mgba_libretro.so")
missing_user=$work/no-user-cores
out=$(ZLYME_RA_USER_CORES=$missing_user ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$view/mgba_libretro.so" ] || fail "missing user dir did not use the view ($core)"
[ "$(readlink "$view/mgba_libretro.so")" = "$sysc/mgba_libretro.so" ] \
	|| fail "missing user dir hid the packaged core"
[ ! -e "$missing_user" ] || fail "a missing user directory was created"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$(readlink "$core")" = "$sysc/mgba_libretro.so" ] \
	|| fail "an empty user directory replaced the packaged core"
[ -L "$view/fake08_libretro.so" ] || fail "a second packaged core was not listed"
[ "$(readlink "$view/fake08_libretro.so")" = "$sysc/fake08_libretro.so" ] \
	|| fail "the second packaged core points at the wrong file"

printf '%s\n' user-only > "$userc/only_libretro.so"
printf '%s\n' user-mgba > "$userc/mgba_libretro.so"
printf '%s\n' not-a-core > "$userc/notes.so"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$view/mgba_libretro.so" ] || fail "override was not selected from the view ($core)"
[ "$(readlink "$core")" = "$userc/mgba_libretro.so" ] \
	|| fail "same-name user core did not replace the packaged core"
[ "$(stat -c %i "$userc/mgba_libretro.so")" = "$(stat -c %i "$(readlink "$core")")" ] \
	|| fail "the view copied the user core"
[ "$(stat -c %i "$sysc/mgba_libretro.so")" = "$sys_mgba_ino" ] \
	|| fail "the packaged core was replaced"
[ "$(cat "$sysc/mgba_libretro.so")" = system-mgba ] || fail "the packaged core was rewritten"
[ -L "$view/only_libretro.so" ] || fail "a user-only core was not listed"
[ "$(readlink "$view/only_libretro.so")" = "$userc/only_libretro.so" ] \
	|| fail "a user-only core points at the wrong file"
[ -L "$view/fake08_libretro.so" ] || fail "an unrelated packaged core disappeared"
[ ! -e "$view/notes.so" ] || fail "a non-libretro name was published"
[ -z "$(find "$userc" "$sysc" -type l -print)" ] || fail "a symlink was written onto a core directory"
[ -z "$(find "$view" -type f -print)" ] || fail "the view contains a copied library"

rm -f "$userc/mgba_libretro.so"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$(readlink "$core")" = "$sysc/mgba_libretro.so" ] \
	|| fail "removing the user core did not restore the packaged core"
[ -L "$view/only_libretro.so" ] || fail "the next launch dropped the user-only core"

printf '%s\n' user-fake > "$userc/fake08_libretro.so"
out=$(ZLYME_EMU_CORE=fake08 ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$(readlink "$core")" = "$userc/fake08_libretro.so" ] \
	|| fail "alternate user core was not selected"
rm -f "$userc/fake08_libretro.so"
out=$(ZLYME_EMU_CORE=fake08 ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$(readlink "$core")" = "$sysc/fake08_libretro.so" ] \
	|| fail "alternate packaged core was not the fallback"

out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' \
	-L "$sysc/mupen64plus_next_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$view/mupen64plus-next_libretro.so" ] || fail "mupen alias missed the view ($core)"
[ "$(readlink "$core")" = "$sysc/mupen64plus-next_libretro.so" ] \
	|| fail "mupen alias resolved to the wrong file"
printf '%s\n' user-mupen > "$userc/mupen64plus_next_libretro.so"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' \
	-L "$sysc/mupen64plus_next_libretro.so" "$work/same.gb")
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$(readlink "$core")" = "$userc/mupen64plus_next_libretro.so" ] \
	|| fail "a user mupen name lost to the packaged alias"

out=$(SAVES_PATH=$work/card2/Saves EMU_TAG=GB ZLYME_RESOLVED_ROM=$work/same.gb \
	ZLYME_RA_SAVES=$work/saves-core-card.cfg \
	ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/only_libretro.so" "$work/same.gb")
grep -qx "savestate_directory = \"$work/card2/Saves/GB\"" "$work/saves-core-card.cfg" \
	|| fail "user core changed the card 2 savestate path"

victim=$work/core-victim
mkdir -p "$victim/nested"
printf '%s\n' keep > "$victim/keep"
out=$(ZLYME_RA_CORE_UNION="$victim" \
	ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock")
dir=$(printf '%s\n' "$out" | awk -F= '/^LIBRETRO_DIRECTORY=/ { print substr($0, index($0, "=") + 1) }')
[ "$dir" = "$view" ] || fail "an inherited core directory was used ($dir)"
[ -f "$victim/keep" ] || fail "an inherited core path was deleted"
[ ! -e "$victim/mgba_libretro.so" ] || fail "an inherited path received a core link"

rm -rf "$view"
ln -s "$victim" "$view"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock" '' -L "$sysc/mgba_libretro.so" "$work/same.gb")
printf '%s\n' "$out" | grep -q '^LIBRETRO_DIRECTORY=' \
	&& fail "a symlinked core directory was accepted"
[ -f "$victim/keep" ] || fail "a symlinked core directory was deleted"
[ ! -e "$victim/mgba_libretro.so" ] || fail "a symlinked core directory received a link"
[ ! -e "$victim/nested/secret" ] || fail "a symlinked core directory was written"
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$sysc/mgba_libretro.so" ] || fail "refused view did not keep the packaged core ($core)"
rm -f "$view"

mkdir -p "$view/nested"
printf '%s\n' keep > "$view/keep_libretro.so"
printf '%s\n' secret > "$view/nested/secret"
printf '%s\n' packaged-keep > "$sysc/keep_libretro.so"
out=$(ZLYME_RA_USER_CORES=$userc ZLYME_RA_SYSTEM_CORES=$sysc \
	run_ra "$work/xdg-core" "$work/etc-stock")
[ -f "$view/keep_libretro.so" ] || fail "cleanup removed a regular file"
[ ! -L "$view/keep_libretro.so" ] || fail "cleanup replaced a regular file"
[ "$(cat "$view/keep_libretro.so")" = keep ] || fail "cleanup rewrote a regular file"
[ -f "$view/nested/secret" ] || fail "cleanup entered a subdirectory"
[ -L "$view/mgba_libretro.so" ] || fail "a safe view stopped listing packaged cores"
grep -q 'menu_show_core_updater = "false"' "$ETC" || fail "core updater menu is enabled"
grep -q -- '--disable-update_cores' "$MK" || fail "core updater build is enabled"

# Flycast's own keys. An explicit no stays. A missing key is added.
grep -q '^Dreamcast.AutoSaveState = yes$' \
	"$ROOT/board/my355/fsoverlay/usr/share/zlyme/emu-defaults/flycast/emu.cfg" \
	|| fail "flycast seed missed auto save"
grep -q '^Dreamcast.AutoLoadState = yes$' \
	"$ROOT/board/my355/fsoverlay/usr/share/zlyme/emu-defaults/flycast/emu.cfg" \
	|| fail "flycast seed missed auto load"
fly=$ROOT/package/system/nextui/paks/Emus/DC.pak/launch.sh
pak_launch=$ROOT/package/system/nextui/zlyme/pak-launch.sh
mkdir -p "$work/fly-bin" "$work/fly-home" "$work/fly-xdg/flycast" \
	"$work/fly-bios" "$work/fly-saves" "$work/fly-roms"
cat > "$work/fly-bin/flycast" << 'EOF'
#!/bin/sh
exit 0
EOF
cat > "$work/fly-bin/mount" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 0755 "$work/fly-bin/flycast" "$work/fly-bin/mount"
cat > "$work/fly-xdg/flycast/emu.cfg" << 'EOF'
[input]
device1 = 0
[config]
Dynarec.Enabled = yes
Dreamcast.AutoSaveState = no
EOF
PATH=$work/fly-bin:/usr/bin:/bin \
	XDG_CONFIG_HOME=$work/fly-xdg \
	USERDATA_PATH=$work/fly-home \
	BIOS_PATH=$work/fly-bios \
	SAVES_PATH=$work/fly-saves \
	sh "$fly" "$work/fly-roms/game.cdi"
grep -qx 'Dreamcast.AutoSaveState = no' "$work/fly-xdg/flycast/emu.cfg" \
	|| fail "flycast overwrote an explicit no"
grep -qx 'Dreamcast.AutoLoadState = yes' "$work/fly-xdg/flycast/emu.cfg" \
	|| fail "flycast did not add a missing auto load"
grep -qx 'Dynarec.Enabled = yes' "$work/fly-xdg/flycast/emu.cfg" \
	|| fail "flycast resume rewrite dropped a setting"
touch -d '2020-01-01 00:00:00' "$work/fly-xdg/flycast/emu.cfg"
before=$(stat -c %Y "$work/fly-xdg/flycast/emu.cfg")
PATH=$work/fly-bin:/usr/bin:/bin \
	XDG_CONFIG_HOME=$work/fly-xdg \
	USERDATA_PATH=$work/fly-home \
	BIOS_PATH=$work/fly-bios \
	SAVES_PATH=$work/fly-saves \
	sh "$fly" "$work/fly-roms/game.cdi"
after=$(stat -c %Y "$work/fly-xdg/flycast/emu.cfg")
[ "$before" = "$after" ] || fail "flycast rewrote a cfg that already had both keys"
if grep -E '^[[:space:]]*trap[[:space:]]' "$fly"; then
	fail "DC.pak still unmounts from an EXIT trap"
fi
grep -q 'exec flycast' "$fly" || fail "DC.pak no longer execs flycast"
awk '
	/^run_pak_cmd\(\)/ { on = 1 }
	on && $1 == "wait" { saw_wait = 1 }
	on && /flycast_bind_release/ && saw_wait { saw_release = 1 }
	on && /^}/ { exit }
	END { exit saw_release ? 0 : 1 }
' "$pak_launch" || fail "the session does not release the Flycast bind after wait"

mount_log=$work/mount.log
umount_log=$work/umount.log
fly_mark=$work/fly.mark
: > "$mount_log"
: > "$umount_log"
rm -f "$bind_live"
cat > "$work/fly-bin/mount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_MOUNT_LOG"
exit 0
EOF
cat > "$work/fly-bin/umount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_UMOUNT_LOG"
exit 0
EOF
cat > "$work/fly-bin/mountpoint" << 'EOF'
#!/bin/sh
if [ "$1" = -q ]; then
	shift
fi
grep -F -q -- "$1" "$ZLYME_TEST_MOUNT_LOG"
EOF
cat > "$work/fly-bin/flycast" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_TEST_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_FLY_MARK"
	exit 3
fi
grep -F -q -- flycast "$ZLYME_TEST_MOUNT_LOG" || exit 4
echo played > "$ZLYME_TEST_FLY_MARK"
exit 7
EOF
chmod 0755 "$work/fly-bin/mount" "$work/fly-bin/umount" \
	"$work/fly-bin/mountpoint" "$work/fly-bin/flycast"
set +e
PATH=$work/fly-bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	ZLYME_TEST_FLY_MARK=$fly_mark \
	XDG_CONFIG_HOME=$work/fly-xdg \
	XDG_DATA_HOME=$work/fly-xdg \
	USERDATA_PATH=$work/fly-home \
	BIOS_PATH=$work/fly-bios \
	SAVES_PATH=$work/fly-saves \
	sh "$fly" "$work/fly-roms/game.cdi"
fly_st=$?
set -e
[ "$fly_st" = 7 ] || fail "Flycast exit status was not preserved ($fly_st)"
grep -qx played "$fly_mark" || fail "Flycast did not run while the bind was held"
[ ! -s "$umount_log" ] || fail "the launcher unmounted Flycast before it exited"
bind_path=$(cat "$bind_live")
[ "$bind_path" = "$work/fly-xdg/flycast" ] || fail "Flycast bind record was $bind_path"
# shellcheck disable=SC1090
. "$pak_launch"
PATH=$work/fly-bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	flycast_bind_release
grep -qx -- "$work/fly-xdg/flycast" "$umount_log" \
	|| fail "the session did not unmount the Flycast bind"
[ ! -e "$bind_live" ] || fail "a released Flycast bind record was kept"

printf '%s\n' '/tmp/not-flycast' > "$bind_live"
: > "$umount_log"
PATH=$work/fly-bin:/usr/bin:/bin flycast_bind_release
[ ! -s "$umount_log" ] || fail "a non-flycast path was unmounted"
[ ! -e "$bind_live" ] || fail "an invalid Flycast bind record was kept"
printf '%s\n' '/tmp/../storage/flycast' > "$bind_live"
PATH=$work/fly-bin:/usr/bin:/bin flycast_bind_release
[ ! -s "$umount_log" ] || fail "a Flycast bind path with .. was unmounted"
printf '%s\n' "$work/fly-xdg/flycast" > "$bind_live"
cat > "$work/fly-bin/umount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_UMOUNT_LOG"
exit 1
EOF
chmod 0755 "$work/fly-bin/umount"
: > "$umount_log"
PATH=$work/fly-bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	flycast_bind_release
grep -qx -- "$work/fly-xdg/flycast" "$umount_log" \
	|| fail "a busy Flycast bind was not attempted"
[ -f "$bind_live" ] || fail "a busy Flycast bind record was dropped"
rm -f "$bind_live"

# Retired theme files are removed from an existing target tree.
# post-build.sh does more than this cleanup, so run only those rm lines.
fake=$work/target
mkdir -p "$fake/usr/share/retroarch/assets/rgui" \
	"$fake/usr/share/zlyme/retroarch" \
	"$fake/usr/share/retroarch/autoconfig"
printf '%s\n' old > "$fake/usr/share/retroarch/rgui-theme.cfg"
printf '%s\n' old > "$fake/usr/share/retroarch/assets/rgui/zlyme.cfg"
printf '%s\n' old > "$fake/usr/share/zlyme/retroarch/rgui-theme.cfg"
printf '%s\n' keep > "$fake/usr/share/retroarch/assets/rgui/font.png"
printf '%s\n' keep > "$fake/usr/share/retroarch/retroarch.cfg"
printf '%s\n' keep > "$fake/usr/share/retroarch/autoconfig/keep.cfg"
rms=$(awk '/^rm -f "\$\{TARGET_DIR\}\/usr\/share\/(retroarch\/rgui-theme\.cfg|retroarch\/assets\/rgui\/zlyme\.cfg|zlyme\/retroarch\/rgui-theme\.cfg)"$/ { print }' \
	"$ROOT/board/my355/post-build.sh")
[ "$(printf '%s\n' "$rms" | wc -l)" = 3 ] || fail "post-build theme cleanup is not three files"
TARGET_DIR=$fake bash -c "$rms"
[ ! -e "$fake/usr/share/retroarch/rgui-theme.cfg" ] || fail "target kept rgui-theme.cfg"
[ ! -e "$fake/usr/share/retroarch/assets/rgui/zlyme.cfg" ] || fail "target kept zlyme.cfg"
[ ! -e "$fake/usr/share/zlyme/retroarch/rgui-theme.cfg" ] || fail "target kept the zlyme theme copy"
[ -f "$fake/usr/share/retroarch/assets/rgui/font.png" ] || fail "cleanup removed an upstream asset"
[ -f "$fake/usr/share/retroarch/retroarch.cfg" ] || fail "cleanup removed retroarch.cfg"
[ -f "$fake/usr/share/retroarch/autoconfig/keep.cfg" ] || fail "cleanup removed an autoconfig"
if grep -q 'rm -rf .*retroarch/assets' "$ROOT/board/my355/post-build.sh"; then
	fail "post-build wipes the RetroArch asset tree"
fi

# README lockup is centered and the GIF bytes are unchanged.
readme=$(head -n 3 "$ROOT/README.md")
expected=$(cat << 'EOF'
<p align="center">
  <img src="package/system/nextui/res/branding/zlyme_slime_loop.gif" alt="Zlyme" width="444">
</p>
EOF
)
[ "$readme" = "$expected" ] || fail "README lockup is not centered"
gif=$ROOT/package/system/nextui/res/branding/zlyme_slime_loop.gif
sum=$(sha256sum "$gif" | awk '{print $1}')
[ "$sum" = "7d6e7534f4ee965ab266ec6e04bf7be3b5bb4dd175e03b6745c6a8c2cc7f960c" ] \
	|| fail "README GIF hash changed"

if grep -q 'Icy_Mammoth1805' "$ROOT/README.md" "$ROOT/CHANGELOG.md"; then
	fail "the FBNeo credit landed in the README or changelog"
fi

b2=$(awk '
	/^##### B2\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b2" | grep -q 'Status: Host-tested' || fail "B2 is not host-tested"
b5=$(awk '
	/^##### B5\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b5" | grep -q 'Status: Host-tested' || fail "B5 is not host-tested"
printf '%s\n' "$b5" | grep -q '/tmp/zlyme-ra-cores' || fail "B5 lost the tmpfs core view"
printf '%s\n' "$b5" | grep -q 'hexdump' && fail "B5 still documents the ELF header check"
grep -q 'source you trust' "$ROOT/docs/USER_GUIDE.md" \
	|| fail "the user guide does not say a user core must be trusted"
grep -q 'source you trust' "$ROOT/CHANGELOG.md" \
	|| fail "the changelog does not say a user core must be trusted"
b7=$(awk '
	/^##### B7\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b7" | grep -q 'Status: Host-tested' || fail "B7 is not host-tested"
b6=$(awk '
	/^##### B6\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b6" | grep -q 'Status: Blocked' || fail "B6 is not blocked"
printf '%s\n' "$b6" | grep -q '320×240' || fail "B6 lost the RGUI limit"
grep -q 'Phase 13B is not complete' "$ROOT/docs/ROADMAP.md" \
	|| fail "Phase 13B was marked complete"

echo "phase 13b ok"
