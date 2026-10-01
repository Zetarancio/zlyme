#!/bin/sh
# The synthetic Splore file follows the library that holds the runtime.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pico-splore"
RT="$ROOT/board/my355/fsoverlay/usr/share/zlyme/pico-runtime.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
art=$work/art.png
printf 'png' > "$art"
main=$work/storage
sd2=$work/sd2
export ZLYME_PICO_ART=$art
export ZLYME_PICO_RUNTIME=$RT
export ZLYME_PICO_LIBRARIES=$work/libs
export ZLYME_PICO_SHARED=$work/native
unset ZLYME_PICO_ROMDIR
mkdir -p "$work/native" "$main/Roms" "$sd2/Roms"

pair() {
	root=$1
	mkdir -p "$root/Bios/PICO"
	printf 'bin' > "$root/Bios/PICO/pico8_64"
	printf 'dat' > "$root/Bios/PICO/pico8.dat"
}
unpair() {
	rm -rf "$1/Bios/PICO"
}

# runtime only on the main card
pair "$main"
printf '%s\n' "$main" > "$work/libs"
"$BIN"
cmp -s "$art" "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
test ! -e "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"

# runtime only on SD2
unpair "$main"
rm -f "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
pair "$sd2"
printf '%s\n' "$main" "$sd2" > "$work/libs"
"$BIN"
cmp -s "$art" "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
test ! -e "$main/Roms/Pico-8 (PICO)/000) Splore.p8"

# both: the first library in the list owns the one row
pair "$main"
"$BIN"
cmp -s "$art" "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
test ! -e "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"

# SD2 arrives after a boot that only knew /storage
unpair "$main"
rm -f "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
printf '%s\n' "$main" > "$work/libs"
"$BIN"
test ! -e "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
test ! -e "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
printf '%s\n' "$main" "$sd2" > "$work/libs"
"$BIN"
cmp -s "$art" "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"

# card already listed at the first run
rm -f "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
"$BIN"
cmp -s "$art" "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"

# Runtime disappears while the card is still a library. Eject unmounts
# first, so the file leaves with the card; this is the still-mounted case.
unpair "$sd2"
printf '%s\n' "$main" "$sd2" > "$work/libs"
"$BIN"
test ! -e "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
test ! -e "$main/Roms/Pico-8 (PICO)/000) Splore.p8"
# An owned copy of the old filename is replaced. A different file is not.
pair "$sd2"
printf 'png' > "$sd2/Roms/Pico-8 (PICO)/Splore.p8"
rm -f "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
"$BIN"
test ! -e "$sd2/Roms/Pico-8 (PICO)/Splore.p8"
cmp -s "$art" "$sd2/Roms/Pico-8 (PICO)/000) Splore.p8"
printf 'user-cart' > "$sd2/Roms/Pico-8 (PICO)/My Splore Game.p8"
"$BIN"
grep -q user-cart "$sd2/Roms/Pico-8 (PICO)/My Splore Game.p8"
echo "splore place ok"
