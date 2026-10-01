#!/bin/sh
# Additive library skeleton. Existing files stay. Unknown roots are rejected.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-library-populate
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
chmod 0755 "$BIN"

manifest=$work/rom-dirs.txt
cat > "$manifest" <<'EOF'
# comment
Game Boy (GB)
Flash (FLASH)
EOF
libs=$work/libs
card=$work/SD\ card
mkdir -p "$card"
printf '%s\n' "$card" > "$libs"

run() {
	ZLYME_LIBRARIES_FILE=$libs ZLYME_ROM_DIRS=$manifest "$BIN" "$1"
}

run "$card"
test -d "$card/Roms/Game Boy (GB)"
test -d "$card/Roms/Flash (FLASH)"
test -d "$card/Bios/PICO"
test -d "$card/Saves/GB"
test -d "$card/Saves/FLASH"
printf 'rom' > "$card/Roms/Game Boy (GB)/keep.gb"
printf 'sav' > "$card/Saves/GB/keep.srm"
printf 'bios' > "$card/Bios/keep.bin"
before=$(find "$card" -type f -exec sha256sum {} \; | sort)
run "$card"
after=$(find "$card" -type f -exec sha256sum {} \; | sort)
test "$before" = "$after"
test "$(cat "$card/Roms/Game Boy (GB)/keep.gb")" = rom

other=$work/other
mkdir -p "$other"
if ZLYME_LIBRARIES_FILE=$libs ZLYME_ROM_DIRS=$manifest "$BIN" "$other"; then
	echo "unlisted root was accepted" >&2
	exit 1
fi
gone=$work/gone
printf '%s\n' "$card" "$gone" > "$libs"
if ZLYME_LIBRARIES_FILE=$libs ZLYME_ROM_DIRS=$manifest "$BIN" "$gone"; then
	echo "missing root was accepted" >&2
	exit 1
fi
echo "library populate ok"
