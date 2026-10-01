#!/bin/sh
# The shallow ROM view uses directory symlinks. cheat_manager must see them.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
launch=$ROOT/package/system/nextui/paks/Tools/Cheat\ Downloader.pak/launch.sh
patch=$ROOT/package/system/cheat-downloader/0001-follow-union-symlinks.patch
grep -q 'pcLinkToDir' "$patch"
grep -q 'list-dirs' "$patch"
if grep -q 'merge_dir' "$launch"; then
	echo "recursive ROM merge is back" >&2
	exit 1
fi

bin=${CHEAT_MANAGER:-/tmp/cheat_manager_host}
if [ ! -x "$bin" ]; then
	echo "cheat symlink test needs a host cheat_manager at $bin" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd1=$work/sd1
sd2=$work/sd2
mkdir -p "$sd1/Roms/Game Boy (GB)" "$sd2/Roms/Super Nintendo (SNES)"
mkdir -p "$sd1/Roms/Genesis (MD)/nested" "$sd2/Roms/Genesis (MD)"
mkdir -p "$sd1/Roms/Doom (DOOM)" "$sd2/Roms/Doom (DOOM)/iwad"
mkdir -p "$sd1/Roms/Game Boy Advance (GBA)"
mkdir -p "$sd1/Roms/Nintendo Entertainment System (NES)/loop"
printf 'a' > "$sd1/Roms/Game Boy (GB)/only-sd1.gb"
printf 'snes' > "$sd2/Roms/Super Nintendo (SNES)/only-sd2.sfc"
printf 'old' > "$sd1/Roms/Genesis (MD)/same.gen"
printf 'new' > "$sd2/Roms/Genesis (MD)/same.gen"
printf 'n1' > "$sd1/Roms/Genesis (MD)/nested/deep.gen"
printf 'wad' > "$sd2/Roms/Doom (DOOM)/iwad/game.wad"
printf 'note' > "$sd1/Roms/Game Boy Advance (GBA)/readme.txt"
printf 'png' > "$sd1/Roms/Game Boy Advance (GBA)/box.png"
# Cycle: the only ROM sits next to a directory symlink back to the system.
printf 'nes' > "$sd1/Roms/Nintendo Entertainment System (NES)/game.nes"
ln -s .. "$sd1/Roms/Nintendo Entertainment System (NES)/loop/again"

printf '%s\n' "$sd1" "$sd2" > "$work/libs"
out=$(ZLYME_CHEAT_DRY=1 ZLYME_CHEAT_KEEP=1 ZLYME_LIBRARIES_FILE=$work/libs \
	SDCARD_PATH=$work "$launch")
union=$(printf '%s\n' "$out" | sed -n 's/^union=//p')
test -n "$union"
test -L "$union/Game Boy (GB)"
test -L "$union/Super Nintendo (SNES)"
test -d "$union/Genesis (MD)"
test ! -L "$union/Genesis (MD)"
test "$(readlink "$union/Genesis (MD)/same.gen")" = "$sd2/Roms/Genesis (MD)/same.gen"
test -L "$union/Doom (DOOM)/iwad"
test -L "$union/Genesis (MD)/nested"

list=$(ROM_DIR=$union CACHE_DIR=$work/cache CHEAT_DIR=$work/cheats \
	SDCARD_PATH=$work "$bin" list-dirs)
printf '%s\n' "$list" | grep -F -q 'Game Boy (GB)'
printf '%s\n' "$list" | grep -F -q 'Super Nintendo (SNES)'
printf '%s\n' "$list" | grep -F -q 'Genesis (MD)'
printf '%s\n' "$list" | grep -F -q 'Doom (DOOM)'
printf '%s\n' "$list" | grep -F -q 'Nintendo Entertainment System (NES)'
if printf '%s\n' "$list" | grep -F -q 'Game Boy Advance (GBA)'; then
	echo "junk-only system was listed" >&2
	exit 1
fi
rm -rf "$union"
echo "cheat symlinks ok"
