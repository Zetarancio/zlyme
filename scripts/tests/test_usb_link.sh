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

# Mocked sysfs only. A bind line is a configfs UDC write, not enumeration.

quiet_stop() {
	run_link stop >/dev/null 2>&1 || true
	kill_link
	rm -rf "$work/run" "$work/configfs/usb_gadget" "$work/ffs"
	mkdir -p "$work/configfs" "$work/ffs"
	printf 'vol0 %s exfat rw 0 0\n' "$work/storage" > "$work/mounts"
	printf '%s\n' 'not attached' > "$work/udc/fcc00000.usb/state"
	rm -f "$work/udc/fcc00000.usb/soft_connect"
	printf '%s\n' idle > "$work/udc/fcc00000.usb/soft_connect"
	: > "$work/dmesg"
	EP0=unknown
}

udc_value() {
	if [ -f "$gadget/UDC" ]; then
		tr -d '[:space:]' < "$gadget/UDC"
	fi
}

expect_unbound() {
	got=$(udc_value || true)
	[ -z "$got" ] || fail "$1 bound the UDC ($got)"
	[ ! -s "$work/run/link.binds" ] || fail "$1 recorded a bind: $(cat "$work/run/link.binds")"
}

expect_one_bind() {
	[ -f "$work/run/link.binds" ] || fail "$1 did not bind"
	got=$(cat "$work/run/link.binds")
	[ "$got" = bind ] || fail "$1 binds [$(printf '%s' "$got" | tr '\n' ' ')]"
	[ "$(udc_value)" = fcc00000.usb ] || fail "$1 UDC is $(udc_value)"
}

status_is() {
	got=$(run_link status)
	printf '%s\n' "$got" | grep -qx "state=$1" || fail "$2 status: $got"
}

no_usb_left() {
	left=0
	for d in /proc/[0-9]*; do
		[ -r "$d/cmdline" ] || continue
		cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
		case "$cmd" in
			*"$HELPER"*" link "*|*"$work/bin/umtprd"*) left=$((left + 1)) ;;
		esac
	done
	[ "$left" = 0 ] || fail "$1 left $left usb processes"
	[ ! -d "$gadget" ] || fail "$1 left the gadget"
}

wait_bound() {
	i=0
	while [ "$i" -lt 40 ]; do
		[ "$(udc_value)" = fcc00000.usb ] && return 0
		i=$((i + 1))
		sleep 0.05
	done
	fail "$1 did not bind"
}

# SDP already present: one configfs bind, no soft_connect.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
EP0=control
run_link start >/dev/null
status_is bound "sdp start"
expect_one_bind "sdp start"
expect_writes '' "sdp start"
latch_is pending "sdp start"
run_link link-once
expect_one_bind "sdp repeat"
expect_writes '' "sdp repeat"
other_untouched
run_link start >/dev/null
expect_one_bind "second start"
run_link stop >/dev/null
no_usb_left "sdp stop"
run_link stop >/dev/null
no_usb_left "second stop"

# CDP already present: one bind.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=0 CDP=1 DCP=0 SLOW-CHARGER=0
EP0=unknown
run_link start >/dev/null
status_is bound "cdp start"
expect_one_bind "cdp start"
expect_writes '' "cdp start"
latch_is pending "cdp start"
other_untouched

# DCP: prepared, not bound.
quiet_stop
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
EP0=failed
run_link start >/dev/null
status_is waiting "dcp start"
expect_unbound "dcp start"
expect_writes '' "dcp start"
latch_is waiting "dcp start"
[ -s "$work/run/link.pid" ] || fail "dcp watcher did not start"
pid=$(cat "$work/run/link.pid")
[ -d "/proc/$pid" ] || fail "dcp watcher is dead"
run_link link-once
expect_unbound "dcp repeat"
run_link stop >/dev/null
no_usb_left "dcp stop"
[ ! -d "/proc/$pid" ] || fail "dcp stop left the watcher"

# No cable names at all. That is not a missing extcon directory.
quiet_stop
rm -rf "$ext"
mkdir -p "$ext"
EP0=unknown
run_link start >/dev/null
status_is waiting "no cable"
expect_unbound "no cable"
latch_is waiting "no cable"

# Charger detection has not finished: every cable reads 0.
quiet_stop
zero_cables
EP0=unknown
run_link start >/dev/null
status_is waiting "incomplete"
expect_unbound "incomplete"
latch_is waiting "incomplete"

# DCP, then SDP. The watcher binds once. soft_connect stays idle.
quiet_stop
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
EP0=control
run_link start >/dev/null
expect_unbound "before sdp"
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
wait_bound "dcp then sdp"
sleep 0.2
expect_one_bind "dcp then sdp"
expect_writes '' "dcp then sdp"
latch_is pending "dcp then sdp"
[ "$(cat "$work/udc/fcc00000.usb/soft_connect")" = idle ] || fail "dcp then sdp wrote soft_connect"

# No cable, then CDP. One bind.
quiet_stop
zero_cables
EP0=unknown
run_link start >/dev/null
expect_unbound "before cdp"
set_cables USB=1 USB-HOST=0 SDP=0 CDP=1 DCP=0 SLOW-CHARGER=0
wait_bound "no cable then cdp"
sleep 0.2
expect_one_bind "no cable then cdp"
expect_writes '' "no cable then cdp"

# Missing extcon fails the start. It is not treated as DCP.
quiet_stop
rm -rf "$ext"
EP0=unknown
if run_link start >"$work/miss.out" 2>"$work/miss.err"; then
	fail "missing extcon started"
fi
grep -q 'extcon' "$work/miss.err" || fail "missing extcon reason: $(cat "$work/miss.err")"
[ ! -d "$gadget" ] || fail "missing extcon left the gadget"
no_usb_left "missing extcon"
printf '%s\n' x > "$ext"
if run_link start >"$work/bad.out" 2>"$work/bad.err"; then
	fail "file extcon started"
fi
grep -q 'extcon' "$work/bad.err" || fail "file extcon reason: $(cat "$work/bad.err")"
rm -f "$ext"
mkdir -p "$ext"

# Another gadget owns the controller. Nothing of ours is written.
quiet_stop
mkdir -p "$work/configfs/usb_gadget/other"
printf '%s\n' keep > "$work/configfs/usb_gadget/other/marker"
printf '%s\n' fcc00000.usb > "$work/configfs/usb_gadget/other/UDC"
printf '%s\n' nope > "$work/udc/fcc00000.usb/soft_connect"
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
if run_link start >"$work/foreign.out" 2>"$work/foreign.err"; then
	fail "start replaced a foreign gadget"
fi
[ "$(cat "$work/configfs/usb_gadget/other/marker")" = keep ] || fail "foreign marker"
[ "$(cat "$work/configfs/usb_gadget/other/UDC")" = fcc00000.usb ] || fail "foreign UDC"
[ "$(cat "$work/udc/fcc00000.usb/soft_connect")" = nope ] || fail "wrote soft_connect for a foreign gadget"
[ ! -d "$gadget" ] || fail "foreign start created our gadget"
rm -rf "$work/configfs/usb_gadget/other"

# Bound and configured: a later DCP reading does not disconnect.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
EP0=control
run_link start >/dev/null
set_host configured
run_link link-once
run_link link-once
expect_writes '' "stable configured"
latch_is configured "stable configured"
expect_one_bind "stable configured"
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes '' "configured dcp"
latch_is configured "configured dcp"
set_host suspended
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once
expect_writes '' "suspended"
latch_is configured "suspended"

# Real unplug drops the host state. One disconnect, then one connect.
set_host 'not attached'
zero_cables
run_link link-once
run_link link-once
expect_writes 'disconnect' "unplug"
latch_is idle "unplug"
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "replug"
latch_is pending "replug"
[ "$(cat "$work/udc/fd000000.usb/soft_connect")" = untouched ] || fail "replug touched the other UDC"

# EP0 enable failure while SDP is already present: one recovery, then stop.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
EP0=failed
run_link start >/dev/null
expect_one_bind "ep0 sdp"
expect_writes 'disconnect
connect' "ep0 sdp"
latch_is pending "ep0 sdp"
[ -f "$work/run/link.recover" ] || fail "ep0 sdp did not record the recovery"
run_link link-once
expect_writes 'disconnect
connect' "ep0 sdp repeat"
other_untouched

# EP0 enable failure on an already-bound gadget that is not configured.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
EP0=failed
run_link link-once
run_link link-once
expect_writes 'disconnect
connect' "ep0 bound"
latch_is pending "ep0 bound"

# A configured gadget does not recover, even if the enable error is set.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
set_host configured
EP0=failed
run_link link-once
run_link link-once
expect_writes '' "ep0 configured"
latch_is configured "ep0 configured"

# Disconnect write fails once and is not repeated.
quiet_stop
zero_cables
bind_ours
rm -f "$work/udc/fcc00000.usb/soft_connect"
ln -s /dev/full "$work/udc/fcc00000.usb/soft_connect"
EP0=control
run_link link-once >/dev/null 2>&1 || fail "disconnect failure aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "disconnect failure retried as an abort"
grep -q 'soft_connect disconnect failed' "$work/run/link.err" || fail "disconnect failure was not recorded"
[ ! -s "$work/run/link.writes" ] || fail "failed disconnect was recorded as a write"
latch_is idle-failed "disconnect failure"
[ "$(cat "$gadget/UDC")" = fcc00000.usb ] || fail "disconnect failure unbound the gadget"

# Connect write fails once after a real disconnect.
quiet_stop
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

# Missing extcon after a bind is recorded. The binding stays. No write.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
rm -rf "$ext"
EP0=failed
run_link link-once >/dev/null 2>&1 || fail "missing extcon aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "missing extcon aborted the repeat"
grep -q 'extcon' "$work/run/link.err" || fail "missing extcon was not recorded"
[ ! -s "$work/run/link.writes" ] || fail "missing extcon wrote soft_connect"
[ "$(cat "$gadget/UDC")" = fcc00000.usb ] || fail "missing extcon unbound the gadget"
mkdir -p "$ext"

# Recovery write fails once.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
bind_ours
rm -f "$work/udc/fcc00000.usb/soft_connect"
ln -s /dev/full "$work/udc/fcc00000.usb/soft_connect"
EP0=failed
run_link link-once >/dev/null 2>&1 || fail "recovery failure aborted link-once"
run_link link-once >/dev/null 2>&1 || fail "recovery failure aborted the repeat"
latch_is recover-failed "failed recovery"
[ ! -s "$work/run/link.writes" ] || fail "failed recovery recorded a write"
grep -q 'soft_connect disconnect failed' "$work/run/link.err" || fail "recovery failure was not recorded"

# A foreign owner that appears while we are waiting is not touched.
quiet_stop
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
EP0=unknown
run_link start >/dev/null
mkdir -p "$work/configfs/usb_gadget/other"
printf '%s\n' fcc00000.usb > "$work/configfs/usb_gadget/other/UDC"
printf '%s\n' nope > "$work/udc/fcc00000.usb/soft_connect"
run_link link-once
expect_unbound "waiting foreign"
[ "$(cat "$work/configfs/usb_gadget/other/UDC")" = fcc00000.usb ] || fail "waiting foreign UDC changed"
[ "$(cat "$work/udc/fcc00000.usb/soft_connect")" = nope ] || fail "waiting foreign wrote soft_connect"
rm -rf "$work/configfs/usb_gadget/other"
run_link stop >/dev/null

# The responder exiting while we wait removes the prepared session.
quiet_stop
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
EP0=unknown
run_link start >/dev/null
status_is waiting "before responder exit"
rpid=$(cat "$work/run/responder.pid")
kill -s KILL "$rpid" 2>/dev/null || true
i=0
while [ "$i" -lt 40 ]; do
	[ -d "$gadget" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "$gadget" ] || fail "responder exit left the gadget"
no_usb_left "responder exit"

# B during a configured session is stop. The watcher and responder go.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
EP0=unknown
run_link start >/dev/null
set_host configured
run_link link-once
status_is bound "configured stop"
run_link stop >/dev/null
no_usb_left "configured stop"
[ ! -f "$work/run/link.recover" ] || fail "stop left link.recover"

# Stop and another link pass serialize. Nothing is written after stop.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
EP0=unknown
run_link start >/dev/null
i=0
while [ "$i" -lt 8 ]; do
	run_link link-once >/dev/null 2>&1 &
	i=$((i + 1))
done
run_link stop >/dev/null
wait || true
run_link link-once >/dev/null 2>&1 || true
no_usb_left "concurrent stop"
[ ! -f "$work/run/link.writes" ] || fail "link-once wrote after stop"

# MENU+START while waiting. The watcher shares the starter group.
# The reaper is outside it and removes the prepared gadget.
quiet_stop
set_cables USB=0 USB-HOST=0 SDP=0 CDP=0 DCP=1 SLOW-CHARGER=0
EP0=unknown
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
ZLYME_USB_EP0=unknown \
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
[ -s "$work/run/link.pid" ] || fail "waiting group watcher did not start"
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
[ "$(pgrp_of "$linkpid")" = "$(pgrp_of "$hold")" ] || fail "waiting watcher left the starter group"
[ "$(cat "$work/run/link.latch")" = waiting ] || fail "group start bound while DCP"
kill -s TERM -- "-$(pgrp_of "$hold")" 2>/dev/null || true
i=0
while [ "$i" -lt 40 ]; do
	[ -d "/proc/$linkpid" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "/proc/$linkpid" ] || fail "waiting group kill left the watcher"
i=0
while [ "$i" -lt 40 ]; do
	[ -d "$gadget" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "$gadget" ] || fail "waiting group kill did not stop the gadget"

# MENU+START while the host has configured the gadget.
quiet_stop
set_cables USB=1 USB-HOST=0 SDP=1 CDP=0 DCP=0 SLOW-CHARGER=0
printf '%s\n' configured > "$work/udc/fcc00000.usb/state"
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
ZLYME_USB_EP0=unknown \
ZLYME_USB_LINK_SLEEP=0.05 \
ZLYME_USB_READY_SLEEP=0 \
ZLYME_USB_SPAWN_SLEEP=0 \
ZLYME_USB_REAP_SLEEP=0.05 \
ZLYME_USB_REAP_WAIT=0.05 \
setsid "$work/bin/hold" >/dev/null 2>&1 &
i=0
while [ "$i" -lt 50 ]; do
	[ -s "$work/run/link.latch" ] && [ -s "$work/hold.pid" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ "$(cat "$work/run/link.latch" 2>/dev/null || true)" = configured ] \
	|| fail "configured group latch: $(cat "$work/run/link.latch" 2>/dev/null || true)"
[ ! -s "$work/run/link.writes" ] || fail "configured group wrote soft_connect"
hold=$(cat "$work/hold.pid")
linkpid=$(cat "$work/run/link.pid")
kill -s TERM -- "-$(pgrp_of "$hold")" 2>/dev/null || true
i=0
while [ "$i" -lt 40 ]; do
	[ -d "$gadget" ] || break
	i=$((i + 1))
	sleep 0.05
done
[ ! -d "$gadget" ] || fail "configured group kill did not stop the gadget"
[ ! -d "/proc/$linkpid" ] || fail "configured group kill left the watcher"

printf '%s\n' 'usb link ok'
