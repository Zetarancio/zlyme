#!/bin/sh
# The built ARMHF loader searches /lib and /usr/lib. Those directories
# on the product image belong to the AArch64 glibc. Do not install
# libc.so.6 from the ARMHF sysroot there.
# shellcheck disable=SC1007
set -eu
fail() { echo "armhf-loader: $*" >&2; exit 1; }
loader=${1:-/tmp/zlyme-armhf-out/target/lib/ld-linux-armhf.so.3}
[ -f "$loader" ] || fail "ARMHF loader is not available at $loader"
if ! strings "$loader" | grep -qx '/lib/'; then
	fail "loader no longer searches /lib; re-check the install plan"
fi
if ! strings "$loader" | grep -qx '/usr/lib/'; then
	fail "loader no longer searches /usr/lib; re-check the install plan"
fi
# The product tree must not already contain this loader.
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
if find "$ROOT/board" "$ROOT/package" -name 'ld-linux-armhf.so.3' | grep -q .; then
	fail "an ARMHF loader is stored in the product tree"
fi
echo "armhf loader path ok"
