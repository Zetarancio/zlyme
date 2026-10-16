#!/bin/sh
# Record the ARMHF runtime that stage-runtime.sh is allowed to copy.
# The compiler and the rest of the sysroot are not part of this list.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT=${ZLYME_OUTPUT:-${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}}
die() { echo "armhf-manifest: $*" >&2; exit 1; }

case "$OUT" in
	"$ROOT" | "$ROOT"/output | "$ROOT"/output/* | "$ROOT"/scripts | "$ROOT"/scripts/*)
		die "refusing to write a manifest for $OUT"
		;;
esac
target=$OUT/target
loader=$target/lib/ld-linux-armhf.so.3
libdir=$target/usr/lib/zlyme-armhf
[ -f "$OUT/.zlyme-defconfig" ] || die "missing $OUT/.zlyme-defconfig"
stamp=$(tr -d '[:space:]' < "$OUT/.zlyme-defconfig")
[ "$stamp" = "zlyme_my355_armhf_defconfig" ] || die "defconfig stamp is $stamp"
[ -f "$loader" ] || die "loader missing"
[ -d "$libdir" ] || die "private library directory missing"
for need in libc.so.6 libm.so.6 libgcc_s.so.1; do
	[ -f "$libdir/$need" ] || die "$need is missing"
done
buildroot=$(awk -F\" '/^readonly BUILDROOT_VERSION=/ { print $2; exit }' "$ROOT/build.sh")
[ -n "$buildroot" ] || die "Buildroot version is not in build.sh"
def_hash=$(sha256sum "$ROOT/configs/zlyme_my355_armhf_defconfig" | awk '{print $1}')
manifest=$OUT/zlyme-armhf-runtime.manifest
tmp=$(mktemp "$OUT/.armhf-manifest.XXXXXX")
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

{
	printf 'format=1\n'
	printf 'defconfig=zlyme_my355_armhf_defconfig\n'
	printf 'defconfig_sha256=%s\n' "$def_hash"
	printf 'buildroot=%s\n' "$buildroot"
	printf 'loader_search=/usr/lib/zlyme-armhf/\n'
	printf 'interpreter=/lib/ld-linux-armhf.so.3\n'
	printf 'abi=elf32-arm-eabihf\n'
} > "$tmp"

record() {
	path=$1
	rel=$2
	case "$rel" in
		*gcc | *g++ | *cc1* | *binutils* | host/* | */host/*)
			die "refusing compiler path $rel"
			;;
	esac
	if [ -L "$path" ]; then
		link=$(readlink "$path")
		case "$link" in
			/* | *..* | */*) die "symlink escapes: $rel -> $link" ;;
		esac
		printf 'link %s %s\n' "$link" "$rel" >> "$tmp"
		return
	fi
	sum=$(sha256sum "$path" | awk '{print $1}')
	mode=$(stat -c '%a' "$path")
	printf 'file %s %s %s\n' "$sum" "$mode" "$rel" >> "$tmp"
}

record "$loader" "lib/ld-linux-armhf.so.3"
# shellcheck disable=SC2012
names=$(ls -A "$libdir" | sort)
for name in $names; do
	record "$libdir/$name" "usr/lib/zlyme-armhf/$name"
done

mv "$tmp" "$manifest"
trap - EXIT
echo "armhf manifest $manifest"
