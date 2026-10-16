#!/bin/sh
# README width, and the two Unreleased chronologies leaving the changelog.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

fail() {
	echo "phase 13a docs: $*" >&2
	exit 1
}

readme=$(grep 'zlyme_slime_loop.gif' "$ROOT/README.md")
printf '%s\n' "$readme" | grep -q 'width="333"' || fail "README width is not 333: $readme"
printf '%s\n' "$readme" | grep -q 'width="887"' && fail "README still uses 887"
gif=$ROOT/package/system/nextui/res/branding/zlyme_slime_loop.gif
head -c 6 "$gif" | grep -q '^GIF8' || fail "README GIF is not a GIF"

unreleased=$(awk '
	/^## \[Unreleased\]/ { on = 1; next }
	on && /^## \[/ { exit }
	on { print }
' "$ROOT/CHANGELOG.md")
printf '%s\n' "$unreleased" | grep -q '7951a37668e3' \
	&& fail "Unreleased still has the MTP chronology"
printf '%s\n' "$unreleased" | grep -q 'Panfrost'"'"'s experimental Vulkan driver showed one frame' \
	&& fail "Unreleased still has the PanVK chronology"
printf '%s\n' "$unreleased" | grep -q 'Known limitations' \
	&& fail "Unreleased still has a Known limitations heading"
rel43=$(awk '
	/^## \[zlyme44\.3\]/ { on = 1; next }
	on && /^## \[/ { exit }
	on { print }
' "$ROOT/CHANGELOG.md")
printf '%s\n' "$rel43" | grep -q 'SDCARD1' || fail "zlyme44.3 omits the MTP names"
printf '%s\n' "$rel43" | grep -q 'basic-data' || fail "zlyme44.3 omits the partition type"
printf '%s\n' "$rel43" | grep -q '](docs/' && fail "zlyme44.3 uses a relative guide link"

grep -q '7951a37668e3' "$ROOT/docs/ROADMAP.md" \
	|| fail "roadmap lost the MTP archive"
grep -q 'one orange frame' "$ROOT/docs/ROADMAP.md" \
	|| fail "roadmap lost the PanVK frame"
grep -q 'one orange frame' "$ROOT/docs/LOGBOOK.md" \
	|| fail "logbook lost the PanVK frame"
grep -q '7951a37668e3' "$ROOT/docs/research/usb-mtp-phase12d.md" \
	|| fail "research lost the MTP archive"

echo "phase 13a docs ok"
