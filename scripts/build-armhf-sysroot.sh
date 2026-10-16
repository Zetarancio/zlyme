#!/bin/sh
# Build the ARMHF sysroot into <repo>/output-armhf. This is not the
# Flip image. ZLYME_ARMHF_WRAPPER_DRY=1 prints the paths and exits.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT="${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}"
case "$OUT" in
	"$ROOT" | "$ROOT"/output | "$ROOT"/output/* | "$ROOT"/scripts | "$ROOT"/scripts/*)
		echo "armhf-sysroot: refusing output $OUT" >&2
		exit 1
		;;
esac
if [ "${ZLYME_ARMHF_WRAPPER_DRY:-}" = 1 ]; then
	printf 'build=%s\n' "$ROOT/build.sh"
	printf 'defconfig=zlyme_my355_armhf_defconfig\n'
	printf 'output=%s\n' "$OUT"
	exit 0
fi
export ZLYME_OUTPUT="$OUT"
set +e
"$ROOT/build.sh" --config zlyme_my355_armhf_defconfig zlyme-armhf-probe target-finalize
status=$?
set -e
if [ "$status" -eq 0 ]; then
	"$ROOT/scripts/armhf-runtime-manifest.sh"
fi
exit "$status"
