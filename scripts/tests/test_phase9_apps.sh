#!/bin/sh
# Pre-release app glue: no private cpufreq, cheat folders are links.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail=0
for f in \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh" \
	"$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pico-bbs"
do
	if grep -E -q 'scaling_governor|scaling_min_freq|scaling_max_freq|scaling_setspeed' "$f"; then
		echo "cpufreq write in $f" >&2
		fail=1
	fi
done
if [ -d "$ROOT/package/system/nextui/paks/Tools/Update.pak" ]; then
	echo "Update.pak is back" >&2
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/Weston.pak" ]; then
	echo "Weston test pak is back" >&2
	fail=1
fi
if [ -e "$ROOT/package/system/nextui/paks/Tools/Joystick Calibration.pak" ]; then
	echo "standalone joystick pak is back" >&2
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Emus/RUFFLE.pak" ]; then
	echo "RUFFLE.pak is back" >&2
	fail=1
fi
grep -F -q 'paks/Emus/RUFFLE.pak' "$ROOT/package/system/nextui/nextui.mk"
grep -F -q 'zlyme43' "$ROOT/ZLYME_VERSION" || {
	echo "product version file changed" >&2
	fail=1
}
grep -F -q 'RUFFLE_PERFORMANCE=0' \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh"
grep -F -q 'Flash (FLASH)' "$ROOT/package/system/nextui/rom-dirs.txt"
grep -F -q 'FLASH: swf' "$ROOT/package/system/nextui/rom-exts.txt"
grep -F -q 'auto_update=0' \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh"
grep -F -q 'cheat: CHECK_UPDATE' \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/a/Roms/Game Boy (GB)" "$work/b/Roms/Game Boy (GB)"
printf '1' > "$work/a/Roms/Game Boy (GB)/only1.gb"
printf '2' > "$work/b/Roms/Game Boy (GB)/only2.gb"
printf 'a' > "$work/a/Roms/Game Boy (GB)/same.gb"
printf 'b' > "$work/b/Roms/Game Boy (GB)/same.gb"
printf '%s\n' "$work/a" "$work/b" > "$work/libs"
out=$(ZLYME_CHEAT_DRY=1 ZLYME_LIBRARIES_FILE=$work/libs SDCARD_PATH=$work \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh" || true)
printf '%s\n' "$out" | grep -F -q "only1.gb $work/a/Roms/Game Boy (GB)/only1.gb"
printf '%s\n' "$out" | grep -F -q "only2.gb $work/b/Roms/Game Boy (GB)/only2.gb"
printf '%s\n' "$out" | grep -F -q "same.gb $work/b/Roms/Game Boy (GB)/same.gb"
if [ "$fail" -ne 0 ]; then
	exit 1
fi
echo "phase9 apps ok"
