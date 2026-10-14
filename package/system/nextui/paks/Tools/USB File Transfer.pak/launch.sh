#!/bin/sh
# MTP on the lower USB-C port for this visit only. MENU+START and a
# normal exit both stop the session. Comment out the next line to skip
# this pak's log (About → System logs).
# shellcheck disable=SC1091
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

TRANSFER=${ZLYME_USB_TRANSFER:-/usr/sbin/zlyme-usb-transfer}
PRESENTER=${ZLYME_USB_PRESENTER:-minui-presenter}

cleaned=0
signaled=0
# Invoked from the EXIT trap. A signal leaves the long cleanup to the
# setsid reaper, which is not in this process group. MENU+START kills
# the group 1.5s after SIGTERM, so this trap must not do that work.
# shellcheck disable=SC2317
finish() {
	rc=$1
	if [ "$signaled" = 1 ]; then
		exit 143
	fi
	if [ "$cleaned" = 1 ]; then
		exit "$rc"
	fi
	cleaned=1
	if [ -x "$TRANSFER" ]; then
		err=$("$TRANSFER" stop 2>&1) || {
			present "$(reason_screen "USB file transfer did not stop." "$err")" "OK" "Back" || true
			exit 1
		}
	fi
	exit "$rc"
}

trap 'signaled=1; exit 143' INT TERM HUP
trap 'rc=$?; finish "$rc"' EXIT

# One short reason line. A long helper error would wrap off the
# six-row panel, and a blank line would consume a row by itself.
reason_screen() {
	_title=$1
	_why=$(printf '%s\n' "$2" | head -n 1)
	_why=$(printf '%.32s' "$_why")
	if [ -n "$_why" ]; then
		printf '%s\n%s' "$_title" "$_why"
	else
		printf '%s' "$_title"
	fi
}

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

# The running page has no A button. A is not a stop control there.
present_stop() {
	_msg=$1
	if [ ! -x "$PRESENTER" ] && ! command -v "$PRESENTER" >/dev/null 2>&1; then
		printf '%s\n' "$_msg" >&2
		return 1
	fi
	"$PRESENTER" \
		--message "$_msg" \
		--message-alignment top \
		--cancel-button B --cancel-text "Stop" --cancel-show \
		--timeout 0
}

# Waiting is expected. The one-second timeout is how this page notices
# that the PHY became a data cable. Exit 124 means look again.
present_wait() {
	_msg=$1
	if [ ! -x "$PRESENTER" ] && ! command -v "$PRESENTER" >/dev/null 2>&1; then
		printf '%s\n' "$_msg" >&2
		return 1
	fi
	"$PRESENTER" \
		--message "$_msg" \
		--message-alignment top \
		--cancel-button B --cancel-text "Stop" --cancel-show \
		--timeout 1
}

if [ ! -x "$TRANSFER" ]; then
	present "USB File Transfer is not installed." "OK" "Back"
	exit 1
fi

intro="Connect your computer to the lower USB-C port."

present "$intro" "Start" "Back"
rc=$?
if [ "$rc" -ne 0 ]; then
	exit "$rc"
fi

err=$("$TRANSFER" start 2>&1) || {
	present "$(reason_screen "USB file transfer did not start." "$err")" "OK" "Back"
	exit 1
}

st=$("$TRANSFER" status 2>/dev/null || true)
state=
storage_bits=
while IFS= read -r line; do
	case "$line" in
		state=*) state=${line#state=} ;;
		export_name=*)
			_kind=${line#export_name=}
			[ -n "$_kind" ] || continue
			case ", $storage_bits," in
				*", $_kind,"*) ;;
				*)
					if [ -z "$storage_bits" ]; then
						storage_bits=$_kind
					else
						storage_bits="$storage_bits, $_kind"
					fi
					;;
			esac
			;;
	esac
done <<EOF
$st
EOF
if [ -z "$storage_bits" ]; then
	storage_line="Storage: none."
else
	storage_line="Storage: $storage_bits."
fi

while :; do
	st=$("$TRANSFER" status 2>/dev/null || true)
	state=
	while IFS= read -r line; do
		case "$line" in
			state=*) state=${line#state=} ;;
		esac
	done <<EOF
$st
EOF
	case "$state" in
		waiting)
			present_wait "USB File Transfer
Waiting for a USB data connection."
			rc=$?
			if [ "$rc" -eq 124 ]; then
				continue
			fi
			exit "$rc"
			;;
		bound)
			running="USB File Transfer
Session is open.
$storage_line"
			present_stop "$running"
			exit $?
			;;
		*)
			if [ -n "$state" ]; then
				present "$(reason_screen "USB file transfer did not stay bound." "State: $state.")" "OK" "Back"
			else
				present "USB file transfer did not stay bound." "OK" "Back"
			fi
			exit 1
			;;
	esac
done
