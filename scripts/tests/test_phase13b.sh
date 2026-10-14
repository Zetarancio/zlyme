#!/bin/sh
# Phase 13B1: RetroArch menu mapping, Classic Orange, the Tools launcher,
# FBNeo BIOS order, and the README lockup.
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
trap 'rm -rf "$work"' EXIT

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
	mkdir -p "$xdg" "$work/bios" "$work/shared"
	: > "$work/bios/.zlyme-ready"
	XDG_CONFIG_HOME=$xdg \
		ZLYME_RA_ETC=$etc \
		BIOS_PATH=$work/bios \
		SHARED_USERDATA_PATH=$work/shared \
		ZLYME_RA_DRY_RUN=1 \
		sh "$RA"
}

# A new cfg gets Classic Orange and keeps the copied keys.
printf '%s\n' 'video_fullscreen = "true"' > "$work/etc-fresh"
run_ra "$work/xdg-fresh" "$work/etc-fresh" >/dev/null
fresh=$work/xdg-fresh/retroarch/retroarch.cfg
grep -qx 'video_fullscreen = "true"' "$fresh" || fail "fresh cfg dropped /etc"
grep -qx 'rgui_menu_color_theme = "2"' "$fresh" || fail "fresh cfg missed Classic Orange"
theme_n=$(grep -c '^rgui_menu_color_theme ' "$fresh")
[ "$theme_n" = 1 ] || fail "fresh cfg has $theme_n theme lines"

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
run_ra "$work/xdg-stock" "$work/etc-stock" >/dev/null
theme_n=$(grep -c '^rgui_menu_color_theme ' "$stock")
[ "$theme_n" = 1 ] || fail "second launch duplicated the theme"

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
printf '%s\n' "$b2" | grep -q 'Status: Planned' || fail "B2 is no longer planned"
b6=$(awk '
	/^##### B6\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b6" | grep -q 'Status: Blocked' || fail "B6 is not blocked"
grep -q 'Phase 13B is not complete' "$ROOT/docs/ROADMAP.md" \
	|| fail "Phase 13B was marked complete"

echo "phase 13b ok"
