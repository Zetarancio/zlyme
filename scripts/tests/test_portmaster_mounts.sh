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
trap 'rm -rf "$work"' EXIT

export ZLYME_PM_MOUNTS="$work/mounts"
export ZLYME_PM_REGISTRY="$work/owned"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_MOUNTS_LIB="$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh"
export ZLYME_LIBRARY_SH="$LIB"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"
export ZLYME_FAKE_MOUNT_FAIL=0
export ZLYME_FAKE_UMOUNT_FAIL=0
export ZLYME_PYTHON_LOG="$work/python.log"
export PATH="$work/bin:$PATH"
: > "$ZLYME_PYTHON_LOG"

mkdir -p "$work/bin"
printf '%s\n' /storage "/mnt/media/USB Games" > "$work/libraries"

cat > "$work/bin/python3" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_PYTHON_LOG:?}"
exit 127
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
	dest=$arg
	n=$((n + 1))
done
if [ "$remount" -eq 1 ] || [ "$n" -lt 2 ]; then
	exit 0
fi
[ -n "$dest" ] || exit 1
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
printf '/dev/fake %s fake rw 0 0\n' "$enc" >> "$ZLYME_PM_MOUNTS"
EOF

cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
set -eu
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
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
tmp=$(mktemp)
removed=0
while IFS= read -r line || [ -n "$line" ]; do
	[ -n "$line" ] || continue
	field=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $2; exit }')
	if [ "$removed" -eq 0 ] && [ -n "$field" ] \
		&& [ "$(mounts_decode "$field")" = "$target" ]; then
		removed=1
		continue
	fi
	printf '%s\n' "$line"
done < "$ZLYME_PM_MOUNTS" > "$tmp"
mv -f "$tmp" "$ZLYME_PM_MOUNTS"
[ "$removed" -eq 1 ]
EOF
chmod 0755 "$work/bin/python3" "$work/bin/mount" "$work/bin/umount"

reset() {
	: > "$ZLYME_PM_MOUNTS"
	rm -f "$ZLYME_PM_REGISTRY"
	: > "$ZLYME_FAKE_UMOUNT_LOG"
	ZLYME_FAKE_MOUNT_FAIL=0
	ZLYME_FAKE_UMOUNT_FAIL=0
}

reg_exact() {
	if [ ! -f "$ZLYME_PM_REGISTRY" ]; then
		return 1
	fi
	grep -Fxq -- "$1" "$ZLYME_PM_REGISTRY"
}

fail() {
	echo "portmaster mounts: $*" >&2
	exit 1
}

# nextui-session still owns cleanup after the pak wait returns.
awk '
	/wait "\$_pak_pid"/ { seen = 1 }
	seen && /portmaster_cleanup/ { found = 1 }
	END { exit found ? 0 : 1 }
' "$SESSION" || fail "session does not clean up after the pak exits"

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

if [ -s "$ZLYME_PYTHON_LOG" ]; then
	fail "mount helper invoked python3"
fi

echo "portmaster mounts ok"
