#!/bin/sh
# The ARMHF defconfig is a separate sysroot, not the Flip image.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CFG=$ROOT/configs/zlyme_my355_armhf_defconfig
PROD=$ROOT/configs/zlyme_my355_defconfig
fail() { echo "armhf-defconfig: $*" >&2; exit 1; }

[ -f "$CFG" ] || fail "defconfig missing"
for need in \
	BR2_arm=y \
	BR2_cortex_a53=y \
	BR2_ARM_EABIHF=y \
	BR2_ARM_FPU_NEON_FP_ARMV8=y \
	BR2_TOOLCHAIN_BUILDROOT_GLIBC=y \
	BR2_KERNEL_HEADERS_7_1=y \
	BR2_PACKAGE_ZLYME_ARMHF_PROBE=y \
	BR2_PACKAGE_SDL2=y \
	BR2_PACKAGE_SDL2_KMSDRM=y \
	BR2_PACKAGE_SDL2_OPENGLES=y \
	BR2_PACKAGE_OPENAL=y \
	BR2_PACKAGE_FREETYPE=y \
	BR2_PACKAGE_BZIP2=y \
	BR2_PACKAGE_PULSEAUDIO=y
do
	grep -qx "$need" "$CFG" || fail "missing $need"
done
# An ARMHF ALSA library would load the AArch64 PipeWire ALSA plugin.
# PulseAudio is the client library only. No X server or compositor.
for banned in BR2_aarch64=y BR2_cortex_a55=y BR2_LINUX_KERNEL=y BR2_TARGET_UBOOT=y \
	BR2_PACKAGE_ALSA_LIB=y BR2_PACKAGE_PULSEAUDIO_DAEMON=y \
	BR2_PACKAGE_XSERVER_XORG_SERVER=y BR2_PACKAGE_WESTON=y BR2_PACKAGE_SDL2_X11=y
do
	if grep -qx "$banned" "$CFG"; then
		fail "armhf defconfig selects $banned"
	fi
done
# shellcheck disable=SC2016
want_patch='BR2_GLOBAL_PATCH_DIR="$(BR2_EXTERNAL_ZLYME_PATH)/board/my355/patches"'
grep -qxF "$want_patch" "$CFG" || fail "ARMHF SDL2 does not take the board SDL2 patches only"
for dir in "$ROOT"/board/my355/patches/*; do
	[ "$(basename "$dir")" = sdl2 ] || fail "board patch directory also patches $(basename "$dir") for ARMHF"
done
grep -q -- '-Dgbm-backends-path=/usr/lib/zlyme-armhf/gbm' "$ROOT/external.mk" ||
	fail "ARMHF GBM still searches the AArch64 backend directory"
grep -q -- '-Ddaemon=false' "$ROOT/external.mk" || fail "ARMHF PulseAudio builds a daemon"
if grep -q 'BR2_PACKAGE_ZLYME_ARMHF_PROBE' "$PROD"; then
	fail "product image selects the armhf probe"
fi
MIN=$ROOT/configs/zlyme_my355_minimal_defconfig
if grep -q 'BR2_PACKAGE_ZLYME_ARMHF_RUNTIME' "$MIN"; then
	fail "minimal image selects the armhf runtime"
fi
if find "$ROOT/board" "$ROOT/package" -name 'ld-linux-armhf.so.3' | grep -q .; then
	fail "an ARMHF loader binary is stored in the tree"
fi
hits=$(grep -R -s -l 'ld-linux-armhf.so.3' "$ROOT/board" "$ROOT/package" || true)
for hit in $hits; do
	case "$hit" in
		"$ROOT/package/system/zlyme-armhf-runtime/"* | \
		"$ROOT/package/system/zlyme-armhf-probe/"* | \
		"$ROOT/package/system/zlyme-box86/"* | \
		"$ROOT/package/system/portmaster/control.txt") ;;
		*) fail "loader path is named in $hit" ;;
	esac
done
if grep -q -- '-static' "$ROOT/package/system/zlyme-armhf-probe/zlyme-armhf-probe.mk"; then
	fail "probe is linked static"
fi
cc -std=c11 -Wall -Wextra -Werror -c \
	-o /tmp/zlyme-armhf-probe.o \
	"$ROOT/package/system/zlyme-armhf-probe/probe.c"
rm -f /tmp/zlyme-armhf-probe.o
echo "armhf defconfig ok"
