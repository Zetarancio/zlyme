#!/bin/sh
# Phase 9K host checks: BIOS union, save root, Splore visibility, clock.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LIB="$ROOT/package/system/nextui/zlyme/zlyme-library.sh"
CLEAN="$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh"
SPLORE="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pico-splore"
CARD="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-card-defaults"
RT="$ROOT/board/my355/fsoverlay/usr/share/zlyme/pico-runtime.sh"
td=$(mktemp -d)
trap 'rm -rf "$td"' EXIT

# --- BIOS union ---
main=$td/main
sd2="$td/sd two"
usb=$td/usb
mkdir -p "$main/Bios/GB" "$sd2/Bios/GB" "$usb/Bios/PS" \
	"$main/Bios/Nested Dir" "$sd2/Roms/Game Boy (GB)"
printf 'main-gb' > "$main/Bios/GB/gb_bios.bin"
printf 'sd-gb' > "$sd2/Bios/GB/gb_bios.bin"
printf 'usb-only' > "$usb/Bios/PS/scph1001.bin"
printf 'space' > "$main/Bios/Nested Dir/file name.bin"
printf 'rom' > "$sd2/Roms/Game Boy (GB)/game.gb"
printf '%s\n' "$main" "$sd2" "$usb" > "$td/libs"
sum_before=$(find "$main/Bios" "$sd2/Bios" "$usb/Bios" -type f -exec sha256sum {} \; | sort)
# shellcheck disable=SC1090
. "$LIB"
export ZLYME_LIBRARIES_FILE=$td/libs
export ZLYME_RUN_DIR=$td/run
export ZLYME_BIOS_PY=$ROOT/board/my355/fsoverlay/usr/share/zlyme/bios-union.py
zlyme_library_for "$sd2/Roms/Game Boy (GB)/game.gb"
test "${ZLYME_BIOS_SCANS:-0}" = 1
zlyme_library_for "$sd2/Roms/Game Boy (GB)/game.gb"
test "${ZLYME_RESOLVE_COUNT:-0}" = 1
test "${ZLYME_BIOS_SCANS:-0}" = 1
test -L "$td/run/bios/GB/gb_bios.bin"
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = sd-gb
test "$(cat "$td/run/bios/PS/scph1001.bin")" = usb-only
test "$(cat "$td/run/bios/Nested Dir/file name.bin")" = space
sum_after=$(find "$main/Bios" "$sd2/Bios" "$usb/Bios" -type f -exec sha256sum {} \; | sort)
test "$sum_before" = "$sum_after"
mkdir -p "$main/Roms/Game Boy (GB)"
printf 'rom' > "$main/Roms/Game Boy (GB)/game.gb"
zlyme_library_for "$main/Roms/Game Boy (GB)/game.gb"
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = main-gb
mkdir -p "$usb/Roms/Game Boy (GB)" "$usb/Bios/GB"
printf 'usb-gb' > "$usb/Bios/GB/gb_bios.bin"
printf 'rom' > "$usb/Roms/Game Boy (GB)/game.gb"
zlyme_library_for "$usb/Roms/Game Boy (GB)/game.gb"
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = usb-gb
test -f "$td/run/bios/PS/scph1001.bin"

# --- Saves ---
mkdir -p "$main/Saves/GBA" "$sd2/Saves/GBA" "$usb/Saves/GBA" \
	"$main/Roms/Game Boy Advance (GBA)" \
	"$sd2/Roms/Game Boy Advance (GBA)" \
	"$usb/Roms/Game Boy Advance (GBA)"
rom=$sd2/Roms/Game\ Boy\ Advance\ \(GBA\)/Quest.gba
printf 'r' > "$rom"
# no saves -> ROM card
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$sd2"
# empty dir does not count
mkdir -p "$main/Saves/GBA"
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$sd2"
# save only on another card
printf 's' > "$main/Saves/GBA/Quest.sav"
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$main"
# ROM card plus another card -> ROM card
printf 's' > "$sd2/Saves/GBA/Quest.sav"
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$sd2"
# unrelated files on the ROM card, exact save on USB
rm -f "$sd2/Saves/GBA/Quest.sav" "$main/Saves/GBA/Quest.sav"
printf 'other' > "$sd2/Saves/GBA/Other.sav"
printf 'exact' > "$usb/Saves/GBA/Quest.srm"
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$usb"
# standalone-style directory with no ROM-named file
rm -f "$usb/Saves/GBA/Quest.srm" "$sd2/Saves/GBA/Other.sav"
mkdir -p "$usb/Saves/PSP/SAVEDATA"
printf 'mem' > "$usb/Saves/PSP/SAVEDATA/ULUS.ppst"
psp=$sd2/Roms/Sony\ PlayStation\ Portable\ \(PSP\)/Game.iso
mkdir -p "$(dirname "$psp")"
printf 'i' > "$psp"
got=$(zlyme_save_root "$psp" PSP)
test "$got" = "$usb"

# per-ROM delete follows the selected root only
export ZLYME_LIBRARY_SH="$LIB"
export ZLYME_CLEANUP_ROOT=$main
export ZLYME_RECENT_FILE=$td/recent.txt
export ZLYME_ROM_PLAN=$td/plan
: > "$ZLYME_RECENT_FILE"
printf 'only' > "$main/Saves/GBA/Quest.sav"
rm -rf "$sd2/Saves/GBA" "$usb/Saves/GBA"
"$CLEAN" rom "$rom" --dry-run >/dev/null
grep -q "$main/Saves/GBA/Quest.sav" "$td/plan"
if grep -q "$sd2/Saves" "$td/plan"; then
	echo "delete planned the ROM card save dir" >&2
	exit 1
fi
# both copies: only the ROM card
mkdir -p "$sd2/Saves/GBA" "$usb/Saves/GBA"
printf 'romcard' > "$sd2/Saves/GBA/Quest.sav"
printf 'other' > "$usb/Saves/GBA/Quest.sav"
"$CLEAN" rom "$rom" --dry-run >/dev/null
grep -q "$sd2/Saves/GBA/Quest.sav" "$td/plan"
if grep -q "$usb/Saves/GBA/Quest.sav" "$td/plan"; then
	echo "delete planned a non-selected card" >&2
	exit 1
fi
if grep -q "$main/Saves/GBA/Quest.sav" "$td/plan"; then
	echo "delete planned the losing copy" >&2
	exit 1
fi

# --- Splore visibility ---
art=$td/art.p8
printf 'synthetic-splore' > "$art"
export ZLYME_PICO_ART=$art
export ZLYME_PICO_RUNTIME=$RT
export ZLYME_PICO_LIBRARIES=$td/pico-libs
unset ZLYME_PICO_ROMDIR
export ZLYME_PICO_SHARED=$td/native
mkdir -p "$td/native" "$main/Roms" "$sd2/Roms"
: > "$td/pico-libs"
"$SPLORE"
if [ -e "$main/Roms/Pico-8 (PICO)/000) Splore.p8" ]; then
	echo "splore seeded without a runtime" >&2
	exit 1
fi
mkdir -p "$sd2/Bios/PICO"
printf 'bin' > "$sd2/Bios/PICO/pico8_64"
printf 'dat' > "$sd2/Bios/PICO/pico8.dat"
printf '%s\n' "$main" "$sd2" > "$td/pico-libs"
"$SPLORE"
cmp -s "$art" "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
if [ -e "$main/Roms/Pico-8 (PICO)/000) Splore.p8" ]; then
	echo "splore seeded on a card with no runtime" >&2
	exit 1
fi
# user file is not deleted when the runtime goes away
mkdir -p "$main/Roms/Pico-8 (PICO)"
printf 'user-cart' > "$main/Roms/Pico-8 (PICO)/My Splore Game.p8"
rm -f "$sd2/Bios/PICO/pico8_64"
"$SPLORE"
if [ -e "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8" ]; then
	echo "owned splore survived a missing runtime" >&2
	exit 1
fi
grep -q 'user-cart' "$main/Roms/Pico-8 (PICO)/My Splore Game.p8"
# runtime only on main, with no other splore-named file in the way
rm -f "$main/Roms/Pico-8 (PICO)/My Splore Game.p8"
mkdir -p "$main/Bios/PICO"
printf 'bin' > "$main/Bios/PICO/pico8_64"
printf 'dat' > "$main/Bios/PICO/pico8.dat"
printf '%s\n' "$main" > "$td/pico-libs"
"$SPLORE"
cmp -s "$art" "$main/Roms/Pico-8 (PICO)/000) Splore.p8"

# --- Clock ---
export SHARED_USERDATA_PATH=$td/ui
export BIOS_PATH=$td/bios
export SAVES_PATH=$td/saves
export CHEATS_PATH=$td/cheats
mkdir -p "$td/ui"
"$CARD"
grep -q '^showclock=1$' "$td/ui/minuisettings.txt"
test -f "$td/ui/.zlyme-clock-on-default"
sed -i 's/^showclock=.*/showclock=0/' "$td/ui/minuisettings.txt"
"$CARD"
grep -q '^showclock=0$' "$td/ui/minuisettings.txt"
rm -f "$td/ui/minuisettings.txt" "$td/ui/.zlyme-clock-on-default"
"$CARD"
grep -q '^showclock=1$' "$td/ui/minuisettings.txt"

# --- Source regressions that are not separate binaries ---
wifi=$ROOT/../zlyme-nextui/workspace/all/settings/wifimenu.cpp
if [ -f "$wifi" ]; then
	grep -q 'i == countryItem' "$wifi"
	grep -q 'items.push_back(countryItem)' "$wifi"
fi
ui=$ROOT/../zlyme-nextui/workspace/all/nextui/nextui.c
if [ -f "$ui" ]; then
	awk '
		/currentScreen == SCREEN_EDITPREFS/ { on = 1 }
		on && /currentScreen == SCREEN_QUICKMENU/ { on = 0 }
		on && /PAD_tappedMenu/ { bad = 1 }
		END { exit bad ? 1 : 0 }
	' "$ui" || {
		echo "edit prefs still treats menu release as back" >&2
		exit 1
	}
	grep -q 'show_setting == 1' "$ui"
	grep -q 'Pico-8-native/bbs/carts' "$ui"
fi
plat=$ROOT/../zlyme-nextui/workspace/my355/platform/platform.h
if [ -f "$plat" ]; then
	grep -q 'define JOY_A' "$plat"
	awk '/define JOY_A/ { print $3 }' "$plat" | grep -qx 0
	awk '/define JOY_B/ { print $3 }' "$plat" | grep -qx 1
fi

echo "phase9k ok"
