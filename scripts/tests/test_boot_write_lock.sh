#!/bin/sh
# Boot-fat writes serialize, keep the wrapped command's status, and
# leave /boot read-only. The boot volume is a synthetic mount table,
# not the host /boot.
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
export ZLYME_BOOT_WRITE_POISON=$work/run/poison
export ZLYME_MOUNT_LOG=$work/mount.log
export ZLYME_DEVICE_CONF=$work/device.conf
printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
: > "$work/mount.log"
: > "$work/cmd.log"

lock_free() {
	flock -n "$ZLYME_BOOT_WRITE_LOCK" true
}

reset_boot() {
	: > "$work/cmd.log"
	: > "$work/mount.log"
	printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
	rm -rf "$ZLYME_BOOT_WRITE_LOCK" "$ZLYME_BOOT_WRITE_POISON"
}

"$BIN" sh -c 'echo a-start >> "$1"; sleep 0.6; echo a-end >> "$1"' sh "$work/cmd.log" &
first=$!
sleep 0.2
"$BIN" sh -c 'echo b-start >> "$1"; echo b-end >> "$1"' sh "$work/cmd.log"
wait "$first"

awk '
	$0 == "a-start" { if (seen) bad = 1; seen = 1 }
	$0 == "a-end" { if (seen != 1) bad = 1; seen = 2 }
	$0 == "b-start" { if (seen != 2) bad = 1; seen = 3 }
	$0 == "b-end" { if (seen != 3) bad = 1; seen = 4 }
	END { if (bad || seen != 4) exit 1 }
' "$work/cmd.log" || {
	echo "writers overlapped:" >&2
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
lock_free

reset_boot
"$BIN" sh -c 'exit 0'
grep -q ' ro ' "$work/mounts"
printf '%s\n' rw ro > "$work/want-mount"
cmp -s "$work/want-mount" "$work/mount.log"
lock_free

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
lock_free

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
grep -q ' ro ' "$work/mounts"
lock_free

reset_boot
python3 -c '
import os, signal, subprocess, sys, time
p = subprocess.Popen(
    [sys.argv[1], "sh", "-c", "sleep 1; echo continued >> \"$1\"", "sh", sys.argv[2]],
    start_new_session=True,
)
time.sleep(0.2)
os.killpg(p.pid, signal.SIGINT)
os.killpg(p.pid, signal.SIGTERM)
os.killpg(p.pid, signal.SIGHUP)
try:
    rc = p.wait(timeout=4)
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    print("transaction did not finish after signals", file=sys.stderr)
    sys.exit(1)
if rc != 0:
    print("signal path status was %s" % rc, file=sys.stderr)
    sys.exit(1)
' "$BIN" "$work/cmd.log"
grep -qx continued "$work/cmd.log"
grep -q ' ro ' "$work/mounts"
printf '%s\n' rw ro > "$work/want-mount"
cmp -s "$work/want-mount" "$work/mount.log"
lock_free

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
[ -f "$ZLYME_BOOT_WRITE_POISON" ]
lock_free
: > "$work/mount.log"
set +e
"$BIN" true >"$work/poison2.out" 2>"$work/poison2.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "poisoned boot was reused" >&2
	exit 1
fi
grep -q 'left writable' "$work/poison2.err"
if [ -s "$work/mount.log" ]; then
	echo "poisoned boot was remounted" >&2
	exit 1
fi

reset_boot
printf '/dev/wrong /boot vfat ro 0 0\n' > "$work/mounts"
set +e
"$BIN" true >"$work/wrong.out" 2>"$work/wrong.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "wrong boot source was accepted" >&2
	exit 1
fi
grep -q 'expected' "$work/wrong.err"
if [ -s "$work/mount.log" ]; then
	echo "wrong boot source was remounted" >&2
	exit 1
fi
grep -q ' ro ' "$work/mounts"
[ ! -e "$ZLYME_BOOT_WRITE_POISON" ]

reset_boot
printf '/dev/fake /boot vfat rw 0 0\n' > "$work/mounts"
"$BIN" true
grep -q ' ro ' "$work/mounts"
printf '%s\n' ro rw ro > "$work/want-mount"
cmp -s "$work/want-mount" "$work/mount.log"
lock_free

reset_boot
printf '/dev/fake /boot vfat rw 0 0\n' > "$work/mounts"
export ZLYME_MOUNT_RO_FAIL=1
set +e
"$BIN" sh -c 'echo ran >> "$1"' sh "$work/cmd.log" >"$work/stuck.out" 2>"$work/stuck.err"
status=$?
set -e
unset ZLYME_MOUNT_RO_FAIL
if [ "$status" -eq 0 ]; then
	echo "writable boot that could not be restored was accepted" >&2
	exit 1
fi
if grep -qx ran "$work/cmd.log"; then
	echo "command ran before read-only was restored" >&2
	exit 1
fi
[ -f "$ZLYME_BOOT_WRITE_POISON" ]
if grep -qx rw "$work/mount.log"; then
	echo "opened read-write before proving read-only" >&2
	cat "$work/mount.log" >&2
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
grep -q 'could not open the boot lock' "$work/dir.err"
if [ -s "$work/mount.log" ]; then
	echo "directory lock still remounted" >&2
	exit 1
fi

echo "boot write lock ok"
