#!/bin/sh
# The second SD slot is the sdmmc1 controller. A blank card is still SD2.
# A USB disk is not SD2, even when it already has a Roms directory.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
bin=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage
if grep -q 'is_library_root' "$bin"; then
	echo "storage still classifies SD2 by library contents" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sys=$work/sys
mkdir -p "$sys/class/block"

link_disk() {
	name=$1
	host=$2
	dest=$sys/devices/platform/$host/mmc_host/mmcX/${name}/block/$name
	mkdir -p "$dest"
	ln -s "../../devices/platform/$host/mmc_host/mmcX/${name}/block/$name" \
		"$sys/class/block/$name"
}

link_disk mmcblk0 fe2b0000.mmc
link_disk mmcblk1 fe2c0000.mmc
link_disk mmcblk2 fe310000.mmc
usb=$sys/devices/platform/usb1/1-1/1-1:1.0/host0/target0:0:0/0:0:0:0/block/sda
mkdir -p "$usb"
ln -s "../../devices/platform/usb1/1-1/1-1:1.0/host0/target0:0:0/0:0:0:0/block/sda" \
	"$sys/class/block/sda"
# No sysfs identity. ID_BUS is the only USB signal.
mkdir -p "$sys/devices/platform/virtual/block/sdb"
ln -s "../../devices/platform/virtual/block/sdb" "$sys/class/block/sdb"

classify() {
	ZLYME_STORAGE_SYSFS=$sys "$bin" classify "$1"
}

test "$(classify mmcblk1)" = secondary-sd
test "$(classify mmcblk1p1)" = secondary-sd
test "$(classify /dev/mmcblk1p1)" = secondary-sd
test "$(classify mmcblk0)" = other
test "$(classify mmcblk2)" = other
test "$(classify sda)" = usb
test "$(classify sda1)" = usb
test "$(ID_BUS=usb classify sdb)" = usb
test "$(classify sdb)" = other
# A Roms directory must not change the answer. Classification never mounts.
mkdir -p "$work/blank" "$work/roms/Roms"
test "$(classify mmcblk1)" = secondary-sd
test "$(classify sda1)" = usb
echo "storage slot ok"
