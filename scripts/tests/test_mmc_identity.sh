#!/bin/sh
# The my355 boot disk is mmcblk0 because the DTS aliases say so, and
# the GPT layout makes p2 the boot FAT and p3 the storage exFAT.
# This is a fixed-string check, not a DTS or genimage parser.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
dts=$ROOT/board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts
conf=$ROOT/board/my355/fsoverlay/usr/share/zlyme/device.conf
gen=$ROOT/board/my355/genimage.cfg
ext=$ROOT/board/my355/extlinux.conf

grep -q 'mmc0 = &sdmmc0;' "$dts"
grep -q 'mmc1 = &sdmmc1;' "$dts"
grep -q '^ZLYME_OS_DISK=/dev/mmcblk0$' "$conf"
grep -q '^ZLYME_BOOT_DEVICE=/dev/mmcblk0p2$' "$conf"
grep -q '^ZLYME_STORAGE_DEVICE=/dev/mmcblk0p3$' "$conf"
grep -q '^ZLYME_BOOT_LABEL=ZLYMEBOOT$' "$conf"

awk '
	$1 == "partition" && $2 == "uboot" { u = NR }
	$1 == "partition" && $2 == "boot" { b = NR }
	$1 == "partition" && $2 == "storage" { s = NR }
	END {
		if (!(u && b && s && u < b && b < s))
			exit 1
	}
' "$gen"
grep -q 'offset = 8M' "$gen"
grep -q 'size = 4M' "$gen"
grep -q 'offset = 12M' "$gen"
grep -q 'label = "ZLYMEBOOT"' "$gen"
grep -q 'in-partition-table = false' "$gen"

append=$(sed -n 's/^[[:space:]]*APPEND //p' "$ext")
if [ "$append" != "earlycon quiet console=ttyS2,1500000n8" ]; then
	echo "extlinux APPEND is: $append" >&2
	exit 1
fi
case "$append" in
	*label=*)
		echo "kernel command line still carries label=" >&2
		exit 1
		;;
esac

echo "mmc identity ok"
