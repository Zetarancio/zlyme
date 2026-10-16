#!/bin/sh
# The ARMHF loader's compiled search path is /usr/lib/zlyme-armhf/.
# That is not an LD_LIBRARY_PATH override. The interpreter stays
# /lib/ld-linux-armhf.so.3 so an unmodified binary can find the loader.
# libc.so.6 must not sit in /lib or /usr/lib beside the AArch64 glibc.
# shellcheck disable=SC1007
set -eu
fail() { echo "armhf-loader: $*" >&2; exit 1; }
loader=${1:-/tmp/zlyme-armhf-out/target/lib/ld-linux-armhf.so.3}
[ -f "$loader" ] || fail "ARMHF loader is not available at $loader"
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
	fail "private libgcc is missing"
fi
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
if find "$ROOT/board" "$ROOT/package" -name 'ld-linux-armhf.so.3' | grep -q .; then
	fail "an ARMHF loader is stored in the product tree"
fi
if [ -e "$ROOT/output/target/lib/ld-linux-armhf.so.3" ]; then
	fail "the product image contains the ARMHF loader"
fi
echo "armhf loader path ok"
