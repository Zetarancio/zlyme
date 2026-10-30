#!/bin/sh
# OTA archive listing must exit 0 before any extract or quarantine decision.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
UPDATE="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update"
fail() { echo "update-archive: $*" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
conf=$work/device.conf
cat >"$conf" <<'EOF'
ZLYME_UPDATE_PREFIX=zlyme-my355
ZLYME_DTB=rk3566-miyoo-flip.dtb
ZLYME_DEVICE_ID=my355
EOF
boot=$work/boot
storage=$work/storage
mkdir -p "$boot" "$storage"
printf 'live\n' >"$boot/zlyme"

run() {
	ZLYME_UPDATE_TEST=1 \
	ZLYME_DEVICE_CONF="$conf" \
	ZLYME_STORAGE="$storage" \
	ZLYME_BOOT="$boot" \
		"$UPDATE" "$@"
}

if [ -x "$ROOT/output/host/bin/mksquashfs" ]; then
	MKSQ=$ROOT/output/host/bin/mksquashfs
elif command -v mksquashfs >/dev/null 2>&1; then
	MKSQ=$(command -v mksquashfs)
else
	fail "mksquashfs is required"
fi

write_squashfs() {
	dest=$1
	tag=$2
	src=$work/tree-$tag
	rm -rf "$src"
	mkdir -p "$src/dir"
	printf '%s\n' "$tag" >"$src/dir/file"
	rm -f "$dest"
	"$MKSQ" "$src" "$dest" -comp zstd -all-root -noappend >/dev/null
}

full_stage() {
	dir=$1
	mkdir -p "$dir/overlays" "$dir/extlinux"
	printf 'kernel' >"$dir/Image.gz"
	printf 'dtb' >"$dir/rk3566-miyoo-flip.dtb"
	write_squashfs "$dir/zlyme" full
	printf 'idb' >"$dir/idbloader.img"
	printf 'itb' >"$dir/u-boot.itb"
	printf 'ver\n20261008\n' >"$dir/VERSION"
	printf '#!/bin/sh\n' >"$dir/pre-update.sh"
	printf '#!/bin/sh\n' >"$dir/post-update.sh"
	printf 'dtbo' >"$dir/overlays/x.dtbo"
	printf 'menu' >"$dir/extlinux/extlinux.conf"
}

full_stage "$work/full"
good=$work/good.tar
tar -C "$work/full" -cf "$good" Image.gz rk3566-miyoo-flip.dtb zlyme idbloader.img \
	u-boot.itb overlays extlinux VERSION pre-update.sh post-update.sh

# A later header is corrupt. tar -tf still prints the early required names.
python3 - "$good" "$work/damaged.tar" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())
off = 0
found = False
while off + 512 <= len(data):
    name = data[off:off + 100].split(b"\0", 1)[0]
    if name == b"idbloader.img":
        data[off + 257:off + 262] = b"XXXXX"
        found = True
        break
    off += 512
if not found:
    raise SystemExit("idbloader header was not found")
open(dst, "wb").write(data)
PY
damaged=$work/damaged.tar
tar -tf "$damaged" >"$work/damaged.list" 2>"$work/damaged.err" || true
grep -qx Image.gz "$work/damaged.list" || fail "fixture did not list Image.gz"
grep -qx rk3566-miyoo-flip.dtb "$work/damaged.list" || fail "fixture did not list the dtb"
grep -qx zlyme "$work/damaged.list" || fail "fixture did not list zlyme"
if tar -tf "$damaged" >/dev/null 2>&1; then
	fail "fixture tar -tf exited 0"
fi

rm -rf "$storage/.update"
set +e
run verify "$damaged" >"$work/out" 2>"$work/err"
rc=$?
set -e
[ "$rc" != 0 ] || fail "damaged listing was accepted"
grep -q 'tar listing failed' "$work/out" "$work/err" || fail "damaged reason $(cat "$work/out" "$work/err")"
if [ -e "$storage/.update/pending" ]; then
	fail "damaged tar was extracted"
fi

# Same archive through the apply path: junk, not a quarantined retry.
mkdir -p "$storage/.update"
cp "$damaged" "$storage/.update/zlyme-my355-damaged.tar"
set +e
run boot-apply >"$work/boot.out" 2>"$work/boot.err"
set -e
if [ -e "$storage/.update/pending" ]; then
	fail "boot-apply extracted the damaged tar"
fi
if [ -e "$storage/.update/failed/zlyme-my355-damaged.tar" ]; then
	fail "damaged listing was quarantined for retry"
fi
if [ -e "$storage/.update/zlyme-my355-damaged.tar" ]; then
	fail "damaged listing was left queued"
fi
grep -q 'tar listing failed' "$storage/.update/apply.log" || fail "boot-apply log $(cat "$storage/.update/apply.log")"

# Missing required member.
rm -rf "$storage/.update"
mkdir -p "$work/nodtb"
printf 'kernel' >"$work/nodtb/Image.gz"
printf 'root-bytes\n' >"$work/nodtb/zlyme"
tar -C "$work/nodtb" -cf "$work/nodtb.tar" Image.gz zlyme
set +e
run verify "$work/nodtb.tar" >"$work/out" 2>"$work/err"
rc=$?
set -e
[ "$rc" != 0 ] || fail "tar without a dtb was accepted"
grep -q 'tar has no dtb' "$work/out" "$work/err" || fail "missing dtb reason $(cat "$work/out" "$work/err")"
if [ -e "$storage/.update/pending" ]; then
	fail "incomplete tar was extracted"
fi

# Valid full tar lists cleanly and test-stage extracts it.
rm -rf "$storage/.update"
run verify "$good" >"$work/out" 2>"$work/err"
grep -q 'tar ok' "$work/out" "$work/err" || fail "valid tar was not accepted $(cat "$work/out" "$work/err")"
run test-stage "$good" >"$work/out" 2>"$work/err"
cmp "$storage/.update/pending/zlyme" "$work/full/zlyme" || fail "valid extract mismatch"
test -s "$storage/.update/pending/Image.gz" || fail "valid extract omitted Image.gz"
python3 - "$work/full/zlyme" <<'PY' || fail "valid fixture is not a SquashFS image"
import sys
data = open(sys.argv[1], "rb").read(4)
if data != b"hsqs":
    raise SystemExit("fixture magic")
PY

# A listed archive whose root is not a SquashFS is an apply failure.
# test-stage must not publish it. boot-apply quarantines and returns.
python3 - "$work" <<'PY'
import os
import struct
import sys
work = sys.argv[1]
def write(name, data):
    with open(os.path.join(work, name), "wb") as handle:
        handle.write(data)
write("arbitrary", b"root-bytes\n" * 16)
write("short", b"short")
write("magic-short", b"hsqs" + b"\0" * 20)
buf = bytearray(128)
struct.pack_into("<I", buf, 0, 0x73717368)
struct.pack_into("<I", buf, 4, 2)
struct.pack_into("<I", buf, 12, 131072)
struct.pack_into("<H", buf, 20, 6)
struct.pack_into("<H", buf, 22, 17)
struct.pack_into("<H", buf, 26, 1)
struct.pack_into("<H", buf, 28, 4)
struct.pack_into("<Q", buf, 32, 96)
struct.pack_into("<Q", buf, 40, 10000000)
write("overlong", bytes(buf))
PY

reject_staged() {
	label=$1
	rootfile=$2
	reason=$3
	dir=$work/bad-$label
	rm -rf "$dir" "$storage/.update"
	mkdir -p "$dir" "$storage/.update"
	printf 'kernel' >"$dir/Image.gz"
	printf 'dtb' >"$dir/rk3566-miyoo-flip.dtb"
	cp "$rootfile" "$dir/zlyme"
	printf 'ver\n20261008\n' >"$dir/VERSION"
	tar -C "$dir" -cf "$work/$label.tar" Image.gz rk3566-miyoo-flip.dtb zlyme VERSION
	set +e
	run test-stage "$work/$label.tar" >"$work/out" 2>"$work/err"
	rc=$?
	set -e
	[ "$rc" != 0 ] || fail "$label test-stage accepted the root (rc $rc)"
	grep -q "$reason" "$work/out" "$work/err" || fail "$label test-stage reason $(cat "$work/out" "$work/err")"
	if [ -e "$storage/.update/pending/zlyme" ]; then
		fail "$label test-stage published pending/zlyme"
	fi
	cp "$work/$label.tar" "$storage/.update/zlyme-my355-$label.tar"
	printf 'live\n' >"$boot/zlyme"
	printf 'live\n' >"$work/live"
	set +e
	timeout 5 sh -c '
		ZLYME_UPDATE_TEST=1 \
		ZLYME_DEVICE_CONF="$1" \
		ZLYME_STORAGE="$2" \
		ZLYME_BOOT="$3" \
			"$4" boot-apply
	' sh "$conf" "$storage" "$boot" "$UPDATE" >"$work/out" 2>"$work/err"
	rc=$?
	set -e
	[ "$rc" = 0 ] || fail "$label boot-apply rc $rc"
	if [ -e "$storage/.update/pending/zlyme" ]; then
		fail "$label left pending/zlyme"
	fi
	if [ -e "$storage/.update/incoming" ]; then
		fail "$label left an unpublished extract"
	fi
	test -f "$storage/.update/failed/zlyme-my355-$label.tar" || fail "$label was not quarantined"
	if [ -e "$storage/.update/zlyme-my355-$label.tar" ]; then
		fail "$label stayed queued"
	fi
	grep -q "$reason" "$storage/.update/FAILED" "$storage/.update/apply.log" || fail "$label apply reason $(cat "$storage/.update/FAILED" "$storage/.update/apply.log")"
	cmp "$boot/zlyme" "$work/live" || fail "$label changed the live root"
}

reject_staged arbitrary "$work/arbitrary" "not a squashfs"
reject_staged short "$work/short" "truncated squashfs"
reject_staged magic-short "$work/magic-short" "truncated squashfs"
reject_staged overlong "$work/overlong" "squashfs length"

# ensure_pending must not reuse a pending root that already failed this check.
rm -rf "$storage/.update"
mkdir -p "$storage/.update/pending"
printf 'kernel' >"$storage/.update/pending/Image.gz"
printf 'dtb' >"$storage/.update/pending/rk3566-miyoo-flip.dtb"
printf 'ver\n20261008\n' >"$storage/.update/pending/VERSION"
cp "$work/arbitrary" "$storage/.update/pending/zlyme"
printf 'live\n' >"$boot/zlyme"
set +e
timeout 5 sh -c '
	ZLYME_UPDATE_TEST=1 \
	ZLYME_DEVICE_CONF="$1" \
	ZLYME_STORAGE="$2" \
	ZLYME_BOOT="$3" \
		"$4" boot-apply
' sh "$conf" "$storage" "$boot" "$UPDATE" >"$work/out" 2>"$work/err"
rc=$?
set -e
[ "$rc" = 0 ] || fail "ensure_pending boot-apply rc $rc"
if [ -e "$storage/.update/pending/zlyme" ]; then
	fail "ensure_pending reused a non-squashfs root"
fi
if [ -e "$storage/.update/incoming" ]; then
	fail "ensure_pending left an unpublished extract"
fi
grep -q 'not a squashfs' "$storage/.update/FAILED" "$storage/.update/apply.log" || fail "ensure_pending reason $(cat "$storage/.update/FAILED" "$storage/.update/apply.log")"
cmp "$boot/zlyme" "$work/live" || fail "ensure_pending changed the live root"

# zlyme-update apply is not boot-apply. A rejected pending root must still be removed.
rm -rf "$storage/.update"
mkdir -p "$storage/.update/pending"
printf 'kernel' >"$storage/.update/pending/Image.gz"
printf 'dtb' >"$storage/.update/pending/rk3566-miyoo-flip.dtb"
printf 'ver\n20261008\n' >"$storage/.update/pending/VERSION"
cp "$work/arbitrary" "$storage/.update/pending/zlyme"
printf 'live\n' >"$boot/zlyme"
set +e
timeout 5 sh -c '
	ZLYME_UPDATE_TEST=1 \
	ZLYME_DEVICE_CONF="$1" \
	ZLYME_STORAGE="$2" \
	ZLYME_BOOT="$3" \
		"$4" apply
' sh "$conf" "$storage" "$boot" "$UPDATE" >"$work/out" 2>"$work/err"
rc=$?
set -e
[ "$rc" != 0 ] || fail "apply accepted a non-squashfs pending root"
[ "$rc" != 124 ] || fail "apply rebooted on a rejected root"
if [ -e "$storage/.update/pending/zlyme" ]; then
	fail "apply left a rejected pending root"
fi
grep -q 'not a squashfs' "$storage/.update/FAILED" "$storage/.update/apply.log" || fail "apply reason $(cat "$storage/.update/FAILED" "$storage/.update/apply.log")"
cmp "$boot/zlyme" "$work/live" || fail "apply changed the live root"

# A listing that exits 0 can still fail extraction. That stays a quarantine.
rm -rf "$storage/.update"
mkdir -p "$storage/.update" "$work/bin"
cp "$good" "$storage/.update/zlyme-my355-extract.tar"
cat >"$work/bin/tar" <<'EOF'
#!/bin/sh
if [ "$1" = "-xf" ]; then
	echo "forced extract failure" >&2
	exit 1
fi
exec /usr/bin/tar "$@"
EOF
chmod 0755 "$work/bin/tar"
set +e
PATH="$work/bin:$PATH" \
ZLYME_UPDATE_TEST=1 \
ZLYME_DEVICE_CONF="$conf" \
ZLYME_STORAGE="$storage" \
ZLYME_BOOT="$boot" \
	"$UPDATE" boot-apply >"$work/out" 2>"$work/err"
set -e
test -f "$storage/.update/failed/zlyme-my355-extract.tar" || fail "extract failure was not quarantined"
if [ -e "$storage/.update/pending/zlyme" ]; then
	fail "failed extract left a pending root"
fi
if [ -e "$storage/.update/zlyme-my355-extract.tar" ]; then
	fail "failed extract left the tar queued"
fi
grep -q 'extract failed' "$storage/.update/apply.log" || fail "extract log $(cat "$storage/.update/apply.log")"

echo "update archive ok"
