#!/bin/sh
# Host-side delta staging. Does not reboot and does not touch /boot.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
UPDATE="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

old=$work/old
new=$work/new
printf 'root-v1-bytes\n' >"$old"
printf 'root-v1-bytes\nchanged\n' >"$new"
boot=$work/boot
mkdir -p "$boot"
cp "$old" "$boot/zlyme"
storage=$work/storage
mkdir -p "$storage"
conf=$work/device.conf
cat >"$conf" <<'EOF'
ZLYME_UPDATE_PREFIX=zlyme-my355
ZLYME_DTB=rk3566-miyoo-flip.dtb
ZLYME_DEVICE_ID=my355
EOF

stage=$work/full
mkdir -p "$stage/overlays" "$stage/extlinux"
cp "$new" "$stage/zlyme"
printf 'kernel' >"$stage/Image.gz"
printf 'dtb' >"$stage/rk3566-miyoo-flip.dtb"
printf 'idb' >"$stage/idbloader.img"
printf 'itb' >"$stage/u-boot.itb"
printf 'abc\n20260930\n' >"$stage/VERSION"
printf '#!/bin/sh\n' >"$stage/pre-update.sh"
printf '#!/bin/sh\n' >"$stage/post-update.sh"
printf 'splash' >"$stage/splash.anim"
printf 'dtbo' >"$stage/overlays/x.dtbo"
printf 'menu' >"$stage/extlinux/extlinux.conf"
full=$work/full.tar
tar -C "$stage" -cf "$full" Image.gz rk3566-miyoo-flip.dtb idbloader.img u-boot.itb \
	VERSION pre-update.sh post-update.sh splash.anim overlays extlinux zlyme

base=$(sha256sum "$old" | awk '{print $1}')
target=$(sha256sum "$new" | awk '{print $1}')
size=$(wc -c <"$new")
size=$((size))
patch=$work/zlyme.patch.zst
zstd --patch-from="$old" "$new" -o "$patch" -f
destage=$work/delta-stage
mkdir -p "$destage"
cp "$patch" "$destage/zlyme.patch.zst"
tar -C "$stage" -cf - Image.gz rk3566-miyoo-flip.dtb idbloader.img u-boot.itb \
	VERSION pre-update.sh post-update.sh splash.anim overlays extlinux | tar -C "$destage" -xf -
cat >"$destage/DELTA-MANIFEST" <<EOF
TYPE=delta
SCHEMA=1
DEVICE=my355
FROM_VERSION=zlyme43
TARGET_VERSION=zlyme43.1
BASE_SHA256=$base
TARGET_SHA256=$target
TARGET_SIZE=$size
PATCH=zlyme.patch.zst
EOF
delta=$work/delta.tar
tar -C "$destage" -cf "$delta" DELTA-MANIFEST zlyme.patch.zst Image.gz \
	rk3566-miyoo-flip.dtb idbloader.img u-boot.itb VERSION pre-update.sh \
	post-update.sh splash.anim overlays extlinux

run_stage() {
	ZLYME_UPDATE_TEST=1 \
	ZLYME_DEVICE_CONF="$conf" \
	ZLYME_STORAGE="$storage" \
	ZLYME_BOOT="$boot" \
		"$UPDATE" test-stage "$1"
}

run_stage "$delta"
cmp "$storage/.update/pending/zlyme" "$new"
test ! -e "$storage/.update/reconstruct"
test ! -e "$storage/.update/pending/zlyme.new"
test ! -e "$boot/zlyme.new"
cmp "$boot/zlyme" "$old"

# Wrong base leaves the installed root and does not create pending/zlyme.
printf 'other-root\n' >"$boot/zlyme"
rm -rf "$storage/.update"
if run_stage "$delta"; then
	echo "wrong base was accepted" >&2
	exit 1
fi
test ! -e "$storage/.update/pending/zlyme"
printf 'other-root\n' >"$work/expect-wrong"
cmp "$boot/zlyme" "$work/expect-wrong"

# A reconstructed file whose hash is not TARGET_SHA256 is not pending.
cp "$old" "$boot/zlyme"
rm -rf "$storage/.update"
wrong=$(printf '%064d' 0 | tr 0 f)
cat >"$destage/DELTA-MANIFEST" <<EOF
TYPE=delta
SCHEMA=1
DEVICE=my355
FROM_VERSION=zlyme43
TARGET_VERSION=zlyme43.1
BASE_SHA256=$base
TARGET_SHA256=$wrong
TARGET_SIZE=$size
PATCH=zlyme.patch.zst
EOF
mismatch=$work/mismatch.tar
tar -C "$destage" -cf "$mismatch" DELTA-MANIFEST zlyme.patch.zst Image.gz \
	rk3566-miyoo-flip.dtb idbloader.img u-boot.itb VERSION pre-update.sh \
	post-update.sh splash.anim overlays extlinux
if run_stage "$mismatch"; then
	echo "wrong target hash was accepted" >&2
	exit 1
fi
test ! -e "$storage/.update/pending/zlyme"
test ! -e "$storage/.update/reconstruct/zlyme.new"
cmp "$boot/zlyme" "$old"

# Corrupt patch.
cp "$old" "$boot/zlyme"
rm -rf "$storage/.update"
printf 'not-a-patch' >"$destage/zlyme.patch.zst"
bad=$work/bad.tar
tar -C "$destage" -cf "$bad" DELTA-MANIFEST zlyme.patch.zst Image.gz \
	rk3566-miyoo-flip.dtb idbloader.img u-boot.itb VERSION pre-update.sh \
	post-update.sh splash.anim overlays extlinux
if run_stage "$bad"; then
	echo "corrupt patch was accepted" >&2
	exit 1
fi
test ! -e "$storage/.update/pending/zlyme"
cmp "$boot/zlyme" "$old"

echo "delta stage ok"
