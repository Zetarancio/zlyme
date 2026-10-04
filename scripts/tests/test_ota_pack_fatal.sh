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

mkdir -p "$work/final"
printf 'kept\n' > "$work/final/zlyme-my355-kept.tar"
printf 'kept\n' > "$work/final/zlyme-my355-kept.tar.sha256"
set +e
env ZLYME_POST_IMAGE_TEST=pack-final \
	ZLYME_OTA_PACKER="$work/fail-packer.sh" \
	bash "$post" "$work/final" >"$work/final.out" 2>"$work/final.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "pack-final treated a packer failure as success" >&2
	exit 1
fi
if [ -e "$work/final/zlyme.img" ]; then
	echo "failed pack left zlyme.img" >&2
	exit 1
fi
if [ "$(cat "$work/final/zlyme-my355-kept.tar")" != kept ]; then
	echo "failed pack removed an older tar" >&2
	exit 1
fi
if [ "$(cat "$work/final/zlyme-my355-kept.tar.sha256")" != kept ]; then
	echo "failed pack removed an older checksum" >&2
	exit 1
fi

pack=$ROOT/board/my355/make-update-tar.sh
export ZLYME_IMAGE_DATE=2026-10-05
seed_inputs() {
	dir=$1
	mkdir -p "$dir"
	dtb=rk3566-miyoo-flip.dtb
	for f in Image.gz "$dtb" zlyme idbloader.img u-boot.itb; do
		printf 'x\n' > "$dir/$f"
	done
}

seed_inputs "$work/tar-ok"
bash "$pack" "$work/tar-ok" >"$work/tar-ok.out"
ok_tars=$(find "$work/tar-ok" -maxdepth 1 -name '*.tar' | wc -l)
ok_sums=$(find "$work/tar-ok" -maxdepth 1 -name '*.tar.sha256' | wc -l)
ok_parts=$(find "$work/tar-ok" -maxdepth 1 -name '*.part' | wc -l)
if [ "$ok_tars" -ne 1 ] || [ "$ok_sums" -ne 1 ] || [ "$ok_parts" -ne 0 ]; then
	echo "successful pack left tar=$ok_tars sha=$ok_sums part=$ok_parts" >&2
	ls -la "$work/tar-ok" >&2
	exit 1
fi

seed_inputs "$work/tar-fail"
printf 'kept\n' > "$work/tar-fail/zlyme-my355-kept.tar"
printf 'kept\n' > "$work/tar-fail/zlyme-my355-kept.tar.sha256"
mkdir -p "$work/bin"
cat > "$work/bin/tar" <<'EOF'
#!/bin/sh
prev=
archive=
for arg in "$@"; do
	if [ "$prev" = "-cf" ]; then
		archive=$arg
	fi
	prev=$arg
done
if [ -n "$archive" ]; then
	printf 'partial\n' > "$archive"
fi
exit 1
EOF
chmod 0755 "$work/bin/tar"
set +e
env PATH="$work/bin:$PATH" bash "$pack" "$work/tar-fail" >"$work/tar-fail.out" 2>"$work/tar-fail.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "failing tar was published" >&2
	exit 1
fi
if [ "$(cat "$work/tar-fail/zlyme-my355-kept.tar")" != kept ]; then
	echo "interrupted tar removed an older archive" >&2
	exit 1
fi
if find "$work/tar-fail" -maxdepth 1 -name '*.part' | grep -q .; then
	echo "interrupted tar left a partial archive" >&2
	find "$work/tar-fail" -maxdepth 1 -name '*.part' >&2
	exit 1
fi
new_tars=$(find "$work/tar-fail" -maxdepth 1 -name '*.tar' ! -name 'zlyme-my355-kept.tar' | wc -l)
if [ "$new_tars" -ne 0 ]; then
	echo "interrupted tar left a final archive" >&2
	exit 1
fi

seed_inputs "$work/tar-sum"
printf 'kept\n' > "$work/tar-sum/zlyme-my355-kept.tar"
printf 'kept\n' > "$work/tar-sum/zlyme-my355-kept.tar.sha256"
mkdir -p "$work/bin-sum"
cat > "$work/bin-sum/sha256sum" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 0755 "$work/bin-sum/sha256sum"
set +e
env PATH="$work/bin-sum:$PATH" bash "$pack" "$work/tar-sum" >"$work/tar-sum.out" 2>"$work/tar-sum.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "failed checksum was published" >&2
	exit 1
fi
if [ "$(cat "$work/tar-sum/zlyme-my355-kept.tar")" != kept ]; then
	echo "checksum failure removed an older archive" >&2
	exit 1
fi
new_tars=$(find "$work/tar-sum" -maxdepth 1 -name '*.tar' ! -name 'zlyme-my355-kept.tar' | wc -l)
new_sums=$(find "$work/tar-sum" -maxdepth 1 -name '*.sha256' ! -name 'zlyme-my355-kept.tar.sha256' | wc -l)
new_parts=$(find "$work/tar-sum" -maxdepth 1 -name '*.part' | wc -l)
if [ "$new_tars" -ne 0 ] || [ "$new_sums" -ne 0 ] || [ "$new_parts" -ne 0 ]; then
	echo "checksum failure left tar=$new_tars sha=$new_sums part=$new_parts" >&2
	ls -la "$work/tar-sum" >&2
	exit 1
fi

echo "ota pack fatal ok"
