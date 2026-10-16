#!/bin/sh
# Per-ROM preference cleanup. Does not touch /storage.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CLEAN=$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh

fail() {
	echo "orphan prefs: $*" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd1=$work/sd1
sd2=$work/sd2
usb=$work/media/USB
mkdir -p "$sd1/Roms/Game Boy (GB)/nested" "$sd1/Roms/NES (NES)" \
	"$sd2/Roms/Game Boy (GB)" "$usb/Roms/Game Boy (GB)"
printf x > "$sd1/Roms/Game Boy (GB)/nested/keep.gb"
printf x > "$sd1/Roms/NES (NES)/same.nes"
printf x > "$sd2/Roms/Game Boy (GB)/only.gb"
printf x > "$usb/Roms/Game Boy (GB)/stick.gb"
printf '%s\n' "$sd1" > "$work/libs"
prefs=$work/prefs
cat > "$prefs" << EOF
# keep
rom	GB	nested/keep.gb	performance	gambatte
rom	GB	nested/gone.gb	performance	gambatte
rom	GB	SD2/only.gb	quiet	
rom	GB	USB/stick.gb	performance	gambatte
folder	GB	nested	performance	
tag	GB		auto	
rom	NES	same.nes	performance	fceumm
rom	GB	nested/gone.gb	performance	gambatte
this is malformed
rom	GB		performance	
EOF

run() {
	ZLYME_CLEANUP_ROOT=$sd1 \
	ZLYME_SD2_ROOT=$sd2 \
	ZLYME_MEDIA_ROOT=$work/media \
	ZLYME_LIBRARIES_FILE=$work/libs \
	ZLYME_PREFS_FILE=$prefs \
	sh "$CLEAN" "$@"
}

out=$(run orphan-prefs --dry-run)
printf '%s\n' "$out" | head -n 1 | grep -qx 'COUNT=2' || fail "dry-run count: $out"
grep -q 'nested/gone.gb' "$prefs" || fail "dry-run rewrote the file"
before=$(wc -c < "$prefs")
run orphan-prefs >/dev/null
after=$(grep -c 'nested/gone.gb' "$prefs" || true)
[ "$after" = 0 ] || fail "orphan rom rows remained"
grep -q 'nested/keep.gb' "$prefs" || fail "existing rom was removed"
grep -q 'SD2/only.gb' "$prefs" || fail "absent SD2 row was removed"
grep -q 'USB/stick.gb' "$prefs" || fail "unmounted volume row was removed"
grep -q '^folder	GB	nested' "$prefs" || fail "folder row was removed"
grep -q '^tag	GB		auto' "$prefs" || fail "system row was removed"
grep -q 'same.nes' "$prefs" || fail "other system was removed"
grep -q 'this is malformed' "$prefs" || fail "malformed row was removed"
grep -q '^rom	GB		performance' "$prefs" || fail "blank rom path was removed"
[ "$(wc -c < "$prefs")" -lt "$before" ] || fail "file did not shrink"

# Second card present and the ROM is there: still kept.
printf '%s\n' "$sd1" "$sd2" > "$work/libs"
# Put the row back and a missing one.
printf '%s\n' 'rom	GB	SD2/only.gb	quiet	' >> "$prefs"
printf '%s\n' 'rom	GB	SD2/missing.gb	quiet	' >> "$prefs"
run orphan-prefs >/dev/null
grep -q 'SD2/only.gb' "$prefs" || fail "present SD2 rom was removed"
grep -q 'SD2/missing.gb' "$prefs" && fail "missing SD2 rom was kept"

# Mounted USB without the file, and the name is not a primary folder.
printf '%s\n' "$sd1" "$usb" > "$work/libs"
printf '%s\n' 'rom	GB	USB/stick.gb	performance	gambatte' >> "$prefs"
printf '%s\n' 'rom	GB	USB/gone.gb	performance	gambatte' >> "$prefs"
run orphan-prefs >/dev/null
grep -q 'USB/stick.gb' "$prefs" || fail "present USB rom was removed"
grep -q 'USB/gone.gb' "$prefs" && fail "missing USB rom was kept"

# Repeated dry-run does not change a clean file.
stamp=$(stat -c %Y "$prefs")
run orphan-prefs --dry-run >/dev/null
[ "$(stat -c %Y "$prefs")" = "$stamp" ] || fail "dry-run touched a clean file"

echo "orphan prefs ok"
