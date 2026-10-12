#!/bin/sh
# Real mount-namespace confinement for the USB transfer helper.
# The caller must already be root in a user and mount namespace.
# Nothing here opens the host's USB controllers.
set -eu

fail() {
	printf 'usb confine: %s\n' "$*" >&2
	exit 1
}

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
mkdir -p "$sec/storage/Roms" "$sec/storage/Bios" "$sec/mnt/sd2/Roms" \
	"$sec/mnt/sd2/Bios" "$sec/private/.config" "$sec/boot" \
	"$sec/storage/RomsExtra" "$sec/run" "$sec/ffs"
printf '%s\n' 'ZLYME-SECRET-CONFIG' > "$sec/private/.config/key"
printf '%s\n' 'ZLYME-SECRET-BOOT' > "$sec/boot/secret"
printf '%s\n' 'ZLYME-SECRET-SIB' > "$sec/storage/RomsExtra/secret"
printf '%s\n' ROMDATA > "$sec/storage/Roms/game.rom"
printf '%s\n' BIOSDATA > "$sec/storage/Bios/file.bin"
printf '%s\n' SDROM > "$sec/mnt/sd2/Roms/game.rom"
ln -s "$sec/private/.config/key" "$sec/storage/Roms/to-config"
ln -s "$sec/boot/secret" "$sec/storage/Roms/to-boot"
ln -s ../.config/key "$sec/storage/Roms/rel-dot"
ln -s ../RomsExtra/secret "$sec/storage/Roms/to-sibling"
ln -s ../../boot/secret "$sec/storage/Roms/rel-boot"
ln -s ../../private/.config/key "$sec/storage/Roms/rel-up"
mkdir -p "$sec/storage/Roms/hidden"
printf '%s\n' SAFE > "$sec/storage/Roms/swap"
mount -t tmpfs tmpfs "$sec/storage/Roms/hidden"
printf '%s\n' 'ZLYME-SECRET-NEST' > "$sec/storage/Roms/hidden/secret"
printf '%s\tROMs\n%s\tBIOS\n%s\tSDROMs\n%s\tSDBIOS\n' \
	"$sec/storage/Roms" "$sec/storage/Bios" \
	"$sec/mnt/sd2/Roms" "$sec/mnt/sd2/Bios" > "$sec/run/exports"
printf '%s\n' 'loop_on_disconnect 1' > "$sec/run/umtprd.conf"
ZLYME_USB_RUN=$sec/run \
ZLYME_USB_FFS=$sec/ffs \
ZLYME_USB_UMTPRD=$PROBE \
PROBE_SHARE=$sec/storage/Roms \
"$ENTER" >"$sec/enter.err" 2>&1 &
probe_pid=$!
i=0
while [ "$i" -lt 80 ]; do
	if [ -f "$sec/storage/Roms/result" ] && grep -q READY "$sec/storage/Roms/result"; then
		break
	fi
	i=$((i + 1))
	sleep 0.05
done
grep -q READY "$sec/storage/Roms/result" 2>/dev/null || fail "probe did not become ready: $(cat "$sec/enter.err" 2>/dev/null)"
rm -f "$sec/storage/Roms/swap"
ln -s "$sec/private/.config/key" "$sec/storage/Roms/swap"
: > "$sec/storage/Roms/race-go"
i=0
while [ "$i" -lt 80 ]; do
	grep -q DONE "$sec/storage/Roms/result" && break
	i=$((i + 1))
	sleep 0.05
done
grep -q DONE "$sec/storage/Roms/result" || fail "probe did not finish"
if grep -q 'ZLYME-SECRET' "$sec/storage/Roms/result"; then
	fail "jail exposed a secret: $(cat "$sec/storage/Roms/result")"
fi
grep -q '^rom DATA ROMDATA$' "$sec/storage/Roms/result" || fail "share read failed"
grep -q '^bios DATA BIOSDATA$' "$sec/storage/Roms/result" || fail "bios read failed"
grep -q '^write OK$' "$sec/storage/Roms/result" || fail "share was not writable"
grep -q '^config BLOCKED ' "$sec/storage/Roms/result" || fail "config symlink was not confined"
grep -q '^boot BLOCKED ' "$sec/storage/Roms/result" || fail "boot symlink was not confined"
grep -q '^reldot BLOCKED ' "$sec/storage/Roms/result" || fail "relative dot symlink was not confined"
grep -q '^relup BLOCKED ' "$sec/storage/Roms/result" || fail "dotdot symlink was not confined"
grep -q '^sibling BLOCKED ' "$sec/storage/Roms/result" || fail "sibling symlink was not confined"
grep -q '^dotdot-sib BLOCKED ' "$sec/storage/Roms/result" || fail "sibling prefix was not confined"
grep -q '^nested BLOCKED ' "$sec/storage/Roms/result" || fail "nested mount was visible"
grep -q '^race BLOCKED ' "$sec/storage/Roms/result" || fail "swapped symlink was readable"
grep -q '^race DATA ' "$sec/storage/Roms/result" && fail "swapped symlink returned data"
kill "$probe_pid" 2>/dev/null || true
wait "$probe_pid" 2>/dev/null || true
probe_pid=
umount "$sec/storage/Roms/hidden" || fail "nested tmpfs stayed mounted"

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
mkdir -p "$base/configfs" "$base/udc/fcc00000.usb" "$base/storage/Roms" \
	"$base/storage/Bios" "$base/sd2/Roms" "$base/sd2/Bios" \
	"$base/empty" "$base/ro/Roms" "$base/usb/Roms" "$base/ntfs/Roms" \
	"$base/private/.config" "$base/ffs"
printf '%s\n' 'not attached' > "$base/udc/fcc00000.usb/state"
printf '%s\n' secret > "$base/private/.config/key"
ln -s "$base/private/.config/key" "$base/sd2/Roms/leak"
printf '%s\n' "$base/storage" "$base/sd2" "$base/empty" "$base/ro" \
	"$base/usb" "$base/ntfs" > "$base/libraries"
printf 'vol0 %s exfat rw 0 0\nvol1 %s ext4 rw 0 0\nvol2 %s ext4 rw 0 0\nvol3 %s ext4 ro 0 0\nvol4 %s ext4 rw 0 0\nvol5 %s ntfs rw 0 0\n' \
	"$base/storage" "$base/sd2" "$base/empty" "$base/ro" "$base/usb" "$base/ntfs" \
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
	ZLYME_FAKE_UMTP=ready \
	"$HELPER" "$@"
}

run_real start >"$base/start.out" 2>"$base/start.err" || fail "ext4 start failed: $(cat "$base/start.err")"
st=$(run_real status)
printf '%s\n' "$st" | grep -qx "export=$base/storage/Roms" || fail "primary missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/storage/Bios" || fail "primary bios missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/sd2/Roms" || fail "ext4 sd2 missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/sd2/Bios" || fail "ext4 sd2 bios missing: $st"
printf '%s\n' "$st" | grep -qx "export=$base/usb/Roms" || fail "ext4 usb missing: $st"
printf '%s\n' "$st" | grep -q "skipped=$base/empty/Roms is missing" || fail "missing roms was not reported: $st"
printf '%s\n' "$st" | grep -q "skipped=$base/ro mounted read-only" || fail "read-only ext4 was shared: $st"
printf '%s\n' "$st" | grep -q "skipped=$base/ntfs filesystem is ntfs" || fail "ntfs was not skipped: $st"
conf=$base/run/umtprd.conf
grep -q "storage \"$base/sd2/Roms\"" "$conf" || fail "ext4 storage line missing"
grep -q "storage \"$base/usb/Roms\"" "$conf" || fail "usb ext4 storage line missing"
grep -q mmcblk "$conf" && fail "block device exported"
grep -q '/\.config' "$conf" && fail "config path exported"
grep -q '/boot' "$conf" && fail "boot path exported"
[ -L "$base/sd2/Roms/leak" ] || fail "ext4 symlink was removed"
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

# Normal PAK exit stops the jailed session.
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
ZLYME_USB_MOUNT=$WORK/bin/mount \
ZLYME_USB_UMOUNT=$WORK/bin/umount \
ZLYME_USB_TEST_LAYOUT=1 \
ZLYME_USB_READY_SLEEP=0.05 \
ZLYME_USB_SPAWN_SLEEP=0.05 \
ZLYME_USB_REAP_SLEEP=0.05 \
ZLYME_USB_REAP_WAIT=0.05 \
"$PAK" >"$base/pak.out" 2>&1 || fail "pak exit is nonzero: $(cat "$base/pak.out")"
grep -q 'ext4' "$WORK/presenter.log" || fail "pak did not mention ext4"
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
export ZLYME_FAKE_UMOUNT_DELAY=2
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
i=0
while [ "$i" -lt 80 ]; do
	[ -s "$base/run/reaper.pgid" ] && [ -d "$base/configfs/usb_gadget/zlyme-mtp" ] && break
	i=$((i + 1))
	sleep 0.05
done
[ -d "$base/configfs/usb_gadget/zlyme-mtp" ] || fail "jailed group did not bind: $(cat "$base/group.out" 2>/dev/null)"
reaper_pg=$(cat "$base/run/reaper.pgid")
[ "$reaper_pg" != "$pak_pgrp" ] || fail "reaper stayed in the jailed pak group"
reaper_pid=$(cat "$base/run/reaper.pid")
kill -s TERM -- "-$pak_pgrp"
sleep 1.5
kill -s KILL -- "-$pak_pgrp" 2>/dev/null || true
kill -0 "$reaper_pid" 2>/dev/null || fail "jailed cleanup died with the pak"
i=0
while [ "$i" -lt 40 ]; do
	kill -0 "$reaper_pid" 2>/dev/null || break
	i=$((i + 1))
	sleep 0.1
done
kill -0 "$reaper_pid" 2>/dev/null && fail "jailed cleanup did not finish"
[ ! -d "$base/configfs/usb_gadget/zlyme-mtp" ] || fail "group kill left the jailed gadget"
