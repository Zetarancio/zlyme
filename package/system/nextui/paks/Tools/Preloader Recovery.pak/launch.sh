#!/bin/sh
# Preloader Recovery. Two destructive operations, both default to cancel.
set -u

[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
printf '%s' /storage > /tmp/last.txt

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
items=$work/items
out=$work/out

show_message() {
	minui-presenter \
		--message "$1" \
		--message-alignment top \
		--confirm-button A --confirm-text "OK" --confirm-show \
		>/dev/null 2>&1 || true
}

# First line is the default selection. It is always cancel.
choose() {
	title=$1
	confirm=$2
	shift 2
	: >"$items"
	printf '%s\n' "$@" >"$items"
	: >"$out"
	minui-list \
		--format text \
		--file "$items" \
		--title "$title" \
		--confirm-text "$confirm" \
		--cancel-text "BACK" \
		--write-location "$out" >/dev/null 2>&1
	rc=$?
	case "$rc" in
		0|4) cat "$out" ;;
		*) printf '%s\n' "Cancel" ;;
	esac
}

[ -x /usr/sbin/zlyme-preloader ] || {
	show_message "Preloader recovery is not installed."
	exit 1
}

status=$(/usr/sbin/zlyme-preloader status 2>&1 || true)
show_message "$status"

pick=$(choose "Preloader Recovery" "SELECT" \
	"Cancel" \
	"Restore stock preloader" \
	"Erase preloader")
case "$pick" in
	"Restore stock preloader")
		show_message "Restore stock preloader

This writes the original preloader backup back to internal NAND.

The backup is mtd5-original-<sha256>.img on the ZLYMEBOOT card. The current preloader is saved first. A failed write is not reported as success.

Cancel is the next default."
		ok=$(choose "Restore stock preloader" "RESTORE" \
			"Cancel" \
			"RESTORE STOCK PRELOADER")
		[ "$ok" = "RESTORE STOCK PRELOADER" ] || exit 0
		result=$work/result
		if /usr/sbin/zlyme-preloader restore >"$result" 2>&1; then
			show_message "Restore finished. The readback hash matched the backup."
		elif grep -q 'previous preloader restored and verified' "$result"; then
			show_message "Restore failed; previous preloader restored and verified."
			exit 1
		else
			show_message "CRITICAL: restore failed and rollback could not be verified.

Do not assume internal boot works.
The backup is preserved under /storage/.config/zlyme/preloader-backups/.
MASKROM/xrock recovery may be required."
			exit 1
		fi
		;;
	"Erase preloader")
		show_message "ERASE PRELOADER

This erases the preloader on internal NAND.

After the next power-on the Flip is expected to enter MASKROM instead of booting from the SD card. Zlyme will not reboot.

The current preloader is saved first. Cancel is the next default."
		ok=$(choose "ERASE PRELOADER" "ERASE" \
			"Cancel" \
			"ERASE PRELOADER TO MASKROM")
		[ "$ok" = "ERASE PRELOADER TO MASKROM" ] || exit 0
		result=$work/result
		if /usr/sbin/zlyme-preloader erase-maskrom >"$result" 2>&1; then
			show_message "Preloader erase finished. Leave the device powered on until you choose the next power action. MASKROM is expected on the next power-on."
		elif grep -q 'previous preloader restored and verified' "$result"; then
			show_message "Erase failed; previous preloader restored and verified."
			exit 1
		else
			show_message "CRITICAL: erase failed and rollback could not be verified.

Do not assume internal boot works.
The backup is preserved under /storage/.config/zlyme/preloader-backups/.
MASKROM/xrock recovery may be required."
			exit 1
		fi
		;;
	*)
		exit 0
		;;
esac
