#!/bin/sh
# ArtBook path mapping and shipped wallpaper files. No Flip.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
ART=$ROOT/package/system/nextui/artbook
fail() { echo "artbook: $*" >&2; exit 1; }

[ -f "$ART/NOTICE.md" ] || fail "notice missing"
grep -q 'CC BY-NC-SA' "$ART/NOTICE.md" || grep -q 'Attribution-NonCommercial-ShareAlike 2.0' "$ART/NOTICE.md" || fail "license missing"
grep -q 'd772d07109701d9bd7c9fda305bfef6601105ab8' "$ART/NOTICE.md" || fail "source commit missing"
grep -q 'Anthony Caccese' "$ART/NOTICE.md" || fail "author credit missing"
grep -q 'not an MIT' "$ART/NOTICE.md" || fail "license was flattened"
grep -q 'Dan Patrick' "$ART/NOTICE.md" || fail "logo credit missing"
command -v rsvg-convert >/dev/null 2>&1 || fail "rsvg-convert is required"
python3 "$ART/gen.py" --check

# A rom-dirs tag with no mapping is an error. The installed set is not used.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s\n' 'New System (ZZZZ)' > "$work/dirs"
if ARTBOOK_ROM_DIRS="$work/dirs" python3 "$ART/gen.py" --check >"$work/out" 2>"$work/err"; then
	fail "unmapped tag was accepted"
fi
grep -q 'ZZZZ' "$work/err" || fail "unmapped tag was not named"

for need in \
	"system/(GB).png" "system/(GBA).png" "system/(FC).png" \
	"list/(GB)-list.png" "system/Tools.png" "list/Tools-list.png" \
	"system/Collections.png" "system/Recently Played.png" \
	"list/Recently Played-list.png"
do
	[ -f "$ART/$need" ] || fail "missing $need"
done
find "$ART/system" "$ART/list" \( -name '*.ttf' -o -name '*.bmp' -o -name '*.fig' -o -name '*.svg' \) | grep -q . && fail "source asset shipped as a wallpaper"
[ -f "$ART/src/fonts/DejaVuSans-Bold.ttf" ] || fail "wordmark font missing"
[ ! -f "$ART/system/Root.png" ] || fail "unused root wallpaper shipped"

[ -f "$NEXT/workspace/all/nextui/zlyme_artbook.c" ] || fail "resolver missing"
cc -std=c11 -Wall -Wextra -Werror -I"$NEXT/workspace/all/nextui" \
	-o /tmp/zlyme-artbook-test \
	"$NEXT/workspace/all/nextui/zlyme_artbook.c" \
	"$NEXT/workspace/all/nextui/test_zlyme_artbook.c"
/tmp/zlyme-artbook-test
rm -f /tmp/zlyme-artbook-test

ui=$NEXT/workspace/all/nextui/nextui.c
grep -q 'zlyme_folder_artbook' "$ui" || fail "frontend does not call the resolver"
# User .media is tested before the stock image.
awk '
	/\.media\/bg\.png/ { media = NR }
	/zlyme_folder_artbook/ { art = NR }
	END { exit (media && art && media < art) ? 0 : 1 }
' "$ui" || fail "ArtBook is consulted before user .media"
grep -q 'SDCARD_PATH "/bg.png"' "$ui" || fail "user bg.png fallback missing"
grep -q '/usr/share/nextui/artbook' "$ui" || fail "firmware path missing"
grep -q 'artbook/system/' "$ROOT/package/system/nextui/nextui.mk" || fail "package does not install system wallpapers"
grep -q 'artbook/list/' "$ROOT/package/system/nextui/nextui.mk" || fail "package does not install list wallpapers"
grep -q 'artbook/NOTICE.md' "$ROOT/package/system/nextui/nextui.mk" || fail "package does not install the notice"
if grep -q 'cp -a $(NEXTUI_PKGDIR)/artbook/\.' "$ROOT/package/system/nextui/nextui.mk"; then
	fail "package installs the artwork sources"
fi

echo "artbook ok"
