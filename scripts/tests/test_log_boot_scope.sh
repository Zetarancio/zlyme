#!/bin/sh
# System logs are latched once per boot. Settings changes the next boot.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CTL=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl
LOGS=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-logs
STAMP=$ROOT/board/my355/fsoverlay/usr/bin/zlyme-logstamp
S15=$ROOT/board/my355/fsoverlay/etc/init.d/S15bootpart
work=$(mktemp -d)
_rp=
_ap=
cleanup() {
	# Release a host rm wrapper, then stop any race children.
	if [ -n "${work:-}" ]; then
		: > "$work/barrier.go" 2>/dev/null || true
	fi
	if [ -n "${_rp:-}" ]; then
		kill "$_rp" 2>/dev/null || true
	fi
	if [ -n "${_ap:-}" ]; then
		kill "$_ap" 2>/dev/null || true
	fi
	if [ -n "${_rp:-}" ]; then
		wait "$_rp" 2>/dev/null || true
	fi
	if [ -n "${_ap:-}" ]; then
		wait "$_ap" 2>/dev/null || true
	fi
	rm -rf "$work"
}
trap cleanup EXIT

cat > "$work/zlyme.conf" << EOF
ZLYME_STORAGE=$work/storage
ZLYME_CFG=$work/storage/.config
ZLYME_DEFAULTS=/usr/share/zlyme
ZLYME_BOOT=$work/boot
EOF
export ZLYME_CONF=$work/zlyme.conf
export ZLYME_LOG_EFFECTIVE=$work/effective
export ZLYME_BOOT_LOG_FLAG=$work/boot-flag
mkdir -p "$work/storage/.config/zlyme"

fail() { echo "log boot scope: $*" >&2; exit 1; }

# Absent latch is off even if the saved request is on.
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
if ZLYME_CONF=$work/zlyme.conf ZLYME_LOG_EFFECTIVE=$work/effective "$CTL" want logs; then
	fail "unlatched want logs followed the saved request"
fi

ZLYME_CONF=$work/zlyme.conf ZLYME_LOG_EFFECTIVE=$work/effective "$CTL" latch-logs
"$CTL" want logs || fail "latch did not turn effective logs on"
# Saved request changes. This boot does not.
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
"$CTL" want logs || fail "effective logs followed a settings change"
# The boot flag follows the saved request, not the running boot.
"$CTL" apply-logs
[ ! -e "$work/boot-flag" ] || fail "apply-logs left the next-boot flag set"
# And it does not open a generation.
if [ -d "$work/storage/.logs/system-0" ]; then
	fail "apply-logs started a capture interval"
fi
if grep -q 'zlyme-logs apply' "$CTL"; then
	fail "apply-logs still starts zlyme-logs"
fi

# Turn the saved request back on. Runtime stays on from the latch.
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
"$CTL" apply-logs
[ -f "$work/boot-flag" ] || fail "apply-logs did not prepare the next boot flag"
"$CTL" want logs || fail "preparing the boot flag changed the running boot"

# A second latch does not follow a new saved value.
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
"$CTL" latch-logs
"$CTL" want logs || fail "second latch rewrote the effective state"

# S15 latches before the background seed.
awk '
	/latch-logs/ { seen = NR }
	/seed &/ && seen && !order { if (seen < NR) order = 1 }
	END { if (!order) exit 1 }
' "$S15" || fail "S15 latches logs after the seed returns"

# Settings text says the switch waits for restart.
grep -q 'Takes effect on next boot. Recording continues until you restart.' \
	"$ROOT/package/system/nextui/0001-logs-take-effect-on-next-boot.patch" \
	|| fail "settings description does not say restart"

# Stamps carry a wall clock and a monotonic value. A later wall-clock
# correction does not make the monotonic value go backwards.
datebin=$work/datebin
mkdir -p "$datebin"
cat > "$datebin/date" << 'EOF'
#!/bin/sh
if [ "${ZLYME_DATE_MODE:-early}" = early ]; then
	printf '%s\n' '1970-01-01T00:00:00Z'
else
	printf '%s\n' '2026-10-27T23:00:00Z'
fi
EOF
chmod 0755 "$datebin/date"
PATH="$datebin:$PATH" ZLYME_DATE_MODE=early "$STAMP" > "$work/early"
PATH="$datebin:$PATH" ZLYME_DATE_MODE=late "$STAMP" > "$work/late"
grep -q '^1970-01-01T00:00:00Z ' "$work/early" || fail "early stamp"
grep -q '^2026-10-27T23:00:00Z ' "$work/late" || fail "late stamp"
emono=$(awk '{print $2}' "$work/early")
lmono=$(awk '{print $2}' "$work/late")
awk -v a="$emono" -v b="$lmono" 'BEGIN { if (!(b+0 >= a+0)) exit 1 }' \
	|| fail "monotonic went backwards across a clock correction"

# One generation when effective logs are on. Force still drives zlyme-logs.
mark=$work/mark
root=$work/logs
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$root" ZLYME_LOG_MARK="$mark" \
	ZLYME_LOG_LOCK="$work/lock" "$LOGS" start
test -d "$root/system-0"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$root" ZLYME_LOG_MARK="$mark" \
	ZLYME_LOG_LOCK="$work/lock" "$LOGS" start
test ! -d "$root/system-1"

# Initramfs authorization. Temporary files only. No host mounts.
INIT=$ROOT/package/boot/zlyme-initramfs/init
bootroot=$work/bootroot
storroot=$work/storroot
mkdir -p "$bootroot" "$storroot/.config/zlyme"
printf '%s\n' "/dev/fixture ${storroot} exfat rw 0 0" > "$work/imounts"
cfg=$storroot/.config/zlyme/logs
marker=$bootroot/zlyme-logs
decide() {
	ZLYME_INIT_TEST=logs \
		ZLYME_INIT_BOOT="$bootroot" \
		ZLYME_INIT_STORAGE="$storroot" \
		ZLYME_PROC_MOUNTS="$work/imounts" \
		sh "$INIT"
}
has() {
	printf '%s\n' "$1" | grep -qx "$2" || fail "expected $2 in: $1"
}

# A. Saved off, no marker.
printf '%s\n' off > "$cfg"
rm -f "$marker"
out=$(decide)
has "$out" capture=no
has "$out" remount=none

# B. Saved off, stale marker. No capture and no diagnostic remount.
: > "$marker"
out=$(decide)
has "$out" capture=no
has "$out" remount=none

# C. Saved on and marker present.
printf '%s\n' on > "$cfg"
out=$(decide)
has "$out" capture=yes
has "$out" remount=logs
printf '%s\n' '  on  ' > "$cfg"
out=$(decide)
has "$out" capture=yes
printf '%s\n' 1 > "$cfg"
out=$(decide)
has "$out" capture=yes

# D. Saved on, marker absent.
rm -f "$marker"
printf '%s\n' on > "$cfg"
out=$(decide)
has "$out" capture=no
has "$out" remount=none

# E. Missing, empty, invalid, unreadable, or storage not mounted.
rm -f "$cfg"
: > "$marker"
out=$(decide)
has "$out" capture=no
: > "$cfg"
out=$(decide)
has "$out" capture=no
printf '%s\n' no > "$cfg"
out=$(decide)
has "$out" capture=no
chmod a-r "$cfg"
if [ -r "$cfg" ]; then
	fail "mode 000 file is still readable"
fi
out=$(decide)
has "$out" capture=no
chmod u+r "$cfg"
mkdir -p "$work/other/.config/zlyme"
printf '%s\n' on > "$work/other/.config/zlyme/logs"
printf '%s\n' off > "$cfg"
out=$(decide)
has "$out" capture=no
printf '%s\n' "proc /proc proc rw 0 0" > "$work/imounts"
printf '%s\n' on > "$cfg"
out=$(decide)
has "$out" capture=no
has "$out" remount=none
printf '%s\n' "/dev/fixture ${storroot} exfat rw 0 0" > "$work/imounts"

# F. A failed remove leaves the marker. The next initramfs decision
# still refuses capture.
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
: > "$work/boot-flag"
cat > "$work/failwrite" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 0755 "$work/failwrite"
if ZLYME_BOOT_WRITE="$work/failwrite" "$CTL" reconcile-boot-logs; then
	fail "failed boot write reported success"
fi
[ -f "$work/boot-flag" ] || fail "failed remove deleted the marker"
grep -qx off "$work/storage/.config/zlyme/logs"
printf '%s\n' off > "$cfg"
: > "$marker"
out=$(decide)
has "$out" capture=no
has "$out" remount=none

# A failed arm does not roll the saved request back.
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
rm -f "$work/boot-flag"
if ZLYME_BOOT_WRITE="$work/failwrite" "$CTL" apply-logs; then
	fail "failed flag create reported success"
fi
grep -qx on "$work/storage/.config/zlyme/logs"
[ ! -e "$work/boot-flag" ] || fail "failed create left a marker"

# G. A later cleanup removes the stale marker.
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
: > "$work/boot-flag"
cat > "$work/runwrite" << 'EOF'
#!/bin/sh
"$@"
EOF
chmod 0755 "$work/runwrite"
ZLYME_BOOT_WRITE="$work/runwrite" "$CTL" reconcile-boot-logs
[ ! -e "$work/boot-flag" ] || fail "cleanup left the stale marker"

# H. Effective off, saved already on: cleanup must not touch the marker.
printf '%s\n' off > "$work/effective"
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
: > "$work/boot-flag"
: > "$work/called"
cat > "$work/nope" << EOF
#!/bin/sh
printf '%s\\n' called >> "$work/called"
exit 1
EOF
chmod 0755 "$work/nope"
ZLYME_BOOT_WRITE="$work/nope" "$CTL" reconcile-boot-logs
[ ! -s "$work/called" ] || fail "cleanup ran while the saved request was on"
[ -f "$work/boot-flag" ] || fail "cleanup removed a marker armed for the next boot"
if "$CTL" want logs; then
	fail "effective state followed the pending request"
fi
# The saved value flips to on inside the locked command.
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
: > "$work/boot-flag"
cat > "$work/flip" << EOF
#!/bin/sh
printf '%s\\n' on > "$work/storage/.config/zlyme/logs"
"\$@"
EOF
chmod 0755 "$work/flip"
ZLYME_BOOT_WRITE="$work/flip" "$CTL" reconcile-boot-logs
grep -qx on "$work/storage/.config/zlyme/logs"
[ -f "$work/boot-flag" ] || fail "in-lock enable lost the marker"

# I. Effective on, saved off. This boot keeps recording. The marker goes.
printf '%s\n' on > "$work/effective"
printf '%s\n' off > "$work/storage/.config/zlyme/logs"
: > "$work/boot-flag"
ZLYME_BOOT_WRITE="$work/runwrite" "$CTL" reconcile-boot-logs
"$CTL" want logs || fail "cleanup changed the running boot"
[ ! -e "$work/boot-flag" ] || fail "pending off left the marker"
printf '%s\n' off > "$cfg"
rm -f "$marker"
out=$(decide)
has "$out" capture=no

# J. A pending update still asks for a remount when diagnostics do not.
mkdir -p "$storroot/.update/pending"
: > "$storroot/.update/pending/zlyme"
: > "$marker"
out=$(decide)
has "$out" capture=no
has "$out" remount=update
rm -rf "$storroot/.update"
grep -q 'commit_update' "$INIT" || fail "update transaction missing"

# K. First enabled reboot: the marker, the saved value, and the latch agree.
rm -f "$work/effective" "$work/boot-flag" "$marker"
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
"$CTL" apply-logs
[ -f "$work/boot-flag" ] || fail "apply-logs did not arm the next boot"
"$CTL" latch-logs
"$CTL" want logs || fail "latch did not follow the saved on request"
cp "$work/boot-flag" "$marker"
printf '%s\n' on > "$cfg"
out=$(decide)
has "$out" capture=yes
has "$out" remount=logs

# L. The decision functions do not remount. The real path still closes
# the volume after a write.
if awk '/^early_dmesg_wanted\(\)/,/^}/' "$INIT" | grep -w -q mount; then
	fail "early decision remounts"
fi
if awk '/^classify_boot_rw\(\)/,/^}/' "$INIT" | grep -w -q mount; then
	fail "classify remounts"
fi
grep -q 'boot_close_ro' "$INIT" || fail "boot is not closed read-only"
grep -q '\[ "$pending" -eq 1 \] || \[ "$logs" -eq 1 \]' "$INIT" || fail "remount gate missing"
if grep -q '\[ -f /boot_root/zlyme-logs \]' "$INIT"; then
	fail "marker alone still authorizes capture"
fi

# The seed retries a stale marker before the boot snapshot, off the
# first-frame path.
awk '
	/^seed\(\)/ { in_seed = 1 }
	in_seed && /^}/ { in_seed = 0 }
	in_seed && /reconcile-boot-logs/ && !seen { seen = NR }
	in_seed && /zlyme-logs start boot/ && seen && seen < NR { ok = 1 }
	END { exit ok ? 0 : 1 }
' "$S15" || fail "seed does not reconcile before start boot"

grep -q 'Early boot log was not updated.' \
	"$ROOT/package/system/nextui/0001-logs-take-effect-on-next-boot.patch" \
	|| fail "settings does not report a failed boot write"

# Saved on and the marker already present: the locked command does not
# rewrite the file. The writer still runs, so the lock is not skipped.
printf '%s\n' on > "$work/storage/.config/zlyme/logs"
printf '%s\n' keep > "$work/boot-flag"
cat > "$work/passwrite" << 'EOF'
#!/bin/sh
"$@"
EOF
chmod 0755 "$work/passwrite"
ZLYME_BOOT_WRITE="$work/passwrite" "$CTL" apply-logs
grep -qx keep "$work/boot-flag" || fail "an already-correct marker was rewritten"

# Host-only pause. The wrapper stops on the fixture marker while
# lockwrite still holds the flock, then removes it after release.
mkdir -p "$work/rmbin"
cat > "$work/rmbin/rm" << EOF
#!/bin/sh
i=0
for a in "\$@"; do
	if [ "\$a" = "$work/boot-flag" ]; then
		printf '%s\n' reached > "$work/barrier"
		while [ ! -f "$work/barrier.go" ]; do
			i=\$((i + 1))
			if [ "\$i" -gt 200 ]; then
				echo "boot-marker rm wait expired" >&2
				exit 1
			fi
			sleep 0.05
		done
		break
	fi
done
exec /bin/rm "\$@"
EOF
chmod 0755 "$work/rmbin/rm"
cat > "$work/lockwrite" << EOF
#!/bin/sh
exec 9>>"$work/bwlock"
flock 9
"\$@"
EOF
chmod 0755 "$work/lockwrite"

# expect=kept: apply waits, then the marker is present.
# expect=lost: apply returns while the remove is held, then the marker is gone.
race_once() {
	_ctl=$1
	_expect=$2
	printf '%s\n' off > "$work/storage/.config/zlyme/logs"
	: > "$work/boot-flag"
	rm -f "$work/barrier" "$work/barrier.go" "$work/bwlock"
	_rp=
	_ap=
	PATH="$work/rmbin:$PATH" ZLYME_BOOT_WRITE="$work/lockwrite" \
		"$_ctl" reconcile-boot-logs &
	_rp=$!
	_i=0
	while [ ! -s "$work/barrier" ]; do
		_i=$((_i + 1))
		if [ "$_i" -gt 80 ]; then
			fail "reconcile did not reach the remove"
		fi
		sleep 0.05
	done
	printf '%s\n' on > "$work/storage/.config/zlyme/logs"
	PATH="$work/rmbin:$PATH" ZLYME_BOOT_WRITE="$work/lockwrite" \
		"$_ctl" apply-logs &
	_ap=$!
	sleep 0.2
	_alive=0
	if kill -0 "$_ap" 2>/dev/null; then
		_alive=1
	fi
	: > "$work/barrier.go"
	wait "$_rp" || fail "reconcile failed"
	wait "$_ap" || fail "apply-logs failed"
	_rp=
	_ap=
	grep -qx on "$work/storage/.config/zlyme/logs" || fail "saved request changed"
	if [ "$_expect" = kept ]; then
		[ "$_alive" -eq 1 ] || fail "apply-logs returned while reconcile held the lock"
		[ -f "$work/boot-flag" ] || fail "the next boot lost its marker"
	else
		[ "$_alive" -eq 0 ] || fail "the old apply waited for the lock"
		[ ! -e "$work/boot-flag" ] || fail "the old apply kept the marker"
	fi
}

git -C "$ROOT" show 86b204a429bc5066b863cd179658f9f4b7317901:board/my355/fsoverlay/usr/sbin/zlyme-ctl \
	> "$work/baseline-ctl"
chmod 0755 "$work/baseline-ctl"
race_once "$work/baseline-ctl" lost
race_once "$CTL" kept

echo "log boot scope ok"
