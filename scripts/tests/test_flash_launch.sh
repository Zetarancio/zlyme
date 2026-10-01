#!/bin/sh
# Flash is a stock emulator. The SWF's library is the data root.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
dirs=$ROOT/package/system/nextui/rom-dirs.txt
exts=$ROOT/package/system/nextui/rom-exts.txt
pak=$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh
grep -F -q 'Flash (FLASH)' "$dirs"
grep -F -q 'FLASH: swf' "$exts"
test -f "$pak"
test ! -d "$ROOT/package/system/nextui/paks/Emus/RUFFLE.pak"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for root in "$work/storage" "$work/sd2" "$work/media/OTG"; do
	mkdir -p "$root/Roms/Flash (FLASH)"
	printf 'swf' > "$root/Roms/Flash (FLASH)/Game.swf"
	printf '%s\n' "$root" >> "$work/libs"
done
libsh=$ROOT/package/system/nextui/zlyme/zlyme-library.sh
mkdir -p "$work/os"
launch() {
	rom=$1
	ZLYME_RUFFLE_DRY=1 ZLYME_STATE_ROOT=$work/os \
		ZLYME_LIBRARY_SH=$libsh ZLYME_LIBRARIES_FILE=$work/libs \
		ROM=$rom "$pak" "$rom"
}
check() {
	root=$1
	out=$2
	printf '%s\n' "$out" | grep -F -q "library=$root"
	printf '%s\n' "$out" | grep -F -q "romroot=$root"
	printf '%s\n' "$out" | grep -F -q "flash=$root/Roms/Flash (FLASH)"
	printf '%s\n' "$out" | grep -F -q "rom=$root/Roms/Flash (FLASH)/Game.swf"
	printf '%s\n' "$out" | grep -F -q "data=$root/Saves/FLASH/flash_data"
	test -f "$root/Roms/Flash (FLASH)/Game.swf"
	test ! -e "$root/Saves/FLASH/flash"
}
out=$(launch "$work/storage/Roms/Flash (FLASH)/Game.swf")
check "$work/storage" "$out"
out=$(launch "$work/sd2/Roms/Flash (FLASH)/Game.swf")
check "$work/sd2" "$out"
out=$(launch "$work/media/OTG/Roms/Flash (FLASH)/Game.swf")
check "$work/media/OTG" "$out"
echo "flash launch ok"
