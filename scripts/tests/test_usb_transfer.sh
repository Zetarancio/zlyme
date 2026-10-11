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
			*"$work/bin/umtprd"*)
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
if [ "${ZLYME_FAKE_MOUNT_FAIL:-}" = 1 ]; then
	exit 1
fi
dest=
for a in "$@"; do
	case "$a" in
		-*|functionfs|mtp) ;;
		*) dest=$a ;;
	esac
done
[ -n "$dest" ] || exit 1
if [ "${ZLYME_FAKE_BIND_FAIL:-}" = 1 ]; then
	chmod a-w "$ZLYME_USB_CONFIGFS/usb_gadget/zlyme-mtp/UDC" 2>/dev/null || true
fi
mkdir -p "$dest"
: > "$dest/ep0"
printf '%s %s %s %s %s %s\n' ffs "$dest" functionfs rw 0 0 >> "$ZLYME_USB_MOUNTS"
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
rm -rf "$dest"
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
		"$work/storage" "$work/sd2" "$work/private"
	mkdir -p "$work/configfs/usb_gadget" "$work/udc/fcc00000.usb" \
		"$work/storage/Roms" "$work/storage/Bios"
	printf '%s\n' "not attached" > "$work/udc/fcc00000.usb/state"
	printf 'vol0 %s exfat rw 0 0\n' "$work/storage" > "$work/mounts"
	printf '%s\n' "$work/storage" > "$work/libraries"
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
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_READY_POLLS="${POLLS:-15}" \
	ZLYME_USB_READY_SLEEP="${SLEEP:-0}" \
	ZLYME_USB_KILL_POLLS=8 \
	ZLYME_USB_KILL_SLEEP=0.05 \
	ZLYME_FAKE_UMTP="${MODE:-ready}" \
	ZLYME_FAKE_MOUNT_FAIL="${MOUNT_FAIL:-}" \
	ZLYME_FAKE_BIND_FAIL="${BIND_FAIL:-}" \
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
run_helper start
[ "$(count_responder)" = 1 ] || fail "repeated start spawned another responder"
run_helper stop
[ "$(count_responder)" = 0 ] || fail "stop left a responder"
[ ! -d "$gadget" ] || fail "stop left the gadget"
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
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start stole an owned UDC"
fi
grep -q 'owned by gadget other' "$work/err" || fail "owned reason: $(cat "$work/err")"
cmp -s "$work/other-udc" "$work/configfs/usb_gadget/other/UDC" || fail "foreign gadget UDC changed"
[ ! -d "$gadget" ] || fail "owned-UDC start created our gadget"

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

# configfs gadget directory missing.
reset_tree
rm -rf "$work/configfs/usb_gadget"
if run_helper start >"$work/out" 2>"$work/err"; then
	fail "start succeeded without configfs"
fi
grep -q 'configfs usb_gadget is not available' "$work/err" || fail "configfs reason: $(cat "$work/err")"
[ "$(count_responder)" = 0 ] || fail "configfs failure left a responder"

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

kill_responders
printf '%s\n' "usb transfer ok"
