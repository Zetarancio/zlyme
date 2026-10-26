#!/bin/sh
# Phase 14 PortMaster validation: static guards plus dynamic integration.
# Proves command-substitution stalls under real shells, then exercises the
# format=4 validator with a mocked PORTS launcher and live processes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATE=$ROOT/scripts/device/phase14-portmaster-validate.sh
INVENTORY=$ROOT/scripts/device/phase14-portmaster-inventory.sh
SHELL_CACHE=${ZLYME_POSIX_SHELL_CACHE:-/tmp/zlyme-posix-shells}

fail() {
	echo "phase14 validate: $*" >&2
	exit 1
}

expect_fail() {
	label=$1
	shift
	if "$@" >/dev/null 2>&1; then
		fail "$label: expected failure"
	fi
}

[ -f "$VALIDATE" ] || fail "missing validate script"
grep -q 'exec "\$ports" "\$script"' "$VALIDATE" ||
	fail "validate does not exec canonical PORTS.pak"
if grep -q 'run_ports_like' "$VALIDATE"; then
	fail "validate still embeds a duplicated ports setup"
fi
if grep -E -q 'arm_timeout_waiter|start_post_observer|TIMER_PID|POST_OBSERVER_PID' \
	"$VALIDATE"; then
	fail "validate still contains in-session timer/observer helpers"
fi
if grep -q 'kill -TERM "\$waiter_pid"' "$VALIDATE"; then
	fail "validate still has bare waiter PID TERM"
fi
if grep -E -q '\$\((arm_|start_post)' "$VALIDATE"; then
	fail "validate still uses risky command substitution for helpers"
fi
grep -q 'claimer_starttime' "$VALIDATE" || fail "validate missing starttime identity"
grep -q 'require_completion_evidence' "$VALIDATE" ||
	fail "validate missing completion evidence gate"
grep -q 'format=4' "$VALIDATE" || fail "validate not format=4"
sh -n "$VALIDATE" || fail "validate syntax"
sh -n "$INVENTORY" || fail "inventory syntax"

# --- Real shell: command-substitution inherits background stdout and stalls. ---
cs_script=$(mktemp)
cat > "$cs_script" << 'BUG'
arm() {
	(
		sleep 2
		echo BG
	) &
	printf '%s\n' "$!"
}
start=$(date +%s)
pid=$(arm) >/dev/null
end=$(date +%s)
echo "$((end - start))"
BUG

run_cs_stall() {
	shell=$1
	label=$2
	out=$("$shell" "$cs_script") || fail "$label CS stall script failed"
	case "$out" in
		0) fail "$label did not stall on command-sub background (elapsed=$out)" ;;
		1|2|3) ;;
		*) fail "$label unexpected CS stall elapsed=$out" ;;
	esac
	echo "phase14 validate: $label CS-stall reproduced (${out}s)"
}

run_cs_stall bash bash

ensure_cached_shell() {
	name=$1
	url=$2
	dest=$SHELL_CACHE/$name
	if [ -x "$dest" ]; then
		return 0
	fi
	mkdir -p "$SHELL_CACHE"
	case "$name" in
	dash)
		pkg=$(mktemp)
		curl -fsSL -o "$pkg" "$url" || return 1
		tmpdir=$(mktemp -d)
		tar -I zstd -xf "$pkg" -C "$tmpdir" usr/bin/dash
		cp -f "$tmpdir/usr/bin/dash" "$dest"
		chmod 0755 "$dest"
		rm -rf "$tmpdir" "$pkg"
		;;
	busybox)
		curl -fsSL -o "$dest" "$url" || return 1
		chmod 0755 "$dest"
		;;
	*) return 1 ;;
	esac
	[ -x "$dest" ]
}

ASH_BIN=
if ensure_cached_shell dash \
	"https://archlinux.org/packages/core/x86_64/dash/download/"; then
	run_cs_stall "$SHELL_CACHE/dash" dash
else
	echo "phase14 validate: dash unavailable; bash stall still required" >&2
fi
if ensure_cached_shell busybox \
	"https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"; then
	ash_wrap=$(mktemp)
	cat > "$ash_wrap" << ASH
#!/bin/sh
exec "$SHELL_CACHE/busybox" ash "\$@"
ASH
	chmod 0755 "$ash_wrap"
	ASH_BIN=$ash_wrap
	run_cs_stall "$ash_wrap" busybox-ash
else
	echo "phase14 validate: busybox ash unavailable; bash stall still required" >&2
fi
rm -f "$cs_script"

# --- Campaign integration with mocked PORTS + inventory. ---
work=$(mktemp -d)
# shellcheck disable=SC2064
trap 'rm -rf "$work"; rm -f "'"${ASH_BIN:-}"'"' EXIT
export ZLYME_PHASE14_VALIDATE_DIR=$work/state
export ZLYME_PHASE14_TEST_GPU=libmali
export ZLYME_PHASE14_TEST_BOOT_ID=bootA
export ZLYME_PHASE14_TEST_SQUASHFS=sqA
export ZLYME_PHASE14_TEST_LIBRARIES=/storage
export ZLYME_PHASE14_TEST_NEXTUI=yes
export ZLYME_PHASE14_OWNED_MOUNTS=$work/owned-mounts
export ZLYME_PHASE14_DRM_CLIENTS=$work/drm-clients
export ZLYME_PHASE14_PAK_CLEANUP_FAILED=$work/pak-cleanup-failed
: > "$work/drm-clients"
rm -f "$work/owned-mounts" "$work/pak-cleanup-failed"

mkdir -p "$work/lib/Roms/Ports (PORTS)" "$work/bin"
good=$work/lib/Roms/Ports\ \(PORTS\)/Good\ Port.sh
printf '%s\n' '#!/bin/sh' 'echo game_ran >> "$GAME_LOG"' 'exit 0' > "$good"
chmod 0755 "$good"
second=$work/lib/Roms/Ports\ \(PORTS\)/Second\ Port.sh
printf '%s\n' '#!/bin/sh' 'echo second >> "$GAME_LOG"' 'exit 0' > "$second"
chmod 0755 "$second"

cat > "$work/bin/ports-launch.sh" << 'PORTS'
#!/bin/sh
set -eu
printf 'PORTS_ARGV\n' >> "$TRACE"
printf '%s\n' "$@" >> "$TRACE"
printf 'PORTS_START\n' >> "$TRACE"
if [ -n "${PORTS_HOLD_SECS:-}" ]; then
	sleep "$PORTS_HOLD_SECS"
fi
if [ -n "${1:-}" ] && [ -x "$1" ]; then
	"$1"
fi
printf 'PORTS_END\n' >> "$TRACE"
PORTS
chmod 0755 "$work/bin/ports-launch.sh"
export ZLYME_PORTS_LAUNCH=$work/bin/ports-launch.sh

stub_inv=$work/stub-inventory
cat > "$stub_inv" << STUB
#!/bin/sh
set -eu
out=\${1:-}
mkdir -p "\$out"
printf 'ELIGIBLE\tgood\t$good\n' > "\$out/queue.txt"
printf 'ELIGIBLE\tsecond\t$second\n' >> "\$out/queue.txt"
printf 'EXTERNAL_DATA_REQUIRED\tskaut\t/missing/skaut.sh\n' >> "\$out/queue.txt"
STUB
chmod 0755 "$stub_inv"
export ZLYME_PHASE14_INVENTORY=$stub_inv
export ZLYME_PHASE14_OBSERVER=/nonexistent-phase14-observer

export TRACE=$work/trace
export GAME_LOG=$work/game.log
: > "$TRACE"
: > "$GAME_LOG"

run_validate() {
	sh "$VALIDATE" "$@"
}

# Prefer BusyBox ash for lifecycle when available.
if [ -n "${ASH_BIN:-}" ]; then
	run_validate() {
		"$ASH_BIN" "$VALIDATE" "$@"
	}
	echo "phase14 validate: lifecycle under busybox ash"
fi

run_validate start >/dev/null
cid=$(cat "$work/state/active-campaign")
cdir=$work/state/campaigns/$cid
[ -s "$cdir/queue.txt" ] || fail "start did not write queue"
grep -q 'format=4' "$cdir/meta.txt" || fail "campaign meta not format=4"

# Same-second collision: pre-create the next candidate base is hard; instead
# force an existing directory and ensure start allocates a distinct id.
export ZLYME_PHASE14_TEST_BOOT_ID=bootA
# With unresolved empty, start a second campaign after reset.
# First prove start refuses while unresolved.
: > "$TRACE"
(
	PORTS_HOLD_SECS=8 run_validate run
) &
holder=$!
i=0
while [ "$i" -lt 80 ]; do
	[ -f "$cdir/active-run" ] && break
	i=$((i + 1))
	sleep 0.05 2>/dev/null || sleep 1
done
[ -f "$cdir/active-run" ] || fail "holder did not claim active-run"
# Prove the claimer identity is live before negative tests.
claimer=$(awk -F= '/^claimer_pid=/{print $2; exit}' "$cdir/active-run")
[ -d "/proc/$claimer" ] || fail "holder claimer pid $claimer not live"
cst=$(awk -F= '/^claimer_starttime=/{print $2; exit}' "$cdir/active-run")
[ -n "$cst" ] || fail "active-run missing claimer_starttime"

# complete while mocked PORTS is running must fail.
err=$(run_validate complete PASS_PROCESS 2>&1) && fail "complete while running: expected failure"
printf '%s\n' "$err" | grep -q 'still active' ||
	fail "complete while running did not cite live claimer: $err"
[ -f "$cdir/active-run" ] || fail "complete-while-running cleared active-run"
[ "$(cat "$cdir/cursor")" = 0 ] || fail "complete-while-running advanced cursor"

# retry while running must fail.
err=$(run_validate retry 2>&1) && fail "retry while running: expected failure"
printf '%s\n' "$err" | grep -q 'still active' ||
	fail "retry while running did not cite live claimer: $err"
[ -f "$cdir/active-run" ] || fail "retry-while-running cleared active-run"

# reset/start during unresolved must fail.
expect_fail "reset while unresolved" run_validate reset
expect_fail "start while unresolved" run_validate start

# Second runner cannot advance.
expect_fail "second run while in-flight" run_validate run
count=$(grep -c '^PORTS_ARGV$' "$TRACE" || true)
[ "$count" = 1 ] || fail "expected one PORTS invoke during hold, got $count"

wait "$holder" || true
[ ! -d "/proc/$holder" ] || sleep 1

# Claimer ended; observe + complete path.
export ZLYME_PHASE14_TEST_NEXTUI=yes
rm -f "$work/owned-mounts" "$work/pak-cleanup-failed"
run_validate observe 1 >/dev/null
run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
grep -q 'OBSERVE time=' "$run_log" || fail "observe did not append evidence"
grep -q 'NEXTUI_RESTORED process=yes' "$run_log" || fail "observe missing NextUI yes"
grep -q 'OWNED_MOUNTS_REMAIN none' "$run_log" || fail "observe missing mounts none"
grep -q 'PAK_CLEANUP_FAILED no' "$run_log" || fail "observe missing cleanup flag"

# Missing observer evidence prevents completion: wipe OBSERVE lines into a copy test.
# incomplete cleanup prevents completion.
printf '1\t/tmp/leak\n' > "$work/owned-mounts"
expect_fail "complete with mount leak" run_validate complete PASS_PROCESS
rm -f "$work/owned-mounts"

printf '125\n' > "$work/pak-cleanup-failed"
expect_fail "complete with pak cleanup 125" run_validate complete PASS_PROCESS
rm -f "$work/pak-cleanup-failed"

# blocked state must not be cleared by complete.
printf 'prior\n' > "$cdir/blocked"
expect_fail "complete while blocked" run_validate complete PASS_PROCESS
rm -f "$cdir/blocked"

# Missing observe: strip OBSERVE from log and refuse complete.
# Re-observe first to ensure clean, then test a fresh claim without observe.
run_validate complete PASS_PROCESS >/dev/null
[ ! -e "$cdir/active-run" ] || fail "complete left active-run"
[ "$(cat "$cdir/cursor")" = 1 ] || fail "complete did not advance cursor to 1"
completes=$(grep -h 'COMPLETE time=' "$cdir/runs/"*.log 2>/dev/null | wc -l | tr -d ' ')
[ "$completes" = 1 ] || fail "expected exactly one COMPLETE, got $completes"

# Second game: run, refuse complete without observe, then observe+complete.
: > "$TRACE"
: > "$GAME_LOG"
run_validate run
grep -Fq "$second" "$TRACE" || fail "second eligible was not selected"
expect_fail "complete without observe" run_validate complete PASS_PROCESS
[ -f "$cdir/active-run" ] || fail "complete-without-observe cleared active-run"
[ "$(cat "$cdir/cursor")" = 1 ] || fail "complete-without-observe advanced cursor"
run_validate observe 1 >/dev/null
run_validate complete PASS_PROCESS >/dev/null
[ "$(cat "$cdir/cursor")" = 2 ] || fail "second complete did not advance to 2"

# Interrupted / fail path: new campaign game then fail keeps identity.
run_validate reset >/dev/null
export ZLYME_PHASE14_TEST_BOOT_ID=bootA2
run_validate start >/dev/null
cid=$(cat "$work/state/active-campaign")
cdir=$work/state/campaigns/$cid
: > "$TRACE"
run_validate run
cur=$(cat "$cdir/cursor")
run_validate fail unresolved >/dev/null
[ -f "$cdir/active-run" ] || fail "fail cleared active-run"
[ -f "$cdir/blocked" ] || fail "fail did not set blocked"
[ "$(cat "$cdir/cursor")" = "$cur" ] || fail "fail advanced cursor"
id=$(awk -F= '/^id=/{print $2; exit}' "$cdir/active-run")
[ "$id" = good ] || fail "fail lost game identity ($id)"
run_validate retry >/dev/null
[ ! -e "$cdir/active-run" ] || fail "retry left active-run"
[ ! -e "$cdir/blocked" ] || fail "retry left blocked"
[ "$(cat "$cdir/cursor")" = "$cur" ] || fail "retry moved cursor"
# Retryable: same game launches again.
: > "$TRACE"
run_validate run
grep -Fq "$good" "$TRACE" || fail "retry did not relaunch same game"

# PID reuse / starttime mismatch: forge active-run with live pid, wrong starttime.
pid=$(awk -F= '/^claimer_pid=/{print $2; exit}' "$cdir/active-run")
# End the process first via retry after natural exit — already ended? Still in flight.
# Wait for natural exit of this quick game, then forge a live shell as claimer with bad starttime.
run_validate observe 1 >/dev/null
run_validate fail forge-setup >/dev/null
run_validate retry >/dev/null

# Start a hold run, then rewrite starttime to a wrong value while pid still live.
: > "$TRACE"
(
	PORTS_HOLD_SECS=4 run_validate run
) &
holder=$!
i=0
while [ "$i" -lt 80 ]; do
	[ -f "$cdir/active-run" ] && break
	i=$((i + 1))
	sleep 0.05 2>/dev/null || sleep 1
done
[ -f "$cdir/active-run" ] || fail "reuse-holder did not claim"
# Corrupt starttime → identity mismatch while pid live → refuse transitions.
awk '
	BEGIN { OFS=FS="=" }
	$1 == "claimer_starttime" { print "claimer_starttime=1"; next }
	{ print }
' "$cdir/active-run" > "$cdir/active-run.bad"
mv -f "$cdir/active-run.bad" "$cdir/active-run"
expect_fail "complete with starttime mismatch" run_validate complete PASS_PROCESS
expect_fail "retry with starttime mismatch" run_validate retry
# Restore real starttime so we can wait and clean up without killing (user forbids kill for pass).
# Read live starttime from /proc.
live_pid=$(awk -F= '/^claimer_pid=/{print $2; exit}' "$cdir/active-run")
line=$(cat "/proc/$live_pid/stat")
rest=${line#*)}
# shellcheck disable=SC2086
set -- $rest
live_st=${20}
awk -v st="$live_st" '
	BEGIN { FS=OFS="=" }
	$1 == "claimer_starttime" { print "claimer_starttime=" st; next }
	{ print }
' "$cdir/active-run" > "$cdir/active-run.fix"
mv -f "$cdir/active-run.fix" "$cdir/active-run"
wait "$holder" || true
run_validate observe 1 >/dev/null
run_validate fail cleanup-hold >/dev/null
run_validate retry >/dev/null

# Changed library identity invalidates the queue.
export ZLYME_PHASE14_TEST_LIBRARIES=/storage
run_validate start >/dev/null
cid=$(cat "$work/state/active-campaign")
cdir=$work/state/campaigns/$cid
export ZLYME_PHASE14_TEST_LIBRARIES=/mnt/sd2
expect_fail "run after library change" run_validate run

# Same-second campaign creation cannot overwrite reports.
export ZLYME_PHASE14_TEST_LIBRARIES=/storage
export ZLYME_PHASE14_TEST_BOOT_ID=bootSame
# Pre-create a colliding id pattern by starting once, then mkdir a forged sibling.
run_validate start >/dev/null
cid_a=$(cat "$work/state/active-campaign")
# Fabricate the exact next id the algorithm might pick is unnecessary:
# starting again after reset with a pre-existing directory of the new cid.
run_validate reset >/dev/null
# Create many possible collision dirs for this second: stamp-$$-gpu-boot
# Easier: create the directory that start will try: we cannot know $$ of the
# child, so create after capturing by racing — instead verify two starts keep both.
run_validate start >/dev/null
cid_b=$(cat "$work/state/active-campaign")
run_validate reset >/dev/null
run_validate start >/dev/null
cid_c=$(cat "$work/state/active-campaign")
[ -d "$work/state/campaigns/$cid_a" ] || fail "campaign A reports overwritten"
[ -d "$work/state/campaigns/$cid_b" ] || fail "campaign B reports overwritten"
[ -d "$work/state/campaigns/$cid_c" ] || fail "campaign C missing"
[ "$cid_b" != "$cid_c" ] || fail "sequential starts reused campaign id"
# Explicit overwrite guard: mkdir the id start is about to use by predicting
# from a wrapper is heavy; create a directory matching an existing campaign and
# ensure start still succeeds with a suffixed id when base exists.
base_prefix=$(date -u +%Y%m%dT%H%M%SZ)
# Force collision by creating campaigns/$base_prefix-*-libmali-* is awkward.
# Create the active campaign dir path that equals what a known $$ would use:
# Directly invoke the uniqueness loop by planting cid file.
plant=$work/state/campaigns/planted-collide
mkdir -p "$plant/runs"
# Not the same algorithm — instead plant using the next start's $$ via a shim:
cat > "$work/bin/start-collide.sh" << SH
#!/bin/sh
set -eu
VALIDATE=$VALIDATE
gpu=\${ZLYME_PHASE14_TEST_GPU}
bid=\$(printf '%s' "\${ZLYME_PHASE14_TEST_BOOT_ID}" | cut -c1-8)
stamp=\$(date -u +%Y%m%dT%H%M%SZ)
cid=\${stamp}-\$\$-\${gpu}-\${bid}
mkdir -p "\$ZLYME_PHASE14_VALIDATE_DIR/campaigns/\$cid/runs"
printf 'planted\\n' > "\$ZLYME_PHASE14_VALIDATE_DIR/campaigns/\$cid/meta.txt"
exec sh "\$VALIDATE" start
SH
chmod 0755 "$work/bin/start-collide.sh"
run_validate reset >/dev/null
export ZLYME_PHASE14_TEST_BOOT_ID=bootCollide
"$work/bin/start-collide.sh" >/dev/null
new=$(cat "$work/state/active-campaign")
[ -f "$work/state/campaigns/$new/meta.txt" ] || fail "colliding start lost meta"
grep -q 'format=4' "$work/state/campaigns/$new/meta.txt" ||
	fail "colliding start overwrote planted reports without new campaign"
planted_count=$(grep -rl '^planted$' "$work/state/campaigns" 2>/dev/null | wc -l | tr -d ' ')
[ "$planted_count" -ge 1 ] || fail "planted campaign reports were overwritten"
# New campaign must be distinct from the planted directory.
planted_id=$(grep -rl '^planted$' "$work/state/campaigns" | head -1 | awk -F/ '{print $(NF-1)}')
[ "$new" != "$planted_id" ] || fail "start reused planted campaign id"

# GPU campaigns remain separate.
export ZLYME_PHASE14_TEST_GPU=panfrost
export ZLYME_PHASE14_TEST_BOOT_ID=bootPan
run_validate reset >/dev/null
run_validate start >/dev/null
cid_p=$(cat "$work/state/active-campaign")
case "$cid_p" in
	*panfrost*) ;;
	*) fail "panfrost campaign id missing gpu tag: $cid_p" ;;
esac

# No leftover watchdog/helper.
# shellcheck disable=SC2009
if ps -eo args= 2>/dev/null | grep -F "$work/state" | grep -E 'sleep 180|arm_timeout|post_observer' >/dev/null; then
	fail "leftover watchdog/helper still running"
fi

echo "phase14 validate ok"
