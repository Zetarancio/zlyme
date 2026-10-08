#!/bin/sh
# Phase 11C: installer image, preloader gates, and apommel patcher parity.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PRE=$ROOT/package/system/zlyme-preloader/zlyme-preloader
PY=$ROOT/package/system/zlyme-preloader/preloader_image.py
GEN=$ROOT/board/my355/genimage.cfg
POST=$ROOT/board/my355/post-image.sh
TAR=$ROOT/board/my355/make-update-tar.sh
DEF=$ROOT/configs/zlyme_my355_defconfig
fail() { echo "phase11c: $*" >&2; exit 1; }

[ -x "$PRE" ] || fail "backend is not executable"
grep -q 'miyoo355_fw.img' "$GEN" || fail "genimage does not list the installer"
grep -q 'miyoo355_fw.img' "$POST" || fail "post-image does not require the installer"
if grep -q 'miyoo355_fw.img' "$TAR"; then
	fail "OTA packer must not ship the installer"
fi
grep -q 'BR2_PACKAGE_MY355_FW_INSTALLER=y' "$DEF" || fail "installer package is off"
grep -q 'BR2_PACKAGE_ZLYME_PRELOADER=y' "$DEF" || fail "recovery package is off"
grep -q 'BR2_PACKAGE_MTD_FLASH_ERASE=y' "$DEF" || fail "flash_erase is off"
grep -q 'BR2_PACKAGE_MTD_NANDWRITE=y' "$DEF" || fail "nandwrite is off"
grep -q 'BR2_PACKAGE_MTD_MTDINFO=y' "$DEF" || fail "mtdinfo is off"
grep -q '# BR2_PACKAGE_MTD_NANDDUMP is not set' "$DEF" || fail "nanddump is not disabled"
if [ -e "$ROOT/package/system/nextui/paks/Tools/Preloader Recovery.pak" ]; then
	fail "Preloader Recovery pak is still in the tree"
fi
grep -q 'erase-preloader) cmd_erase' "$PRE" || fail "erase-preloader missing"
if grep -q 'erase-maskrom' "$PRE"; then
	fail "erase-maskrom name remains"
fi
grep -q 'a bootable SD idbloader can start instead of USB MASKROM' "$PRE" || fail "erase does not explain SD boot"
if grep -q 'expected to enter MASKROM' "$PRE"; then
	fail "erase still claims MASKROM"
fi

# --- installer bytes, when the pinned tree is available ---
tree=${ZLYME_APOMMEL_TREE:-}
if [ -z "$tree" ] && [ -d /tmp/apommel-tree ]; then
	tree=$(echo /tmp/apommel-tree/baseos-my355-e09d37bb0f03c34e564d61bd02164f332d8515a8)
fi
if [ -n "$tree" ] && [ -f "$tree/tools/preloader-installer/mkfwimg.py" ]; then
	a=$(mktemp)
	b=$(mktemp)
	python3 "$tree/tools/preloader-installer/mkfwimg.py" "$a" >/dev/null
	python3 "$tree/tools/preloader-installer/mkfwimg.py" "$b" >/dev/null
	ha=$(sha256sum "$a" | awk '{print $1}')
	hb=$(sha256sum "$b" | awk '{print $1}')
	[ "$ha" = "$hb" ] || fail "installer generations differ"
	[ "$(wc -c < "$a" | tr -d ' ')" = "28672" ] || fail "installer size"
	python3 - "$a" <<'PY'
import sys
p=open(sys.argv[1],"rb").read()
head=p.split(b"\n", 2)
assert head[0]==b"model:miyoo355", head[0]
assert head[1]==b"version:baseos-preloader-1", head[1]
PY
	[ "$ha" = "39f8705c42c21a5d6af6b8133138e05e7fe26b46a4693e8c6ce65ba60dee6800" ] || fail "unexpected installer hash $ha"
	if command -v xxd >/dev/null 2>&1 && [ -f "$tree/tests/make_preloader_fixture.py" ]; then
		work=$(mktemp -d)
		python3 "$tree/tests/make_preloader_fixture.py" "$work/fixture.img"
		python3 "$tree/tools/mkpreloader.py" "$work/fixture.img" "$work/py.img" >/dev/null
		PATCHED=$work/py.img
		AWK_SCRIPT="$tree/tools/preloader-installer/fdtpatch.awk" \
			sh "$tree/tools/preloader-installer/patch-preloader.sh" \
			"$work/fixture.img" "$work/sh.img" >/dev/null
		cmp "$work/py.img" "$work/sh.img" || fail "patchers disagree"
		if python3 "$tree/tools/mkpreloader.py" "$work/sh.img" "$work/again.img" >/dev/null 2>&1; then
			fail "python patcher accepted an already-patched image"
		fi
		if AWK_SCRIPT="$tree/tools/preloader-installer/fdtpatch.awk" \
			sh "$tree/tools/preloader-installer/patch-preloader.sh" \
			"$work/sh.img" "$work/again.img" >/dev/null 2>&1; then
			fail "shell patcher accepted an already-patched image"
		fi
		cp "$work/fixture.img" "$work/bad.img"
		printf '\xde\xad' | dd of="$work/bad.img" bs=1 seek=140000 conv=notrunc status=none
		if python3 "$tree/tools/mkpreloader.py" "$work/bad.img" "$work/nope.img" >/dev/null 2>&1; then
			fail "python patcher accepted a corrupt image"
		fi
		if AWK_SCRIPT="$tree/tools/preloader-installer/fdtpatch.awk" \
			sh "$tree/tools/preloader-installer/patch-preloader.sh" \
			"$work/bad.img" "$work/nope.img" >/dev/null 2>&1; then
			fail "shell patcher accepted a corrupt image"
		fi
		GOOD=$work/fixture.img
		[ -f "$PATCHED" ] || fail "patched fixture missing"
		rm -rf "$work/sh.img" "$work/again.img" "$work/nope.img" "$work/bad.img"
	else
		fail "xxd or the apommel fixture generator is missing"
	fi
else
	fail "pinned apommel tree is not available"
fi

# --- fixture runner ---
BIN=$(mktemp -d)
cat > "$BIN/flash_erase" <<'EOF'
#!/bin/sh
root=${ZLYME_PRELOADER_ROOT:?}
printf 'flash_erase %s\n' "$*" >> "$root/actions.log"
n=0
[ -f "$root/erase-n" ] && n=$(cat "$root/erase-n")
n=$((n + 1))
printf '%s\n' "$n" > "$root/erase-n"
limit=0
[ -f "$root/fail-erase-first" ] && limit=$(cat "$root/fail-erase-first")
[ "$n" -le "$limit" ] && exit 1
exit 0
EOF
cat > "$BIN/nandwrite" <<'EOF'
#!/bin/sh
root=${ZLYME_PRELOADER_ROOT:?}
printf 'nandwrite %s\n' "$*" >> "$root/actions.log"
n=0
[ -f "$root/nand-n" ] && n=$(cat "$root/nand-n")
n=$((n + 1))
printf '%s\n' "$n" > "$root/nand-n"
limit=0
[ -f "$root/fail-nandwrite-first" ] && limit=$(cat "$root/fail-nandwrite-first")
[ "$n" -le "$limit" ] && exit 1
img=
for a in "$@"; do
	img=$a
done
cp "$img" "$root/live/preloader.img"
r=0
[ -f "$root/read-n" ] && r=$(cat "$root/read-n")
r=$((r + 1))
printf '%s\n' "$r" > "$root/read-n"
rlimit=0
[ -f "$root/fail-readback-first" ] && rlimit=$(cat "$root/fail-readback-first")
if [ "$r" -le "$rlimit" ]; then
	python3 - "$root/live/preloader.img" <<'PY'
import sys
f=open(sys.argv[1],"r+b")
f.seek(0)
b=f.read(1)
f.seek(0)
f.write(bytes([(b[0] ^ 0xff)]))
PY
fi
exit 0
EOF
cat > "$BIN/mtdinfo" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$BIN/dd" <<'EOF'
#!/bin/sh
echo "real dd must not run in a fixture" >&2
exit 99
EOF
chmod 0755 "$BIN"/*

new_fix() {
	fix=$(mktemp -d)
	mkdir -p "$fix/usr/share/zlyme" "$fix/proc/device-tree" \
		"$fix/sys/class/mtd/mtd0" "$fix/sys/class/power_supply/battery" \
		"$fix/sys/class/power_supply/ac" "$fix/boot" "$fix/live" \
		"$fix/storage/.config/zlyme/preloader-backups"
	printf '%s\n' 'ZLYME_DEVICE_ID=my355' > "$fix/usr/share/zlyme/device.conf"
	printf 'Miyoo Flip' > "$fix/proc/device-tree/model"
	printf 'miyoo,flip\0rockchip,rk3566\0' > "$fix/proc/device-tree/compatible"
	printf '%s\n' 'dev:    size   erasesize  name' > "$fix/proc/mtd"
	printf '%s\n' 'mtd0: 00200000 00020000 "preloader"' >> "$fix/proc/mtd"
	printf 'preloader' > "$fix/sys/class/mtd/mtd0/name"
	printf 'nand' > "$fix/sys/class/mtd/mtd0/type"
	printf '2097152' > "$fix/sys/class/mtd/mtd0/size"
	printf '131072' > "$fix/sys/class/mtd/mtd0/erasesize"
	printf '2048' > "$fix/sys/class/mtd/mtd0/writesize"
	printf '64' > "$fix/sys/class/mtd/mtd0/oobsize"
	printf '0' > "$fix/sys/class/mtd/mtd0/bad_blocks"
	printf '80' > "$fix/sys/class/power_supply/battery/capacity"
	printf '0' > "$fix/sys/class/power_supply/battery/online"
	printf '0' > "$fix/sys/class/power_supply/ac/online"
	cp "$PATCHED" "$fix/live/preloader.img"
	sum=$(sha256sum "$GOOD" | awk '{print $1}')
	cp "$GOOD" "$fix/boot/mtd5-original-$sum.img"
	: > "$fix/actions.log"
	printf '%s\n' "$fix"
}

run() {
	fix=$1
	shift
	set +e
	ZLYME_PRELOADER_TEST=1 \
	ZLYME_PRELOADER_ROOT="$fix" \
	ZLYME_PRELOADER_IMAGE_PY="$PY" \
	PATH="$BIN:$PATH" \
		"$PRE" "$@" >"$fix/out" 2>"$fix/err"
	rc=$?
	set -e
	printf '%s\n' "$rc"
}

# Optional SHA and path overrides. Empty values leave the production pins.
run_fb() {
	fix=$1
	cmd=$2
	stock_sha=${3:-}
	patched_sha=${4:-}
	stock_file=${5:-}
	set +e
	ZLYME_PRELOADER_TEST=1 \
	ZLYME_PRELOADER_ROOT="$fix" \
	ZLYME_PRELOADER_IMAGE_PY="$PY" \
	ZLYME_PRELOADER_STOCK_SHA="$stock_sha" \
	ZLYME_PRELOADER_PATCHED_SHA="$patched_sha" \
	ZLYME_PRELOADER_STOCK="$stock_file" \
	PATH="$BIN:$PATH" \
		"$PRE" "$cmd" >"$fix/out" 2>"$fix/err"
	rc=$?
	set -e
	printf '%s\n' "$rc"
}

no_cmd() {
	fix=$1
	if grep -q '^flash_erase \|^nandwrite ' "$fix/actions.log"; then
		fail "$2 ran a destructive command"
	fi
}

base=$(new_fix)
rc=$(run "$base" status)
[ "$rc" = "0" ] || fail "status rc=$rc $(cat "$base/err")"
no_cmd "$base" status

rc=$(run "$base" status-machine)
[ "$rc" = "0" ] || fail "status-machine rc=$rc $(cat "$base/err")"
grep -q '^preloader=valid$' "$base/out" || fail "status-machine preloader $(cat "$base/out")"
grep -q '^backup=available$' "$base/out" || fail "status-machine backup $(cat "$base/out")"
grep -q '^battery=80$' "$base/out" || fail "status-machine battery $(cat "$base/out")"
grep -q '^charger=off$' "$base/out" || fail "status-machine charger $(cat "$base/out")"
if grep -q '^error=' "$base/out"; then
	fail "status-machine reported an error $(cat "$base/out")"
fi
if grep -q '^fallback=' "$base/out"; then
	fail "status-machine named a fallback while a backup exists $(cat "$base/out")"
fi
if grep -q 'zlyme-preloader:' "$base/out"; then
	fail "status-machine leaked a human log line"
fi
no_cmd "$base" status-machine

fix=$(new_fix)
printf '10' > "$fix/sys/class/power_supply/battery/capacity"
printf '0' > "$fix/sys/class/power_supply/ac/online"
rc=$(run "$fix" status-machine)
[ "$rc" != "0" ] || fail "low battery status-machine was accepted"
grep -q '^error=battery 10% and no charger$' "$fix/out" || fail "status-machine error $(cat "$fix/out")"
no_cmd "$fix" "low battery status-machine"

# wrong platform
fix=$(new_fix)
printf '%s\n' 'ZLYME_DEVICE_ID=other' > "$fix/usr/share/zlyme/device.conf"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong platform was accepted"
no_cmd "$fix" "wrong platform"

fix=$(new_fix)
printf 'Other' > "$fix/proc/device-tree/model"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong model was accepted"
no_cmd "$fix" "wrong model"

fix=$(new_fix)
printf '%s\n' 'dev:    size   erasesize  name' > "$fix/proc/mtd"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "missing partition was accepted"
no_cmd "$fix" "missing partition"

fix=$(new_fix)
printf '%s\n' 'dev:    size   erasesize  name' > "$fix/proc/mtd"
printf '%s\n' 'mtd5: 00200000 00020000 "spl"' >> "$fix/proc/mtd"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "spl/mtd5 was accepted"
no_cmd "$fix" "spl not mtd0"

fix=$(new_fix)
printf '1048576' > "$fix/sys/class/mtd/mtd0/size"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong size was accepted"
no_cmd "$fix" "wrong size"

fix=$(new_fix)
printf '65536' > "$fix/sys/class/mtd/mtd0/erasesize"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong geometry was accepted"
no_cmd "$fix" "wrong geometry"

fix=$(new_fix)
printf '1' > "$fix/sys/class/mtd/mtd0/bad_blocks"
rc=$(run "$fix" erase-preloader)
[ "$rc" != "0" ] || fail "bad blocks were accepted"
no_cmd "$fix" "bad blocks"

fix=$(new_fix)
printf '10' > "$fix/sys/class/power_supply/battery/capacity"
printf '0' > "$fix/sys/class/power_supply/ac/online"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "low battery was accepted"
no_cmd "$fix" "low battery"

fix=$(new_fix)
printf '10' > "$fix/sys/class/power_supply/battery/capacity"
printf '1' > "$fix/sys/class/power_supply/ac/online"
rc=$(run "$fix" status)
[ "$rc" = "0" ] || fail "charger did not allow low battery"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "missing backup was accepted"
grep -q 'does not exactly match this preloader revision' "$fix/err" || fail "missing backup refusal $(cat "$fix/err")"
grep -q 'Restore refused' "$fix/err" || fail "missing backup did not refuse"
no_cmd "$fix" "missing backup"

fix=$(new_fix)
sum=$(sha256sum "$GOOD" | awk '{print $1}')
cp "$GOOD" "$fix/boot/mtd5-original-$sum.img"
cp "$GOOD" "$fix/boot/mtd5-original-${sum}.img.bak" 2>/dev/null || true
# second distinct name that still matches the glob and exists
cp "$GOOD" "$fix/boot/mtd5-original-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.img"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "ambiguous backups were accepted"
grep -q 'more than one original preloader backup' "$fix/err" || fail "ambiguous backup fell through $(cat "$fix/err")"
no_cmd "$fix" "ambiguous backups"

fix=$(new_fix)
sum=$(sha256sum "$GOOD" | awk '{print $1}')
cp "$GOOD" "$fix/boot/mtd5-original-${sum%?}0.img"
rm -f "$fix"/boot/mtd5-original-"$sum".img
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong filename hash was accepted"
no_cmd "$fix" "filename hash"

fix=$(new_fix)
sum=$(sha256sum "$GOOD" | awk '{print $1}')
dd if=/dev/zero of="$fix/boot/mtd5-original-$sum.img" bs=2097152 count=1 status=none
# filename hash will not match zeros; also size is wrong if we truncate
rm -f "$fix"/boot/mtd5-original-"$sum".img
printf 'short' > "$fix/boot/mtd5-original-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.img"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "short backup was accepted"
no_cmd "$fix" "short backup"

fix=$(new_fix)
# corrupt the only backup's payload but keep the name hash wrong on purpose
sum=$(sha256sum "$GOOD" | awk '{print $1}')
cp "$GOOD" "$fix/boot/wrong-name.img"
rm -f "$fix"/boot/mtd5-original-*.img
cp "$GOOD" "$fix/boot/mtd5-original-$sum.img"
printf '\x00\x00' | dd of="$fix/boot/mtd5-original-$sum.img" bs=1 seek=140000 conv=notrunc status=none
# hash no longer matches the name, which is the first refusal
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "corrupt backup was accepted"
no_cmd "$fix" "corrupt backup"

fix=$(new_fix)
rm -rf "$fix/storage"
printf 'not-a-directory' > "$fix/storage"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "backup write failure was accepted"
no_cmd "$fix" "current backup failure"

fix=$(new_fix)
printf '\x00' | dd of="$fix/live/preloader.img" bs=1 seek=140000 conv=notrunc status=none
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "corrupt current preloader was accepted"
no_cmd "$fix" "corrupt current"
grep -q '^CURRENT_BACKUP ' "$fix/actions.log" && fail "corrupt current was treated as a ready backup"
rc=$(run "$fix" erase-preloader)
[ "$rc" != "0" ] || fail "corrupt current was accepted for erase"
no_cmd "$fix" "corrupt current erase"

fix=$(new_fix)
other=$fix/other.img
python3 - "$GOOD" "$other" <<'PY'
import hashlib, struct, sys
src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())
for base in (131072, 524288):
    entry = base + 0x78
    off, count = struct.unpack_from("<HH", data, entry)
    start = base + off * 512
    length = count * 512
    data[start] ^= 0x5A
    data[entry + 0x18:entry + 0x38] = hashlib.sha256(data[start:start + length]).digest()
open(dst, "wb").write(data)
PY
sum=$(sha256sum "$other" | awk '{print $1}')
rm -f "$fix"/boot/mtd5-original-*.img
cp "$other" "$fix/boot/mtd5-original-$sum.img"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "DDR mismatch was accepted"
no_cmd "$fix" "DDR mismatch"
grep -q 'DDR payload' "$fix/err" || fail "DDR mismatch did not say why"

# First N flash_erase/nandwrite/readback operations fail, then succeed.
# Three target attempts, then rollback.
rollback_used_current() {
	fix=$1
	cur=$(awk '/^CURRENT_BACKUP / { print $2; exit }' "$fix/actions.log")
	[ -n "$cur" ] && [ -f "$cur" ] || fail "$2 lost the current backup"
	awk -v cur="$cur" '
		/^ROLLBACK$/ { r=1; next }
		r && /^nandwrite / {
			n++
			if (index($0, cur) == 0) bad=1
			if (index($0, "mtd5-original-") > 0) bad=1
		}
		END { exit !(r && n && !bad) }
	' "$fix/actions.log" || fail "$2 rollback did not write the current backup"
	live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
	want=$(sha256sum "$cur" | awk '{print $1}')
	orig=$(sha256sum "$GOOD" | awk '{print $1}')
	[ "$live" = "$want" ] || fail "$2 live image is not the pre-operation backup"
	[ "$live" != "$orig" ] || fail "$2 rollback wrote the stock candidate"
	grep -q '^READBACK target ok$' "$fix/actions.log" && fail "$2 claimed the stock restore"
	grep -q 'previous preloader restored and verified' "$fix/err" || fail "$2 missing rollback message"
	awk '
		/^GATES / { g=NR }
		/^CURRENT_BACKUP / { c=NR }
		/^flash_erase / { if (!e) e=NR }
		/^ROLLBACK$/ { r=NR }
		/^ROLLBACK_READBACK ok$/ { b=NR }
		END { exit !(g && c && e && r && b && g < c && c < e && e < r && r < b) }
	' "$fix/actions.log" || fail "$2 command order"
}

fix=$(new_fix)
printf '3\n' > "$fix/fail-erase-first"
rc=$(run "$fix" restore)
[ "$rc" = "3" ] || fail "erase failure rc=$rc $(cat "$fix/err")"
rollback_used_current "$fix" "erase failure"
awk '/^ROLLBACK$/ { exit } /^nandwrite / { bad=1 } END { exit bad }' "$fix/actions.log" \
	|| fail "nandwrite ran on a failed target erase"

fix=$(new_fix)
printf '3\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" restore)
[ "$rc" = "3" ] || fail "nandwrite failure rc=$rc $(cat "$fix/err")"
rollback_used_current "$fix" "nandwrite failure"
grep -q '^READBACK target ok$' "$fix/actions.log" && fail "nandwrite failure claimed target readback"

fix=$(new_fix)
printf '3\n' > "$fix/fail-readback-first"
rc=$(run "$fix" restore)
[ "$rc" = "3" ] || fail "readback mismatch rc=$rc $(cat "$fix/err")"
rollback_used_current "$fix" "readback mismatch"

fix=$(new_fix)
printf '6\n' > "$fix/fail-erase-first"
rc=$(run "$fix" restore)
[ "$rc" = "1" ] || fail "rollback erase failure rc=$rc"
grep -q '^ROLLBACK$' "$fix/actions.log" || fail "rollback erase case did not roll back"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" && fail "rollback erase claimed success"
grep -q '^nandwrite ' "$fix/actions.log" && fail "nandwrite ran when rollback erase failed"
grep -q 'CRITICAL: restore failed and rollback could not be verified' "$fix/err" || fail "critical erase message"
cur=$(awk '/^CURRENT_BACKUP / { print $2; exit }' "$fix/actions.log")
[ -f "$cur" ] || fail "rollback erase failure deleted the backup"
grep -q "backup preserved at $cur" "$fix/err" || fail "critical message omitted the backup path"

fix=$(new_fix)
printf '6\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" restore)
[ "$rc" = "1" ] || fail "rollback nandwrite failure rc=$rc"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" && fail "rollback nandwrite claimed success"
grep -q 'CRITICAL: restore failed and rollback could not be verified' "$fix/err" || fail "critical nandwrite message"
cur=$(awk '/^CURRENT_BACKUP / { print $2; exit }' "$fix/actions.log")
[ -f "$cur" ] || fail "rollback nandwrite failure deleted the backup"
awk -v cur="$cur" '
	/^ROLLBACK$/ { r=1; next }
	r && /^nandwrite / { if (index($0, cur) == 0) bad=1; n++ }
	END { exit !(r && n && !bad) }
' "$fix/actions.log" || fail "failed rollback nandwrite was not the current backup"

fix=$(new_fix)
printf '6\n' > "$fix/fail-readback-first"
rc=$(run "$fix" restore)
[ "$rc" = "1" ] || fail "rollback readback failure rc=$rc"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" && fail "rollback readback claimed success"
grep -q 'CRITICAL: restore failed and rollback could not be verified' "$fix/err" || fail "critical readback message"
cur=$(awk '/^CURRENT_BACKUP / { print $2; exit }' "$fix/actions.log")
[ -f "$cur" ] || fail "rollback readback failure deleted the backup"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
want=$(sha256sum "$cur" | awk '{print $1}')
[ "$live" != "$want" ] || fail "rollback readback mismatch still matched the backup"

fix=$(new_fix)
rc=$(run "$fix" restore)
[ "$rc" = "0" ] || fail "restore failed: $(cat "$fix/err")"
grep -q '^READBACK target ok$' "$fix/actions.log" || fail "target readback missing"
grep -q '^ROLLBACK$' "$fix/actions.log" && fail "successful restore rolled back"
awk '
	/^GATES / { g=NR }
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { if (!e) e=NR; ne++ }
	/^nandwrite / { if (!n) n=NR; nn++ }
	/^READBACK target ok$/ { t=NR }
	END { exit !(g && c && e && n && t && g < c && c < e && e < n && n < t && ne == 1 && nn == 1) }
' "$fix/actions.log" || fail "successful restore order"
awk '/^nandwrite / { if (index($0, "mtd5-original-") == 0) bad=1 } END { exit bad }' "$fix/actions.log" \
	|| fail "successful restore did not write the stock candidate"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
orig=$(sha256sum "$GOOD" | awk '{print $1}')
[ "$live" = "$orig" ] || fail "successful restore did not leave the stock image"

STOCK_IMG=$ROOT/package/system/zlyme-preloader/preloader-stock.img
PROV=$ROOT/package/system/zlyme-preloader/preloader-stock.PROVENANCE
STOCK_SHA=$(sed -n 's/^STOCK_SHA=//p' "$PRE")
PATCHED_SHA=$(sed -n 's/^PATCHED_SHA=//p' "$PRE")
[ -f "$STOCK_IMG" ] || fail "bundled stock image is missing"
[ "$(sha256sum "$STOCK_IMG" | awk '{print $1}')" = "$STOCK_SHA" ] || fail "bundled stock sha"
[ "$(md5sum "$STOCK_IMG" | awk '{print $1}')" = "1d525e6e6c89bd788b5245c90c97833b" ] || fail "bundled stock md5"
grep -q "$STOCK_SHA" "$PROV" || fail "provenance sha"
grep -q 'c126d3235face9ddca5bf021258a84758dca543c' "$PROV" || fail "provenance wiki commit"
grep -q 'preloader-stock-rocknix/App/apommel-multiboot/preloader-stock.img' "$PROV" || fail "provenance path"
grep -q "$PATCHED_SHA" "$PROV" || fail "provenance patched fingerprint"
grep -q '/usr/share/zlyme/recovery/preloader-stock.img' "$PRE" || fail "stock install path"
grep -q 'preloader-stock.img' "$ROOT/package/system/zlyme-preloader/zlyme-preloader.mk" || fail "package does not install the stock image"
if grep -q 'preloader-patched.img' "$ROOT/package/system/zlyme-preloader/zlyme-preloader.mk"; then
	fail "package installs the patched image"
fi
if [ -e "$ROOT/package/system/zlyme-preloader/preloader-patched.img" ]; then
	fail "patched image is in the package tree"
fi
# The SHA overrides are reached only when the fixture switch is on.
awk '
	/expected_stock_sha\(\)/ { f=1 }
	f && /ZLYME_PRELOADER_STOCK_SHA/ { saw=1 }
	f && /\[ "\$TEST" = 1 \]/ { gate=1 }
	f && /^}/ { exit !(saw && gate) }
' "$PRE" || fail "stock sha override is not test-only"
WIKI=${ZLYME_WIKI_TREE:-/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP}
KNOWN=$WIKI/preloader-stock-rocknix/App/apommel-multiboot/preloader-patched.img
[ -f "$KNOWN" ] || fail "known patched preloader is not available"
[ "$(sha256sum "$KNOWN" | awk '{print $1}')" = "$PATCHED_SHA" ] || fail "known patched fingerprint"

install_stock() {
	mkdir -p "$1/usr/share/zlyme/recovery"
	cp "$STOCK_IMG" "$1/usr/share/zlyme/recovery/preloader-stock.img"
}

# Per-device backup wins even when the live image is the known patched
# counterpart and the bundled stock file is installed.
fix=$(new_fix)
cp "$KNOWN" "$fix/live/preloader.img"
sum=$(sha256sum "$STOCK_IMG" | awk '{print $1}')
rm -f "$fix"/boot/mtd5-original-*.img
cp "$STOCK_IMG" "$fix/boot/mtd5-original-$sum.img"
install_stock "$fix"
rc=$(run "$fix" restore)
[ "$rc" = "0" ] || fail "per-device backup restore rc=$rc $(cat "$fix/err")"
awk '/^nandwrite / { if (index($0, "mtd5-original-") == 0 || index($0, "preloader-stock.img") != 0) bad=1 } END { exit bad }' "$fix/actions.log" \
	|| fail "per-device backup did not win $(cat "$fix/actions.log")"
awk '
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { e=NR }
	END { exit !(c && e && c < e) }
' "$fix/actions.log" || fail "per-device restore erased before the current backup"

# Two backups still refuse, including when the fallback would otherwise match.
fix=$(new_fix)
cp "$KNOWN" "$fix/live/preloader.img"
sum=$(sha256sum "$STOCK_IMG" | awk '{print $1}')
rm -f "$fix"/boot/mtd5-original-*.img
cp "$STOCK_IMG" "$fix/boot/mtd5-original-$sum.img"
cp "$STOCK_IMG" "$fix/boot/mtd5-original-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.img"
install_stock "$fix"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "ambiguous backup used the fallback"
grep -q 'more than one original preloader backup' "$fix/err" || fail "ambiguous fallback reason $(cat "$fix/err")"
no_cmd "$fix" "ambiguous fallback"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp "$KNOWN" "$fix/live/preloader.img"
install_stock "$fix"
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "compatible fallback status rc=$rc $(cat "$fix/err")"
grep -q '^backup=unavailable$' "$fix/out" || fail "compatible status backup $(cat "$fix/out")"
grep -q '^fallback=compatible$' "$fix/out" || fail "compatible status fallback $(cat "$fix/out")"
rc=$(run "$fix" restore)
[ "$rc" = "0" ] || fail "stock fallback restore rc=$rc $(cat "$fix/err")"
grep -q 'using bundled stock fallback' "$fix/err" || fail "fallback was not selected"
grep -q 'restored stock fallback' "$fix/err" || fail "fallback restore text"
awk '/^nandwrite / { if (index($0, "preloader-stock.img") == 0) bad=1 } END { exit bad }' "$fix/actions.log" \
	|| fail "fallback did not write the bundled image"
awk '
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { if (!e) e=NR }
	/^nandwrite / { n=NR }
	END { exit !(c && e && n && c < e && e < n) }
' "$fix/actions.log" || fail "fallback erased before the current backup"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" = "$STOCK_SHA" ] || fail "fallback did not leave the stock image"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp "$KNOWN" "$fix/live/preloader.img"
printf '\x5a' | dd of="$fix/live/preloader.img" bs=1 seek=2097151 conv=notrunc status=none
install_stock "$fix"
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "one-byte status rc=$rc $(cat "$fix/err")"
grep -q '^backup=unavailable$' "$fix/out" || fail "one-byte status backup"
grep -q '^fallback=incompatible$' "$fix/out" || fail "one-byte status fallback $(cat "$fix/out")"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "one-byte difference was accepted"
grep -q 'does not exactly match this preloader revision' "$fix/err" || fail "one-byte refusal $(cat "$fix/err")"
no_cmd "$fix" "one-byte difference"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
python3 - "$KNOWN" "$fix/live/preloader.img" <<'PY'
import hashlib, sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (131072, 524288):
    entry = base + 0x78 + 0x58
    off = int.from_bytes(data[entry:entry + 2], "little")
    count = int.from_bytes(data[entry + 2:entry + 4], "little")
    start = base + off * 512
    data[start + 64] ^= 0x5A
    blob = bytes(data[start:start + count * 512])
    data[entry + 0x18:entry + 0x38] = hashlib.sha256(blob).digest()
open(sys.argv[2], "wb").write(data)
PY
python3 "$PY" "$fix/live/preloader.img" || fail "ddr-only image is not a preloader"
python3 "$PY" ddr "$fix/live/preloader.img" "$STOCK_IMG" || fail "ddr-only image does not share DDR"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" != "$PATCHED_SHA" ] || fail "ddr-only image still matches the fingerprint"
install_stock "$fix"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "ddr-only match was accepted"
grep -q 'does not exactly match this preloader revision' "$fix/err" || fail "ddr-only refusal $(cat "$fix/err")"
grep -q 'DDR payload does not match' "$fix/err" && fail "ddr-only was decided by the DDR check"
no_cmd "$fix" "ddr-only match"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp "$KNOWN" "$fix/live/preloader.img"
mkdir -p "$fix/usr/share/zlyme/recovery"
cp "$GOOD" "$fix/usr/share/zlyme/recovery/preloader-stock.img"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "wrong stock sha was accepted"
grep -q 'bundled stock preloader hash does not match' "$fix/err" || fail "stock sha refusal $(cat "$fix/err")"
no_cmd "$fix" "wrong stock sha"

fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp "$KNOWN" "$fix/live/preloader.img"
dd if=/dev/zero of="$fix/bad-stock.img" bs=2097152 count=1 status=none
badsha=$(sha256sum "$fix/bad-stock.img" | awk '{print $1}')
rc=$(run_fb "$fix" restore "$badsha" "" "$fix/bad-stock.img")
[ "$rc" != "0" ] || fail "invalid stock structure was accepted"
grep -q 'image structure refused' "$fix/err" || fail "structure refusal $(cat "$fix/err")"
no_cmd "$fix" "invalid stock structure"

fix=$(new_fix)
rc=$(run "$fix" erase-preloader)
[ "$rc" = "0" ] || fail "erase failed: $(cat "$fix/err")"
grep -q '^flash_erase /dev/mtd0 0 0' "$fix/actions.log" || fail "maskrom erase missing"
grep -q '^nandwrite ' "$fix/actions.log" && fail "erase-preloader wrote an image"
grep -q '^ERASE ok' "$fix/actions.log" || fail "erase did not record success"
grep -q '^ROLLBACK$' "$fix/actions.log" && fail "successful erase rolled back"
awk '
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { e=NR; n++ }
	END { exit !(c && e && c < e && n == 1) }
' "$fix/actions.log" || fail "erase ran before the current backup"

fix=$(new_fix)
printf '1\n' > "$fix/fail-erase-first"
rc=$(run "$fix" erase-preloader)
[ "$rc" = "3" ] || fail "maskrom erase failure rc=$rc $(cat "$fix/err")"
grep -q '^ERASE ok' "$fix/actions.log" && fail "failed erase claimed MASKROM success"
rollback_used_current "$fix" "maskrom erase failure"

# Release asset, native recovery, and the maskrom restart. None of this
# talks to a Flip.
grep -q 'miyoo355_fw.img.sha256' "$POST" || fail "sha256 is not generated"
grep -q 'sha256sum miyoo355_fw.img' "$POST" || fail "sha256 command"
grep -q 'miyoo355_fw.img.sha256' "$ROOT/.github/workflows/build-stage.yml" || fail "stage upload omits the installer hash"
grep -q 'miyoo355_fw.img$' "$ROOT/.github/workflows/build.yml" || fail "release upload omits the installer"
grep -q 'miyoo355_fw.img.sha256' "$ROOT/.github/workflows/build.yml" || fail "release upload omits the installer hash"
if [ -e "$ROOT/.github/workflows/miyoo355-fw.yml" ] || [ -e "$ROOT/.github/workflows/installer.yml" ]; then
	fail "a second installer workflow was added"
fi
wf=$(ls "$ROOT/.github/workflows/"*.yml "$ROOT/.github/workflows/"*.yaml 2>/dev/null | wc -l)
# The product workflows stay build.yml, build-stage.yml, and docker-image.yml.
[ "$wf" = 3 ] || fail "workflow count is $wf"
if [ -e "$ROOT/package/system/zlyme-maskrom" ]; then
	fail "maskrom helper package remains"
fi
if grep -q 'BR2_PACKAGE_ZLYME_MASKROM' "$DEF" "$ROOT/package/system/Config.in"; then
	fail "maskrom helper is still selected"
fi
if [ -e "$ROOT/board/my355/uboot/patches/uboot/008-my355-maskrom-request.patch" ]; then
	fail "maskrom-request patch remains"
fi
if [ -e "$ROOT/board/my355/uboot/patches/uboot/009-rk3568-soc-con1-download.patch" ]; then
	fail "soc-con1 experiment remains"
fi
if [ -e "$ROOT/board/my355/uboot/maskrom_request.h" ]; then
	fail "maskrom request header remains"
fi
if [ -e "$ROOT/scripts/tests/maskrom_request_test.c" ]; then
	fail "maskrom request fixture remains"
fi
if grep -q 'maskrom-request' "$ROOT/board/my355/board.mk" \
	"$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch"; then
	fail "preboot still runs maskrom-request"
fi
if grep -q 'zlyme-maskrom' "$PRE"; then
	fail "preloader script calls zlyme-maskrom"
fi
if [ -e "$ROOT/board/my355/linux/patches/20-rk3566/linux/1014-soc-rockchip-miyoo-flip-maskrom-restart.patch" ]; then
	fail "direct maskrom kernel patch remains"
fi
if grep -q 'miyoo,flip-maskrom-restart' "$ROOT/board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts"; then
	fail "direct maskrom dts node remains"
fi
if grep -q 'CONFIG_MIYOO_FLIP_MASKROM_RESTART' "$ROOT/board/my355/linux/linux.config"; then
	fail "direct maskrom kernel config remains"
fi
if grep -R -l 'miyoo-flip-maskrom' "$ROOT/board/my355/linux" >/dev/null 2>&1; then
	fail "direct maskrom driver source remains"
fi
if grep -l 'register_restart_handler' "$ROOT/board/my355/linux/patches/"*/*/*.patch 2>/dev/null; then
	fail "a patch registers a restart handler"
fi
if grep -R -l 'psci_sys_reset' "$ROOT/board/my355/linux/patches" >/dev/null 2>&1; then
	fail "a patch edits the PSCI restart handler"
fi
if grep -R 'rockchip_restart_notify' "$ROOT/board/my355/linux/patches" >/dev/null 2>&1; then
	fail "a patch edits the clock restart handler"
fi
grep -q 'CONFIG_CMD_RBROM=y' "$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch" || fail "uboot rbrom config"
grep -q 'CONFIG_BOOTDELAY=-2' "$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch" || fail "bootdelay changed"
preboot='blkcache configure 32 32; my355 fg'
grep -q "$preboot" "$ROOT/board/my355/board.mk" || fail "board preboot"
grep -q "$preboot" "$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch" || fail "defconfig preboot"
grep -q 'my355 fg' "$ROOT/board/my355/uboot/patches/uboot/006-cmd-add-my355-boot-helpers.patch" || fail "fuel gauge command missing"
grep -q 'u-boot,spl-boot-order = &sdmmc0;' "$ROOT/board/my355/uboot/dts/rk3566-miyoo-flip-u-boot.dtsi" || fail "spl boot order changed"
grep -q 'mmc0 = &sdmmc0;' "$ROOT/board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts" || fail "linux mmc0 alias changed"
DTSI=$ROOT/output/build/uboot-2026.01/arch/arm/dts/rk356x-u-boot.dtsi
if [ -f "$DTSI" ]; then
	grep -q 'mmc0 = &sdhci;' "$DTSI" || fail "staged mmc0 is not sdhci"
	sdmmc=$(sed -n 's/^[[:space:]]*mmc\([0-9][0-9]*\)[[:space:]]*=[[:space:]]*&sdmmc0;.*/\1/p' "$DTSI")
	[ "$sdmmc" = "1" ] || fail "staged sdmmc0 alias is mmc${sdmmc:-missing}"
fi
grep -q 'Settings -> System -> Advanced -> Recovery' "$ROOT/package/system/nextui/nextui.mk" || fail "pin does not name the native Recovery page"
pin=$(sed -n 's/^NEXTUI_VERSION = //p' "$ROOT/package/system/nextui/nextui.mk")
if [ -d /home/ale/NextUI/.git ]; then
	head=$(git -C /home/ale/NextUI rev-parse HEAD)
	[ "$head" = "$pin" ] || fail "NextUI checkout $head is not the pin $pin"
	git -C /home/ale/NextUI grep -q 'RESTORE STOCK PRELOADER' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no restore confirmation"
	git -C /home/ale/NextUI grep -q 'ARM MASKROM RECOVERY' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no arm confirmation"
	git -C /home/ale/NextUI grep -q 'DISARM MASKROM RECOVERY' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no disarm confirmation"
	git -C /home/ale/NextUI grep -q 'prepare-recovery' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not prepare"
	git -C /home/ale/NextUI grep -q 'arm-recovery' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not arm"
	git -C /home/ale/NextUI grep -q 'disarm-recovery' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not disarm"
	if git -C /home/ale/NextUI grep -q 'zlyme-maskrom' "$head" -- workspace/all/settings/zlymemenu.cpp; then
		fail "pinned NextUI still calls zlyme-maskrom"
	fi
	if git -C /home/ale/NextUI grep -q 'Reboot to MASKROM' "$head" -- workspace/all/settings/zlymemenu.cpp; then
		fail "pinned NextUI still offers Reboot to MASKROM"
	fi
	git -C /home/ale/NextUI grep -q 'status-machine' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not call status-machine"
	git -C /home/ale/NextUI grep -q 'StaticMenuItem' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI status is not a fixed page"
	git -C /home/ale/NextUI grep -q '"Stock restore"' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no stock restore row"
	git -C /home/ale/NextUI grep -q 'Recovery armed' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no armed label"
	if git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/^static InputReactionHint recovery_status/,/^static InputReactionHint recovery_restore_now/
	' | grep -q showOverlay; then
		fail "preloader status still uses an overlay"
	fi
	if git -C /home/ale/NextUI grep -q 'erase-preloader' "$head" -- workspace/all/settings/zlymemenu.cpp; then
		fail "pinned NextUI exposes erase-preloader"
	fi
	arm=$(git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/^static InputReactionHint recovery_arm_now/,/^static InputReactionHint recovery_disarm_now/
	')
	printf '%s\n' "$arm" | grep -q 'prepare-recovery' || fail "arm UI does not prepare"
	printf '%s\n' "$arm" | grep -q 'arm-recovery' || fail "arm UI does not arm"
	printf '%s\n' "$arm" | awk '
		/prepare-recovery/ { p=NR }
		/arm-recovery/ { a=NR }
		END { exit !(p && a && p < a) }
	' || fail "arm UI calls arm before prepare"
	disarm=$(git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/^static InputReactionHint recovery_disarm_now/,/^static MenuList \*recovery_final/
	')
	printf '%s\n' "$disarm" | grep -q 'disarm-recovery' || fail "disarm UI does not disarm"
	if printf '%s\n' "$disarm" | grep -q '"restore"'; then
		fail "disarm UI calls stock restore"
	fi
	git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/rows.push_back\(new MenuItem\{ListItemType::Button, "Cancel"/ { print; exit }
	' | grep -q Cancel || fail "native confirmation does not start on Cancel"
fi

# Recovery preloader reversal. Fixtures only. restore stays fail-closed.
RECOVERY_SHA=f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367
BANNER='U-Boot SPL 2017.09 (Nov 02 2024 - 15:59:04)'

reseal_idb() {
	python3 - "$1" <<'PY'
import hashlib, sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (131072, 524288):
    for i in (0, 1):
        entry = base + 0x78 + i * 0x58
        off = int.from_bytes(data[entry:entry + 2], "little")
        count = int.from_bytes(data[entry + 2:entry + 4], "little")
        start = base + off * 512
        blob = bytes(data[start:start + count * 512])
        data[entry + 0x18:entry + 0x38] = hashlib.sha256(blob).digest()
open(sys.argv[1], "wb").write(data)
PY
}

# A preloader-current file is not a restore source, even when it is valid.
fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp "$KNOWN" "$fix/live/preloader.img"
install_stock "$fix"
stock_sum=$(sha256sum "$STOCK_IMG" | awk '{print $1}')
cp "$STOCK_IMG" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$stock_sum.img"
rc=$(run "$fix" restore)
[ "$rc" = "0" ] || fail "stock fallback beside a current backup rc=$rc $(cat "$fix/err")"
awk '/^nandwrite / { if (index($0, "preloader-stock.img") == 0 || index($0, "preloader-current-") != 0) bad=1 } END { exit bad }' \
	"$fix/actions.log" || fail "restore used preloader-current $(cat "$fix/actions.log")"

fix=$(new_fix)
rc=$(run "$fix" prepare-recovery)
[ "$rc" != "0" ] || fail "synthetic SPL was accepted as a recovery source"
grep -q 'this preloader is not a supported recovery source' "$fix/err" || fail "synthetic refusal $(cat "$fix/err")"
no_cmd "$fix" "synthetic prepare"

fix=$(new_fix)
cp "$KNOWN" "$fix/live/preloader.img"
rc=$(run "$fix" prepare-recovery)
[ "$rc" = "0" ] || fail "prepare-recovery rc=$rc $(cat "$fix/err")"
grep -q 'NAND was not written' "$fix/err" || fail "prepare did not say NAND was untouched"
grep -q 'Zlyme will not reboot' "$fix/err" || fail "prepare rebooted in its text"
no_cmd "$fix" "prepare-recovery"
grep -q '^PREPARE_RECOVERY ' "$fix/actions.log" || fail "prepare did not record the image"
src_sum=$(sha256sum "$KNOWN" | awk '{print $1}')
src_file="$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img"
[ -f "$src_file" ] || fail "prepare did not keep the source backup"
cmp -s "$KNOWN" "$src_file" || fail "source backup is not the live image"
cmp -s "$KNOWN" "$fix/live/preloader.img" || fail "prepare wrote the live preloader"
rec_file="$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
[ -f "$rec_file" ] || fail "recovery image missing"
[ "$(sha256sum "$rec_file" | awk '{print $1}')" = "$RECOVERY_SHA" ] || fail "recovery image sha"
man="$fix/storage/.config/zlyme/preloader-recovery/manifest.json"
python3 - "$man" "$src_sum" "$RECOVERY_SHA" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["schema"] == 1
assert doc["design"] == "right-sd-v1"
assert doc["device"] == "my355"
assert doc["source_sha256"] == sys.argv[2]
assert doc["recovery_sha256"] == sys.argv[3]
assert doc["source_backup"] == "preloader-current-" + sys.argv[2] + ".img"
assert "sig" not in doc
PY
boot_src="$fix/boot/preloader-current-$src_sum.img"
cmp -s "$src_file" "$boot_src" || fail "FAT source copy differs"
grep -q 'NOT EXECUTED DURING RECOVERY PREPARATION' "$fix/boot/preloader-current-$src_sum.txt" || fail "FAT note"
grep -q "xrock flash write 0 preloader-current-$src_sum.img" "$fix/boot/preloader-current-$src_sum.txt" || fail "FAT restore command"
cmp -s "$man" "$fix/boot/preloader-recovery-manifest.json" || fail "FAT manifest copy"
prepared=$fix

# Honest manifest, live image still the normal preloader.
fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$KNOWN" "$fix/live/preloader.img"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "normal preloader was disarmed"
grep -q 'live preloader is not the recovery image' "$fix/err" || fail "normal live text $(cat "$fix/err")"
no_cmd "$fix" "already normal"

# Successful disarm restores the source and leaves that backup in place.
fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
: > "$fix/actions.log"
rc=$(run "$fix" disarm-recovery)
[ "$rc" = "0" ] || fail "disarm rc=$rc $(cat "$fix/err")"
grep -q 'disarmed recovery preloader' "$fix/err" || fail "disarm text"
grep -q 'Zlyme will not reboot' "$fix/err" || fail "disarm rebooted in its text"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" = "$src_sum" ] || fail "disarm left $live"
cmp -s "$src_file" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" || fail "disarm rewrote the source backup"
[ -f "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$RECOVERY_SHA.img" ] || fail "rollback copy missing"
awk -v src="$src_sum" '
	/^GATES / { g=NR }
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { if (!e) e=NR; ne++ }
	/^nandwrite / { if (!n) n=NR; nn++; if (index($0, src) == 0) bad=1 }
	/^READBACK target ok$/ { t=NR }
	END { exit !(g && c && e && n && t && g < c && c < e && e < n && n < t && ne == 1 && nn == 1 && !bad) }
' "$fix/actions.log" || fail "disarm order $(cat "$fix/actions.log")"
# The same fixture's current-backup must not satisfy restore once the
# recovery image is what NAND holds and no original backup is present.
fix=$(new_fix)
rm -f "$fix"/boot/mtd5-original-*.img
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
install_stock "$fix"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "restore accepted the recovery image"
grep -q 'does not exactly match this preloader revision' "$fix/err" || fail "restore refusal $(cat "$fix/err")"
no_cmd "$fix" "restore of recovery image"

fix=$(new_fix)
cp "$rec_file" "$fix/live/preloader.img"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "missing manifest was accepted"
grep -q 'recovery manifest is missing' "$fix/err" || fail "missing manifest text $(cat "$fix/err")"
no_cmd "$fix" "missing manifest"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
printf '{\n' > "$fix/storage/.config/zlyme/preloader-recovery/manifest.json"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "malformed manifest was accepted"
grep -q 'recovery manifest is malformed' "$fix/err" || fail "malformed text $(cat "$fix/err")"
no_cmd "$fix" "malformed manifest"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p))
doc["device"] = "other"
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "wrong manifest device was accepted"
grep -q 'recovery manifest device is not my355' "$fix/err" || fail "wrong device text $(cat "$fix/err")"
no_cmd "$fix" "wrong manifest device"

fix=$(new_fix)
printf '%s\n' 'ZLYME_DEVICE_ID=other' > "$fix/usr/share/zlyme/device.conf"
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "wrong platform disarm was accepted"
grep -q 'platform is not my355' "$fix/err" || fail "platform text $(cat "$fix/err")"
no_cmd "$fix" "wrong platform disarm"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p))
doc["recovery_sha256"] = "0" * 64
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "live sha mismatch was accepted"
grep -q 'live preloader is not the recovery image' "$fix/err" || fail "live sha text $(cat "$fix/err")"
no_cmd "$fix" "live sha mismatch"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
rm -f "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "missing source was accepted"
grep -q 'source backup is missing' "$fix/err" || fail "missing source text $(cat "$fix/err")"
no_cmd "$fix" "missing source"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
printf '\x5a' | dd of="$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" bs=1 seek=200 conv=notrunc status=none
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "source sha mismatch was accepted"
grep -q 'source backup sha does not match the manifest' "$fix/err" || fail "source sha text $(cat "$fix/err")"
no_cmd "$fix" "source sha mismatch"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
# Corrupt the DDR payload and leave its stored hash stale.
entry = 131072 + 0x78
off = int.from_bytes(data[entry:entry + 2], "little")
data[131072 + off * 512 + 32] ^= 0x5A
open(sys.argv[1], "wb").write(data)
PY
bad=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" | awk '{print $1}')
mv "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" \
	"$fix/storage/.config/zlyme/preloader-backups/preloader-current-$bad.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$bad" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["source_sha256"] = sha
doc["source_backup"] = "preloader-current-" + sha + ".img"
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "invalid source structure was accepted"
grep -q 'fails its SHA-256' "$fix/err" || fail "invalid source text $(cat "$fix/err")"
no_cmd "$fix" "invalid source structure"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
printf '\x00' | dd of="$fix/live/preloader.img" bs=1 seek=140000 conv=notrunc status=none
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "invalid live structure was accepted"
grep -q 'image structure refused' "$fix/err" || fail "invalid live text $(cat "$fix/err")"
no_cmd "$fix" "invalid live structure"

# DDR bytes differ. The manifest is updated to the altered source hash
# so only the DDR comparison can refuse it.
fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" <<'PY'
import hashlib, sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (131072, 524288):
    entry = base + 0x78
    off = int.from_bytes(data[entry:entry + 2], "little")
    count = int.from_bytes(data[entry + 2:entry + 4], "little")
    start = base + off * 512
    data[start + 32] ^= 0x5A
    blob = bytes(data[start:start + count * 512])
    data[entry + 0x18:entry + 0x38] = hashlib.sha256(blob).digest()
open(sys.argv[1], "wb").write(data)
PY
bad=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" | awk '{print $1}')
mv "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" \
	"$fix/storage/.config/zlyme/preloader-backups/preloader-current-$bad.img"
python3 - "$PY" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$bad.img" \
	"$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$bad" <<'PY'
import hashlib, json, sys
py, img, man, sha = sys.argv[1:]
ns = {"__name__": "preloader_image"}
exec(open(py).read(), ns)
data = open(img, "rb").read()
_ddr, _spl = ns["_paired"](data)
doc = json.load(open(man))
doc["source_sha256"] = sha
doc["source_backup"] = "preloader-current-" + sha + ".img"
doc["source_ddr_sha256"] = hashlib.sha256(_ddr).hexdigest()
json.dump(doc, open(man, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "DDR mismatch was accepted"
grep -q 'DDR payload does not match the source backup' "$fix/err" || fail "DDR text $(cat "$fix/err")"
no_cmd "$fix" "DDR mismatch"

# Same executable and DDR as this unit, but the stock DTB. A consistent
# manifest must still refuse it: derive(stock) is not the live image.
fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
rm -f "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img"
stock_sum=$(sha256sum "$STOCK_IMG" | awk '{print $1}')
cp "$STOCK_IMG" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$stock_sum.img"
python3 - "$PY" "$STOCK_IMG" "$rec_file" \
	"$fix/storage/.config/zlyme/preloader-recovery/manifest.json" <<'PY'
import hashlib, json, sys
py, stock, live, man = sys.argv[1:]
ns = {"__name__": "preloader_image"}
exec(open(py).read(), ns)
data = open(stock, "rb").read()
ddr, spl = ns["_paired"](data)
doc = json.load(open(man))
sha = hashlib.sha256(data).hexdigest()
doc["source_sha256"] = sha
doc["source_backup"] = "preloader-current-" + sha + ".img"
doc["source_ddr_sha256"] = hashlib.sha256(ddr).hexdigest()
doc["executable_sha256"] = hashlib.sha256(spl[0]["payload"][:ns["DTB_OFF"]]).hexdigest()
doc["recovery_sha256"] = hashlib.sha256(open(live, "rb").read()).hexdigest()
json.dump(doc, open(man, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "stock source was authorized by the manifest"
grep -q 'live recovery image is not the derivative of the source backup' "$fix/err" || fail "stock source text $(cat "$fix/err")"
no_cmd "$fix" "arbitrary stock source"

# Forged recovery hash equal to the five-entry source. The extra boot
# devices are still in that image, so it is not the derivative.
fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$KNOWN" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$src_sum" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "five-entry image was accepted as the recovery image"
grep -q 'live recovery image is not the derivative of the source backup' "$fix/err" || fail "extra boot device text $(cat "$fix/err")"
no_cmd "$fix" "additional boot device"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live-mmc.img"
python3 - "$fix/live-mmc.img" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
old = b"/dwmmc@fe2b0000\x00"
new = b"/sdhci@fe310000\x00"
found = 0
idx = 0
while True:
    at = data.find(old, idx)
    if at < 0:
        break
    if data[at + len(old):at + len(old) + 4] == b"\x00\x00\x00\x02":
        data[at:at + len(old)] = new
        found += 1
    idx = at + 1
if found != 2:
    raise SystemExit(f"boot-order sites {found}")
open(sys.argv[1], "wb").write(data)
PY
reseal_idb "$fix/live-mmc.img"
mmc_sum=$(sha256sum "$fix/live-mmc.img" | awk '{print $1}')
cp "$fix/live-mmc.img" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$mmc_sum" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "wrong MMC boot order was accepted"
grep -q 'live recovery image is not the derivative of the source backup' "$fix/err" || fail "wrong MMC text $(cat "$fix/err")"
no_cmd "$fix" "wrong MMC"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live-exec.img"
python3 - "$fix/live-exec.img" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (0x2E000, 0x8E000):
    data[base + 0x100] ^= 0x5A
open(sys.argv[1], "wb").write(data)
PY
reseal_idb "$fix/live-exec.img"
exec_sum=$(sha256sum "$fix/live-exec.img" | awk '{print $1}')
cp "$fix/live-exec.img" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$exec_sum" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "changed executable was accepted"
grep -q 'recovery image changed SPL executable bytes' "$fix/err" || fail "executable text $(cat "$fix/err")"
no_cmd "$fix" "changed executable"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$KNOWN" "$fix/live-banner.img"
python3 - "$fix/live-banner.img" "$BANNER" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
old = sys.argv[2].encode()
new = old[:-1] + b"5"
if data.count(old) != 2:
    raise SystemExit(f"banner count {data.count(old)}")
data = data.replace(old, new)
open(sys.argv[1], "wb").write(data)
PY
reseal_idb "$fix/live-banner.img"
banner_sum=$(sha256sum "$fix/live-banner.img" | awk '{print $1}')
rm -f "$fix"/storage/.config/zlyme/preloader-backups/*
cp "$fix/live-banner.img" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$banner_sum.img"
cp "$fix/live-banner.img" "$fix/live/preloader.img"
python3 - "$PY" "$fix/live-banner.img" \
	"$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$banner_sum" <<'PY'
import hashlib, json, sys
py, img, man, sha = sys.argv[1:]
ns = {"__name__": "preloader_image"}
exec(open(py).read(), ns)
data = open(img, "rb").read()
ddr, spl = ns["_paired"](data)
doc = json.load(open(man))
doc["source_sha256"] = sha
doc["recovery_sha256"] = sha
doc["source_backup"] = "preloader-current-" + sha + ".img"
doc["source_ddr_sha256"] = hashlib.sha256(ddr).hexdigest()
doc["executable_sha256"] = hashlib.sha256(spl[0]["payload"][:ns["DTB_OFF"]]).hexdigest()
json.dump(doc, open(man, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "other SPL banner was accepted"
grep -q 'different SPL build' "$fix/err" || fail "other SPL text $(cat "$fix/err")"
no_cmd "$fix" "other SPL build"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p))
doc["source_backup"] = "../preloader-current-" + doc["source_sha256"] + ".img"
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "path escape was accepted"
grep -q 'source backup name is not the source sha' "$fix/err" || fail "path escape text $(cat "$fix/err")"
no_cmd "$fix" "manifest path escape"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
printf '10' > "$fix/sys/class/power_supply/battery/capacity"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "low battery disarm was accepted"
grep -q 'battery 10% and no charger' "$fix/err" || fail "battery text $(cat "$fix/err")"
no_cmd "$fix" "disarm battery"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
printf '1' > "$fix/sys/class/mtd/mtd0/bad_blocks"
rc=$(run "$fix" disarm-recovery)
[ "$rc" != "0" ] || fail "bad block disarm was accepted"
grep -q 'preloader has bad blocks' "$fix/err" || fail "bad block text $(cat "$fix/err")"
no_cmd "$fix" "disarm bad blocks"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
before=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")
printf '3\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" disarm-recovery)
[ "$rc" = "3" ] || fail "disarm nandwrite failure rc=$rc $(cat "$fix/err")"
grep -q 'Disarm failed; recovery preloader restored and verified.' "$fix/err" || fail "disarm rollback text $(cat "$fix/err")"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" = "$RECOVERY_SHA" ] || fail "rollback did not keep the recovery image"
[ "$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")" = "$before" ] || fail "failed disarm changed the source backup"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" || fail "disarm rollback did not verify"
awk -v cur="preloader-current-$RECOVERY_SHA.img" '
	/^ROLLBACK$/ { r=1; next }
	r && /^nandwrite / { if (index($0, cur) == 0) bad=1; n++ }
	END { exit !(r && n && !bad) }
' "$fix/actions.log" || fail "rollback wrote a different image $(cat "$fix/actions.log")"

fix=$(new_fix)
cp -a "$prepared/storage/." "$fix/storage/"
cp "$rec_file" "$fix/live/preloader.img"
before=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")
printf '6\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" disarm-recovery)
[ "$rc" = "1" ] || fail "disarm double failure rc=$rc $(cat "$fix/err")"
grep -q 'CRITICAL: disarm failed and rollback could not be verified.' "$fix/err" || fail "critical disarm text $(cat "$fix/err")"
grep -q 'MASKROM/xrock recovery may be required' "$fix/err" || fail "critical disarm omitted xrock"
[ "$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")" = "$before" ] || fail "double failure changed the source backup"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" && fail "double failure claimed rollback"

# arm-recovery installs only the derived image, through the same writer.
awk '/^cmd_arm_recovery\(\)/,/^cmd_erase\(\)/' "$PRE" | grep -q 'write_and_verify' || fail "arm does not use the existing writer"
awk '/^cmd_arm_recovery\(\)/,/^cmd_erase\(\)/' "$PRE" | grep -E 'nandwrite|flash_erase|^[[:space:]]*reboot' && fail "arm has its own writer or a reboot"
arm_fix() {
	fix=$(new_fix)
	cp -a "$prepared/storage/." "$fix/storage/"
	cp -a "$prepared/boot/." "$fix/boot/"
	cp "$KNOWN" "$fix/live/preloader.img"
	printf '%s\n' "$fix"
}

fix=$(arm_fix)
rc=$(run "$fix" arm-recovery)
[ "$rc" = "0" ] || fail "arm rc=$rc $(cat "$fix/err")"
grep -q 'conditional recovery preloader installed and verified' "$fix/err" || fail "arm success text $(cat "$fix/err")"
grep -q 'device was not rebooted' "$fix/err" || fail "arm rebooted in its text"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" = "$RECOVERY_SHA" ] || fail "arm left $live"
cmp -s "$KNOWN" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" || fail "arm rewrote the source bytes"
awk -v rec="recovery-$RECOVERY_SHA.img" '
	/^GATES / { g=NR }
	/^CURRENT_BACKUP / { c=NR }
	/^flash_erase / { if (!e) e=NR; ne++ }
	/^nandwrite / { if (!n) n=NR; nn++; if (index($0, rec) == 0) bad=1 }
	/^READBACK target ok$/ { t=NR }
	END { exit !(g && c && e && n && t && g < c && c < e && e < n && n < t && ne == 1 && nn == 1 && !bad) }
' "$fix/actions.log" || fail "arm order $(cat "$fix/actions.log")"
grep -q '^BOOT_WRITE ' "$fix/actions.log" && fail "arm published to the boot volume"

fix=$(arm_fix)
rm -f "$fix/storage/.config/zlyme/preloader-recovery/manifest.json"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing manifest armed"
grep -q 'recovery manifest is missing' "$fix/err" || fail "arm missing manifest $(cat "$fix/err")"
no_cmd "$fix" "arm missing manifest"

fix=$(arm_fix)
printf '{\n' > "$fix/storage/.config/zlyme/preloader-recovery/manifest.json"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "malformed manifest armed"
grep -q 'recovery manifest is malformed' "$fix/err" || fail "arm malformed $(cat "$fix/err")"
no_cmd "$fix" "arm malformed manifest"

fix=$(arm_fix)
cp "$STOCK_IMG" "$fix/live/preloader.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "wrong live source armed"
grep -q 'live preloader is not the source image in the manifest' "$fix/err" || fail "arm wrong live $(cat "$fix/err")"
no_cmd "$fix" "arm wrong live"

fix=$(arm_fix)
cp "$rec_file" "$fix/live/preloader.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "already-recovery image armed"
grep -q 'live preloader is already the recovery image' "$fix/err" || fail "arm already recovery $(cat "$fix/err")"
no_cmd "$fix" "arm already recovery"

fix=$(arm_fix)
rm -f "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing source armed"
grep -q 'source backup is missing' "$fix/err" || fail "arm missing source $(cat "$fix/err")"
no_cmd "$fix" "arm missing source"

fix=$(arm_fix)
printf '\x5a' | dd of="$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img" bs=1 seek=200 conv=notrunc status=none
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "source mismatch armed"
grep -q 'source backup sha does not match the manifest' "$fix/err" || fail "arm source mismatch $(cat "$fix/err")"
no_cmd "$fix" "arm source mismatch"

fix=$(arm_fix)
cp "$STOCK_IMG" "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "source that is not the live image armed"
grep -q 'source backup sha does not match the manifest' "$fix/err" || fail "arm source bytes $(cat "$fix/err")"
no_cmd "$fix" "arm source not live"

fix=$(arm_fix)
rm -f "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing recovery armed"
grep -q 'prepared recovery image is missing' "$fix/err" || fail "arm missing recovery $(cat "$fix/err")"
no_cmd "$fix" "arm missing recovery"

fix=$(arm_fix)
printf '\x5a' | dd of="$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img" bs=1 seek=300 conv=notrunc status=none
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "recovery sha mismatch armed"
grep -q 'prepared recovery sha does not match the manifest' "$fix/err" || fail "arm recovery sha $(cat "$fix/err")"
no_cmd "$fix" "arm recovery sha"

fix=$(arm_fix)
stock_rec=$fix/stock-recovery.img
python3 "$PY" derive "$STOCK_IMG" "$stock_rec"
stock_rec_sum=$(sha256sum "$stock_rec" | awk '{print $1}')
cp "$stock_rec" "$fix/storage/.config/zlyme/preloader-recovery/recovery-$stock_rec_sum.img"
rm -f "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$stock_rec_sum" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "non-derivative recovery armed"
grep -q 'prepared recovery image is not the derivative of the source backup' "$fix/err" || fail "arm derivation $(cat "$fix/err")"
no_cmd "$fix" "arm derivation"

fix=$(arm_fix)
python3 - "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img" <<'PY'
import hashlib, sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (131072, 524288):
    entry = base + 0x78
    off = int.from_bytes(data[entry:entry + 2], "little")
    count = int.from_bytes(data[entry + 2:entry + 4], "little")
    start = base + off * 512
    data[start + 32] ^= 0x5A
    blob = bytes(data[start:start + count * 512])
    data[entry + 0x18:entry + 0x38] = hashlib.sha256(blob).digest()
open(sys.argv[1], "wb").write(data)
PY
bad=$(sha256sum "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img" | awk '{print $1}')
mv "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img" \
	"$fix/storage/.config/zlyme/preloader-recovery/recovery-$bad.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$bad" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "DDR mismatch armed"
grep -q 'DDR payload does not match the source backup' "$fix/err" || fail "arm DDR $(cat "$fix/err")"
no_cmd "$fix" "arm DDR"

fix=$(arm_fix)
cp "$rec_file" "$fix/arm-exec.img"
python3 - "$fix/arm-exec.img" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
for base in (0x2E000, 0x8E000):
    data[base + 0x100] ^= 0x5A
open(sys.argv[1], "wb").write(data)
PY
reseal_idb "$fix/arm-exec.img"
bad=$(sha256sum "$fix/arm-exec.img" | awk '{print $1}')
cp "$fix/arm-exec.img" "$fix/storage/.config/zlyme/preloader-recovery/recovery-$bad.img"
rm -f "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$bad" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "executable mismatch armed"
grep -q 'recovery image changed SPL executable bytes' "$fix/err" || fail "arm executable $(cat "$fix/err")"
no_cmd "$fix" "arm executable"

fix=$(arm_fix)
cp "$rec_file" "$fix/arm-mmc.img"
python3 - "$fix/arm-mmc.img" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
old = b"/dwmmc@fe2b0000\x00"
new = b"/sdhci@fe310000\x00"
found = 0
idx = 0
while True:
    at = data.find(old, idx)
    if at < 0:
        break
    if data[at + len(old):at + len(old) + 4] == b"\x00\x00\x00\x02":
        data[at:at + len(old)] = new
        found += 1
    idx = at + 1
if found != 2:
    raise SystemExit("boot-order sites %s" % found)
open(sys.argv[1], "wb").write(data)
PY
reseal_idb "$fix/arm-mmc.img"
bad=$(sha256sum "$fix/arm-mmc.img" | awk '{print $1}')
cp "$fix/arm-mmc.img" "$fix/storage/.config/zlyme/preloader-recovery/recovery-$bad.img"
rm -f "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$bad" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "wrong MMC armed"
grep -q 'recovery boot order is not the right-hand slot' "$fix/err" || fail "arm wrong MMC $(cat "$fix/err")"
no_cmd "$fix" "arm wrong MMC"

fix=$(arm_fix)
cp "$KNOWN" "$fix/storage/.config/zlyme/preloader-recovery/recovery-$src_sum.img"
rm -f "$fix/storage/.config/zlyme/preloader-recovery/recovery-$RECOVERY_SHA.img"
python3 - "$fix/storage/.config/zlyme/preloader-recovery/manifest.json" "$src_sum" <<'PY'
import json, sys
p, sha = sys.argv[1:]
doc = json.load(open(p))
doc["recovery_sha256"] = sha
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "extra boot device armed"
grep -q 'recovery boot order has an extra boot device' "$fix/err" || fail "arm extra boot $(cat "$fix/err")"
no_cmd "$fix" "arm extra boot"

fix=$(arm_fix)
rm -f "$fix/boot/preloader-current-$src_sum.img"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing FAT backup armed"
grep -q 'FAT source backup is missing' "$fix/err" || fail "arm FAT missing $(cat "$fix/err")"
no_cmd "$fix" "arm FAT missing"

fix=$(arm_fix)
printf '\x5a' | dd of="$fix/boot/preloader-current-$src_sum.img" bs=1 seek=220 conv=notrunc status=none
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "FAT backup mismatch armed"
grep -q 'FAT source backup does not match the source' "$fix/err" || fail "arm FAT mismatch $(cat "$fix/err")"
no_cmd "$fix" "arm FAT mismatch"

fix=$(arm_fix)
rm -f "$fix/boot/preloader-recovery-manifest.json"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing FAT manifest armed"
grep -q 'FAT recovery manifest is missing' "$fix/err" || fail "arm FAT manifest $(cat "$fix/err")"
no_cmd "$fix" "arm FAT manifest missing"

fix=$(arm_fix)
python3 - "$fix/boot/preloader-recovery-manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p))
doc["device"] = "other"
json.dump(doc, open(p, "w"))
PY
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "FAT manifest mismatch armed"
grep -q 'FAT recovery manifest does not match' "$fix/err" || fail "arm FAT manifest mismatch $(cat "$fix/err")"
no_cmd "$fix" "arm FAT manifest mismatch"

fix=$(arm_fix)
rm -f "$fix/boot/preloader-current-$src_sum.txt"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "missing note armed"
grep -q 'recovery note is missing' "$fix/err" || fail "arm note $(cat "$fix/err")"
no_cmd "$fix" "arm note"

fix=$(arm_fix)
printf '%s\n' '/dev/mmcblk0p2 /boot vfat rw,noatime 0 0' > "$fix/proc/mounts"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "writable boot armed"
grep -q 'boot volume is writable' "$fix/err" || fail "arm writable boot $(cat "$fix/err")"
no_cmd "$fix" "arm writable boot"

fix=$(arm_fix)
printf '10' > "$fix/sys/class/power_supply/battery/capacity"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "low battery armed"
grep -q 'battery 10% and no charger' "$fix/err" || fail "arm battery $(cat "$fix/err")"
no_cmd "$fix" "arm battery"

fix=$(arm_fix)
printf '1' > "$fix/sys/class/mtd/mtd0/bad_blocks"
rc=$(run "$fix" arm-recovery)
[ "$rc" != "0" ] || fail "bad block armed"
grep -q 'preloader has bad blocks' "$fix/err" || fail "arm bad blocks $(cat "$fix/err")"
no_cmd "$fix" "arm bad blocks"

fix=$(arm_fix)
before=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")
printf '3\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" arm-recovery)
[ "$rc" = "3" ] || fail "arm rollback rc=$rc $(cat "$fix/err")"
grep -q 'Arm failed; source preloader restored and verified.' "$fix/err" || fail "arm rollback text $(cat "$fix/err")"
live=$(sha256sum "$fix/live/preloader.img" | awk '{print $1}')
[ "$live" = "$src_sum" ] || fail "arm rollback left $live"
[ "$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")" = "$before" ] || fail "arm rollback changed the source"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" || fail "arm rollback did not verify"

fix=$(arm_fix)
before=$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")
printf '6\n' > "$fix/fail-nandwrite-first"
rc=$(run "$fix" arm-recovery)
[ "$rc" = "1" ] || fail "arm double failure rc=$rc $(cat "$fix/err")"
grep -q 'CRITICAL: arm failed and rollback could not be verified.' "$fix/err" || fail "arm critical $(cat "$fix/err")"
grep -q 'MASKROM/xrock recovery may be required' "$fix/err" || fail "arm critical omitted xrock"
[ "$(sha256sum "$fix/storage/.config/zlyme/preloader-backups/preloader-current-$src_sum.img")" = "$before" ] || fail "arm double failure changed the source"
grep -q '^ROLLBACK_READBACK ok$' "$fix/actions.log" && fail "arm double failure claimed rollback"

# Read-only recovery classification. status-machine must not prepare.
awk '
	/^cmd_status_machine\(\)/ { f=1 }
	f && /^[a-z].*\(\)/ && !/^cmd_status_machine/ { exit }
	f { print }
' "$PRE" | grep -q 'prepare-recovery' && fail "status-machine calls prepare-recovery"
awk '
	/^cmd_disarm_recovery\(\)/ { f=1 }
	f && /^cmd_/ && !/^cmd_disarm_recovery/ { exit }
	f { print }
' "$PRE" | grep -q 'cmd_restore\| restore$' && fail "disarm calls stock restore"

classify() {
	python3 "$PY" recovery-state "$1" "$2" "$3" "$4"
}

bind_fix() {
	man="$1/storage/.config/zlyme/preloader-recovery/manifest.json"
	bak="$1/storage/.config/zlyme/preloader-backups"
	recdir="$1/storage/.config/zlyme/preloader-recovery"
}

fix=$(arm_fix)
bind_fix "$fix"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=normal$' || fail "prepared mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=ready$' || fail "prepared recovery $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^source_backup=available$' || fail "prepared source $(printf '%s' "$out")"
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "prepared status-machine rc=$rc $(cat "$fix/err")"
grep -q '^mode=normal$' "$fix/out" || fail "prepared machine mode $(cat "$fix/out")"
grep -q '^recovery=ready$' "$fix/out" || fail "prepared machine recovery $(cat "$fix/out")"
grep -q '^source_backup=available$' "$fix/out" || fail "prepared machine source $(cat "$fix/out")"
grep -q '^stock_restore=available$' "$fix/out" || fail "prepared machine stock $(cat "$fix/out")"
grep -q '^PREPARE_RECOVERY ' "$fix/actions.log" && fail "status-machine prepared a recovery image"
no_cmd "$fix" "prepared status-machine"

fix=$(arm_fix)
bind_fix "$fix"
rm -f "$man"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=normal$' || fail "missing manifest mode"
printf '%s\n' "$out" | grep -q '^recovery=not-prepared$' || fail "missing manifest recovery $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^source_backup=missing$' || fail "missing manifest source"

fix=$(arm_fix)
bind_fix "$fix"
printf '{\n' > "$man"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=unknown$' || fail "corrupt manifest mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=invalid$' || fail "corrupt manifest recovery"

fix=$(arm_fix)
bind_fix "$fix"
rm -f "$bak/preloader-current-$src_sum.img"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=unknown$' || fail "missing source mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=invalid$' || fail "missing source recovery"
printf '%s\n' "$out" | grep -q '^source_backup=missing$' || fail "missing source flag"

fix=$(arm_fix)
bind_fix "$fix"
rm -f "$recdir/recovery-$RECOVERY_SHA.img"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^recovery=invalid$' || fail "missing recovery image $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^source_backup=available$' || fail "missing recovery kept the source"

fix=$(arm_fix)
bind_fix "$fix"
printf '\x5a' | dd of="$recdir/recovery-$RECOVERY_SHA.img" bs=1 seek=300 conv=notrunc status=none
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=unknown$' || fail "mismatch mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=invalid$' || fail "mismatch recovery"

fix=$(arm_fix)
bind_fix "$fix"
cp "$recdir/recovery-$RECOVERY_SHA.img" "$fix/live/preloader.img"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=recovery$' || fail "armed mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=armed$' || fail "armed recovery $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^source_backup=available$' || fail "armed source"
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "armed status-machine rc=$rc $(cat "$fix/err")"
grep -q '^mode=recovery$' "$fix/out" || fail "armed machine $(cat "$fix/out")"
grep -q '^recovery=armed$' "$fix/out" || fail "armed machine recovery $(cat "$fix/out")"
grep -q '^stock_restore=available$' "$fix/out" || fail "armed machine stock $(cat "$fix/out")"
no_cmd "$fix" "armed status-machine"

fix=$(arm_fix)
bind_fix "$fix"
cp "$recdir/recovery-$RECOVERY_SHA.img" "$fix/live/preloader.img"
rm -f "$fix"/boot/mtd5-original-*.img
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "armed without stock rc=$rc $(cat "$fix/err")"
grep -q '^stock_restore=unavailable$' "$fix/out" || fail "armed without stock $(cat "$fix/out")"
grep -q '^fallback=incompatible$' "$fix/out" || fail "armed without stock fallback $(cat "$fix/out")"
no_cmd "$fix" "armed without stock"

fix=$(arm_fix)
bind_fix "$fix"
cp "$STOCK_IMG" "$fix/live/preloader.img"
out=$(classify "$man" "$fix/live/preloader.img" "$bak" "$recdir")
printf '%s\n' "$out" | grep -q '^mode=unknown$' || fail "unknown live mode $(printf '%s' "$out")"
printf '%s\n' "$out" | grep -q '^recovery=invalid$' || fail "unknown live recovery $(printf '%s' "$out")"

fix=$(new_fix)
cp "$KNOWN" "$fix/live/preloader.img"
rc=$(run "$fix" status-machine)
[ "$rc" = "0" ] || fail "unprepared status-machine rc=$rc $(cat "$fix/err")"
grep -q '^mode=normal$' "$fix/out" || fail "unprepared mode $(cat "$fix/out")"
grep -q '^recovery=not-prepared$' "$fix/out" || fail "unprepared recovery $(cat "$fix/out")"
grep -q '^source_backup=missing$' "$fix/out" || fail "unprepared source $(cat "$fix/out")"
grep -q '^stock_restore=available$' "$fix/out" || fail "unprepared stock $(cat "$fix/out")"
no_cmd "$fix" "unprepared status-machine"

echo "phase11c: ok"
