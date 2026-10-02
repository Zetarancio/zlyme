#!/bin/sh
# ZcrapeGoat attribution stays attached to the upstream project.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ui=$ROOT/package/system/zcrapegoat/src/src/ui.c
up=$ROOT/package/system/zcrapegoat/src/UPSTREAM
lic=$ROOT/package/system/zcrapegoat/src/LICENSE
pak=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/pak.json
ss=$ROOT/package/system/zcrapegoat/src/src/screenscraper.h

grep -q 'ZcrapeGoat v2.3.0' "$ui"
grep -q 'ScrapeGoat by Helaas' "$ui"
grep -q 'under the MIT License.' "$ui"
grep -q 'https://github.com/Helaas/nextui-scrapegoat-pak' "$up"
if grep -q 'https://github.com/Helaas/nextui-scrapegoat-pak' "$ui"; then
	echo "About popup still includes the upstream URL" >&2
	exit 1
fi
if grep -q 'Artwork: ScreenScraper.fr' "$ui"; then
	echo "About popup still continues past the MIT License" >&2
	exit 1
fi
# User-facing ScrapeGoat strings are the attribution lines only.
extra=$(grep -n 'ScrapeGoat' "$ui" | grep -v 'Based on ScrapeGoat by Helaas' | grep -v 'ScrapeGoat and releasing it' || true)
if [ -n "$extra" ]; then
	echo "unexpected user-facing ScrapeGoat string:" >&2
	printf '%s\n' "$extra" >&2
	exit 1
fi
if grep -q 'ScrapeGoat' "$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/launch.sh"; then
	echo "launcher still says ScrapeGoat" >&2
	exit 1
fi
grep -q 'c52f749eae21a4c02c767e485fef2abbb773f2d7' "$up"
grep -q 'v2.3.0' "$up"
grep -q 'MIT License' "$lic"
grep -q '"name": "ZcrapeGoat"' "$pak"
grep -q 'ZcrapeGoat-v2.3.0' "$ss"
test ! -e "$ROOT/package/system/zcrapegoat/0001-zlyme-libraries.patch"
test ! -d "$ROOT/package/system/scrapegoat"
echo "zcrapegoat attribution ok"
