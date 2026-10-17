#!/bin/sh
# ArtBook is firmware. This checks the inventory function and that
# NextUI selects the package. It does not build a product image.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CHECK=$ROOT/board/my355/assert-input-rootfs.sh
fail() { echo "artbook-rootfs: $*" >&2; exit 1; }

grep -q 'select BR2_PACKAGE_ZLYME_ARTBOOK' "$ROOT/package/system/nextui/Config.in" \
	|| fail "NextUI does not select ArtBook"
grep -q 'zlyme-artbook' "$ROOT/package/system/nextui/nextui.mk" \
	|| fail "NextUI does not depend on zlyme-artbook"
grep -q '^BR2_PACKAGE_NEXTUI=y$' "$ROOT/configs/zlyme_my355_defconfig" \
	|| fail "product defconfig has no NextUI"
grep -q '^BR2_PACKAGE_ZLYME_ARTBOOK=y$' "$ROOT/configs/zlyme_my355_defconfig" \
	|| fail "product defconfig has no ArtBook"
if grep -q '^BR2_PACKAGE_NEXTUI=y$' "$ROOT/configs/zlyme_my355_minimal_defconfig" \
	|| grep -q '^BR2_PACKAGE_ZLYME_ARTBOOK=y$' "$ROOT/configs/zlyme_my355_minimal_defconfig"
then
	fail "minimal image selects NextUI or ArtBook"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
base=$work/good/usr/share/nextui/artbook
mkdir -p "$base/system" "$base/tools"
cp "$ROOT/package/system/zlyme-artbook/NOTICE.md" "$base/NOTICE.md"
/usr/bin/python3 - "$ROOT" "$base" << 'PY'
import re
import struct
import sys
import zlib
from pathlib import Path

repo, base = map(Path, sys.argv[1:])

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

def png():
    raw = b"".join(b"\x00" + (b"\x00" * 4 * 640) for _ in range(480))
    ihdr = struct.pack(">IIBBBBB", 640, 480, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

body = png()
tags = []
for line in (repo / "package/system/nextui/rom-dirs.txt").read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    tags.append(re.search(r"\(([^)]+)\)$", line).group(1))
for tag in tags:
    (base / "system" / ("(%s).png" % tag)).write_bytes(body)
paks = repo / "package/system/nextui/paks/Tools"
for pak in paks.iterdir():
    if pak.name.endswith(".pak"):
        (base / "tools" / (pak.name[:-4] + ".png")).write_bytes(body)
(base / "special").mkdir()
(base / "special" / "recent.png").write_bytes(body)
(base / "special" / "tools.png").write_bytes(body)
print("fixture", len(tags), len(list(paks.glob("*.pak"))), 2)
PY

"$CHECK" --check-artbook "$work/good"

expect_reject() {
	tree=$1
	needle=$2
	if out=$("$CHECK" --check-artbook "$tree" 2>&1); then
		fail "accepted a bad tree ($needle)"
	fi
	printf '%s\n' "$out" | grep -q "$needle" || fail "bad tree did not report $needle: $out"
}

bad=$work/bad
cp -a "$work/good" "$bad"
rm -f "$bad/usr/share/nextui/artbook/system/(GB).png"
expect_reject "$bad" "inventory mismatch"

cp -a "$work/good" "$work/notools"
rm -f "$work/notools/usr/share/nextui/artbook/special/tools.png"
expect_reject "$work/notools" "inventory mismatch"

cp -a "$work/good" "$work/extra"
mkdir -p "$work/extra/usr/share/nextui/artbook/list"
printf 'nope' > "$work/extra/usr/share/nextui/artbook/list/(GB)-list.png"
expect_reject "$work/extra" "list wallpaper"

cp -a "$work/good" "$work/svg"
printf '<svg/>' > "$work/svg/usr/share/nextui/artbook/system/logo.svg"
expect_reject "$work/svg" "source asset"

cp -a "$work/good" "$work/size"
printf 'not a png' > "$work/size/usr/share/nextui/artbook/tools/Files.png"
expect_reject "$work/size" "not a 640x480 RGBA PNG"

# A header-sized prefix used to pass. Pillow has to decode the image.
cp -a "$work/good" "$work/trunc"
dd if="$work/good/usr/share/nextui/artbook/tools/Files.png" \
	of="$work/trunc/usr/share/nextui/artbook/tools/Files.png" \
	bs=32 count=1 status=none
expect_reject "$work/trunc" "not a 640x480 RGBA PNG"

echo "artbook rootfs ok"
