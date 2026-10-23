#!/bin/sh
# Copy the verified private runtime and Box86 artifact into a directory
# CI can carry. The toolchain and the build tree stay behind.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
src=${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}
dest=${1:?destination directory}
die() { echo "armhf-export: $*" >&2; exit 1; }

[ -f "$src/zlyme-armhf-runtime.manifest" ] || die "manifest missing in $src"
[ -f "$src/zlyme-box86.manifest" ] || die "Box86 manifest missing in $src"
[ -f "$src/.config" ] || die "Buildroot config missing"
[ -f "$src/.zlyme-defconfig" ] || die "defconfig stamp missing"
[ -f "$src/target/lib/ld-linux-armhf.so.3" ] || die "loader missing"
[ -d "$src/target/usr/lib/zlyme-armhf" ] || die "private library directory missing"
[ -x "$src/target/usr/bin/box86" ] || die "Box86 binary missing"

rm -rf "$dest"
mkdir -p "$dest/target/lib" "$dest/target/usr/lib" "$dest/target/usr/bin"
cp -a "$src/zlyme-armhf-runtime.manifest" "$src/zlyme-box86.manifest" \
	"$src/.config" "$src/.zlyme-defconfig" "$dest/"
cp -a "$src/target/lib/ld-linux-armhf.so.3" "$dest/target/lib/"
cp -a "$src/target/usr/lib/zlyme-armhf" "$dest/target/usr/lib/"
cp -a "$src/target/usr/bin/box86" "$dest/target/usr/bin/"
"$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh" "$dest"
"$ROOT/package/system/zlyme-box86/check-manifest.sh" "$dest"
echo "armhf export ok"
