#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_CLEANUP_ROOT="$work/storage"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_RECENT_FILE="$work/storage/.config/nextui/shared/.minui/recent.txt"
export ZLYME_ROM_PLAN="$work/plan"
printf '%s\n' "$work/storage" "$work/sd2" > "$work/libraries"
a="$work/storage/Roms/Game Boy Advance (GBA)"
b="$work/sd2/Roms/Game Boy Advance (GBA)"
mkdir -p "$a/.media" "$b/.media" \
	"$work/storage/Saves/GBA" "$work/sd2/Saves/GBA" \
	"$(dirname "$ZLYME_RECENT_FILE")" \
	"$work/storage/.config/nextui/shared/Pico-8-native"
rom="$a/It's a \"game\".gba"
printf 'rom' > "$rom"
printf 'save' > "$work/storage/Saves/GBA/It's a \"game\".sav"
printf 'state' > "$work/storage/Saves/GBA/It's a \"game\".state"
printf 'art' > "$a/.media/It's a \"game\".png"
printf 'other' > "$b/It's a \"game\".gba"
printf 'keep' > "$work/sd2/Saves/GBA/It's a \"game\".sav"
printf 'keepart' > "$b/.media/It's a \"game\".png"
printf 'bin' > "$a/disc.bin"
cue="$a/disc.cue"
printf 'FILE disc.bin BINARY\n' > "$cue"
printf '%s\n' "$rom" "$b/It's a \"game\".gba" > "$ZLYME_RECENT_FILE"
"$BIN" rom "$rom" --dry-run > "$work/out"
test -f "$rom"
grep -q "$rom" "$work/plan"
grep -q 'game".sav' "$work/plan"
if grep -q '/sd2/' "$work/plan"; then
	echo "other card was planned" >&2
	exit 1
fi
"$BIN" rom-apply "$work/plan"
test ! -e "$rom"
test ! -e "$work/storage/Saves/GBA/It's a \"game\".sav"
test ! -e "$a/.media/It's a \"game\".png"
test -f "$b/It's a \"game\".gba"
test -f "$work/sd2/Saves/GBA/It's a \"game\".sav"
test -f "$b/.media/It's a \"game\".png"
grep -qx "$b/It's a \"game\".gba" "$ZLYME_RECENT_FILE"
if grep -qx "$rom" "$ZLYME_RECENT_FILE"; then
	echo "recent entry survived" >&2
	exit 1
fi
"$BIN" rom "$cue" --dry-run > "$work/cue.out"
if grep -q disc.bin "$work/plan"; then
	echo "cue delete included the referenced bin" >&2
	exit 1
fi
test -f "$a/disc.bin"
splore="$a/Splore.p8"
printf 'splore' > "$splore"
marker="$work/storage/.config/nextui/shared/Pico-8-native/splore-installed"
: > "$marker"
"$BIN" rom "$splore" --dry-run >/dev/null
grep -q "$marker" "$work/plan"
echo "rom delete ok"
