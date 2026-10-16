#!/bin/sh
# ArtBook package, transparent system art, and tool images. No Flip.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
PKG=$ROOT/package/system/zlyme-artbook
fail() { echo "artbook: $*" >&2; exit 1; }

[ -f "$PKG/NOTICE.md" ] || fail "notice missing"
grep -q 'CC BY-NC-SA' "$PKG/NOTICE.md" || fail "license missing"
grep -q 'd772d07109701d9bd7c9fda305bfef6601105ab8' "$PKG/NOTICE.md" || fail "commit missing"
grep -q 'Anthony Caccese' "$PKG/NOTICE.md" || fail "author missing"
grep -q '430110584bafa614b7a3f4af1891c675e58de60e6658e3758d0724554f77ebd3' "$PKG/zlyme-artbook.hash" || fail "archive checksum missing"
grep -q 'ZLYME_ARTBOOK_VERSION = d772d07109701d9bd7c9fda305bfef6601105ab8' "$PKG/zlyme-artbook.mk" || fail "package source is not the pinned archive"
grep -q 'host-librsvg' "$PKG/zlyme-artbook.mk" || fail "svg rasterizer is not a host package"
if [ -d "$ROOT/package/system/nextui/artbook/src" ] || [ -d "$ROOT/package/system/nextui/artbook/system" ]; then
	fail "upstream art is still vendored under nextui"
fi
if find "$PKG" -path '*/artwork/*' -o -path '*/logos/*' | grep -q .; then
	fail "upstream images are vendored in the package"
fi
if grep -q 'artbook/system/' "$ROOT/package/system/nextui/nextui.mk"; then
	fail "nextui still installs artwork"
fi

# Every rom-dirs tag is mapped. A new tag is not.
python3 - "$ROOT" "$PKG/systems.txt" << 'PY'
import re, sys
root, mapping = sys.argv[1:]
tags = []
for line in open(root + "/package/system/nextui/rom-dirs.txt"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    m = re.search(r"\(([^)]+)\)$", line)
    if not m:
        sys.exit("rom dir has no tag")
    tags.append(m.group(1))
got = []
for line in open(mapping):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    got.append(line.split()[0])
if got != tags:
    sys.exit("system map does not match rom-dirs: %s" % (set(tags) ^ set(got)))
print("tags", len(tags))
PY

# Every stock tool pak has an svg and a tools.txt line.
python3 - "$ROOT" "$PKG/tools/tools.txt" << 'PY'
import os, sys
root, listing = sys.argv[1:]
paks = sorted(os.path.splitext(n)[0] for n in os.listdir(root + "/package/system/nextui/paks/Tools") if n.endswith(".pak"))
want = [line.strip() for line in open(listing) if line.strip() and not line.startswith("#")]
if want != paks:
    sys.exit("tool list does not match Tools paks: %s" % (set(paks) ^ set(want)))
for name in paks:
    path = root + "/package/system/zlyme-artbook/tools/" + name + ".svg"
    if not os.path.isfile(path):
        sys.exit("missing tool svg " + name)
print("tools", len(paks))
PY

# Resolver and the frontend call sites.
[ -f "$NEXT/workspace/all/nextui/zlyme_artbook.c" ] || fail "resolver missing"
cc -std=c11 -Wall -Wextra -Werror -I"$NEXT/workspace/all/nextui" \
	-o /tmp/zlyme-artbook-test \
	"$NEXT/workspace/all/nextui/zlyme_artbook.c" \
	"$NEXT/workspace/all/nextui/test_zlyme_artbook.c"
/tmp/zlyme-artbook-test
rm -f /tmp/zlyme-artbook-test
ui=$NEXT/workspace/all/nextui/nextui.c
grep -q 'zlyme_system_artbook' "$ui" || fail "system art is not requested"
grep -q 'zlyme_tool_artbook' "$ui" || fail "tool art is not requested"
grep -q 'zlyme_art_reserve' "$ui" || fail "scrolling names are not kept off the art"
grep -q 'ENTRY_PAK' "$ui" || fail "pak entries are not considered"
awk '
	/\.media\/bg\.png/ { media = NR }
	/zlyme_system_artbook/ { art = NR }
	END { exit (media && art && media < art) ? 0 : 1 }
' "$ui" || fail "user .media is not checked first"
grep -q 'SDL_PIXELFORMAT_ARGB8888' "$ui" || fail "folder art is not kept in ARGB8888"
grep -q 'layer == 1' "$NEXT/workspace/all/common/generic_video.c" || fail "background layer does not blend"

# Render when the pinned tree is already on disk. The package build is
# the offline path; this checks the pixels without a second download.
upstream=""
if [ -d /tmp/art-book-src/_inc/systems/artwork ]; then
	upstream=/tmp/art-book-src
fi
if [ -n "$upstream" ]; then
	out=$(mktemp -d)
	trap 'rm -rf "$out"' EXIT
	python3 "$PKG/compose.py" \
		--upstream "$upstream" \
		--out "$out/art" \
		--map "$PKG/systems.txt" \
		--tools "$PKG/tools" \
		--font "$PKG/fonts/DejaVuSans-Bold.ttf" \
		--contact "$out/sheets"
	python3 - "$PKG/compose.py" "$out/art" "$ROOT/package/system/nextui/rom-dirs.txt" "$PKG/tools/tools.txt" << 'PY'
import importlib.util, re, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("compose", sys.argv[1])
compose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compose)
art, roms, tools = Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
if (art / "list").exists():
    sys.exit("list directory was generated")
tags = []
for line in roms.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    tags.append(re.search(r"\(([^)]+)\)$", line).group(1))
for tag in tags:
    path = art / "system" / ("(%s).png" % tag)
    w, h, rows = compose.read_png(path)
    if (w, h) != (640, 480):
        sys.exit("size %s" % tag)
    box = compose.content_box(rows)
    if box[4] < 1000:
        sys.exit("not transparent %s" % tag)
    if box[0] < compose.SAFE_X:
        sys.exit("art enters the name column %s x=%s" % (tag, box[0]))
names = [line.strip() for line in tools.read_text().splitlines() if line.strip() and not line.startswith("#")]
for name in names:
    path = art / "tools" / (name + ".png")
    w, h, rows = compose.read_png(path)
    if (w, h) != (640, 480):
        sys.exit("tool size " + name)
    if compose.content_box(rows)[4] < 1000:
        sys.exit("tool not transparent " + name)
print("rendered", len(tags), len(names))
PY
	test -f "$out/sheets/systems-light.png"
	test -f "$out/sheets/systems-dark.png"
	test -f "$out/sheets/tools-light.png"
	test -f "$out/sheets/tools-dark.png"
fi

echo "artbook ok"
