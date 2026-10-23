#!/bin/sh
# Verify the ARMHF Box86 artifact without widening the core runtime manifest.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
out=${1:?ARMHF output directory}
manifest=$out/zlyme-box86.manifest
binary=$out/target/usr/bin/box86
die() { echo "box86-manifest: $*" >&2; exit 1; }

[ -f "$manifest" ] || die "manifest is missing ($manifest)"
[ -f "$binary" ] || die "binary is missing ($binary)"
[ -f "$out/.config" ] || die "sysroot has no Buildroot config"
[ -f "$out/.zlyme-defconfig" ] || die "sysroot has no defconfig stamp"

format=
defconfig=
def_hash=
buildroot=
version=
abi=
interpreter=
file_sum=
file_mode=
file_path=
while IFS= read -r line; do
	case "$line" in
		format=*) format=${line#format=} ;;
		defconfig=*) defconfig=${line#defconfig=} ;;
		defconfig_sha256=*) def_hash=${line#defconfig_sha256=} ;;
		buildroot=*) buildroot=${line#buildroot=} ;;
		box86_version=*) version=${line#box86_version=} ;;
		abi=*) abi=${line#abi=} ;;
		interpreter=*) interpreter=${line#interpreter=} ;;
		file\ *)
			# shellcheck disable=SC2086
			set -- $line
			[ "$#" -eq 4 ] || die "bad file record"
			file_sum=$2
			file_mode=$3
			file_path=$4
			;;
		''|'#'*) ;;
		*) die "unknown manifest line: $line" ;;
	esac
done < "$manifest"

[ "$format" = 1 ] || die "unsupported manifest format"
[ "$defconfig" = zlyme_my355_armhf_defconfig ] || die "wrong defconfig"
[ "$(tr -d '[:space:]' < "$out/.zlyme-defconfig")" = "$defconfig" ] ||
	die "defconfig stamp changed"
[ "$def_hash" = "$(sha256sum "$ROOT/configs/$defconfig" | awk '{print $1}')" ] ||
	die "defconfig hash changed"
repo_br=$(awk -F\" '/^readonly BUILDROOT_VERSION=/ { print $2; exit }' "$ROOT/build.sh")
[ "$buildroot" = "$repo_br" ] || die "Buildroot version changed"
recipe_version=$(awk '/^BOX86_ARMHF_VERSION = / { print $3; exit }' \
	"$ROOT/package/system/box86-armhf/box86-armhf.mk")
[ "$version" = "$recipe_version" ] || die "Box86 version changed"
[ "$abi" = elf32-arm-eabihf ] || die "ABI is $abi"
[ "$interpreter" = /lib/ld-linux-armhf.so.3 ] || die "interpreter is $interpreter"
[ "$file_path" = usr/bin/box86 ] || die "unexpected artifact path $file_path"
[ "$file_sum" = "$(sha256sum "$binary" | awk '{print $1}')" ] ||
	die "binary hash changed"
[ "$file_mode" = "$(stat -c '%a' "$binary")" ] || die "binary mode changed"
grep -qx 'BR2_arm=y' "$out/.config" || die "sysroot is not ARM"
grep -qx 'BR2_ARM_EABIHF=y' "$out/.config" || die "sysroot is not hard-float"
grep -qx 'BR2_PACKAGE_BOX86_ARMHF=y' "$out/.config" || die "Box86 was not selected"
readelf -h "$binary" | grep -q 'Class:.*ELF32' || die "binary is not ELF32"
readelf -h "$binary" | grep -q 'Machine:.*ARM' || die "binary is not ARM"
readelf -h "$binary" | grep -q 'hard-float ABI' || die "binary is not hard-float"
readelf -A "$binary" | grep -q 'Tag_ABI_VFP_args: VFP registers' ||
	die "binary does not use the hard-float calling convention"
got=$(readelf -l "$binary" | awk '
	/Requesting program interpreter/ { gsub(/[][]/, "", $NF); print $NF }
')
[ "$got" = "$interpreter" ] || die "binary interpreter is $got"
for needed in $(readelf -d "$binary" | awk '
	/NEEDED/ { gsub(/[][]/, "", $NF); print $NF }
'); do
	if [ "$needed" = ld-linux-armhf.so.3 ]; then
		[ -f "$out/target/lib/ld-linux-armhf.so.3" ] ||
			die "private runtime is missing the loader"
		continue
	fi
	[ -e "$out/target/usr/lib/zlyme-armhf/$needed" ] ||
		die "private runtime is missing $needed"
done

echo "box86 manifest ok"
