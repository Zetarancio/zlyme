#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage-format"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_FMT_MOUNTS="$work/mounts"
export ZLYME_FMT_BLKID="$work/blkid"
export ZLYME_FMT_BLOCKS="$work/blocks"
export ZLYME_FMT_LOG="$work/log"
cat > "$work/mounts" <<'EOF'
/dev/mmcblk0p2 / ext4 rw 0 0
/dev/mmcblk0p1 /boot vfat ro 0 0
/dev/mmcblk0p3 /storage exfat rw 0 0
/dev/mmcblk1p1 /mnt/sd2 exfat rw 0 0
EOF
cat > "$work/blkid" <<'EOF'
/dev/mmcblk0p1 parent=mmcblk0 LABEL=ZLYMEBOOT TYPE=vfat
/dev/mmcblk0p2 parent=mmcblk0 LABEL= TYPE=ext4
/dev/mmcblk0p3 parent=mmcblk0 LABEL=ZLYME TYPE=exfat
/dev/mmcblk0 parent=mmcblk0 LABEL= TYPE=
/dev/mmcblk1p1 parent=mmcblk1 LABEL=GAMES TYPE=exfat
/dev/mmcblk1 parent=mmcblk1 LABEL= TYPE=
/dev/sda1 parent=sda LABEL=USB TYPE=exfat
/dev/sda parent=sda LABEL= TYPE=
/dev/sdb1 parent=sdb LABEL=ZLYME TYPE=ext4
EOF
cat > "$work/blocks" <<'EOF'
/dev/mmcblk0
/dev/mmcblk0p1
/dev/mmcblk0p2
/dev/mmcblk0p3
/dev/mmcblk1
/dev/mmcblk1p1
/dev/sda
/dev/sda1
/dev/sdb1
/dev/sdz9
EOF
list=$("$BIN" list)
printf '%s\n' "$list" | grep -q '/dev/mmcblk1p1'
printf '%s\n' "$list" | grep -q '/dev/sda1'
if printf '%s\n' "$list" | grep -q '/dev/mmcblk0'; then
	echo "OS disk was listed" >&2
	exit 1
fi
if printf '%s\n' "$list" | grep -q '/dev/sdb1'; then
	echo "ZLYME label was listed" >&2
	exit 1
fi
for bad in /dev/mmcblk0 /dev/mmcblk0p1 /dev/mmcblk0p2 /dev/mmcblk0p3 /dev/mmcblk1 /dev/sda /dev/sdb1 /dev/sdz9 /tmp/not-a-disk; do
	if "$BIN" format "$bad" exfat ZLYME-LIB; then
		echo "accepted $bad" >&2
		exit 1
	fi
done
: > "$work/log"
"$BIN" format /dev/mmcblk1p1 exfat ZLYME-LIB
grep -q '^UMOUNT /mnt/sd2$' "$work/log"
grep -q '^MKFS exfat ZLYME-LIB /dev/mmcblk1p1$' "$work/log"
grep -q '^RESCAN /dev/mmcblk1p1$' "$work/log"
: > "$work/log"
export ZLYME_FMT_UMOUNT_FAIL=1
if "$BIN" format /dev/mmcblk1p1 exfat; then
	echo "busy unmount formatted" >&2
	exit 1
fi
if grep -q '^MKFS ' "$work/log"; then
	echo "mkfs ran after a failed unmount" >&2
	exit 1
fi
unset ZLYME_FMT_UMOUNT_FAIL
# Unmounted USB: no umount line, mkfs still runs.
grep -v mmcblk1p1 "$work/mounts" > "$work/mounts2"
export ZLYME_FMT_MOUNTS="$work/mounts2"
: > "$work/log"
export ZLYME_FMT_MKFS_FAIL=1
if "$BIN" format /dev/sda1 ext4; then
	echo "mkfs failure reported success" >&2
	exit 1
fi
if grep -q '^RESCAN ' "$work/log"; then
	echo "rescan after mkfs failure" >&2
	exit 1
fi
echo "storage format ok"
