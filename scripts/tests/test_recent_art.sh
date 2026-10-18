#!/bin/sh
# Recently Played uses NextUI's existing .media path. The seed copies
# the firmware picture once. It is not a Tool pak.
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
grep -q '2c3fe9093230e4a85c02e2dd350755f035f2dbce' \
	"$ROOT/package/system/nextui/nextui.mk" || fail "NextUI pin changed"

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
broken=$(mktemp -d)
trap 'rm -rf "$card" "$custom" "$global" "$broken"' EXIT
mkdir -p "$card/.config" "$card/Recently Played"
printf 'history\n' > "$card/Recently Played/list.txt"

run_seed "$card"
dest="$card/Recently Played/.media/bg.png"
[ -f "$dest" ] || fail "first seed did not copy"
cmp -s "$SRC" "$dest" || fail "seeded file is not the firmware picture"
[ -f "$card/.config/zlyme/recent-art-seeded" ] || fail "marker missing"
[ "$(cat "$card/Recently Played/list.txt")" = "history" ] || fail "history changed"

printf 'changed\n' > "$dest"
run_seed "$card"
[ "$(cat "$dest")" = "changed" ] || fail "second seed overwrote the picture"

rm -f "$dest"
run_seed "$card"
[ ! -e "$dest" ] || fail "deleted stock picture came back"

# A new card with a custom picture is left alone.
mkdir -p "$custom/Recently Played/.media" "$custom/.config"
printf 'mine\n' > "$custom/Recently Played/.media/bg.png"
run_seed "$custom"
[ "$(cat "$custom/Recently Played/.media/bg.png")" = "mine" ] || fail "custom picture changed"
[ -f "$custom/.config/zlyme/recent-art-seeded" ] || fail "custom card was not marked"

# A global background wins, and is not rewritten.
mkdir -p "$global/.config"
printf 'global\n' > "$global/bg.png"
run_seed "$global"
[ ! -e "$global/Recently Played/.media/bg.png" ] || fail "global background did not skip seeding"
[ "$(cat "$global/bg.png")" = "global" ] || fail "global background changed"
[ -f "$global/.config/zlyme/recent-art-seeded" ] || fail "global card was not marked"

# A failed copy does not set the marker, so the next boot can retry.
mkdir -p "$broken/.config" "$broken/Recently Played"
printf 'not-a-directory\n' > "$broken/Recently Played/.media"
if run_seed "$broken"; then
	fail "a blocked copy was treated as success"
fi
[ ! -f "$broken/.config/zlyme/recent-art-seeded" ] || fail "failed copy set the marker"
rm -f "$broken/Recently Played/.media"
run_seed "$broken"
[ -f "$broken/Recently Played/.media/bg.png" ] || fail "retry did not copy"
[ -f "$broken/.config/zlyme/recent-art-seeded" ] || fail "retry did not mark"

# A previous built-in picture, identified by hash, becomes the new one.
old=$(mktemp -d)
known=$(mktemp)
printf 'old-stock\n' > "$old/picture"
oldhash=$(sha256sum "$old/picture" | awk '{print $1}')
printf '%s\n' "$oldhash" > "$known"
mkdir -p "$old/Recently Played/.media" "$old/.config/zlyme"
cp "$old/picture" "$old/Recently Played/.media/bg.png"
: > "$old/.config/zlyme/recent-art-seeded"
printf 'history\n' > "$old/Recently Played/list.txt"
ZLYME_STOCK_ROOT=$old ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	ZLYME_RECENT_ART=$SRC ZLYME_RECENT_KNOWN=$known sh "$SEED"
cmp -s "$SRC" "$old/Recently Played/.media/bg.png" || fail "known stock was not replaced"
[ "$(cat "$old/Recently Played/list.txt")" = "history" ] || fail "migration changed history"

# The current firmware picture is not rewritten.
cur=$(mktemp -d)
mkdir -p "$cur/Recently Played/.media" "$cur/.config/zlyme"
cp "$SRC" "$cur/Recently Played/.media/bg.png"
: > "$cur/.config/zlyme/recent-art-seeded"
before=$(stat -c '%Y' "$cur/Recently Played/.media/bg.png")
sleep 1
ZLYME_STOCK_ROOT=$cur ZLYME_STOCK_SHARE=$SHARE ZLYME_DEVICE_CONF= \
	ZLYME_RECENT_ART=$SRC ZLYME_RECENT_KNOWN=$known sh "$SEED"
cmp -s "$SRC" "$cur/Recently Played/.media/bg.png" || fail "current stock changed"
after=$(stat -c '%Y' "$cur/Recently Played/.media/bg.png")
[ "$before" = "$after" ] || fail "current stock was rewritten"

# A copy that cannot be written leaves the old file in place.
# Root ignores a directory mode, so the failing step is cp itself.
stuck=$(mktemp -d)
fakecp=$(mktemp -d)
mkdir -p "$stuck/Recently Played/.media" "$stuck/.config/zlyme"
cp "$old/picture" "$stuck/Recently Played/.media/bg.png"
: > "$stuck/.config/zlyme/recent-art-seeded"
cat > "$fakecp/cp" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$fakecp/cp"
if PATH="$fakecp:$PATH" ZLYME_STOCK_ROOT=$stuck ZLYME_STOCK_SHARE=$SHARE \
	ZLYME_DEVICE_CONF= ZLYME_RECENT_ART=$SRC ZLYME_RECENT_KNOWN=$known \
	sh "$SEED"; then
	fail "a blocked replacement was treated as success"
fi
cmp -s "$old/picture" "$stuck/Recently Played/.media/bg.png" || fail "blocked replacement changed the picture"
[ -f "$stuck/.config/zlyme/recent-art-seeded" ] || fail "blocked replacement cleared the marker"
rm -rf "$fakecp"

rm -rf "$old" "$cur" "$stuck" "$known"
echo "recent art ok"
