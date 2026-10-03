#!/bin/sh
# Pre-release app glue: no private cpufreq, cheat folders are links.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail=0
for f in \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/launch.sh" \
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
if [ -e "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-weston-test" ] || \
	[ -e "$ROOT/board/my355/fsoverlay/usr/bin/zlyme-weston-test" ]; then
	echo "zlyme-weston-test is back" >&2
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/Artwork Scraper.pak" ]; then
	echo "Artwork Scraper is back" >&2
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak" ] || \
	[ -d "$ROOT/package/system/cheat-downloader" ]; then
	echo "Cheat Downloader is back" >&2
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
grep -F -q 'zlyme44' "$ROOT/ZLYME_VERSION" || {
	echo "product version file is not zlyme44" >&2
	fail=1
}
grep -F -q 'RUFFLE_PERFORMANCE=0' \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh"
grep -F -q 'Flash (FLASH)' "$ROOT/package/system/nextui/rom-dirs.txt"
grep -F -q 'FLASH: swf' "$ROOT/package/system/nextui/rom-exts.txt"
grep -F -q 'auto_update=0' \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh"
grep -F -q 'rm -rf $(TARGET_DIR)/usr/share/nextui/paks/Emus' \
	"$ROOT/package/system/nextui/nextui.mk"
if [ "$fail" -ne 0 ]; then
	exit 1
fi
echo "phase9 apps ok"
