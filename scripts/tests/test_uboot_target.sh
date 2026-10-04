#!/bin/sh
# Bootloader target resolution uses the disk behind /boot. A second
# disk named uboot is never selected. Nothing here raw-writes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
UPDATE=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update
CONF=$ROOT/board/my355/fsoverlay/usr/share/zlyme/device.conf
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

add_disk() {
	disk=$1
	mkdir -p "$work/sys/devices/$disk/$disk/queue" "$work/sys/class/block"
	ln -sfn "../../devices/$disk/$disk" "$work/sys/class/block/$disk"
	printf '512\n' > "$work/sys/devices/$disk/$disk/queue/logical_block_size"
}

add_part() {
	disk=$1
	part=$2
	start=$3
	sectors=$4
	label=$5
	base=$work/sys/devices/$disk/$disk/$part
	mkdir -p "$base"
	ln -sfn "../../devices/$disk/$disk/$part" "$work/sys/class/block/$part"
	printf '1\n' > "$base/partition"
	printf 'PARTNAME=%s\n' "$label" > "$base/uevent"
	printf '%s\n' "$start" > "$base/start"
	printf '%s\n' "$sectors" > "$base/size"
}

mount_boot() {
	printf '/dev/%s /boot vfat ro 0 0\n' "$1" > "$work/mounts"
}

run_target() {
	ZLYME_UPDATE_TEST=1 \
	ZLYME_DEVICE_CONF=$CONF \
	ZLYME_SYS_BLOCK=$work/sys/class/block \
	ZLYME_PROC_MOUNTS=$work/mounts \
	ZLYME_UBOOT_LOADER_BYTES=${1:-4096} \
	ZLYME_UBOOT_FIT_BYTES=${2:-4096} \
		"$UPDATE" uboot-target
}

expect_ok() {
	out=$work/out
	if ! run_target >"$out" 2>"$work/err"; then
		echo "expected a target, got:" >&2
		cat "$work/err" >&2
		exit 1
	fi
	grep -qx 'disk=/dev/mmcblk0' "$out"
	grep -qx 'part=/dev/mmcblk0p1' "$out"
	grep -qx 'start=16384' "$out"
	if grep -q '/dev/mmcblk1' "$out"; then
		echo "second disk was selected" >&2
		cat "$out" >&2
		exit 1
	fi
}

expect_fail() {
	if run_target >"$work/out" 2>"$work/err"; then
		echo "expected refusal, selected:" >&2
		cat "$work/out" >&2
		exit 1
	fi
	if grep -q '/dev/mmcblk1' "$work/out" 2>/dev/null; then
		echo "failure still printed the second disk" >&2
		exit 1
	fi
}

rm -rf "$work/sys" "$work/mounts"
add_disk mmcblk0
add_part mmcblk0 mmcblk0p1 16384 8192 uboot
add_part mmcblk0 mmcblk0p2 32768 262144 boot
mount_boot mmcblk0p2
expect_ok

add_disk mmcblk1
add_part mmcblk1 mmcblk1p1 16384 8192 uboot
add_part mmcblk1 mmcblk1p2 32768 262144 boot
expect_ok

mount_boot mmcblk1p2
expect_fail
mount_boot mmcblk0p2
expect_ok

mount_boot mmcblk0p1
expect_fail
mount_boot mmcblk0p2
expect_ok

printf '4096\n' > "$work/sys/devices/mmcblk0/mmcblk0/queue/logical_block_size"
expect_fail
printf '512\n' > "$work/sys/devices/mmcblk0/mmcblk0/queue/logical_block_size"
expect_ok

rm -f "$work/sys/devices/mmcblk0/mmcblk0/queue/logical_block_size"
expect_fail
printf '512\n' > "$work/sys/devices/mmcblk0/mmcblk0/queue/logical_block_size"
expect_ok

rm -f "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p1/uevent"
printf 'PARTNAME=boot\n' > "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p1/uevent"
expect_fail
printf 'PARTNAME=uboot\n' > "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p1/uevent"

add_part mmcblk0 mmcblk0p5 16384 8192 uboot
expect_fail
rm -rf "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p5"
rm -f "$work/sys/class/block/mmcblk0p5"
expect_ok

printf '100\n' > "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p1/start"
expect_fail
printf '16384\n' > "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p1/start"

if run_target 4096 $((8192 * 512 + 1)) >"$work/out" 2>"$work/err"; then
	echo "oversized FIT was accepted" >&2
	exit 1
fi
if run_target $(( (16384 - 64) * 512 + 1 )) 4096 >"$work/out" 2>"$work/err"; then
	echo "idbloader past the partition gap was accepted" >&2
	exit 1
fi

rm -rf "$work/sys/devices/mmcblk0/mmcblk0/mmcblk0p2"
mkdir -p "$work/sys/devices/orphan"
ln -sfn "../../devices/orphan" "$work/sys/class/block/mmcblk0p2"
printf '1\n' > "$work/sys/devices/orphan/partition"
expect_fail

echo "uboot target ok"
