#!/bin/sh
# Host checks for bounded system and PAK logs. Does not touch /storage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LOGS="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-logs"
PAK="$ROOT/package/system/nextui/zlyme/pak-log.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sys=$work/logs
mark=$work/run/zlyme-logs-generation
mkdir -p "$work/run"

boot() {
	rm -f "$mark"
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
	cur=$(ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" current)
	printf '%s\n' "$1" > "$cur/id"
}

n=1
while [ "$n" -le 7 ]; do
	boot "$n"
	n=$((n + 1))
done

cur=$(ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" current)
[ "$(cat "$cur/id")" = 7 ]
[ "$(cat "$sys/system-0/id")" = 7 ]
[ "$(cat "$sys/system-1/id")" = 6 ]
[ "$(cat "$sys/system-2/id")" = 5 ]
[ "$(cat "$sys/system-3/id")" = 4 ]
[ "$(cat "$sys/system-4/id")" = 3 ]
test ! -d "$sys/system-5"
test ! -d "$sys/system-6"

# Second start in the same boot does not rotate.
printf '%s\n' same > "$sys/system-0/id"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
[ "$(cat "$sys/system-0/id")" = same ]
[ "$(cat "$sys/system-1/id")" = 6 ]

# Off then On in the same boot does not rotate either.
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" stop
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
[ "$(cat "$sys/system-0/id")" = same ]
[ "$(cat "$sys/system-1/id")" = 6 ]
test -f "$mark"

# Logging off does not create a generation.
off=$work/off
offmark=$work/off-mark
ZLYME_LOG_ROOT="$off" ZLYME_LOG_MARK="$offmark" "$LOGS" start
test ! -d "$off/system-0"
test ! -f "$offmark"

paks=$work/paks-root
launch() {
	tag=$1
	id=$2
	# pak-log redirects the shell that sources it. Keep that inside
	# this command so the test runner's own stdout stays put.
	sh -c '
		EMU_TAG=$1
		EMU_EXE=core
		ROM=
		ZLYME_LOG_FORCE=1
		ZLYME_LOG_ROOT=$2
		. "$3"
		printf "LAUNCH %s\n" "$4" >> "$ZLYME_PAK_LOG"
	' sh "$tag" "$paks" "$PAK" "$id"
}

i=1
while [ "$i" -le 5 ]; do
	launch GBA "$i"
	i=$((i + 1))
done
grep -q 'LAUNCH 5' "$paks/paks/GBA.log"
grep -q 'LAUNCH 4' "$paks/paks/GBA.log.1"
grep -q 'LAUNCH 3' "$paks/paks/GBA.log.2"
test ! -e "$paks/paks/GBA.log.3"
grep -q 'LAUNCH 5' "$paks/paks/GBA.log.1" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log.1" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log.2" && exit 1
grep -q 'LAUNCH 2' "$paks/paks/GBA.log.2" && exit 1

launch PSP 1
launch PSP 2
grep -q 'LAUNCH 2' "$paks/paks/PSP.log"
grep -q 'LAUNCH 1' "$paks/paks/PSP.log.1"
grep -q 'LAUNCH 5' "$paks/paks/GBA.log"

quiet=$work/quiet
sh -c 'EMU_TAG=GBA EMU_EXE=core ROM= ZLYME_LOG_ROOT=$1 . "$2"' sh "$quiet" "$PAK"
test ! -e "$quiet/paks/GBA.log"

# Text already in the tmpfs files when logs turn on is not copied.
# Bytes appended while logs are on are. Off, then on, skips the gap
# and does not rotate again.
sess=$work/session-src
mkdir -p "$sess"
printf '%s\n' 'OFF-A' > "$sess/wrap.log"
printf '%s\n' 'OFF-T' > "$sess/text.txt"
snap=$work/snap
snapmark=$work/snap-mark
snap_env() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$snap" ZLYME_LOG_MARK="$snapmark" \
		ZLYME_LOG_LOCK="$work/snap.lock" \
		ZLYME_SESSION_WRAP="$sess/wrap.log" ZLYME_SESSION_TEXT="$sess/text.txt" \
		"$@"
}
snap_env "$LOGS" start
if [ -f "$snap/system-0/session.txt" ]; then
	grep -q 'OFF-A' "$snap/system-0/session.txt" && exit 1
fi
if [ -f "$snap/system-0/next.txt" ]; then
	grep -q 'OFF-T' "$snap/system-0/next.txt" && exit 1
fi
printf '%s\n' 'ON-A' >> "$sess/wrap.log"
printf '%s\n' 'ON-T' >> "$sess/text.txt"
snap_env "$LOGS" start
grep -q 'ON-A' "$snap/system-0/session.txt"
grep -q 'ON-T' "$snap/system-0/next.txt"
grep -q 'OFF-A' "$snap/system-0/session.txt" && exit 1
test ! -d "$snap/system-1"
printf '%s\n' 'ON-TAIL' >> "$sess/wrap.log"
snap_env "$LOGS" stop
grep -q 'ON-TAIL' "$snap/system-0/session.txt"
printf '%s\n' 'OFF-B' >> "$sess/wrap.log"
snap_env "$LOGS" start
grep -q 'OFF-B' "$snap/system-0/session.txt" && exit 1
grep -q 'ON-A' "$snap/system-0/session.txt"
printf '%s\n' 'ON-C' >> "$sess/wrap.log"
snap_env "$LOGS" start
grep -q 'ON-C' "$snap/system-0/session.txt"
grep -q 'OFF-B' "$snap/system-0/session.txt" && exit 1
test ! -d "$snap/system-1"

# Two unlocked checkers both pass a missing marker and both record a
# rotation. The count is lines appended after the barrier, not a shared
# increment: $$ is the parent shell in both jobs.
umark=$work/umark
ubar=$work/ubar
unlocked() {
	if [ ! -f "$umark" ]; then
		echo x >> "$ubar"
		while [ ! -f "$ubar.go" ]; do
			sleep 0.02
		done
		echo x >> "$umark"
	fi
}
unlocked &
unlocked &
while [ "$(wc -l < "$ubar" | tr -d ' ')" -lt 2 ]; do
	sleep 0.02
done
: > "$ubar.go"
wait
[ "$(wc -l < "$umark" | tr -d ' ')" = 2 ]

# The same overlap through zlyme-logs, under the lock, rotates once.
rm -f "$umark"
race=$work/race
rmark=$work/rmark
rlock=$work/rlock
rbar=$work/rbar
mkdir -p "$race"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$race" ZLYME_LOG_MARK="$rmark" \
	ZLYME_LOG_LOCK="$rlock" ZLYME_LOG_RACE="$rbar" "$LOGS" start &
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$race" ZLYME_LOG_MARK="$rmark" \
	ZLYME_LOG_LOCK="$rlock" ZLYME_LOG_RACE="$rbar" "$LOGS" start &
while [ ! -s "$rbar" ]; do
	sleep 0.02
done
sleep 0.2
[ "$(wc -l < "$rbar" | tr -d ' ')" = 1 ]
: > "$rbar.go"
wait
test -d "$race/system-0"
test ! -d "$race/system-1"

# A service tail is the last 64 KiB, not the whole file.
svc=$work/svc
mkdir -p "$svc"
dd if=/dev/zero bs=1024 count=128 of="$svc/input-late.log" 2>/dev/null
printf '%s\n' 'SERVICE-TAIL' >> "$svc/input-late.log"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$snap" ZLYME_LOG_MARK="$snapmark" \
	ZLYME_LOG_LOCK="$work/snap.lock" ZLYME_SERVICE_DIR="$svc" \
	ZLYME_SESSION_WRAP="$sess/wrap.log" ZLYME_SESSION_TEXT="$sess/text.txt" \
	"$LOGS" start
grep -q 'SERVICE-TAIL' "$snap/system-0/services/input-late.log"
_svcsz=$(wc -c < "$snap/system-0/services/input-late.log" | tr -d ' ')
[ "$_svcsz" -le 65536 ]

# A finished pak log over 1 MiB keeps its tail. The new launch has not
# opened it yet. An unrelated file in the log directory stays.
huge=$work/huge-root
mkdir -p "$huge/paks"
dd if=/dev/zero bs=1024 count=1100 of="$huge/paks/GBA.log" 2>/dev/null
printf '%s\n' 'KEEP-TAIL' >> "$huge/paks/GBA.log"
printf '%s\n' 'mine' > "$huge/paks/notes.txt"
sh -c '
	EMU_TAG=GBA EMU_EXE=core ROM= ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$1
	. "$2"
' sh "$huge" "$PAK"
grep -q 'KEEP-TAIL' "$huge/paks/GBA.log.1"
_hugesz=$(wc -c < "$huge/paks/GBA.log.1" | tr -d ' ')
[ "$_hugesz" -le 1048576 ]
grep -q 'mine' "$huge/paks/notes.txt"

# Boot seed copies session text that already exists, because logs were
# on before the session started. A plain start does not.
bootroot=$work/bootcap
bootmark=$work/boot-mark
bootsess=$work/boot-sess
mkdir -p "$bootsess"
printf '%s\n' 'BOOT-ON' > "$bootsess/wrap.log"
printf '%s\n' 'BOOT-T' > "$bootsess/text.txt"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$bootroot" ZLYME_LOG_MARK="$bootmark" \
	ZLYME_LOG_LOCK="$work/boot.lock" \
	ZLYME_SESSION_WRAP="$bootsess/wrap.log" ZLYME_SESSION_TEXT="$bootsess/text.txt" \
	"$LOGS" start boot
grep -q 'BOOT-ON' "$bootroot/system-0/session.txt"
grep -q 'BOOT-T' "$bootroot/system-0/next.txt"
printf '%s\n' 'BOOT-2' >> "$bootsess/wrap.log"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$bootroot" ZLYME_LOG_MARK="$bootmark" \
	ZLYME_LOG_LOCK="$work/boot.lock" \
	ZLYME_SESSION_WRAP="$bootsess/wrap.log" ZLYME_SESSION_TEXT="$bootsess/text.txt" \
	"$LOGS" start boot
grep -q 'BOOT-2' "$bootroot/system-0/session.txt"
test ! -d "$bootroot/system-1"

# A generation copy over the budget keeps its tail. The kernel snapshot
# we placed is not removed to make room.
gen=$work/gen
mkdir -p "$gen/system-0"
dd if=/dev/zero bs=1024 count=200 of="$gen/system-0/session.txt" 2>/dev/null
printf '%s\n' 'GEN-END' >> "$gen/system-0/session.txt"
printf '%s\n' 'DMESG' > "$gen/system-0/dmesg.txt"
: > "$work/gen-mark"
: > "$work/gen-mark.on"
printf '%s\n' 0 > "$work/gen-sess"
printf '%s\n' 0 > "$work/gen-sess"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$gen" ZLYME_LOG_MARK="$work/gen-mark" \
	ZLYME_LOG_LOCK="$work/gen.lock" ZLYME_LOG_GEN_MAX=100000 \
	ZLYME_SESSION_WRAP="$work/gen-sess" ZLYME_SESSION_TEXT="$work/gen-sess" \
	"$LOGS" start
grep -q 'GEN-END' "$gen/system-0/session.txt"
grep -q 'DMESG' "$gen/system-0/dmesg.txt"
_gensz=$(wc -c < "$gen/system-0/session.txt" | tr -d ' ')
[ "$_gensz" -le 100000 ]

# Owned history over the total drops the oldest generation and old pak
# generations. The current pak log, a user file, and a user directory stay.
agg=$work/agg
mkdir -p "$agg/system-4" "$agg/paks/OPENBOR" "$agg/userdir"
dd if=/dev/zero bs=1024 count=200 of="$agg/system-4/dmesg.txt" 2>/dev/null
dd if=/dev/zero bs=1024 count=200 of="$agg/paks/OLD.log.2" 2>/dev/null
printf '%s\n' 'LIVE' > "$agg/paks/LIVE.log"
printf '%s\n' 'NOTES' > "$agg/system-4/notes.txt"
printf '%s\n' 'USER' > "$agg/userdir/save"
printf '%s\n' 'SHOT' > "$agg/paks/OPENBOR/not-a-log-name"
: > "$work/agg-mark"
: > "$work/agg-mark.on"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$agg" ZLYME_LOG_MARK="$work/agg-mark" \
	ZLYME_LOG_LOCK="$work/agg.lock" ZLYME_LOG_TOTAL_MAX=150000 \
	ZLYME_SESSION_WRAP="$work/gen-sess" ZLYME_SESSION_TEXT="$work/gen-sess" \
	"$LOGS" start
test ! -f "$agg/system-4/dmesg.txt"
grep -q 'NOTES' "$agg/system-4/notes.txt"
test ! -f "$agg/paks/OLD.log.2"
grep -q 'LIVE' "$agg/paks/LIVE.log"
grep -q 'USER' "$agg/userdir/save"
grep -q 'SHOT' "$agg/paks/OPENBOR/not-a-log-name"

# Replacing a path does not redirect a descriptor that is already open.
# That is why a live log is not trimmed in place.
live=$work/livefile
printf '%s\n' 'OLD' > "$live"
sh -c 'exec 3>>"$1"; : > "$2"; sleep 0.3; printf LIVE\n >&3' sh "$live" "$work/live-ready" &
while [ ! -f "$work/live-ready" ]; do
	sleep 0.02
done
printf '%s\n' 'NEW' > "$live.next"
mv -f "$live.next" "$live"
wait
grep -q 'NEW' "$live"
grep -q 'LIVE' "$live" && exit 1

# An unwritable destination does not fail the caller.
bad=$work/bad
mkdir -p "$bad"
chmod 555 "$bad"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$bad" ZLYME_LOG_MARK="$work/bad-mark" \
	ZLYME_LOG_LOCK="$work/bad.lock" "$LOGS" start >/dev/null 2>&1
chmod 755 "$bad"

# OpenBOR trims a previous native log and leaves saves and screenshots.
ob=$work/ob
mkdir -p "$ob/bin" "$ob/saves" "$ob/state/ScreenShots" "$ob/logs/paks/OPENBOR" "$ob/bios"
cat > "$ob/bin/OpenBOR" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$ob/bin/OpenBOR"
dd if=/dev/zero bs=1024 count=1100 of="$ob/logs/paks/OPENBOR/OpenBOR.log" 2>/dev/null
printf '%s\n' 'OB-TAIL' >> "$ob/logs/paks/OPENBOR/OpenBOR.log"
printf '%s\n' 'SAVE' > "$ob/saves/slot"
printf '%s\n' 'SHOT' > "$ob/state/ScreenShots/a.png"
PATH="$ob/bin:$PATH" \
	USERDATA_PATH="$ob/state" SAVES_PATH="$ob/saves" BIOS_PATH="$ob/bios" \
	LOGS_PATH="$ob/logs/paks" ZLYME_PAK_LOG="$ob/logs/paks/OPENBOR.log" \
	"$ROOT/package/system/nextui/paks/Emus/OPENBOR.pak/launch.sh" "$ob/game.pak"
grep -q 'OB-TAIL' "$ob/logs/paks/OPENBOR/OpenBOR.log"
_obsz=$(wc -c < "$ob/logs/paks/OPENBOR/OpenBOR.log" | tr -d ' ')
[ "$_obsz" -le 1048576 ]
grep -q 'SAVE' "$ob/saves/slot"
grep -q 'SHOT' "$ob/state/ScreenShots/a.png"

# The session process is not pointed at the card log.
s28=$ROOT/board/my355/fsoverlay/etc/init.d/S28minui
# The seed asks for one boot capture. S28 does not call zlyme-logs.
grep -q 'zlyme-logs start boot' "$ROOT/board/my355/fsoverlay/etc/init.d/S15bootpart"
grep -q '/usr/sbin/zlyme-logs' "$s28" && exit 1
grep -q '! -e /boot/zlyme-logs' "$LOGS"
grep -q '/tmp/nextui-session.log' "$s28"
grep -q 'session.txt' "$s28" && exit 1
grep -q 'SESSION_LOG=/tmp/nextui-session.txt' \
	"$ROOT/package/system/nextui/nextui-session"
grep -F -q 'SESSION_LOG=$_cur/next.txt' \
	"$ROOT/package/system/nextui/nextui-session" && exit 1

# Turning logs off copies a Weston tail that still exists, then later
# bytes are not part of that copy.
wlog=$work/weston.log
dd if=/dev/zero bs=1024 count=80 of="$wlog" 2>/dev/null
printf '%s\n' 'WESTON-ON' >> "$wlog"
wroot=$work/weston-root
wmark=$work/weston-mark
mkdir -p "$wroot/system-0"
: > "$wmark"
: > "$wmark.on"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wroot" ZLYME_LOG_MARK="$wmark" \
	ZLYME_LOG_LOCK="$work/weston.lock" ZLYME_WESTON_LOG="$wlog" \
	"$LOGS" stop
grep -q 'WESTON-ON' "$wroot/system-0/services/weston.log"
_wsz=$(wc -c < "$wroot/system-0/services/weston.log" | tr -d ' ')
[ "$_wsz" -le 65536 ]
printf '%s\n' 'WESTON-OFF' >> "$wlog"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wroot" ZLYME_LOG_MARK="$wmark" \
	ZLYME_LOG_LOCK="$work/weston.lock" ZLYME_WESTON_LOG="$wlog" \
	ZLYME_SESSION_WRAP="$work/gen-sess" ZLYME_SESSION_TEXT="$work/gen-sess" \
	"$LOGS" start
grep -q 'WESTON-OFF' "$wroot/system-0/services/weston.log" && exit 1

# A later Weston run is a new file. Its bytes are copied from the
# start. A short run does not erase the previous capture.
printf '%s\n' 'RUN1-END' > "$wlog"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wroot" ZLYME_LOG_MARK="$wmark" \
	ZLYME_LOG_LOCK="$work/weston.lock" ZLYME_WESTON_LOG="$wlog" \
	"$LOGS" start
ZLYME_LOG_MARK="$wmark" ZLYME_LOG_LOCK="$work/weston.lock" \
	"$LOGS" weston-closed
printf '%s\n' 'RUN2-SHORT' > "$wlog"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wroot" ZLYME_LOG_MARK="$wmark" \
	ZLYME_LOG_LOCK="$work/weston.lock" ZLYME_WESTON_LOG="$wlog" \
	"$LOGS" start
grep -q 'RUN1-END' "$wroot/system-0/services/weston.log"
grep -q 'RUN2-SHORT' "$wroot/system-0/services/weston.log"

# want_logs is true before the lock and false once the lock is held.
# That start must not leave the capture flag set.
ctl=$work/bin
mkdir -p "$ctl"
cat > "$ctl/zlyme-ctl" << EOF
#!/bin/sh
[ "\${1:-}" = want ] && [ "\${2:-}" = logs ] || exit 1
n=0
[ -f "$work/ctl-count" ] && n=\$(cat "$work/ctl-count")
n=\$((n + 1))
printf '%s\n' "\$n" > "$work/ctl-count"
[ "\$n" -eq 1 ]
EOF
chmod 0755 "$ctl/zlyme-ctl"
gap=$work/gap
gapmark=$work/gap-mark
mkdir -p "$work/gap-sess"
printf '%s\n' 'OFF-GAP' > "$work/gap-sess/wrap.log"
PATH="$ctl:$PATH" ZLYME_LOG_ROOT="$gap" ZLYME_LOG_MARK="$gapmark" \
	ZLYME_LOG_LOCK="$work/gap.lock" \
	ZLYME_SESSION_WRAP="$work/gap-sess/wrap.log" \
	ZLYME_SESSION_TEXT="$work/gap-sess/wrap.log" \
	"$LOGS" start
test ! -f "$gapmark.on"
if [ -f "$gap/system-0/session.txt" ]; then
	grep -q 'OFF-GAP' "$gap/system-0/session.txt" && exit 1
fi

echo "log history ok"
