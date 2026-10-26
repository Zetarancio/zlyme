#!/bin/sh
# Dolphin and Flycast save binds are owned by mount id.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "save-binds: $*" >&2
	exit 1
}
dol=$ROOT/package/emulators/dolphin-emu/start_dolphin.sh
dbinds=$ROOT/package/emulators/dolphin-emu/dolphin-binds.sh
dc=$ROOT/package/system/nextui/paks/Emus/DC.pak/launch.sh
fbinds=$ROOT/package/system/nextui/zlyme/flycast-binds.sh
pak=$ROOT/package/system/nextui/zlyme/pak-launch.sh
pm=$ROOT/package/system/portmaster/zlyme-portmaster-mounts.sh
mounts_lib=$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh

if grep -E '^[[:space:]]*trap[[:space:]]' "$dol" "$dc"; then
	fail "a launcher still unmounts from an EXIT trap"
fi
grep -q 'exec dolphin-emu-nogui' "$dol" || fail "dolphin no longer execs"
grep -q 'exec flycast' "$dc" || fail "flycast no longer execs"
awk '
	/^run_pak_cmd\(\)/ { on = 1 }
	on && /launch_is_dolphin "\$_exe" && pak_cleanup_failed "\$st"/ { d = 1 }
	on && /launch_is_flycast "\$_exe" && pak_cleanup_failed "\$st"/ { f = 1 }
	on && /^}/ { exit }
	END { exit (d && f) ? 0 : 1 }
' "$pak" || fail "status 125 still releases a Dolphin or Flycast bind"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export PATH="$work/bin:$PATH"
export ZLYME_PM_MOUNTINFO="$work/mountinfo"
export ZLYME_PM_MOUNTS="$work/mounts"
export ZLYME_DOLPHIN_MOUNTINFO="$work/mountinfo"
export ZLYME_FLYCAST_MOUNTINFO="$work/mountinfo"
export ZLYME_DOLPHIN_BINDS="$work/dolphin-reg"
export ZLYME_FLYCAST_BINDS="$work/flycast-reg"
export ZLYME_DOLPHIN_UNRESOLVED="$work/dolphin-unresolved"
export ZLYME_FLYCAST_UNRESOLVED="$work/flycast-unresolved"
export ZLYME_DOLPHIN_BINDS_SH="$dbinds"
export ZLYME_FLYCAST_BINDS_SH="$fbinds"
export ZLYME_PORTMASTER_MOUNTS="$pm"
export ZLYME_MOUNTS_LIB="$mounts_lib"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_FAKE_MOUNT_SEQ="$work/seq"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_FAKE_MOUNT_ARGV="$work/mount-argv"
printf '%s\n' /storage /mnt/sd2 > "$work/libraries"
mkdir -p "$work/bin" \
	"$work/sd2/GC" "$work/sd2/WII" "$work/sd2/DC" \
	"$work/internal/GC" "$work/internal/WII" "$work/internal/DC" \
	"$work/home/.local/share/dolphin-emu/GC" \
	"$work/home/.local/share/dolphin-emu/Wii" \
	"$work/home/.local/share/flycast" \
	"$work/cfg/dolphin-emu" "$work/bios/GC/USA" "$work/bios/GC/EUR" \
	"$work/bios/GC/JAP" "$work/bios/WII" "$work/bios/DC"
: > "$work/rom.iso"
: > "$work/other.iso"

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
cat > "$work/bin/dolphin-emu-nogui" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
echo played > "$ZLYME_TEST_MARK"
exit 0
EOF
cat > "$work/bin/flycast" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
echo played > "$ZLYME_TEST_MARK"
exit 0
EOF
chmod 0755 "$work/bin/mount" "$work/bin/umount" \
	"$work/bin/dolphin-emu-nogui" "$work/bin/flycast"
# shellcheck disable=SC1090
. "$dbinds"
# shellcheck disable=SC1090
. "$fbinds"

gc=$work/home/.local/share/dolphin-emu/GC
wii=$work/home/.local/share/dolphin-emu/Wii
fly=$work/home/.local/share/flycast

reset_table() {
	printf '%s\n' 10 > "$work/seq"
	: > "$work/mountinfo"
	: > "$work/mounts"
	: > "$work/umount.log"
	: > "$work/mount-argv"
	: > "$work/dolphin-reg"
	: > "$work/flycast-reg"
	rm -f "$work/dolphin-unresolved" "$work/flycast-unresolved" "$work/mark"
	unset ZLYME_FAKE_MOUNT_FAIL_PATH ZLYME_FAKE_UMOUNT_FAIL
	unset ZLYME_DOLPHIN_REGISTER_FAIL ZLYME_FLYCAST_REGISTER_FAIL
}

not_unmounted() {
	if grep -Fxq -- "$1" "$work/umount.log"; then
		fail "$1 was unmounted"
	fi
}
id_count() {
	awk -v p="$1" '$5 == p { n++ } END { print n + 0 }' "$work/mountinfo"
}
source_of() {
	awk -v p="$1" '$5 == p { print $9 }' "$work/mountinfo"
}

run_dolphin() {
	SDCARD_PATH=$work/card \
		BIOS_PATH=$work/bios \
		USERDATA_PATH=$work/home \
		XDG_CONFIG_HOME=$work/cfg \
		XDG_DATA_HOME=$work/home/.local/share \
		SAVES_PATH=$1 \
		ZLYME_TEST_MARK=$work/mark \
		sh "$dol" "$work/rom.iso"
}
run_flycast() {
	SDCARD_PATH=$work/card \
		BIOS_PATH=$work/bios \
		USERDATA_PATH=$work/home \
		XDG_CONFIG_HOME=$work/cfg \
		XDG_DATA_HOME=$work/home/.local/share \
		SAVES_PATH=$1 \
		ZLYME_TEST_MARK=$work/mark \
		sh "$dc" "$work/rom.iso"
}

reset_table
set +e
run_dolphin "$work/sd2"
st=$?
set -e
[ "$st" = 0 ] || fail "dolphin did not start ($st)"
grep -qx played "$work/mark" || fail "dolphin did not run"
[ "$(id_count "$gc")" = 1 ] || fail "GC was not one mount"
[ "$(id_count "$wii")" = 1 ] || fail "Wii was not one mount"
[ "$(source_of "$gc")" = "$work/sd2/GC" ] || fail "GC source is wrong"
[ "$(source_of "$wii")" = "$work/sd2/WII" ] || fail "Wii source is wrong"
[ ! -s "$work/umount.log" ] || fail "dolphin unmounted its own binds"
dolphin_bind_release || fail "dolphin cleanup failed"
[ "$(id_count "$gc")" = 0 ] || fail "GC mount remained"
[ "$(id_count "$wii")" = 0 ] || fail "Wii mount remained"
[ ! -s "$work/dolphin-reg" ] || fail "dolphin records remained"
not_unmounted /storage
not_unmounted /mnt/sd2

# The child exec does not release. The parent does, after the process
# is gone. That is also the MENU+START path.
reset_table
run_dolphin "$work/sd2" >/dev/null
[ "$(id_count "$gc")" = 1 ] || fail "exec removed the GC bind"
dolphin_bind_release || fail "parent cleanup after exec failed"
[ "$(id_count "$gc")" = 0 ] || fail "parent cleanup left the GC bind"

# Status 125 does not release, and the next launch fails closed.
reset_table
run_dolphin "$work/sd2" >/dev/null
owned=$(id_count "$gc")
: > "$work/umount.log"
dolphin_mark_unresolved
if dolphin_bind_release; then
	fail "status 125 released a Dolphin bind"
fi
rm -f "$work/mark"
: > "$work/mount-argv"
set +e
run_dolphin "$work/internal"
st=$?
set -e
[ "$st" != 0 ] || fail "dolphin started during an unproved session"
[ ! -e "$work/mark" ] || fail "dolphin played during an unproved session"
[ "$(id_count "$gc")" = "$owned" ] || fail "the unproved launch changed the bind"
[ ! -s "$work/umount.log" ] || fail "the unproved launch unmounted"
dolphin_clear_unresolved
dolphin_bind_release || fail "cleanup after the unresolved session failed"

# An unowned mount is not adopted.
reset_table
printf '%s\n' '50 1 0:50 / '"$gc"' rw - fake other rw' > "$work/mountinfo"
printf '%s\n' "other $gc fake rw 0 0" > "$work/mounts"
rm -f "$work/mark"
set +e
run_dolphin "$work/sd2"
st=$?
set -e
[ "$st" != 0 ] || fail "dolphin started on an unowned mount"
[ ! -e "$work/mark" ] || fail "dolphin played on an unowned mount"
grep -q '^50 ' "$work/mountinfo" || fail "the unowned mount was removed"
not_unmounted "$gc"

# A busy SD2 bind is not reused by the other card.
reset_table
run_dolphin "$work/sd2" >/dev/null
export ZLYME_FAKE_UMOUNT_FAIL=1
dolphin_bind_release || true
grep -q "$(printf '\t%s' "$gc")" "$work/dolphin-reg" || fail "a busy record was dropped"
[ "$(source_of "$gc")" = "$work/sd2/GC" ] || fail "the busy bind lost its source"
owned=$(id_count "$gc")
rm -f "$work/mark"
: > "$work/mount-argv"
set +e
run_dolphin "$work/internal"
st=$?
set -e
[ "$st" != 0 ] || fail "dolphin started on a busy SD2 bind"
[ ! -e "$work/mark" ] || fail "dolphin played through the busy SD2 bind"
[ "$(id_count "$gc")" = "$owned" ] || fail "the refused launch changed the busy bind"
[ "$(source_of "$gc")" = "$work/sd2/GC" ] || fail "the busy source changed"
unset ZLYME_FAKE_UMOUNT_FAIL
dolphin_bind_release || fail "the busy mount was not released on retry"
reset_table
run_dolphin "$work/internal" >/dev/null
[ "$(source_of "$gc")" = "$work/internal/GC" ] || fail "the new card was not bound"
if source_of "$gc" | grep -q "$work/sd2/GC"; then
	fail "the SD2 source remained"
fi
dolphin_bind_release || fail "internal dolphin cleanup failed"

# The second bind fails.
reset_table
export ZLYME_FAKE_MOUNT_FAIL_PATH="$wii"
rm -f "$work/mark"
set +e
run_dolphin "$work/sd2"
st=$?
set -e
unset ZLYME_FAKE_MOUNT_FAIL_PATH
[ "$st" != 0 ] || fail "dolphin started after a partial bind"
[ ! -e "$work/mark" ] || fail "dolphin played after a partial bind"
[ "$(id_count "$gc")" = 0 ] || fail "the partial GC bind remained"
[ "$(id_count "$wii")" = 0 ] || fail "the failed Wii destination was mounted"

# Registration fails and rollback removes the mount.
reset_table
export ZLYME_DOLPHIN_REGISTER_FAIL=1
rm -f "$work/mark"
set +e
run_dolphin "$work/sd2"
st=$?
set -e
unset ZLYME_DOLPHIN_REGISTER_FAIL
[ "$st" != 0 ] || fail "dolphin started after registration failed"
[ ! -e "$work/mark" ] || fail "dolphin played after registration failed"
[ "$(id_count "$gc")" = 0 ] || fail "rollback left the GC bind"
[ ! -s "$work/dolphin-reg" ] || fail "a failed registration left a record"

# Registration and rollback both fail. The id is kept.
reset_table
export ZLYME_DOLPHIN_REGISTER_FAIL=1
export ZLYME_FAKE_UMOUNT_FAIL=1
rm -f "$work/mark"
set +e
run_dolphin "$work/sd2"
st=$?
set -e
unset ZLYME_DOLPHIN_REGISTER_FAIL
unset ZLYME_FAKE_UMOUNT_FAIL
[ "$st" != 0 ] || fail "dolphin started when rollback could not unmount"
[ "$(id_count "$gc")" = 1 ] || fail "the unrecorded GC bind disappeared"
grep -q "$(printf '\t%s' "$gc")" "$work/dolphin-reg" || fail "the busy unrecorded bind was not kept"
dolphin_bind_release || fail "the retained bind could not be released later"

# Replaced, covered, and hidden mounts are not unmounted.
reset_table
printf '%s\n' '9 1 0:9 / '"$gc"' rw - fake replacement rw' > "$work/mountinfo"
printf '7\t%s\n' "$gc" > "$work/dolphin-reg"
: > "$work/umount.log"
dolphin_bind_release || true
grep -q '^9 ' "$work/mountinfo" || fail "the replacement mount was removed"
not_unmounted "$gc"
printf '%s\n' \
	'7 40 0:7 / '"$gc"' rw - fake high rw' \
	'40 1 0:40 / '"$gc"' rw - fake low rw' \
	> "$work/mountinfo"
printf '40\t%s\n' "$gc" > "$work/dolphin-reg"
: > "$work/umount.log"
if dolphin_bind_release; then
	fail "a covered mount was reported free"
fi
grep -q '^40'"$(printf '\t')" "$work/dolphin-reg" || fail "the covered id was dropped"
not_unmounted "$gc"
hide=$work/home/.local/share
printf '%s\n' \
	"20 10 0:20 / $hide rw - fake top rw" \
	"10 1 0:10 / $hide rw - fake base rw" \
	"30 10 0:30 / $hide/dolphin-emu rw - fake game rw" \
	"40 30 0:40 / $gc rw - fake save rw" \
	> "$work/mountinfo"
printf '40\t%s\n' "$gc" > "$work/dolphin-reg"
: > "$work/umount.log"
if dolphin_bind_release; then
	fail "a hidden mount was reported free"
fi
grep -q '^40'"$(printf '\t')" "$work/dolphin-reg" || fail "the hidden id was dropped"
not_unmounted "$gc"

# Protected roots are not unmounted.
reset_table
printf '%s\n' '1 0 0:1 / /storage rw - fake storage rw' > "$work/mountinfo"
printf '3\t/storage\n' > "$work/dolphin-reg"
: > "$work/umount.log"
dolphin_bind_release || true
not_unmounted /storage
grep -q '^1 ' "$work/mountinfo" || fail "the storage mount was removed"

# A missing ROM creates no mount.
reset_table
set +e
SDCARD_PATH=$work/card BIOS_PATH=$work/bios USERDATA_PATH=$work/home \
	XDG_CONFIG_HOME=$work/cfg SAVES_PATH=$work/sd2 \
	sh "$dol" >/dev/null 2>&1
st=$?
set -e
[ "$st" != 0 ] || fail "dolphin started without a ROM"
[ ! -s "$work/mountinfo" ] || fail "a missing ROM created a mount"

# The helper is required.
reset_table
set +e
ZLYME_DOLPHIN_BINDS_SH=/no/such/dolphin-binds.sh \
	SDCARD_PATH=$work/card BIOS_PATH=$work/bios USERDATA_PATH=$work/home \
	XDG_CONFIG_HOME=$work/cfg SAVES_PATH=$work/sd2 \
	sh "$dol" "$work/rom.iso" >/dev/null 2>&1
st=$?
set -e
[ "$st" != 0 ] || fail "dolphin started without its bind helper"
[ ! -s "$work/mountinfo" ] || fail "a missing helper created a mount"

# Flycast: one bind, kept until the parent releases it.
reset_table
set +e
run_flycast "$work/sd2"
st=$?
set -e
[ "$st" = 0 ] || fail "flycast did not start ($st)"
grep -qx played "$work/mark" || fail "flycast did not run"
[ "$(id_count "$fly")" = 1 ] || fail "flycast was not one mount"
[ "$(source_of "$fly")" = "$work/sd2/DC" ] || fail "flycast source is wrong"
[ ! -s "$work/umount.log" ] || fail "flycast unmounted before it exited"
flycast_bind_release || fail "flycast cleanup failed"
[ "$(id_count "$fly")" = 0 ] || fail "the flycast mount remained"

reset_table
run_flycast "$work/sd2" >/dev/null
flycast_mark_unresolved
: > "$work/umount.log"
if flycast_bind_release; then
	fail "status 125 released a Flycast bind"
fi
set +e
run_flycast "$work/internal"
st=$?
set -e
[ "$st" != 0 ] || fail "flycast started during an unproved session"
[ "$(source_of "$fly")" = "$work/sd2/DC" ] || fail "the unproved launch changed the source"
flycast_clear_unresolved
flycast_bind_release || fail "flycast cleanup after the unresolved session failed"

reset_table
printf '%s\n' '50 1 0:50 / '"$fly"' rw - fake other rw' > "$work/mountinfo"
: > "$work/flycast-reg"
set +e
run_flycast "$work/sd2"
st=$?
set -e
[ "$st" != 0 ] || fail "flycast started on an unowned mount"
grep -q '^50 ' "$work/mountinfo" || fail "flycast removed an unowned mount"

reset_table
run_flycast "$work/sd2" >/dev/null
export ZLYME_FAKE_UMOUNT_FAIL=1
flycast_bind_release || true
set +e
run_flycast "$work/internal"
st=$?
set -e
[ "$st" != 0 ] || fail "flycast reused a busy SD2 bind"
[ "$(source_of "$fly")" = "$work/sd2/DC" ] || fail "the busy flycast source changed"
unset ZLYME_FAKE_UMOUNT_FAIL
flycast_bind_release || fail "the busy flycast mount was not released"
reset_table
run_flycast "$work/internal" >/dev/null
[ "$(source_of "$fly")" = "$work/internal/DC" ] || fail "flycast did not bind the new card"
flycast_bind_release || fail "internal flycast cleanup failed"

reset_table
export ZLYME_FLYCAST_REGISTER_FAIL=1
set +e
run_flycast "$work/sd2"
st=$?
set -e
unset ZLYME_FLYCAST_REGISTER_FAIL
[ "$st" != 0 ] || fail "flycast started after registration failed"
[ "$(id_count "$fly")" = 0 ] || fail "flycast rollback left the bind"

reset_table
export ZLYME_FLYCAST_REGISTER_FAIL=1
export ZLYME_FAKE_UMOUNT_FAIL=1
set +e
run_flycast "$work/sd2"
st=$?
set -e
unset ZLYME_FLYCAST_REGISTER_FAIL
unset ZLYME_FAKE_UMOUNT_FAIL
[ "$st" != 0 ] || fail "flycast started when rollback could not unmount"
grep -q "$(printf '\t%s' "$fly")" "$work/flycast-reg" || fail "flycast did not keep the busy id"
flycast_bind_release || fail "the retained flycast bind could not be released"

reset_table
set +e
SAVES_PATH=$work/sd2 USERDATA_PATH=$work/home XDG_CONFIG_HOME=$work/cfg \
	BIOS_PATH=$work/bios sh "$dc" >/dev/null 2>&1
st=$?
set -e
[ "$st" != 0 ] || fail "flycast started without a ROM"
[ ! -s "$work/mountinfo" ] || fail "a missing ROM created a flycast mount"

reset_table
set +e
ZLYME_FLYCAST_BINDS_SH=/no/such/flycast-binds.sh \
	SAVES_PATH=$work/sd2 USERDATA_PATH=$work/home BIOS_PATH=$work/bios \
	sh "$dc" "$work/rom.iso" >/dev/null 2>&1
st=$?
set -e
[ "$st" != 0 ] || fail "flycast started without its bind helper"
[ ! -s "$work/mountinfo" ] || fail "a missing helper created a flycast mount"

echo "save binds ok"
