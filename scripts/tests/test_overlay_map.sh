#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-overlay"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_OVERLAY_DB="$work/map.tsv"
a="/storage/Roms/Game Boy Advance (GBA)"
b="/mnt/sd2/Roms/Game Boy Advance (GBA)"
cfg_a="$work/a.cfg"
cfg_b="$work/b.cfg"
"$BIN" write-cfg "$cfg_a" "$work/a.png"
printf '%s\n' 'video_smooth = "false"' >> "$cfg_a"
"$BIN" write-cfg "$cfg_a" "$work/b.png"
grep -q 'video_smooth = "false"' "$cfg_a"
grep -q 'input_overlay = "'"$work/b.png"'"' "$cfg_a"
if grep -c 'input_overlay ' "$cfg_a" | grep -qx 1; then
	:
else
	echo "overlay key duplicated" >&2
	exit 1
fi
"$BIN" assign "$a" "$cfg_a"
"$BIN" assign "$b" "$cfg_b"
test "$("$BIN" for-rom "$a/Game.gba")" = "$cfg_a"
test "$("$BIN" for-rom "$b/Game.gba")" = "$cfg_b"
test "$("$BIN" for-rom "$a/subdir/Game.gba")" = "$cfg_a"
"$BIN" assign "$a" "$cfg_b"
test "$("$BIN" for-rom "$a/Game.gba")" = "$cfg_b"
test "$("$BIN" for-rom "$b/Game.gba")" = "$cfg_b"
echo "overlay map ok"
