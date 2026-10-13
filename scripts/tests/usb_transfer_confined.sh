#!/bin/sh
# Real mount-namespace confinement for the USB transfer helper.
# The caller must already be root in a user and mount namespace.
# Nothing here opens the host's USB controllers.
set -eu

fail() {
	printf 'usb confine: %s\n' "$*" >&2
	exit 1
}

# shellcheck disable=SC1091,SC1007
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/usb_group_reaper.sh"

WORK=${CONFINE_WORK:?}
HELPER=${CONFINE_HELPER:?}
PAK=${CONFINE_PAK:?}
ENTER=${CONFINE_ENTER:?}
PROBE=${CONFINE_PROBE:?}
RESP=${CONFINE_RESP:?}

probe_pid=
resp_note() {
	:
}
cleanup() {
	if [ -n "$probe_pid" ]; then
		kill "$probe_pid" 2>/dev/null || true
		wait "$probe_pid" 2>/dev/null || true
	fi
}
trap cleanup EXIT

sec=$WORK/sec
mkdir -p "$sec/storage/Roms" "$sec/storage/Bios" "$sec/storage/.config" \
	"$sec/storage/RomsExtra" "$sec/mnt/sd2" "$sec/private/.config" \
	"$sec/boot" "$sec/run" "$sec/ffs" "$sec/usbvol"
printf '%s\n' 'VISIBLE-CONFIG' > "$sec/storage/.config/key"
printf '%s\n' 'VISIBLE-SIB' > "$sec/storage/RomsExtra/secret"
printf '%s\n' 'ZLYME-SECRET-CONFIG' > "$sec/private/.config/key"
printf '%s\n' 'ZLYME-SECRET-BOOT' > "$sec/boot/secret"
printf '%s\n' ROMDATA > "$sec/storage/Roms/game.rom"
printf '%s\n' BIOSDATA > "$sec/storage/Bios/file.bin"
printf '%s\n' SDROM > "$sec/mnt/sd2/note.txt"
ln -s "$sec/private/.config/key" "$sec/storage/Roms/to-config"
ln -s "$sec/boot/secret" "$sec/storage/Roms/to-boot"
ln -s ../.config/key "$sec/storage/Roms/rel-dot"
ln -s ../RomsExtra/secret "$sec/storage/Roms/to-sibling"
ln -s ../../boot/secret "$sec/storage/Roms/rel-boot"
ln -s ../../private/.config/key "$sec/storage/Roms/rel-up"
mkdir -p "$sec/storage/Roms/hidden"
printf '%s\n' SAFE > "$sec/storage/swap"
mount -t tmpfs tmpfs "$sec/storage/Roms/hidden"
printf '%s\n' 'ZLYME-SECRET-NEST' > "$sec/storage/Roms/hidden/secret"
# Naming .config as its own export is refused. The same directory is
# visible only because the filesystem root is the export.
printf '%s\tsecret\n' "$sec/storage/.config" > "$sec/run/exports"
if ZLYME_USB_RUN=$sec/run ZLYME_USB_FFS=$sec/ffs ZLYME_USB_UMTPRD=$PROBE \
	"$ENTER" >"$sec/dot.err" 2>&1
then
	fail "hidden directory export was accepted"
fi
grep -q 'refusing export' "$sec/dot.err" || fail "hidden export reason: $(cat "$sec/dot.err")"
printf '%s\tboot\n' /boot > "$sec/run/exports"
if ZLYME_USB_RUN=$sec/run ZLYME_USB_FFS=$sec/ffs ZLYME_USB_UMTPRD=$PROBE \
	"$ENTER" >"$sec/boot.err" 2>&1
then
	fail "boot export was accepted"
fi
grep -q 'refusing export' "$sec/boot.err" || fail "boot export reason: $(cat "$sec/boot.err")"
printf '%s\tZLYME\n%s\tSD Card\n' "$sec/storage" "$sec/mnt/sd2" > "$sec/run/exports"
printf '%s\n' 'loop_on_disconnect 1' > "$sec/run/umtprd.conf"
ZLYME_USB_RUN=$sec/run \
ZLYME_USB_FFS=$sec/ffs \
ZLYME_USB_UMTPRD=$PROBE \
PROBE_SHARE=$sec/storage \
"$ENTER" >"$sec/enter.err" 2>&1 &
probe_pid=$!
i=0
while [ "$i" -lt 80 ]; do
	if [ -f "$sec/storage/result" ] && grep -q READY "$sec/storage/result"; then
		break
	fi
	i=$((i + 1))
	sleep 0.05
done
grep -q READY "$sec/storage/result" 2>/dev/null || fail "probe did not become ready: $(cat "$sec/enter.err" 2>/dev/null)"
rm -f "$sec/storage/swap"
ln -s "$sec/private/.config/key" "$sec/storage/swap"
: > "$sec/storage/race-go"
i=0
while [ "$i" -lt 80 ]; do
	grep -q DONE "$sec/storage/result" && break
	i=$((i + 1))
	sleep 0.05
done
grep -q DONE "$sec/storage/result" || fail "probe did not finish"
if grep -q 'ZLYME-SECRET' "$sec/storage/result"; then
	fail "jail exposed a secret: $(cat "$sec/storage/result")"
fi
grep -q '^rom DATA ROMDATA$' "$sec/storage/result" || fail "share read failed"
grep -q '^bios DATA BIOSDATA$' "$sec/storage/result" || fail "bios read failed"
grep -q '^inconfig DATA VISIBLE-CONFIG$' "$sec/storage/result" || fail "root export hid .config"
grep -q '^insib DATA VISIBLE-SIB$' "$sec/storage/result" || fail "root export hid a sibling directory"
grep -q '^reldot DATA VISIBLE-CONFIG$' "$sec/storage/result" || fail "in-tree relative link failed"
grep -q '^sibling DATA VISIBLE-SIB$' "$sec/storage/result" || fail "in-tree sibling link failed"
grep -q '^write OK$' "$sec/storage/result" || fail "share was not writable"
grep -q '^config BLOCKED ' "$sec/storage/result" || fail "config symlink was not confined"
grep -q '^boot BLOCKED ' "$sec/storage/result" || fail "boot symlink was not confined"
grep -q '^relboot BLOCKED ' "$sec/storage/result" || fail "boot relative link was not confined"
grep -q '^relup BLOCKED ' "$sec/storage/result" || fail "dotdot symlink was not confined"
grep -q '^escape BLOCKED ' "$sec/storage/result" || fail "parent directory was visible"
grep -q '^etc BLOCKED ' "$sec/storage/result" || fail "host /etc was visible"
grep -q '^dev BLOCKED ' "$sec/storage/result" || fail "host block device was visible"
grep -q '^hostboot BLOCKED ' "$sec/storage/result" || fail "host /boot was visible"
grep -q '^nested BLOCKED ' "$sec/storage/result" || fail "nested mount was visible"
grep -q '^race BLOCKED ' "$sec/storage/result" || fail "swapped symlink was readable"
grep -q '^race DATA ' "$sec/storage/result" && fail "swapped symlink returned data"
kill "$probe_pid" 2>/dev/null || true
wait "$probe_pid" 2>/dev/null || true
probe_pid=
umount "$sec/storage/Roms/hidden" || fail "nested tmpfs stayed mounted"

# A volume removed after the clone is not replaced by a new directory.
mkdir -p "$sec/usbvol"
mount -t tmpfs tmpfs "$sec/usbvol"
printf '%s\n' OLDFILE > "$sec/usbvol/note"
printf '%s\told\n' "$sec/usbvol" > "$sec/run/exports"
ZLYME_USB_RUN=$sec/run \
ZLYME_USB_FFS=$sec/ffs \
ZLYME_USB_UMTPRD=$PROBE \
PROBE_SHARE=$sec/usbvol \
"$ENTER" >"$sec/usb.err" 2>&1 &
probe_pid=$!
i=0
while [ "$i" -lt 80 ]; do
	if [ -f "$sec/usbvol/result" ] && grep -q READY "$sec/usbvol/result"; then
		break
	fi
	i=$((i + 1))
	sleep 0.05
done
grep -q READY "$sec/usbvol/result" 2>/dev/null || fail "usb probe did not become ready: $(cat "$sec/usb.err" 2>/dev/null)"
# The probe's rom check looks under Roms/. This second share only needs
# the removal check below, so stop it before that check can fail the
# secret scan. Read the cloned file from the jail via /proc instead.
jail_note=/proc/$probe_pid/root$sec/usbvol/note
grep -qx OLDFILE "$jail_note" || fail "clone did not keep the original file"
umount "$sec/usbvol"
mkdir -p "$sec/usbvol"
printf '%s\n' NEWFILE > "$sec/usbvol/note"
grep -qx OLDFILE "$jail_note" || fail "clone followed the replacement directory"
grep -qx NEWFILE "$jail_note" && fail "clone saw the replacement file"
kill "$probe_pid" 2>/dev/null || true
wait "$probe_pid" 2>/dev/null || true
probe_pid=

# A symlink as the export root is refused before any pivot.
ln -s "$sec/private" "$sec/linkroot"
printf '%s\tX\n' "$sec/linkroot" > "$sec/run/exports"
if ZLYME_USB_RUN=$sec/run ZLYME_USB_FFS=$sec/ffs ZLYME_USB_UMTPRD=$PROBE \
	"$ENTER" >"$sec/link.err" 2>&1
then
	fail "symlink export root was accepted"
fi
grep -q 'refusing export' "$sec/link.err" || fail "symlink export reason: $(cat "$sec/link.err")"

# Helper session: primary exFAT plus ext4 libraries.
base=$WORK/int
rm -rf "$base"
mkdir -p "$base/configfs" "$base/udc/fcc00000.usb" "$base/storage" \
	"$base/sd2" "$base/media/empty" "$base/media/ro" "$base/media/usb" \
	"$base/media/ntfs" "$base/private/.config" "$base/ffs"
printf '%s\n' 'not attached' > "$base/udc/fcc00000.usb/state"
printf '%s\n' secret > "$base/private/.config/key"
ln -s "$base/private/.config/key" "$base/sd2/leak"
printf '%s\n' "$base/storage" "$base/sd2" "$base/media/empty" \
	"$base/media/ro" "$base/media/usb" "$base/media/ntfs" \
	"$base/media/missing" > "$base/libraries"
printf 'vol0 %s exfat rw 0 0\nvol1 %s ext4 rw 0 0\nvol2 %s ext4 rw 0 0\nvol3 %s ext4 ro 0 0\nvol4 %s ext4 rw 0 0\nvol5 %s ntfs rw 0 0\n' \
	"$base/storage" "$base/sd2" "$base/media/empty" "$base/media/ro" \
	"$base/media/usb" "$base/media/ntfs" \
	> "$base/mounts"
: > "$base/mount.log"

run_real() {
	ZLYME_USB_RUN=$base/run \
	ZLYME_USB_CONFIGFS=$base/configfs \
	ZLYME_USB_UDC_CLASS=$base/udc \
	ZLYME_USB_MOUNTS=$base/mounts \
	ZLYME_USB_FFS=$base/ffs \
	ZLYME_USB_UMTPRD=$RESP \
	ZLYME_USB_ENTER=$ENTER \
	ZLYME_USB_JAIL=1 \
	ZLYME_USB_UDC_NAME=fcc00000.usb \
	ZLYME_LIBRARIES_FILE=$base/libraries \
	ZLYME_USB_STORAGE=$base/storage \
	ZLYME_USB_SD2=$base/sd2 \
	ZLYME_USB_MEDIA=$base/media \
	ZLYME_USB_BOOT=$base/boot \
	ZLYME_USB_MOUNT=$WORK/bin/mount \
	ZLYME_USB_UMOUNT=$WORK/bin/umount \
	ZLYME_USB_MOUNT_LOG=$base/mount.log \
	ZLYME_USB_TEST_LAYOUT=1 \
	ZLYME_USB_READY_POLLS=40 \
	ZLYME_USB_READY_SLEEP=0.05 \
	ZLYME_USB_SPAWN_POLLS=40 \
	ZLYME_USB_SPAWN_SLEEP=0.05 \
	ZLYME_USB_KILL_POLLS=8 \
	ZLYME_USB_KILL_SLEEP=0.05 \
	ZLYME_USB_REAP_SLEEP=0.05 \
	ZLYME_USB_REAP_WAIT=0.05 \
	ZLYME_USB_LINK_SLEEP=0.05 \
	ZLYME_USB_DMESG=$base/dmesg \
	ZLYME_FAKE_UMTP=ready \
	"$HELPER" "$@"
}

run_real start >"$base/start.out" 2>"$base/start.err" || fail "ext4 start failed: $(cat "$base/start.err")"
st=$(run_real status)
printf '%s\n' "$st" | grep -qx "export=$base/storage" || fail "primary missing: $st"
printf '%s\n' "$st" | grep -qx 'export_name=ZLYME' || fail "primary name missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/sd2" || fail "ext4 sd2 missing: $st"
printf '%s\n' "$st" | grep -qx 'export_name=SD Card' || fail "sd2 name missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/media/usb" || fail "ext4 usb missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/media/empty" || fail "empty volume missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/media/ro" || fail "read-only ext4 missing: $st"
printf '%s\n' "$st" | grep -q "skipped=$base/media/missing is not mounted" || fail "missing volume was not reported: $st"
printf '%s\n' "$st" | grep -q "skipped=$base/media/ntfs filesystem is ntfs" || fail "ntfs was not skipped: $st"
conf=$base/run/umtprd.conf
grep -q "storage \"$base/storage\" \"ZLYME\" \"rw\"" "$conf" || fail "primary storage line missing"
grep -q "storage \"$base/sd2\" \"SD Card\" \"rw,removable\"" "$conf" || fail "ext4 storage line missing"
grep -q "storage \"$base/media/usb\" \"usb\" \"rw,removable\"" "$conf" || fail "usb ext4 storage line missing"
grep -q "storage \"$base/media/ro\" \"ro\" \"ro,removable\"" "$conf" || fail "read-only line missing"
grep -q "storage \"$base/media/empty\" \"empty\" \"rw,removable\"" "$conf" || fail "empty volume line missing"
grep -q mmcblk "$conf" && fail "block device exported"
grep -q '/\.config' "$conf" && fail "config path exported"
grep -q '/boot' "$conf" && fail "boot path exported"
[ -L "$base/sd2/leak" ] || fail "ext4 symlink was removed"
rpid=$(cat "$base/run/responder.pid")
self_ns=$(readlink /proc/self/ns/mnt)
resp_ns=$(readlink "/proc/$rpid/ns/mnt")
[ "$self_ns" != "$resp_ns" ] || fail "responder stayed in the caller mount namespace"
printf '%s\n' 'not attached' > "$base/udc/fcc00000.usb/state"
st=$(run_real status)
printf '%s\n' "$st" | grep -qx 'state=bound' || fail "unplug dropped the session: $st"
printf '%s\n' "$st" | grep -qx 'host=not attached' || fail "unplug state: $st"
kill -0 "$rpid" 2>/dev/null || fail "unplug killed the responder"
printf '%s\n' 'configured' > "$base/udc/fcc00000.usb/state"
st=$(run_real status)
printf '%s\n' "$st" | grep -qx 'host=configured' || fail "replug state: $st"
run_real stop >"$base/stop.out" 2>"$base/stop.err" || fail "stop failed: $(cat "$base/stop.err")"
[ ! -d "$base/configfs/usb_gadget/zlyme-mtp" ] || fail "stop left the gadget"
kill -0 "$rpid" 2>/dev/null && fail "stop left the responder"

# Nested mount in the mount table is still refused.
mkdir -p "$base/storage/Roms/hidden"
printf 'nest %s ext4 rw 0 0\n' "$base/storage/Roms/hidden" >> "$base/mounts"
if run_real start >"$base/nest.out" 2>"$base/nest.err"; then
	fail "nested mount was exported"
fi
grep -q 'nested mount' "$base/nest.err" || fail "nested reason: $(cat "$base/nest.err")"
[ -d "$base/storage/Roms/hidden" ] || fail "nested test removed the directory"

# Foreign gadget is left alone.
printf 'vol0 %s exfat rw 0 0\n' "$base/storage" > "$base/mounts"
mkdir -p "$base/configfs/usb_gadget/other"
printf '%s\n' fcc00000.usb > "$base/configfs/usb_gadget/other/UDC"
if run_real start >"$base/foreign.out" 2>"$base/foreign.err"; then
	fail "start replaced a foreign gadget"
fi
got=$(tr -d '[:space:]' < "$base/configfs/usb_gadget/other/UDC")
[ "$got" = fcc00000.usb ] || fail "foreign UDC changed to $got"
rm -rf "$base/configfs/usb_gadget/other"

# Normal PAK exit stops the jailed session. The kernel state is
# "not attached", so the running screen must not say connected.
printf '%s\n' 'not attached' > "$base/udc/fcc00000.usb/state"
printf '%s\n' 0 0 > "$WORK/presenter.codes"
: > "$WORK/presenter.log"
rm -f "$WORK/presenter.count"
ZLYME_USB_TRANSFER=$HELPER \
ZLYME_USB_PRESENTER=$WORK/bin/presenter \
ZLYME_PRESENTER_LOG=$WORK/presenter.log \
ZLYME_PRESENTER_CODES=$WORK/presenter.codes \
ZLYME_PRESENTER_COUNT=$WORK/presenter.count \
ZLYME_USB_RUN=$base/run \
ZLYME_USB_CONFIGFS=$base/configfs \
ZLYME_USB_UDC_CLASS=$base/udc \
ZLYME_USB_MOUNTS=$base/mounts \
ZLYME_USB_FFS=$base/ffs \
ZLYME_USB_UMTPRD=$RESP \
ZLYME_USB_ENTER=$ENTER \
ZLYME_USB_JAIL=1 \
ZLYME_USB_UDC_NAME=fcc00000.usb \
	ZLYME_LIBRARIES_FILE=$base/libraries \
	ZLYME_USB_STORAGE=$base/storage \
	ZLYME_USB_SD2=$base/sd2 \
	ZLYME_USB_MEDIA=$base/media \
	ZLYME_USB_BOOT=$base/boot \
	ZLYME_USB_MOUNT=$WORK/bin/mount \
ZLYME_USB_UMOUNT=$WORK/bin/umount \
ZLYME_USB_TEST_LAYOUT=1 \
ZLYME_USB_READY_SLEEP=0.05 \
ZLYME_USB_SPAWN_SLEEP=0.05 \
ZLYME_USB_REAP_SLEEP=0.05 \
ZLYME_USB_REAP_WAIT=0.05 \
ZLYME_USB_LINK_SLEEP=0.05 \
ZLYME_USB_DMESG=$base/dmesg \
"$PAK" >"$base/pak.out" 2>&1 || fail "pak exit is nonzero: $(cat "$base/pak.out")"
grep -q 'whole data card' "$WORK/presenter.log" || fail "pak did not warn about the data card"
check_presenter_pages "$WORK/presenter.log.pages"
if grep -q 'USB:' "$WORK/presenter.log.pages"; then
	fail "pak printed a raw USB state"
fi
if grep -q 'MENU+START' "$WORK/presenter.log.pages"; then
	fail "pak explained the emergency stop"
fi
grep -q 'Storage: ZLYME.' "$WORK/presenter.log.pages" || fail "pak did not summarize storage"
grep -q 'MTP is active.' "$WORK/presenter.log.pages" || fail "pak did not say MTP is active"
run_page=$(sed -n '2p' "$WORK/presenter.log")
printf '%s\n' "$run_page" | grep -q -- '--confirm-show' && fail "running page showed A"
if grep -q "$base/" "$WORK/presenter.log.pages"; then
	fail "pak printed a full export path"
fi
if grep -q 'connected' "$WORK/presenter.log.pages"; then
	fail "pak called the host connected"
fi
[ ! -d "$base/configfs/usb_gadget/zlyme-mtp" ] || fail "pak stop left the gadget"

# MENU+START against a jailed responder in another process group.
our_pgrp=$(
	line=$(cat /proc/$$/stat)
	rest=${line#*)}
	set -f
	# shellcheck disable=SC2086
	set -- $rest
	printf '%s\n' "$3"
)
cat > "$WORK/bin/run-pak-jail" << EOF
#!/bin/sh
printf '%s\\n' "\$\$" > "$base/pak.pid"
export ZLYME_USB_TRANSFER="$HELPER"
export ZLYME_USB_PRESENTER="$WORK/bin/hold-presenter"
export ZLYME_PRESENTER_COUNT="$base/presenter.count"
export ZLYME_USB_RUN="$base/run"
export ZLYME_USB_CONFIGFS="$base/configfs"
export ZLYME_USB_UDC_CLASS="$base/udc"
export ZLYME_USB_MOUNTS="$base/mounts"
export ZLYME_USB_FFS="$base/ffs"
export ZLYME_USB_UMTPRD="$RESP"
export ZLYME_USB_ENTER="$ENTER"
export ZLYME_USB_JAIL=1
export ZLYME_USB_UDC_NAME=fcc00000.usb
export ZLYME_LIBRARIES_FILE="$base/libraries"
export ZLYME_USB_STORAGE="$base/storage"
export ZLYME_USB_SD2="$base/sd2"
export ZLYME_USB_MOUNT="$WORK/bin/mount"
export ZLYME_USB_UMOUNT="$WORK/bin/umount"
export ZLYME_USB_TEST_LAYOUT=1
export ZLYME_USB_READY_SLEEP=0.05
export ZLYME_USB_SPAWN_SLEEP=0.05
export ZLYME_USB_KILL_SLEEP=0.05
export ZLYME_USB_REAP_SLEEP=0.05
export ZLYME_USB_REAP_WAIT=0.05
export ZLYME_USB_LINK_SLEEP=0.05
export ZLYME_USB_DMESG="$base/dmesg"
export ZLYME_FAKE_UMOUNT_DELAY=2
export ZLYME_FAKE_UMOUNT_MARK="$base/umount-delay.mark"
exec "$PAK"
EOF
chmod 755 "$WORK/bin/run-pak-jail"
rm -f "$base/pak.pid" "$base/presenter.count"
setsid "$WORK/bin/run-pak-jail" >"$base/group.out" 2>&1 < /dev/null &
i=0
while [ "$i" -lt 50 ]; do
	[ -s "$base/pak.pid" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -s "$base/pak.pid" ] || fail "jailed pak did not start"
pak_pid=$(cat "$base/pak.pid")
pak_pgrp=$(
	line=$(cat "/proc/$pak_pid/stat")
	rest=${line#*)}
	set -f
	# shellcheck disable=SC2086
	set -- $rest
	printf '%s\n' "$3"
)
[ "$pak_pgrp" != "$our_pgrp" ] || fail "jailed pak shares this process group"
prove_group_reaper "jailed cleanup" "$base/run" \
	"$base/configfs/usb_gadget/zlyme-mtp" "$base/mounts" \
	"$base/ffs" "$pak_pgrp" "$base/umount-delay.mark"
