#!/bin/sh
# MAME 2003-Plus (and some FBNeo sets) look for BIOS zips next to the
# game. NextUI would list those zips as games if they sat in Roms/.
# Stage symlinks from Bios/ plus the game zip, then print the staged path.
#
#   zlyme-arcade-stage TAG /path/to/game.zip

TAG=${1:-}
ROM=${2:-}
BIOS_PATH="${BIOS_PATH:-/storage/Bios}"

if [ -z "$TAG" ] || [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
	echo "$ROM"
	exit 0
fi

dest=/tmp/zlyme-arcade-$TAG
rm -rf "$dest"
mkdir -p "$dest" || {
	echo "$ROM"
	exit 0
}

link_zip() {
	f=$1
	[ -e "$f" ] || return 0
	bn=$(basename "$f")
	[ -e "$dest/$bn" ] && return 0
	ln -s "$f" "$dest/$bn" 2>/dev/null || true
}

# Game first so a same-named zip in Bios/ cannot hide the ROM.
link_zip "$ROM"

for d in \
	"$BIOS_PATH" \
	"$BIOS_PATH/$TAG" \
	"$BIOS_PATH/fbneo" \
	"$BIOS_PATH/FBNEO" \
	"$BIOS_PATH/mame2003-plus" \
	"$BIOS_PATH/MAME"
do
	[ -d "$d" ] || continue
	for f in "$d"/*.zip "$d"/*.7z "$d"/*.ZIP "$d"/*.7Z; do
		[ -e "$f" ] || continue
		link_zip "$f"
	done
done

echo "$dest/$(basename "$ROM")"
