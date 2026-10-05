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

# Walk each partition block. A block with in-partition-table = false is
# outside the GPT. The in-table order is the partition numbers.
awk '
function flush() {
	if (name == "")
		return
	if (block ~ /in-partition-table = false/) {
		out_n++
		out_name[out_n] = name
		out_off[name] = offset
	} else {
		gpt_n++
		gpt_name[gpt_n] = name
		gpt_off[name] = offset
		gpt_size[name] = size
	}
	name = ""
	block = ""
	offset = ""
	size = ""
}
$1 == "partition" && $2 ~ /^[A-Za-z0-9_]+$/ {
	flush()
	name = $2
	next
}
name != "" {
	block = block $0 "\n"
	if ($1 == "offset")
		offset = $3
	if ($1 == "size")
		size = $3
	if ($0 ~ /^[[:space:]]*}[[:space:]]*$/)
		flush()
}
END {
	flush()
	if (out_n != 1 || out_name[1] != "idbloader" || out_off["idbloader"] != "32K")
		exit 1
	if (gpt_n != 3)
		exit 1
	if (gpt_name[1] != "uboot" || gpt_off["uboot"] != "8M" || gpt_size["uboot"] != "4M")
		exit 1
	if (gpt_name[2] != "boot" || gpt_off["boot"] != "12M")
		exit 1
	if (gpt_name[3] != "storage")
		exit 1
}
' "$gen" || {
	echo "genimage GPT numbering does not match p1 uboot, p2 boot, p3 storage" >&2
	exit 1
}
grep -q 'label = "ZLYMEBOOT"' "$gen"

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
