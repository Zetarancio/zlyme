#!/bin/sh
# DraStic must not delete persistent saves through a leftover mount or symlink.
# Mounts are simulated. This test does not call the real mount command.
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
	fail "a failed bind is still replaced with a symlink"
fi
if [ -e /tmp/drastic-run ] || [ -L /tmp/drastic-run ]; then
	fail "/tmp/drastic-run already exists; not touching it"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export PATH="$work/bin:$PATH"
export ZLYME_DRASTIC_WORKDIR="$work/run"
export ZLYME_DRASTIC_MOUNTINFO="$work/mountinfo"
export ZLYME_DRASTIC_BIN="$work/bin/drastic"
export ZLYME_FAKE_MOUNT_SEQ="$work/seq"
export ZLYME_FAKE_MOUNT_LOG="$work/mount.log"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_TEST_MARK="$work/mark"
export ZLYME_FAKE_WORK="$work"
unset ZLYME_DRASTIC_PRELOAD ZLYME_FAKE_MOUNT_FAIL_PATH ZLYME_FAKE_UMOUNT_FAIL

mkdir -p "$work/bin" "$work/saves/backup" "$work/saves/savestates" \
	"$work/cfg" "$work/run"
printf '%s\n' keep > "$work/saves/backup/keep.sav"
printf '%s\n' state > "$work/saves/savestates/slot.dss"
printf '%s\n' 'user-cfg' > "$work/cfg/drastic.cfg"

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
printf '%s\n' "$target" >> "$ZLYME_FAKE_UMOUNT_LOG"
if [ "${ZLYME_FAKE_UMOUNT_FAIL:-0}" = 1 ]; then
	exit 1
fi
tmp=$(mktemp)
awk -v p="$target" '$5 != p { print }' "$ZLYME_DRASTIC_MOUNTINFO" > "$tmp"
mv -f "$tmp" "$ZLYME_DRASTIC_MOUNTINFO"
EOF
cat > "$work/bin/drastic" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
echo played > "$ZLYME_TEST_MARK"
if [ "${ZLYME_FAKE_STACK_BACKUP:-0}" = 1 ]; then
	printf '%s 1 0:80 / %s/run/backup rw - fake extra rw\n' 80 "$ZLYME_FAKE_WORK" >> "$ZLYME_DRASTIC_MOUNTINFO"
fi
exit 0
EOF
chmod 0755 "$work/bin/mount" "$work/bin/umount" "$work/bin/drastic"
command -v mount | grep -q "$work/bin/mount" || fail "PATH did not select the fake mount"

not_unmounted() {
	if [ -s "$work/umount.log" ] && grep -Fxq -- "$1" "$work/umount.log"; then
		fail "$1 was unmounted"
	fi
}

run_it() {
	XDG_CONFIG_HOME=$work/cfg_parent \
		SAVES_PATH=$work/saves_parent \
		SDCARD_PATH=$work/card \
		sh "$script" "$work/game.nds"
}

# The launcher appends /NDS itself. Point the parents at the fixtures.
mkdir -p "$work/cfg_parent" "$work/saves_parent" "$work/card"
rm -rf "$work/saves" "$work/cfg"
mkdir -p "$work/saves_parent/NDS/backup" "$work/saves_parent/NDS/savestates" \
	"$work/cfg_parent/drastic"
printf '%s\n' keep > "$work/saves_parent/NDS/backup/keep.sav"
printf '%s\n' state > "$work/saves_parent/NDS/savestates/slot.dss"
printf '%s\n' 'user-cfg' > "$work/cfg_parent/drastic/drastic.cfg"
save_backup=$work/saves_parent/NDS/backup
save_states=$work/saves_parent/NDS/savestates

# The earlier fixtures were the wrong shape. Keep the names used below.
work_saves_backup=$save_backup
work_saves_states=$save_states

reset_table() {
	printf '%s\n' 10 > "$work/seq"
	: > "$work/mountinfo"
	: > "$work/mount.log"
	: > "$work/umount.log"
	rm -f "$work/mark"
	unset ZLYME_FAKE_MOUNT_FAIL_PATH ZLYME_FAKE_UMOUNT_FAIL
	rm -rf "$work/run"
	mkdir -p "$work/run"
}

saves_intact() {
	printf '%s\n' keep | cmp -s - "$work_saves_backup/keep.sav" || fail "backup save changed"
	printf '%s\n' state | cmp -s - "$work_saves_states/slot.dss" || fail "savestate changed"
}

# 1. A clean directory is removed and the launch proceeds.
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
saves_intact
grep -q 'user-cfg' "$work/cfg_parent/drastic/drastic.cfg" || fail "user config was replaced"
grep -Fxq "$work/run/backup" "$work/umount.log" || fail "backup was not released"
grep -Fxq "$work/run/savestates" "$work/umount.log" || fail "savestates were not released"
grep -q '^2 ' "$work/mountinfo" || fail "the unrelated /storage mount was removed"
not_unmounted /storage
if [ -e /tmp/drastic-run ] || [ -L /tmp/drastic-run ]; then
	fail "default work directory was created"
fi

# 2. A simulated stale bind refuses before deletion.
reset_table
printf '%s\n' stale > "$work/run/marker"
printf '%s 1 0:9 / %s rw - fake %s rw\n' \
	9 "$work/run/backup" "$work_saves_backup" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a stale bind was launched"
[ -f "$work/run/marker" ] || fail "stale bind deleted the work directory"
saves_intact
[ ! -s "$work/umount.log" ] || fail "a stale bind was unmounted"
grep -q "$work/run/backup" "$work/mountinfo" || fail "the stale bind left the table"

# 3. The work directory itself being mounted is the same refusal.
reset_table
printf '%s\n' sticky > "$work/run/marker"
printf '%s 1 0:8 / %s rw - fake %s rw\n' \
	8 "$work/run" "$work_saves_backup" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a mounted work directory was launched"
[ -f "$work/run/marker" ] || fail "mounted work directory was deleted"
saves_intact
[ ! -s "$work/umount.log" ] || fail "a mounted work directory was unmounted"

# 4. A failed unmount does not let the next launch delete.
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
grep -q "$work/run/backup" "$work/mountinfo" || fail "failed unmount dropped the backup line"
unset ZLYME_FAKE_UMOUNT_FAIL
: > "$work/umount.log"
printf '%s\n' next > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "the launch after a failed unmount proceeded"
[ -f "$work/run/marker" ] || fail "the launch after a failed unmount deleted the work directory"
saves_intact
[ ! -s "$work/umount.log" ] || fail "the second launch unmounted a leftover"

# 5. A symlink at the save slot cannot redirect cleanup.
reset_table
rmdir "$work/run"
ln -s "$work_saves_backup" "$work/run"
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "symlink work directory exited $st"
saves_intact
[ ! -L "$work/run" ] || fail "work directory stayed a symlink"
[ -d "$work/run" ] || fail "work directory was not recreated"

reset_table
ln -s "$work_saves_backup" "$work/run/backup"
ln -s "$work_saves_states" "$work/run/savestates"
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "symlink slots exited $st"
saves_intact
[ ! -L "$work/run/backup" ] || fail "backup stayed a symlink"
[ ! -L "$work/run/savestates" ] || fail "savestates stayed a symlink"

# 6. An unexpected mount is not unmounted, including a near name.
reset_table
printf '%s 1 0:4 / %s-extra rw - fake other rw\n' 4 "$work/run" > "$work/mountinfo"
printf '%s\n' '5 1 0:5 / /storage rw - fake storage rw' >> "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" = 0 ] || fail "an unrelated mount blocked launch ($st)"
grep -q '^4 ' "$work/mountinfo" || fail "the near-name mount was removed"
grep -q '^5 ' "$work/mountinfo" || fail "the storage mount was removed"
not_unmounted "$work/run-extra"
not_unmounted /storage
saves_intact

# 7. A mount whose path contains an escaped space still blocks deletion.
reset_table
printf '%s\n' blocked > "$work/run/marker"
printf '%s 1 0:6 / %s/foo\\040bar rw - fake src rw\n' 6 "$work/run" > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "an escaped mount path was ignored"
[ -f "$work/run/marker" ] || fail "escaped mount path deleted the work directory"
saves_intact
[ ! -s "$work/umount.log" ] || fail "an escaped mount was unmounted"

# 8. An unreadable or malformed table refuses before deletion.
reset_table
printf '%s\n' blocked > "$work/run/marker"
printf '%s\n' 'not a mount line' > "$work/mountinfo"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "a malformed table was accepted"
[ -f "$work/run/marker" ] || fail "a malformed table deleted the work directory"

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
saves_intact

# 9. A failed bind does not create a symlink or unmount anything else.
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
[ ! -s "$work/umount.log" ] || fail "a failed bind unmounted something"
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
grep -q "$work/run/backup" "$work/mountinfo" || fail "the first bind was dropped"
[ ! -s "$work/umount.log" ] || fail "a partial bind was unmounted"
unset ZLYME_FAKE_MOUNT_FAIL_PATH
: > "$work/umount.log"
printf '%s\n' next > "$work/run/marker"
set +e
run_it
st=$?
set -e
[ "$st" != 0 ] || fail "the launch after a partial bind proceeded"
[ -f "$work/run/marker" ] || fail "the launch after a partial bind deleted the work directory"
saves_intact

# 10. Two mounts at one slot are left alone.
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
saves_intact
[ ! -s "$work/umount.log" ] || fail "two mounts were unmounted"

# 11. A second mount that appears before release is left mounted.
reset_table
printf '%s\n' '1 0 0:1 / /tmp rw - tmpfs tmpfs rw' > "$work/mountinfo"
export ZLYME_FAKE_STACK_BACKUP=1
set +e
run_it
st=$?
set -e
unset ZLYME_FAKE_STACK_BACKUP
[ "$st" != 0 ] || fail "a stacked backup mount was treated as released"
grep -qx played "$work/mark" || fail "the stacked case did not reach the emulator"
saves_intact
grep -q '^80 ' "$work/mountinfo" || fail "the extra backup mount was removed"
not_unmounted "$work/run/backup"
grep -Fxq "$work/run/savestates" "$work/umount.log" || fail "the single savestate mount was not released"

if [ -e /tmp/drastic-run ] || [ -L /tmp/drastic-run ]; then
	fail "default work directory was created"
fi
echo "drastic workdir ok"
