#!/bin/sh
# Exit 0 when the image directory has a non-empty product OTA and zlyme.img.
# The release job still checks members, checksums, and the manifest.
set -eu

dir=${1:?images directory required}
if [ ! -d "$dir" ]; then
	exit 1
fi

tar_ok=0
for archive in "$dir"/zlyme-my355-*.tar; do
	if [ -f "$archive" ] && [ -s "$archive" ]; then
		tar_ok=1
		break
	fi
done

if [ "$tar_ok" -eq 1 ] && [ -s "$dir/zlyme.img" ]; then
	exit 0
fi
exit 1
