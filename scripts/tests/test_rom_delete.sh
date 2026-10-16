#!/bin/sh
# Delete Game removes one ROM and its own saves, art, preference, and recent row.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_CLEANUP_ROOT="$work/storage"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_RECENT_FILE="$work/storage/.config/nextui/shared/.minui/recent.txt"
export ZLYME_PREFS_FILE="$work/storage/.config/nextui/shared/zlyme-prefs.txt"
export ZLYME_LIBRARY_SH="$ROOT/package/system/nextui/zlyme/zlyme-library.sh"
export ZLYME_RUN_DIR="$work/run"
export ZLYME_SD2_ROOT="$work/sd2"
export ZLYME_MEDIA_ROOT="$work/media"
printf '%s\n' "$work/storage" "$work/sd2" > "$work/libraries"
a="$work/storage/Roms/Game Boy Advance (GBA)"
b="$work/sd2/Roms/Game Boy Advance (GBA)"
nest="$work/storage/Roms/Game Boy (GB)/nested"
mkdir -p "$a/.media" "$b/.media" "$nest/.media" \
	"$work/storage/Saves/GBA" "$work/sd2/Saves/GBA" "$work/storage/Saves/GB" \
	"$(dirname "$ZLYME_RECENT_FILE")" \
	"$work/storage/.config/nextui/shared/Pico-8-native"

fail() {
	echo "rom delete: $*" >&2
	exit 1
}

rom="$a/It's a \"game\".gba"
printf 'rom' > "$rom"
printf 'save' > "$work/storage/Saves/GBA/It's a \"game\".sav"
printf 'state' > "$work/storage/Saves/GBA/It's a \"game\".state"
printf 'art' > "$a/.media/It's a \"game\".png"
printf 'note' > "$a/.media/It's a \"game\".txt"
printf 'other' > "$b/It's a \"game\".gba"
printf 'keep' > "$work/sd2/Saves/GBA/It's a \"game\".sav"
printf 'keepart' > "$b/.media/It's a \"game\".png"
printf 'bin' > "$a/disc.bin"
cue="$a/disc.cue"
printf 'FILE disc.bin BINARY\n' > "$cue"
printf 'shared' > "$a/Twin.gba"
printf 'also' > "$a/Twin.gbc"
printf 'box' > "$a/.media/Twin.png"
printf 'mine' > "$nest/only.gb"
printf 'box' > "$nest/.media/only.png"
printf 'side' > "$nest/.media/other.png"
prefs=$ZLYME_PREFS_FILE
{
	printf 'rom\tGBA\t%s\tplay\tmgba\n' "It's a \"game\".gba"
	printf 'rom\tGBA\t%s\theavy\ttvba\n' "SD2/It's a \"game\".gba"
	printf 'rom\tGB\t%s\tidle\tgambatte\n' 'nested/only.gb'
	printf 'rom\tGBA\t%s\tsmart\tmgba\n' 'Twin.gba'
	printf 'folder\tGBA\t%s\tsmart\t\n' 'nested'
	printf 'tag\tGBA\t\tauto\tmgba\n'
	printf 'not a row\n'
} > "$prefs"
printf '%s\n' "$rom" "/Roms/Game Boy Advance (GBA)/It's a \"game\".gba" \
	"$b/It's a \"game\".gba" "$nest/only.gb" > "$ZLYME_RECENT_FILE"

"$BIN" rom "$rom" --dry-run > "$work/out"
test -f "$rom"
test -f "$prefs"
grep -F "$rom" "$work/out" >/dev/null || fail "dry-run omitted the rom"
grep -F 'game".sav' "$work/out" >/dev/null || fail "dry-run omitted the save"
# The save is Saves/GBA/, including the space in "Game Boy Advance".
# A check that treats the library root as the system tag rejects this file.
grep -F "$work/storage/Saves/GBA/It's a \"game\".sav" "$work/out" >/dev/null || fail "dry-run omitted the system save path"
grep -F 'game".png' "$work/out" >/dev/null || fail "dry-run omitted the art"
if grep -F '/sd2/' "$work/out" >/dev/null; then
	fail "other card was planned"
fi
if grep -F 'game".txt' "$work/out" >/dev/null; then
	fail "dry-run included a non-image"
fi
stamp=$(stat -c %Y "$prefs")
"$BIN" rom "$rom" --dry-run >/dev/null
[ "$(stat -c %Y "$prefs")" = "$stamp" ] || fail "dry-run rewrote preferences"

"$BIN" rom "$rom" > "$work/did"
test ! -e "$rom"
test ! -e "$work/storage/Saves/GBA/It's a \"game\".sav"
test ! -e "$a/.media/It's a \"game\".png"
test -f "$a/.media/It's a \"game\".txt"
test -f "$b/It's a \"game\".gba"
test -f "$work/sd2/Saves/GBA/It's a \"game\".sav"
test -f "$b/.media/It's a \"game\".png"
grep -qx "$b/It's a \"game\".gba" "$ZLYME_RECENT_FILE" || fail "other card recent was removed"
if grep -qx "$rom" "$ZLYME_RECENT_FILE"; then
	fail "deleted game stayed in recents"
fi
if grep -qx "/Roms/Game Boy Advance (GBA)/It's a \"game\".gba" "$ZLYME_RECENT_FILE"; then
	fail "relative recent stayed"
fi
grep -F "SD2/It's a \"game\".gba" "$prefs" >/dev/null || fail "other card preference was removed"
grep -F 'folder	GBA	nested' "$prefs" >/dev/null || fail "folder preference was removed"
grep -F 'tag	GBA		auto' "$prefs" >/dev/null || fail "system preference was removed"
grep -qx 'not a row' "$prefs" || fail "malformed preference was removed"
if grep -F "It's a \"game\".gba	play" "$prefs" >/dev/null; then
	fail "deleted game preference stayed"
fi

"$BIN" rom "$cue" --dry-run > "$work/cue.out"
if grep -F disc.bin "$work/cue.out" >/dev/null; then
	fail "cue delete included the referenced bin"
fi
test -f "$a/disc.bin"

# Same image stem, two ROMs. Art stays while the other ROM exists.
"$BIN" rom "$a/Twin.gba" >/dev/null
test ! -e "$a/Twin.gba"
test -f "$a/Twin.gbc"
test -f "$a/.media/Twin.png"
if grep -F 'Twin.gba	smart' "$prefs" >/dev/null; then
	fail "twin preference stayed"
fi
"$BIN" rom "$a/Twin.gbc" >/dev/null
test ! -e "$a/.media/Twin.png"

# Nested ROM on the primary card, and the same basename is not the match.
"$BIN" rom "$nest/only.gb" >/dev/null
test ! -e "$nest/only.gb"
test ! -e "$nest/.media/only.png"
test -f "$nest/.media/other.png"
if grep -F 'nested/only.gb	idle' "$prefs" >/dev/null; then
	fail "nested preference stayed"
fi
if grep -F "$nest/only.gb" "$ZLYME_RECENT_FILE" >/dev/null; then
	fail "nested recent stayed"
fi

# Second card. Its preference key uses the SD2 badge.
sd2rom="$b/only.gba"
printf 'x' > "$sd2rom"
printf 's' > "$work/sd2/Saves/GBA/only.sav"
printf 'p' > "$b/.media/only.png"
printf 'rom\tGBA\tSD2/only.gba\tplay\tmgba\n' >> "$prefs"
printf '%s\n' "$sd2rom" >> "$ZLYME_RECENT_FILE"
"$BIN" rom "$sd2rom" >/dev/null
test ! -e "$sd2rom"
test ! -e "$work/sd2/Saves/GBA/only.sav"
test ! -e "$b/.media/only.png"
test -f "$b/It's a \"game\".gba"
if grep -F 'SD2/only.gba	play' "$prefs" >/dev/null; then
	fail "sd2 preference stayed"
fi

# Multiple dots: only the full stem's image goes.
dots="$a/My.Game.gba"
printf 'd' > "$dots"
printf 'wide' > "$a/.media/My.Game.png"
printf 'narrow' > "$a/.media/My.png"
"$BIN" rom "$dots" >/dev/null
test ! -e "$a/.media/My.Game.png"
test -f "$a/.media/My.png"

# Refusals leave the card alone.
keep="$a/keep.gba"
printf 'k' > "$keep"
if "$BIN" rom "$work/storage/.config/nextui/shared/zlyme-prefs.txt" >/dev/null 2>"$work/err"; then
	fail "config path was accepted"
fi
test -f "$prefs"
ln -s "$keep" "$a/link.gba"
if "$BIN" rom "$a/link.gba" >/dev/null 2>>"$work/err"; then
	fail "symlink was accepted"
fi
test -f "$keep"
test -L "$a/link.gba"
if "$BIN" rom "$work/storage/Roms/Game Boy Advance (GBA)/../../outside.gba" >/dev/null 2>>"$work/err"; then
	fail "traversal was accepted"
fi
printf 'out' > "$work/outside.gba"
if "$BIN" rom "$work/outside.gba" >/dev/null 2>>"$work/err"; then
	fail "path outside the libraries was accepted"
fi
test -f "$work/outside.gba"
rmdir "$a/empty-dir" 2>/dev/null || true
mkdir -p "$a/empty-dir"
if "$BIN" rom "$a/empty-dir" >/dev/null 2>>"$work/err"; then
	fail "directory was accepted"
fi
if "$BIN" rom-apply "$work/out" >/dev/null 2>>"$work/err"; then
	fail "external plan was accepted"
fi

# Repeated delete of a missing ROM refuses.
if "$BIN" rom "$dots" >/dev/null 2>>"$work/err"; then
	fail "missing rom was deleted again"
fi

splore="$a/Splore.p8"
printf 'splore' > "$splore"
marker="$work/storage/.config/nextui/shared/Pico-8-native/splore-installed"
: > "$marker"
"$BIN" rom "$splore" --dry-run > "$work/splore.out"
grep -F "$marker" "$work/splore.out" >/dev/null || fail "splore marker was not planned"
"$BIN" rom "$splore" >/dev/null
test ! -e "$marker"
test ! -e "$splore"

# A failed rename leaves the previous preference file.
printf 'rom\tGBA\tkeep.gba\tplay\tmgba\nrom\tGBA\tgone.gba\tidle\tmgba\n' > "$prefs"
cat > "$work/mv" <<'EOF'
#!/bin/sh
last=
for arg in "$@"; do
	last=$arg
done
if [ "${ZLYME_MV_FAIL:-0}" = 1 ] && [ "$last" = "${ZLYME_PREFS_FILE:-}" ]; then
	exit 1
fi
exec /usr/bin/mv "$@"
EOF
chmod 755 "$work/mv"
gone="$a/gone.gba"
printf 'g' > "$gone"
before=$(cat "$prefs")
if ZLYME_MV_FAIL=1 PATH="$work:$PATH" "$BIN" rom "$gone" >/dev/null 2>>"$work/err"; then
	fail "preference rename failure was ignored"
fi
[ "$(cat "$prefs")" = "$before" ] || fail "failed rename replaced preferences"
test -f "$gone"

# Same basename in three systems. Only the GBA save folder is touched.
gba="$work/storage/Roms/Game Boy Advance (GBA)"
gb="$work/storage/Roms/Game Boy (GB)"
nes="$work/storage/Roms/Nintendo Entertainment System (NES)"
mkdir -p "$gba" "$gb" "$nes" \
	"$work/storage/Saves/GBA" "$work/storage/Saves/GB" "$work/storage/Saves/NES" \
	"$work/sd2/Roms/Game Boy Advance (GBA)" "$work/sd2/Saves/GBA"
printf 'g' > "$gba/Mario.gba"
printf 'b' > "$gb/Mario.gb"
printf 'n' > "$nes/Mario.nes"
printf 'gba-save' > "$work/storage/Saves/GBA/Mario.srm"
printf 'slot' > "$work/storage/Saves/GBA/Mario.state.1"
printf 'gb-save' > "$work/storage/Saves/GB/Mario.srm"
printf 'nes-save' > "$work/storage/Saves/NES/Mario.srm"
"$BIN" rom "$gba/Mario.gba" >/dev/null
test ! -e "$gba/Mario.gba"
test ! -e "$work/storage/Saves/GBA/Mario.srm"
test ! -e "$work/storage/Saves/GBA/Mario.state.1"
test -f "$work/storage/Saves/GB/Mario.srm"
test -f "$work/storage/Saves/NES/Mario.srm"
test -f "$gb/Mario.gb"
test -f "$nes/Mario.nes"

# Same system, two extensions. The shared save stays.
printf 'g' > "$gba/Mario.gba"
printf 'c' > "$gba/Mario.gbc"
printf 'again' > "$work/storage/Saves/GBA/Mario.srm"
"$BIN" rom "$gba/Mario.gba" >/dev/null
test ! -e "$gba/Mario.gba"
test -f "$gba/Mario.gbc"
test -f "$work/storage/Saves/GBA/Mario.srm"

# Each card has its own ROM and its own save. Only this card's save goes.
rm -f "$gba/Mario.gbc"
printf 'g' > "$gba/Mario.gba"
printf '2' > "$work/sd2/Roms/Game Boy Advance (GBA)/Mario.gba"
printf 'sd1' > "$work/storage/Saves/GBA/Mario.srm"
printf 'sd2' > "$work/sd2/Saves/GBA/Mario.srm"
"$BIN" rom "$gba/Mario.gba" >/dev/null
test ! -e "$work/storage/Saves/GBA/Mario.srm"
test -f "$work/sd2/Saves/GBA/Mario.srm"
test -f "$work/sd2/Roms/Game Boy Advance (GBA)/Mario.gba"

# The other card has the only save and also its own ROM. Do not guess.
printf 'g' > "$gba/Mario.gba"
"$BIN" rom "$gba/Mario.gba" >/dev/null
test -f "$work/sd2/Saves/GBA/Mario.srm"
test -f "$work/sd2/Roms/Game Boy Advance (GBA)/Mario.gba"

echo "rom delete ok"
