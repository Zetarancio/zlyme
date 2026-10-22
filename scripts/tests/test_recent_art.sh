#!/bin/sh
# Recently Played art comes from the firmware picture. Session start
# does not copy, delete, or rewrite it. An update copies a picture the
# person put at the zlyme44.3 folder path when it is not a built-in
# render and the new override is absent.
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
grep -q '39f5cf0e51ae35c7fd98378791065da596a1d09c' \
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

# Session start leaves a built-in render and a history list alone.
old=$(mktemp -d)
mkdir -p "$old/Recently Played/.media"
printf 'old-stock\n' > "$old/Recently Played/.media/bg.png"
printf 'history\n' > "$old/Recently Played/list.txt"
run_seed "$old"
[ "$(cat "$old/Recently Played/.media/bg.png")" = "old-stock" ] || fail "seed removed old art"
[ "$(cat "$old/Recently Played/list.txt")" = "history" ] || fail "seed changed history"
if grep -q 'seed_recent\|recent-stock' "$SEED"; then
	fail "session seed still migrates Recently Played"
fi

# 44.3 custom art is copied once. Built-in renders are not. The old
# file and the history list stay.
POST=$ROOT/board/my355/post-update.sh
run_update() {
	ZLYME_STORAGE_ROOT=$1 sh "$POST"
}
keep=$(mktemp -d)
mkdir -p "$keep/Recently Played/.media"
printf 'mine\n' > "$keep/Recently Played/.media/bg.png"
printf 'history\n' > "$keep/Recently Played/list.txt"
run_update "$keep"
[ "$(cat "$keep/.config/nextui/shared/artbook/special/recent.png")" = "mine" ] \
	|| fail "44.3 custom art was not kept"
[ "$(cat "$keep/Recently Played/.media/bg.png")" = "mine" ] || fail "update removed the old file"
[ "$(cat "$keep/Recently Played/list.txt")" = "history" ] || fail "update changed history"
run_update "$keep"
[ "$(cat "$keep/.config/nextui/shared/artbook/special/recent.png")" = "mine" ] \
	|| fail "second update rewrote the override"

stock=$(mktemp -d)
dejavu=c67d6a187feecee5f791ae89a723b13c5ba974d0d84080c96a192f15c7f67703
grep -q "$dejavu" "$POST" || fail "update does not know the built-in render"
stub=$(mktemp -d)
cat > "$stub/sha256sum" << EOF
#!/bin/sh
printf '%s  %s\n' '$dejavu' "\$1"
EOF
chmod 755 "$stub/sha256sum"
mkdir -p "$stock/Recently Played/.media"
printf 'builtin\n' > "$stock/Recently Played/.media/bg.png"
PATH="$stub:$PATH" run_update "$stock"
[ ! -e "$stock/.config/nextui/shared/artbook/special/recent.png" ] \
	|| fail "built-in render became the override"
[ "$(cat "$stock/Recently Played/.media/bg.png")" = "builtin" ] || fail "built-in render was deleted"

owned=$(mktemp -d)
mkdir -p "$owned/.config/nextui/shared/artbook/special"
printf 'kept\n' > "$owned/.config/nextui/shared/artbook/special/recent.png"
mkdir -p "$owned/Recently Played/.media"
printf 'older\n' > "$owned/Recently Played/.media/bg.png"
run_update "$owned"
[ "$(cat "$owned/.config/nextui/shared/artbook/special/recent.png")" = "kept" ] \
	|| fail "existing override was replaced"

rm -rf "$old" "$keep" "$stock" "$stub" "$owned"
echo "recent art ok"
