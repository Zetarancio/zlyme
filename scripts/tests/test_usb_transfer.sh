#!/bin/sh
# shellcheck disable=SC1007
# Host tests for zlyme-usb-transfer. Fake configfs, UDC, mounts, and
# responder. Nothing here touches the host's USB controllers.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
HELPER=$ROOT/package/system/zlyme-usb-transfer/zlyme-usb-transfer
PAK="$ROOT/package/system/nextui/paks/Tools/USB File Transfer.pak/launch.sh"

fail() {
	printf 'usb transfer: %s\n' "$*" >&2
	exit 1
}

work=$(mktemp -d)
kill_responders() {
	for d in /proc/[0-9]*; do
		[ -r "$d/cmdline" ] || continue
		# shellcheck disable=SC2002 # cat avoids a set -e abort when /proc/pid disappears mid-read.
		cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
		case "$cmd" in
			*"$work/bin/umtprd"*|*"$HELPER"*" reap "*)
				kill -s TERM "${d#/proc/}" 2>/dev/null || true
				;;
		esac
	done
}
trap 'kill_responders; rm -rf "$work"' EXIT

mkdir -p "$work/bin"
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
	mode=${ZLYME_FAKE_UMTP:-ready}
child=
trap 'if [ -n "$child" ]; then kill -s TERM "$child" 2>/dev/null || true; fi; exit 0' TERM INT
case "$mode" in
	exit) exit 1 ;;
	noready) ;;
	ready)
		ep=$(sed -n 's/^usb_epin_path[[:space:]]*"\(.*\)".*/\1/p' "$conf")
		dir=$(dirname "$ep")
		: > "$dir/ep1"
		: > "$dir/ep2"
		: > "$dir/ep3"
		;;
	*) exit 1 ;;
esac
while :; do
	sleep 30 &
	child=$!
	wait "$child" || true
done
EOF
cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_USB_MOUNT_LOG:-/dev/null}"
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
[ -n "$dest" ] || exit 1
case "$typ" in
	configfs)
		if [ "${ZLYME_FAKE_CONFIGFS_FAIL:-}" = 1 ]; then
			exit 1
		fi
		mkdir -p "$dest/usb_gadget"
		printf '%s %s %s %s %s %s\n' configfs "$dest" configfs rw 0 0 >> "$ZLYME_USB_MOUNTS"
		;;
	functionfs)
		if [ "${ZLYME_FAKE_MOUNT_FAIL:-}" = 1 ]; then
			exit 1
		fi
		if [ "${ZLYME_FAKE_BIND_FAIL:-}" = 1 ]; then
			chmod a-w "$ZLYME_USB_CONFIGFS/usb_gadget/zlyme-mtp/UDC" 2>/dev/null || true
		fi
		mkdir -p "$dest"
		: > "$dest/ep0"
		printf '%s %s %s %s %s %s\n' ffs "$dest" functionfs rw 0 0 >> "$ZLYME_USB_MOUNTS"
		;;
	*)
		exit 1
		;;
esac
EOF
cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
dest=
for a in "$@"; do
	dest=$a
done
if [ -n "${ZLYME_FAKE_UMOUNT_DELAY:-}" ] && [ "$dest" = "${ZLYME_USB_FFS:-}" ]; then
	sleep "$ZLYME_FAKE_UMOUNT_DELAY"
fi
tmp=$(mktemp)
if [ -f "$ZLYME_USB_MOUNTS" ]; then
	grep -F -v " ${dest} " "$ZLYME_USB_MOUNTS" > "$tmp" || true
else
	: > "$tmp"
fi
mv "$tmp" "$ZLYME_USB_MOUNTS"
# The configfs mountpoint is a directory that stays after umount.
# FunctionFS is created for the session and can go away with it.
if [ "$dest" != "${ZLYME_USB_CONFIGFS:-}" ]; then
	rm -rf "$dest"
fi
EOF
chmod 755 "$work/bin/umtprd" "$work/bin/mount" "$work/bin/umount"

count_responder() {
	n=0
	for d in /proc/[0-9]*; do
		[ -r "$d/cmdline" ] || continue
		# shellcheck disable=SC2002 # cat avoids a set -e abort when /proc/pid disappears mid-read.
		cmd=$(cat "$d/cmdline" 2>/dev/null | tr '\000' ' ' || true)
		case "$cmd" in
			*"$work/bin/umtprd"*) n=$((n + 1)) ;;
		esac
	done
	printf '%s\n' "$n"
}

reset_tree() {
	kill_responders
	rm -rf "$work/run" "$work/configfs" "$work/udc" "$work/ffs" \
		"$work/storage" "$work/sd2" "$work/private" "$work/usb"
	mkdir -p "$work/configfs" "$work/udc/fcc00000.usb" \
		"$work/storage/Roms" "$work/storage/Bios"
	printf '%s\n' "not attached" > "$work/udc/fcc00000.usb/state"
	printf 'vol0 %s exfat rw 0 0\n' "$work/storage" > "$work/mounts"
	printf '%s\n' "$work/storage" > "$work/libraries"
	: > "$work/mount.log"
}

run_helper() {
	ZLYME_USB_RUN="$work/run" \
	ZLYME_USB_CONFIGFS="$work/configfs" \
	ZLYME_USB_UDC_CLASS="$work/udc" \
	ZLYME_USB_MOUNTS="$work/mounts" \
	ZLYME_USB_FFS="$work/ffs" \
	ZLYME_USB_UMTPRD="$work/bin/umtprd" \
	ZLYME_USB_UDC_NAME=fcc00000.usb \
	ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_USB_STORAGE="$work/storage" \
	ZLYME_USB_SD2="$work/sd2" \
	ZLYME_USB_MOUNT="$work/bin/mount" \
	ZLYME_USB_UMOUNT="$work/bin/umount" \
	ZLYME_USB_MOUNT_LOG="$work/mount.log" \
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_READY_POLLS="${POLLS:-15}" \
	ZLYME_USB_READY_SLEEP="${SLEEP:-0}" \
	ZLYME_USB_KILL_POLLS=8 \
	ZLYME_USB_KILL_SLEEP=0.05 \
	ZLYME_USB_SPAWN_POLLS="${SPAWN_POLLS:-8}" \
	ZLYME_USB_SPAWN_SLEEP="${SPAWN_SLEEP:-0}" \
	ZLYME_USB_REAP_SLEEP="${REAP_SLEEP:-0.05}" \
	ZLYME_USB_REAP_WAIT=0.05 \
	ZLYME_USB_SIGNAL="${SIGNAL_CMD:-}" \
	ZLYME_FAKE_UMTP="${MODE:-ready}" \
	ZLYME_FAKE_MOUNT_FAIL="${MOUNT_FAIL:-}" \
	ZLYME_FAKE_CONFIGFS_FAIL="${CONFIGFS_FAIL:-}" \
	ZLYME_FAKE_BIND_FAIL="${BIND_FAIL:-}" \
	ZLYME_FAKE_UMOUNT_DELAY="${UMOUNT_DELAY:-}" \
	"$HELPER" "$@"
}

gadget=$work/configfs/usb_gadget/zlyme-mtp

# Default off: status does not start a responder.
reset_tree
MODE=ready
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx 'state=off' || fail "default status is not off: $out"
[ "$(count_responder)" = 0 ] || fail "status started a responder"
[ ! -d "$gadget" ] || fail "status created a gadget"
grep -q configfs "$work/mounts" && fail "status mounted configfs"
[ ! -s "$work/mount.log" ] || fail "status called mount"

# Successful start, repeated start, repeated stop.
reset_tree
run_helper start
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx 'state=bound' || fail "start did not bind: $out"
printf '%s\n' "$out" | grep -qx "export=$work/storage/Roms" || fail "primary ROMs missing: $out"
printf '%s\n' "$out" | grep -qx "export=$work/storage/Bios" || fail "primary BIOS missing: $out"
printf '%s\n' "$out" | grep -qx 'host=not attached' || fail "host state not passed through: $out"
conf=$work/run/umtprd.conf
grep -q 'usb_vendor_id 0x1D6B' "$conf" || fail "vendor id missing"
grep -q 'usb_product_id 0x0100' "$conf" || fail "product id missing"
grep -q 'serial "zlyme"' "$conf" || fail "serial is not the fixed string"
grep -q 'usb_functionfs_mode 0x1' "$conf" || fail "functionfs mode missing"
grep -q "storage \"$work/storage/Roms\" \"ROMs\" \"rw\"" "$conf" || fail "ROMs storage line"
grep -q mmcblk "$conf" && fail "block device name leaked into the conf"
grep -q '/\.config' "$conf" && fail "config path exported"
grep -q '/boot' "$conf" && fail "boot path exported"
got=$(tr -d '[:space:]' < "$gadget/UDC")
[ "$got" = fcc00000.usb ] || fail "UDC file is $got"
[ "$(count_responder)" = 1 ] || fail "expected one responder"
grep -q "configfs $work/configfs configfs" "$work/mounts" || fail "configfs was not mounted"
[ -f "$work/run/configfs-mounted-by-us" ] || fail "configfs ownership was not recorded"
grep -q -- '-t configfs' "$work/mount.log" || fail "start did not mount configfs"
run_helper start
[ "$(count_responder)" = 1 ] || fail "repeated start spawned another responder"
run_helper stop
[ "$(count_responder)" = 0 ] || fail "stop left a responder"
[ ! -d "$gadget" ] || fail "stop left the gadget"
grep -q configfs "$work/mounts" && fail "owned configfs stayed mounted"
[ ! -f "$work/run/configfs-mounted-by-us" ] || fail "configfs marker stayed"
run_helper stop
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx 'state=off' || fail "status after stop: $out"

# No UDC.
reset_tree
rm -rf "$work/udc/fcc00000.usb"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded with no UDC"
fi
grep -q 'no UDC is registered' "$work/err" || fail "missing no-UDC reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "no-UDC start left a gadget"
[ "$(count_responder)" = 0 ] || fail "no-UDC start left a responder"

# A single unexpected controller is not used.
reset_tree
rm -rf "$work/udc/fcc00000.usb"
mkdir -p "$work/udc/fd000000.usb"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start bound an unexpected UDC"
fi
grep -q 'not that controller' "$work/err" || fail "unexpected UDC reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "unexpected UDC left a gadget"
[ ! -f "$work/udc/fd000000.usb/UDC" ] || fail "unexpected controller was written"

# Several controllers, none of them the lower port.
reset_tree
rm -rf "$work/udc/fcc00000.usb"
mkdir -p "$work/udc/aaa" "$work/udc/bbb"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded with an ambiguous UDC list"
fi
grep -q 'ambiguous UDC list' "$work/err" || fail "ambiguous reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "ambiguous start left a gadget"

# Another gadget already owns the lower-port controller.
reset_tree
mkdir -p "$work/configfs/usb_gadget/other"
printf '%s\n' fcc00000.usb > "$work/configfs/usb_gadget/other/UDC"
cp "$work/configfs/usb_gadget/other/UDC" "$work/other-udc"
printf 'configfs %s configfs rw 0 0\n' "$work/configfs" >> "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start stole an owned UDC"
fi
grep -q 'owned by gadget other' "$work/err" || fail "owned reason: $(cat "$work/err")"
cmp -s "$work/other-udc" "$work/configfs/usb_gadget/other/UDC" || fail "foreign gadget UDC changed"
[ ! -d "$gadget" ] || fail "owned-UDC start created our gadget"
grep -q "configfs $work/configfs configfs" "$work/mounts" || fail "foreign configfs was unmounted"
grep -q -- '-t configfs' "$work/mount.log" && fail "start mounted over a shared configfs"

# Primary storage not mounted. The directory existing is not enough.
reset_tree
printf 'vol0 %s exfat rw 0 0\n' "$work/elsewhere" > "$work/mounts"
mkdir -p "$work/elsewhere"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded without a mounted primary"
fi
grep -q 'primary storage is not mounted' "$work/err" || fail "mount reason: $(cat "$work/err")"

# Primary ROM directory missing.
reset_tree
rm -rf "$work/storage/Roms"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded without ROMs"
fi
grep -q 'primary ROM directory' "$work/err" || fail "rom reason: $(cat "$work/err")"

# ROM directory is a symlink. Do not follow it.
reset_tree
rm -rf "$work/storage/Roms"
ln -s "$work/storage/Bios" "$work/storage/Roms"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start followed a ROM symlink"
fi
grep -q 'primary ROM directory' "$work/err" || fail "symlink reason: $(cat "$work/err")"

# Second card listed but not mounted is omitted. A mounted one is shared.
reset_tree
mkdir -p "$work/sd2/Roms" "$work/sd2/Bios"
printf '%s\n%s\n' "$work/storage" "$work/sd2" > "$work/libraries"
run_helper start
out=$(run_helper status)
printf '%s\n' "$out" | grep -q "$work/sd2/Roms" && fail "unmounted SD2 was exported: $out"
run_helper stop
printf 'vol0 %s exfat rw 0 0\nvol1 %s exfat rw 0 0\n' \
	"$work/storage" "$work/sd2" > "$work/mounts"
run_helper start
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx "export=$work/sd2/Roms" || fail "mounted SD2 ROMs missing: $out"
printf '%s\n' "$out" | grep -qx "export=$work/sd2/Bios" || fail "mounted SD2 BIOS missing: $out"
run_helper stop

# Private OS paths and a block-device mount source stay out of the conf.
reset_tree
mkdir -p "$work/private/.update/Roms" "$work/storage/.config/Roms"
printf '%s\n%s\n' "$work/storage" "$work/private/.update" > "$work/libraries"
printf 'vol0 %s exfat rw 0 0\n/dev/mmcblk0p3 %s exfat rw 0 0\n' \
	"$work/storage" "$work/private/.update" > "$work/mounts"
run_helper start
conf=$work/run/umtprd.conf
grep -q '\.update' "$conf" && fail "update path exported"
grep -q '\.config' "$conf" && fail "config path exported"
grep -q 'mmcblk' "$conf" && fail "mmcblk exported"
grep -q "storage \"/dev" "$conf" && fail "storage line points at /dev"
run_helper stop

# Mount failure rolls back.
reset_tree
MOUNT_FAIL=1
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start survived a mount failure"
fi
unset MOUNT_FAIL
grep -q 'FunctionFS mount failed' "$work/err" || fail "mount-fail reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "mount failure left a gadget"
[ "$(count_responder)" = 0 ] || fail "mount failure left a responder"

# Responder exits immediately.
reset_tree
MODE='exit'
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start survived a dead responder"
fi
MODE=ready
grep -q 'responder exited' "$work/err" || fail "exit reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "dead responder left a gadget"

# Endpoints never appear.
reset_tree
MODE=noready
POLLS=3
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded without endpoints"
fi
MODE=ready
POLLS=15
grep -q 'endpoints were not ready' "$work/err" || fail "ready reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "readiness failure left a gadget"
[ "$(count_responder)" = 0 ] || fail "readiness failure left a responder"

# Bind failure after the gadget exists.
reset_tree
BIND_FAIL=1
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start survived a bind failure"
fi
unset BIND_FAIL
grep -q 'failed to bind' "$work/err" || fail "bind reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "bind failure left a gadget"
[ "$(count_responder)" = 0 ] || fail "bind failure left a responder"

# Partial gadget and a stale pid that is some other process.
reset_tree
mkdir -p "$gadget"
printf '%s\n' fcc00000.usb > "$gadget/UDC"
sleep 30 &
other=$!
mkdir -p "$work/run"
printf '%s\n' "$other" > "$work/run/responder.pid"
run_helper stop
kill -0 "$other" 2>/dev/null || fail "stop killed an unrelated pid"
kill -s TERM "$other" 2>/dev/null || true
wait "$other" 2>/dev/null || true
[ ! -d "$gadget" ] || fail "stop left a partial gadget"

# TERM during startup cleans the gadget and the responder.
reset_tree
MODE=noready
POLLS=1000
SLEEP=0.2
ZLYME_USB_RUN="$work/run" \
ZLYME_USB_CONFIGFS="$work/configfs" \
ZLYME_USB_UDC_CLASS="$work/udc" \
ZLYME_USB_MOUNTS="$work/mounts" \
ZLYME_USB_FFS="$work/ffs" \
ZLYME_USB_UMTPRD="$work/bin/umtprd" \
ZLYME_USB_UDC_NAME=fcc00000.usb \
ZLYME_LIBRARIES_FILE="$work/libraries" \
ZLYME_USB_STORAGE="$work/storage" \
ZLYME_USB_SD2="$work/sd2" \
ZLYME_USB_MOUNT="$work/bin/mount" \
ZLYME_USB_UMOUNT="$work/bin/umount" \
ZLYME_USB_TEST_LAYOUT=1 \
ZLYME_USB_READY_POLLS=1000 \
ZLYME_USB_READY_SLEEP=0.2 \
ZLYME_USB_KILL_POLLS=8 \
ZLYME_USB_KILL_SLEEP=0.05 \
ZLYME_FAKE_UMTP=noready \
"$HELPER" start >"$work/out" 2>"$work/err" &
helper_pid=$!
i=0
while [ "$i" -lt 50 ]; do
	[ -d "$gadget" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -d "$gadget" ] || fail "startup did not reach gadget setup"
kill -s TERM "$helper_pid"
set +e
wait "$helper_pid"
sig_rc=$?
set -e
[ "$sig_rc" -eq 143 ] || fail "signal exit is $sig_rc"
[ ! -d "$gadget" ] || fail "signal left the gadget"
[ "$(count_responder)" = 0 ] || fail "signal left a responder"
MODE=ready
POLLS=15
SLEEP=0

# The PAK starts transfer only after confirm, and exit stops it.
cat > "$work/bin/presenter" << 'EOF'
#!/bin/sh
log=$ZLYME_PRESENTER_LOG
codes=$ZLYME_PRESENTER_CODES
countf=$ZLYME_PRESENTER_COUNT
n=0
if [ -f "$countf" ]; then
	read -r n < "$countf" || n=0
fi
n=$((n + 1))
printf '%s\n' "$n" > "$countf"
printf '%s\n' "$*" >> "$log"
code=$(sed -n "${n}p" "$codes")
[ -n "$code" ] || code=0
exit "$code"
EOF
cat > "$work/bin/transfer" << 'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$ZLYME_TRANSFER_LOG"
case "$1" in
	start)
		if [ "${ZLYME_FAKE_TRANSFER_FAIL:-}" = 1 ]; then
			printf '%s\n' "lower USB-C controller name is unset" >&2
			exit 1
		fi
		exit 0
		;;
	status)
		printf '%s\n' "state=bound"
		printf '%s\n' "host=not attached"
		printf '%s\n' "export=/tmp/example/Roms"
		exit 0
		;;
	stop)
		if [ "${ZLYME_FAKE_STOP_FAIL:-}" = 1 ]; then
			printf '%s\n' "owned responder 9 is still running" >&2
			exit 1
		fi
		exit 0
		;;
esac
exit 0
EOF
chmod 755 "$work/bin/presenter" "$work/bin/transfer"

printf '%s\n' 0 0 > "$work/presenter.codes"
: > "$work/presenter.log"
: > "$work/transfer.log"
rm -f "$work/presenter.count"
ZLYME_USB_TRANSFER="$work/bin/transfer" \
ZLYME_USB_PRESENTER="$work/bin/presenter" \
ZLYME_PRESENTER_LOG="$work/presenter.log" \
ZLYME_PRESENTER_CODES="$work/presenter.codes" \
ZLYME_PRESENTER_COUNT="$work/presenter.count" \
ZLYME_TRANSFER_LOG="$work/transfer.log" \
"$PAK"
grep -qx start "$work/transfer.log" || fail "pak did not start"
grep -qx status "$work/transfer.log" || fail "pak did not read status"
grep -qx stop "$work/transfer.log" || fail "pak exit did not stop"
grep -q 'lower USB-C' "$work/presenter.log" || fail "pak did not name the port"

# Cancel before start still runs stop, and does not start.
printf '%s\n' 2 > "$work/presenter.codes"
: > "$work/presenter.log"
: > "$work/transfer.log"
rm -f "$work/presenter.count"
set +e
ZLYME_USB_TRANSFER="$work/bin/transfer" \
ZLYME_USB_PRESENTER="$work/bin/presenter" \
ZLYME_PRESENTER_LOG="$work/presenter.log" \
ZLYME_PRESENTER_CODES="$work/presenter.codes" \
ZLYME_PRESENTER_COUNT="$work/presenter.count" \
ZLYME_TRANSFER_LOG="$work/transfer.log" \
"$PAK"
pak_rc=$?
set -e
[ "$pak_rc" -eq 2 ] || fail "cancel exit is $pak_rc"
grep -q '^start$' "$work/transfer.log" && fail "cancel started transfer"
grep -qx stop "$work/transfer.log" || fail "cancel did not stop"

# A failed start is shown and still stopped.
printf '%s\n' 0 0 > "$work/presenter.codes"
: > "$work/presenter.log"
: > "$work/transfer.log"
rm -f "$work/presenter.count"
set +e
ZLYME_USB_TRANSFER="$work/bin/transfer" \
ZLYME_USB_PRESENTER="$work/bin/presenter" \
ZLYME_PRESENTER_LOG="$work/presenter.log" \
ZLYME_PRESENTER_CODES="$work/presenter.codes" \
ZLYME_PRESENTER_COUNT="$work/presenter.count" \
ZLYME_TRANSFER_LOG="$work/transfer.log" \
ZLYME_FAKE_TRANSFER_FAIL=1 \
"$PAK"
pak_rc=$?
set -e
[ "$pak_rc" -eq 1 ] || fail "start-failure exit is $pak_rc"
grep -qx start "$work/transfer.log" || fail "start-failure did not try start"
grep -qx stop "$work/transfer.log" || fail "start-failure did not stop"
grep -q 'did not start' "$work/presenter.log" || fail "start-failure was not shown"

# A normal exit reports a teardown failure instead of claiming success.
printf '%s\n' 0 0 0 > "$work/presenter.codes"
: > "$work/presenter.log"
: > "$work/transfer.log"
rm -f "$work/presenter.count"
set +e
ZLYME_USB_TRANSFER="$work/bin/transfer" \
ZLYME_USB_PRESENTER="$work/bin/presenter" \
ZLYME_PRESENTER_LOG="$work/presenter.log" \
ZLYME_PRESENTER_CODES="$work/presenter.codes" \
ZLYME_PRESENTER_COUNT="$work/presenter.count" \
ZLYME_TRANSFER_LOG="$work/transfer.log" \
ZLYME_FAKE_STOP_FAIL=1 \
"$PAK"
pak_rc=$?
set -e
[ "$pak_rc" -eq 1 ] || fail "stop-failure exit is $pak_rc"
grep -qx stop "$work/transfer.log" || fail "stop-failure did not stop"
grep -q 'did not stop' "$work/presenter.log" || fail "stop-failure was not shown"
unset ZLYME_FAKE_STOP_FAIL

# A mounted configfs with no usb_gadget directory cannot be completed.
reset_tree
printf 'configfs %s configfs rw 0 0\n' "$work/configfs" >> "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded without usb_gadget"
fi
grep -q 'configfs usb_gadget is not available' "$work/err" || fail "configfs reason: $(cat "$work/err")"
[ "$(count_responder)" = 0 ] || fail "configfs failure left a responder"
grep -q -- '-t configfs' "$work/mount.log" && fail "start mounted over an existing configfs"

# Controller name unset, including a device.conf that does not name one.
reset_tree
printf '%s\n' 'ZLYME_DEVICE_ID=my355' > "$work/device.conf"
if ZLYME_USB_RUN="$work/run" \
	ZLYME_USB_CONFIGFS="$work/configfs" \
	ZLYME_USB_UDC_CLASS="$work/udc" \
	ZLYME_USB_MOUNTS="$work/mounts" \
	ZLYME_USB_FFS="$work/ffs" \
	ZLYME_USB_UMTPRD="$work/bin/umtprd" \
	ZLYME_USB_UDC_NAME= \
	ZLYME_DEVICE_CONF="$work/device.conf" \
	ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_USB_STORAGE="$work/storage" \
	ZLYME_USB_SD2="$work/sd2" \
	ZLYME_USB_MOUNT="$work/bin/mount" \
	ZLYME_USB_UMOUNT="$work/bin/umount" \
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_READY_POLLS=5 \
	ZLYME_USB_READY_SLEEP=0 \
	"$HELPER" start >"$work/out" 2>"$work/err"
then
	fail "start succeeded with no controller name"
fi
grep -q 'controller name is unset' "$work/err" || fail "unset reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "unset name created a gadget"

# Configfs mount failure leaves no gadget.
reset_tree
CONFIGFS_FAIL=1
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start survived a configfs mount failure"
fi
unset CONFIGFS_FAIL
grep -q 'configfs mount failed' "$work/err" || fail "configfs mount reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "configfs mount failure left a gadget"
grep -q "configfs $work/configfs configfs" "$work/mounts" && fail "failed configfs mount was recorded"
[ "$(count_responder)" = 0 ] || fail "configfs mount failure left a responder"

# A different filesystem at the configfs path is not covered.
reset_tree
printf 'tmpfs %s tmpfs rw 0 0\n' "$work/configfs" >> "$work/mounts"
cp "$work/mounts" "$work/mounts.before"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start mounted over a tmpfs configfs path"
fi
grep -q 'not configfs' "$work/err" || fail "wrong-fs reason: $(cat "$work/err")"
grep -q -- '-t configfs' "$work/mount.log" && fail "mount was called over tmpfs"
cmp -s "$work/mounts.before" "$work/mounts" || fail "wrong filesystem mount changed"
[ ! -d "$gadget" ] || fail "wrong filesystem left a gadget"

# FunctionFS failure after configfs was mounted removes the gadget and the mount.
reset_tree
MOUNT_FAIL=1
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "partial setup survived functionfs failure"
fi
unset MOUNT_FAIL
grep -q 'FunctionFS mount failed' "$work/err" || fail "partial reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "partial setup left a gadget"
grep -q configfs "$work/mounts" && fail "partial setup left configfs mounted"
[ "$(count_responder)" = 0 ] || fail "partial setup left a responder"

# No boot script or fstab mounts configfs or starts the responder.
if grep -n configfs \
	"$ROOT/board/my355/fsoverlay/etc/fstab" \
	"$ROOT/package/boot/zlyme-initramfs/init" \
	"$ROOT"/board/my355/fsoverlay/etc/init.d/*; then
	fail "configfs is referenced from boot"
fi
if grep -n -E 'zlyme-usb-transfer|umtprd' \
	"$ROOT"/board/my355/fsoverlay/etc/init.d/*; then
	fail "boot script starts usb transfer"
fi

# Primary ext4 is not an export. The directory existing is not enough.
reset_tree
printf 'vol0 %s ext4 rw 0 0\n' "$work/storage" > "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start exported an ext4 primary"
fi
grep -q 'not exfat or vfat' "$work/err" || fail "ext4 primary reason: $(cat "$work/err")"
[ ! -f "$work/run/umtprd.conf" ] || fail "ext4 primary wrote a conf"

# Primary read-only exFAT is not an export.
reset_tree
printf 'vol0 %s exfat ro 0 0\n' "$work/storage" > "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start exported read-only primary storage"
fi
grep -q 'mounted read-only' "$work/err" || fail "read-only reason: $(cat "$work/err")"

# A nested mount under the ROM directory is refused.
reset_tree
mkdir -p "$work/storage/Roms/hidden"
printf 'vol0 %s exfat rw 0 0\nnest %s ext4 rw 0 0\n' \
	"$work/storage" "$work/storage/Roms/hidden" > "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start exported a nested mount"
fi
grep -q 'nested mount' "$work/err" || fail "nested reason: $(cat "$work/err")"
[ -d "$work/storage/Roms/hidden" ] || fail "nested mount test removed the directory"
if [ -f "$work/run/umtprd.conf" ] && grep -q hidden "$work/run/umtprd.conf"; then
	fail "nested path exported"
fi

# Secondary exFAT is shared. Secondary ext4, including a symlink into
# private state, is skipped and left mounted. A read-only exFAT card
# and a USB library on ext4 are skipped too.
reset_tree
mkdir -p "$work/sd2/Roms" "$work/sd2/Bios" "$work/private/.config" \
	"$work/usb/Roms"
printf '%s\n' secret > "$work/private/.config/key"
ln -s "$work/private/.config/key" "$work/sd2/Roms/leak"
printf '%s\n%s\n%s\n%s\n' "$work/storage" "$work/sd2" "$work/ro" "$work/usb" > "$work/libraries"
mkdir -p "$work/ro/Roms"
printf 'vol0 %s exfat rw 0 0\nvol1 %s ext4 rw 0 0\nvol2 %s exfat ro 0 0\nvol3 %s ext4 rw 0 0\n' \
	"$work/storage" "$work/sd2" "$work/ro" "$work/usb" > "$work/mounts"
# The ext4 card above is the symlink case. Add a separate exFAT card too.
mkdir -p "$work/sd2b/Roms" "$work/sd2b/Bios"
printf '%s\n' "$work/sd2b" >> "$work/libraries"
printf 'vol4 %s exfat rw 0 0\n' "$work/sd2b" >> "$work/mounts"
run_helper start
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx "export=$work/storage/Roms" || fail "primary missing beside skipped cards: $out"
printf '%s\n' "$out" | grep -qx "export=$work/sd2b/Roms" || fail "secondary exfat missing: $out"
printf '%s\n' "$out" | grep -qx "export=$work/sd2b/Bios" || fail "secondary exfat BIOS missing: $out"
printf '%s\n' "$out" | grep -q "skipped=$work/sd2 filesystem is ext4" || fail "ext4 skip missing: $out"
printf '%s\n' "$out" | grep -q "skipped=$work/usb filesystem is ext4" || fail "usb ext4 skip missing: $out"
printf '%s\n' "$out" | grep -q "skipped=$work/ro mounted read-only" || fail "read-only skip missing: $out"
conf=$work/run/umtprd.conf
grep -q "storage \"$work/sd2/" "$conf" && fail "ext4 library exported"
grep -q "storage \"$work/usb/" "$conf" && fail "usb ext4 library exported"
grep -q "$work/private" "$conf" && fail "private symlink target exported"
grep -q 'mmcblk\|/dev/' "$conf" && fail "device path exported"
[ -L "$work/sd2/Roms/leak" ] || fail "skipped library was modified"
run_helper stop

# An unexpected filesystem type on the primary volume fails closed.
reset_tree
printf 'vol0 %s ntfs rw 0 0\n' "$work/storage" > "$work/mounts"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start exported ntfs"
fi
grep -q 'not exfat or vfat' "$work/err" || fail "ntfs reason: $(cat "$work/err")"

# A child that never becomes umtprd is not left running, and the gadget is rolled back.
reset_tree
cat > "$work/bin/not-umtp" << 'EOF'
#!/bin/sh
printf '%s\n' "$$" > "${ZLYME_FAKE_CHILD_PID:?}"
exec sleep 30
EOF
chmod 755 "$work/bin/not-umtp"
SPAWN_POLLS=4
SPAWN_SLEEP=0.05
if ZLYME_USB_RUN="$work/run" \
	ZLYME_USB_CONFIGFS="$work/configfs" \
	ZLYME_USB_UDC_CLASS="$work/udc" \
	ZLYME_USB_MOUNTS="$work/mounts" \
	ZLYME_USB_FFS="$work/ffs" \
	ZLYME_USB_UMTPRD="$work/bin/not-umtp" \
	ZLYME_USB_UDC_NAME=fcc00000.usb \
	ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_USB_STORAGE="$work/storage" \
	ZLYME_USB_SD2="$work/sd2" \
	ZLYME_USB_MOUNT="$work/bin/mount" \
	ZLYME_USB_UMOUNT="$work/bin/umount" \
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_READY_POLLS=4 \
	ZLYME_USB_READY_SLEEP=0 \
	ZLYME_USB_SPAWN_POLLS=4 \
	ZLYME_USB_SPAWN_SLEEP=0.05 \
	ZLYME_USB_KILL_POLLS=4 \
	ZLYME_USB_KILL_SLEEP=0.05 \
	ZLYME_USB_REAP_SLEEP=0.05 \
	ZLYME_USB_REAP_WAIT=0.05 \
	ZLYME_FAKE_CHILD_PID="$work/child.pid" \
	"$HELPER" start >"$work/out" 2>"$work/err"
then
	fail "start accepted a process that is not umtprd"
fi
SPAWN_POLLS=8
SPAWN_SLEEP=0
grep -E -q 'not the umtprd we started|responder exited' "$work/err" || fail "spawn reason: $(cat "$work/err")"
[ ! -d "$gadget" ] || fail "bad responder left a gadget"
if [ -f "$work/child.pid" ]; then
	child=$(cat "$work/child.pid")
	kill -0 "$child" 2>/dev/null && fail "bad responder child $child is still running"
fi

# A responder that ignores signals keeps its pid file and stop fails.
reset_tree
cat > "$work/bin/ignore-kill" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$work/bin/ignore-kill"
SIGNAL_CMD="$work/bin/ignore-kill"
if run_helper stop >"$work/out" 2>"$work/err"; then
	:
fi
run_helper start
if run_helper stop >"$work/out" 2>"$work/err"; then
	fail "stop claimed success while the responder ignored signals"
fi
grep -q 'still running' "$work/err" || fail "unkillable reason: $(cat "$work/err")"
grep -q 'cleanup incomplete' "$work/err" || fail "cleanup was not reported: $(cat "$work/err")"
[ -s "$work/run/responder.pid" ] || fail "ownership pid file was discarded"
out=$(run_helper status)
printf '%s\n' "$out" | grep -qx 'state=partial' || fail "unkillable status is not partial: $out"
printf '%s\n' "$out" | grep -qx 'responder=running' || fail "unkillable status lost the responder: $out"
if run_helper stop >"$work/out" 2>"$work/err"; then
	fail "second stop claimed success"
fi
[ -s "$work/run/responder.pid" ] || fail "second stop discarded the pid file"
SIGNAL_CMD=
kill_responders

# TERM, 1.5s, KILL against a separate process group. Cleanup runs outside it.
reset_tree
our_pgrp=$(
	line=$(cat /proc/$$/stat)
	rest=${line#*)}
	set -f
	# shellcheck disable=SC2086
	set -- $rest
	printf '%s\n' "$3"
)
cat > "$work/bin/hold-presenter" << 'EOF'
#!/bin/sh
countf=${ZLYME_PRESENTER_COUNT:?}
n=0
if [ -f "$countf" ]; then
	read -r n < "$countf" || n=0
fi
n=$((n + 1))
printf '%s\n' "$n" > "$countf"
if [ "$n" -eq 1 ]; then
	exit 0
fi
sleep 60
EOF
chmod 755 "$work/bin/hold-presenter"
cat > "$work/bin/run-pak" << EOF
#!/bin/sh
printf '%s\\n' "\$\$" > "$work/pak.pid"
export ZLYME_USB_TRANSFER="$HELPER"
export ZLYME_USB_PRESENTER="$work/bin/hold-presenter"
export ZLYME_PRESENTER_COUNT="$work/presenter.count"
export ZLYME_USB_RUN="$work/run"
export ZLYME_USB_CONFIGFS="$work/configfs"
export ZLYME_USB_UDC_CLASS="$work/udc"
export ZLYME_USB_MOUNTS="$work/mounts"
export ZLYME_USB_FFS="$work/ffs"
export ZLYME_USB_UMTPRD="$work/bin/umtprd"
export ZLYME_USB_UDC_NAME=fcc00000.usb
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_USB_STORAGE="$work/storage"
export ZLYME_USB_SD2="$work/sd2"
export ZLYME_USB_MOUNT="$work/bin/mount"
export ZLYME_USB_UMOUNT="$work/bin/umount"
export ZLYME_USB_TEST_LAYOUT=1
export ZLYME_USB_READY_SLEEP=0
export ZLYME_USB_SPAWN_SLEEP=0.05
export ZLYME_USB_KILL_SLEEP=0.05
export ZLYME_USB_REAP_SLEEP=0.05
export ZLYME_USB_REAP_WAIT=0.05
export ZLYME_FAKE_UMOUNT_DELAY=2
export ZLYME_FAKE_UMTP=ready
exec "$PAK"
EOF
chmod 755 "$work/bin/run-pak"
rm -f "$work/pak.pid" "$work/presenter.count"
setsid "$work/bin/run-pak" >"$work/pak.out" 2>&1 < /dev/null &
i=0
while [ "$i" -lt 50 ]; do
	[ -s "$work/pak.pid" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -s "$work/pak.pid" ] || fail "pak session did not write its pid"
pak_pid=$(cat "$work/pak.pid")
pak_pgrp=$(
	line=$(cat "/proc/$pak_pid/stat")
	rest=${line#*)}
	set -f
	# shellcheck disable=SC2086
	set -- $rest
	printf '%s\n' "$3"
)
[ "$pak_pgrp" != "$our_pgrp" ] || fail "pak shares the test process group"
i=0
while [ "$i" -lt 80 ]; do
	[ -s "$work/run/reaper.pgid" ] && [ -d "$gadget" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -d "$gadget" ] || fail "group session did not create a gadget: $(cat "$work/pak.out" 2>/dev/null)"
reaper_pg=$(cat "$work/run/reaper.pgid")
[ "$reaper_pg" != "$pak_pgrp" ] || fail "reaper stayed in the pak group"
reaper_pid=$(cat "$work/run/reaper.pid")
kill -s TERM -- "-$pak_pgrp"
sleep 1.5
kill -s KILL -- "-$pak_pgrp" 2>/dev/null || true
kill -0 "$reaper_pid" 2>/dev/null || fail "cleanup process died with the pak group"
i=0
while [ "$i" -lt 40 ]; do
	kill -0 "$reaper_pid" 2>/dev/null || break
	i=$((i + 1))
	sleep 0.1
done
kill -0 "$reaper_pid" 2>/dev/null && fail "cleanup process did not finish"
[ ! -d "$gadget" ] || fail "group kill left the gadget"
[ "$(count_responder)" = 0 ] || fail "group kill left a responder"
grep -q configfs "$work/mounts" && fail "group kill left configfs mounted"

kill_responders
printf '%s\n' "usb transfer ok"
