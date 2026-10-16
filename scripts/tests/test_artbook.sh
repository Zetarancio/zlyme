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
grep -q 'f5fe9929148748d0d5039b993c4815818fbb921a' "$ART/NOTICE.md" || fail "source commit missing"
grep -q 'Timothy Bueno' "$ART/NOTICE.md" || fail "author credit missing"
grep -q 'not an MIT' "$ART/NOTICE.md" || fail "license was flattened"

coverage=0
set +e
python3 - <<PY
import os, re, struct, sys
art = "$ART"
dirs = []
for line in open("$ROOT/package/system/nextui/rom-dirs.txt"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    m = re.search(r"\(([^)]+)\)$", line)
    if not m:
        sys.exit("rom dir has no tag: " + line)
    dirs.append(m.group(1))
missing = []
for tag in dirs:
    for path in (
        os.path.join(art, "system", "(%s).png" % tag),
        os.path.join(art, "list", "(%s)-list.png" % tag),
    ):
        if not os.path.isfile(path):
            missing.append(path)
        else:
            data = open(path, "rb").read(24)
            if data[0] != 0x89 or data[1:4] != b"PNG":
                sys.exit("not a png: " + path)
            w, h = struct.unpack(">II", data[16:24])
            if (w, h) != (640, 480):
                sys.exit("size %s %dx%d" % (path, w, h))
# Also check every shipped png, including Tools and Collections.
for dirpath, _, files in os.walk(art):
    for name in files:
        if not name.endswith(".png"):
            continue
        path = os.path.join(dirpath, name)
        data = open(path, "rb").read(24)
        if data[0] != 0x89 or data[1:4] != b"PNG":
            sys.exit("not a png: " + path)
        w, h = struct.unpack(">II", data[16:24])
        if (w, h) != (640, 480):
            sys.exit("size %s %dx%d" % (path, w, h))
if missing:
    print("missing default artwork:", file=sys.stderr)
    for path in missing:
        print("  " + os.path.relpath(path, art), file=sys.stderr)
    sys.exit(2)
print("tags", len(dirs))
PY
coverage=$?
set -e
if [ "$coverage" -ne 0 ] && [ "$coverage" -ne 2 ]; then
	exit "$coverage"
fi

for need in \
	"system/(GB).png" "system/(GBA).png" "system/(FC).png" \
	"list/(GB)-list.png" "system/Tools.png" "list/Tools-list.png" \
	"system/Collections.png" "system/Recently Played.png" \
	"list/Recently Played-list.png"
do
	[ -f "$ART/$need" ] || fail "missing $need"
done
find "$ART" -name '*.ttf' -o -name '*.bmp' -o -name '*.fig' | grep -q . && fail "non-wallpaper asset shipped"

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
grep -q 'cp -a $(NEXTUI_PKGDIR)/artbook/' "$ROOT/package/system/nextui/nextui.mk" || fail "package does not install artbook"

if [ "$coverage" -ne 0 ]; then
	exit "$coverage"
fi
echo "artbook ok"
