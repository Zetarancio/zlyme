#!/bin/sh
# The wrapper must name the repository build.sh, the ARMHF defconfig,
# and <repo>/output-armhf. It does not start a toolchain build.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "armhf-wrapper: $*" >&2; exit 1; }
out=$(ZLYME_ARMHF_WRAPPER_DRY=1 "$ROOT/scripts/build-armhf-sysroot.sh")
printf '%s\n' "$out" | grep -qx "build=$ROOT/build.sh" || fail "build.sh path: $out"
printf '%s\n' "$out" | grep -qx "defconfig=zlyme_my355_armhf_defconfig" || fail "defconfig: $out"
printf '%s\n' "$out" | grep -qx "output=$ROOT/output-armhf" || fail "output: $out"
printf '%s\n' "$out" | grep -q '/scripts/output-armhf' && fail "output is under scripts"
printf '%s\n' "$out" | grep -q '/scripts/build.sh' && fail "build.sh is under scripts"
grep -q 'ZLYME_OUTPUT}:/zlyme/output' "$ROOT/build.sh" || fail "build.sh does not mount ZLYME_OUTPUT"
if ZLYME_ARMHF_WRAPPER_DRY=1 ZLYME_ARMHF_OUTPUT="$ROOT/output" \
	"$ROOT/scripts/build-armhf-sysroot.sh" >/dev/null 2>&1
then
	fail "product output was accepted"
fi
echo "armhf wrapper ok"
