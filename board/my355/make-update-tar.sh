#!/usr/bin/env bash
# Pack KERNEL + DTB + overlays + squashfs file for OTA.
# Device picks the newest /storage/.update/zlyme-my355-*.tar
# (the pak still renames a GitHub download to update.tar). Releases
# ship the versioned tar and its .sha256.

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
ota_files="Image rk3566-miyoo-flip.dtb zlyme overlays extlinux VERSION pre-update.sh post-update.sh"
if [ -s "${BINARIES_DIR}/splash.anim" ]; then
	install -m 0644 "${BINARIES_DIR}/splash.anim" "$stage/splash.anim"
	ota_files="$ota_files splash.anim"
fi
if [ -s "${BINARIES_DIR}/progress.anim" ]; then
	install -m 0644 "${BINARIES_DIR}/progress.anim" "$stage/progress.anim"
	ota_files="$ota_files progress.anim"
fi
install -m 0644 "${BOARD_DIR}/extlinux.conf" "$stage/extlinux/extlinux.conf"
if [ -d "${BINARIES_DIR}/overlays" ]; then
	cp -a "${BINARIES_DIR}/overlays/." "$stage/overlays/"
fi
printf '%s\n' "$ver" "$stamp" > "$stage/VERSION"
install -m 0755 "${BOARD_DIR}/pre-update.sh" "$stage/pre-update.sh"
install -m 0755 "${BOARD_DIR}/post-update.sh" "$stage/post-update.sh"

base="zlyme-my355-${stamp}-${ver}.tar"
out="${BINARIES_DIR}/${base}"
# shellcheck disable=SC2086
tar -C "$stage" -cf "$out" $ota_files
rm -f "${BINARIES_DIR}/zlyme-my355-update.tar"
(
	cd "${BINARIES_DIR}"
	sha256sum "${base}" > "${base}.sha256"
)
echo "make-update-tar: $out"
echo "make-update-tar: ${out}.sha256"
