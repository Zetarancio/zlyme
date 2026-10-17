#!/bin/sh
# Recipe edits and manifest edits invalidate zlyme-armhf-runtime separately.
# Neither path starts a toolchain build.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "armhf-refresh: $*" >&2; exit 1; }
PKG=$ROOT/package/system/zlyme-armhf-runtime
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fingerprint() {
	(
		cd "$1"
		find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1
	)
}

printf '%s\n' 'BR2_PACKAGE_ZLYME_ARMHF_RUNTIME=y' > "$work/.config"
mkdir -p "$work"
rec=$work/rec
ZLYME_OUTPUT=$work ZLYME_FINGERPRINT_CHECK=1 ZLYME_FINGERPRINT_RECORD=$rec \
	"$ROOT/build.sh" >/dev/null
grep -qx 'zlyme-armhf-runtime-dirclean' "$rec" || fail "first refresh did not dirclean the runtime: $(cat "$rec")"
if grep -q 'glibc' "$rec"; then
	fail "refresh named glibc: $(cat "$rec")"
fi
live=$(cat "$work/.zlyme-source-zlyme-armhf-runtime")
want=$(
	cd "$ROOT"
	find package/system/zlyme-armhf-runtime -type f -print0 |
		LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1
)
[ "$live" = "$want" ] || fail "fingerprint does not match the package directory"

: > "$rec"
ZLYME_OUTPUT=$work ZLYME_FINGERPRINT_CHECK=1 ZLYME_FINGERPRINT_RECORD=$rec \
	"$ROOT/build.sh" >/dev/null
[ ! -s "$rec" ] || fail "unchanged source refreshed: $(cat "$rec")"

printf '%s\n' 'stale' > "$work/.zlyme-source-zlyme-armhf-runtime"
ZLYME_OUTPUT=$work ZLYME_FINGERPRINT_CHECK=1 ZLYME_FINGERPRINT_RECORD=$rec \
	"$ROOT/build.sh" >/dev/null
grep -qx 'zlyme-armhf-runtime-dirclean' "$rec" || fail "changed fingerprint did not refresh"

copy=$work/pkg
mkdir -p "$copy"
cp -a "$PKG/." "$copy/"
base=$(fingerprint "$copy")
printf '\n' >> "$copy/stage-runtime.sh"
changed=$(fingerprint "$copy")
[ "$base" != "$changed" ] || fail "install script edit left the fingerprint unchanged"
printf 'x\n' > "$work/manifest"
man1=$(sha256sum "$work/manifest" | awk '{print $1}')
after_manifest=$(fingerprint "$copy")
[ "$after_manifest" = "$changed" ] || fail "manifest edit changed the recipe fingerprint"
printf 'y\n' >> "$work/manifest"
man2=$(sha256sum "$work/manifest" | awk '{print $1}')
[ "$man1" != "$man2" ] || fail "manifest edit left the version hash unchanged"

if "$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh" "$work/missing" \
	>"$work/miss.out" 2>&1
then
	fail "missing manifest was accepted"
fi
grep -q 'missing' "$work/miss.out" || fail "missing manifest was not named"

if grep -qi qemu "$ROOT/Dockerfile" \
	"$ROOT/package/system/zlyme-armhf-runtime/"*.mk \
	"$ROOT/package/system/zlyme-armhf-probe/"*.mk
then
	fail "QEMU is a build-image or ARMHF package dependency"
fi
if grep -q 'BR2_PACKAGE_ZLYME_ARMHF_RUNTIME' "$ROOT/configs/zlyme_my355_minimal_defconfig"; then
	fail "minimal image selects the runtime"
fi
if [ -f "$ROOT/output/target/lib/libc.so.6" ]; then
	class=$(od -An -t x1 -j 4 -N 1 "$ROOT/output/target/lib/libc.so.6" | tr -d ' ')
	[ "$class" = "02" ] || fail "product libc is not ELF64"
fi
echo "armhf refresh ok"
