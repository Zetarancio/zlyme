#!/usr/bin/env bash
# Copy extlinux.conf, make a 64MB exFAT storage image, run genimage.

set -euo pipefail

BINARIES_DIR="${1:?post-image.sh: expected BINARIES_DIR as the first argument}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -D -m 0644 "${BOARD_DIR}/extlinux.conf" \
	"${BINARIES_DIR}/extlinux/extlinux.conf"

STORAGE_MB=64
rm -f "${BINARIES_DIR}/storage.exfat"
truncate -s "${STORAGE_MB}M" "${BINARIES_DIR}/storage.exfat"
mkfs.exfat -L ZLYME "${BINARIES_DIR}/storage.exfat" >/dev/null

[ -s "${BINARIES_DIR}/rk3566-miyoo-flip.dtb" ] ||
	{ echo "post-image: rk3566-miyoo-flip.dtb is missing" >&2
	  exit 1; }

exec support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
