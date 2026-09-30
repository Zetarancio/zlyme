#!/bin/sh
# Phase 9L: one resolve per launch, cached BIOS, defaults, format UI.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LIB="$ROOT/package/system/nextui/zlyme/zlyme-library.sh"
PY="$ROOT/board/my355/fsoverlay/usr/share/zlyme/bios-union.py"
FMTUI="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-format-ui"
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
rom=$main/Roms/Game\ Boy\ Advance\ \(GBA\)/Quest.gba
mkdir -p "$(dirname "$rom")"
printf 'r\n' > "$rom"
printf '%s\n' "$main" "$sd" > "$td/libs"
# shellcheck disable=SC1090
. "$LIB"
export ZLYME_LIBRARIES_FILE=$td/libs
export ZLYME_RUN_DIR=$td/run
export ZLYME_BIOS_PY=$PY
export EMU_TAG=GBA
zlyme_library_for "$rom"
test "$ZLYME_RESOLVE_COUNT" = 1
test "$ZLYME_BIOS_SCANS" = 1
test "$(cat "$td/run/bios/GB/gb_bios.bin")" = lose
zlyme_library_for "$rom"
test "$ZLYME_RESOLVE_COUNT" = 1
test "$ZLYME_BIOS_SCANS" = 1
test "$SAVES_PATH" = "$sd/Saves"
# existing save is on the other card
unset ZLYME_RESOLVED_ROM
zlyme_library_for "$rom"
# BIOS cache still valid
test "$ZLYME_BIOS_SCANS" = 1
got=$(zlyme_save_root "$rom" GBA)
test "$got" = "$sd"

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

# --- format UI stages, no disks ---
bin=$td/bin
mkdir -p "$bin"
cat > "$bin/zlyme-storage-format" <<'EOF'
#!/bin/sh
if [ "$1" = list ]; then
	printf '%s\t%s\n' /dev/mmcblk1p1 "Second SD"
	exit 0
fi
if [ "$1" = format ]; then
	printf '%s %s %s\n' "$2" "$3" "$4" > "${ZLYME_FMT_RESULT:?}"
	exit "${ZLYME_FMT_RC:-0}"
fi
exit 1
EOF
cat > "$bin/minui-list" <<'EOF'
#!/bin/sh
loc= val=
while [ $# -gt 0 ]; do
	case "$1" in
		--write-location) loc=$2; shift 2 ;;
		--write-value) val=$2; shift 2 ;;
		--file) file=$2; shift 2 ;;
		--title) title=$2; shift 2 ;;
		*) shift ;;
	esac
done
printf '%s\n' "$title" >> "${ZLYME_UI_LOG:?}"
if [ "${ZLYME_UI_CANCEL:-}" = "$title" ]; then
	exit 2
fi
# selected value is the first file line
head -n 1 "$file" > "$loc"
test "$val" = selected
EOF
cat > "$bin/minui-presenter" <<'EOF'
#!/bin/sh
show=
while [ $# -gt 0 ]; do
	case "$1" in
		--confirm-show) show=1; shift ;;
		--file) file=$2; shift 2 ;;
		*) shift ;;
	esac
done
printf 'confirm\n' >> "${ZLYME_UI_LOG:?}"
test -n "$show"
grep -q 'ALL DATA WILL BE LOST' "$file"
if [ "${ZLYME_UI_CANCEL:-}" = confirm ]; then
	exit 2
fi
exit 0
EOF
cat > "$bin/show.elf" <<'EOF'
#!/bin/sh
printf 'show %s\n' "$1" >> "${ZLYME_UI_LOG:?}"
EOF
chmod 0755 "$bin"/*
export PATH="$bin:$PATH"
export ZLYME_FMT_BIN=$bin/zlyme-storage-format
export ZLYME_FORMAT_STATUS=$td/status
export ZLYME_UI_LOG=$td/ui.log
export ZLYME_FMT_RESULT=$td/result

: > "$ZLYME_UI_LOG"
ZLYME_UI_CANCEL="Format storage" "$FMTUI"
grep -q "cancelled at device" "$ZLYME_FORMAT_STATUS"
test ! -e "$ZLYME_FMT_RESULT"

: > "$ZLYME_UI_LOG"
ZLYME_UI_CANCEL="Filesystem" "$FMTUI"
grep -q "cancelled at filesystem" "$ZLYME_FORMAT_STATUS"

: > "$ZLYME_UI_LOG"
ZLYME_UI_CANCEL=confirm "$FMTUI"
grep -q "cancelled at confirm" "$ZLYME_FORMAT_STATUS"
test ! -e "$ZLYME_FMT_RESULT"

: > "$ZLYME_UI_LOG"
unset ZLYME_UI_CANCEL
if ZLYME_FMT_RC=1 "$FMTUI"; then
	echo "format failure returned success" >&2
	exit 1
fi
grep -q "format failed" "$ZLYME_FORMAT_STATUS"

: > "$ZLYME_UI_LOG"
ZLYME_FMT_RC=0 "$FMTUI"
grep -q "format succeeded /dev/mmcblk1p1 exFAT" "$ZLYME_FORMAT_STATUS"
grep -q '/dev/mmcblk1p1 exfat ZLYME-LIB' "$ZLYME_FMT_RESULT"

echo "phase9l ok"
