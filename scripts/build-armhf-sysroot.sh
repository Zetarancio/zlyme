#!/bin/sh
# Build the ARMHF sysroot into output-armhf. This is not the Flip image
# and it does not install the runtime into that image.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export ZLYME_OUTPUT="${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}"
exec "$ROOT/build.sh" --config zlyme_my355_armhf_defconfig zlyme-armhf-probe
