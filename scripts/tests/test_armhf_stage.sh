#!/bin/sh
# Stage the ARMHF runtime into a fake root and prove it does not replace
# an AArch64 libc. qemu-arm is not required for this check.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
STAGE=$ROOT/package/system/zlyme-armhf-runtime/stage-runtime.sh
SYSROOT=${ZLYME_ARMHF_SYSROOT:-/tmp/zlyme-armhf-out/target}
fail() { echo "armhf-stage-test: $*" >&2; exit 1; }
blocked() { echo "armhf-stage-test blocked: $*" >&2; exit 2; }

[ -f "$SYSROOT/lib/ld-linux-armhf.so.3" ] || blocked "ARMHF sysroot is not at $SYSROOT"
if grep -q 'DEVICE_HAS_ARMHF=Y' "$ROOT/package/system/portmaster/portmaster-launch" \
	"$ROOT/configs/zlyme_my355_defconfig"
then
	fail "DEVICE_HAS_ARMHF is enabled"
fi
if grep -q '^BR2_PACKAGE_ZLYME_ARMHF_RUNTIME=y$' "$ROOT/configs/zlyme_my355_defconfig"; then
	fail "the product defconfig installs the ARMHF runtime"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/lib"
# A stand-in for the product libc: ELF64, AArch64 machine id.
python3 - "$work/root/lib/libc.so.6" << 'PY'
import sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[18] = 0xB7
open(sys.argv[1], "wb").write(header)
PY
before=$(sha256sum "$work/root/lib/libc.so.6")
ZLYME_ARMHF_SYSROOT=$SYSROOT "$STAGE" "$work/root"
after=$(sha256sum "$work/root/lib/libc.so.6")
[ "$before" = "$after" ] || fail "AArch64 libc was replaced"
[ -f "$work/root/lib/ld-linux-armhf.so.3" ] || fail "loader was not installed"
[ -f "$work/root/usr/lib/zlyme-armhf/libc.so.6" ] || fail "private libc missing"
[ ! -e "$work/root/usr/lib/libc.so.6" ] || fail "libc was copied to /usr/lib"

python3 - "$work/root" << 'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])

def ident(path):
    data = path.read_bytes()[:20]
    if data[:4] != b"\x7fELF":
        return "other", ""
    machine = data[18] | (data[19] << 8)
    return data[4], machine

cls, machine = ident(root / "lib/ld-linux-armhf.so.3")
if cls != 1 or machine != 40:
    sys.exit("loader is not ELF32 ARM")
cls, machine = ident(root / "lib/libc.so.6")
if cls != 2:
    sys.exit("stand-in AArch64 libc changed class")
for path in (root / "usr/lib/zlyme-armhf").iterdir():
    if path.is_symlink():
        if path.readlink().is_absolute() or ".." in path.readlink().parts:
            sys.exit("bad symlink " + path.name)
        continue
    data = path.read_bytes()[:4]
    if data == b"\x7fELF":
        cls, machine = ident(path)
        if cls != 1 or machine != 40:
            sys.exit("non-ARMHF ELF " + path.name)
print("staged elfs ok")
PY

# A second stage replaces the private directory and drops a stale file.
printf 'stale\n' > "$work/root/usr/lib/zlyme-armhf/libstale.so.1"
ZLYME_ARMHF_SYSROOT=$SYSROOT "$STAGE" "$work/root"
[ ! -e "$work/root/usr/lib/zlyme-armhf/libstale.so.1" ] || fail "stale ARMHF file survived"
again=$(sha256sum "$work/root/lib/libc.so.6")
[ "$before" = "$again" ] || fail "repeated staging changed AArch64 libc"
find "$work/root" -name '.armhf-stage.*' | grep -q . && fail "staging directory was left behind"

# A 64-bit file is rejected before anything is published.
bad=$work/bad-sys/usr/lib/zlyme-armhf
mkdir -p "$bad" "$work/bad-sys/lib" "$work/bad-dest/usr/lib/zlyme-armhf" "$work/bad-dest/lib"
cp -a "$SYSROOT/lib/ld-linux-armhf.so.3" "$work/bad-sys/lib/"
cp -a "$SYSROOT/usr/lib/zlyme-armhf/." "$bad/"
python3 - "$bad/libevil.so.1" "$work/bad-dest/lib/libc.so.6" << 'PY'
import sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[18] = 0xB7
open(sys.argv[1], "wb").write(header)
open(sys.argv[2], "wb").write(header + b"keep")
PY
printf 'keepme\n' > "$work/bad-dest/usr/lib/zlyme-armhf/libkeep.so.1"
kept=$(sha256sum "$work/bad-dest/lib/libc.so.6")
if out=$(ZLYME_ARMHF_SYSROOT=$work/bad-sys "$STAGE" "$work/bad-dest" 2>&1); then
	fail "an ELF64 file in the private directory was installed"
fi
printf '%s\n' "$out" | grep -q 'ELF64' || fail "ELF64 was not the reported reason: $out"
[ "$(cat "$work/bad-dest/usr/lib/zlyme-armhf/libkeep.so.1")" = "keepme" ] \
	|| fail "rejected runtime still changed the destination"
[ "$(sha256sum "$work/bad-dest/lib/libc.so.6")" = "$kept" ] \
	|| fail "rejected runtime changed AArch64 libc"
find "$work/bad-dest" -name '.armhf-stage.*' | grep -q . && fail "failed stage left a directory"

echo "armhf stage ok"
