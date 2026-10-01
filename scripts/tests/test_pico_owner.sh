#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pico-splore"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
art=$work/art.png
printf 'png' > "$art"
export ZLYME_PICO_ART="$art"
export ZLYME_PICO_ROMDIR="$work/Pico-8 (PICO)"
export ZLYME_PICO_SHARED="$work/native"
export ZLYME_PICO_RUNTIME="$ROOT/board/my355/fsoverlay/usr/share/zlyme/pico-runtime.sh"
export ZLYME_PICO_LIBRARIES="$work/libs"
mkdir -p "$work/native/cdata" "$work/native/bbs" "$work/native/data" \
	"$work/storage/Bios/PICO"
printf 'bin' > "$work/storage/Bios/PICO/pico8_64"
printf 'dat' > "$work/storage/Bios/PICO/pico8.dat"
printf '%s\n' "$work/storage" > "$work/libs"
printf 'keep' > "$work/native/cdata/user"
"$BIN"
test -f "$work/Pico-8 (PICO)/000) Splore.p8"
test -f "$work/native/splore-installed"
printf 'changed' > "$work/Pico-8 (PICO)/000) Splore.p8"
"$BIN"
grep -q changed "$work/Pico-8 (PICO)/000) Splore.p8"
grep -q keep "$work/native/cdata/user"
if grep -q seed_splore "$ROOT/package/system/nextui/paks/Emus/PICO.pak/launch.sh"; then
	echo "PICO.pak still seeds Splore" >&2
	exit 1
fi
if grep -q zlyme-pico-splore "$ROOT/package/system/nextui/nextui-session"; then
	echo "session still owns Splore" >&2
	exit 1
fi
grep -q 'rescan_nextui' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage"
grep -q 'fake08' "$ROOT/package/system/nextui/paks/Emus/PICO.pak/launch.sh"
grep -q 'native' "$ROOT/package/system/nextui/paks/Emus/P8.pak/launch.sh"
grep -q -- '-root_path' "$ROOT/package/emulators/pico8/start_pico8.sh"
grep -q -- '-splore' "$ROOT/package/emulators/pico8/start_pico8.sh"
if grep -q 'rm .*cdata' "$ROOT/package/emulators/pico8/start_pico8.sh"; then
	echo "pico launcher deletes cdata" >&2
	exit 1
fi
echo "pico owner ok"
