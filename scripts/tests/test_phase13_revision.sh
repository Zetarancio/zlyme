#!/bin/sh
# Stock configuration, writable libretro cores, and arcade-stage removal.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

fail() {
	echo "phase 13 revision: $*" >&2
	exit 1
}

SEED=$ROOT/package/system/nextui/zlyme/zlyme-stock-seed
SYNC=$ROOT/package/system/nextui/zlyme/zlyme-core-sync
RA=$ROOT/package/system/nextui/zlyme/ra-run.sh
CLEAN=$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh
STOCK=$ROOT/board/my355/fsoverlay/usr/share/zlyme/retroarch/retroarch.cfg
FLY=$ROOT/board/my355/fsoverlay/usr/share/zlyme/emu-defaults/flycast/emu.cfg
SHARE=$ROOT/board/my355/fsoverlay/usr/share/zlyme

for key in \
	'rgui_menu_color_theme = "2"' \
	'savestate_auto_save = "true"' \
	'savestate_auto_load = "true"' \
	'quit_on_close_content = "2"' \
	'config_save_on_exit = "false"' \
	'libretro_directory = "/storage/.config/retroarch/cores"' \
	'menu_show_core_updater = "false"'
do
	grep -qx "$key" "$STOCK" || fail "stock RetroArch cfg missed: $key"
done
if grep -q 'rgui-theme.cfg\|rgui_theme_preset' "$STOCK" "$RA"; then
	fail "an obsolete RGUI preset is still shipped"
fi
grep -q -- '--disable-update_cores' "$ROOT/package/emulators/retroarch/retroarch.mk" \
	|| fail "core updater build is enabled"
if grep -E -q 'config_save_on_exit[[:space:]]*=' "$RA"; then
	fail "ra-run forces config_save_on_exit"
fi
if grep -q 'settle_user_cfg\|cfg_replace\|zlyme-ra-cores' "$RA"; then
	fail "ra-run still migrates a configuration or builds a core view"
fi
if grep -q 'fly_ensure_resume\|maple_sdl_joystick' \
	"$ROOT/package/system/nextui/paks/Emus/DC.pak/launch.sh"; then
	fail "Flycast still rewrites an existing configuration"
fi
grep -q '^Dreamcast.AutoSaveState = yes$' "$FLY" || fail "flycast stock missed auto save"
grep -q '^Dreamcast.AutoLoadState = yes$' "$FLY" || fail "flycast stock missed auto load"
for launcher in \
	"$ROOT/package/system/nextui/paks/Emus/FBNEO.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Emus/MAME.pak/launch.sh" \
	"$ROOT/package/system/nextui/nextui.mk"
do
	if grep -q 'zlyme-arcade-stage' "$launcher"; then
		fail "arcade staging is still referenced in $launcher"
	fi
done
[ ! -e "$ROOT/package/system/nextui/zlyme/arcade-stage.sh" ] \
	|| fail "arcade-stage.sh is still in the tree"
if grep -q 'stages BIOS\|Bios/FBNEO/' "$ROOT/docs/USER_GUIDE.md"; then
	fail "the user guide still describes staged or uppercase FBNeo BIOS"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Missing RetroArch configuration is the stock file. An existing file stays.
mkdir -p "$work/card/.config"
ZLYME_STOCK_ROOT=$work/card ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	sh "$SEED"
cmp -s "$STOCK" "$work/card/.config/retroarch/retroarch.cfg" \
	|| fail "a missing RetroArch cfg was not the stock file"
printf '%s\n' 'video_driver = "vulkan"' 'savestate_auto_save = "false"' \
	> "$work/card/.config/retroarch/retroarch.cfg"
cp "$work/card/.config/retroarch/retroarch.cfg" "$work/ra-user"
ZLYME_STOCK_ROOT=$work/card ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	sh "$SEED"
cmp -s "$work/ra-user" "$work/card/.config/retroarch/retroarch.cfg" \
	|| fail "seeding again changed an existing RetroArch cfg"

# Launches do not edit that file. Session paths are append-only.
mkdir -p "$work/bios" "$work/saves/GB" "$work/sys" "$work/user-cores"
printf '%s\n' packaged > "$work/sys/mgba_libretro.so"
printf '%s\n' packaged-mupen > "$work/sys/mupen64plus-next_libretro.so"
: > "$work/bios/.zlyme-ready"
before=$(stat -c %Y "$work/card/.config/retroarch/retroarch.cfg")
out=$(
	XDG_CONFIG_HOME=$work/card/.config \
		BIOS_PATH=$work/bios \
		SAVES_PATH=$work/saves \
		EMU_TAG=GB \
		ZLYME_RESOLVED_ROM=$work/game.gb \
		ZLYME_RA_DRY_RUN=1 \
		ZLYME_RA_SYSTEM_CORES=$work/sys \
		ZLYME_RA_USER_CORES=$work/user-cores \
		ZLYME_RA_MINUI=$work/minui.cfg \
		ZLYME_RA_SAVES=$work/ra-saves.cfg \
		sh "$RA" -L "$work/sys/mgba_libretro.so" "$work/game.gb"
)
after=$(stat -c %Y "$work/card/.config/retroarch/retroarch.cfg")
[ "$before" = "$after" ] || fail "ra-run changed the user configuration mtime"
cmp -s "$work/ra-user" "$work/card/.config/retroarch/retroarch.cfg" \
	|| fail "ra-run changed the user configuration bytes"
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$work/sys/mgba_libretro.so" ] || fail "packaged fallback was $core"
grep -q "$work/saves/GB" "$work/ra-saves.cfg" || fail "session save path was not appended"
if grep -q 'savestate_auto_save\|quit_on_close_content\|rgui_menu_color_theme\|config_save_on_exit' \
	"$work/ra-saves.cfg" "$work/minui.cfg" /tmp/zlyme-ra-ac.cfg; then
	fail "a session file forced a user preference"
fi
append=$(printf '%s\n' "$out" | awk -F= '/^APPEND=/ { print substr($0, index($0, "=") + 1) }')
case "$append" in
	*"$STOCK"*|*/etc/retroarch.cfg*|*/ra-perf.cfg*)
		fail "append includes a stock preference file: $append" ;;
esac
# A second launch still leaves the edited file alone.
XDG_CONFIG_HOME=$work/card/.config \
	BIOS_PATH=$work/bios \
	SAVES_PATH=$work/saves \
	EMU_TAG=GB \
	ZLYME_RESOLVED_ROM=$work/game.gb \
	ZLYME_RA_DRY_RUN=1 \
	ZLYME_RA_SYSTEM_CORES=$work/sys \
	ZLYME_RA_USER_CORES=$work/user-cores \
	ZLYME_RA_MINUI=$work/minui.cfg \
	ZLYME_RA_SAVES=$work/ra-saves.cfg \
	sh "$RA" -L "$work/sys/mgba_libretro.so" "$work/game.gb" >/dev/null
cmp -s "$work/ra-user" "$work/card/.config/retroarch/retroarch.cfg" \
	|| fail "a second launch changed the user configuration"

# The provisioned core wins. A missing one falls back. An alternate name works.
printf '%s\n' writable > "$work/user-cores/mgba_libretro.so"
out=$(
	XDG_CONFIG_HOME=$work/card/.config \
		BIOS_PATH=$work/bios \
		ZLYME_RA_DRY_RUN=1 \
		ZLYME_RA_SYSTEM_CORES=$work/sys \
		ZLYME_RA_USER_CORES=$work/user-cores \
		ZLYME_RA_MINUI=$work/minui.cfg \
		ZLYME_RA_SAVES=$work/ra-saves.cfg \
		sh "$RA" -L "$work/sys/mgba_libretro.so" "$work/game.gb"
)
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$work/user-cores/mgba_libretro.so" ] || fail "provisioned core was $core"
rm -f "$work/user-cores/mgba_libretro.so"
out=$(
	XDG_CONFIG_HOME=$work/card/.config \
		BIOS_PATH=$work/bios \
		ZLYME_EMU_CORE=mupen64plus_next \
		ZLYME_RA_DRY_RUN=1 \
		ZLYME_RA_SYSTEM_CORES=$work/sys \
		ZLYME_RA_USER_CORES=$work/user-cores \
		ZLYME_RA_MINUI=$work/minui.cfg \
		ZLYME_RA_SAVES=$work/ra-saves.cfg \
		sh "$RA" -L "$work/sys/mgba_libretro.so" "$work/game.gb"
)
core=$(printf '%s\n' "$out" | awk -F= '/^CORE=/ { print substr($0, index($0, "=") + 1) }')
[ "$core" = "$work/sys/mupen64plus-next_libretro.so" ] || fail "mupen alias was $core"

# Explicit reset installs the stock file and leaves saves, BIOS, and cores.
mkdir -p "$work/card/Saves" "$work/card/Bios" "$work/card/.config/retroarch/cores" \
	"$work/card/.config/retroarch/config"
printf '%s\n' save > "$work/card/Saves/keep.srm"
printf '%s\n' bios > "$work/card/Bios/keep.bin"
printf '%s\n' mine > "$work/card/.config/retroarch/cores/mine_libretro.so"
printf '%s\n' opt > "$work/card/.config/retroarch/config/Keep.opt"
ZLYME_STOCK_SEED=$SEED \
	ZLYME_STOCK_SHARE=$SHARE \
	ZLYME_DEVICE_CONF= \
	ZLYME_CLEANUP_ROOT=$work/card \
	ZLYME_LIBRARIES_FILE=$work/none \
	sh "$CLEAN" ra-cfg >/dev/null
cmp -s "$STOCK" "$work/card/.config/retroarch/retroarch.cfg" \
	|| fail "reset did not install the stock RetroArch cfg"
cmp -s "$work/card/Saves/keep.srm" /dev/stdin << 'EOF' || true
EOF
[ "$(cat "$work/card/Saves/keep.srm")" = save ] || fail "reset removed a save"
[ "$(cat "$work/card/Bios/keep.bin")" = bios ] || fail "reset removed a BIOS file"
[ "$(cat "$work/card/.config/retroarch/cores/mine_libretro.so")" = mine ] \
	|| fail "reset removed a core"
[ "$(cat "$work/card/.config/retroarch/config/Keep.opt")" = opt ] \
	|| fail "configuration reset removed core options"
ZLYME_STOCK_SEED=$SEED \
	ZLYME_STOCK_SHARE=$SHARE \
	ZLYME_DEVICE_CONF= \
	ZLYME_CLEANUP_ROOT=$work/card \
	ZLYME_LIBRARIES_FILE=$work/none \
	sh "$CLEAN" ra-cores >/dev/null
[ ! -e "$work/card/.config/retroarch/config/Keep.opt" ] \
	|| fail "core-option reset left the old option file"
[ "$(cat "$work/card/.config/retroarch/cores/mine_libretro.so")" = mine ] \
	|| fail "core-option reset removed a core"
[ -f "$work/card/.config/retroarch/config/FinalBurn Neo/FinalBurn Neo.opt" ] \
	|| fail "core-option reset did not restore a stock option"

# Writable cores: first copy, idle reboot, update, failure, and interruption.
src=$work/cores-src
dst=$work/cores-dst
stamp=$work/cores.stamp
refresh=$work/no-image
export ZLYME_CORE_REFRESH=$refresh
mkdir -p "$src"
printf '%s\n' one > "$src/a_libretro.so"
printf '%s\n' two > "$src/b_libretro.so"
sh "$SYNC" stamp "$src" "$stamp"
ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
cmp -s "$src/a_libretro.so" "$dst/a_libretro.so" || fail "first sync missed a"
cmp -s "$src/b_libretro.so" "$dst/b_libretro.so" || fail "first sync missed b"
stamp_a=$(stat -c %Y "$dst/a_libretro.so")
ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
[ "$(stat -c %Y "$dst/a_libretro.so")" = "$stamp_a" ] \
	|| fail "a reboot copied an unchanged core"
printf '%s\n' user-only > "$dst/custom_libretro.so"
printf '%s\n' replaced > "$dst/a_libretro.so"
ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
[ "$(cat "$dst/a_libretro.so")" = replaced ] \
	|| fail "a reboot overwrote a hand-replaced core"
[ "$(cat "$dst/custom_libretro.so")" = user-only ] \
	|| fail "a reboot removed a user-only core"
# A new image with the same core bytes still restores shipped names.
: > "$work/image-new"
printf '%s\n' replaced > "$dst/a_libretro.so"
ZLYME_CORE_REFRESH=$work/image-new \
	ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
[ "$(cat "$dst/a_libretro.so")" = one ] \
	|| fail "a new image left a replaced shipped core"
[ "$(cat "$dst/custom_libretro.so")" = user-only ] \
	|| fail "a new image removed a user-only core"
[ ! -e "$work/image-new" ] || fail "a finished image refresh left its marker"
export ZLYME_CORE_REFRESH=$refresh
printf '%s\n' one-new > "$src/a_libretro.so"
printf '%s\n' three > "$src/c_libretro.so"
rm -f "$src/b_libretro.so"
sh "$SYNC" stamp "$src" "$stamp"
ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
[ "$(cat "$dst/a_libretro.so")" = one-new ] || fail "update did not replace a shipped core"
[ "$(cat "$dst/c_libretro.so")" = three ] || fail "update did not add a shipped core"
[ "$(cat "$dst/b_libretro.so")" = two ] || fail "update removed a core the image no longer ships"
[ "$(cat "$dst/custom_libretro.so")" = user-only ] || fail "update removed a user-only core"
printf '%s\n' good > "$dst/a_libretro.so"
old_stamp=$(cat "$dst/.zlyme-core-set")
printf '%s\n' different > "$work/fail.stamp"
if ZLYME_CORE_TEST=1 ZLYME_CORE_FAIL=a_libretro.so \
	ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$work/fail.stamp \
	sh "$SYNC"; then
	fail "a failed copy was reported as success"
fi
[ "$(cat "$dst/a_libretro.so")" = good ] || fail "a failed copy destroyed the working core"
[ "$(cat "$dst/.zlyme-core-set")" = "$old_stamp" ] \
	|| fail "a failed copy recorded the new stamp"
: > "$work/image-fail"
printf '%s\n' good > "$dst/a_libretro.so"
if ZLYME_CORE_TEST=1 ZLYME_CORE_FAIL=a_libretro.so \
	ZLYME_CORE_REFRESH=$work/image-fail \
	ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"; then
	fail "a failed image refresh was reported as success"
fi
[ "$(cat "$dst/a_libretro.so")" = good ] \
	|| fail "a failed image refresh destroyed the working core"
[ -f "$work/image-fail" ] || fail "a failed image refresh cleared its marker"
export ZLYME_CORE_REFRESH=$refresh
printf '%s\n' "$(cat "$stamp")" > "$dst/.zlyme-core-set"
rm -f "$dst/c_libretro.so"
printf '%s\n' stale > "$stamp"
if ZLYME_CORE_TEST=1 ZLYME_CORE_STOP_AFTER=1 \
	ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"; then
	fail "an interrupted sync was reported as success"
fi
[ ! -f "$dst/.zlyme-core-set" ] || [ "$(cat "$dst/.zlyme-core-set")" != "$(cat "$stamp")" ] \
	|| fail "an interrupted sync recorded the new stamp"
ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$stamp \
	sh "$SYNC"
cmp -s "$src/c_libretro.so" "$dst/c_libretro.so" || fail "a resumed sync missed the new core"
[ "$(cat "$dst/.zlyme-core-set")" = "$(awk 'NR==1 { print; exit }' "$stamp")" ] \
	|| fail "a resumed sync did not record the stamp"
rm -f "$dst/c_libretro.so"
if ZLYME_CORE_TEST=1 ZLYME_CORE_AVAIL=0 \
	ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$work/other.stamp \
	sh "$SYNC" stamp "$src" "$work/other.stamp" \
	&& ZLYME_CORE_TEST=1 ZLYME_CORE_AVAIL=0 \
		ZLYME_CORE_SRC=$src ZLYME_CORE_DST=$dst ZLYME_CORE_STAMP=$work/other.stamp \
		sh "$SYNC"; then
	fail "a copy without free space was reported as success"
fi
[ ! -e "$dst/c_libretro.so" ] || fail "a copy without free space created the core"

INIT=$ROOT/package/boot/zlyme-initramfs/init
grep -q '/storage_root/.config/zlyme/os-image-new' "$INIT" \
	|| fail "initramfs does not mark a committed image"
grep -q 'os-image-new' "$SYNC" || fail "core sync ignores the image marker"

echo "phase 13 revision ok"
