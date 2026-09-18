#!/usr/bin/env bash
# Copy boot files, make the exFAT seed (grown on first boot), run genimage.

set -euo pipefail

BINARIES_DIR="${1:?post-image.sh: expected BINARIES_DIR as the first argument}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
mkfs.exfat -L ZLYME "${BINARIES_DIR}/storage.exfat" >/dev/null

[ -s "${BINARIES_DIR}/rk3566-miyoo-flip.dtb" ] ||
	{ echo "post-image: rk3566-miyoo-flip.dtb is missing" >&2
	  exit 1; }

[ -s "${BINARIES_DIR}/rootfs.squashfs" ] ||
	{ echo "post-image: rootfs.squashfs is missing" >&2
	  exit 1; }

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

sq_bytes=$(wc -c < "${BINARIES_DIR}/zlyme")
echo "post-image: squashfs ${sq_bytes} bytes as FAT file zlyme on 1300M ZLYMEBOOT"
support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
# Versioned OTA tar + sha256 next to zlyme.img. The device pak mv's it
# to /storage/.update/zlyme-my355-update.tar. Do not Etcher over a games card.
if [ -x "${BOARD_DIR}/make-update-tar.sh" ]; then
	"${BOARD_DIR}/make-update-tar.sh" "${BINARIES_DIR}" || \
		echo "post-image: update tar skipped" >&2
fi
