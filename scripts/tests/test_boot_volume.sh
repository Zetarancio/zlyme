#!/bin/sh
# Initramfs must mount the boot volume by label. A partition-number
# shortcut can accept the second card and then skip the label search.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
init=$ROOT/package/boot/zlyme-initramfs/init
if grep -n 'mount_boot /dev/mmcblk' "$init"; then
	echo "initramfs still mounts a boot partition by number" >&2
	exit 1
fi
awk '
	/\/zlyme-splash \/splash.rgb565/ { splash = NR }
	/wait_mount mount_boot "LABEL=/ { label = NR }
	label && /splash_progress$/ && !call { call = NR }
	END {
		if (!splash || !label || !call) {
			print "splash, label mount, or progress signal missing" > "/dev/stderr"
			exit 1
		}
		if (!(splash < label && label < call)) {
			print "splash must start before the label mount, and progress follows it" > "/dev/stderr"
			exit 1
		}
	}
' "$init"
grep -q 'kill -USR1' "$init"
grep -q 'umount /boot_root' "$init"
echo "boot volume ok"
