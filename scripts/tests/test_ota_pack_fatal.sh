#!/bin/sh
# A failing OTA packer fails the product post-image step before mkfs.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
post=$ROOT/board/my355/post-image.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/fail-packer.sh" <<'EOF'
#!/bin/sh
echo packer-failed >&2
exit 7
EOF
chmod 0755 "$work/fail-packer.sh"
mkdir -p "$work/images"

set +e
env ZLYME_POST_IMAGE_TEST=pack \
	ZLYME_OTA_PACKER="$work/fail-packer.sh" \
	bash "$post" "$work/images" >"$work/fail.out" 2>"$work/fail.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "failing packer was ignored" >&2
	exit 1
fi
grep -q 'packer-failed' "$work/fail.err"
if grep -q 'update tar skipped' "$work/fail.err"; then
	echo "post-image still swallows a packer failure" >&2
	exit 1
fi
if [ -e "$work/images/storage.exfat" ]; then
	echo "post-image reached mkfs after the packer failed" >&2
	exit 1
fi

mkdir -p "$work/skip"
env ZLYME_POST_IMAGE_TEST=pack ZLYME_SKIP_OTA=1 \
	bash "$post" "$work/skip" >"$work/skip.out" 2>"$work/skip.err"
grep -q 'ZLYME_SKIP_OTA=1' "$work/skip.err"
if [ -e "$work/skip/storage.exfat" ]; then
	echo "skip path still reached mkfs" >&2
	exit 1
fi

echo "ota pack fatal ok"
