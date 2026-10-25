#!/bin/sh
# Native ARMHF PortMaster libraries: GameMaker's gmloader needs SDL2,
# OpenAL, and FreeType, and its bundled libzip needs libbz2. They are
# private ELF32 hard-float objects with no search path, and the product
# AArch64 libraries of the same name stay where they are.
# Usage: test_armhf_portmaster_libs.sh [armhf-output] [product-target]
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
OUT=${1:-$ROOT/output-armhf}
PRODUCT=${2:-$ROOT/output/target}
RE=$OUT/host/bin/arm-buildroot-linux-gnueabihf-readelf
fail() { echo "armhf-portmaster-libs: $*" >&2; exit 1; }
blocked() { echo "armhf-portmaster-libs blocked: $*" >&2; exit 2; }
[ -x "$RE" ] || blocked "ARMHF readelf is not at $RE"
[ -f "$OUT/zlyme-armhf-runtime.manifest" ] || blocked "runtime manifest is missing"

sonames="libSDL2-2.0.so.0 libopenal.so.1 libfreetype.so.6 libbz2.so.1.0 \
libpulse.so.0 libpulse-simple.so.0"

armhf_elf() {
	file=$1
	"$RE" -h "$file" | grep -q 'ELF32' || fail "$file is not ELF32"
	"$RE" -h "$file" | grep -q 'Machine:.*ARM$' || fail "$file is not ARM"
	"$RE" -h "$file" | grep -q 'hard-float ABI' || fail "$file is not hard-float"
}

check_private() {
	dir=$(CDPATH= cd -P -- "$1" && pwd)
	for soname in $sonames; do
		[ -e "$dir/$soname" ] || fail "$soname is missing from $dir"
		real=$(readlink -f "$dir/$soname")
		case "$real" in
			"$dir"/*) ;;
			*) fail "$soname leaves $dir: $real" ;;
		esac
		armhf_elf "$real"
		got=$("$RE" -d "$real" | awk '/SONAME/ { gsub(/[][]/, "", $NF); print $NF; exit }')
		[ "$got" = "$soname" ] || fail "$real has SONAME $got"
	done
	find "$dir" -type f -name '*.so*' | while IFS= read -r file; do
		search=$("$RE" -d "$file" 2>/dev/null | awk '/\(RPATH\)|\(RUNPATH\)/ {
			sub(/.*\[/, ""); sub(/\].*/, ""); printf "%s", $0
		}')
		[ -z "$search" ] || fail "$file searches $search"
	done
	[ ! -e "$dir/pulseaudio" ] || fail "$dir has a PulseAudio module directory"
	[ ! -e "$dir/pulse-17.0" ] || fail "$dir has PulseAudio daemon modules"
	gbm=$(readlink -f "$dir/libgbm.so.1")
	strings "$gbm" | grep -qx '/usr/lib/zlyme-armhf/gbm' ||
		fail "libgbm does not search the private backend directory"
	if strings "$gbm" | grep -qx '/usr/lib/gbm'; then
		fail "libgbm still searches /usr/lib/gbm"
	fi
	[ -f "$dir/gbm/dri_gbm.so" ] || fail "private GBM backend is missing"
	sdl=$(readlink -f "$dir/libSDL2-2.0.so.0")
	strings "$sdl" | grep -qx 'libpulse.so.0' || fail "ARMHF SDL2 has no PulseAudio backend"
	strings "$sdl" | grep -q 'KMSDRM' || fail "ARMHF SDL2 has no KMSDRM driver"
	if strings "$sdl" | grep -qx 'libasound.so.2'; then
		fail "ARMHF SDL2 loads ALSA"
	fi
	openal=$(readlink -f "$dir/libopenal.so.1")
	strings "$openal" | grep -qx 'libpulse.so.0' || fail "ARMHF OpenAL has no PulseAudio backend"
}

check_private "$OUT/target/usr/lib/zlyme-armhf"

if [ -d "$PRODUCT/usr/lib/zlyme-armhf" ]; then
	check_private "$PRODUCT/usr/lib/zlyme-armhf"
	for name in $sonames libEGL.so.1 libGLESv2.so.2 libgbm.so.1; do
		for dir in "$PRODUCT/lib" "$PRODUCT/usr/lib"; do
			[ -e "$dir/$name" ] || continue
			class=$(od -An -t x1 -j 4 -N 1 "$(readlink -f "$dir/$name")" | tr -d ' ')
			[ "$class" = "02" ] || fail "$dir/$name is not the AArch64 library"
		done
	done
	[ -e "$PRODUCT/usr/lib/libSDL2-2.0.so.0" ] || fail "system SDL2 is missing"
fi
echo "armhf portmaster libs ok"
