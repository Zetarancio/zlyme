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
	BR2_PACKAGE_ZLYME_ARMHF_PROBE=y
do
	grep -qx "$need" "$CFG" || fail "missing $need"
done
for banned in BR2_aarch64=y BR2_cortex_a55=y BR2_LINUX_KERNEL=y BR2_TARGET_UBOOT=y; do
	if grep -qx "$banned" "$CFG"; then
		fail "armhf defconfig selects $banned"
	fi
done
if grep -q 'BR2_PACKAGE_ZLYME_ARMHF_PROBE' "$PROD"; then
	fail "product image selects the armhf probe"
fi
if grep -R -n 'ld-linux-armhf.so.3' "$ROOT/board" "$ROOT/package" --exclude='*.mk' --exclude='probe.c' >/dev/null 2>&1; then
	# The probe package must not ship a fake loader. A mention in a
	# comment is still a fail so the path stays a real glibc file.
	fail "a loader path is named outside the ARMHF toolchain"
fi
if grep -q -- '-static' "$ROOT/package/system/zlyme-armhf-probe/zlyme-armhf-probe.mk"; then
	fail "probe is linked static"
fi
cc -std=c11 -Wall -Wextra -Werror -c \
	-o /tmp/zlyme-armhf-probe.o \
	"$ROOT/package/system/zlyme-armhf-probe/probe.c"
rm -f /tmp/zlyme-armhf-probe.o
echo "armhf defconfig ok"
