#!/bin/sh
# A cloned card with the same ZLYMEBOOT and ZLYME labels must not be
# selected. Identity is the primary node. The label only confirms it.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
init=$ROOT/package/boot/zlyme-initramfs/init
s12=$ROOT/board/my355/fsoverlay/etc/init.d/S12bootfs
s13=$ROOT/board/my355/fsoverlay/etc/init.d/S13resize
s15=$ROOT/board/my355/fsoverlay/etc/init.d/S15bootpart
rcs=$ROOT/board/my355/fsoverlay/etc/init.d/rcS
writer=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-boot-write
conf=$ROOT/board/my355/fsoverlay/usr/share/zlyme/device.conf

grep -q '^ZLYME_OS_DISK=/dev/mmcblk0$' "$conf"
grep -q '^ZLYME_BOOT_DEVICE=/dev/mmcblk0p2$' "$conf"
grep -q '^ZLYME_STORAGE_DEVICE=/dev/mmcblk0p3$' "$conf"
grep -q '^ZLYME_BOOT_LABEL=ZLYMEBOOT$' "$conf"
grep -q '^ZLYME_STORAGE_LABEL=ZLYME$' "$conf"
if grep -n 'mmcblk1' "$init" "$s12" "$s13" "$s15"; then
	echo "a script still names the secondary card" >&2
	exit 1
fi
if grep -n 'S12bootfs)' "$rcs"; then
	echo "rcS still special-cases S12" >&2
	exit 1
fi

awk '
	/\/zlyme-splash \/splash.rgb565/ { splash = NR }
	splash && /select_os_volumes/ && !sel { sel = NR }
	sel && /splash_progress$/ && !call { call = NR }
	END {
		if (!splash || !sel || !call || !(splash < sel && sel < call))
			exit 1
	}
' "$init"
grep -q 'kill -USR1' "$init"
grep -q 'umount /boot_root' "$init"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/cards" "$work/mnt/boot" "$work/mnt/storage" "$work/run"
touch "$work/cards/mmcblk0p2" "$work/cards/mmcblk0p3" \
	"$work/cards/mmcblk1p2" "$work/cards/mmcblk1p3"
pboot=$work/cards/mmcblk0p2
pstor=$work/cards/mmcblk0p3
sboot=$work/cards/mmcblk1p2
sstor=$work/cards/mmcblk1p3

cat > "$work/device.conf" <<EOF
ZLYME_OS_DISK=$work/cards/mmcblk0
ZLYME_BOOT_DEVICE=$pboot
ZLYME_STORAGE_DEVICE=$pstor
ZLYME_BOOT_LABEL=ZLYMEBOOT
ZLYME_STORAGE_LABEL=ZLYME
EOF
cat > "$work/os.conf" <<EOF
ZLYME_STORAGE=$work/mnt/storage
ZLYME_CFG=$work/mnt/storage/.config
ZLYME_DEFAULTS=$work/defaults
ZLYME_BOOT=$work/mnt/boot
EOF
printf '%s\t%s\n' \
	"$pboot" ZLYMEBOOT \
	"$pstor" ZLYME \
	"$sboot" ZLYMEBOOT \
	"$sstor" ZLYME > "$work/blkid.db"
printf 'autoresize=true\n' > "$work/boot.conf"

cat > "$work/bin/blkid" <<'EOF'
#!/bin/sh
set -eu
if [ "$#" -eq 0 ]; then
	printf 'scan\n' >> "$ZLYME_BLKID_SCANS"
	if [ "${ZLYME_BLKID_ORDER:-clone-first}" = primary-first ]; then
		cat "$ZLYME_BLKID_PRIMARY" "$ZLYME_BLKID_CLONE"
	else
		cat "$ZLYME_BLKID_CLONE" "$ZLYME_BLKID_PRIMARY"
	fi
	exit 0
fi
found=$(awk -F '\t' -v d="$1" '$1 == d { print $2; exit }' "$ZLYME_BLKID_DB")
[ -n "$found" ] || exit 1
printf '%s: LABEL="%s" TYPE="fake"\n' "$1" "$found"
EOF
cat > "$work/bin/mount" <<'EOF'
#!/bin/sh
set -eu
opt=
pos1=
pos2=
n=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		-t) shift 2 ;;
		-o) opt=$2; shift 2 ;;
		--move) shift ;;
		-*) shift ;;
		*)
			n=$((n + 1))
			if [ "$n" -eq 1 ]; then pos1=$1; else pos2=$1; fi
			shift
			;;
	esac
done
printf '%s\n' "$pos1" >> "$ZLYME_MOUNT_LOG"
case "$pos1" in
	*mmcblk1*) exit 1 ;;
esac
case "$opt" in
	remount,rw|remount,ro)
		mode=${opt#remount,}
		awk -v mp="$pos1" -v mode="$mode" '
			BEGIN { OFS = " " }
			$2 == mp { $4 = mode }
			{ print }
		' "$ZLYME_PROC_MOUNTS" > "$ZLYME_PROC_MOUNTS.new"
		mv "$ZLYME_PROC_MOUNTS.new" "$ZLYME_PROC_MOUNTS"
		exit 0
		;;
esac
if [ -n "$pos2" ]; then
	printf '%s %s fake rw 0 0\n' "$pos1" "$pos2" >> "$ZLYME_PROC_MOUNTS"
fi
exit 0
EOF
for tool in sgdisk parted mkfs.exfat blockdev reboot; do
	cat > "$work/bin/$tool" <<EOF
#!/bin/sh
printf '%s\n' "$*" >> "$work/tools.log"
exit 1
EOF
	chmod 0755 "$work/bin/$tool"
done
chmod 0755 "$work/bin/blkid" "$work/bin/mount"
awk -F '\t' -v p="$pboot" -v s="$pstor" '$1 == p || $1 == s' "$work/blkid.db" > "$work/primary.blk"
awk -F '\t' -v p="$sboot" -v s="$sstor" '$1 == p || $1 == s' "$work/blkid.db" > "$work/clone.blk"

export PATH="$work/bin:$PATH"
export ZLYME_DEVICE_CONF=$work/device.conf
export ZLYME_PROC_MOUNTS=$work/mounts
export ZLYME_MOUNT_LOG=$work/mount.log
export ZLYME_BLKID_DB=$work/blkid.db
export ZLYME_BLKID_SCANS=$work/scans
export ZLYME_BLKID_PRIMARY=$work/primary.blk
export ZLYME_BLKID_CLONE=$work/clone.blk
export ZLYME_OS_CONF=$work/os.conf
export ZLYME_BOOT_CONF=$work/boot.conf
export ZLYME_RESIZE_LOG=$work/resize.log
export ZLYME_BOOT_TIMING=$work/timing
export ZLYME_BOOT_WRITE_LOCK=$work/run/lock
export ZLYME_RESIZE_TEST=1

reset_io() {
	: > "$work/mount.log"
	: > "$work/scans"
	: > "$work/tools.log"
	: > "$work/mounts"
}

assert_no_clone() {
	if grep -F 'mmcblk1' "$work/mount.log"; then
		echo "clone device was used" >&2
		exit 1
	fi
	if [ -s "$work/scans" ]; then
		echo "label scan was used" >&2
		exit 1
	fi
	if [ -s "$work/tools.log" ]; then
		echo "resize tool ran:" >&2
		cat "$work/tools.log" >&2
		exit 1
	fi
}

for order in clone-first primary-first; do
	reset_io
	out=$(ZLYME_INIT_TEST=1 ZLYME_BLKID_ORDER=$order sh "$init")
	printf '%s\n' "$out" | grep -qx "storage=$pstor"
	printf '%s\n' "$out" | grep -qx "boot=$pboot"
	grep -F -qx "$pboot" "$work/mount.log"
	grep -F -qx "$pstor" "$work/mount.log"
	assert_no_clone
done

reset_io
awk -F '\t' -v p="$pboot" 'BEGIN { OFS = "\t" } $1 == p { $2 = "NOTBOOT" } { print }' \
	"$work/blkid.db" > "$work/blkid.wrongboot"
set +e
out=$(ZLYME_INIT_TEST=1 ZLYME_BLKID_DB=$work/blkid.wrongboot sh "$init" 2>"$work/init.err")
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "wrong boot label still mounted" >&2
	printf '%s\n' "$out" >&2
	exit 1
fi
assert_no_clone

reset_io
awk -F '\t' -v p="$pstor" 'BEGIN { OFS = "\t" } $1 == p { $2 = "NOTZLYME" } { print }' \
	"$work/blkid.db" > "$work/blkid.wrongstor"
out=$(ZLYME_INIT_TEST=1 ZLYME_BLKID_DB=$work/blkid.wrongstor sh "$init")
printf '%s\n' "$out" | grep -qx 'storage=none'
printf '%s\n' "$out" | grep -qx "boot=$pboot"
if grep -F -qx "$pstor" "$work/mount.log" || grep -F -qx "$sstor" "$work/mount.log"; then
	echo "bad storage label was mounted" >&2
	exit 1
fi
assert_no_clone

reset_io
rm -f "$pstor"
out=$(ZLYME_INIT_TEST=1 sh "$init")
printf '%s\n' "$out" | grep -qx 'storage=none'
printf '%s\n' "$out" | grep -qx "boot=$pboot"
assert_no_clone
touch "$pstor"

reset_io
out=$(ZLYME_BOOT=$work/mnt/boot "$s12" start)
printf '%s\n' "$out" | grep -q "OK ($pboot)"
grep -F -qx "$pboot" "$work/mount.log"
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$pboot" "$work/mnt/boot" > "$work/mounts"
out=$(ZLYME_BOOT=$work/mnt/boot "$s12" start)
printf '%s\n' "$out" | grep -q 'already mounted'
grep -F -qx "$work/mnt/boot" "$work/mount.log"
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$sboot" "$work/mnt/boot" > "$work/mounts"
set +e
out=$(ZLYME_BOOT=$work/mnt/boot "$s12" start)
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "S12 accepted the clone boot volume" >&2
	printf '%s\n' "$out" >&2
	exit 1
fi
printf '%s\n' "$out" | grep -q FAIL
if [ -s "$work/mount.log" ]; then
	echo "S12 remounted the clone" >&2
	exit 1
fi
assert_no_clone

reset_io
out=$("$s15" start)
printf '%s\n' "$out" | grep -q "OK ($pstor)"
grep -F -qx "$pstor" "$work/mount.log"
assert_no_clone
i=0
while [ ! -d "$work/mnt/storage/.config" ]; do
	i=$((i + 1))
	if [ "$i" -gt 30 ]; then
		echo "primary storage was not seeded" >&2
		exit 1
	fi
	sleep 0.05
done

reset_io
mkdir -p "$work/mnt/clone"
cat > "$work/clone.conf" <<EOF
ZLYME_STORAGE=$work/mnt/clone
ZLYME_CFG=$work/mnt/clone/.config
ZLYME_DEFAULTS=$work/defaults
ZLYME_BOOT=$work/mnt/boot
EOF
printf '%s %s exfat rw 0 0\n' "$sstor" "$work/mnt/clone" > "$work/mounts"
set +e
out=$(ZLYME_OS_CONF=$work/clone.conf "$s15" start)
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "S15 accepted the clone storage volume" >&2
	printf '%s\n' "$out" >&2
	exit 1
fi
printf '%s\n' "$out" | grep -q FAIL
if [ -d "$work/mnt/clone/.config" ]; then
	echo "S15 seeded the clone" >&2
	exit 1
fi
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$pboot" "$work/mnt/boot" > "$work/mounts"
printf '%s %s exfat rw 0 0\n' "$pstor" "$work/mnt/storage" >> "$work/mounts"
out=$("$s13" start)
printf '%s\n' "$out" | grep -qx "resize=$pstor"
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$pboot" "$work/mnt/boot" > "$work/mounts"
printf '%s %s exfat rw 0 0\n' "$sstor" "$work/mnt/storage" >> "$work/mounts"
out=$("$s13" start || true)
if printf '%s\n' "$out" | grep -q '^resize='; then
	echo "S13 selected a target while storage was the clone" >&2
	printf '%s\n' "$out" >&2
	exit 1
fi
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$sboot" "$work/mnt/boot" > "$work/mounts"
printf '%s %s exfat rw 0 0\n' "$pstor" "$work/mnt/storage" >> "$work/mounts"
out=$("$s13" start || true)
if printf '%s\n' "$out" | grep -q '^resize='; then
	echo "S13 selected a target while boot was the clone" >&2
	exit 1
fi
assert_no_clone

reset_io
printf '%s %s vfat ro 0 0\n' "$sboot" "$work/mnt/boot" > "$work/mounts"
set +e
ZLYME_BOOT=$work/mnt/boot "$writer" true >"$work/writer.out" 2>"$work/writer.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "boot-write opened the clone" >&2
	exit 1
fi
grep -q 'expected' "$work/writer.err"
if [ -s "$work/mount.log" ]; then
	echo "boot-write remounted the clone" >&2
	exit 1
fi

reset_io
printf '%s %s vfat ro 0 0\n' "$pboot" "$work/mnt/boot" > "$work/mounts"
ZLYME_BOOT=$work/mnt/boot "$writer" true
grep -q ' ro ' "$work/mounts"
flock -n "$ZLYME_BOOT_WRITE_LOCK" true
assert_no_clone

echo "boot volume ok"
