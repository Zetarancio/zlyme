#!/bin/sh
# Record the one ARMHF Box86 executable imported by the AArch64 product.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT=${ZLYME_OUTPUT:-${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}}
die() { echo "box86-manifest: $*" >&2; exit 1; }

case "$OUT" in
	"$ROOT"|"$ROOT"/output|"$ROOT"/output/*|"$ROOT"/scripts|"$ROOT"/scripts/*)
		die "refusing output $OUT"
		;;
esac
binary=$OUT/target/usr/bin/box86
[ -f "$binary" ] || die "Box86 binary is missing"
[ -f "$OUT/.zlyme-defconfig" ] || die "defconfig stamp is missing"
[ "$(tr -d '[:space:]' < "$OUT/.zlyme-defconfig")" = \
	zlyme_my355_armhf_defconfig ] || die "wrong defconfig stamp"
[ -f "$OUT/.config" ] || die "Buildroot config is missing"
grep -qx 'BR2_PACKAGE_BOX86_ARMHF=y' "$OUT/.config" ||
	die "Box86 package is not selected"
readelf -h "$binary" | grep -q 'Class:.*ELF32' || die "Box86 is not ELF32"
readelf -h "$binary" | grep -q 'Machine:.*ARM' || die "Box86 is not ARM"
readelf -h "$binary" | grep -q 'hard-float ABI' || die "Box86 is not hard-float"
readelf -A "$binary" | grep -q 'Tag_ABI_VFP_args: VFP registers' ||
	die "Box86 does not use the hard-float calling convention"
interp=$(readelf -l "$binary" | awk '
	/Requesting program interpreter/ { gsub(/[][]/, "", $NF); print $NF }
')
[ "$interp" = /lib/ld-linux-armhf.so.3 ] ||
	die "Box86 interpreter is $interp"
for needed in $(readelf -d "$binary" | awk '
	/NEEDED/ { gsub(/[][]/, "", $NF); print $NF }
'); do
	if [ "$needed" = ld-linux-armhf.so.3 ]; then
		[ -f "$OUT/target/lib/ld-linux-armhf.so.3" ] ||
			die "private runtime is missing the loader"
		continue
	fi
	[ -e "$OUT/target/usr/lib/zlyme-armhf/$needed" ] ||
		die "private runtime is missing $needed"
done

buildroot=$(awk -F\" '/^readonly BUILDROOT_VERSION=/ { print $2; exit }' "$ROOT/build.sh")
version=$(awk '/^BOX86_ARMHF_VERSION = / { print $3; exit }' \
	"$ROOT/package/system/box86-armhf/box86-armhf.mk")
def_hash=$(sha256sum "$ROOT/configs/zlyme_my355_armhf_defconfig" |
	awk '{print $1}')
sum=$(sha256sum "$binary" | awk '{print $1}')
mode=$(stat -c '%a' "$binary")
manifest=$OUT/zlyme-box86.manifest
tmp=$(mktemp "$OUT/.box86-manifest.XXXXXX")
trap 'rm -f "$tmp"' EXIT
{
	printf 'format=1\n'
	printf 'defconfig=zlyme_my355_armhf_defconfig\n'
	printf 'defconfig_sha256=%s\n' "$def_hash"
	printf 'buildroot=%s\n' "$buildroot"
	printf 'box86_version=%s\n' "$version"
	printf 'abi=elf32-arm-eabihf\n'
	printf 'interpreter=/lib/ld-linux-armhf.so.3\n'
	printf 'file %s %s usr/bin/box86\n' "$sum" "$mode"
} > "$tmp"
mv "$tmp" "$manifest"
trap - EXIT
echo "box86 manifest $manifest"
