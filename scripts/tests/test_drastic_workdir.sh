#!/bin/sh
# DraStic scratch-directory safety. Mounts are rows in a file.
# rm outside the disposable root is refused, and path-refusal cases
# do not execute rm at all. This test does not create a bind mount.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
script=$ROOT/package/emulators/drastic/start_drastic.sh
fail() {
	echo "drastic-workdir: $*" >&2
	exit 1
}

[ -f "$script" ] || fail "launcher missing"
if grep -q 'ln -s' "$script"; then
	fail "the launcher still creates a symlink"
fi
if grep -E '^[[:space:]]*trap[[:space:]]' "$script"; then
	fail "the launcher traps a signal"
fi
RM=/bin/rm
[ -x "$RM" ] || RM=/usr/bin/rm
[ -x "$RM" ] || fail "host rm is missing"

had_dir=0
had_lock=0
if [ -e /tmp/drastic-run ] || [ -L /tmp/drastic-run ]; then
	had_dir=1
fi
if [ -e /tmp/drastic-run.lock ] || [ -L /tmp/drastic-run.lock ]; then
	had_lock=1
fi
holder=

work=$(mktemp -d)
case "$work" in
	/tmp/tmp.*) ;;
	*) fail "mktemp returned an unexpected directory" ;;
esac
cleanup() {
	# Only this test's launcher and its fake emulator. Never a process
	# group, and never the device scratch path.
	if [ -n "${holder:-}" ]; then
		kill "$holder" 2>/dev/null || true
		wait "$holder" 2>/dev/null || true
	fi
	if [ -n "${work:-}" ] && [ -f "$work/hold.pid" ]; then
		kill "$(cat "$work/hold.pid")" 2>/dev/null || true
	fi
	if [ -n "${work:-}" ] && [ -f "$work/sleep.pid" ]; then
		kill "$(cat "$work/sleep.pid")" 2>/dev/null || true
	fi
	case "${work:-}" in
		/tmp/tmp.*)
			if [ -d "$work" ] && [ ! -L "$work" ]; then
				"$RM" -rf -- "$work"
			fi
			;;
	esac
}
cleanup_src=$(awk '
	/^cleanup\(\) \{/ { on = 1 }
	on { print }
	on && /^\}/ { exit }
' "$0")
[ -n "$cleanup_src" ] || fail "cleanup function was not found"
case "$cleanup_src" in
	*drastic-run*) fail "cleanup names the production scratch path" ;;
esac
if printf '%s\n' "$cleanup_src" | grep -E '(^|[^[:alnum:]_])(rmdir|mount|umount)([^[:alnum:]_]|$)'; then
	fail "cleanup calls rmdir, mount, or umount"
fi
trap cleanup EXIT

export ZLYME_TEST_ROOT="$work"
export ZLYME_DRASTIC_WORKDIR="$work/run"
export ZLYME_DRASTIC_MOUNTINFO="$work/mountinfo"
export ZLYME_DRASTIC_BIN="$work/bin/drastic"
export ZLYME_FAKE_MOUNT_SEQ="$work/seq"
export ZLYME_FAKE_MOUNT_LOG="$work/mount.log"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_FAKE_RM_LOG="$work/rm.log"
export ZLYME_TEST_MARK="$work/mark"
unset ZLYME_DRASTIC_PRELOAD ZLYME_FAKE_MOUNT_FAIL_PATH ZLYME_FAKE_UMOUNT_FAIL
unset ZLYME_FAKE_RM_DENY ZLYME_FAKE_HOLD ZLYME_FAKE_REPLACE_BACKUP

mkdir -p "$work/bin" "$work/cfg_parent/drastic" \
	"$work/saves_parent/NDS/backup" "$work/saves_parent/NDS/savestates" \
	"$work/card" "$work/run"
printf '%s\n' keep > "$work/saves_parent/NDS/backup/keep.sav"
printf '%s\n' state > "$work/saves_parent/NDS/savestates/slot.dss"
printf '%s\n' 'user-cfg' > "$work/cfg_parent/drastic/drastic.cfg"
save_backup=$work/saves_parent/NDS/backup
save_states=$work/saves_parent/NDS/savestates

cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
set -eu
dest=
n=0
for arg in "$@"; do
	case "$arg" in
		-*) continue ;;
	esac
	if [ "$n" -ge 1 ]; then
		src=$dest
	fi
	dest=$arg
	n=$((n + 1))
done
[ "$n" -ge 2 ] || exit 1
case "$dest" in
	/tmp/drastic-run|/tmp/drastic-run/*|/storage|/storage/*) exit 99 ;;
esac
if [ -n "${ZLYME_FAKE_MOUNT_FAIL_PATH:-}" ] &&
	[ "$dest" = "$ZLYME_FAKE_MOUNT_FAIL_PATH" ]; then
	exit 1
fi
id=$(cat "$ZLYME_FAKE_MOUNT_SEQ")
printf '%s\n' "$((id + 1))" > "$ZLYME_FAKE_MOUNT_SEQ"
printf '%s 1 0:%s / %s rw shared:1 - fake %s rw\n' \
	"$id" "$id" "$dest" "$src" >> "$ZLYME_DRASTIC_MOUNTINFO"
printf '%s\n' "$dest" >> "$ZLYME_FAKE_MOUNT_LOG"
EOF
cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
set -eu
target=
for arg in "$@"; do
	case "$arg" in
		-*) continue ;;
	esac
	target=$arg
done
[ -n "$target" ] || exit 1
case "$target" in
	/tmp/drastic-run|/tmp/drastic-run/*|/storage|/storage/*) exit 99 ;;
esac
printf '%s\n' "$target" >> "$ZLYME_FAKE_UMOUNT_LOG"
if [ "${ZLYME_FAKE_UMOUNT_FAIL:-0}" = 1 ]; then
	exit 1
fi
tmp=$(mktemp)
awk -v p="$target" '$5 != p { print }' "$ZLYME_DRASTIC_MOUNTINFO" > "$tmp"
mv -f "$tmp" "$ZLYME_DRASTIC_MOUNTINFO"
EOF
cat > "$work/bin/rm" << 'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$ZLYME_FAKE_RM_LOG"
if [ "${ZLYME_FAKE_RM_DENY:-0}" = 1 ]; then
	echo "rm denied" >&2
	exit 99
fi
for arg in "$@"; do
	case "$arg" in
		--) continue ;;
		-*) continue ;;
	esac
	case "$arg" in
		*..*)
			echo "rm traversal" >&2
			exit 99
			;;
		"$ZLYME_TEST_ROOT"/*) ;;
		*)
			echo "rm outside" >&2
			exit 99
			;;
	esac
done
exec /bin/rm "$@"
EOF
cat > "$work/bin/drastic" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
if [ "${ZLYME_FAKE_REPLACE_BACKUP:-0}" = 1 ]; then
	tmp=$(mktemp)
	awk -v p="$ZLYME_DRASTIC_WORKDIR/backup" '
		$5 == p { $1 = 99 }
		{ print }
	' "$ZLYME_DRASTIC_MOUNTINFO" > "$tmp"
	mv -f "$tmp" "$ZLYME_DRASTIC_MOUNTINFO"
fi
echo played > "$ZLYME_TEST_MARK"
if [ "${ZLYME_FAKE_HOLD:-0}" = 1 ]; then
	echo held > "$ZLYME_TEST_MARK"
	echo $$ > "$ZLYME_TEST_ROOT/hold.pid"
	sleep 30 &
	echo $! > "$ZLYME_TEST_ROOT/sleep.pid"
	wait
fi
exit 0
EOF
chmod 0755 "$work/bin/mount" "$work/bin/umount" "$work/bin/rm" "$work/bin/drastic"
[ -x "$work/bin/mount" ] || fail "fake mount is missing"
[ -x "$work/bin/rm" ] || fail "fake rm is missing"

not_unmounted() {
	if [ -s "$work/umount.log" ] && grep -Fxq -- "$1" "$work/umount.log"; then
		fail "$1 was unmounted"
	fi
}

run_it() {
	PATH="$work/bin:$PATH" \
		XDG_CONFIG_HOME=$work/cfg_parent \
		SAVES_PATH=$work/saves_parent \
		SDCARD_PATH=$work/card \
		ZLYME_DRASTIC_WORKDIR="$ZLYME_DRASTIC_WORKDIR" \
		sh "$script" "$work/game.nds"
}

reset_table() {
	printf '%s\n' 10 > "$work/seq"
	: > "$work/mountinfo"
	: > "$work/mount.log"
	: > "$work/umount.log"
	: > "$work/rm.log"
	"$RM" -f "$work/mark" "$work/hold.pid"
	unset ZLYME_FAKE_MOUNT_FAIL_PATH ZLYME_FAKE_UMOUNT_FAIL
	unset ZLYME_FAKE_RM_DENY ZLYME_FAKE_HOLD ZLYME_FAKE_REPLACE_BACKUP
	ZLYME_DRASTIC_WORKDIR=$work/run
	export ZLYME_DRASTIC_WORKDIR
	"$RM" -rf "$work/run" "$work/run.lock"
	mkdir -p "$work/run"
}

saves_intact() {
	printf '%s\n' keep | cmp -s - "$save_backup/keep.sav" || fail "backup save changed"
	printf '%s\n' state | cmp -s - "$save_states/slot.dss" || fail "savestate changed"
}

rm_idle() {
	[ ! -s "$work/rm.log" ] || fail "rm ran: $(cat "$work/rm.log")"
}

# A clean directory is replaced, the recorded mounts are released, and
# the launch lock does not remain.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
printf '%s\n' '2 1 0:2 / /storage rw shared:1 - exfat /dev/disk rw' >> "$work/mountinfo"
printf '%s\n' stale > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "clean launch exited $st"
grep -qx played "$work/mark" || fail "clean launch did not run"
[ ! -e "$work/run/marker" ] || fail "a clean work directory was not replaced"
[ ! -e "$work/run.lock" ] || fail "the launch lock remained after success"
saves_intact
grep -q 'user-cfg' "$work/cfg_parent/drastic/drastic.cfg" || fail "user config was replaced"
grep -Fxq "$work/run/backup" "$work/umount.log" || fail "backup was not released"
grep -Fxq "$work/run/savestates" "$work/umount.log" || fail "savestates were not released"
grep -q '^2 ' "$work/mountinfo" || fail "the unrelated /storage row was removed"
not_unmounted /storage

# Stale and stacked mounts refuse before deletion and are not unmounted.
reset_table
printf '%s\n' stale > "$work/run/marker"
printf '%s 1 0:9 / %s rw - fake %s rw\n' \
	9 "$work/run/backup" "$save_backup" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a stale bind was launched"
[ -f "$work/run/marker" ] || fail "stale bind deleted the work directory"
rm_idle
saves_intact
[ ! -s "$work/umount.log" ] || fail "a stale bind was unmounted"
grep -q "$work/run/backup" "$work/mountinfo" || fail "the stale bind left the table"
[ ! -e "$work/run.lock" ] || fail "a refused launch kept its lock"

reset_table
printf '%s\n' sticky > "$work/run/marker"
printf '%s 1 0:8 / %s rw - fake %s rw\n' \
	8 "$work/run" "$save_backup" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a mounted work directory was launched"
[ -f "$work/run/marker" ] || fail "mounted work directory was deleted"
rm_idle
saves_intact

reset_table
printf '%s 1 0:11 / %s rw - fake a rw\n' 11 "$work/run/backup" > "$work/mountinfo"
printf '%s 11 0:12 / %s rw - fake b rw\n' 12 "$work/run/backup" >> "$work/mountinfo"
printf '%s\n' stacked > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "two mounts at backup were accepted"
[ -f "$work/run/marker" ] || fail "two mounts were deleted through"
rm_idle
saves_intact
[ ! -s "$work/umount.log" ] || fail "two mounts were unmounted"

# A different id at the same path is not this launch's mount.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_REPLACE_BACKUP=1
set +e
run_it
st=$?
set -e
unset ZLYME_FAKE_REPLACE_BACKUP
[ "$st" != 0 ] || fail "a replacement mount was treated as owned"
grep -qx played "$work/mark" || fail "the replacement case did not reach the emulator"
saves_intact
not_unmounted "$work/run/backup"
awk '$1 == 99 && $5 == p { found = 1 } END { exit found ? 0 : 1 }' \
	p="$work/run/backup" "$work/mountinfo" || fail "the replacement id was removed"
grep -Fxq "$work/run/savestates" "$work/umount.log" || fail "the owned savestate mount was not released"
[ -d "$work/run.lock" ] || fail "a replacement mount dropped the launch lock"
: > "$work/rm.log"
: > "$work/umount.log"
printf '%s\n' next > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "the launch after a replacement mount proceeded"
[ -f "$work/run/marker" ] || fail "the launch after a replacement mount deleted the work directory"
rm_idle
saves_intact

# Failed release leaves the lock. The next launch does not remove the tree.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_UMOUNT_FAIL=1
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a failed unmount exited 0"
grep -qx played "$work/mark" || fail "the emulator did not run before the failed unmount"
saves_intact
[ -d "$work/run.lock" ] || fail "a failed unmount removed the launch lock"
unset ZLYME_FAKE_UMOUNT_FAIL
: > "$work/umount.log"
: > "$work/rm.log"
printf '%s\n' next > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "the launch after a failed unmount proceeded"
[ -f "$work/run/marker" ] || fail "the launch after a failed unmount deleted the work directory"
rm_idle
saves_intact
[ ! -s "$work/umount.log" ] || fail "the second launch unmounted a leftover"

# A failed bind does not create a symlink. Our own first mount is released.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_MOUNT_FAIL_PATH="$work/run/backup"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a failed backup bind continued"
saves_intact
[ ! -L "$work/run/backup" ] || fail "a failed bind created a symlink"
[ ! -s "$work/umount.log" ] || fail "a failed first bind unmounted something"
[ ! -e "$work/run.lock" ] || fail "a failed first bind kept the lock"
unset ZLYME_FAKE_MOUNT_FAIL_PATH

reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_MOUNT_FAIL_PATH="$work/run/savestates"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a failed savestate bind continued"
saves_intact
[ ! -L "$work/run/savestates" ] || fail "a failed savestate bind created a symlink"
not_unmounted "$work/run/savestates"
grep -Fxq "$work/run/backup" "$work/umount.log" || fail "the owned backup mount was left behind"
if grep -q "$work/run/backup" "$work/mountinfo"; then
	fail "the released backup row remained"
fi
[ ! -e "$work/run.lock" ] || fail "a rolled-back bind kept the lock"
unset ZLYME_FAKE_MOUNT_FAIL_PATH

# An existing lock is another launch. Do not remove its directory.
reset_table
mkdir "$work/run.lock"
printf '%s\n' busy > "$work/run/marker"
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a held lock was launched"
[ -f "$work/run/marker" ] || fail "a held lock deleted the work directory"
[ -d "$work/run.lock" ] || fail "a held lock was removed"
rm_idle
saves_intact

# The work directory itself being a symlink is refused.
reset_table
"$RM" -rf "$work/run"
ln -s "$save_backup" "$work/run"
export ZLYME_FAKE_RM_DENY=1
set +e
run_it
st=$?
set -e
unset ZLYME_FAKE_RM_DENY
[ "$st" != 0 ] || fail "a symlink work directory was accepted"
rm_idle
saves_intact
[ -L "$work/run" ] || fail "the symlink work directory was replaced"

# Save-slot symlinks are removed as links. The targets stay.
reset_table
ln -s "$save_backup" "$work/run/backup"
ln -s "$save_states" "$work/run/savestates"
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "symlink slots exited $st"
saves_intact
[ ! -L "$work/run/backup" ] || fail "backup stayed a symlink"
[ ! -L "$work/run/savestates" ] || fail "savestates stayed a symlink"

# An intermediate symlink is not a scratch directory.
reset_table
mkdir -p "$work/real"
printf '%s\n' secret > "$work/real/secret"
ln -s "$work/real" "$work/jump"
ZLYME_DRASTIC_WORKDIR=$work/jump/run
export ZLYME_DRASTIC_WORKDIR ZLYME_FAKE_RM_DENY=1
set +e
run_it
st=$?
set -e
unset ZLYME_FAKE_RM_DENY
ZLYME_DRASTIC_WORKDIR=$work/run
export ZLYME_DRASTIC_WORKDIR
[ "$st" != 0 ] || fail "an intermediate symlink was accepted"
rm_idle
printf '%s\n' secret | cmp -s - "$work/real/secret" || fail "symlink target changed"
saves_intact

# Lexical refusals do not execute rm. These strings are not created.
refuse_path() {
	reset_table
	export ZLYME_FAKE_RM_DENY=1
	ZLYME_DRASTIC_WORKDIR=$1
	export ZLYME_DRASTIC_WORKDIR
	set +e
	run_it
	st=$?
	set -e
	unset ZLYME_FAKE_RM_DENY
	ZLYME_DRASTIC_WORKDIR=$work/run
	export ZLYME_DRASTIC_WORKDIR
	[ "$st" != 0 ] || fail "$1 was accepted"
	rm_idle
	saves_intact
}
refuse_path /tmp/../storage
refuse_path /tmp/./storage
refuse_path /tmp//storage
refuse_path /tmp/storage/
refuse_path /tmp/foo/../../storage
refuse_path storage/nds
refuse_path ""
refuse_path /tmp/drastic-run
refuse_path "$save_backup"

reset_table
printf '%s\n' blocked > "$work/run/marker"
printf '%s 1 0:6 / %s/foo\\040bar rw - fake src rw\n' 6 "$work/run" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "an escaped mount path was ignored"
[ -f "$work/run/marker" ] || fail "escaped mount path deleted the work directory"
rm_idle
saves_intact

reset_table
printf '%s\n' blocked > "$work/run/marker"
printf '%s\n' 'not a mount line' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a malformed table was accepted"
[ -f "$work/run/marker" ] || fail "a malformed table deleted the work directory"
rm_idle

reset_table
printf '%s\n' blocked > "$work/run/marker"
printf '%s\n' '1 0 0:1 / / rw - x x rw' > "$work/mountinfo"
chmod a-r "$work/mountinfo"
set +e
run_it
st=$?
set -e
chmod u+r "$work/mountinfo" || true
[ "$st" != 0 ] || fail "an unreadable table was accepted"
[ -f "$work/run/marker" ] || fail "an unreadable table deleted the work directory"
rm_idle
saves_intact

# A second launch cannot clear the directory while the first holds it.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_HOLD=1
run_it >"$work/hold.out" 2>"$work/hold.err" &
holder=$!
i=0
while [ "$i" -lt 50 ]; do
	if [ -f "$work/mark" ] && grep -qx held "$work/mark"; then
		break
	fi
	i=$((i + 1))
	sleep 0.05
done
grep -qx held "$work/mark" || fail "the holder did not start"
: > "$work/rm.log"
: > "$work/umount.log"
export ZLYME_FAKE_HOLD=0
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a concurrent launch proceeded"
rm_idle
saves_intact
if [ -f "$work/hold.pid" ]; then
	kill "$(cat "$work/hold.pid")" 2>/dev/null || true
fi
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
holder=
unset ZLYME_FAKE_HOLD

reset_table
printf '%s\n' '4 1 0:4 / '"$work/run"'-extra rw - fake other rw' > "$work/mountinfo"
printf '%s\n' '5 1 0:5 / /storage rw - fake storage rw' >> "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "an unrelated mount blocked launch ($st)"
grep -q '^4 ' "$work/mountinfo" || fail "the near-name mount was removed"
grep -q '^5 ' "$work/mountinfo" || fail "the storage row was removed"
not_unmounted "$work/run-extra"
not_unmounted /storage
saves_intact

# A normal exit can be followed by another launch.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "the first normal launch exited $st"
[ ! -e "$work/run.lock" ] || fail "the first normal launch left the lock"
: > "$work/umount.log"
: > "$work/mark"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "the launch after a normal exit exited $st"
[ ! -e "$work/run.lock" ] || fail "the second normal launch left the lock"
saves_intact

# MENU+START signals the launcher shell before the emulator.
# pak-spawn waits 30 polls of 50 ms, then may use SIGKILL.
# This shell has no trap, so SIGTERM does not reach the unmount lines.
signal_holder() {
	sig=$1
	reset_table
	printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
	export ZLYME_FAKE_HOLD=1
	PATH="$work/bin:$PATH" \
		XDG_CONFIG_HOME=$work/cfg_parent \
		SAVES_PATH=$work/saves_parent \
		SDCARD_PATH=$work/card \
		ZLYME_DRASTIC_WORKDIR=$work/run \
		sh "$script" "$work/game.nds" >"$work/hold.out" 2>"$work/hold.err" &
	holder=$!
	i=0
	while [ "$i" -lt 50 ]; do
		if [ -f "$work/mark" ] && grep -qx held "$work/mark"; then
			break
		fi
		i=$((i + 1))
		sleep 0.05
	done
	grep -qx held "$work/mark" || fail "the $sig holder did not start"
	[ -d "$work/run.lock" ] || fail "the $sig holder did not take the lock"
	grep -q "$work/run/backup" "$work/mountinfo" || fail "the $sig holder did not bind backup"
	: > "$work/umount.log"
	: > "$work/rm.log"
	kill "-$sig" "$holder"
	i=0
	while [ "$i" -lt 20 ]; do
		if ! kill -0 "$holder" 2>/dev/null; then
			break
		fi
		i=$((i + 1))
		sleep 0.05
	done
	if kill -0 "$holder" 2>/dev/null; then
		fail "$sig left the launcher running"
	fi
	wait "$holder" 2>/dev/null || true
	holder=
	if ! kill -0 "$(cat "$work/hold.pid")" 2>/dev/null; then
		fail "$sig also stopped the emulator before a separate signal"
	fi
	[ -d "$work/run.lock" ] || fail "$sig released the lock"
	grep -q "$work/run/backup" "$work/mountinfo" || fail "$sig dropped the backup mount"
	grep -q "$work/run/savestates" "$work/mountinfo" || fail "$sig dropped the savestate mount"
	[ ! -s "$work/umount.log" ] || fail "$sig unmounted"
	rm_idle
	saves_intact
	printf '%s\n' kept > "$work/run/marker"
	export ZLYME_FAKE_HOLD=0
	set +e
	run_it
	st=$?
	set -e
	[ "$st" != 0 ] || fail "a launch after $sig proceeded"
	[ -f "$work/run/marker" ] || fail "the launch after $sig deleted the work directory"
	rm_idle
	saves_intact
	[ ! -s "$work/umount.log" ] || fail "the launch after $sig unmounted"
	if [ -f "$work/hold.pid" ]; then
		kill "$(cat "$work/hold.pid")" 2>/dev/null || true
	fi
	if [ -f "$work/sleep.pid" ]; then
		kill "$(cat "$work/sleep.pid")" 2>/dev/null || true
	fi
	unset ZLYME_FAKE_HOLD
}

printf '%s\n' kept > "$work/run/marker" 2>/dev/null || true
signal_holder TERM
signal_holder KILL

if [ "$had_dir" = 0 ] && { [ -e /tmp/drastic-run ] || [ -L /tmp/drastic-run ]; }; then
	fail "the test created /tmp/drastic-run"
fi
if [ "$had_lock" = 0 ] && [ -e /tmp/drastic-run.lock ]; then
	fail "the test created /tmp/drastic-run.lock"
fi
echo "drastic workdir ok"
