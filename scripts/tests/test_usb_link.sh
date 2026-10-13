#!/bin/sh
# shellcheck disable=SC1007,SC2002
# Soft-connect decisions for the RK3566 ep0out failure.
# Mocked sysfs only. This does not open the host's USB controllers.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
HELPER=$ROOT/package/system/zlyme-usb-transfer/zlyme-usb-transfer

fail() {
	printf 'usb link: %s\n' "$*" >&2
	exit 1
}

work=$(mktemp -d)
kill_link() {
	for d in /proc/[0-9]*; do
		[ -r "$d/cmdline" ] || continue
		cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
		case "$cmd" in
			*"$HELPER"*" link"*|*"$work/bin/umtprd"*|*"$HELPER"*" reap "*)
				kill -s TERM "${d#/proc/}" 2>/dev/null || true
				;;
		esac
	done
}
trap 'kill_link; rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/udc/fcc00000.usb" "$work/udc/fd000000.usb" \
	"$work/configfs" "$work/storage/Roms" "$work/ffs"
printf '%s\n' 'untouched' > "$work/udc/fd000000.usb/soft_connect"
printf '%s\n' 'not attached' > "$work/udc/fcc00000.usb/state"
: > "$work/dmesg"
printf 'vol0 %s exfat rw 0 0\n' "$work/storage" > "$work/mounts"
printf '%s\n' "$work/storage" > "$work/libraries"

cat > "$work/bin/umtprd" << 'EOF'
#!/bin/sh
conf=
while [ $# -gt 0 ]; do
	if [ "$1" = "-conf" ]; then
		conf=$2
		shift 2
	else
		shift
	fi
done
ep=$(sed -n 's/^usb_epin_path[[:space:]]*"\(.*\)".*/\1/p' "$conf")
dir=$(dirname "$ep")
: > "$dir/ep1"
: > "$dir/ep2"
: > "$dir/ep3"
while :; do
	sleep 30
done
EOF
cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
typ=
prev=
dest=
for a in "$@"; do
	if [ "$prev" = "-t" ]; then
		typ=$a
	fi
	case "$a" in
		-*) ;;
		*) dest=$a ;;
	esac
	prev=$a
done
case "$typ" in
	configfs)
		mkdir -p "$dest/usb_gadget"
		printf '%s %s %s %s %s %s\n' configfs "$dest" configfs rw 0 0 >> "$ZLYME_USB_MOUNTS"
		;;
	functionfs)
		mkdir -p "$dest"
		: > "$dest/ep0"
		printf '%s %s %s %s %s %s\n' ffs "$dest" functionfs rw 0 0 >> "$ZLYME_USB_MOUNTS"
		;;
	*) exit 1 ;;
esac
EOF
cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
dest=
for a in "$@"; do
	dest=$a
done
tmp=$(mktemp)
if [ -f "$ZLYME_USB_MOUNTS" ]; then
	grep -F -v " ${dest} " "$ZLYME_USB_MOUNTS" > "$tmp" || true
else
	: > "$tmp"
fi
mv "$tmp" "$ZLYME_USB_MOUNTS"
if [ "$dest" != "${ZLYME_USB_CONFIGFS:-}" ]; then
	rm -rf "$dest"
fi
EOF
chmod 755 "$work/bin/umtprd" "$work/bin/mount" "$work/bin/umount"

ext=$work/extcon
gadget=$work/configfs/usb_gadget/zlyme-mtp

set_cables() {
	rm -rf "$ext"
	mkdir -p "$ext"
	i=0
	for spec in "$@"; do
		name=${spec%%=*}
		val=${spec#*=}
		mkdir -p "$ext/cable.$i"
		printf '%s\n' "$name" > "$ext/cable.$i/name"
		printf '%s\n' "$val" > "$ext/cable.$i/state"
		i=$((i + 1))
	done
}

zero_cables() {
	set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=0 SLOW-CHARGER=0
}

bind_ours() {
	mkdir -p "$gadget" "$work/run"
	printf '%s\n' fcc00000.usb > "$gadget/UDC"
	printf '%s\n' 'not attached' > "$work/udc/fcc00000.usb/state"
	rm -f "$work/udc/fcc00000.usb/soft_connect"
	: > "$work/udc/fcc00000.usb/soft_connect"
	rm -f "$work/run/link.latch" "$work/run/link.writes" "$work/run/link.err" \
		"$work/run/link.recover"
}

set_host() {
	printf '%s\n' "$1" > "$work/udc/fcc00000.usb/state"
}

latch_is() {
	[ "$(cat "$work/run/link.latch")" = "$1" ] || fail "$2 latch: $(cat "$work/run/link.latch")"
	if [ "$1" = healthy ]; then
		fail "$2 latched healthy"
	fi
}

run_link() {
	ZLYME_USB_RUN="$work/run" \
	ZLYME_USB_CONFIGFS="$work/configfs" \
	ZLYME_USB_UDC_CLASS="$work/udc" \
	ZLYME_USB_MOUNTS="$work/mounts" \
	ZLYME_USB_FFS="$work/ffs" \
	ZLYME_USB_UMTPRD="$work/bin/umtprd" \
	ZLYME_USB_JAIL=0 \
	ZLYME_USB_UDC_NAME=fcc00000.usb \
	ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_USB_STORAGE="$work/storage" \
	ZLYME_USB_SD2="$work/sd2" \
	ZLYME_USB_MOUNT="$work/bin/mount" \
	ZLYME_USB_UMOUNT="$work/bin/umount" \
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_EXTCON="$ext" \
	ZLYME_USB_DMESG="$work/dmesg" \
	ZLYME_USB_EP0="${EP0:-unknown}" \
	ZLYME_USB_LINK_SLEEP=0.05 \
	ZLYME_USB_READY_SLEEP=0 \
	ZLYME_USB_SPAWN_SLEEP=0 \
	ZLYME_USB_REAP_SLEEP=0.05 \
	ZLYME_USB_REAP_WAIT=0.05 \
	"$HELPER" "$@"
}

writes() {
	if [ -f "$work/run/link.writes" ]; then
		cat "$work/run/link.writes"
	fi
}

expect_writes() {
	got=$(writes || true)
	[ "$got" = "$1" ] || fail "$2: writes [$(printf '%s' "$got" | tr '\n' ' ')] want [$(printf '%s' "$1" | tr '\n' ' ')]"
}

other_untouched() {
	got=$(cat "$work/udc/fd000000.usb/soft_connect")
	[ "$got" = untouched ] || fail "foreign UDC soft_connect changed: $got"
	[ "$(cat "$work/udc/fcc00000.usb/state")" = "not attached" ] || fail "UDC state was rewritten"
}

# 1. Not attached, EP0 descriptor class control, DCP. Not a healthy link.
# One disconnect, then silence.
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
bind_ours
EP0=control
run_link link-once
run_link link-once
expect_writes 'disconnect' "control plus dcp"
latch_is idle "control plus dcp"
other_untouched

# 2. Not attached, EP0 class control, SDP already present.
# The bind is the attempt. control is not healthy, and it is not a reset.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=control
run_link link-once
run_link link-once
expect_writes '' "control plus sdp"
latch_is pending "control plus sdp"
other_untouched

# 3. CDP, not attached. Same as SDP: no reset while it stays.
set_cables USB=1 USB-HOST=0 SDP=0 CDP=1 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=control
run_link link-once
run_link link-once
expect_writes '' "control plus cdp"
latch_is pending "control plus cdp"
other_untouched

# 4. No VBUS. One disconnect.
zero_cables
bind_ours
EP0=control
run_link link-once
run_link link-once
expect_writes 'disconnect' "no vbus"
latch_is idle "no vbus"
other_untouched

# 5. DCP, then SDP. The descriptor class does not block the connect.
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
bind_ours
EP0=control
run_link link-once
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "dcp then sdp"
latch_is pending "dcp then sdp"
other_untouched

# 6. Disconnect, then reconnect. One write each way.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=unknown
run_link link-once
zero_cables
run_link link-once
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "replug once"
latch_is pending "replug"
other_untouched

# 7. SDP, then DCP. One disconnect, including after a configured host.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
set_host configured
EP0=control
run_link link-once
run_link link-once
expect_writes '' "configured before unplug"
latch_is configured "configured before unplug"
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes 'disconnect' "sdp then dcp"
latch_is idle "sdp then dcp"
got=$(cat "$work/udc/fd000000.usb/soft_connect")
[ "$got" = untouched ] || fail "foreign UDC soft_connect changed: $got"

# 8. Configured stays configured across repeated calls. No soft_connect.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
set_host configured
EP0=control
run_link link-once
run_link link-once
run_link link-once
expect_writes '' "stable configured"
latch_is configured "stable configured"
set_host suspended
run_link link-once
expect_writes '' "suspended stays"
latch_is configured "suspended"
set_host 'not attached'
run_link link-once
run_link link-once
expect_writes '' "drop without cable loss"
latch_is pending "drop without cable loss"

# 9. EP0 enable failure, then SDP. One recovery, then the connect.
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
bind_ours
EP0=failed
run_link link-once
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "ep0 fail then sdp"
latch_is pending "ep0 fail then sdp"
other_untouched

# 9b. EP0 enable failure while SDP is already present: one pair, then stop.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=failed
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "ep0 fail on sdp"
latch_is pending "ep0 fail on sdp"

# 10. EP0 enable failure and DCP only. Disconnect, never connect.
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
bind_ours
EP0=failed
run_link link-once
run_link link-once
expect_writes 'disconnect' "ep0 fail on dcp"
latch_is idle "ep0 fail on dcp"
other_untouched

# 11. Disconnect write fails once and is not repeated.
zero_cables
bind_ours
rm -f "$work/udc/fcc00000.usb/soft_connect"
ln -s /dev/full "$work/udc/fcc00000.usb/soft_connect"
EP0=control
run_link link-once >/dev/null 2>&1 || fail "disconnect failure aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "disconnect failure retried as an abort"
grep -q 'soft_connect disconnect failed' "$work/run/link.err" || fail "disconnect failure was not recorded"
[ ! -f "$work/run/link.writes" ] || fail "failed disconnect was recorded as a write"
latch_is idle-failed "disconnect failure"
[ "$(cat "$gadget/UDC")" = fcc00000.usb ] || fail "disconnect failure unbound the gadget"

# 12. Connect write fails once after a real disconnect.
zero_cables
bind_ours
EP0=control
run_link link-once
rm -f "$work/udc/fcc00000.usb/soft_connect"
ln -s /dev/full "$work/udc/fcc00000.usb/soft_connect"
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once >/dev/null 2>&1 || fail "connect failure aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "connect failure retried as an abort"
grep -q 'soft_connect connect failed' "$work/run/link.err" || fail "connect failure was not recorded"
expect_writes 'disconnect' "connect failure"
latch_is pending-failed "connect failure"

# 13. No debugfs and no enable error. The descriptor class is not consulted.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=unknown
run_link link-once
run_link link-once
expect_writes '' "no debugfs"
latch_is pending "no debugfs"

# 14. Missing PHY extcon is recorded. The binding stays. No write.
bind_ours
rm -rf "$ext"
EP0=failed
run_link link-once >/dev/null 2>&1 || fail "missing extcon aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "missing extcon aborted the repeat"
grep -q 'extcon' "$work/run/link.err" || fail "missing extcon was not recorded"
[ ! -f "$work/run/link.writes" ] || fail "missing extcon wrote soft_connect"
[ "$(cat "$gadget/UDC")" = fcc00000.usb ] || fail "missing extcon unbound the gadget"
zero_cables

# 15. After a failed recovery, more calls do not write.
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
rm -f "$work/udc/fcc00000.usb/soft_connect"
ln -s /dev/full "$work/udc/fcc00000.usb/soft_connect"
EP0=failed
run_link link-once >/dev/null 2>&1 || fail "recovery failure aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "recovery failure aborted the repeat"
run_link link-once >/dev/null 2>&1 || fail "recovery failure aborted the third call"
latch_is recover-failed "failed recovery"
[ ! -f "$work/run/link.writes" ] || fail "failed recovery recorded a write"
grep -q 'soft_connect disconnect failed' "$work/run/link.err" || fail "recovery failure was not recorded"

# 9. A foreign gadget is not modified. Our gadget is not bound.
rm -rf "$gadget"
mkdir -p "$work/configfs/usb_gadget/other"
printf '%s\n' keep > "$work/configfs/usb_gadget/other/marker"
printf '%s\n' fcc00000.usb > "$work/configfs/usb_gadget/other/UDC"
rm -f "$work/udc/fcc00000.usb/soft_connect"
printf '%s\n' nope > "$work/udc/fcc00000.usb/soft_connect"
EP0=failed
zero_cables
run_link link-once
[ "$(cat "$work/configfs/usb_gadget/other/marker")" = keep ] || fail "foreign marker"
[ "$(cat "$work/configfs/usb_gadget/other/UDC")" = fcc00000.usb ] || fail "foreign UDC"
[ "$(cat "$work/udc/fcc00000.usb/soft_connect")" = nope ] || fail "wrote soft_connect for a foreign gadget"
rm -rf "$work/configfs/usb_gadget/other"

# 13. Missing soft_connect is recorded and the session binding stays.
bind_ours
rm -f "$work/udc/fcc00000.usb/soft_connect"
EP0=failed
zero_cables
run_link link-once >/dev/null 2>&1 || fail "missing soft_connect aborted link-once"
grep -q 'not available' "$work/run/link.err" || fail "missing soft_connect was not recorded"
[ ! -f "$work/run/link.writes" ] || fail "missing soft_connect still wrote"
[ "$(cat "$gadget/UDC")" = fcc00000.usb ] || fail "missing soft_connect unbound the gadget"

# 10 and 15. Start with no cable, then B-style stop leaves no watcher.
zero_cables
: > "$work/udc/fcc00000.usb/soft_connect"
EP0=failed
run_link start >/dev/null
[ -s "$work/run/link.pid" ] || fail "watcher did not start"
pid=$(cat "$work/run/link.pid")
[ -d "/proc/$pid" ] || fail "watcher pid is dead"
grep -qx disconnect "$work/run/link.writes" || fail "start with no cable did not disconnect"
run_link stop >/dev/null
[ ! -d "/proc/$pid" ] || fail "stop left the watcher"
left=0
for d in /proc/[0-9]*; do
	[ -r "$d/cmdline" ] || continue
	cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
	case "$cmd" in
		*"$HELPER"*" link "*|*"$work/bin/umtprd"*) left=$((left + 1)) ;;
	esac
done
[ "$left" = 0 ] || fail "stop left $left usb processes"
[ ! -d "$gadget" ] || fail "stop left the gadget"

# 12. Stop and another link pass serialize. Nothing is written after stop.
zero_cables
EP0=failed
run_link start >/dev/null
i=0
while [ "$i" -lt 8 ]; do
	run_link link-once >/dev/null 2>&1 &
	i=$((i + 1))
done
run_link stop >/dev/null
wait || true
run_link link-once >/dev/null 2>&1 || true
[ ! -d "$gadget" ] || fail "concurrent stop left the gadget"
[ ! -f "$work/run/link.writes" ] || fail "link-once wrote after stop"
left=0
for d in /proc/[0-9]*; do
	[ -r "$d/cmdline" ] || continue
	cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
	case "$cmd" in
		*"$HELPER"*" link "*) left=$((left + 1)) ;;
	esac
done
[ "$left" = 0 ] || fail "concurrent stop left a watcher"

# 11. The watcher shares the starter's process group, so a group kill
# takes it with the PAK. The reaper is outside that group.
zero_cables
EP0=failed
cat > "$work/bin/hold" << EOF
#!/bin/sh
printf '%s\\n' "\$\$" > "$work/hold.pid"
"$HELPER" start
sleep 30
EOF
chmod 755 "$work/bin/hold"
rm -f "$work/hold.pid"
ZLYME_USB_RUN="$work/run" \
ZLYME_USB_CONFIGFS="$work/configfs" \
ZLYME_USB_UDC_CLASS="$work/udc" \
ZLYME_USB_MOUNTS="$work/mounts" \
ZLYME_USB_FFS="$work/ffs" \
ZLYME_USB_UMTPRD="$work/bin/umtprd" \
ZLYME_USB_JAIL=0 \
ZLYME_USB_UDC_NAME=fcc00000.usb \
ZLYME_LIBRARIES_FILE="$work/libraries" \
ZLYME_USB_STORAGE="$work/storage" \
ZLYME_USB_SD2="$work/sd2" \
ZLYME_USB_MOUNT="$work/bin/mount" \
ZLYME_USB_UMOUNT="$work/bin/umount" \
ZLYME_USB_TEST_LAYOUT=1 \
ZLYME_USB_EXTCON="$ext" \
ZLYME_USB_DMESG="$work/dmesg" \
ZLYME_USB_EP0=failed \
ZLYME_USB_LINK_SLEEP=0.05 \
ZLYME_USB_READY_SLEEP=0 \
ZLYME_USB_SPAWN_SLEEP=0 \
ZLYME_USB_REAP_SLEEP=0.05 \
ZLYME_USB_REAP_WAIT=0.05 \
setsid "$work/bin/hold" >/dev/null 2>&1 &
i=0
while [ "$i" -lt 50 ]; do
	[ -s "$work/run/link.pid" ] && [ -s "$work/hold.pid" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -s "$work/run/link.pid" ] || fail "group watcher did not start"
hold=$(cat "$work/hold.pid")
linkpid=$(cat "$work/run/link.pid")
pgrp_of() {
	line=$(cat "/proc/$1/stat")
	rest=${line#*)}
	set -f
	# shellcheck disable=SC2086
	set -- $rest
	set +f
	printf '%s\n' "$3"
}
[ "$(pgrp_of "$linkpid")" = "$(pgrp_of "$hold")" ] || fail "watcher left the starter group"
kill -s TERM -- "-$(pgrp_of "$hold")" 2>/dev/null || true
i=0
while [ "$i" -lt 40 ]; do
	[ -d "/proc/$linkpid" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "/proc/$linkpid" ] || fail "group kill left the watcher"
# The reaper calls stop. Give it a moment to drop the gadget.
i=0
while [ "$i" -lt 40 ]; do
	[ -d "$gadget" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "$gadget" ] || fail "group kill did not stop the gadget"

printf '%s\n' 'usb link ok'
