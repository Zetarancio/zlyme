#!/bin/sh
# Check the ARMHF runtime manifest against the sysroot it names.
# A missing, stale, or wrong-architecture tree fails closed.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
out=${1:?ARMHF output directory}
die() { echo "armhf-manifest: $*" >&2; exit 1; }
manifest=$out/zlyme-armhf-runtime.manifest
[ -f "$manifest" ] || die "runtime manifest is missing ($manifest). Build it with scripts/build-armhf-sysroot.sh"
[ -f "$out/.zlyme-defconfig" ] || die "sysroot has no defconfig stamp"
[ -f "$out/.config" ] || die "sysroot has no Buildroot config"

defconfig=
def_hash=
buildroot=
loader_search=
interpreter=
abi=
format=
scratch=$(mktemp -d)
files=$scratch/files
links=$scratch/links
seen=$scratch/seen
: > "$files"
: > "$links"
: > "$seen"
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

while IFS= read -r line; do
	case "$line" in
		'' | '#'*) continue ;;
		format=*) format=${line#format=} ;;
		defconfig=*) defconfig=${line#defconfig=} ;;
		defconfig_sha256=*) def_hash=${line#defconfig_sha256=} ;;
		buildroot=*) buildroot=${line#buildroot=} ;;
		loader_search=*) loader_search=${line#loader_search=} ;;
		interpreter=*) interpreter=${line#interpreter=} ;;
		abi=*) abi=${line#abi=} ;;
		file\ *) printf '%s\n' "$line" >> "$files" ;;
		link\ *) printf '%s\n' "$line" >> "$links" ;;
		*) die "unknown manifest line: $line" ;;
	esac
done < "$manifest"

[ "$format" = "1" ] || die "unsupported manifest format"
[ "$defconfig" = "zlyme_my355_armhf_defconfig" ] || die "manifest defconfig is $defconfig"
stamp=$(tr -d '[:space:]' < "$out/.zlyme-defconfig")
[ "$stamp" = "$defconfig" ] || die "sysroot stamp is $stamp"
want=$(sha256sum "$ROOT/configs/$defconfig" | awk '{print $1}')
[ "$def_hash" = "$want" ] || die "manifest does not match configs/$defconfig"
repo_br=$(awk -F\" '/^readonly BUILDROOT_VERSION=/ { print $2; exit }' "$ROOT/build.sh")
[ "$buildroot" = "$repo_br" ] || die "manifest Buildroot $buildroot is not $repo_br"
[ "$loader_search" = "/usr/lib/zlyme-armhf/" ] || die "loader search is $loader_search"
[ "$interpreter" = "/lib/ld-linux-armhf.so.3" ] || die "interpreter is $interpreter"
[ "$abi" = "elf32-arm-eabihf" ] || die "abi is $abi"
grep -qx 'BR2_arm=y' "$out/.config" || die "sysroot is not BR2_arm"
grep -qx 'BR2_ARM_EABIHF=y' "$out/.config" || die "sysroot is not hard-float"
if grep -qx 'BR2_aarch64=y' "$out/.config"; then
	die "sysroot is AArch64"
fi

while read -r kind sum mode rel; do
	[ "$kind" = "file" ] || die "bad file record"
	case "$rel" in
		lib/ld-linux-armhf.so.3 | usr/lib/zlyme-armhf/*) ;;
		*) die "runtime path is not staged: $rel" ;;
	esac
	case "$rel" in
		*gcc | *g++ | *cc1* | *binutils* | host/*) die "compiler path in manifest: $rel" ;;
	esac
	path=$out/target/$rel
	[ -f "$path" ] || die "missing $rel"
	[ ! -L "$path" ] || die "$rel is a symlink, manifest says file"
	got=$(sha256sum "$path" | awk '{print $1}')
	[ "$got" = "$sum" ] || die "stale $rel"
	now=$(stat -c '%a' "$path")
	[ "$now" = "$mode" ] || die "mode of $rel changed"
	printf '%s\n' "$rel" >> "$seen"
done < "$files"
while read -r kind link rel; do
	[ "$kind" = "link" ] || die "bad link record"
	case "$rel" in
		usr/lib/zlyme-armhf/*) ;;
		*) die "symlink is outside the private directory: $rel" ;;
	esac
	case "$link" in
		/* | *..* | */*) die "manifest symlink escapes: $rel -> $link" ;;
	esac
	path=$out/target/$rel
	[ -L "$path" ] || die "$rel is not a symlink"
	[ "$(readlink "$path")" = "$link" ] || die "symlink target changed: $rel"
	printf '%s\n' "$rel" >> "$seen"
done < "$links"

for need in lib/ld-linux-armhf.so.3 usr/lib/zlyme-armhf/libc.so.6 \
	usr/lib/zlyme-armhf/libm.so.6 usr/lib/zlyme-armhf/libgcc_s.so.1
do
	grep -qx "$need" "$seen" || die "manifest omits $need"
done

have=$(find "$out/target/usr/lib/zlyme-armhf" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
for name in $have; do
	grep -qx "usr/lib/zlyme-armhf/$name" "$seen" || die "unlisted runtime file $name"
done
grep -qx 'lib/ld-linux-armhf.so.3' "$seen" || die "manifest omits the loader"
echo "armhf manifest ok"
