#!/bin/sh
# BBS .p8.png carts are their own preview. Normal .media art wins.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ui=/home/ale/zlyme-nextui/workspace/all/nextui/nextui.c
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

art_for() {
	rom=$1
	dir=$(dirname "$rom")
	base=$(basename "$rom")
	stem=${base%.*}
	media="$dir/.media/$stem.png"
	if [ -f "$media" ]; then
		printf '%s\n' "$media"
		return
	fi
	case "$rom" in
		*/Pico-8-native/bbs/carts/*.p8.png)
			printf '%s\n' "$rom"
			;;
		*)
			printf '%s\n' none
			;;
	esac
}

cart="$work/Pico-8-native/bbs/carts/marepike-0.p8.png"
mkdir -p "$(dirname "$cart")"
printf 'png' > "$cart"
test "$(art_for "$cart")" = "$cart"
mkdir -p "$(dirname "$cart")/.media"
printf 'box' > "$(dirname "$cart")/.media/marepike-0.p8.png"
test "$(art_for "$cart")" = "$(dirname "$cart")/.media/marepike-0.p8.png"
other="$work/Roms/Game Boy (GB)/shot.png"
mkdir -p "$(dirname "$other")"
printf 'png' > "$other"
test "$(art_for "$other")" = none
grep -F -q 'Pico-8-native/bbs/carts/' "$ui"
grep -F -q '.media/%s.png' "$ui"
echo "pico art ok"
