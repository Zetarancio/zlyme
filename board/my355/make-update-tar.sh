#!/usr/bin/env bash
# Pack kernel + DTB + overlays + squashfs + U-Boot blobs for OTA.
# apply_files copies the kernel; it does not write the FIT.
# Device picks the newest /storage/.update/${ZLYME_UPDATE_PREFIX}-*.tar
# (the pak still renames a GitHub download to update.tar). Releases
# ship the versioned tar and its .sha256.

set -euo pipefail

BINARIES_DIR="${1:?make-update-tar.sh: expected BINARIES_DIR}"
BOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${BOARD_DIR}/../.." && pwd)"
# shellcheck disable=SC1091
. "${BOARD_DIR}/fsoverlay/usr/share/zlyme/device.conf"
: "${ZLYME_UPDATE_PREFIX:?}"
: "${ZLYME_DTB:?}"

ver="unknown"
if [ -d "${ROOT}/.git" ]; then
	ver=$(git -C "$ROOT" describe --always --dirty --abbrev=12 2>/dev/null || git -C "$ROOT" rev-parse --short=12 HEAD)
fi
# shellcheck disable=SC1091
. "${BOARD_DIR}/image-date.sh"
stamp=$(zlyme_image_stamp)

need=(
	"${BINARIES_DIR}/Image.gz"
	"${BINARIES_DIR}/${ZLYME_DTB}"
	"${BINARIES_DIR}/zlyme"
	"${BINARIES_DIR}/idbloader.img"
	"${BINARIES_DIR}/u-boot.itb"
)
for f in "${need[@]}"; do
	[ -s "$f" ] || { echo "make-update-tar: missing $f" >&2; exit 1; }
done

stage=$(mktemp -d)
part=""
sumpart=""
out=""
published=0
cleanup_pack() {
	status=$?
	rm -rf "$stage"
	if [ -n "$part" ]; then
		rm -f "$part"
	fi
	if [ -n "$sumpart" ]; then
		rm -f "$sumpart"
	fi
	# Only the tar this invocation published. An older differently
	# named artifact is left where it is.
	if [ "$status" -ne 0 ] && [ "$published" = 1 ]; then
		rm -f "$out" "${out}.sha256"
	fi
	exit "$status"
}
trap cleanup_pack EXIT
mkdir -p "$stage/overlays" "$stage/extlinux"

install -m 0644 "${BINARIES_DIR}/Image.gz" "$stage/Image.gz"
install -m 0644 "${BINARIES_DIR}/${ZLYME_DTB}" "$stage/${ZLYME_DTB}"
install -m 0644 "${BINARIES_DIR}/zlyme" "$stage/zlyme"
install -m 0644 "${BINARIES_DIR}/idbloader.img" "$stage/idbloader.img"
install -m 0644 "${BINARIES_DIR}/u-boot.itb" "$stage/u-boot.itb"
ota_files="Image.gz ${ZLYME_DTB} zlyme idbloader.img u-boot.itb overlays extlinux VERSION pre-update.sh post-update.sh"
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

base="${ZLYME_UPDATE_PREFIX}-${stamp}-${ver}.tar"
out="${BINARIES_DIR}/${base}"
part="${out}.part"
sumpart="${out}.sha256.part"
rm -f "$part" "$sumpart"
rm -f "${BINARIES_DIR}/${ZLYME_UPDATE_PREFIX}-update.tar"
# shellcheck disable=SC2086
tar -C "$stage" -cf "$part" $ota_files
mv "$part" "$out"
part=""
published=1
(
	cd "${BINARIES_DIR}"
	sha256sum "${base}" > "${base}.sha256.part"
)
mv "$sumpart" "${out}.sha256"
sumpart=""
echo "make-update-tar: $out"
echo "make-update-tar: ${out}.sha256"
