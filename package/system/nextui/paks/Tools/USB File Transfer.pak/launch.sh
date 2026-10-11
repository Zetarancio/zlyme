#!/bin/sh
# MTP on the lower USB-C port for this visit only. MENU+START and a
# normal exit both stop the session. Comment out the next line to skip
# this pak's log (About → System logs).
# shellcheck disable=SC1091
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

TRANSFER=${ZLYME_USB_TRANSFER:-/usr/sbin/zlyme-usb-transfer}
PRESENTER=${ZLYME_USB_PRESENTER:-minui-presenter}

cleaned=0
# Invoked from the EXIT and signal traps.
# shellcheck disable=SC2317
stop_transfer() {
	[ "$cleaned" = 1 ] && return 0
	cleaned=1
	if [ -x "$TRANSFER" ]; then
		"$TRANSFER" stop >/dev/null 2>&1 || true
	fi
}

trap 'stop_transfer; exit 143' INT TERM HUP
trap 'rc=$?; stop_transfer; exit "$rc"' EXIT

present() {
	_msg=$1
	_confirm=$2
	_cancel=$3
	if [ ! -x "$PRESENTER" ] && ! command -v "$PRESENTER" >/dev/null 2>&1; then
		printf '%s\n' "$_msg" >&2
		return 1
	fi
	"$PRESENTER" \
		--message "$_msg" \
		--message-alignment top \
		--confirm-button A --confirm-text "$_confirm" --confirm-show \
		--cancel-button B --cancel-text "$_cancel" --cancel-show \
		--timeout 0
}

if [ ! -x "$TRANSFER" ]; then
	present "USB File Transfer is not installed." "OK" "Back"
	exit 1
fi

intro="USB file transfer uses MTP on the lower USB-C port. That is the charge port. The upper port stays a USB host.

The computer can add, change, and delete files in the shared ROM and BIOS folders. A mounted second card is included when it has those folders.

The card stays mounted here. This session does not hand the computer the card as a disk.

A starts the session. B goes back."

present "$intro" "Start" "Back"
rc=$?
if [ "$rc" -ne 0 ]; then
	exit "$rc"
fi

err=$("$TRANSFER" start 2>&1) || {
	present "USB file transfer did not start.

$err" "OK" "Back"
	exit 1
}

st=$("$TRANSFER" status 2>/dev/null || true)
state=
host=
shared=
while IFS= read -r line; do
	case "$line" in
		state=*) state=${line#state=} ;;
		host=*) host=${line#host=} ;;
		export=*)
			if [ -z "$shared" ]; then
				shared=${line#export=}
			else
				shared="$shared
${line#export=}"
			fi
			;;
	esac
done <<EOF
$st
EOF

case "$host" in
	configured)
		host_line="A computer has configured the USB gadget."
		;;
	unknown)
		host_line="Whether a computer has configured the gadget is not visible."
		;;
	unbound)
		host_line="The USB gadget is not bound."
		;;
	*)
		host_line="USB state is: $host. That does not by itself mean a computer is connected."
		;;
esac

if [ "$state" != bound ]; then
	present "USB file transfer did not stay bound.

$st" "OK" "Back"
	exit 1
fi

present "MTP is on. Use the lower USB-C port.

Shared folders:
$shared

$host_line

B stops the session and returns to the menu. MENU+START does the same." "Stop" "Stop"
exit $?
