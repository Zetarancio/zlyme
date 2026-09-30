#!/bin/sh
# Native PICO-8 runtime discovery. No proprietary binary is executed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/package/emulators/pico8/start_pico8.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pair() {
	mkdir -p "$1"
	printf 'bin' > "$1/pico8_64"
	printf 'dat' > "$1/pico8.dat"
}

run() {
	BIOS_PATH=$1 \
	SDCARD_PATH=$work/storage \
	SHARED_USERDATA_PATH=$work/home \
	ZLYME_PICO_LIBRARIES=$2 \
	ZLYME_PICO_RUNTIME=$ROOT/board/my355/fsoverlay/usr/share/zlyme/pico-runtime.sh \
	ZLYME_PICO_DRY=1 \
	"$BIN" "$3"
}

# Main card.
pair "$work/storage/Bios/PICO"
printf '%s\n' "$work/storage" > "$work/libs"
out=$(run "$work/storage/Bios" "$work/libs" "$work/storage/Roms/Pico-8 (PICO)/cart.p8")
test "$out" = "LAUNCH_DIR=$work/storage/Bios/PICO"

# Splore dummy on the main card, runtime only on the second card.
rm -rf "$work/storage/Bios/PICO"
mkdir -p "$work/storage/Roms/Pico-8 (PICO)" "$work/sd2/Bios/PICO"
printf 'splore' > "$work/storage/Roms/Pico-8 (PICO)/Splore.p8"
pair "$work/sd2/Bios/PICO"
printf '%s\n' "$work/storage" "$work/sd2" > "$work/libs"
out=$(run "$work/storage/Bios" "$work/libs" "$work/storage/Roms/Pico-8 (PICO)/Splore.p8")
test "$out" = "LAUNCH_DIR=$work/sd2/Bios/PICO"

# ROM on the second card wins over a main-card runtime.
pair "$work/storage/Bios/PICO"
mkdir -p "$work/sd2/Roms/Pico-8 (PICO)"
printf 'cart' > "$work/sd2/Roms/Pico-8 (PICO)/cart.p8"
out=$(run "$work/sd2/Bios" "$work/libs" "$work/sd2/Roms/Pico-8 (PICO)/cart.p8")
test "$out" = "LAUNCH_DIR=$work/sd2/Bios/PICO"

# Incomplete pair is skipped.
rm -rf "$work/storage/Bios/PICO"
mkdir -p "$work/storage/Bios/PICO"
printf 'bin' > "$work/storage/Bios/PICO/pico8_64"
out=$(run "$work/storage/Bios" "$work/libs" "$work/storage/Roms/Pico-8 (PICO)/Splore.p8")
test "$out" = "LAUNCH_DIR=$work/sd2/Bios/PICO"

# No runtime.
rm -rf "$work/sd2/Bios/PICO" "$work/storage/Bios/PICO"
if run "$work/storage/Bios" "$work/libs" "$work/storage/Roms/Pico-8 (PICO)/Splore.p8" >"$work/out" 2>"$work/err"; then
	echo "missing runtime succeeded" >&2
	exit 1
fi
grep -q 'Bios/PICO/' "$work/err"
grep -q 'pico8_64' "$work/err"
grep -q 'pico8.dat' "$work/err"
if grep -q '/storage/Bios/PICO only' "$work/err"; then
	echo "error mentioned only the main card" >&2
	exit 1
fi

# Spaces, and no library registry: main card still works.
spaced="$work/media/My Card"
pair "$spaced/Bios/PICO"
printf '%s\n' "$work/storage" "$spaced" > "$work/libs"
out=$(run "$work/storage/Bios" "$work/libs" "$work/storage/Roms/Pico-8 (PICO)/Splore.p8")
test "$out" = "LAUNCH_DIR=$spaced/Bios/PICO"

rm -f "$work/libs"
pair "$work/storage/Bios/PICO"
out=$(BIOS_PATH=$work/storage/Bios SDCARD_PATH=$work/storage \
	SHARED_USERDATA_PATH=$work/home ZLYME_PICO_LIBRARIES=$work/missing \
	ZLYME_PICO_RUNTIME=$ROOT/board/my355/fsoverlay/usr/share/zlyme/pico-runtime.sh \
	ZLYME_PICO_DRY=1 "$BIN" "$work/storage/Roms/Pico-8 (PICO)/cart.p8")
test "$out" = "LAUNCH_DIR=$work/storage/Bios/PICO"

if grep -n eval "$BIN" >/dev/null; then
	echo "start_pico8.sh uses eval" >&2
	exit 1
fi
echo "pico runtime ok"
