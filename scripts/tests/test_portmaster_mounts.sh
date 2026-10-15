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
export ZLYME_PM_REGISTRY="$work/owned"
export ZLYME_PM_SNAPSHOT="$work/before"
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
	rm -f "$ZLYME_PM_REGISTRY" "$ZLYME_PM_SNAPSHOT"
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

# The session sources pak-launch.sh, which cleans up after the pak wait returns.
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
awk '
	/portmaster_mark/ { if (!mark) mark = NR }
	/spawn_pak "/ { if (!spawn) spawn = NR }
	/wait "\$_pak_pid"/ { seen = 1 }
	seen && /portmaster_cleanup/ { found = 1 }
	END { exit (found && mark && spawn && mark < spawn) ? 0 : 1 }
' "$LAUNCH" || fail "session does not snapshot before the pak and clean up after it"
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

snapshot_gone() {
	if [ -e "$ZLYME_PM_SNAPSHOT" ]; then
		fail "$1"
	fi
}

not_unmounted() {
	if grep -Fxq -- "$1" "$ZLYME_FAKE_UMOUNT_LOG"; then
		fail "$1 was unmounted"
	fi
}

# Port A records one wrapper mount and exits. MENU+START uses this
# same cleanup: the port does not umount its own mount.
reset
base_storage
"$CLEAN" || fail "port A pre-cleanup failed"
"$CLEAN" snapshot || fail "port A snapshot failed"
grep -Fxq /storage/.config/kept "$ZLYME_PM_SNAPSHOT" \
	|| fail "snapshot missed the pre-existing mount"
"$EXEC" mount --bind /src /storage/.config/porta || fail "port A mount failed"
"$CLEAN" || fail "port A post-cleanup failed"
snapshot_gone "port A snapshot survived cleanup"
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
# must leave it. The consumed snapshot cannot select it.
printf '%s\n' 'other /storage/.config/other ext4 rw 0 0' >> "$ZLYME_PM_MOUNTS"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "port B pre-cleanup failed"
snapshot_gone "port B pre-cleanup left a snapshot"
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
"$CLEAN" snapshot || fail "port B snapshot failed"
"$EXEC" mount --bind /src /storage/.config/portb || fail "port B mount failed"
"$CLEAN" || fail "port B post-cleanup failed"
snapshot_gone "port B snapshot survived cleanup"
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
snapshot_gone "idempotent cleanup recreated a snapshot"

# A failed snapshot removes any older file and does not select mounts.
reset
base_storage
"$CLEAN" snapshot || fail "baseline snapshot failed"
printf '%s\n' '/storage/.config/old-baseline' > "$ZLYME_PM_SNAPSHOT"
rm -f "$ZLYME_PM_MOUNTS"
if "$CLEAN" snapshot; then
	fail "snapshot succeeded without a mount table"
fi
snapshot_gone "failed snapshot left the previous file"
printf '%s\n' \
	'/dev/mmcblk0p3 /storage exfat rw 0 0' \
	'later /storage/.config/later ext4 rw 0 0' \
	> "$ZLYME_PM_MOUNTS"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "cleanup after a failed snapshot failed"
grep -F -q ' /storage/.config/later ' "$ZLYME_PM_MOUNTS" \
	|| fail "failed snapshot still selected a mount"
not_unmounted /storage/.config/later

# Cleanup interrupted before it could delete the snapshot. The next
# pre-cleanup deletes that file and leaves the mount that appeared later.
reset
base_storage
"$CLEAN" snapshot || fail "interrupted snapshot failed"
printf '%s\n' 'gap /storage/.config/gap ext4 rw 0 0' >> "$ZLYME_PM_MOUNTS"
[ -f "$ZLYME_PM_SNAPSHOT" ] || fail "interrupted launch lost its snapshot early"
: > "$ZLYME_FAKE_UMOUNT_LOG"
"$CLEAN" || fail "cleanup of an interrupted snapshot failed"
snapshot_gone "interrupted snapshot remained"
grep -F -q ' /storage/.config/gap ' "$ZLYME_PM_MOUNTS" \
	|| fail "interrupted snapshot selected a later mount"
not_unmounted /storage/.config/gap

# An unrelated mount created while the port is open stays. A direct
# mount is the same shape, so it stays too. The recorded mount goes.
reset
base_storage
"$CLEAN" || fail "game pre-cleanup failed"
"$CLEAN" snapshot || fail "game snapshot failed"
printf '%s\n' \
	'live /storage/.config/nextui/my355/godot ext4 rw 0 0' \
	'live /storage/.config/game\040dir ext4 rw 0 0' \
	>> "$ZLYME_PM_MOUNTS"
"$EXEC" mount --bind /src /storage/.config/played || fail "played mount failed"
"$CLEAN" || fail "game post-cleanup failed"
snapshot_gone "game snapshot survived"
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
"$CLEAN" snapshot || fail "stack snapshot failed"
"$EXEC" mount --bind /src /storage/.config/stack || fail "stack mount failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/stack)" -eq 2 ] \
	|| fail "stacked storage mount did not add one layer"
"$CLEAN" || fail "stack cleanup failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/stack)" -eq 1 ] \
	|| fail "stack cleanup removed the unrelated layer"
snapshot_gone "stack snapshot survived"

# The same target, used by port A, then by an unrelated service, then
# by port B as one more layer.
reset
base_storage
"$CLEAN" snapshot || fail "reuse snapshot failed"
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
"$CLEAN" snapshot || fail "reuse second snapshot failed"
"$EXEC" mount --bind /src /storage/.config/reuse || fail "reuse second mount failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/reuse)" -eq 2 ] \
	|| fail "port B did not stack on the reused target"
"$CLEAN" || fail "reuse second cleanup failed"
[ "$(mounts_count "$ZLYME_PM_MOUNTS" /storage/.config/reuse)" -eq 1 ] \
	|| fail "port B removed the unrelated layer at the reused target"
snapshot_gone "reuse snapshot survived"

# A busy recorded mount stays registered. The next cleanup retries it.
# The snapshot is already gone, so the retry does not depend on it.
reset
base_storage
"$CLEAN" snapshot || fail "busy snapshot failed"
"$EXEC" mount --bind /src /storage/.config/busy || fail "busy mount failed"
ZLYME_FAKE_UMOUNT_FAIL=1
if "$CLEAN"; then
	fail "busy cleanup reported success"
fi
grep -F -q ' /storage/.config/busy ' "$ZLYME_PM_MOUNTS" \
	|| fail "busy mount was detached"
reg_exact /storage/.config/busy || fail "busy mount left the registry"
snapshot_gone "busy cleanup left a snapshot"
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
"$CLEAN" snapshot || fail "library snapshot failed"
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
snapshot_gone "library snapshot survived"
printf '%s\n' /storage "/mnt/media/USB Games" > "$ZLYME_LIBRARIES_FILE"

if [ -s "$ZLYME_PYTHON_LOG" ]; then
	fail "mount helper invoked python3"
fi

echo "portmaster mounts ok"
