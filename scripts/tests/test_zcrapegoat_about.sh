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
grep -q 'https://github.com/Helaas/nextui-scrapegoat-pak' "$ui"
grep -q 'MIT License' "$ui"
grep -q 'c52f749eae21a4c02c767e485fef2abbb773f2d7' "$up"
grep -q 'v2.3.0' "$up"
grep -q 'MIT License' "$lic"
grep -q '"name": "ZcrapeGoat"' "$pak"
grep -q 'ZcrapeGoat-v2.3.0' "$ss"
test ! -e "$ROOT/package/system/zcrapegoat/0001-zlyme-libraries.patch"
test ! -d "$ROOT/package/system/scrapegoat"
echo "zcrapegoat attribution ok"
