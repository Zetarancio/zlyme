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
remove "$root/Tools/my355/Preloader Recovery.pak"
remove "$root/.config/miyoo-serial-joypad"
remove "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
legacy="$root/.config/nextui/my355/wine-prefix.ext4"
if [ -f "$legacy" ]; then
	rm -f "$legacy" || echo "post-update: failed to remove $legacy" >&2
fi

# USB File Transfer.pak is the stock tool through zlyme44.3 and the
# 44.4 candidates before the rename. The next session copies
# USB Transfer.pak and leaves extras in place, so this hook is what
# stops both names from showing. A tree that still matches the shipped
# files is removed. Anything else moves out of Tools, and an existing
# backup is left where it is.
usb_old="$root/Tools/my355/USB File Transfer.pak"
# sha256 of the two stock files. Same bytes in zlyme44.3 and 95d086e.
usb_launch_sum=9fcbe7d8b4ce10e144b3febec9e3ef4481f9222179c90d3f05169bea5865a49c
usb_license_sum=31f7ea79d41de2929e12fa99f634754788a6f1260185ef7caec08d9f5e3fbdc3

under_storage() {
	case "$1" in
		"$root" | "$root"/*) return 0 ;;
	esac
	return 1
}

usb_is_stock() {
	[ -d "$usb_old" ] || return 1
	[ -L "$usb_old" ] && return 1
	found_launch=0
	found_license=0
	n=0
	# Globs do not follow symlinks. A dotfile, a subdirectory, or a
	# symlink is not the shipped tree.
	for ent in "$usb_old"/* "$usb_old"/.[!.]* "$usb_old"/..?*; do
		if [ ! -e "$ent" ] && [ ! -L "$ent" ]; then
			continue
		fi
		n=$((n + 1))
		if [ -L "$ent" ]; then
			return 1
		fi
		base=$(basename "$ent")
		case "$base" in
			launch.sh)
				[ -f "$ent" ] || return 1
				sum=$(sha256sum "$ent" | awk '{print $1}')
				[ "$sum" = "$usb_launch_sum" ] || return 1
				found_launch=1
				;;
			LICENSE)
				[ -f "$ent" ] || return 1
				sum=$(sha256sum "$ent" | awk '{print $1}')
				[ "$sum" = "$usb_license_sum" ] || return 1
				found_license=1
				;;
			*)
				return 1
				;;
		esac
	done
	[ "$n" -eq 2 ] && [ "$found_launch" = 1 ] && [ "$found_license" = 1 ]
}

retire_usb() {
	dest_root="$root/.config/zlyme/retired-paks"
	under_storage "$dest_root" || return 1
	mkdir -p "$dest_root" || return 1
	dest="$dest_root/USB File Transfer.pak"
	n=1
	while [ -e "$dest" ] || [ -L "$dest" ]; do
		n=$((n + 1))
		dest="$dest_root/USB File Transfer.pak.$n"
	done
	mv "$usb_old" "$dest"
}

if [ -e "$usb_old" ] || [ -L "$usb_old" ]; then
	if under_storage "$usb_old" && usb_is_stock; then
		rm -rf "$usb_old" || echo "post-update: failed to remove $usb_old" >&2
	elif under_storage "$usb_old"; then
		retire_usb || echo "post-update: failed to retire $usb_old" >&2
	fi
fi
exit 0
