#!/bin/sh
# The runtime manifest matches output-armhf and rejects a stale copy.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CHECK=$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh
SRC=$ROOT/output-armhf
fail() { echo "armhf-manifest-test: $*" >&2; exit 1; }
blocked() { echo "armhf-manifest-test blocked: $*" >&2; exit 2; }
[ -f "$SRC/zlyme-armhf-runtime.manifest" ] || blocked "manifest is missing"
mk=$ROOT/package/system/zlyme-armhf-runtime/zlyme-armhf-runtime.mk
if grep -E 'docker|build\.sh|/tmp/zlyme-armhf' "$mk"; then
	fail "runtime package starts a nested build or reads the old sysroot"
fi
grep -q '/zlyme/armhf' "$mk" || fail "runtime package does not read /zlyme/armhf"
"$CHECK" "$SRC"
if grep -E '^(file|link) .* (host/|usr/bin/|bin/)' "$SRC/zlyme-armhf-runtime.manifest"; then
	fail "manifest lists a compiler or the probe"
fi
if grep -E '/(libclang|libLLVM|libLTO|libRemarks|libLLVMSPIRVLib|libSPIRV-Tools-(diff|link|lint|opt|reduce|shared)|os-release)' \
	"$SRC/zlyme-armhf-runtime.manifest"; then
	fail "manifest lists an ARMHF build-only library or target metadata"
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/good/target/lib" "$work/good/target/usr/lib"
cp -a "$SRC/target/lib/ld-linux-armhf.so.3" "$work/good/target/lib/"
cp -a "$SRC/target/usr/lib/zlyme-armhf" "$work/good/target/usr/lib/"
cp -a "$SRC/.zlyme-defconfig" "$SRC/.config" "$SRC/zlyme-armhf-runtime.manifest" "$work/good/"
"$CHECK" "$work/good"
mkdir -p "$work/good/target/usr/lib/zlyme-armhf/dri"
printf 'unlisted\n' > "$work/good/target/usr/lib/zlyme-armhf/dri/unlisted.so"
if "$CHECK" "$work/good" >"$work/unlisted.out" 2>&1; then
	fail "unlisted nested runtime file was accepted"
fi
grep -q 'unlisted runtime file' "$work/unlisted.out" ||
	fail "nested unlisted file was not reported"
rm -f "$work/good/target/usr/lib/zlyme-armhf/dri/unlisted.so"
sum=$(awk '/^file / { print $2; exit }' "$work/good/zlyme-armhf-runtime.manifest")
sed -i "s/$sum/0000000000000000000000000000000000000000000000000000000000000000/" \
	"$work/good/zlyme-armhf-runtime.manifest"
if "$CHECK" "$work/good" >"$work/stale.out" 2>&1; then
	fail "stale manifest was accepted"
fi
grep -q 'stale' "$work/stale.out" || fail "stale was not reported: $(cat "$work/stale.out")"
rm -f "$work/good/zlyme-armhf-runtime.manifest"
if "$CHECK" "$work/good" >"$work/missing.out" 2>&1; then
	fail "missing manifest was accepted"
fi
grep -q 'missing' "$work/missing.out" || fail "missing was not reported"
echo "armhf manifest test ok"
