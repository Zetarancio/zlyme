#!/bin/sh
# Boot-fat writes serialize, keep the wrapped command's status, and
# refuse a lock that is not a published owner PID. The boot volume is
# a synthetic mount table, not the host /boot.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-boot-write
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/run"
cat > "$work/device.conf" <<'EOF'
ZLYME_BOOT_DEVICE=/dev/fake
ZLYME_BOOT_LABEL=ZLYMEBOOT
EOF
cat > "$work/bin/mount" <<'EOF'
#!/bin/sh
set -eu
opt=
path=
while [ "$#" -gt 0 ]; do
	case "$1" in
		-o) opt=$2; shift 2 ;;
		*) path=$1; shift ;;
	esac
done
mode=ro
case "$opt" in
	remount,rw) mode=rw ;;
	remount,ro)
		if [ "${ZLYME_MOUNT_RO_FAIL:-}" = 1 ]; then
			echo "remount ro failed" >&2
			exit 1
		fi
		mode=ro
		;;
	*) echo "unexpected mount: $opt" >&2; exit 1 ;;
esac
printf '/dev/fake %s vfat %s 0 0\n' "$path" "$mode" > "$ZLYME_PROC_MOUNTS"
printf '%s\n' "$mode" >> "$ZLYME_MOUNT_LOG"
EOF
chmod 0755 "$work/bin/mount"

export PATH="$work/bin:$PATH"
export ZLYME_BOOT=/boot
export ZLYME_PROC_MOUNTS=$work/mounts
export ZLYME_BOOT_WRITE_LOCK=$work/run/lock
export ZLYME_MOUNT_LOG=$work/mount.log
export ZLYME_DEVICE_CONF=$work/device.conf
printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
: > "$work/mount.log"
: > "$work/cmd.log"

reset_boot() {
	: > "$work/cmd.log"
	: > "$work/mount.log"
	printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
	rm -rf "$ZLYME_BOOT_WRITE_LOCK" "$ZLYME_BOOT_WRITE_LOCK".*
}

cat > "$work/nested.sh" <<EOF
#!/bin/sh
echo nested >> "$work/cmd.log"
EOF
cat > "$work/outer.sh" <<EOF
#!/bin/sh
echo outer-start >> "$work/cmd.log"
"$BIN" "$work/nested.sh"
sleep 1
echo outer-end >> "$work/cmd.log"
EOF
chmod 0755 "$work/nested.sh" "$work/outer.sh"
"$BIN" "$work/outer.sh" &
outer=$!
sleep 0.3
"$BIN" sh -c 'echo other >> "$1"' sh "$work/cmd.log"
wait "$outer"

awk '
	$0 == "outer-start" { seen_start = 1 }
	$0 == "nested" { if (!seen_start || seen_end) bad = 1 }
	$0 == "outer-end" { seen_end = 1; if (!seen_start) bad = 1 }
	$0 == "other" { if (!seen_end) bad = 1; seen_other = 1 }
	END {
		if (bad || !seen_start || !seen_end || !seen_other) exit 1
	}
' "$work/cmd.log" || {
	echo "command order:" >&2
	cat "$work/cmd.log" >&2
	exit 1
}

printf '%s\n' rw ro rw ro > "$work/want-mount"
if ! cmp -s "$work/want-mount" "$work/mount.log"; then
	echo "remount log:" >&2
	cat "$work/mount.log" >&2
	exit 1
fi
grep -q ' ro ' "$work/mounts"
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]

reset_boot
"$BIN" sh -c 'exit 0'
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]
grep -q ' ro ' "$work/mounts"

reset_boot
set +e
"$BIN" sh -c 'exit 7'
status=$?
set -e
if [ "$status" -ne 7 ]; then
	echo "exit 7 became $status" >&2
	exit 1
fi
grep -q ' ro ' "$work/mounts"
printf '%s\n' rw ro > "$work/want-mount"
cmp -s "$work/want-mount" "$work/mount.log"
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]

reset_boot
printf '%s\n' 999999 > "$ZLYME_BOOT_WRITE_LOCK"
"$BIN" sh -c 'echo recovered >> "$1"' sh "$work/cmd.log"
grep -qx recovered "$work/cmd.log"
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]

reset_boot
printf '%s\n' 'not-a-pid' > "$ZLYME_BOOT_WRITE_LOCK"
set +e
"$BIN" true >"$work/bad.out" 2>"$work/bad.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "malformed lock was accepted" >&2
	exit 1
fi
grep -q malformed "$work/bad.err"
grep -qx 'not-a-pid' "$ZLYME_BOOT_WRITE_LOCK"
if [ -s "$work/mount.log" ]; then
	echo "malformed lock still remounted" >&2
	exit 1
fi

reset_boot
mkdir -p "$ZLYME_BOOT_WRITE_LOCK"
set +e
"$BIN" true >"$work/dir.out" 2>"$work/dir.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "directory lock was accepted" >&2
	exit 1
fi
[ -d "$ZLYME_BOOT_WRITE_LOCK" ]
grep -q 'not a PID file' "$work/dir.err"

reset_boot
"$BIN" sh -c 'sleep 1; echo held >> "$1"' sh "$work/cmd.log" &
holder=$!
sleep 0.2
if ZLYME_BOOT_WRITE_TIMEOUT=0 "$BIN" sh -c 'echo raced >> "$1"' sh "$work/cmd.log" \
	>"$work/race.out" 2>"$work/race.err"; then
	echo "unrelated caller entered a held transaction" >&2
	cat "$work/cmd.log" >&2
	exit 1
fi
grep -q 'is busy' "$work/race.err"
wait "$holder"
if grep -qx raced "$work/cmd.log"; then
	echo "refused caller still ran" >&2
	exit 1
fi
grep -qx held "$work/cmd.log"
printf '%s\n' rw ro > "$work/want-mount"
cmp -s "$work/want-mount" "$work/mount.log"
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]

reset_boot
python3 -c '
import os, signal, subprocess, sys, time
p = subprocess.Popen(
    [sys.argv[1], "sh", "-c", "sleep 30; echo continued >> \"$1\"", "sh", sys.argv[2]],
    start_new_session=True,
)
time.sleep(0.3)
os.kill(p.pid, signal.SIGINT)
try:
    rc = p.wait(timeout=3)
except subprocess.TimeoutExpired:
    os.kill(p.pid, signal.SIGKILL)
    print("signal did not stop the helper", file=sys.stderr)
    sys.exit(1)
if rc != 130:
    print("INT status was %s" % rc, file=sys.stderr)
    sys.exit(1)
' "$BIN" "$work/cmd.log"
grep -q ' ro ' "$work/mounts"
[ ! -e "$ZLYME_BOOT_WRITE_LOCK" ]
if grep -qx continued "$work/cmd.log"; then
	echo "signal path continued the wrapped command" >&2
	exit 1
fi

reset_boot
export ZLYME_MOUNT_RO_FAIL=1
set +e
"$BIN" true >"$work/poison.out" 2>"$work/poison.err"
status=$?
set -e
unset ZLYME_MOUNT_RO_FAIL
if [ "$status" -eq 0 ]; then
	echo "failed remount-ro was success" >&2
	exit 1
fi
grep -qx poison "$ZLYME_BOOT_WRITE_LOCK"
set +e
"$BIN" true >"$work/poison2.out" 2>"$work/poison2.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "poisoned lock was reused" >&2
	exit 1
fi
grep -qx poison "$ZLYME_BOOT_WRITE_LOCK"

echo "boot write lock ok"
