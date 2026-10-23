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
