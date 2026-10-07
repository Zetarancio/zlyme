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
no_cmd "$fix" "missing backup"

fix=$(new_fix)
sum=$(sha256sum "$GOOD" | awk '{print $1}')
cp "$GOOD" "$fix/boot/mtd5-original-$sum.img"
cp "$GOOD" "$fix/boot/mtd5-original-${sum}.img.bak" 2>/dev/null || true
# second distinct name that still matches the glob and exists
cp "$GOOD" "$fix/boot/mtd5-original-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.img"
rc=$(run "$fix" restore)
[ "$rc" != "0" ] || fail "ambiguous backups were accepted"
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
MASK=$ROOT/package/system/zlyme-maskrom/zlyme-maskrom.c
grep -q 'LINUX_REBOOT_CMD_RESTART2' "$MASK" || fail "helper does not use restart2"
grep -q '"maskrom"' "$MASK" || fail "helper command string"
if grep -E '/dev/mem|devmem' "$MASK" "$PRE" >/dev/null; then
	fail "recovery userspace uses devmem"
fi
if grep -q 'erase-preloader' "$MASK"; then
	fail "maskrom helper erases the preloader"
fi
grep -q 'BR2_PACKAGE_ZLYME_MASKROM=y' "$DEF" || fail "maskrom helper package is off"
DRV=$ROOT/board/my355/linux/patches/20-rk3566/linux/1014-soc-rockchip-miyoo-flip-maskrom-restart.patch
grep -q 'strcmp(cmd, "maskrom")' "$DRV" || fail "restart handler does not match maskrom"
grep -q 'return NOTIFY_DONE' "$DRV" || fail "non-maskrom path missing"
grep -q '0xef08a53c' "$DRV" || fail "download flag missing"
grep -q '0xfdb9' "$DRV" || fail "cru reset value missing"
grep -q 'miyoo,flip-maskrom-restart' "$ROOT/board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts" || fail "dts node missing"
if grep -l 'register_restart_handler' "$ROOT/board/my355/linux/patches/"*/*/*.patch 2>/dev/null | grep -v 1014-soc-rockchip-miyoo-flip-maskrom-restart; then
	fail "another patch registers a restart handler"
fi
# The stock PSCI and clock restart handlers are not patched.
if grep -R -l 'psci_sys_reset' "$ROOT/board/my355/linux/patches" >/dev/null 2>&1; then
	fail "a patch edits the PSCI restart handler"
fi
if grep -R 'rockchip_restart_notify' "$ROOT/board/my355/linux/patches" >/dev/null 2>&1; then
	fail "a patch edits the clock restart handler"
fi
grep -q 'CONFIG_CMD_RBROM=y' "$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch" || fail "uboot rbrom config"
grep -q 'CONFIG_BOOTDELAY=-2' "$ROOT/board/my355/uboot/patches/uboot/001-fix-defconfig.patch" || fail "bootdelay changed"
grep -q 'Settings -> System -> Advanced -> Recovery' "$ROOT/package/system/nextui/nextui.mk" || fail "pin does not name the native Recovery page"
pin=$(sed -n 's/^NEXTUI_VERSION = //p' "$ROOT/package/system/nextui/nextui.mk")
if [ -d /home/ale/NextUI/.git ]; then
	head=$(git -C /home/ale/NextUI rev-parse HEAD)
	[ "$head" = "$pin" ] || fail "NextUI checkout $head is not the pin $pin"
	git -C /home/ale/NextUI grep -q 'RESTORE STOCK PRELOADER' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no restore confirmation"
	git -C /home/ale/NextUI grep -q 'REBOOT TO MASKROM' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI has no maskrom confirmation"
	git -C /home/ale/NextUI grep -q 'zlyme-maskrom' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not call zlyme-maskrom"
	git -C /home/ale/NextUI grep -q 'status-machine' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI does not call status-machine"
	git -C /home/ale/NextUI grep -q 'StaticMenuItem' "$head" -- workspace/all/settings/zlymemenu.cpp || fail "pinned NextUI status is not a fixed page"
	if git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/^static InputReactionHint recovery_status/,/^static InputReactionHint recovery_restore_now/
	' | grep -q showOverlay; then
		fail "preloader status still uses an overlay"
	fi
	if git -C /home/ale/NextUI grep -q 'erase-preloader' "$head" -- workspace/all/settings/zlymemenu.cpp; then
		fail "pinned NextUI exposes erase-preloader"
	fi
	git -C /home/ale/NextUI show "$head:workspace/all/settings/zlymemenu.cpp" | awk '
		/rows.push_back\(new MenuItem\{ListItemType::Button, "Cancel"/ { print; exit }
	' | grep -q Cancel || fail "native confirmation does not start on Cancel"
fi

echo "phase11c: ok"
