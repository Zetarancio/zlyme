#!/bin/sh
# Recently Played art comes from the firmware picture. The seed does
# not copy it. A previous built-in file at the old path is removed so
# it cannot hide the firmware picture. A picture the person made stays.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SEED=$ROOT/package/system/nextui/zlyme/zlyme-stock-seed
SRC=$ROOT/package/system/zlyme-artbook/special/Recently\ Played/background.png
SHARE=$ROOT/board/my355/fsoverlay/usr/share/zlyme
fail() { echo "recent-art: $*" >&2; exit 1; }

[ -f "$SRC" ] || fail "source picture missing"
got=$(sha256sum "$SRC" | awk '{print $1}')
[ "$got" = "95e8f729ee887cd776a49a55dca64521ff14635c8b8765cb8d3df5b27dca5482" ] \
	|| fail "source hash changed"
if [ -e "$ROOT/package/system/nextui/paks/Tools/Recent.pak" ] \
	|| [ -e "$ROOT/package/system/zlyme-artbook/tools/Recent.pak" ]
then
	fail "Recent.pak was added"
fi
grep -q '41f1ef17118ba1bdcd7034c25be677dd8435c65c' \
	"$ROOT/package/system/nextui/nextui.mk" || fail "NextUI pin changed"
if grep -q 'recent-art-seeded' "$SEED"; then
	fail "the seed still writes a marker"
fi

/usr/bin/python3 - "$SRC" "$ROOT/package/system/zlyme-artbook/resources/system-art-alpha.png" << 'PY'
import sys
from PIL import Image, ImageChops
src, mask_path = sys.argv[1:]
image = Image.open(src)
image.load()
if image.size != (454, 1080) or image.mode != "RGBA":
    raise SystemExit("source is not 454x1080 RGBA")
alpha = image.getchannel("A")
raw = alpha.tobytes()
if raw.count(0) != 122128 or sum(1 for v in raw if 0 < v < 255) != 2290:
    raise SystemExit("alpha counts changed")
mask = Image.open(mask_path)
if ImageChops.difference(alpha, mask).getbbox() is not None:
    raise SystemExit("alpha does not match the Art Book mask")
print("source ok")
PY

run_seed() {
	ZLYME_STOCK_ROOT=$1 ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
		ZLYME_RECENT_ART=$SRC sh "$SEED"
}

card=$(mktemp -d)
custom=$(mktemp -d)
global=$(mktemp -d)
trap 'rm -rf "$card" "$custom" "$global"' EXIT

# The whole folder can be absent. Nothing is created.
run_seed "$card"
[ ! -e "$card/Recently Played" ] || fail "seed created Recently Played"
[ ! -e "$card/.config/zlyme/recent-art-seeded" ] || fail "seed wrote the marker"

mkdir -p "$custom/Recently Played/.media"
printf 'mine\n' > "$custom/Recently Played/.media/bg.png"
printf 'history\n' > "$custom/Recently Played/list.txt"
run_seed "$custom"
[ "$(cat "$custom/Recently Played/.media/bg.png")" = "mine" ] || fail "custom picture changed"
[ "$(cat "$custom/Recently Played/list.txt")" = "history" ] || fail "history changed"

mkdir -p "$global/.config"
printf 'global\n' > "$global/bg.png"
run_seed "$global"
[ ! -e "$global/Recently Played" ] || fail "global background created a folder"
[ "$(cat "$global/bg.png")" = "global" ] || fail "global background changed"

# A previous built-in picture is removed. The current firmware bytes stay.
old=$(mktemp -d)
known=$(mktemp)
cur=$(mktemp -d)
printf 'old-stock\n' > "$old/picture"
oldhash=$(sha256sum "$old/picture" | awk '{print $1}')
printf '%s\n' "$oldhash" > "$known"
mkdir -p "$old/Recently Played/.media"
cp "$old/picture" "$old/Recently Played/.media/bg.png"
printf 'history\n' > "$old/Recently Played/list.txt"
ZLYME_STOCK_ROOT=$old ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	ZLYME_RECENT_ART=$SRC ZLYME_RECENT_KNOWN=$known sh "$SEED"
[ ! -e "$old/Recently Played/.media/bg.png" ] || fail "known stock was left in place"
[ "$(cat "$old/Recently Played/list.txt")" = "history" ] || fail "migration changed history"

mkdir -p "$cur/Recently Played/.media"
cp "$SRC" "$cur/Recently Played/.media/bg.png"
before=$(stat -c '%Y' "$cur/Recently Played/.media/bg.png")
sleep 1
ZLYME_STOCK_ROOT=$cur ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	ZLYME_RECENT_ART=$SRC ZLYME_RECENT_KNOWN=$known sh "$SEED"
cmp -s "$SRC" "$cur/Recently Played/.media/bg.png" || fail "current stock changed"
after=$(stat -c '%Y' "$cur/Recently Played/.media/bg.png")
[ "$before" = "$after" ] || fail "current stock was rewritten"

rm -rf "$old" "$cur" "$known"
echo "recent art ok"
