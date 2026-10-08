#!/bin/sh
# Host checks for the stock-side preloader helper images.
# No NAND, no device, no U-Boot.
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
ZLYME="$ROOT/package/boot/my355-fw-installer/zlyme"
APOMMEL="${ZLYME_APOMMEL_TREE:-$ROOT/output/build/my355-fw-installer-e09d37bb0f03c34e564d61bd02164f332d8515a8/tools/preloader-installer}"
STOCK="$ROOT/package/system/zlyme-preloader/preloader-stock.img"
PY="$ROOT/package/system/zlyme-preloader/preloader_image.py"
MKPRE="$ROOT/output/build/my355-fw-installer-e09d37bb0f03c34e564d61bd02164f332d8515a8/tools/mkpreloader.py"
GEN="$ROOT/board/my355/genimage.cfg"
POST="$ROOT/board/my355/post-image.sh"
TAR="$ROOT/board/my355/make-update-tar.sh"
UNIT_RECOVERY=f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367
UNIT_STOCK=dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922

fail() { echo "fw-helpers: $*" >&2; exit 1; }

[ -f "$APOMMEL/mkfwimg.py" ] || fail "pinned apommel tree is missing: $APOMMEL"
[ -f "$STOCK" ] || fail "preloader-stock.img is missing"
command -v shellcheck >/dev/null 2>&1 || fail "shellcheck is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

shellcheck -s sh -x "$ZLYME/install-maskrom.sh" "$ZLYME/install-restore.sh" \
	"$ZLYME/apply-boot-order.sh" "$ZLYME/check-image.sh" "$ZLYME/common.sh" || fail "shellcheck"
sh -n "$ZLYME/common.sh" || fail "common.sh syntax"
python3 -m py_compile "$ZLYME/pack-fwimg.py" || fail "pack-fwimg.py"

for src in "$ZLYME"/*.sh "$ZLYME"/*.awk "$ZLYME"/*.py "$ZLYME"/NOTICE "$ZLYME"/LICENSE; do
	[ -e "$src" ] || continue
	if grep -q "$UNIT_RECOVERY" "$src" || grep -q "$UNIT_STOCK" "$src"; then
		fail "$(basename "$src") embeds a unit preloader hash"
	fi
done
if grep -q -- '--force' "$ZLYME"/*.sh; then
	fail "a helper accepts --force"
fi
if grep -n 'mmcblk1' "$ZLYME/install-maskrom.sh" "$ZLYME/install-restore.sh" "$ZLYME/common.sh"; then
	fail "a Zlyme helper still treats mmcblk1 as a slot"
fi
if grep -n '\<reboot\>' "$ZLYME/install-maskrom.sh" "$ZLYME/install-restore.sh" "$ZLYME/common.sh" \
	| grep -vE ':[0-9]+:[[:space:]]*#'; then
	fail "a Zlyme helper still reboots"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 "$APOMMEL/mkfwimg.py" "$work/a.img" >/dev/null
python3 "$APOMMEL/mkfwimg.py" "$work/b.img" >/dev/null
cmp -s "$work/a.img" "$work/b.img" || fail "multiboot pack is not deterministic"
cp -a "$work/a.img" "$work/miyoo355_fw.img"
cp -a "$work/a.img" "$work/miyoo355_fw-multiboot.img"
cmp -s "$work/miyoo355_fw.img" "$work/miyoo355_fw-multiboot.img" || fail "multiboot alias differs"
if [ -s "$ROOT/output/images/miyoo355_fw.img" ]; then
	cmp -s "$work/miyoo355_fw.img" "$ROOT/output/images/miyoo355_fw.img" || fail "fresh multiboot image differs from the last built miyoo355_fw.img"
fi

pack() {
	python3 "$ZLYME/pack-fwimg.py" --apommel "$APOMMEL" --mode "$1" --version "$2" "$3"
}
pack maskrom zlyme-maskrom-1 "$work/miyoo355_fw-maskrom.img" >/dev/null
pack maskrom zlyme-maskrom-1 "$work/miyoo355_fw-maskrom-again.img" >/dev/null
cmp -s "$work/miyoo355_fw-maskrom.img" "$work/miyoo355_fw-maskrom-again.img" || fail "maskrom pack is not deterministic"
pack restore zlyme-restore-1 "$work/miyoo355_fw-restore.img" >/dev/null
pack restore zlyme-restore-1 "$work/miyoo355_fw-restore-again.img" >/dev/null
cmp -s "$work/miyoo355_fw-restore.img" "$work/miyoo355_fw-restore-again.img" || fail "restore pack is not deterministic"

for img in miyoo355_fw.img miyoo355_fw-multiboot.img miyoo355_fw-maskrom.img miyoo355_fw-restore.img; do
	[ -s "$work/$img" ] || fail "missing $img"
	(cd "$work" && sha256sum "$img" > "$img.sha256")
	(cd "$work" && sha256sum -c "$img.sha256") >/dev/null || fail "checksum $img"
	python3 - "$work/$img" "$UNIT_RECOVERY" "$UNIT_STOCK" << 'PY' || fail "helper contains a unit image hash"
import pathlib, sys
blob = pathlib.Path(sys.argv[1]).read_bytes()
for needle in sys.argv[2:]:
    if needle.encode() in blob:
        raise SystemExit(1)
PY
done

header() { dd if="$1" bs=512 count=1 2>/dev/null | tr -d '\0'; }
printf '%s' "$(header "$work/miyoo355_fw.img")" | grep -q 'version:baseos-preloader-1' || fail "multiboot version changed"
printf '%s' "$(header "$work/miyoo355_fw-maskrom.img")" | grep -q 'version:zlyme-maskrom-1' || fail "maskrom version"
printf '%s' "$(header "$work/miyoo355_fw-restore.img")" | grep -q 'version:zlyme-restore-1' || fail "restore version"

grep -q '"miyoo355_fw.img"' "$GEN" || fail "genimage dropped the normal installer"
if grep -q 'miyoo355_fw-multiboot.img\|miyoo355_fw-maskrom.img\|miyoo355_fw-restore.img' "$GEN"; then
	fail "genimage contains a standalone helper"
fi
if grep -q 'miyoo355_fw' "$TAR"; then
	fail "OTA packer mentions a firmware helper"
fi
for name in miyoo355_fw-multiboot.img miyoo355_fw-maskrom.img miyoo355_fw-restore.img; do
	grep -q "$name" "$POST" || fail "post-image does not hash $name"
	grep -q "$name" "$ROOT/.github/workflows/build.yml" || fail "release upload omits $name"
	grep -q "$name" "$ROOT/.github/workflows/build-stage.yml" || fail "stage upload omits $name"
done
for tarfile in "$ROOT"/output/images/zlyme-my355-*.tar; do
	[ -e "$tarfile" ] || continue
	if tar -tf "$tarfile" | grep -q 'miyoo355_fw'; then
		fail "OTA archive contains a firmware helper: $tarfile"
	fi
done

python3 - "$STOCK" "$MKPRE" "$PY" "$work/expect-recovery.img" "$work/expect-patched.img" << 'PY'
import importlib.util, pathlib, sys
stock_path, mk_path, py_path, rec_path, patched_path = sys.argv[1:]
spec = importlib.util.spec_from_file_location("mkpreloader", mk_path)
mk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mk)
spec = importlib.util.spec_from_file_location("preloader_image", py_path)
pi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi)
raw = pathlib.Path(stock_path).read_bytes()
patched, _notes = mk.patch(raw)
recovery = pi.derive_bytes(patched)
pathlib.Path(patched_path).write_bytes(patched)
pathlib.Path(rec_path).write_bytes(recovery)
order = pi._boot_order(pi._fdt(pi._paired(recovery)[1][0]["payload"]))[1]
if order != [pi.RIGHT_SLOT]:
    raise SystemExit("recovery order")
PY

extract() {
	dest=$1
	img=$2
	rm -rf "$dest"
	mkdir -p "$dest"
	dd if="$img" bs=512 skip=16 2>/dev/null | tar -x -C "$dest"
	[ -f "$dest/install.sh" ] || fail "payload has no install.sh"
}

prepare_fix() {
	fix=$1
	live=$2
	rm -rf "$fix"
	mkdir -p "$fix/bin" "$fix/card" "$fix/power/ac" "$fix/sys"
	cp "$live" "$fix/mtd"
	cp "$live" "$fix/mtdro"
	sha256sum "$live" | cut -c1-64 > "$fix/live.sha"
	printf 'mtd5: 00200000 00020000 "spl"\n' > "$fix/proc-mtd"
	printf 'spl\n' > "$fix/sys/name"
	printf '2097152\n' > "$fix/sys/size"
	printf '131072\n' > "$fix/sys/erasesize"
	printf '2048\n' > "$fix/sys/writesize"
	printf '64\n' > "$fix/sys/oobsize"
	printf '0\n' > "$fix/sys/bad_blocks"
	echo 80 > "$fix/power/battery"
	echo 0 > "$fix/power/ac/online"
	echo ok > "$fix/write-mode"
	: > "$fix/erases"
	cat > "$fix/bin/flash_erase" << EOF
#!/bin/sh
printf x >> "$fix/erases"
exit 0
EOF
	cat > "$fix/bin/nandwrite" << EOF
#!/bin/sh
src=\$3
mode=\$(cat "$fix/write-mode")
live=\$(cat "$fix/live.sha")
got=\$(sha256sum "\$src" | cut -c1-64)
if [ "\$mode" = fail-both ] || { [ "\$mode" = fail-target ] && [ "\$got" != "\$live" ]; }; then
	dd if=/dev/zero of="$fix/mtd" bs=2048 count=1024 status=none
else
	cp "\$src" "$fix/mtd"
fi
	cp "$fix/mtd" "$fix/mtdro"
exit 0
EOF
	cat > "$fix/bin/reboot" << EOF
#!/bin/sh
echo reboot >> "$fix/reboot.log"
exit 99
EOF
	chmod 755 "$fix/bin/flash_erase" "$fix/bin/nandwrite" "$fix/bin/reboot"
	: > "$fix/reboot.log"
}

run_helper() {
	fix=$1
	payload=$2
	mounts=${3:-/proc/mounts}
	env CARD="$fix/card" MTD="$fix/mtd" PROC_MTD="$fix/proc-mtd" \
		MTD_SYSFS="$fix/sys" \
		BATTERY_CAPACITY="$fix/power/battery" POWER_ROOT="$fix/power" \
		MOUNTS="$mounts" \
		PATH="$fix/bin:$PATH" \
		sh "$payload/install.sh"
}

erases() { wc -c < "$1/erases" | tr -d ' '; }

extract "$work/maskrom-root" "$work/miyoo355_fw-maskrom.img"
extract "$work/restore-root" "$work/miyoo355_fw-restore.img"

# Multiboot behavior stays the pinned installer: the descriptive file is that image.
cmp -s "$work/miyoo355_fw.img" "$work/miyoo355_fw-multiboot.img"
extract "$work/multiboot-root" "$work/miyoo355_fw.img"
cmp -s "$work/multiboot-root/install.sh" "$APOMMEL/install.sh" || fail "multiboot install.sh diverged from pinned apommel"
grep -q '/dev/mmcblk1p\*' "$work/multiboot-root/install.sh" || fail "upstream multiboot reboot condition changed"
grep -q '\<reboot\>' "$work/multiboot-root/install.sh" || fail "upstream multiboot installer no longer reboots"

# MASKROM from an original stock preloader. No prior multiboot backup.
prepare_fix "$work/fix" "$STOCK"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "maskrom from stock rc=$rc $(cat "$work/fix/err") $(cat "$work/fix/card/zlyme-fw.log")"
cmp -s "$work/fix/mtdro" "$work/expect-recovery.img" || fail "maskrom from stock did not derive the recovery image"
stock_sha=$(sha256sum "$STOCK" | cut -c1-64)
cmp -s "$work/fix/card/mtd5-original-$stock_sha.img" "$STOCK" || fail "original backup is not the live stock image"
[ "$(erases "$work/fix")" -ge 1 ] || fail "maskrom from stock did not write"
grep -q 'readback verified' "$work/fix/card/zlyme-fw.log" || fail "maskrom success was not logged"

# Same bytes when the live image is already the repaired preloader and the original backup is present.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "maskrom from repaired rc=$rc $(cat "$work/fix/card/zlyme-fw.log")"
cmp -s "$work/fix/mtdro" "$work/expect-recovery.img" || fail "maskrom from repaired differs"

# Already the recovery image: no erase.
prepare_fix "$work/fix" "$work/expect-recovery.img"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "already-recovery rc=$rc"
[ "$(erases "$work/fix")" -eq 0 ] || fail "already-recovery erased"
cmp -s "$work/fix/mtdro" "$work/expect-recovery.img" || fail "already-recovery changed NAND"
grep -q 'nothing was written' "$work/fix/card/zlyme-fw.log" || fail "already-recovery did not refuse the write"

# Unsupported banner, hashes resealed, copies still identical.
python3 - "$STOCK" "$PY" "$work/bad-banner.img" << 'PY'
import hashlib, importlib.util, pathlib, sys
stock, py_path, out = sys.argv[1:]
spec = importlib.util.spec_from_file_location("preloader_image", py_path)
pi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi)
raw = bytearray(pathlib.Path(stock).read_bytes())
found = pi._parse(bytes(raw))
spl = [item for item in found if item["index"] == 1]
payload = bytearray(spl[0]["payload"])
at = payload.find(pi.SPL_BANNER.encode())
if at < 0:
    raise SystemExit("banner missing")
payload[at + 10] ^= 0x01
digest = hashlib.sha256(payload).digest()
for item in spl:
    raw[item["start"]:item["start"] + len(payload)] = payload
    raw[item["entry"] + 0x18:item["entry"] + 0x38] = digest
pathlib.Path(out).write_bytes(raw)
PY
prepare_fix "$work/fix" "$work/bad-banner.img"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "bad banner was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "bad banner erased"
grep -q 'Nov 02 2024' "$work/fix/card/zlyme-fw.log" || fail "bad banner did not name the SPL check"
cmp -s "$work/fix/mtdro" "$work/bad-banner.img" || fail "bad banner changed NAND"

# Malformed magic.
python3 - "$STOCK" "$work/bad-magic.img" << 'PY'
import pathlib, sys
raw = bytearray(pathlib.Path(sys.argv[1]).read_bytes())
raw[131072:131076] = b"XXXX"
pathlib.Path(sys.argv[2]).write_bytes(raw)
PY
prepare_fix "$work/fix" "$work/bad-magic.img"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "bad magic was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "bad magic erased"

# Internally valid but disagreeing SPL copies.
python3 - "$work/expect-patched.img" "$PY" "$work/mismatch.img" << 'PY'
import hashlib, importlib.util, pathlib, sys
src, py_path, out = sys.argv[1:]
spec = importlib.util.spec_from_file_location("preloader_image", py_path)
pi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi)
raw = bytearray(pathlib.Path(src).read_bytes())
found = pi._parse(bytes(raw))
spl = [item for item in found if item["index"] == 1]
payload = bytearray(spl[1]["payload"])
payload[80] ^= 0x5A
digest = hashlib.sha256(payload).digest()
item = spl[1]
raw[item["start"]:item["start"] + len(payload)] = payload
raw[item["entry"] + 0x18:item["entry"] + 0x38] = digest
pathlib.Path(out).write_bytes(raw)
PY
prepare_fix "$work/fix" "$work/mismatch.img"
set +e
run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "mismatched copies were accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "mismatched copies erased"
grep -q 'SPL copies disagree' "$work/fix/card/zlyme-fw.log" || fail "mismatch did not name the copy check"

# No image argument.
prepare_fix "$work/fix" "$STOCK"
set +e
env CARD="$work/fix/card" MTD="$work/fix/mtd" PROC_MTD="$work/fix/proc-mtd" \
	BATTERY_CAPACITY="$work/fix/power/battery" POWER_ROOT="$work/fix/power" \
	PATH="$work/fix/bin:$PATH" \
	sh "$work/maskrom-root/install.sh" /tmp/not-an-image >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "maskrom accepted an image argument"
[ "$(erases "$work/fix")" -eq 0 ] || fail "image argument erased"

# RESTORE the per-device original from a repaired preloader.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "restore from repaired rc=$rc $(cat "$work/fix/card/zlyme-fw.log")"
cmp -s "$work/fix/mtdro" "$STOCK" || fail "restore did not write the saved original"
grep -q "saved original preloader is installed" "$work/fix/card/zlyme-fw.log" || fail "restore success text"

# RESTORE from the recovery derivative.
prepare_fix "$work/fix" "$work/expect-recovery.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "restore from recovery rc=$rc $(cat "$work/fix/card/zlyme-fw.log")"
cmp -s "$work/fix/mtdro" "$STOCK" || fail "restore from recovery did not write the original"

# Filename hash mismatch.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "hash mismatch was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "hash mismatch erased"
grep -q 'does not match its name' "$work/fix/card/zlyme-fw.log" || fail "hash mismatch text"

# Two originals.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
other=$(sha256sum "$work/expect-patched.img" | cut -c1-64)
cp "$work/expect-patched.img" "$work/fix/card/mtd5-original-$other.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "two originals were accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "two originals erased"
grep -q 'more than one' "$work/fix/card/zlyme-fw.log" || fail "two originals text"

# Hash matches, structure does not.
python3 - "$work/garbage.img" << 'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(bytes([7]) * 2097152)
PY
garbage_sha=$(python3 -c 'import hashlib,pathlib,sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$work/garbage.img")
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$work/garbage.img" "$work/fix/card/mtd5-original-$garbage_sha.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "garbage backup was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "garbage backup erased"

# DDR mismatch before erase.
python3 - "$STOCK" "$PY" "$work/other-ddr.img" << 'PY'
import hashlib, importlib.util, pathlib, sys
src, py_path, out = sys.argv[1:]
spec = importlib.util.spec_from_file_location("preloader_image", py_path)
pi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi)
raw = bytearray(pathlib.Path(src).read_bytes())
found = pi._parse(bytes(raw))
ddr = [item for item in found if item["index"] == 0]
payload = bytearray(ddr[0]["payload"])
payload[32] ^= 0x11
digest = hashlib.sha256(payload).digest()
for item in ddr:
    raw[item["start"]:item["start"] + len(payload)] = payload
    raw[item["entry"] + 0x18:item["entry"] + 0x38] = digest
pathlib.Path(out).write_bytes(raw)
PY
other_sha=$(sha256sum "$work/other-ddr.img" | cut -c1-64)
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$work/other-ddr.img" "$work/fix/card/mtd5-original-$other_sha.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "DDR mismatch was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "DDR mismatch erased"
grep -q 'DDR' "$work/fix/card/zlyme-fw.log" || fail "DDR mismatch text"
cmp -s "$work/fix/mtdro" "$work/expect-patched.img" || fail "DDR mismatch changed NAND"

# No backup.
prepare_fix "$work/fix" "$work/expect-patched.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "missing backup was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "missing backup erased"
grep -q 'no mtd5-original' "$work/fix/card/zlyme-fw.log" || fail "missing backup text"

# A current-image backup cannot masquerade as the original.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/preloader-current-$stock_sha.img"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "preloader-current was accepted as an original"
[ "$(erases "$work/fix")" -eq 0 ] || fail "preloader-current erased"

# Target write fails, rollback restores the previous image.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
echo fail-target > "$work/fix/write-mode"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "failed write reported success"
grep -q 'previous preloader was restored' "$work/fix/card/zlyme-fw.log" || fail "rollback text"
grep -q 'saved original preloader is installed' "$work/fix/card/zlyme-fw.log" && fail "failed write claimed restore"
cmp -s "$work/fix/mtdro" "$work/expect-patched.img" || fail "rollback did not restore the previous image"

# Target and rollback both fail.
prepare_fix "$work/fix" "$work/expect-patched.img"
cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
echo fail-both > "$work/fix/write-mode"
set +e
run_helper "$work/fix" "$work/restore-root" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "double failure reported success"
grep -q 'CRITICAL:' "$work/fix/card/zlyme-fw.log" || fail "critical text"
grep -q 'previous preloader was restored' "$work/fix/card/zlyme-fw.log" && fail "double failure claimed rollback"
cmp -s "$work/fix/mtdro" "$work/expect-patched.img" && fail "double failure left the previous image in place"
cmp -s "$work/fix/mtdro" "$STOCK" && fail "double failure left the target in place"

# Second RKNS copy stays hash-valid, but one entry's sector count differs.
# The first-copy window of that payload still matches, which is the compare
# the old checker used. The new checker must refuse on geometry instead.
skew_geometry() {
	python3 - "$1" "$2" "$3" << 'PY'
import hashlib, pathlib, sys
src, dest, which = sys.argv[1:]
img = bytearray(pathlib.Path(src).read_bytes())
index = 0 if which == "ddr" else 1
base = 524288
entry = base + 0x78 + index * 0x58
off = int.from_bytes(img[entry:entry + 2], "little")
cnt = int.from_bytes(img[entry + 2:entry + 4], "little") + 1
img[entry + 2:entry + 4] = cnt.to_bytes(2, "little")
start = base + off * 512
digest = hashlib.sha256(img[start:start + cnt * 512]).digest()
img[entry + 0x18:entry + 0x38] = digest

def read_entry(copy, slot):
    at = copy + 0x78 + slot * 0x58
    o = int.from_bytes(img[at:at + 2], "little")
    c = int.from_bytes(img[at + 2:at + 4], "little")
    blob = bytes(img[copy + o * 512:copy + (o + c) * 512])
    if hashlib.sha256(blob).digest() != bytes(img[at + 0x18:at + 0x38]):
        raise SystemExit("resealed entry hash does not match")
    return o, c, blob

left = read_entry(131072, index)
right = read_entry(524288, index)
if (left[0], left[1]) == (right[0], right[1]):
    raise SystemExit("fixture geometry still agrees")
if right[2][:len(left[2])] != left[2]:
    raise SystemExit("first-copy window changed; this is not a geometry-only fixture")
for copy in (131072, 524288):
    for slot in (0, 1):
        read_entry(copy, slot)
pathlib.Path(dest).write_bytes(img)
PY
}

for which in spl ddr; do
	skew_geometry "$STOCK" "$work/skew-$which.img" "$which"
	prepare_fix "$work/fix" "$work/skew-$which.img"
	set +e
	run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
	rc=$?
	set -e
	[ "$rc" -ne 0 ] || fail "$which geometry mismatch was accepted"
	[ "$(erases "$work/fix")" -eq 0 ] || fail "$which geometry mismatch erased"
	grep -q 'IDB copies disagree on entry geometry' "$work/fix/card/zlyme-fw.log" || fail "$which geometry text"
	set +e
	sh "$ZLYME/apply-boot-order.sh" "$work/skew-$which.img" "$work/fix/out.img" >"$work/fix/apply.out" 2>"$work/fix/apply.err"
	rc=$?
	set -e
	[ "$rc" -ne 0 ] || fail "apply-boot-order accepted $which geometry mismatch"
	grep -q 'IDB copies disagree on entry geometry' "$work/fix/apply.err" || fail "apply-boot-order $which geometry text"
	[ ! -e "$work/fix/out.img" ] || fail "apply-boot-order wrote despite $which geometry mismatch"
done

# Wrong MTD geometry and bad blocks refuse before erase.
for attr in size erasesize bad_blocks; do
	prepare_fix "$work/fix" "$STOCK"
	case "$attr" in
		size) printf '1\n' > "$work/fix/sys/size"; text='mtd5 size is not 2097152' ;;
		erasesize) printf '1\n' > "$work/fix/sys/erasesize"; text='mtd5 erasesize is not 131072' ;;
		bad_blocks) printf '1\n' > "$work/fix/sys/bad_blocks"; text='mtd5 has bad blocks' ;;
	esac
	set +e
	run_helper "$work/fix" "$work/maskrom-root" >"$work/fix/out" 2>"$work/fix/err"
	rc=$?
	set -e
	[ "$rc" -ne 0 ] || fail "$attr was accepted"
	[ "$(erases "$work/fix")" -eq 0 ] || fail "$attr erased"
	grep -q "$text" "$work/fix/card/zlyme-fw.log" || fail "$attr text"
done

# A missing nandwrite refuses through finish, before any erase.
prepare_fix "$work/fix" "$STOCK"
mkdir -p "$work/path"
IFS=:
for dir in $PATH; do
	[ -d "$dir" ] || continue
	for cmd in "$dir"/*; do
		[ -x "$cmd" ] || continue
		base=$(basename "$cmd")
		[ "$base" = "nandwrite" ] && continue
		[ -e "$work/path/$base" ] && continue
		ln -s "$cmd" "$work/path/$base"
	done
done
unset IFS
ln -sf "$work/fix/bin/flash_erase" "$work/path/flash_erase"
rm -f "$work/path/nandwrite" /tmp/fwupdate_done
set +e
env CARD="$work/fix/card" MTD="$work/fix/mtd" PROC_MTD="$work/fix/proc-mtd" \
	MTD_SYSFS="$work/fix/sys" \
	BATTERY_CAPACITY="$work/fix/power/battery" POWER_ROOT="$work/fix/power" \
	PATH="$work/path" \
	sh "$work/maskrom-root/install.sh" >"$work/fix/out" 2>"$work/fix/err"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "missing nandwrite was accepted"
[ "$(erases "$work/fix")" -eq 0 ] || fail "missing nandwrite erased"
grep -q 'required command is missing: nandwrite' "$work/fix/card/zlyme-fw.log" || fail "missing nandwrite text"
[ "$(cat /tmp/fwupdate_done 2>/dev/null)" = "1" ] || fail "missing nandwrite did not signal fwupdate_done"
rm -f /tmp/fwupdate_done

# A verified write must not reboot, whatever stock called the card.
if [ -e /dev/mmcblk0 ] || [ -e /dev/mmcblk1 ] || [ -e /dev/mmcblk2 ]; then
	fail "host has mmcblk nodes; refusing to exercise the slot fixture against them"
fi
for node in /dev/mmcblk0p1 /dev/mmcblk1p1 /dev/mmcblk2p1; do
	prepare_fix "$work/fix" "$work/expect-patched.img"
	cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
	printf 'marker\n' > "$work/fix/card/miyoo355_fw.img"
	card_real=$(CDPATH='' cd -- "$work/fix/card" && pwd -P)
	printf '%s\n' "$node $card_real vfat rw 0 0" > "$work/fix/mounts"
	rm -f /tmp/fwupdate_done
	set +e
	run_helper "$work/fix" "$work/maskrom-root" "$work/fix/mounts" >"$work/fix/out" 2>"$work/fix/err"
	rc=$?
	set -e
	[ "$rc" -eq 0 ] || fail "maskrom on $node rc=$rc $(cat "$work/fix/card/zlyme-fw.log")"
	cmp -s "$work/fix/mtdro" "$work/expect-recovery.img" || fail "maskrom on $node did not verify the recovery image"
	[ ! -e "$work/fix/card/miyoo355_fw.img" ] || fail "maskrom on $node left miyoo355_fw.img"
	grep -q 'readback verified' "$work/fix/card/zlyme-fw.log" || fail "maskrom on $node did not verify"
	grep -q 'removed miyoo355_fw.img from the card' "$work/fix/card/zlyme-fw.log" || fail "maskrom on $node did not remove the helper"
	grep -q 'recovery preloader installed; power the device off before changing cards' "$work/fix/card/zlyme-fw.log" || fail "maskrom on $node completion text"
	grep -q 'rebooting' "$work/fix/card/zlyme-fw.log" && fail "maskrom on $node logged a reboot"
	[ ! -s "$work/fix/reboot.log" ] || fail "maskrom on $node called reboot"
	[ "$(cat /tmp/fwupdate_done 2>/dev/null)" = "1" ] || fail "maskrom on $node did not signal completion"

	prepare_fix "$work/fix" "$work/expect-patched.img"
	cp "$STOCK" "$work/fix/card/mtd5-original-$stock_sha.img"
	printf 'marker\n' > "$work/fix/card/miyoo355_fw.img"
	card_real=$(CDPATH='' cd -- "$work/fix/card" && pwd -P)
	printf '%s\n' "$node $card_real vfat rw 0 0" > "$work/fix/mounts"
	rm -f /tmp/fwupdate_done
	set +e
	run_helper "$work/fix" "$work/restore-root" "$work/fix/mounts" >"$work/fix/out" 2>"$work/fix/err"
	rc=$?
	set -e
	[ "$rc" -eq 0 ] || fail "restore on $node rc=$rc $(cat "$work/fix/card/zlyme-fw.log")"
	cmp -s "$work/fix/mtdro" "$STOCK" || fail "restore on $node did not verify the original"
	[ ! -e "$work/fix/card/miyoo355_fw.img" ] || fail "restore on $node left miyoo355_fw.img"
	grep -q 'readback verified' "$work/fix/card/zlyme-fw.log" || fail "restore on $node did not verify"
	grep -q 'removed miyoo355_fw.img from the card' "$work/fix/card/zlyme-fw.log" || fail "restore on $node did not remove the helper"
	grep -q 'original preloader restored; power the device off before changing cards' "$work/fix/card/zlyme-fw.log" || fail "restore on $node completion text"
	grep -q 'rebooting' "$work/fix/card/zlyme-fw.log" && fail "restore on $node logged a reboot"
	[ ! -s "$work/fix/reboot.log" ] || fail "restore on $node called reboot"
	[ "$(cat /tmp/fwupdate_done 2>/dev/null)" = "1" ] || fail "restore on $node did not signal completion"
done
rm -f /tmp/fwupdate_done

echo "fw-helpers: ok"
