#!/bin/sh
# PortMaster transient mounts. Fake mount(8) edits a table; no root mounts.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
EXEC=$ROOT/package/system/portmaster/zlyme-portmaster-exec
CLEAN=$ROOT/package/system/portmaster/zlyme-portmaster-cleanup
LIB=$ROOT/package/system/nextui/zlyme/zlyme-library.sh
SESSION=$ROOT/package/system/nextui/nextui-session
work=$(mktemp -d)
finish() {
	if [ -r "$work/usb-run/reaper.pid" ]; then
		_rp=$(cat "$work/usb-run/reaper.pid" 2>/dev/null || true)
		if [ -n "${_rp:-}" ]; then
			kill "$_rp" 2>/dev/null || true
		fi
	fi
	rm -rf "$work"
}
trap finish EXIT

export ZLYME_PM_MOUNTS="$work/mounts"
export ZLYME_PM_MOUNTINFO="$work/mountinfo"
export ZLYME_FAKE_MOUNT_SEQ="$work/mountseq"
export ZLYME_PM_REGISTRY="$work/owned"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_MOUNTS_LIB="$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh"
export ZLYME_LIBRARY_SH="$LIB"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_FAKE_MOUNT_FAIL=0
export ZLYME_FAKE_UMOUNT_FAIL=0
export ZLYME_PORTMASTER_MOUNTS="$ROOT/package/system/portmaster/zlyme-portmaster-mounts.sh"
export ZLYME_PYTHON_LOG="$work/python.log"
export ZLYME_INPUT_BIN="$work/bin/zlyme-input"
export ZLYME_INPUT_LOG="$work/input.log"
export ZLYME_SYSTEMCTL_LOG="$work/systemctl.log"
export PATH="$work/bin:$PATH"
: > "$ZLYME_PYTHON_LOG"
: > "$ZLYME_INPUT_LOG"
: > "$ZLYME_SYSTEMCTL_LOG"

mkdir -p "$work/bin"
printf '%s\n' /storage "/mnt/media/USB Games" > "$work/libraries"

cat > "$work/bin/python3" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_PYTHON_LOG:?}"
exit 127
EOF

cat > "$ZLYME_INPUT_BIN" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_INPUT_LOG:?}"
EOF

cat > "$work/bin/systemctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_SYSTEMCTL_LOG:?}"
exit 19
EOF

# Remount leaves the mount count unchanged. Option values are not operands.
cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
set -eu
if [ "${ZLYME_FAKE_MOUNT_FAIL:-0}" = 1 ]; then
	exit 1
fi
take=
remount=0
n=0
dest=
for arg in "$@"; do
	if [ -n "$take" ]; then
		case "$arg" in
			*remount*) remount=1 ;;
		esac
		take=
		continue
	fi
	case "$arg" in
		-o|-t|--options|--types)
			take=1
			continue
			;;
		-*)
			continue
			;;
	esac
	if [ "$n" -ge 1 ]; then
		src=$dest
	fi
	dest=$arg
	n=$((n + 1))
done
if [ "$remount" -eq 1 ] || [ "$n" -lt 2 ]; then
	exit 0
fi
[ -n "$dest" ] || exit 1
src=${src:-/dev/fake}
enc=$(printf '%s' "$dest" | awk '
	BEGIN { ORS = "" }
	{
		for (i = 1; i <= length($0); i++) {
			c = substr($0, i, 1)
			if (c == " ") printf "\\040"
			else if (c == "\t") printf "\\011"
			else if (c == "\\") printf "\\134"
			else if (c == "\n") printf "\\012"
			else printf "%s", c
		}
	}
')
srcenc=$(printf '%s' "$src" | awk '
	BEGIN { ORS = "" }
	{
		for (i = 1; i <= length($0); i++) {
			c = substr($0, i, 1)
			if (c == " ") printf "\\040"
			else if (c == "\t") printf "\\011"
			else if (c == "\\") printf "\\134"
			else if (c == "\n") printf "\\012"
			else printf "%s", c
		}
	}
')
seq=${ZLYME_FAKE_MOUNT_SEQ:?}
if [ ! -s "$seq" ]; then
	printf '%s\n' 1 > "$seq"
fi
id=$(cat "$seq")
printf '%s\n' "$((id + 1))" > "$seq"
# shellcheck disable=SC1090
. "${ZLYME_PORTMASTER_MOUNTS:?}"
parent=$(pm_new_parent "$dest") || exit 1
case "$parent" in
	''|*[!0-9]*) exit 1 ;;
esac
printf '%s %s fake rw 0 0\n' "$srcenc" "$enc" >> "$ZLYME_PM_MOUNTS"
printf '%s %s 0:1 / %s rw - fake %s rw\n' "$id" "$parent" "$enc" "$srcenc" >> "$ZLYME_PM_MOUNTINFO"
EOF

cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
set -eu
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
# shellcheck disable=SC1090
. "${ZLYME_PORTMASTER_MOUNTS:?}"
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
[ -n "$target" ] || exit 1
# umount(path) detaches the visible mount, not the last line.
# A mounts line with no mountinfo record is the only layer at that
# path in this harness. Two layers and no proved id stay mounted.
vid=$(pm_visible_id "$target" 2>/dev/null || true)
if [ -z "$vid" ]; then
	if [ "$(mounts_count "$ZLYME_PM_MOUNTS" "$target")" -ne 1 ]; then
		exit 1
	fi
	drop_mounts=$(mktemp)
	removed=0
	while IFS= read -r line || [ -n "$line" ]; do
		if [ "$removed" -eq 0 ]; then
			f2=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $2; exit }')
			if [ -n "$f2" ] && [ "$(mounts_decode "$f2")" = "$target" ]; then
				removed=1
				continue
			fi
		fi
		printf '%s\n' "$line"
	done < "$ZLYME_PM_MOUNTS" > "$drop_mounts"
	if [ "$removed" -ne 1 ]; then
		rm -f "$drop_mounts"
		exit 1
	fi
	mv -f "$drop_mounts" "$ZLYME_PM_MOUNTS"
	exit 0
fi
src=$(awk -v id="$vid" '
	$1 == id {
		for (i = 1; i <= NF; i++) {
			if ($i == "-") {
				print $(i + 2)
				exit
			}
		}
	}
' "$ZLYME_PM_MOUNTINFO")
[ -n "$src" ] || exit 1
drop_mountinfo=$(mktemp)
awk -v id="$vid" '$1 != id { print }' "$ZLYME_PM_MOUNTINFO" > "$drop_mountinfo"
drop_mounts=$(mktemp)
removed=0
while IFS= read -r line || [ -n "$line" ]; do
	if [ "$removed" -eq 0 ]; then
		f1=$(printf '%s\n' "$line" | awk 'NF >= 1 { print $1; exit }')
		f2=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $2; exit }')
		if [ -n "$f1" ] && [ -n "$f2" ] \
			&& [ "$(mounts_decode "$f1")" = "$(mounts_decode "$src")" ] \
			&& [ "$(mounts_decode "$f2")" = "$target" ]; then
			removed=1
			continue
		fi
	fi
	printf '%s\n' "$line"
done < "$ZLYME_PM_MOUNTS" > "$drop_mounts"
if [ "$removed" -ne 1 ]; then
	rm -f "$drop_mountinfo" "$drop_mounts"
	exit 1
fi
mv -f "$drop_mountinfo" "$ZLYME_PM_MOUNTINFO"
mv -f "$drop_mounts" "$ZLYME_PM_MOUNTS"
EOF
chmod 0755 "$work/bin/python3" "$work/bin/mount" "$work/bin/umount" \
	"$ZLYME_INPUT_BIN" "$work/bin/systemctl"

reset() {
	: > "$ZLYME_PM_MOUNTS"
	: > "$ZLYME_PM_MOUNTINFO"
	printf '%s\n' 1 > "$ZLYME_FAKE_MOUNT_SEQ"
	rm -f "$ZLYME_PM_REGISTRY"
	: > "$ZLYME_FAKE_UMOUNT_LOG"
	ZLYME_FAKE_MOUNT_FAIL=0
	ZLYME_FAKE_UMOUNT_FAIL=0
}

reg_exact() {
	[ -f "$ZLYME_PM_REGISTRY" ] || return 1
	_tab=$(printf '\t')
	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue
		case "$line" in
			*"$_tab"*)
				[ "${line#*"$_tab"}" = "$1" ] && return 0
				;;
			*)
				[ "$line" = "$1" ] && return 0
				;;
		esac
	done < "$ZLYME_PM_REGISTRY"
	return 1
}

reg_id() {
	[ -f "$ZLYME_PM_REGISTRY" ] || return 1
	_tab=$(printf '\t')
	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue
		case "$line" in
			*"$_tab"*)
				if [ "${line#*"$_tab"}" = "$1" ]; then
					printf '%s\n' "${line%%"$_tab"*}"
					return 0
				fi
				;;
		esac
	done < "$ZLYME_PM_REGISTRY"
	return 1
}

fail() {
	echo "portmaster mounts: $*" >&2
	exit 1
}

"$EXEC" systemctl restart oga_events \
	|| fail "PortMaster input restore translation failed"
grep -Fxq ensure "$ZLYME_INPUT_LOG" \
	|| fail "PortMaster input restore did not use zlyme-input ensure"
status=0
"$EXEC" systemctl stop oga_events >/dev/null 2>&1 || status=$?
if [ "$status" -ne 19 ]; then
	fail "unrecognized systemctl request was translated"
fi
grep -Fxq 'stop oga_events' "$ZLYME_SYSTEMCTL_LOG" \
	|| fail "unrecognized systemctl request was not passed through"

# The session sources pak-launch.sh. Cleanup runs after the spawn
# helper returns, which is after the pak session is empty.
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
awk '
	/^portmaster_cleanup\(\)/ { next }
	/portmaster_cleanup/ {
		if (!spawn) pre = 1
		if (seen) post = 1
	}
	/spawn_pak "/ { if (!spawn) spawn = 1 }
	/wait "\$_pak_waiter"/ { seen = 1 }
	END { exit (pre && post && spawn) ? 0 : 1 }
' "$LAUNCH" || fail "session does not clean up before and after the pak"
grep -q 'launch_with_reload' "$SESSION" || fail "session does not run the pak helper"

reset
"$EXEC" mount --bind /src /var/port/runtime || fail "mount failed"
reg_exact /var/port/runtime || fail "successful mount was not registered"
"$EXEC" umount /var/port/runtime || fail "umount failed"
if reg_exact /var/port/runtime; then
	fail "successful umount left the registration"
fi

reset
"$EXEC" mount --bind /src /var/port/left || fail "mount left failed"
"$CLEAN" || fail "cleanup of a left mount failed"
reg_exact /var/port/left && fail "cleanup left the registration"
grep -Fxq /var/port/left "$ZLYME_FAKE_UMOUNT_LOG" || fail "cleanup did not unmount"
if grep -Fxq /var/port/left "$ZLYME_PM_MOUNTS"; then
	fail "mount table still has the target"
fi

# Source A is registered, then removed outside the wrapper. Source B
# is mounted at the same path. Cleanup must not unmount B.
reset
"$EXEC" mount --bind /src/a /var/port/repl || fail "replacement setup failed"
reg_exact /var/port/repl || fail "replacement mount was not registered"
owned=$(reg_id /var/port/repl) || fail "replacement registry has no mount id"
case "$owned" in
	''|*[!0-9]*) fail "replacement id is not numeric: ${owned:-empty}" ;;
esac
grep -q "^${owned} " "$ZLYME_PM_MOUNTINFO" \
	|| fail "registered id is not in mountinfo"
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
strip_target() {
	file=$1
	fieldn=$2
	want=$3
	[ -f "$file" ] || return 0
	tmp=$(mktemp)
	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue
		got=$(printf '%s\n' "$line" | awk -v n="$fieldn" 'NF >= n { print $n; exit }')
		if [ -n "$got" ] && [ "$(mounts_decode "$got")" = "$want" ]; then
			continue
		fi
		printf '%s\n' "$line"
	done < "$file" > "$tmp"
	mv -f "$tmp" "$file"
}
strip_target "$ZLYME_PM_MOUNTS" 2 /var/port/repl
strip_target "$ZLYME_PM_MOUNTINFO" 5 /var/port/repl
if grep -q "^${owned} " "$ZLYME_PM_MOUNTINFO"; then
	fail "bypass did not remove source A"
fi
printf '%s\n' 'B /var/port/repl fake rw 0 0' >> "$ZLYME_PM_MOUNTS"
printf '%s\n' '9000 1 0:9 / /var/port/repl rw - fake B rw' >> "$ZLYME_PM_MOUNTINFO"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "dropping a replaced mount failed"
grep -F -q 'B /var/port/repl ' "$ZLYME_PM_MOUNTS" \
	|| fail "replacement source B was unmounted"
if grep -Fxq /var/port/repl "$ZLYME_FAKE_UMOUNT_LOG"; then
	fail "cleanup unmounted the replacement path"
fi
if reg_exact /var/port/repl; then
	fail "replacement path stayed registered"
fi
grep -q '^9000 ' "$ZLYME_PM_MOUNTINFO" \
	|| fail "replacement mountinfo id was removed"

reset
"$EXEC" mount --bind /src "/var/port/game dir" || fail "parent mount failed"
"$EXEC" mount --bind /src "/var/port/game dir/save" || fail "child mount failed"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "nested cleanup failed"
parent_line=$(grep -n -Fx "/var/port/game dir" "$ZLYME_FAKE_UMOUNT_LOG" | head -n 1 | cut -d: -f1)
child_line=$(grep -n -Fx "/var/port/game dir/save" "$ZLYME_FAKE_UMOUNT_LOG" | head -n 1 | cut -d: -f1)
if [ -z "$parent_line" ] || [ -z "$child_line" ]; then
	fail "nested targets were not both unmounted"
fi
if [ "$child_line" -ge "$parent_line" ]; then
	fail "nested targets were not deepest-first"
fi
if reg_exact "/var/port/game dir" || reg_exact "/var/port/game dir/save"; then
	fail "nested registrations remained"
fi

reset
"$EXEC" mount --bind /src "/var/port/save dir" || fail "space mount failed"
reg_exact "/var/port/save dir" || fail "space path was not registered raw"
grep -q '\\040' "$ZLYME_PM_MOUNTS" || fail "mount table did not escape the space"
"$CLEAN" || fail "space cleanup failed"
grep -Fxq "/var/port/save dir" "$ZLYME_FAKE_UMOUNT_LOG" || fail "space path was not unmounted"
if reg_exact "/var/port/save dir"; then
	fail "space registration remained"
fi

reset
"$EXEC" mount --bind /src /var/port/once || fail "repeat setup failed"
"$CLEAN" || fail "first cleanup failed"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "second cleanup failed"
if [ -s "$ZLYME_FAKE_UMOUNT_LOG" ]; then
	fail "repeated cleanup unmounted again"
fi

reset
ZLYME_FAKE_MOUNT_FAIL=1
if "$EXEC" mount --bind /src /var/port/nope; then
	fail "failed mount returned success"
fi
if [ -f "$ZLYME_PM_REGISTRY" ] && [ -s "$ZLYME_PM_REGISTRY" ]; then
	fail "failed mount was registered"
fi
ZLYME_FAKE_MOUNT_FAIL=0

reset
"$EXEC" mount --bind /src /var/port/stuck || fail "stuck mount failed"
ZLYME_FAKE_UMOUNT_FAIL=1
if "$EXEC" umount /var/port/stuck; then
	fail "failed umount returned success"
fi
reg_exact /var/port/stuck || fail "failed umount dropped the registration"
grep -q /var/port/stuck "$ZLYME_PM_MOUNTS" || fail "failed umount edited the table"
if "$CLEAN"; then
	fail "cleanup reported success while umount failed"
fi
reg_exact /var/port/stuck || fail "failed cleanup dropped the registration"
ZLYME_FAKE_UMOUNT_FAIL=0
"$CLEAN" || fail "later cleanup did not recover"
if reg_exact /var/port/stuck; then
	fail "recovered mount stayed registered"
fi

reset
printf '%s\n' \
	'/dev/mmcblk0p3 /storage ext4 rw 0 0' \
	'/dev/sda1 /mnt/other ext4 rw 0 0' \
	'/dev/sdb1 /mnt/media/USB\040Games ext4 rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' /storage "/mnt/media/USB Games" > "$ZLYME_PM_REGISTRY"
"$EXEC" mount --bind /src /storage/.config/nextui/my355/godot || fail "godot mount failed"
"$CLEAN" || fail "protected cleanup failed"
grep -Fxq /storage/.config/nextui/my355/godot "$ZLYME_FAKE_UMOUNT_LOG" \
	|| fail "owned path under /storage was not unmounted"
if grep -Fxq /storage "$ZLYME_FAKE_UMOUNT_LOG"; then
	fail "cleanup unmounted /storage"
fi
if grep -Fxq "/mnt/media/USB Games" "$ZLYME_FAKE_UMOUNT_LOG"; then
	fail "cleanup unmounted a library root"
fi
if grep -Fxq /mnt/other "$ZLYME_FAKE_UMOUNT_LOG"; then
	fail "cleanup unmounted an unrelated mount"
fi
grep -q ' /storage ' "$ZLYME_PM_MOUNTS" || fail "/storage left the mount table"
grep -q ' /mnt/other ' "$ZLYME_PM_MOUNTS" || fail "unrelated mount left the table"
grep -q 'USB\\040Games' "$ZLYME_PM_MOUNTS" || fail "library root left the table"

reset
printf '%s\n' '/dev/fake /roms/ports fake rw 0 0' > "$ZLYME_PM_MOUNTS"
"$CLEAN" || fail "ports unbind failed"
grep -Fxq /roms/ports "$ZLYME_FAKE_UMOUNT_LOG" || fail "/roms/ports was not unbound"
if grep -q /roms/ports "$ZLYME_PM_MOUNTS"; then
	fail "/roms/ports stayed mounted"
fi

reset
printf '%s\n' \
	'tmpfs /tmp/weston/child tmpfs rw 0 0' \
	'tmpfs /tmp/weston tmpfs rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
"$CLEAN" || fail "weston cleanup failed"
child_line=$(grep -n -Fx /tmp/weston/child "$ZLYME_FAKE_UMOUNT_LOG" | head -n 1 | cut -d: -f1)
parent_line=$(grep -n -Fx /tmp/weston "$ZLYME_FAKE_UMOUNT_LOG" | head -n 1 | cut -d: -f1)
if [ -z "$child_line" ] || [ -z "$parent_line" ]; then
	fail "weston mounts were not unmounted"
fi
if [ "$child_line" -ge "$parent_line" ]; then
	fail "weston child was not unmounted first"
fi

reset
"$EXEC" mount /src /var/port/plain || fail "two-operand mount failed"
reg_exact /var/port/plain || fail "two-operand mount was not registered"
"$EXEC" mount --bind /src /var/port/bind || fail "bind mount failed"
reg_exact /var/port/bind || fail "--bind was not registered"
"$EXEC" mount -t squashfs /src /var/port/sq || fail "squashfs mount failed"
reg_exact /var/port/sq || fail "-t squashfs was not registered"
"$EXEC" mount -o loop /src /var/port/loop || fail "loop mount failed"
reg_exact /var/port/loop || fail "-o loop was not registered"

reset
printf '%s\n' '/dev/fake /var/port/live fake rw 0 0' > "$ZLYME_PM_MOUNTS"
"$EXEC" mount -o remount,rw /var/port/live || fail "remount failed"
if [ -f "$ZLYME_PM_REGISTRY" ] && [ -s "$ZLYME_PM_REGISTRY" ]; then
	fail "successful remount was registered"
fi
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/live)" -eq 1 ] \
	|| fail "remount changed the mount count"

reset
printf '%s\n' '/dev/fake /var/port/live fake rw 0 0' > "$ZLYME_PM_MOUNTS"
ZLYME_FAKE_MOUNT_FAIL=1
if "$EXEC" mount -o remount,rw /var/port/live; then
	fail "failed remount returned success"
fi
if [ -f "$ZLYME_PM_REGISTRY" ] && [ -s "$ZLYME_PM_REGISTRY" ]; then
	fail "failed remount was registered"
fi
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/live)" -eq 1 ] \
	|| fail "failed remount edited the table"
ZLYME_FAKE_MOUNT_FAIL=0

reset
printf '%s\n' '/dev/old /var/port/stack fake rw 0 0' > "$ZLYME_PM_MOUNTS"
"$EXEC" mount --bind /src /var/port/stack || fail "stacked mount failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/stack)" -eq 2 ] \
	|| fail "stacked mount did not add one layer"
reg_lines=0
if [ -f "$ZLYME_PM_REGISTRY" ]; then
	reg_lines=$(grep -c . "$ZLYME_PM_REGISTRY" || true)
fi
[ "$reg_lines" -eq 1 ] || fail "stacked mount registered $reg_lines layers"
reg_exact /var/port/stack || fail "stacked mount missed the owned layer"
"$CLEAN" || fail "stacked cleanup failed"
if [ -f "$ZLYME_PM_REGISTRY" ] && [ -s "$ZLYME_PM_REGISTRY" ]; then
	fail "stacked cleanup left a registration"
fi
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/stack)" -eq 1 ] \
	|| fail "cleanup removed more than the owned layer"
grep -F -q '/dev/old /var/port/stack ' "$ZLYME_PM_MOUNTS" \
	|| fail "stacked cleanup removed the unrelated layer"

if grep -q 'pm_adopt' \
	"$CLEAN" \
	"$ROOT/package/system/portmaster/zlyme-portmaster-mounts.sh"; then
	fail "cleanup still adopts unregistered mounts"
fi

base_storage() {
	printf '%s\n' \
		'/dev/mmcblk0p3 /storage exfat rw 0 0' \
		'/dev/mmcblk1p1 /mnt/sd2 ext4 rw 0 0' \
		'kept /storage/.config/kept ext4 rw 0 0' \
		> "$ZLYME_PM_MOUNTS"
}

not_unmounted() {
	if grep -Fxq -- "$1" "$ZLYME_FAKE_UMOUNT_LOG"; then
		fail "$1 was unmounted"
	fi
}

# The covering mount is the first mountinfo line. The recorded mount
# is last. Parent ids say the first line is the visible mount.
reset
printf '%s\n' \
	'low /var/port/rev fake rw 0 0' \
	'high /var/port/rev fake rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'7 40 0:7 / /var/port/rev rw - fake high rw' \
	'40 1 0:40 / /var/port/rev rw - fake low rw' \
	> "$ZLYME_PM_MOUNTINFO"
printf '40\t/var/port/rev\n' > "$ZLYME_PM_REGISTRY"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN" 2>"$work/rev.err"; then
	fail "reversed order reported the covered mount free"
fi
grep -q 'is covered; leaving it' "$work/rev.err" \
	|| fail "reversed order did not report the covered mount"
grep -F -q 'low /var/port/rev ' "$ZLYME_PM_MOUNTS" \
	|| fail "reversed order removed the recorded lower mount"
grep -F -q 'high /var/port/rev ' "$ZLYME_PM_MOUNTS" \
	|| fail "reversed order removed the covering mount"
not_unmounted /var/port/rev
reg_exact /var/port/rev || fail "reversed order dropped the covered id"

# One recorded mount is the visible mount and is released.
reset
"$EXEC" mount --bind /src /var/port/one || fail "single mount failed"
"$CLEAN" || fail "single mount cleanup failed"
if grep -F -q ' /var/port/one ' "$ZLYME_PM_MOUNTS"; then
	fail "single mount stayed"
fi
if reg_exact /var/port/one; then
	fail "single mount stayed registered"
fi

# Two recorded mounts, stacked. The visible mount has the smaller id
# and is the first mountinfo line. Both are released.
reset
printf '%s\n' \
	'low /var/port/both fake rw 0 0' \
	'high /var/port/both fake rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'4 50 0:4 / /var/port/both rw - fake high rw' \
	'50 1 0:50 / /var/port/both rw - fake low rw' \
	> "$ZLYME_PM_MOUNTINFO"
printf '4\t/var/port/both\n50\t/var/port/both\n' > "$ZLYME_PM_REGISTRY"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "stacked mounts were not both released"
if grep -F -q ' /var/port/both ' "$ZLYME_PM_MOUNTS"; then
	fail "a stacked mount stayed"
fi
if reg_exact /var/port/both; then
	fail "a stacked mount stayed registered"
fi
high_line=$(grep -n -Fx /var/port/both "$ZLYME_FAKE_UMOUNT_LOG" | head -n 1 | cut -d: -f1)
low_count=$(grep -c -Fx /var/port/both "$ZLYME_FAKE_UMOUNT_LOG" || true)
[ "$low_count" -eq 2 ] || fail "stacked cleanup unmounted $low_count times"
[ -n "$high_line" ] || fail "stacked cleanup did not unmount"

# A recorded mount under a covered prefix is not the visible mount,
# even when it is the only line at its own path.
reset
printf '%s\n' \
	'base /var/port/hide fake rw 0 0' \
	'top /var/port/hide fake rw 0 0' \
	'game /var/port/hide/game fake rw 0 0' \
	'save /var/port/hide/game/save fake rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'20 10 0:20 / /var/port/hide rw - fake top rw' \
	'10 1 0:10 / /var/port/hide rw - fake base rw' \
	'30 10 0:30 / /var/port/hide/game rw - fake game rw' \
	'40 30 0:40 / /var/port/hide/game/save rw - fake save rw' \
	> "$ZLYME_PM_MOUNTINFO"
printf '40\t/var/port/hide/game/save\n' > "$ZLYME_PM_REGISTRY"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN" 2>"$work/hide.err"; then
	fail "hidden mount cleanup reported success"
fi
grep -q 'is hidden; leaving it' "$work/hide.err" \
	|| fail "hidden mount was not reported"
grep -F -q 'save /var/port/hide/game/save ' "$ZLYME_PM_MOUNTS" \
	|| fail "hidden mount was removed"
grep -F -q 'top /var/port/hide ' "$ZLYME_PM_MOUNTS" \
	|| fail "hidden cleanup removed the covering mount"
not_unmounted /var/port/hide/game/save
reg_exact /var/port/hide/game/save || fail "hidden id left the registry"

# The same prefix stack does not hide a mount attached to its top.
reset
printf '%s\n' \
	'base /var/port/shown fake rw 0 0' \
	'top /var/port/shown fake rw 0 0' \
	'ok /var/port/shown/ok fake rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'20 10 0:20 / /var/port/shown rw - fake top rw' \
	'10 1 0:10 / /var/port/shown rw - fake base rw' \
	'50 20 0:50 / /var/port/shown/ok rw - fake ok rw' \
	> "$ZLYME_PM_MOUNTINFO"
printf '50\t/var/port/shown/ok\n' > "$ZLYME_PM_REGISTRY"
"$CLEAN" || fail "visible nested mount stayed"
if grep -F -q 'ok /var/port/shown/ok ' "$ZLYME_PM_MOUNTS"; then
	fail "visible nested mount was not released"
fi
grep -F -q 'top /var/port/shown ' "$ZLYME_PM_MOUNTS" \
	|| fail "visible nested cleanup removed the prefix"
grep -F -q 'base /var/port/shown ' "$ZLYME_PM_MOUNTS" \
	|| fail "visible nested cleanup removed the covered prefix"

# Two well-formed mounts that do not form one stack are ambiguous.
reset
printf '%s\n' \
	'a /var/port/bad fake rw 0 0' \
	'b /var/port/bad fake rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'11 1 0:11 / /var/port/bad rw - fake a rw' \
	'12 1 0:12 / /var/port/bad rw - fake b rw' \
	> "$ZLYME_PM_MOUNTINFO"
printf '11\t/var/port/bad\n' > "$ZLYME_PM_REGISTRY"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN" 2>"$work/bad.err"; then
	fail "ambiguous topology reported success"
fi
grep -q 'ambiguous topology' "$work/bad.err" \
	|| fail "ambiguous topology was not reported"
grep -F -q 'a /var/port/bad ' "$ZLYME_PM_MOUNTS" \
	|| fail "ambiguous topology removed a mount"
grep -F -q 'b /var/port/bad ' "$ZLYME_PM_MOUNTS" \
	|| fail "ambiguous topology removed the other mount"
not_unmounted /var/port/bad
reg_exact /var/port/bad || fail "ambiguous topology dropped the id"

# A line that is not mountinfo makes the table unusable.
reset
printf '%s\n' 'z /var/port/junk fake rw 0 0' > "$ZLYME_PM_MOUNTS"
printf '%s\n' \
	'5 1 0:5 / /var/port/junk rw - fake z rw' \
	'not-a-mount' \
	> "$ZLYME_PM_MOUNTINFO"
printf '5\t/var/port/junk\n' > "$ZLYME_PM_REGISTRY"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN" 2>"$work/junk.err"; then
	fail "malformed mountinfo reported success"
fi
grep -q 'ambiguous topology' "$work/junk.err" \
	|| fail "malformed mountinfo was not reported"
grep -F -q 'z /var/port/junk ' "$ZLYME_PM_MOUNTS" \
	|| fail "malformed mountinfo unmounted the path"
not_unmounted /var/port/junk
reg_exact /var/port/junk || fail "malformed mountinfo dropped the id"

if grep -E -q 'pm_snapshot|pm_consume_snapshot|pm_storage_nested|portmaster_mark|storage-before' \
	"$CLEAN" \
	"$EXEC" \
	"$ROOT/package/system/portmaster/zlyme-portmaster-mounts.sh" \
	"$LAUNCH"; then
	fail "snapshot ownership code is still present"
fi

# Port A records one wrapper mount and exits. MENU+START uses this
# same cleanup: the port does not umount its own mount.
reset
base_storage
"$CLEAN" || fail "port A pre-cleanup failed"
"$EXEC" mount --bind /src /storage/.config/porta || fail "port A mount failed"
"$CLEAN" || fail "port A post-cleanup failed"
if grep -F -q ' /storage/.config/porta ' "$ZLYME_PM_MOUNTS"; then
	fail "port A mount stayed"
fi
grep -F -q ' /storage/.config/kept ' "$ZLYME_PM_MOUNTS" \
	|| fail "pre-existing mount was removed during port A"
grep -F -q ' /mnt/sd2 ' "$ZLYME_PM_MOUNTS" || fail "SD2 was removed during port A"
not_unmounted /storage
not_unmounted /mnt/sd2
not_unmounted /storage/.config/kept

# An unrelated service mounts between launches. Port B's pre-cleanup
# must leave it.
printf '%s\n' 'other /storage/.config/other ext4 rw 0 0' >> "$ZLYME_PM_MOUNTS"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "port B pre-cleanup failed"
grep -F -q ' /storage/.config/other ' "$ZLYME_PM_MOUNTS" \
	|| fail "unrelated mount between launches was removed"
not_unmounted /storage/.config/other

# USB File Transfer sees that remaining nested mount and refuses.
# Mount and umount commands here exit without touching a real table.
USB=$ROOT/package/system/zlyme-usb-transfer/zlyme-usb-transfer
mkdir -p "$work/usb-run" "$work/udc/fake0" "$work/configfs"
cat > "$work/bin/usb-block" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_USB_BLOCK_LOG:?}"
exit 1
EOF
chmod 0755 "$work/bin/usb-block"
: > "$work/usb-block.log"
export ZLYME_USB_BLOCK_LOG="$work/usb-block.log"
if ZLYME_USB_RUN="$work/usb-run" \
	ZLYME_USB_MOUNTS="$ZLYME_PM_MOUNTS" \
	ZLYME_USB_STORAGE=/storage \
	ZLYME_USB_SD2=/mnt/sd2 \
	ZLYME_USB_MEDIA=/mnt/media \
	ZLYME_USB_JAIL=0 \
	ZLYME_USB_LINK=0 \
	ZLYME_USB_UDC_NAME=fake0 \
	ZLYME_USB_UDC_CLASS="$work/udc" \
	ZLYME_USB_CONFIGFS="$work/configfs" \
	ZLYME_USB_FFS="$work/ffs" \
	ZLYME_USB_MOUNT="$work/bin/usb-block" \
	ZLYME_USB_UMOUNT="$work/bin/usb-block" \
	"$USB" start >"$work/usb.out" 2>"$work/usb.err"; then
	fail "MTP started while an unrelated nested mount remained"
fi
grep -q 'primary storage contains a nested mount' "$work/usb.err" \
	|| fail "MTP did not refuse the unrelated mount: $(cat "$work/usb.err")"
grep -q 'nested mount /storage/.config/other' "$work/usb.err" \
	|| fail "MTP did not name the unrelated mount: $(cat "$work/usb.err")"
if [ -s "$work/usb-block.log" ]; then
	fail "MTP refusal called mount: $(cat "$work/usb-block.log")"
fi
grep -F -q ' /storage/.config/other ' "$ZLYME_PM_MOUNTS" \
	|| fail "MTP refusal removed the unrelated mount"
if [ -r "$work/usb-run/reaper.pid" ]; then
	kill "$(cat "$work/usb-run/reaper.pid")" 2>/dev/null || true
fi

# Port B then records its own mount. The unrelated one stays.
"$EXEC" mount --bind /src /storage/.config/portb || fail "port B mount failed"
"$CLEAN" || fail "port B post-cleanup failed"
if grep -F -q ' /storage/.config/portb ' "$ZLYME_PM_MOUNTS"; then
	fail "port B mount stayed"
fi
grep -F -q ' /storage/.config/other ' "$ZLYME_PM_MOUNTS" \
	|| fail "unrelated mount did not survive port B"
not_unmounted /storage/.config/other
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "idempotent cleanup failed"
not_unmounted /storage/.config/other
not_unmounted /storage/.config/kept
not_unmounted /mnt/sd2

# An unrelated mount created while the port is open stays. A direct
# mount is the same shape, so it stays too. The recorded mount goes.
reset
base_storage
"$CLEAN" || fail "game pre-cleanup failed"
printf '%s\n' \
	'live /storage/.config/nextui/my355/godot ext4 rw 0 0' \
	'live /storage/.config/game\040dir ext4 rw 0 0' \
	>> "$ZLYME_PM_MOUNTS"
"$EXEC" mount --bind /src /storage/.config/played || fail "played mount failed"
"$CLEAN" || fail "game post-cleanup failed"
if grep -F -q ' /storage/.config/played ' "$ZLYME_PM_MOUNTS"; then
	fail "recorded mount stayed after the game"
fi
grep -F -q 'my355/godot' "$ZLYME_PM_MOUNTS" \
	|| fail "unrelated mount created during play was removed"
grep -F -q 'game\040dir' "$ZLYME_PM_MOUNTS" \
	|| fail "escaped unrelated mount was removed"
not_unmounted /storage/.config/nextui/my355/godot

# One recorded layer on top of an unrelated layer at the same target.
reset
printf '%s\n' \
	'/dev/mmcblk0p3 /storage exfat rw 0 0' \
	'base /storage/.config/stack ext4 rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
"$EXEC" mount --bind /src /storage/.config/stack || fail "stack mount failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/stack)" -eq 2 ] \
	|| fail "stacked storage mount did not add one layer"
"$CLEAN" || fail "stack cleanup failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/stack)" -eq 1 ] \
	|| fail "stack cleanup removed the unrelated layer"
grep -F -q 'base /storage/.config/stack ' "$ZLYME_PM_MOUNTS" \
	|| fail "stack cleanup removed the base layer"

# The same target, used by port A, then by an unrelated service, then
# by port B as one more layer.
reset
base_storage
"$EXEC" mount --bind /src /storage/.config/reuse || fail "reuse mount failed"
"$CLEAN" || fail "reuse post-cleanup failed"
if grep -F -q ' /storage/.config/reuse ' "$ZLYME_PM_MOUNTS"; then
	fail "port A left the reused target mounted"
fi
printf '%s\n' 'again /storage/.config/reuse ext4 rw 0 0' >> "$ZLYME_PM_MOUNTS"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "reuse pre-cleanup failed"
grep -F -q ' /storage/.config/reuse ' "$ZLYME_PM_MOUNTS" \
	|| fail "reused target was removed before port B"
not_unmounted /storage/.config/reuse
"$EXEC" mount --bind /src /storage/.config/reuse || fail "reuse second mount failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/reuse)" -eq 2 ] \
	|| fail "port B did not stack on the reused target"
"$CLEAN" || fail "reuse second cleanup failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/reuse)" -eq 1 ] \
	|| fail "port B removed the unrelated layer at the reused target"
grep -F -q 'again /storage/.config/reuse ' "$ZLYME_PM_MOUNTS" \
	|| fail "port B removed the unrelated source"

# A busy recorded mount stays registered. The next cleanup retries it.
reset
base_storage
"$EXEC" mount --bind /src /storage/.config/busy || fail "busy mount failed"
ZLYME_FAKE_UMOUNT_FAIL=1
if "$CLEAN"; then
	fail "busy cleanup reported success"
fi
grep -F -q ' /storage/.config/busy ' "$ZLYME_PM_MOUNTS" \
	|| fail "busy mount was detached"
reg_exact /storage/.config/busy || fail "busy mount left the registry"
ZLYME_FAKE_UMOUNT_FAIL=0
"$CLEAN" || fail "busy retry failed"
if grep -F -q ' /storage/.config/busy ' "$ZLYME_PM_MOUNTS"; then
	fail "busy retry left the mount"
fi
if reg_exact /storage/.config/busy; then
	fail "busy retry left the registration"
fi

# A library root and the second card stay mounted, including when a
# stale registry line names them. The recorded port mount is released.
reset
printf '%s\n' /storage "/mnt/media/USB Games" /storage/Roms > "$ZLYME_LIBRARIES_FILE"
printf '%s\n' \
	'/dev/mmcblk0p3 /storage exfat rw 0 0' \
	'/dev/mmcblk1p1 /mnt/sd2 ext4 rw 0 0' \
	'roms /storage/Roms ext4 rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
printf '%s\n' /storage/Roms /mnt/sd2 > "$ZLYME_PM_REGISTRY"
"$EXEC" mount --bind /src /storage/.config/ownedlib || fail "library-case mount failed"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "library cleanup failed"
grep -F -q ' /storage/Roms ' "$ZLYME_PM_MOUNTS" || fail "library root was removed"
grep -F -q ' /mnt/sd2 ' "$ZLYME_PM_MOUNTS" || fail "SD2 was removed"
not_unmounted /storage/Roms
not_unmounted /mnt/sd2
if grep -F -q ' /storage/.config/ownedlib ' "$ZLYME_PM_MOUNTS"; then
	fail "recorded mount under a library case stayed"
fi
printf '%s\n' /storage "/mnt/media/USB Games" > "$ZLYME_LIBRARIES_FILE"

# Two wrapper layers at one path. Both ids are released, top first.
reset
"$EXEC" mount --bind /src/low /var/port/layers || fail "lower layer failed"
"$EXEC" mount --bind /src/high /var/port/layers || fail "upper layer failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/layers)" -eq 2 ] \
	|| fail "two owned layers were not stacked"
"$CLEAN" || fail "two owned layers were not released"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /var/port/layers)" -eq 0 ] \
	|| fail "an owned layer stayed"
if reg_exact /var/port/layers; then
	fail "owned layers stayed registered"
fi

# The wrapper umounts the top mount. If that top is not the recorded
# id, the recorded mount stays registered.
reset
"$EXEC" mount --bind /src/owned /var/port/cover2 || fail "covered owner failed"
owned_cover=$(reg_id /var/port/cover2) || fail "covered owner has no id"
printf '%s\n' 'B /var/port/cover2 fake rw 0 0' >> "$ZLYME_PM_MOUNTS"
printf '%s\n' '9100 1 0:91 / /var/port/cover2 rw - fake B rw' >> "$ZLYME_PM_MOUNTINFO"
"$EXEC" umount /var/port/cover2 || fail "umount of the covering mount failed"
grep -F -q '/src/owned /var/port/cover2 ' "$ZLYME_PM_MOUNTS" \
	|| fail "wrapper umount removed the recorded layer"
if grep -F -q 'B /var/port/cover2 ' "$ZLYME_PM_MOUNTS"; then
	fail "wrapper umount left the covering layer"
fi
[ "$(reg_id /var/port/cover2)" = "$owned_cover" ] \
	|| fail "wrapper umount dropped the still-mounted id"
"$CLEAN" || fail "cleanup did not release the uncovered owner"
if grep -F -q '/src/owned /var/port/cover2 ' "$ZLYME_PM_MOUNTS"; then
	fail "uncovered owner stayed mounted"
fi

# A later mount covering the recorded id is left alone, including on
# a second cleanup.
reset
"$EXEC" mount --bind /src/owned /var/port/cover || fail "cover owner failed"
printf '%s\n' 'cover /var/port/cover fake rw 0 0' >> "$ZLYME_PM_MOUNTS"
printf '%s\n' '8000 1 0:8 / /var/port/cover rw - fake cover rw' >> "$ZLYME_PM_MOUNTINFO"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN"; then
	fail "covered cleanup reported success"
fi
grep -F -q '/src/owned /var/port/cover ' "$ZLYME_PM_MOUNTS" \
	|| fail "covered cleanup removed the owned layer"
grep -F -q 'cover /var/port/cover ' "$ZLYME_PM_MOUNTS" \
	|| fail "covered cleanup removed the top layer"
reg_exact /var/port/cover || fail "covered id left the registry"
not_unmounted /var/port/cover
if "$CLEAN"; then
	fail "repeated covered cleanup reported success"
fi
grep -F -q 'cover /var/port/cover ' "$ZLYME_PM_MOUNTS" \
	|| fail "repeated cleanup removed the top layer"
reg_exact /var/port/cover || fail "repeated cleanup dropped the covered id"

# A registry line with no mount id is not unmounted.
reset
printf '%s\n' /var/port/amb > "$ZLYME_PM_REGISTRY"
printf '%s\n' 'x /var/port/amb fake rw 0 0' >> "$ZLYME_PM_MOUNTS"
printf '%s\n' '3 1 0:3 / /var/port/amb rw - fake x rw' >> "$ZLYME_PM_MOUNTINFO"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN" 2>"$work/amb.err"; then
	fail "ambiguous cleanup reported success"
fi
grep -q 'ambiguous registry entry' "$work/amb.err" \
	|| fail "ambiguous entry was not reported"
grep -F -q 'x /var/port/amb ' "$ZLYME_PM_MOUNTS" \
	|| fail "ambiguous cleanup unmounted the path"
reg_exact /var/port/amb || fail "ambiguous entry was dropped"
not_unmounted /var/port/amb
if "$CLEAN" 2>"$work/amb2.err"; then
	fail "repeated ambiguous cleanup reported success"
fi
grep -F -q 'x /var/port/amb ' "$ZLYME_PM_MOUNTS" \
	|| fail "repeated ambiguous cleanup unmounted the path"

# The recorded id is already gone. The path now has no mount. Cleanup
# drops the line and does not call umount.
reset
"$EXEC" mount --bind /src/a /var/port/gone || fail "gone setup failed"
strip_target "$ZLYME_PM_MOUNTS" 2 /var/port/gone
strip_target "$ZLYME_PM_MOUNTINFO" 5 /var/port/gone
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "dropping a missing id failed"
not_unmounted /var/port/gone
if reg_exact /var/port/gone; then
	fail "missing id stayed registered"
fi
"$CLEAN" || fail "repeated cleanup of a missing id failed"

# Mountinfo cannot be read. The recorded mount stays mounted.
reset
"$EXEC" mount --bind /src/a /var/port/blind || fail "blind setup failed"
rm -f "$ZLYME_PM_MOUNTINFO"
: > "$ZLYME_FAKE_UMOUNT_LOG"
if "$CLEAN"; then
	fail "unreadable mountinfo reported success"
fi
grep -F -q '/src/a /var/port/blind ' "$ZLYME_PM_MOUNTS" \
	|| fail "unreadable mountinfo unmounted the path"
reg_exact /var/port/blind || fail "unreadable mountinfo dropped the entry"
not_unmounted /var/port/blind
if "$CLEAN"; then
	fail "repeated unreadable cleanup reported success"
fi
grep -F -q '/src/a /var/port/blind ' "$ZLYME_PM_MOUNTS" \
	|| fail "repeated unreadable cleanup unmounted the path"


if [ -s "$ZLYME_PYTHON_LOG" ]; then
	fail "mount helper invoked python3"
fi

echo "portmaster mounts ok"
