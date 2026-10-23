#!/bin/sh
# Pack a checked ARMHF export into one tar. upload-artifact does not
# keep symlink targets or file modes. The directory cache stays; this
# archive is what the image job downloads.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
src=${1:?export directory}
arc=${2:?archive path}
die() { echo "armhf-pack: $*" >&2; exit 1; }

"$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh" "$src"
"$ROOT/package/system/zlyme-box86/check-manifest.sh" "$src"
mkdir -p "$(dirname "$arc")"
rm -f "$arc"
# POSIX tar, no dereference. Members are relative to the export root.
tar --format=posix -cf "$arc" -C "$src" .
echo "armhf pack ok"
