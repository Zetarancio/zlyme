#!/bin/sh
# The OS date is the image build date, not the NextUI package date.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
post=$ROOT/board/my355/post-build.sh
tarsh=$ROOT/board/my355/make-update-tar.sh
build=$ROOT/build.sh
helper=$ROOT/board/my355/image-date.sh

version=$(tr -d ' \t\r\n' < "$ROOT/ZLYME_VERSION")
python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import zlyme_release; zlyme_release.parse_version(sys.argv[2])' "$ROOT/scripts" "$version"

if grep -q 'build-date.txt' "$post"; then
	echo "OS version still reads NextUI build-date.txt" >&2
	exit 1
fi
grep -q 'image-date.sh' "$post"
grep -q 'ZLYME_IMAGE_DATE' "$post"
grep -q 'image-date.sh' "$tarsh"
grep -q 'zlyme_image_stamp' "$tarsh"
if grep -q 'date -u +%Y%m%d' "$tarsh"; then
	echo "OTA stamp still reads the clock itself" >&2
	exit 1
fi
grep -q 'ZLYME_IMAGE_DATE' "$build"
grep -q -- '-e ZLYME_IMAGE_DATE' "$build"

# shellcheck disable=SC1091
. "$helper"

sample=2024-07-04
ZLYME_IMAGE_DATE=$sample
zlyme_require_image_date
stamp=$(zlyme_image_stamp)
test "$stamp" = 20240704
test "$(printf '%s (%s)' "$version" "$ZLYME_IMAGE_DATE")" = "$version ($sample)"

fail_date() {
	if ZLYME_IMAGE_DATE=$1 zlyme_require_image_date >/dev/null 2>&1; then
		echo "accepted bad image date: $1" >&2
		exit 1
	fi
}
fail_date ''
fail_date 20240704
fail_date 2024-7-04
fail_date 2024-13-01
fail_date 2024-02-31
fail_date 2024/07/04

echo "image date ok"
