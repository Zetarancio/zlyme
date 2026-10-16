#!/bin/sh
# ArtBook package checks. Rendering is mandatory when the tools exist.
# A missing archive or renderer exits 2. That is not a passing render.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
PKG=$ROOT/package/system/zlyme-artbook
PAKS=$ROOT/package/system/nextui/paks/Tools
ARCHIVE_NAME=d772d07109701d9bd7c9fda305bfef6601105ab8.tar.gz
ARCHIVE_SHA=430110584bafa614b7a3f4af1891c675e58de60e6658e3758d0724554f77ebd3
fail() { echo "artbook: $*" >&2; exit 1; }
blocked() { echo "artbook blocked: $*" >&2; exit 2; }

[ -f "$PKG/NOTICE.md" ] || fail "notice missing"
grep -q 'CC BY-NC-SA' "$PKG/NOTICE.md" || fail "license missing"
grep -q 'd772d07109701d9bd7c9fda305bfef6601105ab8' "$PKG/NOTICE.md" || fail "commit missing"
grep -q 'Anthony Caccese' "$PKG/NOTICE.md" || fail "author missing"
grep -q "$ARCHIVE_SHA" "$PKG/zlyme-artbook.hash" || fail "archive checksum missing"
grep -q 'ZLYME_ARTBOOK_VERSION = d772d07109701d9bd7c9fda305bfef6601105ab8' "$PKG/zlyme-artbook.mk" || fail "package pin drifted"
grep -q '/usr/bin/python3' "$PKG/zlyme-artbook.mk" || fail "recipe does not use the container Python"
grep -q '/usr/bin/rsvg-convert' "$PKG/zlyme-artbook.mk" || fail "recipe does not use the container rasterizer"
if grep -q 'host-librsvg' "$PKG/zlyme-artbook.mk"; then
	fail "recipe still builds host-librsvg"
fi
if [ -d "$ROOT/package/system/nextui/artbook" ]; then
	fail "old artbook tree is still present"
fi
if find "$PKG/tools" -name '*.svg' | grep -q .; then
	fail "tool svg sources are still the maintained artwork"
fi
if grep -q 'artbook/system/' "$ROOT/package/system/nextui/nextui.mk"; then
	fail "nextui still installs artwork"
fi
grep -q 'branches:' "$ROOT/.github/workflows/docker-image.yml" || fail "docker publish is not branch limited"
grep -q "github.ref == 'refs/heads/main'" "$ROOT/.github/workflows/docker-image.yml" || fail "manual docker dispatch can publish latest"
test -f "$PKG/ARTWORK_GENERATION_PROMPT.md" || fail "artwork prompt missing"
grep -q '^PAK_NAME:' "$PKG/ARTWORK_GENERATION_PROMPT.md" || fail "prompt has no PAK_NAME field"
grep -q '^PAK_DESCRIPTION:' "$PKG/ARTWORK_GENERATION_PROMPT.md" || fail "prompt has no PAK_DESCRIPTION field"
grep -q 'viewBox="0 0 453 1080"' "$PKG/resources/system-art-mask.svg" || fail "mask viewBox changed"
grep -q 'CC BY-NC-SA' "$PKG/resources/README.md" || fail "mask license missing"
if grep -n '/storage' "$PKG/compose.py" "$PKG/zlyme-artbook.mk"; then
	fail "artwork build mentions /storage"
fi
grep -q "rm -rf \$(TARGET_DIR)/usr/share/nextui/artbook/system" "$PKG/zlyme-artbook.mk" || fail "install keeps stale system art"
grep -q "rm -rf \$(TARGET_DIR)/usr/share/nextui/artbook/tools" "$PKG/zlyme-artbook.mk" || fail "install keeps stale tool art"

python3 - "$ROOT/package/system/nextui/rom-dirs.txt" "$PKG/systems.txt" "$PKG/tools" "$PAKS" << 'PY'
import re, sys
from pathlib import Path
roms, mapping, tools, paks = map(Path, sys.argv[1:])
tags = []
for line in roms.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    tags.append(re.search(r"\(([^)]+)\)$", line).group(1))
got = []
for line in mapping.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    got.append(line.split()[0])
if got != tags:
    sys.exit("system map does not match rom-dirs")
stock = sorted(p.name for p in paks.iterdir() if p.name.endswith(".pak"))
found = sorted(p.name for p in tools.iterdir() if p.is_dir() and p.name.endswith(".pak"))
if found != stock:
    sys.exit("tool backgrounds %s" % (set(stock) ^ set(found)))
for name in stock:
    if not (tools / name / "background.png").is_file():
        sys.exit("missing background " + name)
print("static", len(tags), len(stock))
PY

# Resolver.
cc -std=c11 -Wall -Wextra -Werror -I"$NEXT/workspace/all/nextui" \
	-o /tmp/zlyme-artbook-test \
	"$NEXT/workspace/all/nextui/zlyme_artbook.c" \
	"$NEXT/workspace/all/nextui/test_zlyme_artbook.c"
/tmp/zlyme-artbook-test
rm -f /tmp/zlyme-artbook-test
ui=$NEXT/workspace/all/nextui/nextui.c
grep -q 'zlyme_system_artbook' "$ui" || fail "system art is not requested"
grep -q 'zlyme_tool_artbook' "$ui" || fail "tool art is not requested"
grep -q 'zlyme_art_reserve' "$ui" || fail "names are not kept off the art"
awk '
	/\.media\/bg\.png/ { media = NR }
	/zlyme_system_artbook/ { art = NR }
	END { exit (media && art && media < art) ? 0 : 1 }
' "$ui" || fail "user .media is not first"
grep -q 'layer == 1' "$NEXT/workspace/all/common/generic_video.c" || fail "background layer does not blend"

command -v rsvg-convert >/dev/null 2>&1 || blocked "rsvg-convert is not installed"
/usr/bin/python3 -c 'import PIL' >/dev/null 2>&1 || blocked "container Python has no Pillow"

dl=${ZLYME_ARTBOOK_DL:-$ROOT/dl/zlyme-artbook}
archive=$dl/$ARCHIVE_NAME
if [ ! -f "$archive" ]; then
	mkdir -p "$dl"
	curl -fsSL -o "$archive" \
		"https://github.com/anthonycaccese/art-book-next-es-de/archive/${ARCHIVE_NAME}" \
		|| blocked "could not download the pinned archive"
fi
got=$(sha256sum "$archive" | awk '{print $1}')
[ "$got" = "$ARCHIVE_SHA" ] || fail "archive checksum mismatch"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -xzf "$archive" -C "$work"
upstream=$(find "$work" -maxdepth 1 -type d -name 'art-book-next-es-de-*' | head -1)
[ -n "$upstream" ] || fail "archive layout changed"

sheets=${ZLYME_ARTBOOK_SHEETS:-$work/sheets}
mkdir -p "$sheets" "$work/once/system" "$work/once/tools"
tmp_before=$(find /tmp -maxdepth 1 -type d -name 'zlyme-artbook-*' | sort)
echo stale > "$work/once/system/(GONE).png"
echo stale > "$work/once/tools/Obsolete Tool.png"
/usr/bin/python3 "$PKG/compose.py" \
	--upstream "$upstream" \
	--out "$work/once" \
	--map "$PKG/systems.txt" \
	--tools "$PKG/tools" \
	--paks "$PAKS" \
	--font "$PKG/fonts/DejaVuSans-Bold.ttf" \
	--rsvg /usr/bin/rsvg-convert \
	--contact "$sheets"
/usr/bin/python3 "$PKG/compose.py" \
	--upstream "$upstream" \
	--out "$work/twice" \
	--map "$PKG/systems.txt" \
	--tools "$PKG/tools" \
	--paks "$PAKS" \
	--font "$PKG/fonts/DejaVuSans-Bold.ttf" \
	--rsvg /usr/bin/rsvg-convert
if ! cmp -s "$work/once/tools/Files.png" "$work/twice/tools/Files.png"; then
	fail "tool output is not deterministic"
fi
if ! cmp -s "$work/once/system/(GB).png" "$work/twice/system/(GB).png"; then
	fail "system output is not deterministic"
fi
test ! -e "$work/once/system/(GONE).png" || fail "removed system art survived"
test ! -e "$work/once/tools/Obsolete Tool.png" || fail "removed tool art survived"
tmp_after=$(find /tmp -maxdepth 1 -type d -name 'zlyme-artbook-*' | sort)
if [ "$tmp_before" != "$tmp_after" ]; then
	fail "temporary directory leaked"
fi

fix=$work/fixture
mkdir -p "$fix/paks" "$fix/tools" "$fix/out/tools" "$fix/out/system"
cp -a "$PKG/tools/Files.pak" "$fix/tools/"
cp -a "$PAKS/Files.pak" "$fix/paks/"
printf 'GB gb GAME BOY\n' > "$fix/map.txt"
echo old > "$fix/out/tools/Music Player.png"
echo old > "$fix/out/system/(GONE).png"
/usr/bin/python3 "$PKG/compose.py" \
	--upstream "$upstream" \
	--out "$fix/out" \
	--map "$fix/map.txt" \
	--tools "$fix/tools" \
	--paks "$fix/paks" \
	--font "$PKG/fonts/DejaVuSans-Bold.ttf" \
	--rsvg /usr/bin/rsvg-convert
test ! -e "$fix/out/tools/Music Player.png" || fail "renamed tool survived a rebuild"
test ! -e "$fix/out/system/(GONE).png" || fail "renamed system survived a rebuild"
test -f "$fix/out/tools/Files.png" || fail "remaining tool was not rendered"
test -f "$fix/out/system/(GB).png" || fail "remaining system was not rendered"
tmp_after=$(find /tmp -maxdepth 1 -type d -name 'zlyme-artbook-*' | sort)
if [ "$tmp_before" != "$tmp_after" ]; then
	fail "temporary directory leaked after a fixture rebuild"
fi
printf 'NOPE nope NOPE\n' > "$work/bad-map.txt"
if /usr/bin/python3 "$PKG/compose.py" \
	--upstream "$upstream" \
	--out "$work/bad-out" \
	--map "$work/bad-map.txt" \
	--tools "$PKG/tools" \
	--paks "$PAKS" \
	--font "$PKG/fonts/DejaVuSans-Bold.ttf" \
	--rsvg /usr/bin/rsvg-convert
then
	fail "a missing system picture was accepted"
fi
tmp_after=$(find /tmp -maxdepth 1 -type d -name 'zlyme-artbook-*' | sort)
if [ "$tmp_before" != "$tmp_after" ]; then
	fail "temporary directory leaked after a failed render"
fi

/usr/bin/python3 - "$PKG/compose.py" "$work" "$PKG" "$PAKS" << 'PY'
import importlib.util, shutil, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("compose", sys.argv[1])
compose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compose)
work, pkg, paks = map(Path, sys.argv[2:])
if compose.svg_text("A & B <C>") != "A &amp; B &lt;C&gt;":
    raise SystemExit("pak name was not escaped")
tools = work / "partial"
tools.mkdir()
shutil.copytree(pkg / "tools" / "Files.pak", tools / "Files.pak")
try:
    compose.check_tools(tools, paks)
except SystemExit as exc:
    text = str(exc)
    if "Moonlight.pak" not in text:
        raise SystemExit("missing tool was not named: " + text)
else:
    raise SystemExit("partial tool tree was accepted")
extra = work / "extra"
shutil.copytree(pkg / "tools", extra)
(extra / "Not A Tool.pak").mkdir()
(extra / "Not A Tool.pak" / "background.png").write_bytes(b"nope")
try:
    compose.check_tools(extra, paks)
except SystemExit as exc:
    if "Not A Tool.pak" not in str(exc):
        raise SystemExit("extra background was not named: " + str(exc))
else:
    raise SystemExit("unknown tool background was accepted")
from PIL import Image
mask = compose.load_alpha_mask(pkg / "resources" / "system-art-alpha.png")
compose.validate_mask(mask)
rect = Image.new("RGBA", mask.size, (0, 0, 0, 255))
if compose.respects_mask(rect, mask):
    raise SystemExit("a black rectangle matched the silhouette")
clipped = compose.apply_canonical_mask(rect, mask)
if not compose.respects_mask(clipped, mask):
    raise SystemExit("normalized art still leaves the silhouette")
if clipped.getpixel((0, 0))[3] != 0:
    raise SystemExit("exterior pixel stayed opaque")
if clipped.getpixel((200, 0)) != (0, 0, 0, 255):
    raise SystemExit("interior pixel was changed")
painted = Image.new("RGBA", mask.size, (10, 20, 30, 255))
painted.putpixel((200, 40), (7, 8, 9, 200))
again = compose.apply_canonical_mask(painted, mask)
if again.getpixel((200, 40)) != (7, 8, 9, 200):
    raise SystemExit("interior artwork was rewritten")
if again.getpixel((0, 0))[3] != 0:
    raise SystemExit("upper exterior stayed opaque")
stage = work / "stage-src"
dest = work / "stage-dest"
stage.mkdir()
dest.mkdir()
(stage / "Files.png").write_text("new")
(dest / "Music Player.png").write_text("old")
compose.publish_tree(stage, dest)
if (dest / "Music Player.png").exists() or (dest / "Files.png").read_text() != "new":
    raise SystemExit("publish left a stale file")
print("drop-in checks ok")
PY

# Pixel contract. rom-dirs is beside the package tree.
/usr/bin/python3 - "$PKG/compose.py" "$work/once" "$ROOT/package/system/nextui/rom-dirs.txt" "$PAKS" << 'PY'
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("compose", sys.argv[1])
compose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compose)
art, roms, paks = Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
if (art / "list").exists():
    sys.exit("list wallpaper was generated")
import re
tags = []
for line in roms.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    tags.append(re.search(r"\(([^)]+)\)$", line).group(1))
expected = ["(%s).png" % tag for tag in tags]
got = sorted(p.name for p in (art / "system").iterdir())
if got != sorted(expected):
    sys.exit("system inventory %s" % (set(got) ^ set(expected)))
tool_names = sorted(p.name[:-4] + ".png" for p in paks.iterdir() if p.name.endswith(".pak"))
got_tools = sorted(p.name for p in (art / "tools").iterdir())
if got_tools != tool_names:
    sys.exit("tool inventory %s" % (set(got_tools) ^ set(tool_names)))
for tag in tags:
    image = compose.load_rgba(art / "system" / ("(%s).png" % tag))
    if image.size != (640, 480) or image.mode != "RGBA":
        sys.exit("bad system image " + tag)
    box = compose.content_box(image)
    if box[4] < 1000 or box[0] < compose.SAFE_X:
        sys.exit("system art crosses the name column " + tag)
for pak in sorted(p.name for p in paks.iterdir() if p.name.endswith(".pak")):
    label = pak[:-4]
    image = compose.load_rgba(art / "tools" / (label + ".png"))
    if image.size != (640, 480) or image.mode != "RGBA":
        sys.exit("bad tool image " + label)
    box = compose.content_box(image)
    if box[4] < 1000 or box[0] < compose.SAFE_X:
        sys.exit("tool art crosses the name column " + label)
special = art / "special"
names = sorted(p.name for p in special.iterdir()) if special.is_dir() else []
if names != ["recent.png"]:
    sys.exit("special inventory %s" % names)
image = compose.load_rgba(special / "recent.png")
if image.size != (640, 480) or image.mode != "RGBA":
    sys.exit("bad recent image")
box = compose.content_box(image)
if box[4] < 1000 or box[0] < compose.SAFE_X:
    sys.exit("recent art crosses the name column")
print("rendered", len(tags), "tools", len(list(paks.glob('*.pak'))), "special", 1)
PY

# A long name and a name with markup still fit, and the source file is untouched.
before=$(sha256sum "$PKG/tools/USB File Transfer.pak/background.png" | awk '{print $1}')
/usr/bin/python3 - "$PKG/compose.py" "$work/long" "$PKG" "$upstream" << 'PY'
import importlib.util, sys, tempfile
from pathlib import Path
spec = importlib.util.spec_from_file_location("compose", sys.argv[1])
compose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compose)
out, pkg, upstream = map(Path, sys.argv[2:])
work = out / "w"
work.mkdir(parents=True)
logo = compose.wordmark("USB File Transfer", pkg / "fonts" / "DejaVuSans-Bold.ttf", "/usr/bin/rsvg-convert", work)
if logo.width > compose.LOGO_MAX_W:
    raise SystemExit("long name is wider than 291")
logo = compose.wordmark("A & B <C>", pkg / "fonts" / "DejaVuSans-Bold.ttf", "/usr/bin/rsvg-convert", work)
if logo.width > compose.LOGO_MAX_W:
    raise SystemExit("escaped name does not fit")
print("names ok", logo.width)
PY
after=$(sha256sum "$PKG/tools/USB File Transfer.pak/background.png" | awk '{print $1}')
[ "$before" = "$after" ] || fail "build rewrote a tool background"
if grep -n 'logo.height - 24' "$PKG/compose.py"; then
	fail "tool logos still use a separate vertical position"
fi

/usr/bin/python3 - "$PKG/compose.py" "$work/geom" "$PKG" "$upstream" << 'PY'
import importlib.util, sys
from pathlib import Path
from PIL import Image
spec = importlib.util.spec_from_file_location("compose", sys.argv[1])
compose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compose)
out, pkg, upstream = map(Path, sys.argv[2:])
work = out / "w"
work.mkdir(parents=True)
font = pkg / "fonts" / "DejaVuSans-Bold.ttf"
rsvg = "/usr/bin/rsvg-convert"
target_x = compose.SAFE_X + compose.REGION_W / 2
target_y = compose.HEIGHT / 2

def expect(name, mark, light):
    if mark.width > compose.LOGO_MAX_W or mark.height > compose.HEIGHT:
        raise SystemExit(name + " does not fit")
    x, y = compose.logo_origin(mark)
    cx = x + mark.width / 2
    cy = y + mark.height / 2
    if abs(cx - target_x) > 0.5 or abs(cy - target_y) > 0.5:
        raise SystemExit("%s center %.2f,%.2f" % (name, cx, cy))
    # The styled box is the logo. Composite it on both themes and keep
    # that same origin. The background art is not part of this box.
    for theme in ((16, 16, 18, 255), (236, 232, 224, 255)):
        canvas = Image.new("RGBA", (compose.WIDTH, compose.HEIGHT), theme)
        compose.place(canvas, mark)
        if canvas.getpixel((x, y))[3] == 0 and mark.getpixel((0, 0))[3] != 0:
            raise SystemExit(name + " was not placed at its origin")
        if y + mark.height > compose.HEIGHT or x + mark.width > compose.WIDTH:
            raise SystemExit(name + " is clipped")
    print("center", name, mark.size, "at", x, y, "light" if light else "dark")

square = Image.new("RGBA", (20, 20), (255, 255, 255, 255))
styled = compose.styled_logo(square)
if styled.size != (20 + compose.SHADOW * 2, 20 + compose.SHADOW * 2):
    raise SystemExit("shadow padding changed")
# Two pixels outside the white square is the black contour.
if styled.getpixel((compose.SHADOW - compose.OUTLINE, compose.SHADOW + 10))[:3] != (0, 0, 0):
    raise SystemExit("contour is not black")
# Farther out is the 50% shadow, not a second formula.
shadow = styled.getpixel((1, compose.SHADOW + 10))
if shadow[3] < 100 or shadow[3] > 140 or shadow[:3] != (0, 0, 0):
    raise SystemExit("shadow is not 50% black: %s" % (shadow,))

for label in ("Files", "PortMaster", "RetroArch", "USB File Transfer", "ZcrapeGoat", "Recently Played"):
    expect(label, compose.wordmark(label, font, rsvg, work), True)
logos = upstream / "_inc" / "systems" / "logos"
wide_name = None
wide_ratio = 0
for stem in ("gb", "psx", "genesis", "snes", "nes", "n64"):
    mark = compose.prepare_system_logo(logos / ("%s.svg" % stem), font, rsvg, work)
    expect(stem, mark, False)
    ratio = mark.width / max(1, mark.height)
    if ratio > wide_ratio:
        wide_ratio = ratio
        wide_name = stem
print("logo geometry ok", "widest", wide_name, round(wide_ratio, 2))
PY

test -f "$sheets/systems-light.png"
test -f "$sheets/systems-dark.png"
test -f "$sheets/tools-light.png"
test -f "$sheets/tools-dark.png"
test -f "$sheets/special-light.png"
test -f "$sheets/special-dark.png"
sh "$ROOT/scripts/tests/test_recent_art.sh"
sh "$ROOT/scripts/tests/test_artbook_rootfs.sh"
echo "artbook ok"
