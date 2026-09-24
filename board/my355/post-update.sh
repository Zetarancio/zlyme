#!/bin/sh
# OTA hook. Runs from initramfs after the new squashfs is copied onto
# ZLYMEBOOT and before pending is deleted.
#
# Remove a card copy of the retired Autocal tool. Legacy calibration
# data under the storage config directory is left in place.
if [ -e /storage_root/Tools/my355/Autocal.pak ]; then
	rm -rf /storage_root/Tools/my355/Autocal.pak || echo "post-update: Autocal.pak removal failed" >&2
fi
exit 0
