#!/bin/sh
# PortMaster artwork is copied onto the card that holds the port.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ART=$ROOT/package/system/portmaster/zlyme-portmaster-art
LAUNCH=$ROOT/package/system/portmaster/portmaster-launch
MK=$ROOT/package/system/portmaster/portmaster.mk

fail() {
	echo "portmaster art: $*" >&2
	exit 1
}

[ -f "$ART" ] || fail "missing art helper"
grep -q 'zlyme-portmaster-art' "$MK" || fail "the image does not install the art helper"
grep -q 'zlyme-portmaster-art' "$LAUNCH" || fail "PortMaster does not publish art on exit"
if grep -q 'zlyme-portmaster-root set' "$ART"; then
	fail "artwork changes the selected library"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd1=$work/sd1
sd2=$work/sd2
ports1="$sd1/Roms/Ports (PORTS)"
ports2="$sd2/Roms/Ports (PORTS)"
mkdir -p "$ports1/A Key(s) Path" "$ports1/gamedata" "$ports1/Bare" \
	"$ports1/a-data" "$ports1/b-data" "$ports2/A Key(s) Path" \
	"$work/bin" "$work/other/Roms/Ports (PORTS)/Secret"
printf '%s\n' cover1 > "$ports1/A Key(s) Path/cover.png"
printf '%s\n' shot1 > "$ports1/A Key(s) Path/screenshot.png"
printf '%s\n' '#!/bin/sh' > "$ports1/A Key(s) Path.sh"
printf '%s\n' odd-cover > "$ports1/gamedata/screenshot.png"
cat > "$ports1/gamedata/port.json" << 'EOF'
{"items": ["Odd Name.sh", "gamedata/"]}
EOF
printf '%s\n' '#!/bin/sh' > "$ports1/Odd Name.sh"
printf '%s\n' '#!/bin/sh' > "$ports1/Bare.sh"
printf '%s\n' kept > "$ports1/Bare/readme.txt"
mkdir -p "$ports1/.media" "$ports1/Kept"
printf '%s\n' user-art > "$ports1/.media/Kept.png"
printf '%s\n' '#!/bin/sh' > "$ports1/Kept.sh"
printf '%s\n' port-art > "$ports1/Kept/cover.png"
printf '%s\n' jpeg-bytes > "$ports1/A Key(s) Path/cover.jpg"
printf '%s\n' a-cover > "$ports1/a-data/cover.png"
printf '%s\n' b-cover > "$ports1/b-data/cover.png"
cat > "$ports1/a-data/port.json" << 'EOF'
{"items": ["Shared.sh"]}
EOF
cat > "$ports1/b-data/port.json" << 'EOF'
{"items": ["Shared.sh"]}
EOF
printf '%s\n' '#!/bin/sh' > "$ports1/Shared.sh"
printf '%s\n' cover2 > "$ports2/A Key(s) Path/cover.png"
printf '%s\n' '#!/bin/sh' > "$ports2/A Key(s) Path.sh"
printf '%s\n' '#!/bin/sh' > "$ports2/Missing.sh"
# A symlink image is not a file on exFAT and is not copied.
ln -s "$ports2/A Key(s) Path/cover.png" "$ports1/Bare/cover.png"
mkdir -p "$work/sd3/Roms"
ln -s "$work/other/Roms/Ports (PORTS)" "$work/sd3/Roms/Ports (PORTS)"
printf '%s\n' other-secret > "$work/other/Roms/Ports (PORTS)/Secret/cover.png"
printf '%s\n' '#!/bin/sh' > "$work/other/Roms/Ports (PORTS)/Secret.sh"
printf '%s\n' "$sd1" "$sd2" "$work/sd3" > "$work/roots"
flag=$work/portmaster-root
printf '%s\n' "$sd2" > "$flag"

gcc -std=c11 -Wall -Wextra -Werror -O2 -o "$work/bin/artpng" \
	"$ROOT/package/system/portmaster/zlyme-portmaster-artpng.c" -ljpeg -lpng \
	|| fail "the JPEG converter did not compile"
command -v ffmpeg >/dev/null 2>&1 || fail "the host has no ffmpeg to make a JPEG fixture"

ZLYME_PM_ART_ROOTS=$work/roots \
	ZLYME_PM_ART_JPEG=$work/bin/artpng \
	sh "$ART"
[ "$(cat "$ports1/.media/A Key(s) Path.png")" = cover1 ] \
	|| fail "cover did not win over screenshot"
[ "$(cat "$ports1/.media/Odd Name.png")" = odd-cover ] \
	|| fail "port.json did not match the launcher"
[ ! -e "$ports1/.media/Bare.png" ] || fail "a missing image was published"
[ "$(cat "$ports1/.media/Kept.png")" = user-art ] \
	|| fail "user artwork was replaced"
[ "$(cat "$ports1/.media/Shared.png")" = a-cover ] \
	|| fail "duplicate directories did not use the sorted port"
[ "$(cat "$ports2/.media/A Key(s) Path.png")" = cover2 ] \
	|| fail "SD2 received SD1 artwork"
cmp -s "$ports1/.media/A Key(s) Path.png" "$ports2/.media/A Key(s) Path.png" \
	&& fail "the same port name was given one image"
[ ! -e "$ports2/.media/Missing.png" ] || fail "SD2 published a missing image"
[ ! -e "$work/other/Roms/Ports (PORTS)/.media/Secret.png" ] \
	|| fail "a symlinked ports directory was scanned"
[ "$(cat "$flag")" = "$sd2" ] || fail "the selected library changed"
[ -f "$ports1/A Key(s) Path.sh" ] || fail "a launcher was moved"
[ -f "$ports2/A Key(s) Path/cover.png" ] || fail "SD2 art was removed"

before=$(stat -c %Y "$ports1/.media/A Key(s) Path.png")
ZLYME_PM_ART_ROOTS=$work/roots \
	ZLYME_PM_ART_JPEG=$work/bin/artpng \
	sh "$ART"
after=$(stat -c %Y "$ports1/.media/A Key(s) Path.png")
[ "$before" = "$after" ] || fail "a second launch rewrote published artwork"

# A JPEG the converter cannot read stays unpublished, with one diagnostic.
rm -rf "$ports1/Jpeg" "$ports1/.media/Jpeg.png"
mkdir -p "$ports1/Jpeg"
printf '%s\n' jpeg-src > "$ports1/Jpeg/cover.jpg"
printf '%s\n' '#!/bin/sh' > "$ports1/Jpeg.sh"
ZLYME_PM_ART_ROOTS=$work/roots \
	ZLYME_PM_ART_JPEG=$work/missing-artpng \
	sh "$ART" >"$work/jpeg-miss.out" 2>"$work/jpeg-miss.err"
[ ! -e "$ports1/.media/Jpeg.png" ] || fail "a JPEG was published without a converter"
grep -q 'Jpeg.sh: could not publish cover.jpg' "$work/jpeg-miss.err" \
	|| fail "a failed JPEG was silent"
[ -z "$(find "$ports1/.media" -name '.zlyme-art.*' -print)" ] \
	|| fail "a failed JPEG left a temporary file"

# The installed port layout: launcher case differs from the directory,
# and the only image is screenshot.jpg.
mkdir -p "$ports2/abombniball"
cat > "$ports2/abombniball/port.json" << 'EOF'
{"items": ["Abombniball.sh", "abombniball/"], "attr": {"title": "Abombniball"}}
EOF
printf '%s\n' '#!/bin/sh' > "$ports2/Abombniball.sh"
ffmpeg -nostdin -y -loglevel error -f lavfi -i color=c=blue:s=8x8 \
	-frames:v 1 "$ports2/abombniball/screenshot.jpg"
# cover.png in a different directory name wins over a JPEG.
mkdir -p "$ports1/Case Diff"
printf '%s\n' cover-wins > "$ports1/Case Diff/cover.png"
printf '%s\n' '#!/bin/sh' > "$ports1/Case Diff.sh"
ffmpeg -nostdin -y -loglevel error -f lavfi -i color=c=green:s=4x4 \
	-frames:v 1 "$ports1/Case Diff/screenshot.jpg"
# Wait: stem "Case Diff" matches the directory, so cover.png is found
# without port.json. The differing-name case is Abombniball.

ZLYME_PM_ART_ROOTS=$work/roots \
	ZLYME_PM_ART_JPEG=$work/bin/artpng \
	sh "$ART" >"$work/jpeg.out" 2>"$work/jpeg.err"
sig=$(od -An -tx1 -N8 "$ports2/.media/Abombniball.png" | tr -d ' \n')
[ "$sig" = "89504e470d0a1a0a" ] || fail "screenshot.jpg was not published as the launcher name ($sig)"
[ "$(cat "$ports1/.media/Case Diff.png")" = cover-wins ] \
	|| fail "cover.png did not win over screenshot.jpg"
jpeg=$(od -An -tx1 -N3 "$ports2/abombniball/screenshot.jpg" | tr -d ' \n')
[ "$jpeg" = "ffd8ff" ] || fail "the JPEG source was rewritten ($jpeg)"
[ ! -e "$ports2/.media/abombniball.png" ] || fail "artwork used the directory name instead of the launcher"
grep -q 'Abombniball.sh' "$work/jpeg.err" && fail "a published JPEG was reported as a failure"

before=$(stat -c %Y "$ports2/.media/Abombniball.png")
ZLYME_PM_ART_ROOTS=$work/roots \
	ZLYME_PM_ART_JPEG=$work/bin/artpng \
	sh "$ART" >"$work/again.out" 2>"$work/again.err"
after=$(stat -c %Y "$ports2/.media/Abombniball.png")
[ "$before" = "$after" ] || fail "a second import rewrote published artwork"

echo "portmaster art ok"
