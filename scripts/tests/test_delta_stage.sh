#!/bin/sh
# Host-side delta staging. Does not reboot and does not touch /boot.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
UPDATE="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update"
grep -q 'zstd -d --memory=2048MB --mmap-dict --patch-from=' "$UPDATE"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -x "$ROOT/output/host/bin/mksquashfs" ]; then
	MKSQ=$ROOT/output/host/bin/mksquashfs
elif command -v mksquashfs >/dev/null 2>&1; then
	MKSQ=$(command -v mksquashfs)
else
	echo "mksquashfs is required" >&2
	exit 1
fi
write_squashfs() {
	dest=$1
	tag=$2
	src=$work/tree-$tag
	rm -rf "$src"
	mkdir -p "$src/dir"
	printf '%s\n' "$tag" >"$src/dir/file"
	rm -f "$dest"
	"$MKSQ" "$src" "$dest" -comp zstd -all-root -noappend >/dev/null
}
old=$work/old
new=$work/new
write_squashfs "$old" old
write_squashfs "$new" new
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

# Manifest hash and size can match a file that is not a SquashFS.
cp "$old" "$boot/zlyme"
rm -rf "$storage/.update"
plain=$work/plain
: >"$plain"
n=0
while [ "$n" -lt 16 ]; do
	printf 'not-a-squashfs\n' >>"$plain"
	n=$((n + 1))
done
pbase=$(sha256sum "$old" | awk '{print $1}')
ptarget=$(sha256sum "$plain" | awk '{print $1}')
psize=$(wc -c <"$plain")
psize=$((psize))
ppatch=$work/plain.patch.zst
zstd --patch-from="$old" "$plain" -o "$ppatch" -f
pdir=$work/plain-delta
mkdir -p "$pdir"
cp "$ppatch" "$pdir/zlyme.patch.zst"
tar -C "$stage" -cf - Image.gz rk3566-miyoo-flip.dtb idbloader.img u-boot.itb \
	VERSION pre-update.sh post-update.sh splash.anim overlays extlinux | tar -C "$pdir" -xf -
cat >"$pdir/DELTA-MANIFEST" <<EOF
TYPE=delta
SCHEMA=1
DEVICE=my355
FROM_VERSION=zlyme43
TARGET_VERSION=zlyme43.1
BASE_SHA256=$pbase
TARGET_SHA256=$ptarget
TARGET_SIZE=$psize
PATCH=zlyme.patch.zst
EOF
pdelta=$work/plain-delta.tar
tar -C "$pdir" -cf "$pdelta" DELTA-MANIFEST zlyme.patch.zst Image.gz \
	rk3566-miyoo-flip.dtb idbloader.img u-boot.itb VERSION pre-update.sh \
	post-update.sh splash.anim overlays extlinux
set +e
pout=$(run_stage "$pdelta" 2>&1)
prc=$?
set -e
if [ "$prc" = 0 ]; then
	echo "non-squashfs reconstruction was accepted" >&2
	exit 1
fi
printf '%s\n' "$pout" | grep -q 'not a squashfs' || {
	echo "non-squashfs reconstruction reason: $pout" >&2
	exit 1
}
test ! -e "$storage/.update/pending/zlyme"
test ! -e "$storage/.update/reconstruct"
cmp "$boot/zlyme" "$old"

echo "delta stage ok"
