#!/bin/bash
# A changed initramfs asset dircleans zlyme-initramfs and nothing else.
# The linux stamp edge then rebuilds Image. This does not run make.
# shellcheck disable=SC1007,SC2016
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
	echo "initramfs refresh: $*" >&2
	exit 1
}

# shellcheck disable=SC1091
eval "$(sed -n '/^refresh_compiled_package()/,/^}/p' "$ROOT/build.sh")"
type refresh_compiled_package >/dev/null

say() { :; }
calls=$work/calls
: >"$calls"
logged_make() {
	printf '%s\n' "$*" >>"$calls"
}

repo=$work/repo
mkdir -p "$repo/package/boot"
cp -a "$ROOT/package/boot/zlyme-initramfs" "$repo/package/boot/zlyme-initramfs"
mkdir -p "$work/output"
printf '%s\n' 'BR2_PACKAGE_ZLYME_INITRAMFS=y' >"$work/output/.config"
export REPO=$repo
export ZLYME_OUTPUT=$work/output

for asset in splash.rgb565 progress.rgb565 splash.anim progress.anim; do
	[ -f "$repo/package/boot/zlyme-initramfs/$asset" ] || fail "missing $asset"
done

refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 1 ] || fail "first fingerprint did not dirclean"
grep -qx 'zlyme-initramfs-dirclean' "$calls" || fail "dirclean target: $(cat "$calls")"
[ -s "$work/output/.zlyme-source-zlyme-initramfs" ] || fail "fingerprint was not recorded"

refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 1 ] || fail "unchanged assets dircleaned again"

# One flipped byte is a new splash still. The real asset is not touched.
printf 'x' >>"$repo/package/boot/zlyme-initramfs/splash.rgb565"
refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 2 ] || fail "changed splash.rgb565 did not refresh"
grep -qx 'zlyme-initramfs-dirclean' "$calls" || fail "refresh target changed: $(cat "$calls")"

printf 'y' >>"$repo/package/boot/zlyme-initramfs/progress.anim"
refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 3 ] || fail "changed progress.anim did not refresh"

mkdir -p "$repo/package/unrelated"
printf 'nope\n' >"$repo/package/unrelated/note"
refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 3 ] || fail "an unrelated path refreshed initramfs"

printf '%s\n' 'BR2_PACKAGE_ZLYME_INITRAMFS=n' >"$work/output/.config"
printf 'z' >>"$repo/package/boot/zlyme-initramfs/progress.rgb565"
refresh_compiled_package zlyme-initramfs BR2_PACKAGE_ZLYME_INITRAMFS \
	package/boot/zlyme-initramfs
[ "$(wc -l <"$calls")" -eq 3 ] || fail "a disabled package was dircleaned"
grep -q 'linux-dirclean' "$calls" && fail "kernel sources were dircleaned"

grep -Eq '^[[:space:]]*refresh_compiled_package[[:space:]]+zlyme-initramfs[[:space:]]+BR2_PACKAGE_ZLYME_INITRAMFS([[:space:]]|\\|$)' \
	"$ROOT/build.sh" || fail "build.sh does not fingerprint zlyme-initramfs"
grep -q 'package/boot/zlyme-initramfs' "$ROOT/build.sh" || fail "fingerprint path missing"

# dirclean removes the install stamp. This edge makes the next image
# build rebuild the kernel after that stamp returns. Image.gz follows
# .stamp_built via the images install rule. The kernel tree is not cleaned.
grep -F -q '$(LINUX_DIR)/.stamp_built: $(ZLYME_INITRAMFS_DIR)/.stamp_target_installed' \
	"$ROOT/board/my355/board.mk" || fail "linux stamp does not depend on the initramfs install"
grep -F -q 'rm -rf $(INITRAMFS_DIR)' \
	"$ROOT/package/boot/zlyme-initramfs/zlyme-initramfs.mk" || fail "install does not replace the initramfs tree"
awk '
	/\$\(\$\(2\)_TARGET_INSTALL_IMAGES\):/ && /\$\(\$\(2\)_TARGET_BUILD\)/ { found = 1 }
	END { exit found ? 0 : 1 }
' "$ROOT/buildroot/package/pkg-generic.mk" || fail "image install does not follow the build stamp"

cmp -s "$ROOT/package/boot/zlyme-initramfs/splash.rgb565" \
	"$repo/package/boot/zlyme-initramfs/splash.rgb565" \
	&& fail "the fixture did not change its own splash copy"
echo "initramfs refresh ok"
