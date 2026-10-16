#!/bin/sh
# The ARMHF loader's compiled search path is /usr/lib/zlyme-armhf/.
# The product libc stays AArch64. The loader may be installed beside it.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "armhf-loader: $*" >&2; exit 1; }
blocked() { echo "armhf-loader blocked: $*" >&2; exit 2; }
old=$(printf '%s%s' /tmp/zlyme-armhf- out)
if grep -q "$old" "$ROOT/scripts/tests/"*.sh "$ROOT/scripts/build-armhf-sysroot.sh"; then
	fail "a test still names the old temporary sysroot"
fi
loader=${1:-$ROOT/output-armhf/target/lib/ld-linux-armhf.so.3}
[ -f "$loader" ] || blocked "ARMHF loader is not available at $loader"
if ! strings "$loader" | grep -qx '/usr/lib/zlyme-armhf/'; then
	fail "loader does not search /usr/lib/zlyme-armhf"
fi
if strings "$loader" | grep -qx '/lib/'; then
	fail "loader still searches /lib"
fi
if strings "$loader" | grep -qx '/usr/lib/'; then
	fail "loader still searches /usr/lib"
fi
target=$(CDPATH= cd -- "$(dirname "$loader")/.." && pwd)
if [ -e "$target/lib/libc.so.6" ] || [ -e "$target/usr/lib/libc.so.6" ]; then
	fail "ARMHF libc is on the default library path"
fi
if [ ! -f "$target/usr/lib/zlyme-armhf/libc.so.6" ]; then
	fail "private libc is missing"
fi
if [ ! -f "$target/usr/lib/zlyme-armhf/libgcc_s.so.1" ]; then
	blocked "private libgcc is not in the sysroot yet"
fi
out=$(CDPATH= cd -- "$target/.." && pwd)
[ "$(tr -d '[:space:]' < "$out/.zlyme-defconfig")" = "zlyme_my355_armhf_defconfig" ] \
	|| fail "sysroot stamp is not the ARMHF defconfig"
grep -qx 'BR2_arm=y' "$out/.config" || fail "sysroot is not BR2_arm"
grep -qx 'BR2_ARM_EABIHF=y' "$out/.config" || fail "sysroot is not hard-float"
if grep -qx 'BR2_aarch64=y' "$out/.config"; then
	fail "sysroot is AArch64"
fi
staging=$out/host/arm-buildroot-linux-gnueabihf/sysroot/usr/lib
if [ -d "$staging" ]; then
	[ -L "$staging/crti.o" ] || fail "toolchain crti.o is not linked into usr/lib"
	[ "$(readlink "$staging/crti.o")" = "zlyme-armhf/crti.o" ] || fail "crti.o link target"
	[ ! -e "$staging/libc.so.6" ] || fail "versioned libc is on the toolchain's /usr/lib"
fi
product=$ROOT/output/target
if [ -f "$product/lib/libc.so.6" ]; then
	class=$(od -An -t x1 -j 4 -N 1 "$product/lib/libc.so.6" | tr -d ' ')
	[ "$class" != "01" ] || fail "product libc is ELF32"
fi
if [ -e "$product/usr/lib/libc.so.6" ]; then
	fail "product /usr/lib/libc.so.6 exists"
fi
if [ -e "$product/lib/ld-linux-aarch64.so.1" ] && [ -e "$product/lib/ld-linux-armhf.so.3" ]; then
	arm_class=$(od -An -t x1 -j 4 -N 1 "$product/lib/ld-linux-armhf.so.3" | tr -d ' ')
	[ "$arm_class" = "01" ] || fail "installed ARMHF loader is not ELF32"
	[ -f "$product/usr/lib/zlyme-armhf/libc.so.6" ] || fail "installed private libc is missing"
fi
if find "$ROOT/board" "$ROOT/package" -name 'ld-linux-armhf.so.3' | grep -q .; then
	fail "an ARMHF loader is stored in the source tree"
fi
echo "armhf loader path ok"
