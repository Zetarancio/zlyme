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
grep -q 'ZLYME_BOOT_WRITE:-/usr/sbin/zlyme-boot-write' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl"
grep -F -q '"$writer" touch "$flag"' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl"
grep -q 'zlyme-boot-write' "$LOGS" && exit 1
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

# A failed tail leaves the saved Weston copy and does not advance the
# cursor. The next successful copy can still save the new bytes.
realtail=$(command -v tail)
mkdir -p "$work/tailbin"
cat > "$work/tailbin/tail" << EOF
#!/bin/sh
if [ "\${ZLYME_TAIL_FAIL:-}" = 1 ]; then
	exit 1
fi
exec $realtail "\$@"
EOF
chmod 0755 "$work/tailbin/tail"
failroot=$work/fail-weston
failmark=$work/fail-mark
mkdir -p "$failroot/system-0/services"
printf '%s\n' 'KEEP-WESTON' > "$failroot/system-0/services/weston.log"
printf '%s\n' 'NEW-WESTON' > "$wlog"
: > "$failmark"
: > "$failmark.on"
ZLYME_TAIL_FAIL=1 PATH="$work/tailbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$failroot" ZLYME_LOG_MARK="$failmark" \
	ZLYME_LOG_LOCK="$work/fail.lock" ZLYME_WESTON_LOG="$wlog" \
	"$LOGS" start
grep -q 'KEEP-WESTON' "$failroot/system-0/services/weston.log"
test ! -f "$failmark.weston"
PATH="$work/tailbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$failroot" ZLYME_LOG_MARK="$failmark" \
	ZLYME_LOG_LOCK="$work/fail.lock" ZLYME_WESTON_LOG="$wlog" \
	"$LOGS" start
grep -q 'KEEP-WESTON' "$failroot/system-0/services/weston.log"
grep -q 'NEW-WESTON' "$failroot/system-0/services/weston.log"

# Text already in a service file when logs turn on is not copied.
offsvc=$work/offsvc
mkdir -p "$offsvc"
printf '%s\n' 'OFF-SVC' > "$offsvc/input-late.log"
osroot=$work/offsvc-root
osmark=$work/offsvc-mark
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$osroot" ZLYME_LOG_MARK="$osmark" \
	ZLYME_LOG_LOCK="$work/offsvc.lock" ZLYME_SERVICE_DIR="$offsvc" \
	"$LOGS" start
if [ -f "$osroot/system-0/services/input-late.log" ]; then
	grep -q 'OFF-SVC' "$osroot/system-0/services/input-late.log" && exit 1
fi
printf '%s\n' 'ON-SVC' >> "$offsvc/input-late.log"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$osroot" ZLYME_LOG_MARK="$osmark" \
	ZLYME_LOG_LOCK="$work/offsvc.lock" ZLYME_SERVICE_DIR="$offsvc" \
	"$LOGS" start
grep -q 'ON-SVC' "$osroot/system-0/services/input-late.log"
grep -q 'OFF-SVC' "$osroot/system-0/services/input-late.log" && exit 1

# A failed size read does not rewind the session cursor.
realwc=$(command -v wc)
mkdir -p "$work/wcbin"
cat > "$work/wcbin/wc" << EOF
#!/bin/sh
if [ "\${ZLYME_WC_FAIL:-}" = 1 ]; then
	exit 1
fi
if [ "\${ZLYME_WC_FAIL_LARGE:-}" = 1 ]; then
	_wctmp=\$(mktemp)
	cat > "\$_wctmp"
	_wcn=\$($realwc -c < "\$_wctmp" | tr -d ' ')
	rm -f "\$_wctmp"
	if [ "\$_wcn" -gt 65536 ]; then
		exit 1
	fi
	printf '%s\n' "\$_wcn"
	exit 0
fi
exec $realwc "\$@"
EOF
chmod 0755 "$work/wcbin/wc"
wcroot=$work/wc-root
wcmark=$work/wc-mark
wcsess=$work/wc-sess
mkdir -p "$wcroot/system-0" "$wcsess"
printf '%s\n' 'ON-A' > "$wcsess/wrap.log"
wclen=$(wc -c < "$wcsess/wrap.log" | tr -d ' ')
printf '%s\n' "$wclen" > "$wcmark.wrap"
cp "$wcsess/wrap.log" "$wcroot/system-0/session.txt"
: > "$wcmark"
: > "$wcmark.on"
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wcroot" ZLYME_LOG_MARK="$wcmark" \
	ZLYME_LOG_LOCK="$work/wc.lock" \
	ZLYME_SESSION_WRAP="$wcsess/wrap.log" ZLYME_SESSION_TEXT="$wcsess/wrap.log" \
	"$LOGS" start
[ "$(tr -d ' \n' < "$wcmark.wrap")" = "$wclen" ]
[ "$(grep -c 'ON-A' "$wcroot/system-0/session.txt")" = 1 ]

# Enable cannot watermark while wc fails. The next success records the
# size and still does not copy the earlier text.
notesrc=$work/note-src
mkdir -p "$notesrc"
printf '%s\n' 'OFF-NOTE' > "$notesrc/input-late.log"
nroot=$work/note-root
nmark=$work/note-mark
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$nroot" ZLYME_LOG_MARK="$nmark" \
	ZLYME_LOG_LOCK="$work/note.lock" ZLYME_SERVICE_DIR="$notesrc" \
	"$LOGS" start
test -f "$nmark.svc.input-late.log.unread"
if [ -f "$nroot/system-0/services/input-late.log" ]; then
	grep -q 'OFF-NOTE' "$nroot/system-0/services/input-late.log" && exit 1
fi
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$nroot" ZLYME_LOG_MARK="$nmark" \
	ZLYME_LOG_LOCK="$work/note.lock" ZLYME_SERVICE_DIR="$notesrc" \
	"$LOGS" start
if [ -f "$nroot/system-0/services/input-late.log" ]; then
	grep -q 'OFF-NOTE' "$nroot/system-0/services/input-late.log" && exit 1
fi
test ! -f "$nmark.svc.input-late.log.unread"
printf '%s\n' 'ON-NOTE' >> "$notesrc/input-late.log"
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$nroot" ZLYME_LOG_MARK="$nmark" \
	ZLYME_LOG_LOCK="$work/note.lock" ZLYME_SERVICE_DIR="$notesrc" \
	"$LOGS" start
grep -q 'ON-NOTE' "$nroot/system-0/services/input-late.log"
grep -q 'OFF-NOTE' "$nroot/system-0/services/input-late.log" && exit 1

# A failed size read during a service copy does not take the new bytes
# and does not move the cursor. The following success copies only those
# new bytes.
capsrc=$work/cap-src
mkdir -p "$capsrc"
printf '%s\n' 'BASE' > "$capsrc/led.log"
croot=$work/cap-root
cmark=$work/cap-mark
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$croot" ZLYME_LOG_MARK="$cmark" \
	ZLYME_LOG_LOCK="$work/cap.lock" ZLYME_SERVICE_DIR="$capsrc" \
	"$LOGS" start
clen=$(wc -c < "$capsrc/led.log" | tr -d ' ')
printf '%s\n' 'NEW-SVC' >> "$capsrc/led.log"
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$croot" ZLYME_LOG_MARK="$cmark" \
	ZLYME_LOG_LOCK="$work/cap.lock" ZLYME_SERVICE_DIR="$capsrc" \
	"$LOGS" start
[ "$(tr -d ' \n' < "$cmark.svc.led.log")" = "$clen" ]
if [ -f "$croot/system-0/services/led.log" ]; then
	grep -q 'NEW-SVC' "$croot/system-0/services/led.log" && exit 1
	grep -q 'BASE' "$croot/system-0/services/led.log" && exit 1
fi
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$croot" ZLYME_LOG_MARK="$cmark" \
	ZLYME_LOG_LOCK="$work/cap.lock" ZLYME_SERVICE_DIR="$capsrc" \
	"$LOGS" start
grep -q 'NEW-SVC' "$croot/system-0/services/led.log"
grep -q 'BASE' "$croot/system-0/services/led.log" && exit 1

# The same failed read on a Weston file leaves the saved tail and cursor.
wfail=$work/wfail.log
printf '%s\n' 'WBASE' > "$wfail"
wfroot=$work/wfail-root
wfmark=$work/wfail-mark
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wfroot" ZLYME_LOG_MARK="$wfmark" \
	ZLYME_LOG_LOCK="$work/wfail.lock" ZLYME_WESTON_LOG="$wfail" \
	"$LOGS" start
wlen=$(wc -c < "$wfail" | tr -d ' ')
printf '%s\n' 'WNEW' >> "$wfail"
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wfroot" ZLYME_LOG_MARK="$wfmark" \
	ZLYME_LOG_LOCK="$work/wfail.lock" ZLYME_WESTON_LOG="$wfail" \
	"$LOGS" start
[ "$(tr -d ' \n' < "$wfmark.weston")" = "$wlen" ]
if [ -f "$wfroot/system-0/services/weston.log" ]; then
	grep -q 'WNEW' "$wfroot/system-0/services/weston.log" && exit 1
fi
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wfroot" ZLYME_LOG_MARK="$wfmark" \
	ZLYME_LOG_LOCK="$work/wfail.lock" ZLYME_WESTON_LOG="$wfail" \
	"$LOGS" start
grep -q 'WNEW' "$wfroot/system-0/services/weston.log"
grep -q 'WBASE' "$wfroot/system-0/services/weston.log" && exit 1

# The 64 KiB decision does not install a combined file when its size
# cannot be read. The earlier saved bytes stay.
big=$work/big-src
mkdir -p "$big"
printf '%s\n' 'BBASE' > "$big/storage.log"
broot=$work/big-root
bmark=$work/big-mark
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/big.lock" ZLYME_SERVICE_DIR="$big" \
	"$LOGS" start
mkdir -p "$broot/system-0/services"
printf '%s\n' 'KEEP-HEAD' > "$broot/system-0/services/storage.log"
dd if=/dev/zero bs=1024 count=70 >> "$broot/system-0/services/storage.log" 2>/dev/null
printf '%s\n' 'BIG-NEW' >> "$big/storage.log"
ZLYME_WC_FAIL_LARGE=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/big.lock" ZLYME_SERVICE_DIR="$big" \
	"$LOGS" start
grep -q 'KEEP-HEAD' "$broot/system-0/services/storage.log"
grep -q 'BIG-NEW' "$broot/system-0/services/storage.log" && exit 1
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/big.lock" ZLYME_SERVICE_DIR="$big" \
	"$LOGS" start
grep -q 'BIG-NEW' "$broot/system-0/services/storage.log"
_bigsz=$(wc -c < "$broot/system-0/services/storage.log" | tr -d ' ')
[ "$_bigsz" -le 65536 ]

# Without flock, start does not rotate a generation.
nf=$work/nof
mkdir -p "$nf"
for _cmd in mkdir wc tail cat mv mktemp basename dirname chmod sleep date cp rm tr grep; do
	ln -s "$(command -v "$_cmd")" "$nf/$_cmd"
done
unset _cmd
nfroot=$work/nof-root
nfmark=$work/nof-mark
PATH="$nf" ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$nfroot" ZLYME_LOG_MARK="$nfmark" \
	ZLYME_LOG_LOCK="$work/nof.lock" \
	"$LOGS" start
test ! -d "$nfroot/system-0"
test ! -f "$nfmark"

realflock=$(command -v flock)
mkdir -p "$work/flockbin"
cat > "$work/flockbin/flock" << EOF
#!/bin/sh
if [ "\${ZLYME_FLOCK_FAIL:-}" = 1 ]; then
	exit 1
fi
exec $realflock "\$@"
EOF
chmod 0755 "$work/flockbin/flock"

# Both session files: a failed enable watermark does not copy OFF.
# The next success records the size. Text written after that is copied.
both=$work/both-sess
mkdir -p "$both"
printf '%s\n' 'OFF-WRAP' > "$both/wrap.log"
printf '%s\n' 'OFF-TEXT' > "$both/text.txt"
broot=$work/both-root
bmark=$work/both-mark
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/both.lock" \
	ZLYME_SESSION_WRAP="$both/wrap.log" ZLYME_SESSION_TEXT="$both/text.txt" \
	"$LOGS" start
test -f "$bmark.wrap.unread"
test -f "$bmark.text.unread"
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/both.lock" \
	ZLYME_SESSION_WRAP="$both/wrap.log" ZLYME_SESSION_TEXT="$both/text.txt" \
	"$LOGS" start
test ! -f "$bmark.wrap.unread"
test ! -f "$bmark.text.unread"
if [ -f "$broot/system-0/session.txt" ]; then
	grep -q 'OFF-WRAP' "$broot/system-0/session.txt" && exit 1
fi
if [ -f "$broot/system-0/next.txt" ]; then
	grep -q 'OFF-TEXT' "$broot/system-0/next.txt" && exit 1
fi
printf '%s\n' 'ON-WRAP' >> "$both/wrap.log"
printf '%s\n' 'ON-TEXT' >> "$both/text.txt"
PATH="$work/wcbin:$PATH" \
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$broot" ZLYME_LOG_MARK="$bmark" \
	ZLYME_LOG_LOCK="$work/both.lock" \
	ZLYME_SESSION_WRAP="$both/wrap.log" ZLYME_SESSION_TEXT="$both/text.txt" \
	"$LOGS" start
grep -q 'ON-WRAP' "$broot/system-0/session.txt"
grep -q 'ON-TEXT' "$broot/system-0/next.txt"
grep -q 'OFF-WRAP' "$broot/system-0/session.txt" && exit 1
grep -q 'OFF-TEXT' "$broot/system-0/next.txt" && exit 1
test ! -d "$broot/system-1"

# A cursor from an earlier on-interval is not a license to copy the
# off gap after a failed re-enable watermark.
prior=$work/prior-sess
mkdir -p "$prior"
: > "$prior/wrap.log"
proot=$work/prior-root
pmark=$work/prior-mark
penv() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$proot" ZLYME_LOG_MARK="$pmark" \
		ZLYME_LOG_LOCK="$work/prior.lock" \
		ZLYME_SESSION_WRAP="$prior/wrap.log" ZLYME_SESSION_TEXT="$prior/wrap.log" \
		"$@"
}
penv "$LOGS" start
printf '%s\n' 'ON-A' >> "$prior/wrap.log"
penv "$LOGS" start
grep -q 'ON-A' "$proot/system-0/session.txt"
penv "$LOGS" stop
printf '%s\n' 'OFF-GAP' >> "$prior/wrap.log"
ZLYME_WC_FAIL=1 PATH="$work/wcbin:$PATH" penv "$LOGS" start
PATH="$work/wcbin:$PATH" penv "$LOGS" start
grep -q 'ON-A' "$proot/system-0/session.txt"
[ "$(grep -c 'ON-A' "$proot/system-0/session.txt")" = 1 ]
grep -q 'OFF-GAP' "$proot/system-0/session.txt" && exit 1
printf '%s\n' 'ON-B' >> "$prior/wrap.log"
PATH="$work/wcbin:$PATH" penv "$LOGS" start
grep -q 'ON-B' "$proot/system-0/session.txt"
grep -q 'OFF-GAP' "$proot/system-0/session.txt" && exit 1
test ! -d "$proot/system-1"

# A stop that cannot lock does not leave the old interval open.
lost=$work/lost-sess
mkdir -p "$lost"
: > "$lost/wrap.log"
lroot=$work/lost-root
lmark=$work/lost-mark
lenv() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$lroot" ZLYME_LOG_MARK="$lmark" \
		ZLYME_LOG_LOCK="$work/lost.lock" \
		ZLYME_SESSION_WRAP="$lost/wrap.log" ZLYME_SESSION_TEXT="$lost/wrap.log" \
		"$@"
}
lenv "$LOGS" start
printf '%s\n' 'ON-A' >> "$lost/wrap.log"
lenv "$LOGS" start
grep -q 'ON-A' "$lroot/system-0/session.txt"
ZLYME_FLOCK_FAIL=1 PATH="$work/flockbin:$PATH" lenv "$LOGS" stop
test -f "$lmark.incomplete"
test -f "$lmark.on"
printf '%s\n' 'OFF' >> "$lost/wrap.log"
PATH="$work/flockbin:$PATH" lenv "$LOGS" start
grep -q 'ON-A' "$lroot/system-0/session.txt"
grep -q 'OFF' "$lroot/system-0/session.txt" && exit 1
test ! -f "$lmark.incomplete"
printf '%s\n' 'ON-B' >> "$lost/wrap.log"
PATH="$work/flockbin:$PATH" lenv "$LOGS" start
grep -q 'ON-B' "$lroot/system-0/session.txt"
grep -q 'OFF' "$lroot/system-0/session.txt" && exit 1
[ "$(grep -c 'ON-A' "$lroot/system-0/session.txt")" = 1 ]
test ! -d "$lroot/system-1"

# weston-closed could not drop the cursor. The next log is not read
# from that old offset, and the first run stays saved.
w1=$work/wseq.log
: > "$w1"
wroot=$work/wseq-root
wmark=$work/wseq-mark
wenv() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$wroot" ZLYME_LOG_MARK="$wmark" \
		ZLYME_LOG_LOCK="$work/wseq.lock" ZLYME_WESTON_LOG="$w1" \
		"$@"
}
wenv "$LOGS" start
printf '%s\n' 'RUN1-END' > "$w1"
wenv "$LOGS" start
grep -q 'RUN1-END' "$wroot/system-0/services/weston.log"
rm -f "$w1"
ZLYME_FLOCK_FAIL=1 PATH="$work/flockbin:$PATH" wenv "$LOGS" weston-closed
test -f "$wmark.weston.stale"
printf '%s\n' 'RUN2-BEGIN extra' > "$w1"
PATH="$work/flockbin:$PATH" wenv "$LOGS" start
grep -q 'RUN1-END' "$wroot/system-0/services/weston.log"
grep -q 'RUN2-BEGIN' "$wroot/system-0/services/weston.log"
test ! -f "$wmark.weston.stale"

# Failed weston-closed, then logs off, then logs on over a file that
# already contains OFF-WESTON. The new watermark must win.
w2=$work/wgap.log
: > "$w2"
groot=$work/wgap-root
gmark=$work/wgap-mark
genv() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$groot" ZLYME_LOG_MARK="$gmark" \
		ZLYME_LOG_LOCK="$work/wgap.lock" ZLYME_WESTON_LOG="$w2" \
		"$@"
}
genv "$LOGS" start
printf '%s\n' 'RUN1-END' > "$w2"
genv "$LOGS" start
grep -q 'RUN1-END' "$groot/system-0/services/weston.log"
rm -f "$w2"
ZLYME_FLOCK_FAIL=1 PATH="$work/flockbin:$PATH" genv "$LOGS" weston-closed
test -f "$gmark.weston.stale"
genv "$LOGS" stop
printf '%s\n' 'OFF-WESTON' > "$w2"
genv "$LOGS" start
genv "$LOGS" start
grep -q 'OFF-WESTON' "$groot/system-0/services/weston.log" && exit 1
grep -q 'RUN1-END' "$groot/system-0/services/weston.log"
printf '%s\n' 'ON-WESTON' >> "$w2"
genv "$LOGS" start
grep -q 'ON-WESTON' "$groot/system-0/services/weston.log"
grep -q 'OFF-WESTON' "$groot/system-0/services/weston.log" && exit 1
test ! -d "$groot/system-1"

# A normal stop still ends the interval, and a normal weston-closed
# still drops the cursor.
ok=$work/ok-sess
mkdir -p "$ok"
: > "$ok/wrap.log"
oroot=$work/ok-root
omark=$work/ok-mark
oenv() {
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$oroot" ZLYME_LOG_MARK="$omark" \
		ZLYME_LOG_LOCK="$work/ok.lock" \
		ZLYME_SESSION_WRAP="$ok/wrap.log" ZLYME_SESSION_TEXT="$ok/wrap.log" \
		ZLYME_WESTON_LOG="$work/ok-weston.log" \
		"$@"
}
: > "$work/ok-weston.log"
oenv "$LOGS" start
printf '%s\n' 'OK-ON' >> "$ok/wrap.log"
printf '%s\n' 'OK-W' > "$work/ok-weston.log"
oenv "$LOGS" start
grep -q 'OK-ON' "$oroot/system-0/session.txt"
grep -q 'OK-W' "$oroot/system-0/services/weston.log"
oenv "$LOGS" stop
printf '%s\n' 'OK-OFF' >> "$ok/wrap.log"
oenv "$LOGS" start
grep -q 'OK-OFF' "$oroot/system-0/session.txt" && exit 1
rm -f "$work/ok-weston.log"
oenv "$LOGS" weston-closed
test ! -f "$omark.weston"
test ! -f "$omark.weston.stale"
printf '%s\n' 'OK-W2' > "$work/ok-weston.log"
oenv "$LOGS" start
grep -q 'OK-W2' "$oroot/system-0/services/weston.log"

echo "log history ok"
