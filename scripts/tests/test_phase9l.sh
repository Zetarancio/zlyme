#!/bin/sh
# Phase 9L: one resolve per launch, cached BIOS, defaults, format UI.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LIB="$ROOT/package/system/nextui/zlyme/zlyme-library.sh"
PY="$ROOT/board/my355/fsoverlay/usr/share/zlyme/bios-union.py"
DEF="$ROOT/package/system/nextui/emu-defaults.txt"
td=$(mktemp -d)
trap 'rm -rf "$td"' EXIT

# --- resolver runs once, BIOS tree is not walked again ---
main=$td/main
sd=$td/sd
mkdir -p "$main/Bios/GB" "$sd/Bios/GB" "$sd/Roms/Game Boy (GB)" \
	"$main/Roms/Game Boy Advance (GBA)" "$sd/Saves/GBA"
i=0
while [ "$i" -lt 200 ]; do
	printf 'b\n' > "$sd/Bios/GB/file$i.bin"
	i=$((i + 1))
done
printf 'win\n' > "$sd/Bios/GB/gb_bios.bin"
printf 'lose\n' > "$main/Bios/GB/gb_bios.bin"
printf 'r\n' > "$sd/Roms/Game Boy (GB)/game.gb"
printf 's\n' > "$sd/Saves/GBA/Quest.sav"
gba_rom=$main/Roms/Game\ Boy\ Advance\ \(GBA\)/Quest.gba
mkdir -p "$(dirname "$gba_rom")"
printf 'r\n' > "$gba_rom"
printf '%s\n' "$main" "$sd" > "$td/libs"
# shellcheck disable=SC1090
. "$LIB"
export ZLYME_LIBRARIES_FILE=$td/libs
export ZLYME_RUN_DIR=$td/run
export ZLYME_BIOS_PY=$PY
export EMU_TAG=GBA
zlyme_library_for "$gba_rom"
test "$ZLYME_RESOLVE_COUNT" = 1
test "$ZLYME_BIOS_SCANS" = 1
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = lose
zlyme_library_for "$gba_rom"
test "$ZLYME_RESOLVE_COUNT" = 1
test "$ZLYME_BIOS_SCANS" = 1
test "$SAVES_PATH" = "$sd/Saves"
# existing save is on the other card
unset ZLYME_RESOLVED_ROM
zlyme_library_for "$gba_rom"
# BIOS cache still valid
test "$ZLYME_BIOS_SCANS" = 1
got=$(zlyme_save_root "$gba_rom" GBA)
test "$got" = "$sd"
# A second winning card gets its own view. Returning does not rescan.
unset ZLYME_RESOLVED_ROM
zlyme_library_for "$sd/Roms/Game Boy (GB)/game.gb"
test "$ZLYME_BIOS_SCANS" = 2
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = win
unset ZLYME_RESOLVED_ROM
zlyme_library_for "$gba_rom"
test "$ZLYME_BIOS_SCANS" = 2
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = lose

# PAK sources must not resolve again after pak-log
if grep -n zlyme_library_for "$ROOT/package/system/nextui/paks/Emus/PICO.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Emus/P8.pak/launch.sh"; then
	echo "PICO/P8 resolve after pak-log" >&2
	exit 1
fi
if ! grep -q 'ZLYME_RESOLVED_ROM' "$ROOT/package/system/nextui/zlyme/ra-run.sh"; then
	echo "ra-run always resolves" >&2
	exit 1
fi

# --- defaults match launchers ---
want() {
	tag=$1
	id=$2
	got=$(awk -v t="$tag" '$1==t { print $2; exit }' "$DEF")
	test "$got" = "$id"
}
want GBA gpsp
want PS pcsx_rearmed
want MD picodrive
want MS genesis_plus_gx
want GG genesis_plus_gx
want PICO native
want P8 fake08
for pak in "$ROOT"/package/system/nextui/paks/Emus/*.pak/launch.sh; do
	tag=$(basename "$(dirname "$pak")" .pak)
	exe=$(sed -n 's/^EMU_EXE=//p' "$pak" | head -n 1)
	[ -n "$exe" ] || continue
	got=$(awk -v t="$tag" '$1==t { print $2; exit }' "$DEF")
	if [ "$got" != "$exe" ]; then
		echo "$tag default $got != launcher $exe" >&2
		exit 1
	fi
done

# --- menu copy is explicitly two lines ---
ui=$ROOT/../zlyme-nextui/workspace/all/settings/zlymemenu.cpp
grep -q 'Reset standalone emulator settings.\\nGames and saves are kept.' "$ui"

# The nested minui format UI is gone. Native Settings is test_format_native.sh.
if [ -e "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-format-ui" ]; then
	echo "zlyme-format-ui still shipped" >&2
	exit 1
fi

echo "phase9l ok"
