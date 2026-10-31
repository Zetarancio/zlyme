#!/bin/sh
# Direct shutdown must not let nextui-session start the frontend again.
# restart and reload still leave the relaunch permit for the running session.
# killall, reboot, poweroff, and umount are mocks or absent. Nothing here
# shuts down the host.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
S90=$ROOT/board/my355/fsoverlay/etc/init.d/S90minui
fail() { echo "s90-shutdown: $*" >&2; exit 1; }

work=$(mktemp -d)
session_pid=
cleanup() {
	if [ -n "$session_pid" ]; then
		kill "$session_pid" 2>/dev/null || true
		wait "$session_pid" 2>/dev/null || true
	fi
	rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/bin"
log=$work/session.log
kill_log=$work/kill.log
s28_log=$work/s28.log
exec_file=$work/nextui_exec
alive=$work/frontend-alive
power=$work/poweroff
reboot=$work/reboot

cat >"$work/bin/killall" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$kill_log"
rm -f "$alive"
exit 0
EOF
cat >"$work/bin/s28" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_S28_LOG"
exit 0
EOF
chmod 0755 "$work/bin/killall" "$work/bin/s28"

run_s90() {
	PATH="$work/bin:$PATH" \
	ZLYME_NEXTUI_EXEC="$exec_file" \
	ZLYME_POWEROFF_FLAG="$power" \
	ZLYME_REBOOT_FLAG="$reboot" \
	ZLYME_S28="$work/bin/s28" \
	ZLYME_S28_LOG="$s28_log" \
		"$S90" "$@"
}

# Models the session loop: while /tmp/nextui_exec exists, start the frontend
# and wait until that frontend exits. A later loop is a relaunch.
session() {
	: >"$exec_file"
	while [ -f "$exec_file" ]; do
		echo launch >>"$log"
		: >"$alive"
		while [ -f "$alive" ]; do
			sleep 0.02
		done
		echo exited >>"$log"
	done
	echo session-done >>"$log"
}

wait_for() {
	needle=$1
	n=0
	while [ "$n" -lt 100 ]; do
		if grep -qx "$needle" "$log"; then
			return 0
		fi
		n=$((n + 1))
		sleep 0.02
	done
	fail "timed out waiting for $needle ($(cat "$log" 2>/dev/null || true))"
}

launch_count() {
	grep -c '^launch$' "$log" || true
}

start_session() {
	: >"$log"
	: >"$kill_log"
	: >"$s28_log"
	rm -f "$exec_file" "$alive" "$power" "$reboot"
	session &
	session_pid=$!
	wait_for launch
}

stop_session() {
	rm -f "$exec_file" "$alive"
	wait "$session_pid" 2>/dev/null || true
}

# Shutdown stop: one frontend, then the session ends.
start_session
run_s90 stop
n=0
while [ "$n" -lt 100 ]; do
	if grep -qx session-done "$log"; then
		break
	fi
	n=$((n + 1))
	sleep 0.02
done
grep -qx session-done "$log" || fail "shutdown stop left the session running ($(cat "$log"))"
count=$(launch_count)
[ "$count" = 1 ] || fail "shutdown stop relaunched the frontend ($count launches)"
grep -q nextui.elf "$kill_log" || fail "shutdown stop did not stop the frontend"
if [ -f "$exec_file" ]; then
	fail "shutdown stop left the relaunch permit"
fi
stop_session

# Restart leaves the permit. The same session starts the frontend again.
start_session
run_s90 restart
wait_for exited
n=0
while [ "$n" -lt 100 ]; do
	count=$(launch_count)
	[ "$count" -ge 2 ] && break
	n=$((n + 1))
	sleep 0.02
done
count=$(launch_count)
[ "$count" -ge 2 ] || fail "restart did not let the session relaunch ($(cat "$log"))"
[ -f "$exec_file" ] || fail "restart removed the relaunch permit"
grep -qx start "$s28_log" || fail "restart did not start S28 ($(cat "$s28_log"))"
stop_session

# Reload is the same session contract as restart.
start_session
run_s90 reload
n=0
while [ "$n" -lt 100 ]; do
	count=$(launch_count)
	[ "$count" -ge 2 ] && break
	n=$((n + 1))
	sleep 0.02
done
count=$(launch_count)
[ "$count" -ge 2 ] || fail "reload did not let the session relaunch ($(cat "$log"))"
[ -f "$exec_file" ] || fail "reload removed the relaunch permit"
grep -qx start "$s28_log" || fail "reload did not start S28 ($(cat "$s28_log"))"
stop_session

# A halt flag means the session owns the shutdown. Do not kill or drop it.
start_session
: >"$power"
run_s90 stop
sleep 0.1
if [ -s "$kill_log" ]; then
	fail "poweroff flag still stopped the frontend ($(cat "$kill_log"))"
fi
[ -f "$exec_file" ] || fail "poweroff flag dropped the relaunch permit"
[ -f "$alive" ] || fail "poweroff flag ended the frontend"
stop_session

start_session
: >"$reboot"
run_s90 stop
sleep 0.1
if [ -s "$kill_log" ]; then
	fail "reboot flag still stopped the frontend ($(cat "$kill_log"))"
fi
[ -f "$exec_file" ] || fail "reboot flag dropped the relaunch permit"
stop_session

echo "s90 shutdown ok"
