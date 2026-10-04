#!/bin/sh
# Overlapping writers do not share a remount. A nested call does.
# The boot volume is a synthetic mount table, not the host /boot.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-boot-write
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/run"
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
	remount,ro) mode=ro ;;
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
printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
: > "$work/mount.log"
: > "$work/cmd.log"

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

# One remount pair for the outer transaction, then one for the waiter.
printf '%s\n' rw ro rw ro > "$work/want-mount"
if ! cmp -s "$work/want-mount" "$work/mount.log"; then
	echo "remount log:" >&2
	cat "$work/mount.log" >&2
	exit 1
fi
grep -q ' ro ' "$work/mounts"

: > "$work/cmd.log"
: > "$work/mount.log"
printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
mkdir -p "$ZLYME_BOOT_WRITE_LOCK"
printf '%s\n' 999999 > "$ZLYME_BOOT_WRITE_LOCK/owner"
"$BIN" sh -c 'echo recovered >> "$1"' sh "$work/cmd.log"
grep -qx recovered "$work/cmd.log"
[ ! -d "$ZLYME_BOOT_WRITE_LOCK" ]

: > "$work/cmd.log"
: > "$work/mount.log"
printf '/dev/fake /boot vfat ro 0 0\n' > "$work/mounts"
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

echo "boot write lock ok"
