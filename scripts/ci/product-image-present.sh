#!/bin/sh
# Exit 0 when the image directory has the stage artifact set:
# a non-empty product OTA and its checksum, zlyme.img and its checksum,
# and the four preloader helper images with their checksums.
# The release job still checks members, hashes, the manifest, and notes.
set -eu

dir=${1:?images directory required}
if [ ! -d "$dir" ]; then
	exit 1
fi

for name in \
	zlyme.img \
	zlyme.img.sha256 \
	miyoo355_fw.img \
	miyoo355_fw.img.sha256 \
	miyoo355_fw-multiboot.img \
	miyoo355_fw-multiboot.img.sha256 \
	miyoo355_fw-maskrom.img \
	miyoo355_fw-maskrom.img.sha256 \
	miyoo355_fw-restore.img \
	miyoo355_fw-restore.img.sha256
do
	if [ ! -s "$dir/$name" ]; then
		exit 1
	fi
done

tar_ok=0
for archive in "$dir"/zlyme-my355-*.tar; do
	if [ ! -f "$archive" ]; then
		continue
	fi
	base=$(basename "$archive")
	case "$base" in
	zlyme-my355-delta-*)
		continue
		;;
	esac
	if [ -s "$archive" ] && [ -s "$archive.sha256" ]; then
		tar_ok=1
		break
	fi
done

	[ "$tar_ok" -eq 1 ]
