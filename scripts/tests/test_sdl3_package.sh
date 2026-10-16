#!/bin/sh
# SDL3 is the Buildroot package. The SONAME stub is not installed over it.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cfg=$ROOT/configs/zlyme_my355_defconfig
post=$ROOT/board/my355/post-build.sh
fail() { echo "sdl3 package: $*" >&2; exit 1; }

for opt in BR2_PACKAGE_SDL3 BR2_PACKAGE_SDL3_KMSDRM BR2_PACKAGE_SDL3_OPENGLES BR2_PACKAGE_SDL3_WAYLAND BR2_PACKAGE_SDL2; do
	grep -qx "$opt=y" "$cfg" || fail "$opt is not selected"
done
if grep -q '^BR2_PACKAGE_SDL3_X11=y' "$cfg"; then
	fail "SDL3 X11 is selected"
fi
if grep -q '^BR2_PACKAGE_SDL3_OPENGL=y' "$cfg"; then
	fail "SDL3 desktop OpenGL is selected"
fi
grep -q 'SDL_Init' "$post" || fail "post-build does not check SDL_Init"
if grep -q 'sdl3-stub' "$post"; then
	fail "post-build still compiles the stub"
fi
if [ -e "$ROOT/board/my355/sdl3-stub.c" ] || [ -e "$ROOT/board/my355/sdl3-stub.map" ]; then
	fail "stub sources remain"
fi
echo "sdl3 package ok"
