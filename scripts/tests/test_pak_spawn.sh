#!/bin/sh
# Host checks for the pak session helper. No device and no /storage writes.
set -eu
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
cc=${CC:-gcc}

fail() {
	echo "pak spawn: $*" >&2
	exit 1
}

[ -f "$LAUNCH" ] || fail "missing pak-launch.sh"
work=$(mktemp -d)
owned=$work/owned
: > "$owned"
restore() {
	if [ -f "$owned" ]; then
		while read -r pid; do
			[ -n "$pid" ] || continue
			kill -KILL "$pid" 2>/dev/null || true
		done < "$owned"
	fi
	rm -rf "$work"
}
trap restore EXIT
note() {
	printf '%s\n' "$1" >> "$owned"
}

"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/zlyme-pak-spawn" \
	"$ROOT/package/system/nextui/zlyme/zlyme-pak-spawn.c"
"$cc" -std=gnu99 -Wall -Wextra -Werror -DZLYME_TESTING \
	-o "$work/zlyme-pak-spawn-testing" \
	"$ROOT/package/system/nextui/zlyme/zlyme-pak-spawn.c"
"$cc" -std=gnu99 -Wall -Wextra -Werror -DZLYME_TESTING \
	-I"$ROOT/package/system/zlyme-input" \
	-o "$work/zlyme-pak-hotkey-testing" \
	"$ROOT/package/system/nextui/zlyme/zlyme-pak-hotkey.c"
"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/survivor" -x c - << 'EOF'
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void on_term(int sig)
{
	const char *path;
	FILE *f;
	(void)sig;
	path = getenv("SURVIVOR_MARK");
	if (!path)
		return;
	f = fopen(path, "a");
	if (!f)
		return;
	fputs("term\n", f);
	fclose(f);
}
int main(void)
{
	signal(SIGTERM, on_term);
	for (;;)
		pause();
	return 0;
}
EOF
"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/fanout-helper" -x c - << 'EOF'
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	FILE *out;
	int count, i;
	if (argc != 3)
		return 2;
	count = atoi(argv[1]);
	out = fopen(argv[2], "w");
	if (!out)
		return 2;
	for (i = 0; i < count; i++) {
		pid_t pid = fork();
		if (pid < 0)
			return 3;
		if (pid == 0) {
			if (setpgid(0, 0) != 0)
				_exit(4);
			for (;;)
				pause();
		}
		fprintf(out, "%d\n", (int)pid);
	}
	fclose(out);
	usleep(300000);
	return 0;
}
EOF

mkdir -p "$work/bin" "$work/tree/Emus/my355/PORTS.pak" \
	"$work/tree/Emus/my355/GB.pak"
cp "$work/zlyme-pak-spawn" "$work/bin/zlyme-pak-spawn"
chmod 0755 "$work/bin/zlyme-pak-spawn"
cat > "$work/bin/drm" << 'EOF'
#!/bin/sh
exit 0
EOF
cat > "$work/bin/pm" << 'EOF'
#!/bin/sh
printf '%s\n' clean >> "${SEQ:-/dev/null}"
EOF
cat > "$work/bin/hotkey" << 'EOF'
#!/bin/sh
printf '%s\n' "$3" > "$OUT/hotkey-pid"
printf '%s\n' "$1" > "$OUT/hotkey-waiter"
printf '%s\n' "$2" > "$OUT/hotkey-waiter-start"
ps -o sid= -p "$3" | tr -d ' \n' > "$OUT/hotkey-sid"
sleep 0.2
kill -TERM "$1" 2>/dev/null || true
while :; do
	sleep 1
done
EOF
chmod 0755 "$work/bin/drm" "$work/bin/pm" "$work/bin/hotkey"

# shellcheck disable=SC1090
. "$LAUNCH"
export PATH="$work/bin:/usr/bin:/bin"
export ZLYME_PAK_BT=0
export ZLYME_PAK_LAUNCH_SH="$LAUNCH"
export ZLYME_DRM_RELEASE="$work/bin/drm"
export ZLYME_PORTMASTER_CLEANUP="$work/bin/pm"
export ZLYME_PAK_HOTKEY="$work/missing-hotkey"
export SESSION_LOG="$work/session.log"
export LOGS_ON=0
export SURVIVOR="$work/survivor"
unset ZLYME_PAK_TRACE ZLYME_PAK_SPAWN || true

ports=$work/tree/Emus/my355/PORTS.pak/launch.sh
emu=$work/tree/Emus/my355/GB.pak/launch.sh

wait_bound() {
	pid=$1
	label=$2
	i=0
	while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 80 ]; do
		sleep 0.1
		i=$((i + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		fail "$label did not finish"
	fi
	wait "$pid" 2>/dev/null || true
}

# The hotkey must retain the published waiter identity and signal only
# that pidfd. A reused start time is refused, and the unrelated leader
# is never a signal target.
hotkey_mark=$work/hotkey-term
SURVIVOR_MARK=$hotkey_mark "$work/survivor" &
hotkey_waiter=$!
note "$hotkey_waiter"
sleep 30 &
hotkey_leader=$!
note "$hotkey_leader"
hotkey_waiter_start=$(awk '{ print $22 }' "/proc/$hotkey_waiter/stat")
hotkey_leader_start=$(awk '{ print $22 }' "/proc/$hotkey_leader/stat")
bad_start=$((hotkey_waiter_start + 1))
if ZLYME_TEST_STOP_NOW=1 "$work/zlyme-pak-hotkey-testing" \
	"$hotkey_waiter" "$bad_start" "$hotkey_leader" "$hotkey_leader_start"; then
	fail "hotkey accepted a reused waiter identity"
fi
[ ! -e "$hotkey_mark" ] || fail "reused waiter identity was signaled"
ZLYME_TEST_STOP_NOW=1 "$work/zlyme-pak-hotkey-testing" \
	"$hotkey_waiter" "$hotkey_waiter_start" \
	"$hotkey_leader" "$hotkey_leader_start"
i=0
while [ ! -s "$hotkey_mark" ] && [ "$i" -lt 20 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ -s "$hotkey_mark" ] || fail "hotkey did not signal the published waiter"
kill -0 "$hotkey_waiter" 2>/dev/null || fail "hotkey killed its waiter directly"
kill -0 "$hotkey_leader" 2>/dev/null || fail "hotkey signaled the leader"
kill -KILL "$hotkey_waiter" "$hotkey_leader" 2>/dev/null || true
wait "$hotkey_waiter" 2>/dev/null || true
wait "$hotkey_leader" 2>/dev/null || true

# SIGTERM during the pre-publication handshake must not enter an
# unbounded wait on a child that ignores TERM. The child cannot exec
# before the parent acknowledges its identity, so successful cleanup
# is an ordinary rejected launch rather than unresolved ownership.
handshake_file=$work/handshake-leader
ZLYME_TEST_HANDSHAKE_HANG=1 "$work/zlyme-pak-spawn-testing" \
	"$handshake_file" sh -c 'exit 0' &
handshake_waiter=$!
note "$handshake_waiter"
i=0
children=
while [ "$i" -lt 20 ]; do
	if [ -r "/proc/$handshake_waiter/task/$handshake_waiter/children" ]; then
		children=$(cat "/proc/$handshake_waiter/task/$handshake_waiter/children")
		[ -z "$children" ] || break
	fi
	sleep 0.05
	i=$((i + 1))
done
[ -n "$children" ] || fail "handshake child was not created"
kill -TERM "$handshake_waiter"
i=0
while kill -0 "$handshake_waiter" 2>/dev/null && [ "$i" -lt 80 ]; do
	sleep 0.05
	i=$((i + 1))
done
if kill -0 "$handshake_waiter" 2>/dev/null; then
	fail "handshake termination was unbounded"
fi
handshake_st=0
wait "$handshake_waiter" || handshake_st=$?
[ "$handshake_st" -eq 127 ] || fail "handshake status $handshake_st"
for child in $children; do
	[ ! -d "/proc/$child" ] || fail "handshake child $child survived"
done

# Clean exit. The recorded leader is its own session.
cat > "$emu" << 'EOF'
#!/bin/sh
printf '%s\n' "$$" > "$OUT/pid"
ps -o sid= -p "$$" | tr -d ' \n' > "$OUT/sid"
exit 0
EOF
chmod 0755 "$emu"
OUT=$work/clean
mkdir -p "$OUT"
export OUT
run_pak_cmd "$emu" "/r/a"
# shellcheck disable=SC2154 # set by run_pak_cmd
[ "$st" -eq 0 ] || fail "clean status $st"
[ "$(cat "$OUT/pid")" = "$(cat "$OUT/sid")" ] || fail "clean leader is not its session"
# shellcheck disable=SC2154 # set by spawn_pak
[ "$(cat "$OUT/pid")" = "$_pak_pid" ] || fail "clean target is not the leader"

# A pak may return the status reserved for unresolved ownership. Keep
# that an ordinary launch failure instead of suppressing the frontend.
cat > "$emu" << 'EOF'
#!/bin/sh
exit 125
EOF
chmod 0755 "$emu"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 126 ] || fail "pak status 125 was not kept out of cleanup contract: $st"
if pak_cleanup_failed "$st"; then
	fail "pak status 125 was classified as unresolved ownership"
fi

# Long-running leader. The stub hotkey signals the identity-pinned
# waiter, which owns bounded cleanup of the session.
cat > "$emu" << 'EOF'
#!/bin/sh
printf '%s\n' "$$" > "$OUT/pid"
exec sleep 30
EOF
chmod 0755 "$emu"
OUT=$work/long
mkdir -p "$OUT"
export OUT
export ZLYME_PAK_HOTKEY="$work/bin/hotkey"
(run_pak_cmd "$emu" "/r/a"; printf '%s\n' "$st" > "$OUT/status") &
job=$!
note "$job"
i=0
while [ ! -s "$OUT/hotkey-pid" ] && [ "$i" -lt 50 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ -s "$OUT/hotkey-pid" ] || fail "long-running hotkey did not see a leader"
leader=$(cat "$OUT/hotkey-pid")
waiter=$(cat "$OUT/hotkey-waiter")
sid=$(cat "$OUT/hotkey-sid")
[ "$leader" = "$sid" ] || fail "long-running target sid $sid is not leader $leader"
[ "$waiter" != "$leader" ] || fail "hotkey waiter is the pak leader"
[ -n "$(cat "$OUT/hotkey-waiter-start")" ] || fail "hotkey waiter has no start time"
[ "$leader" != "$$" ] || fail "long-running target is the test shell"
wait_bound "$job" "long-running child"
[ "$(cat "$OUT/status")" -eq 143 ] || fail "hotkey stop status $(cat "$OUT/status")"
[ ! -d "/proc/$leader" ] || fail "long-running leader $leader survived"

# Short-lived wrapper. The leader exits and leaves a child that ignores
# SIGTERM. The helper must still end that child, then port cleanup runs.
cat > "$ports" << 'EOF'
#!/bin/sh
"$SURVIVOR" &
printf '%s\n' "$!" > "$OUT/child"
exit 0
EOF
chmod 0755 "$ports"
OUT=$work/wrap
mkdir -p "$OUT"
export OUT SURVIVOR_MARK="$OUT/mark"
export ZLYME_PAK_HOTKEY="$work/missing-hotkey"
SEQ=$OUT/seq
export SEQ
: > "$SEQ"
run_pak_cmd "$ports" "/r/a" &
job=$!
note "$job"
wait_bound "$job" "wrapper child"
[ -s "$OUT/child" ] || fail "wrapper did not start a child"
child=$(cat "$OUT/child")
[ ! -d "/proc/$child" ] || fail "wrapper child $child survived"
grep -q term "$OUT/mark" || fail "wrapper child was not sent SIGTERM"
grep -q clean "$SEQ" || fail "wrapper skipped port cleanup"

# This shell's sleeper shares the frontend session. A pak that exits
# must not signal it.
cat > "$emu" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$emu"
sleep 30 &
innocent=$!
note "$innocent"
OUT=$work/safe
mkdir -p "$OUT"
export OUT
run_pak_cmd "$emu" "/r/a"
if ! kill -0 "$innocent" 2>/dev/null; then
	fail "frontend sleeper was signaled"
fi
kill "$innocent" 2>/dev/null || true
wait "$innocent" 2>/dev/null || true

# A /proc scan failure is not an empty session. Status 125 is reserved
# for unresolved ownership and is propagated by pak-launch.sh.
OUT=$work/proc-error
mkdir -p "$OUT"
export OUT ZLYME_PAK_SPAWN="$work/zlyme-pak-spawn-testing"
export ZLYME_TEST_PROC_ROOT="$work/missing-proc"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 125 ] || fail "proc failure status $st"
pak_cleanup_failed "$st" || fail "proc failure was not classified"

# A malformed live stat entry is an inspection error, while a zombie is
# not an active owner and must not keep the session busy.
fake=$work/fake-proc
mkdir -p "$fake"
export ZLYME_TEST_PROC_ROOT="$fake"
cat > "$emu" << 'EOF'
#!/bin/sh
mkdir -p "$ZLYME_TEST_PROC_ROOT/999999"
printf '%s\n' 'malformed' > "$ZLYME_TEST_PROC_ROOT/999999/stat"
exit 0
EOF
chmod 0755 "$emu"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 125 ] || fail "malformed proc status $st"
rm -rf "$fake/999999"
# A reused leader number with a different start time is not the owned
# session, even when its PGID and SID numerically match.
cat > "$emu" << 'EOF'
#!/bin/sh
mkdir -p "$ZLYME_TEST_PROC_ROOT/$$"
{
	printf '%s (reused) S 1 %s %s' "$$" "$$" "$$"
	i=0
	while [ "$i" -lt 15 ]; do
		printf ' 0'
		i=$((i + 1))
	done
	printf ' 1\n'
} > "$ZLYME_TEST_PROC_ROOT/$$/stat"
exit 0
EOF
chmod 0755 "$emu"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 125 ] || fail "reused leader status $st"
rm -rf "${fake:?}/"*
cat > "$emu" << 'EOF'
#!/bin/sh
mkdir -p "$ZLYME_TEST_PROC_ROOT/999999"
{
	printf '999999 (zombie) Z 1 999999 %s' "$$"
	i=0
	while [ "$i" -lt 15 ]; do
		printf ' 0'
		i=$((i + 1))
	done
	printf ' 123\n'
} > "$ZLYME_TEST_PROC_ROOT/999999/stat"
exit 0
EOF
chmod 0755 "$emu"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 0 ] || fail "zombie-only session status $st"
rm -rf "$fake/999999"
unset ZLYME_TEST_PROC_ROOT ZLYME_PAK_SPAWN

# Startup rejection must not hide an ownership failure reported by the
# waiter before it can publish a valid session leader.
cat > "$work/reject-no-leader" << 'EOF'
#!/bin/sh
exit 125
EOF
chmod 0755 "$work/reject-no-leader"
export ZLYME_PAK_SPAWN="$work/reject-no-leader"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 125 ] || fail "missing-leader cleanup status $st"

cat > "$work/reject-bad-leader" << 'EOF'
#!/bin/sh
printf '%s\n' invalid > "$1"
exit 125
EOF
chmod 0755 "$work/reject-bad-leader"
export ZLYME_PAK_SPAWN="$work/reject-bad-leader"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 125 ] || fail "invalid-leader cleanup status $st"
unset ZLYME_PAK_SPAWN

# More than the historical 128-member cap, each in its own process
# group but in the pak session, must all be signaled and reaped.
cat > "$emu" << 'EOF'
#!/bin/sh
exec "$FANOUT" 140 "$OUT/pids"
EOF
chmod 0755 "$emu"
OUT=$work/fanout
mkdir -p "$OUT"
export OUT FANOUT="$work/fanout-helper"
run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 0 ] || fail "fanout status $st"
[ "$(wc -l < "$OUT/pids" | tr -d ' ')" -eq 140 ] || fail "fanout count"
while read -r pid; do
	[ -n "$pid" ] || continue
	if [ -d "/proc/$pid" ]; then
		fail "fanout member $pid survived"
	fi
done < "$OUT/pids"

# The frontend wrapper must stop, not show/restart, on the reserved
# cleanup failure after PortMaster cleanup has had its chance.
# shellcheck disable=SC2016
grep -q 'if pak_cleanup_failed "$st"; then' \
	"$ROOT/package/system/nextui/nextui-session" ||
	fail "nextui-session does not stop on cleanup failure"
grep -q 'pak cleanup unresolved; frontend stopped' \
	"$ROOT/package/system/nextui/nextui-session" ||
	fail "nextui-session cleanup failure is not diagnosable"

# Hotkey stop while the leader has already become a zombie must still
# reap session members. The TERM scan warning is not ownership failure
# when the leader identity matches a zombie or an absent PID.
cat > "$emu" << 'EOF'
#!/bin/sh
"$SURVIVOR" &
printf '%s\n' "$!" > "$OUT/child"
# Exit immediately so the waiter may see a zombie/absent leader when
# the stub hotkey signals stop shortly after spawn.
exit 0
EOF
chmod 0755 "$emu"
OUT=$work/zombie-stop
mkdir -p "$OUT"
export OUT SURVIVOR_MARK="$OUT/mark"
export ZLYME_PAK_HOTKEY="$work/bin/hotkey"
SEQ=$OUT/seq
export SEQ
: > "$SEQ"
(run_pak_cmd "$emu" "/r/a"; printf '%s\n' "$st" > "$OUT/status") &
job=$!
note "$job"
i=0
while [ ! -s "$OUT/hotkey-pid" ] && [ "$i" -lt 50 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ -s "$OUT/hotkey-pid" ] || fail "zombie-stop hotkey did not see a leader"
wait_bound "$job" "zombie-stop child"
[ -s "$OUT/child" ] || fail "zombie-stop did not start a child"
child=$(cat "$OUT/child")
[ ! -d "/proc/$child" ] || fail "zombie-stop child $child survived"
st_out=$(cat "$OUT/status")
# Natural exit is 0; hotkey may still race and report 143. Neither is 125.
case "$st_out" in
	0|143) ;;
	*) fail "zombie-stop status $st_out" ;;
esac
if [ "$st_out" -eq 125 ]; then
	fail "zombie-stop raised unresolved ownership"
fi
unset ZLYME_PAK_HOTKEY


echo "pak spawn ok"
