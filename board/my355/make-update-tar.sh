#!/usr/bin/env bash
# Pack KERNEL + DTB + overlays + squashfs file for OTA.
# On the device: copy to /storage/.update/zlyme-my355-update.tar and reboot.
# zlyme-update extracts on ZLYME; initramfs copies pending/zlyme onto FAT.

set -euo pipefail

BINARIES_DIR="${1:?make-update-tar.sh: expected BINARIES_DIR}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${BOARD_DIR}/../.." && pwd)"

ver="unknown"
if [ -d "${ROOT}/.git" ]; then
	ver=$(git -C "$ROOT" describe --always --dirty --abbrev=12 2>/dev/null || git -C "$ROOT" rev-parse --short=12 HEAD)
fi
stamp=$(date -u +%Y%m%d)

need=(
	"${BINARIES_DIR}/Image"
	"${BINARIES_DIR}/rk3566-miyoo-flip.dtb"
	"${BINARIES_DIR}/zlyme"
)
for f in "${need[@]}"; do
	[ -s "$f" ] || { echo "make-update-tar: missing $f" >&2; exit 1; }
done

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/overlays" "$stage/extlinux"

install -m 0644 "${BINARIES_DIR}/Image" "$stage/Image"
install -m 0644 "${BINARIES_DIR}/rk3566-miyoo-flip.dtb" "$stage/rk3566-miyoo-flip.dtb"
install -m 0644 "${BINARIES_DIR}/zlyme" "$stage/zlyme"
install -m 0644 "${BOARD_DIR}/extlinux.conf" "$stage/extlinux/extlinux.conf"
if [ -d "${BINARIES_DIR}/overlays" ]; then
	cp -a "${BINARIES_DIR}/overlays/." "$stage/overlays/"
fi
printf '%s\n' "$ver" "$stamp" > "$stage/VERSION"

out="${BINARIES_DIR}/zlyme-my355-${stamp}-${ver}.tar"
tar -C "$stage" -cf "$out" Image rk3566-miyoo-flip.dtb zlyme overlays extlinux VERSION
ln -sfn "$(basename "$out")" "${BINARIES_DIR}/zlyme-my355-update.tar"
echo "make-update-tar: $out"
