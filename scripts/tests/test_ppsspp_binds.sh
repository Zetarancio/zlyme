#!/bin/sh
# PPSSPP save binds are identified by mountinfo id, not by the pathname.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "ppsspp-binds: $*" >&2
	exit 1
}
psp=$ROOT/package/system/nextui/paks/Emus/PSP.pak/launch.sh
pak=$ROOT/package/system/nextui/zlyme/pak-launch.sh
binds=$ROOT/package/system/nextui/zlyme/ppsspp-binds.sh
pm=$ROOT/package/system/portmaster/zlyme-portmaster-mounts.sh
mounts_lib=$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh
if grep -E '^[[:space:]]*trap[[:space:]]' "$psp"; then
	fail "PSP.pak still unmounts from an EXIT trap"
fi
grep -q 'exec PPSSPPSDL' "$psp" || fail "PSP.pak no longer execs PPSSPPSDL"
grep -q 'ppsspp_bind_release' "$pak" || fail "pak-launch does not release PPSSPP binds"
awk '
	/^run_pak_cmd\(\)/ { on = 1 }
	on && /pak_cleanup_failed "\$st"/ { saw = 1 }
	on && saw && /ppsspp_bind_release/ { guarded = 1 }
	on && /^}/ { exit }
	END { exit guarded ? 0 : 1 }
' "$pak" || fail "status 125 still releases PPSSPP binds"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export PATH="$work/bin:$PATH"
export ZLYME_PPSSPP_BINDS="$work/binds"
export ZLYME_PPSSPP_MOUNTINFO="$work/mountinfo"
export ZLYME_PM_MOUNTINFO="$work/mountinfo"
export ZLYME_PM_MOUNTS="$work/mounts"
export ZLYME_FAKE_MOUNT_SEQ="$work/seq"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_FAKE_MOUNT_ARGV="$work/mount-argv"
export ZLYME_PORTMASTER_MOUNTS="$pm"
export ZLYME_MOUNTS_LIB="$mounts_lib"
export ZLYME_PPSSPP_BINDS_SH="$binds"
export ZLYME_LIBRARIES_FILE="$work/libraries"
printf '%s\n' /storage /mnt/sd2 > "$work/libraries"
printf '%s\n' 10 > "$work/seq"
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/umount.log"
: > "$work/mount-argv"
: > "$work/binds"
mkdir -p "$work/bin" \
	"$work/sd2/PSP/SAVEDATA" "$work/sd2/PSP/PPSSPP_STATE" \
	"$work/card/.config/ppsspp/PSP/SAVEDATA" \
	"$work/card/.config/ppsspp/PSP/PPSSPP_STATE" \
	"$work/card/.config/ppsspp/PSP/SYSTEM"
printf '%s\n' '[SystemParam]' > "$work/card/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
: > "$work/rom.iso"
save=$work/card/.config/ppsspp/PSP/SAVEDATA
state=$work/card/.config/ppsspp/PSP/PPSSPP_STATE

cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
set -eu
for arg in "$@"; do
	printf 'ARG %s\n' "$arg" >> "$ZLYME_FAKE_MOUNT_ARGV"
done
printf 'END\n' >> "$ZLYME_FAKE_MOUNT_ARGV"
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
if [ -n "${ZLYME_FAKE_MOUNT_FAIL_PATH:-}" ] &&
	[ "$dest" = "$ZLYME_FAKE_MOUNT_FAIL_PATH" ]; then
	exit 1
fi
[ "$n" -ge 2 ] || exit 1
# shellcheck disable=SC1090
. "${ZLYME_PORTMASTER_MOUNTS:?}"
parent=$(pm_new_parent "$dest") || exit 1
id=$(cat "$ZLYME_FAKE_MOUNT_SEQ")
printf '%s\n' "$((id + 1))" > "$ZLYME_FAKE_MOUNT_SEQ"
printf '%s %s 0:1 / %s rw - fake %s rw\n' "$id" "$parent" "$dest" "$src" >> "$ZLYME_PM_MOUNTINFO"
printf '%s %s fake rw 0 0\n' "$src" "$dest" >> "$ZLYME_PM_MOUNTS"
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
printf '%s\n' "$target" >> "$ZLYME_FAKE_UMOUNT_LOG"
if [ "${ZLYME_FAKE_UMOUNT_FAIL:-0}" = 1 ]; then
	exit 1
fi
# shellcheck disable=SC1090
. "${ZLYME_PORTMASTER_MOUNTS:?}"
vid=$(pm_visible_id "$target" 2>/dev/null || true)
[ -n "$vid" ] || exit 1
tmp=$(mktemp)
awk -v id="$vid" '$1 != id { print }' "$ZLYME_PM_MOUNTINFO" > "$tmp"
mv -f "$tmp" "$ZLYME_PM_MOUNTINFO"
tmp=$(mktemp)
awk -v p="$target" '$2 != p { print }' "$ZLYME_PM_MOUNTS" > "$tmp"
mv -f "$tmp" "$ZLYME_PM_MOUNTS"
EOF
cat > "$work/bin/PPSSPPSDL" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
echo played > "$ZLYME_TEST_MARK"
exit 9
EOF
chmod 0755 "$work/bin/mount" "$work/bin/umount" "$work/bin/PPSSPPSDL"

run_psp_from() {
	PATH=$work/bin:/usr/bin:/bin \
		ZLYME_TEST_MARK=$work/mark \
		XDG_CONFIG_HOME=$work/card/.config \
		SDCARD_PATH=$work/card \
		USERDATA_PATH=$work/home \
		BIOS_PATH=$work/bios \
		SAVES_PATH=$1 \
		sh "$psp" "$work/rom.iso"
}
run_psp() {
	run_psp_from "$work/sd2"
}
# shellcheck disable=SC1090
. "$binds"
# shellcheck disable=SC1090
. "$pak"

not_unmounted() {
	if grep -Fxq -- "$1" "$work/umount.log"; then
		fail "$1 was unmounted"
	fi
}
id_count() {
	awk -v p="$1" '$5 == p { n++ } END { print n + 0 }' "$work/mountinfo"
}

rm -f "$work/mark"
set +e
run_psp
st=$?
set -e
[ "$st" = 9 ] || fail "PPSSPP exit status was not preserved ($st)"
grep -qx played "$work/mark" || fail "PPSSPP did not run"
[ ! -s "$work/umount.log" ] || fail "binds were released before PPSSPP exited"
grep -q "$(printf '\t%s' "$save")" "$work/binds" || fail "SAVEDATA id was not recorded"
grep -q "$(printf '\t%s' "$state")" "$work/binds" || fail "STATE id was not recorded"
[ "$(id_count "$save")" = 1 ] || fail "SAVEDATA was not one mount"
grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo" || fail "the bind source is not the SD2 save directory"
before=$(id_count "$save")
rm -f "$work/mark"
mkdir -p "$work/internal/PSP/SAVEDATA" "$work/internal/PSP/PPSSPP_STATE"
set +e
run_psp_from "$work/internal"
st=$?
set -e
[ "$st" != 9 ] || fail "PPSSPP started while the SD2 bind was still mounted"
[ ! -e "$work/mark" ] || fail "PPSSPP played on the previous card's bind"
[ "$(id_count "$save")" = "$before" ] || fail "the refused launch changed the bind"
grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo" || fail "the refused launch replaced the SD2 source"
ppsspp_bind_release || fail "normal cleanup failed"
[ ! -s "$work/binds" ] || fail "released records were kept"
[ "$(id_count "$save")" = 0 ] || fail "SAVEDATA mount remained"
[ "$(id_count "$state")" = 0 ] || fail "STATE mount remained"
not_unmounted /storage
not_unmounted /mnt/sd2
rm -f "$work/mark"
: > "$work/umount.log"
set +e
run_psp_from "$work/internal"
st=$?
set -e
[ "$st" = 9 ] || fail "PPSSPP did not start from the internal card after cleanup ($st)"
grep -q "$work/internal/PSP/SAVEDATA" "$work/mountinfo" || fail "the new bind source is not the internal save directory"
if grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo"; then
	fail "the SD2 source remained after the internal launch"
fi
ppsspp_bind_release || fail "internal bind cleanup failed"

# Pre-existing unowned mount.
printf '%s\n' '50 1 0:50 / '"$save"' rw - fake other rw' > "$work/mountinfo"
printf '%s\n' "other $save fake rw 0 0" > "$work/mounts"
: > "$work/binds"
: > "$work/umount.log"
rm -f "$work/mark"
set +e
run_psp
st=$?
set -e
[ "$st" != 9 ] || fail "PPSSPP started on an unowned mount"
[ ! -e "$work/mark" ] || fail "PPSSPP ran on an unowned mount"
grep -q '^50'"$(printf '\t')" "$work/binds" && fail "the unowned id was adopted"
grep -q '^50 ' "$work/mountinfo" || fail "the unowned mount was removed"
not_unmounted "$save"

# Replaced mount: the recorded id is gone and a different id is visible.
printf '%s\n' '9 1 0:9 / '"$save"' rw - fake replacement rw' > "$work/mountinfo"
printf '7\t%s\n' "$save" > "$work/binds"
: > "$work/umount.log"
ppsspp_bind_release || true
not_unmounted "$save"
grep -q '^9 ' "$work/mountinfo" || fail "the replacement mount was removed"
if grep -q '^7'"$(printf '\t')" "$work/binds"; then
	fail "a missing owned id was kept"
fi

# Covered owned mount.
printf '%s\n' \
	'7 40 0:7 / '"$save"' rw - fake high rw' \
	'40 1 0:40 / '"$save"' rw - fake low rw' \
	> "$work/mountinfo"
printf '40\t%s\n' "$save" > "$work/binds"
: > "$work/umount.log"
if ppsspp_bind_release; then
	fail "a covered mount was reported free"
fi
not_unmounted "$save"
grep -q '^40'"$(printf '\t')" "$work/binds" || fail "the covered id was dropped"
grep -q '^7 ' "$work/mountinfo" || fail "the covering mount was removed"

# Hidden owned mount under a covered prefix.
hide=/storage/.config/ppsspp/PSP/SAVEDATA
printf '%s\n' \
	'20 10 0:20 / /storage/.config rw - fake top rw' \
	'10 1 0:10 / /storage/.config rw - fake base rw' \
	'30 10 0:30 / /storage/.config/ppsspp rw - fake game rw' \
	"40 30 0:40 / $hide rw - fake save rw" \
	> "$work/mountinfo"
printf '40\t%s\n' "$hide" > "$work/binds"
: > "$work/umount.log"
if ppsspp_bind_release; then
	fail "a hidden mount was reported free"
fi
not_unmounted "$hide"
grep -q '^40'"$(printf '\t')" "$work/binds" || fail "the hidden id was dropped"

# A busy SD2 bind must not be reused by a launch from the other card.
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/binds"
: > "$work/umount.log"
: > "$work/mount-argv"
run_psp >/dev/null || true
export ZLYME_FAKE_UMOUNT_FAIL=1
ppsspp_bind_release || true
grep -q "$(printf '\t%s' "$save")" "$work/binds" || fail "a busy record was dropped"
grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo" || fail "the busy bind lost its SD2 source"
owned=$(id_count "$save")
rm -f "$work/mark"
: > "$work/mount-argv"
set +e
run_psp_from "$work/internal"
st=$?
set -e
[ "$st" != 9 ] || fail "PPSSPP started on a busy SD2 bind"
[ ! -e "$work/mark" ] || fail "PPSSPP played through the busy SD2 bind"
if grep -q -- "--bind" "$work/mount-argv"; then
	fail "a busy destination was mounted again"
fi
[ "$(id_count "$save")" = "$owned" ] || fail "the refused launch changed the busy bind"
grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo" || fail "the busy source changed"
unset ZLYME_FAKE_UMOUNT_FAIL
ppsspp_bind_release || fail "the busy mount was not released on retry"
[ ! -s "$work/binds" ] || fail "the retried record was kept"

# Partial failure undoes only the bind created by this attempt.
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/binds"
: > "$work/umount.log"
rm -f "$work/mark"
export ZLYME_FAKE_MOUNT_FAIL_PATH="$state"
set +e
run_psp
st=$?
set -e
unset ZLYME_FAKE_MOUNT_FAIL_PATH
[ "$st" != 9 ] || fail "PPSSPP started after a partial bind failure"
[ ! -e "$work/mark" ] || fail "PPSSPP ran after a partial bind failure"
[ "$(id_count "$save")" = 0 ] || fail "the partial bind was left mounted"
[ "$(id_count "$state")" = 0 ] || fail "the failed destination was mounted"
[ ! -s "$work/binds" ] || fail "a partial record was kept"

# The record cannot be created.
rm -rf "$work/binds"
mkdir -p "$work/binds"
rm -f "$work/mark"
: > "$work/mountinfo"
set +e
run_psp
st=$?
set -e
[ "$st" != 9 ] || fail "PPSSPP started without a bind record"
[ ! -e "$work/mark" ] || fail "PPSSPP ran without a bind record"
[ "$(id_count "$save")" = 0 ] || fail "a bind was created without a record"
rmdir "$work/binds"
: > "$work/binds"

# Registration fails and the new mount is removed.
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/binds"
: > "$work/umount.log"
rm -f "$work/mark"
export ZLYME_PPSSPP_REGISTER_FAIL=1
set +e
run_psp
st=$?
set -e
unset ZLYME_PPSSPP_REGISTER_FAIL
[ "$st" != 9 ] || fail "PPSSPP started after registration failed"
[ ! -e "$work/mark" ] || fail "PPSSPP ran after registration failed"
[ "$(id_count "$save")" = 0 ] || fail "rollback left the unrecorded bind"
[ ! -s "$work/binds" ] || fail "a failed registration left a record"

# Registration and rollback unmount both fail. The mount stays and the
# id is recorded so a later cleanup can retry it.
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/binds"
: > "$work/umount.log"
rm -f "$work/mark"
export ZLYME_PPSSPP_REGISTER_FAIL=1
export ZLYME_FAKE_UMOUNT_FAIL=1
set +e
run_psp
st=$?
set -e
unset ZLYME_PPSSPP_REGISTER_FAIL
unset ZLYME_FAKE_UMOUNT_FAIL
[ "$st" != 9 ] || fail "PPSSPP started when rollback could not unmount"
[ ! -e "$work/mark" ] || fail "PPSSPP ran when rollback could not unmount"
[ "$(id_count "$save")" = 1 ] || fail "the unrecorded bind disappeared"
grep -q "$(printf '\t%s' "$save")" "$work/binds" || fail "the busy unrecorded bind was not kept"
grep -q "$work/sd2/PSP/SAVEDATA" "$work/mountinfo" || fail "rollback changed the save source"
ppsspp_bind_release || fail "the retained bind could not be released later"
[ "$(id_count "$save")" = 0 ] || fail "the retained bind remained after retry"

# Status 125 does not release a live owned mount.
: > "$work/mountinfo"
: > "$work/mounts"
: > "$work/umount.log"
run_psp >/dev/null || true
st=125
if ! pak_cleanup_failed "$st"; then
	ppsspp_bind_release || true
fi
[ ! -s "$work/umount.log" ] || fail "status 125 released a PPSSPP bind"
grep -q "$(printf '\t%s' "$save")" "$work/binds" || fail "status 125 dropped the record"
ppsspp_bind_release || fail "cleanup after the unresolved session failed"

# Unrelated mounts stay.
printf '%s\n' \
	'1 0 0:1 / /storage rw - fake storage rw' \
	'2 1 0:2 / /mnt/sd2 rw - fake sd2 rw' \
	'3 1 0:3 / /tmp/other rw - fake other rw' \
	>> "$work/mountinfo"
: > "$work/umount.log"
ppsspp_bind_release || true
not_unmounted /storage
not_unmounted /mnt/sd2
not_unmounted /tmp/other
grep -q '^1 ' "$work/mountinfo" || fail "/storage left the mount table"
grep -q '^2 ' "$work/mountinfo" || fail "/mnt/sd2 left the mount table"

echo "ppsspp binds ok"
