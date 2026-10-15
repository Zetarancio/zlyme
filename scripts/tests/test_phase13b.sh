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
grep -q 'input_menu_swap_ok_cancel_buttons = "false"' "$SEED" \
	|| fail "menu swap is not false in the stock configuration"
if grep -q 'input_menu_swap_ok_cancel_buttons = "true"' "$SEED"; then
	fail "menu swap is true in the stock configuration"
fi
if grep -q 'input_menu_swap_ok_cancel_buttons\|savestate_auto_\|quit_on_close_content\|rgui_menu_color_theme' \
	"$ETC" "$PERF"; then
	fail "a retired append file still sets a user preference"
fi

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
grep -qx 'quit_on_close_content = "2"' "$SEED" \
	|| fail "stock configuration lost CLI close behavior"
[ ! -e "$work/xdg-quit/retroarch/retroarch.cfg" ] \
	|| fail "ra-run created a user configuration"

# Flycast's stock keys stay in the seed. An existing cfg is not edited.
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
cp "$work/fly-xdg/flycast/emu.cfg" "$work/fly-before"
PATH=$work/fly-bin:/usr/bin:/bin \
	XDG_CONFIG_HOME=$work/fly-xdg \
	USERDATA_PATH=$work/fly-home \
	BIOS_PATH=$work/fly-bios \
	SAVES_PATH=$work/fly-saves \
	sh "$fly" "$work/fly-roms/game.cdi"
cmp -s "$work/fly-before" "$work/fly-xdg/flycast/emu.cfg" \
	|| fail "flycast rewrote an existing configuration"
if grep -q '^Dreamcast.AutoLoadState =' "$work/fly-xdg/flycast/emu.cfg"; then
	fail "flycast added a missing auto load"
fi
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
printf '%s\n' "$b2" | grep -q 'does not validate this policy' \
	|| fail "B2 treats the old host test as the new policy"
b5=$(awk '
	/^##### B5\. / { on = 1; next }
	on && /^##### / { exit }
	on { print }
' "$ROOT/docs/ROADMAP.md")
printf '%s\n' "$b5" | grep -q 'Status: Host-tested' || fail "B5 is not host-tested"
printf '%s\n' "$b5" | grep -q 'does not validate this policy' \
	|| fail "B5 treats the old host test as the new policy"
printf '%s\n' "$b5" | grep -q 'tmpfs symlink' \
	|| fail "B5 dropped the superseded core-view note"
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
