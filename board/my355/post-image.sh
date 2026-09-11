#!/usr/bin/env bash
# Copy boot files, make the exFAT seed (grown on first boot), run genimage.

set -euo pipefail

BINARIES_DIR="${1:?post-image.sh: expected BINARIES_DIR as the first argument}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -D -m 0644 "${BOARD_DIR}/extlinux.conf" \
	"${BINARIES_DIR}/extlinux/extlinux.conf"
install -D -m 0644 "${BOARD_DIR}/zlyme-boot.conf" \
	"${BINARIES_DIR}/zlyme-boot.conf"

# Same size as Knulli's miyoo-flip userdata seed. S13resize then grows
# the partition to the end of the card and mkfs.exfat. 64MB filled on
# first boot (paks + PortMaster); 512MB still works if autoresize fails.
STORAGE_MB=512
rm -f "${BINARIES_DIR}/storage.exfat"
truncate -s "${STORAGE_MB}M" "${BINARIES_DIR}/storage.exfat"
mkfs.exfat -L ZLYME "${BINARIES_DIR}/storage.exfat" >/dev/null

[ -s "${BINARIES_DIR}/rk3566-miyoo-flip.dtb" ] ||
	{ echo "post-image: rk3566-miyoo-flip.dtb is missing" >&2
	  exit 1; }

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

exec support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
