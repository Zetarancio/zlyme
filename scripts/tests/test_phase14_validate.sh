#!/bin/sh
# Phase 14 PortMaster validation: static guards plus dynamic integration.
# Proves command-substitution stalls under real shells, then exercises the
# rewritten validator with a mocked PORTS launcher (no device required).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATE=$ROOT/scripts/device/phase14-portmaster-validate.sh
INVENTORY=$ROOT/scripts/device/phase14-portmaster-inventory.sh
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
PROBE=$ROOT/scripts/device/phase14-probe-paks.sh
SHELL_CACHE=${ZLYME_POSIX_SHELL_CACHE:-/tmp/zlyme-posix-shells}

fail() {
	echo "phase14 validate: $*" >&2
	exit 1
}

[ -f "$VALIDATE" ] || fail "missing validate script"
grep -q 'Validation.pak/launch.sh' "$LAUNCH" ||
	fail "pak-launch does not classify the validation Tools PAK as ports"
grep -q 'exec "\$ports" "\$script"' "$VALIDATE" ||
	fail "validate does not exec canonical PORTS.pak"
if grep -q 'run_ports_like' "$VALIDATE"; then
	fail "validate still embeds a duplicated ports setup"
fi
# Forbidden lifecycle hazards.
if grep -E -q 'arm_timeout_waiter|start_post_observer|TIMER_PID|POST_OBSERVER_PID' \
	"$VALIDATE"; then
	fail "validate still contains in-session timer/observer helpers"
fi
if grep -F 'kill -TERM' "$VALIDATE" | grep -q waiter; then
	fail "validate still delayed-kills a saved waiter PID"
fi
if grep -q 'kill -TERM "\$waiter_pid"' "$VALIDATE"; then
	fail "validate still has bare waiter PID TERM"
fi
# No command-sub that starts background helpers.
if grep -E -q '\$\((arm_|start_post)' "$VALIDATE"; then
	fail "validate still uses risky command substitution for helpers"
fi
grep -q 'active-run' "$VALIDATE" || fail "validate has no active-run transaction"
grep -q 'cmd_observe' "$VALIDATE" || fail "validate has no SSH observe command"
grep -q 'install_pm_validation' "$PROBE" ||
	fail "probe-paks does not install the ports-exec validation entry"
sh -n "$VALIDATE" || fail "validate syntax"
sh -n "$INVENTORY" || fail "inventory syntax"
sh -n "$PROBE" || fail "probe-paks syntax"

# --- Real shell: command-substitution inherits background stdout and stalls. ---
cs_script=$(mktemp)
cat > "$cs_script" << 'BUG'
arm() {
	(
		sleep 2
		# Intentionally write to inherited stdout so $(arm) waits.
		echo BG
	) &
	printf '%s\n' "$!"
}
start=$(date +%s)
# Discard captured text; we only care about wall time.
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

if ensure_cached_shell dash \
	"https://archlinux.org/packages/core/x86_64/dash/download/"; then
	run_cs_stall "$SHELL_CACHE/dash" dash
else
	echo "phase14 validate: dash unavailable; bash stall still required" >&2
fi
if ensure_cached_shell busybox \
	"https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"; then
	# BusyBox ash via applet name.
	ash_wrap=$(mktemp)
	cat > "$ash_wrap" << ASH
#!/bin/sh
exec "$SHELL_CACHE/busybox" ash "\$@"
ASH
	chmod 0755 "$ash_wrap"
	run_cs_stall "$ash_wrap" busybox-ash
	rm -f "$ash_wrap"
else
	echo "phase14 validate: busybox ash unavailable; bash stall still required" >&2
fi
rm -f "$cs_script"

# Fixed shape: no $(background). Must reach PORTS marker immediately.
fix_mark=$(mktemp)
fix_ports=$(mktemp)
cat > "$fix_ports" << 'OK'
#!/bin/sh
set -eu
printf 'REACHED\n' > "$1"
printf '%s\n' "$@" > "$1.argv"
OK
chmod 0755 "$fix_ports"
start=$(date +%s)
# Mimic cmd_run's final step: plain exec, no command-sub helpers.
"$fix_ports" "$fix_mark" /fake/Good.sh
end=$(date +%s)
[ "$((end - start))" -lt 1 ] || fail "fixed launch path was not prompt"
grep -q REACHED "$fix_mark" || fail "fixed launch did not reach PORTS"
rm -f "$fix_mark" "$fix_mark.argv" "$fix_ports"

# --- Campaign integration with mocked PORTS + inventory. ---
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_PHASE14_VALIDATE_DIR=$work/state
export ZLYME_PHASE14_TEST_GPU=libmali
export ZLYME_PHASE14_TEST_BOOT_ID=bootA
export ZLYME_PHASE14_TEST_SQUASHFS=sqA

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
# Force SSH-side observe path (no in-tree observer binary required).
export ZLYME_PHASE14_OBSERVER=/nonexistent-phase14-observer

export TRACE=$work/trace
export GAME_LOG=$work/game.log
: > "$TRACE"
: > "$GAME_LOG"

sh "$VALIDATE" start >/dev/null
cid=$(cat "$work/state/active-campaign")
cdir=$work/state/campaigns/$cid
[ -s "$cdir/queue.txt" ] || fail "start did not write queue"

# Prompt launch under the real validator (exec into mock PORTS).
start=$(date +%s%N 2>/dev/null || date +%s)
sh "$VALIDATE" run
end=$(date +%s%N 2>/dev/null || date +%s)
case "$start$end" in
*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
	elapsed_ms=$(( (end - start) / 1000000 ))
	[ "$elapsed_ms" -lt 500 ] || fail "launch not prompt: ${elapsed_ms}ms"
	;;
*)
	elapsed=$((end - start))
	[ "$elapsed" -lt 2 ] || fail "launch not prompt: ${elapsed}s"
	;;
esac

grep -q '^PORTS_ARGV$' "$TRACE" || fail "PORTS launcher was not invoked"
grep -Fq "$good" "$TRACE" || fail "selected game was not the first eligible"
grep -q game_ran "$GAME_LOG" || fail "selected game script did not run"
[ -f "$cdir/active-run" ] || fail "active-run missing after run"
grep -q 'status=in_flight' "$cdir/active-run" || fail "active-run not in_flight"
[ -d "$cdir/lock" ] || fail "lock not held across run claim"
[ "$(cat "$cdir/cursor")" = 0 ] || fail "cursor advanced before complete"

# Second runner must not advance while active-run is set.
if sh "$VALIDATE" run >/dev/null 2>&1; then
	fail "second run was allowed during active-run"
fi
count=$(grep -c '^PORTS_ARGV$' "$TRACE" || true)
[ "$count" = 1 ] || fail "expected one PORTS invoke, got $count"

# Concurrent exclusivity while a held launch is still "running".
: > "$TRACE"
PORTS_HOLD_SECS=2 sh "$VALIDATE" retry >/dev/null
(
	PORTS_HOLD_SECS=2 sh "$VALIDATE" run
) &
holder=$!
# Give the holder time to claim and enter sleep.
i=0
while [ "$i" -lt 50 ]; do
	[ -f "$cdir/active-run" ] && break
	i=$((i + 1))
	# BusyBox-friendly short wait.
	sleep 0.05 2>/dev/null || sleep 1
done
[ -f "$cdir/active-run" ] || fail "holder did not claim active-run"
if sh "$VALIDATE" run >/dev/null 2>&1; then
	kill "$holder" 2>/dev/null || true
	wait "$holder" 2>/dev/null || true
	fail "second run advanced queue during in-flight hold"
fi
wait "$holder" || true
count=$(grep -c '^PORTS_ARGV$' "$TRACE" || true)
[ "$count" = 1 ] || fail "hold test expected one PORTS invoke, got $count"

# SSH-side observe after the PAK process has exited.
sh "$VALIDATE" observe 1 >/dev/null
run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
[ -n "$run_log" ] || fail "active-run missing run_log"
grep -q 'OBSERVE time=' "$run_log" || fail "observe did not append evidence"
grep -q 'NEXTUI_RESTORED' "$run_log" || fail "observe missing NextUI field"
grep -q 'OWNED_MOUNTS_REMAIN' "$run_log" || fail "observe missing mount field"
# Observe must work with no live PAK claimer.
claimer=$(awk -F= '/^claimer_pid=/{print $2; exit}' "$cdir/active-run")
if [ -n "$claimer" ] && [ -d "/proc/$claimer" ]; then
	fail "claimer still alive after PORTS exit; observe must be post-session"
fi

# complete advances cursor and clears claim/lock.
sh "$VALIDATE" complete PASS_PROCESS >/dev/null
[ ! -e "$cdir/active-run" ] || fail "complete left active-run"
[ ! -d "$cdir/lock" ] || fail "complete left lock"
[ "$(cat "$cdir/cursor")" = 1 ] || fail "complete did not advance cursor to 1"
grep -q 'COMPLETE time=' "$run_log" || fail "complete did not log"

# Next run claims exactly the second eligible game.
: > "$TRACE"
: > "$GAME_LOG"
sh "$VALIDATE" run
grep -Fq "$second" "$TRACE" || fail "second eligible was not selected"
grep -q second "$GAME_LOG" || fail "second game script did not run"
count=$(grep -c '^PORTS_ARGV$' "$TRACE" || true)
[ "$count" = 1 ] || fail "second run invoked PORTS $count times"

# fail does not advance; keeps identity for retry.
cur=$(cat "$cdir/cursor")
sh "$VALIDATE" fail unresolved >/dev/null
[ -f "$cdir/active-run" ] || fail "fail cleared active-run"
[ -f "$cdir/blocked" ] || fail "fail did not set blocked"
[ "$(cat "$cdir/cursor")" = "$cur" ] || fail "fail advanced cursor"
# Interrupted/failed must not become PASS by silence.
completes=$(grep -h 'COMPLETE time=' "$cdir/runs/"*.log 2>/dev/null | wc -l | tr -d ' ')
[ "$completes" = 1 ] || fail "unexpected COMPLETE count $completes"
if grep -h 'COMPLETE time=' "$cdir/runs/"*.log 2>/dev/null | grep -q second; then
	fail "failed second run was marked COMPLETE"
fi
if grep -q 'result=PASS' "$cdir/runs/"*second* 2>/dev/null; then
	fail "failed second run was marked PASS"
fi

# retry clears claim without advancing.
sh "$VALIDATE" retry >/dev/null
[ ! -e "$cdir/active-run" ] || fail "retry left active-run"
[ ! -e "$cdir/blocked" ] || fail "retry left blocked"
[ "$(cat "$cdir/cursor")" = "$cur" ] || fail "retry moved cursor"

# reset keeps reports; clears active campaign pointer.
sh "$VALIDATE" reset >/dev/null
[ ! -e "$work/state/active-campaign" ] || fail "reset left active-campaign"
[ -d "$cdir" ] || fail "reset deleted campaign"

# Separate GPU campaigns: restore pointer, refuse mismatched GPU.
printf '%s\n' "$cid" > "$work/state/active-campaign"
export ZLYME_PHASE14_TEST_GPU=panfrost
if sh "$VALIDATE" run >/dev/null 2>&1; then
	fail "run did not refuse GPU mismatch"
fi
# Fresh panfrost campaign is allowed and distinct.
export ZLYME_PHASE14_TEST_BOOT_ID=bootB
sh "$VALIDATE" start >/dev/null
cid2=$(cat "$work/state/active-campaign")
case "$cid2" in
	*panfrost*) ;;
	*) fail "panfrost campaign id missing gpu tag: $cid2" ;;
esac
[ "$cid2" != "$cid" ] || fail "GPU campaigns were not separate"

# No leftover watchdog/helper from this harness.
# shellcheck disable=SC2009
if ps -eo args= 2>/dev/null | grep -F "$work/state" | grep -E 'sleep 180|arm_timeout|post_observer' >/dev/null; then
	fail "leftover watchdog/helper still running"
fi

echo "phase14 validate ok"
