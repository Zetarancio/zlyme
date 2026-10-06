#!/bin/sh
# OTA hook. Runs from initramfs after the new squashfs is copied onto
# ZLYMEBOOT and before pending is deleted.
#
# Remove released Autocal and the old serial-joypad config. Also remove
# a hot-copied old module if one was left under the Zlyme config tree.
# Stale stock Tools copied onto the OS card by older images are removed
# by exact path. The old Wine prefix image is one exact file. It is not
# opened and it is not a directory. Weston, user artwork, cheats, and
# ScrapeGoat state stay.
# Tests may set ZLYME_STORAGE_ROOT. The current gamepad config stays.
root=${ZLYME_STORAGE_ROOT:-/storage_root}

remove() {
	if [ -e "$1" ]; then
		rm -rf "$1" || echo "post-update: failed to remove $1" >&2
	fi
}

remove "$root/Tools/my355/Autocal.pak"
remove "$root/Tools/my355/Weston.pak"
remove "$root/Tools/my355/Artwork Scraper.pak"
remove "$root/Tools/my355/Cheat Downloader.pak"
remove "$root/Tools/my355/ScrapeGoat.pak"
remove "$root/.config/miyoo-serial-joypad"
remove "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
legacy="$root/.config/nextui/my355/wine-prefix.ext4"
if [ -f "$legacy" ]; then
	rm -f "$legacy" || echo "post-update: failed to remove $legacy" >&2
fi
exit 0
