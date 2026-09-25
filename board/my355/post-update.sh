#!/bin/sh
# OTA hook. Runs from initramfs after the new squashfs is copied onto
# ZLYMEBOOT and before pending is deleted.
#
# Remove released Autocal and the old serial-joypad config. Also remove
# a hot-copied old module if one was left under the Zlyme config tree.
# Tests may set ZLYME_STORAGE_ROOT. The current gamepad config stays.
root=${ZLYME_STORAGE_ROOT:-/storage_root}

remove() {
	if [ -e "$1" ]; then
		rm -rf "$1" || echo "post-update: failed to remove $1" >&2
	fi
}

remove "$root/Tools/my355/Autocal.pak"
remove "$root/.config/miyoo-serial-joypad"
remove "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
exit 0
