#!/bin/sh
# Splore titles come from nfo or cart text, via map.txt. Carts are not copied.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pico-bbs
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

shared=$work/shared/Pico-8-native
carts=$shared/bbs/carts
roms=$work/card/Roms/Pico-8\ \(PICO\)
mkdir -p "$carts" "$roms" "$work/bin" "$carts/../1"

printf 'png' > "$carts/marepike-0.p8.png"
printf '%s\n' 'title:Last Bullet' 'author:KaynEterno' > "$carts/temp-marepike.nfo"
printf 'partial' > "$carts/temp-partial.p8.png"
printf 'png' > "$carts/plain-0.p8.png"
printf 'user' > "$roms/MyGame.p8"
printf 'MyGame.p8\tMine\n' > "$roms/map.txt"
printf 'png' > "$shared/bbs/1/15133.p8.png"
mkdir -p "$work/card/Roms/Game Boy (GB)"
printf 'png' > "$work/card/Roms/Game Boy (GB)/shot.png"

cat > "$work/bin/pico8-data-extractor" <<'EOF'
#!/bin/sh
case "$1" in
	*plain-0.p8.png) printf '%s\n' '-- ~Plain Game~' ;;
	*) exit 1 ;;
esac
EOF
chmod 0755 "$work/bin/pico8-data-extractor" "$BIN"

PATH=$work/bin:$PATH \
ZLYME_PICO_SHARED=$shared \
ZLYME_PICO_ROMDIR=$roms \
ZLYME_PICO_EXTRACTOR=$work/bin/pico8-data-extractor \
	"$BIN"

row() {
	awk -F '\t' -v k="$1" '$1 == k { print $2; exit }' "$roms/map.txt"
}
test "$(row marepike-0.p8.png)" = "Last Bullet"
test "$(row plain-0.p8.png)" = "Plain Game"
test "$(row 15133.p8.png)" = "15133"
test "$(row MyGame.p8)" = "Mine"
if awk -F '\t' '$1 ~ /^temp-/ { found=1 } END { exit !found }' "$roms/map.txt"; then
	echo "temp cart was listed" >&2
	exit 1
fi
if [ -e "$roms/marepike-0.p8.png" ] || [ -e "$roms/.media/marepike-0.p8.png" ] || [ -e "$roms/.res/marepike-0.p8.png" ]; then
	echo "cart was copied" >&2
	exit 1
fi
if grep -q shot.png "$roms/map.txt"; then
	echo "ordinary png was indexed" >&2
	exit 1
fi

rm -f "$carts/marepike-0.p8.png"
mv "$carts/plain-0.p8.png" "$carts/renamed-0.p8.png"
PATH=$work/bin:$PATH \
ZLYME_PICO_SHARED=$shared \
ZLYME_PICO_ROMDIR=$roms \
ZLYME_PICO_EXTRACTOR=$work/bin/pico8-data-extractor \
	"$BIN"
if awk -F '\t' '$1 == "marepike-0.p8.png" { found=1 } END { exit !found }' "$roms/map.txt"; then
	echo "removed cart alias remained" >&2
	exit 1
fi
test "$(row renamed-0.p8.png)" = "renamed-0"
test "$(row MyGame.p8)" = "Mine"
echo "pico bbs ok"
