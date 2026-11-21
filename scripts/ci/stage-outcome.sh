#!/bin/sh
# Decide whether a hosted image stage produced a publishable image.
# Stdout is a have_image= line for GITHUB_OUTPUT. The exit status is the
# step status: 0 to continue the workflow, non-zero to fail the stage.
#
# A compile-window timeout may continue, and it does not count as an image
# even if some files were already written. Any other non-zero build status
# fails. Exit 0 with a complete artifact set counts as an image. Exit 0
# without that set fails.
set -eu

rc=${1:?build status required}
dir=${2:?images directory required}
present=$("$(CDPATH='' cd -- "$(dirname "$0")" && pwd)/product-image-present.sh" "$dir" && echo yes || echo no)

case "$rc" in
124|137|143)
	echo "have_image=false"
	echo "Build window closed without an image; next stage continues from ccache." >&2
	exit 0
	;;
esac

if [ "$rc" -eq 0 ] && [ "$present" = yes ]; then
	echo "have_image=true"
	exit 0
fi

echo "have_image=false"
if [ "$rc" -eq 0 ]; then
	echo "build exited 0 without the product artifact set" >&2
	exit 1
fi
echo "build failed with status $rc" >&2
exit "$rc"
