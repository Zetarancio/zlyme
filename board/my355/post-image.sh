#!/usr/bin/env bash
# Copy boot files, make the exFAT seed (grown on first boot), run genimage.

set -euo pipefail

BINARIES_DIR="${1:?post-image.sh: expected BINARIES_DIR as the first argument}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${BOARD_DIR}/fsoverlay/usr/share/zlyme/device.conf"
: "${ZLYME_DTB:?}"
: "${ZLYME_STORAGE_LABEL:?}"
grep -q "FDT /${ZLYME_DTB}" "${BOARD_DIR}/extlinux.conf" || {
	echo "post-image: extlinux.conf FDT does not match device.conf ${ZLYME_DTB}" >&2
	exit 1
}

# A product image without its OTA is an incomplete build. ZLYME_SKIP_OTA=1
# is the only skip, and no supported defconfig sets it. ZLYME_OTA_PACKER
# and ZLYME_POST_IMAGE_TEST=pack let a host test fail this step before
# mkfs or genimage. pack-final checks that a failed pack deletes the
# zlyme.img from this invocation.
pack_product_ota() {
	if [ "${ZLYME_SKIP_OTA:-}" = 1 ]; then
		echo "post-image: OTA packaging skipped (ZLYME_SKIP_OTA=1)" >&2
		return 0
	fi
	local packer="${ZLYME_OTA_PACKER:-${BOARD_DIR}/make-update-tar.sh}"
	if [ ! -x "${packer}" ]; then
		echo "post-image: OTA packer is not executable: ${packer}" >&2
		return 1
	fi
	"${packer}" "${BINARIES_DIR}"
}

finish_ota() {
	if pack_product_ota; then
		return 0
	fi
	rm -f "${BINARIES_DIR}/zlyme.img"
	return 1
}

if [ "${ZLYME_POST_IMAGE_TEST:-}" = pack ]; then
	pack_product_ota
	exit 0
fi

if [ "${ZLYME_POST_IMAGE_TEST:-}" = pack-final ]; then
	: > "${BINARIES_DIR}/zlyme.img"
	finish_ota
	exit 0
fi

install -D -m 0644 "${BOARD_DIR}/extlinux.conf" \
	"${BINARIES_DIR}/extlinux/extlinux.conf"
install -D -m 0644 "${BOARD_DIR}/zlyme-boot.conf" \
	"${BINARIES_DIR}/zlyme-boot.conf"

# Empty exFAT so blkid sees LABEL=ZLYME. First boot S13resize grows it
# to the card and mkfs.exfat (wipes this seed). ROCKNIX STORAGE_SIZE=32;
# Knulli's 256/512M seeds are packed userdata, which we do not ship.
STORAGE_MB=32
rm -f "${BINARIES_DIR}/storage.exfat"
truncate -s "${STORAGE_MB}M" "${BINARIES_DIR}/storage.exfat"
mkfs.exfat -L "${ZLYME_STORAGE_LABEL}" "${BINARIES_DIR}/storage.exfat" >/dev/null

[ -s "${BINARIES_DIR}/${ZLYME_DTB}" ] ||
	{ echo "post-image: ${ZLYME_DTB} is missing" >&2
	  exit 1; }

# U-Boot gunzips Image.gz off FAT. The uncompressed Image stays in
# BINARIES_DIR as the gzip input; it is not shipped on ZLYMEBOOT.
[ -s "${BINARIES_DIR}/Image" ] ||
	{ echo "post-image: Image is missing" >&2
	  exit 1; }
gzip -9 -n -c "${BINARIES_DIR}/Image" > "${BINARIES_DIR}/Image.gz"
[ -s "${BINARIES_DIR}/Image.gz" ] ||
	{ echo "post-image: gzip Image failed" >&2
	  exit 1; }

[ -s "${BINARIES_DIR}/rootfs.squashfs" ] ||
	{ echo "post-image: rootfs.squashfs is missing" >&2
	  exit 1; }

if [ -f "${TARGET_DIR}/usr/sbin/nextui-session" ]; then
	"${BOARD_DIR}/assert-input-rootfs.sh" "${BINARIES_DIR}/rootfs.squashfs"
fi

# Squashfs lives on FAT as "zlyme" (ROCKNIX SYSTEM / Knulli knulli).
ln -f "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/zlyme"

# CPU undervolt overlays. u-boot already has OF_LIBFDT_OVERLAY; Settings
# writes FDTOVERLAYS into extlinux.conf (same as ROCKNIX on this board).
DTC="${HOST_DIR}/bin/dtc"
OVERLAY_SRC="${BOARD_DIR}/linux/overlays"
mkdir -p "${BINARIES_DIR}/overlays"
if [ -x "${DTC}" ]; then
	for dts in "${OVERLAY_SRC}"/*.dts; do
		[ -f "$dts" ] || continue
		base=$(basename "$dts" .dts)
		"${DTC}" -@ -I dts -O dtb \
			-o "${BINARIES_DIR}/overlays/${base}.dtbo" "$dts"
	done
else
	echo "post-image: host dtc missing, undervolt overlays not built" >&2
	exit 1
fi

[ -x "${BINARIES_DIR}/initramfs/init" ] ||
	{ echo "post-image: initramfs is missing (BR2_PACKAGE_ZLYME_INITRAMFS)" >&2
	  exit 1; }
[ -s "${BINARIES_DIR}/splash.anim" ] ||
	{ echo "post-image: splash.anim is missing (rasterize branding, rebuild zlyme-initramfs)" >&2
	  exit 1; }
[ -s "${BINARIES_DIR}/progress.anim" ] ||
	{ echo "post-image: progress.anim is missing (rasterize branding, rebuild zlyme-initramfs)" >&2
	  exit 1; }
for fw in miyoo355_fw.img miyoo355_fw-multiboot.img miyoo355_fw-maskrom.img miyoo355_fw-restore.img; do
	[ -s "${BINARIES_DIR}/${fw}" ] || {
		echo "post-image: ${fw} is missing (my355-fw-installer)" >&2
		exit 1
	}
done
cmp -s "${BINARIES_DIR}/miyoo355_fw.img" "${BINARIES_DIR}/miyoo355_fw-multiboot.img" || {
	echo "post-image: miyoo355_fw-multiboot.img is not the multiboot installer" >&2
	exit 1
}
# Two spaces, then the basename. Same bytes every time for the same image.
(
	cd "${BINARIES_DIR}"
	sha256sum miyoo355_fw.img > miyoo355_fw.img.sha256
	sha256sum miyoo355_fw-multiboot.img > miyoo355_fw-multiboot.img.sha256
	sha256sum miyoo355_fw-maskrom.img > miyoo355_fw-maskrom.img.sha256
	sha256sum miyoo355_fw-restore.img > miyoo355_fw-restore.img.sha256
) || {
	echo "post-image: could not hash a preloader helper image" >&2
	exit 1
}

sq_bytes=$(wc -c < "${BINARIES_DIR}/zlyme")
echo "post-image: squashfs ${sq_bytes} bytes as FAT file zlyme on 1300M ZLYMEBOOT"
support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
# Versioned OTA tar + sha256 next to zlyme.img. The device pak mv's it
# to /storage/.update/zlyme-my355-update.tar. Do not Etcher over a games card.
# A failed pack removes this invocation's zlyme.img. It does not glob
# away older versioned tars.
finish_ota

# Same two-space sha256sum format as the helper images. Not an OTA member.
# genimage has already closed zlyme.img, so this file is not inside it.
if [ -s "${BINARIES_DIR}/zlyme.img" ]; then
	(
		cd "${BINARIES_DIR}"
		sha256sum zlyme.img > zlyme.img.sha256
		sha256sum -c zlyme.img.sha256 >/dev/null
	) || {
		echo "post-image: could not hash zlyme.img" >&2
		exit 1
	}
fi
