#!/bin/sh
# The PulseAudio daemon contract is retired. The PipeWire service test
# is the replacement.
exec sh "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/test_pipewire_service.sh"
# shellcheck disable=SC1007
# Start the real PulseAudio daemon through zlyme-pulse-launch.
# Fake pactl scripts do not cover this. A host without the pulseaudio
# binary still runs the pid and error-text checks, and says the live
# server was not started here.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
S21=$ROOT/board/my355/fsoverlay/etc/init.d/S21pulse
LAUNCH_SRC=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pulse-launch
AUDIO=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
fail() { echo "pulse-daemon: $*" >&2; exit 1; }

[ -x "$LAUNCH_SRC" ] || fail "launcher is not executable"
# shellcheck disable=SC1090
ZLYME_PULSE_LIB=1 . "$S21"

work=$(mktemp -d)
lpid=
runtime=
spid=
trap 'cleanup' EXIT
cleanup() {
	if [ -n "$runtime" ]; then
		ZLYME_PULSE_RUNTIME=$runtime pulse_stop_ours || true
	fi
	if [ -n "$lpid" ]; then
		kill "$lpid" 2>/dev/null || true
		wait "$lpid" 2>/dev/null || true
	fi
	if [ -n "$spid" ]; then
		kill "$spid" 2>/dev/null || true
		wait "$spid" 2>/dev/null || true
	fi
	rm -rf "$work"
}

# Error text. The cookie file is not an input.
mkdir -p "$work/reason"
printf '%s\n' "E: [pulseaudio] main.c: Failed to create '/var/lib/pulse': Read-only file system" > "$work/reason/daemon.log"
printf '%s\n' 1 > "$work/reason/exit"
ZLYME_PULSE_RUNTIME=$work/reason
got=$(pulse_fail_reason)
want="failed: exit 1: Failed to create '/var/lib/pulse': Read-only file system"
[ "$got" = "$want" ] || fail "reason: $got"
printf '%s\n' 'E: [pulseaudio] module.c: Failed to load module "module-alsa-sink" (argument: "device=hw:missing,0 sink_name=codec"): initialization failed.' > "$work/reason/daemon.log"
rm -f "$work/reason/exit"
got=$(pulse_fail_reason)
want='failed: Failed to load module "module-alsa-sink" (argument: "device=hw:missing,0 sink_name=codec"): initialization failed.'
[ "$got" = "$want" ] || fail "module reason: $got"
printf '%s\n' 'E: [pulseaudio] main.c: Sink codec does not exist.' > "$work/reason/daemon.log"
rm -f "$work/reason/exit"
got=$(pulse_fail_reason)
want='failed: Sink codec does not exist.'
[ "$got" = "$want" ] || fail "sink reason: $got"
if grep -q '\[:print:\]' "$S21"; then
	fail "status text uses a BusyBox tr class"
fi
grep -q -- '--log-level="$level"' "$LAUNCH_SRC" || fail "launcher has no log level"
grep -q 'level=notice' "$LAUNCH_SRC" || fail "routine log level is not notice"
grep -q 'ZLYME_PULSE_LOG' "$LAUNCH_SRC" || fail "info logging is not opt-in"
# No daemon log at all.
rm -f "$work/reason/daemon.log" "$work/reason/exit"
got=$(pulse_fail_reason)
[ "$got" = "failed: daemon exited during startup" ] || fail "empty reason: $got"

# A live pid that is not our launcher is not killed, and its pidfile
# is not treated as the server.
mkdir -p "$work/stale"
sleep 120 &
spid=$!
printf '%s\n' "$spid" > "$work/stale/pid"
ZLYME_PULSE_RUNTIME=$work/stale
rc=0
pulse_clear_stale || rc=$?
# 3 means some other pulseaudio was already running. It is still not
# this sleep process, and the pidfile must not keep pointing at it.
[ "$rc" -eq 0 ] || [ "$rc" -eq 3 ] || fail "stale pid returned $rc"
kill -0 "$spid" || fail "stale pid was killed"
[ ! -f "$work/stale/pid" ] || fail "unrelated pidfile was kept"
kill "$spid"
wait "$spid" 2>/dev/null || true
spid=

if ! command -v pulseaudio >/dev/null 2>&1 || ! command -v pactl >/dev/null 2>&1; then
	echo "pulse-daemon: pid and error text ok; this host has no pulseaudio daemon"
	exit 0
fi

runtime=$work/run
mkdir -p "$runtime" "$work/cfg"
export ZLYME_PULSE_RUNTIME="$runtime"
export ZLYME_PULSE_BIN
ZLYME_PULSE_BIN=$(command -v pulseaudio)
export ZLYME_PULSE_FILE="$work/ok.pa"
export PULSE_RUNTIME_PATH="$runtime"
export PULSE_STATE_PATH="$runtime"
export PULSE_CONFIG_PATH="$runtime"
export HOME="$runtime"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$work/no-bus"
unset PULSE_SERVER PULSE_COOKIE || true

cat > "$work/ok.pa" << EOF
.fail
load-module module-native-protocol-unix auth-anonymous=0 auth-cookie=$runtime/cookie auth-cookie-enabled=1 socket=$runtime/native
load-module module-null-sink sink_name=codec channels=2 rate=48000 format=s16le
set-default-sink codec
EOF
cat > "$work/client.conf" << EOF
autospawn = no
default-server = unix:$runtime/native
cookie-file = $runtime/cookie
EOF
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/zlyme.conf"

"$LAUNCH_SRC" &
lpid=$!
printf '%s\n' "$lpid" > "$runtime/pid"
i=0
while [ "$i" -lt 5 ]; do
	if [ -S "$runtime/native" ] && [ -f "$runtime/cookie" ]; then
		break
	fi
	kill -0 "$lpid" 2>/dev/null || break
	i=$((i + 1))
	sleep 1
done
[ -S "$runtime/native" ] || {
	echo "pulse-daemon: log:" >&2
	cat "$runtime/daemon.log" >&2 || true
	fail "daemon did not create a socket"
}
[ -f "$runtime/cookie" ] || fail "daemon did not write a cookie"
# mode is at least not world-readable. stat -c is not POSIX; ls is enough
# to show the mode to a failure, and a direct bit test uses the shell.
[ ! -r "$runtime/cookie" ] && fail "cookie is not readable by the launching user"
cookie_mode=$(stat -c %a "$runtime/cookie")
[ "$cookie_mode" = 600 ] || fail "cookie mode $cookie_mode"

export PULSE_SERVER="unix:$runtime/native"
export PULSE_COOKIE="$runtime/cookie"
pactl info >/dev/null || fail "pactl did not connect"
pactl list short sinks | awk '$2 == "codec" { found = 1 } END { exit !found }' ||
	fail "codec sink missing"
pactl set-sink-volume codec 30% || fail "volume was not accepted"
# A wrong cookie must not open a second server.
dd if=/dev/zero of="$work/bad-cookie" bs=256 count=1 status=none 2>/dev/null ||
	dd if=/dev/zero of="$work/bad-cookie" bs=256 count=1 2>/dev/null
if PULSE_COOKIE="$work/bad-cookie" pactl info >/dev/null 2>&1; then
	fail "a replaced cookie was accepted"
fi
pactl info >/dev/null || fail "good cookie stopped working"
# One native client writes a buffer. This is the PCM path.
cat > "$work/pcm.c" << 'EOF'
#include <pulse/simple.h>
#include <pulse/error.h>
#include <string.h>
int main(void)
{
    pa_sample_spec ss = { PA_SAMPLE_S16LE, 48000, 2 };
    int err = 0;
    short buf[960];
    pa_simple *s = pa_simple_new(NULL, "zlyme-test", PA_STREAM_PLAYBACK,
                                 NULL, "tone", &ss, NULL, NULL, &err);
    if (!s)
        return 1;
    memset(buf, 0, sizeof buf);
    if (pa_simple_write(s, buf, sizeof buf, &err) < 0) {
        pa_simple_free(s);
        return 2;
    }
    pa_simple_drain(s, &err);
    pa_simple_free(s);
    return 0;
}
EOF
if cc -std=c11 -Wall -Wextra -Werror -o "$work/pcm" "$work/pcm.c" -lpulse-simple; then
	PULSE_CLIENTCONFIG="$work/client.conf" "$work/pcm" || fail "libpulse-simple did not write"
else
	fail "could not compile the libpulse client"
fi

# Readiness uses the real helper and the real status words.
export ZLYME_CONF="$work/zlyme.conf"
export ZLYME_CFG="$work/cfg"
export ZLYME_PULSE_NO_MIGRATE=1
export ZLYME_PULSE_READY_LIMIT=2
export PATH="$ROOT/board/my355/fsoverlay/usr/sbin:$PATH"
token=testdaemon
printf '%s\n' "$token" > "$runtime/boot-id"
ready_check "$token"
first=$(head -n 1 "$runtime/service")
[ "$first" = "ready" ] || fail "status after a live codec sink: $first"
"$AUDIO" pulse-service || fail "zlyme-audio pulse-service rejected the live sink"

# Restart. The old process is gone and one new server answers.
ZLYME_PULSE_RUNTIME=$runtime pulse_stop_ours
wait "$lpid" 2>/dev/null || true
lpid=
[ -f "$runtime/exit" ] || fail "launcher did not record an exit status"
if pulse_our_daemon; then
	fail "daemon still running after stop"
fi
"$LAUNCH_SRC" &
lpid=$!
printf '%s\n' "$lpid" > "$runtime/pid"
i=0
while [ "$i" -lt 5 ]; do
	[ -S "$runtime/native" ] && break
	i=$((i + 1))
	sleep 1
done
[ -S "$runtime/native" ] || fail "restart did not create a socket"
pactl info >/dev/null || fail "pactl did not connect after restart"
count=0
for pid in $(pidof pulseaudio 2>/dev/null || true); do
	if pulse_environ_is_ours "$pid" "$runtime"; then
		count=$((count + 1))
	fi
done
[ "$count" -eq 1 ] || fail "restart left $count daemons"

# A codec device that is not there must exit and keep the reason.
# Stop the good server first so this host does not keep two.
ZLYME_PULSE_RUNTIME=$runtime pulse_stop_ours
wait "$lpid" 2>/dev/null || true
lpid=
bad=$work/bad
mkdir -p "$bad"
export ZLYME_PULSE_RUNTIME="$bad"
runtime=$bad
export ZLYME_PULSE_FILE="$work/bad.pa"
export PULSE_RUNTIME_PATH="$bad"
export PULSE_STATE_PATH="$bad"
export HOME="$bad"
cat > "$work/bad.pa" << EOF
.fail
load-module module-native-protocol-unix auth-anonymous=1 socket=$bad/native
load-module module-alsa-sink device=hw:zlyme-no-such-card,0 sink_name=codec
EOF
# A missing card must not look like a ready server. PulseAudio 17
# has been observed to log the module error and keep running, so an
# exit is not required. The codec sink must be absent, the log must
# contain the error, and no server is left behind.
"$LAUNCH_SRC" &
lpid=$!
printf '%s\n' "$lpid" > "$bad/pid"
i=0
while [ "$i" -lt 5 ]; do
	if ! kill -0 "$lpid" 2>/dev/null; then
		break
	fi
	if [ -S "$bad/native" ]; then
		break
	fi
	i=$((i + 1))
	sleep 1
done
if [ -S "$bad/native" ]; then
	if PULSE_SERVER="unix:$bad/native" pactl list short sinks 2>/dev/null |
		awk '$2 == "codec" { found = 1 } END { exit !found }'; then
		fail "bad codec device still published a codec sink"
	fi
fi
grep -q '^E:' "$bad/daemon.log" || fail "bad startup log has no error line"
token=testbad
printf '%s\n' "$token" > "$bad/boot-id"
export ZLYME_PULSE_READY_LIMIT=1
ready_check "$token"
first=$(head -n 1 "$bad/service")
case $first in
	failed:*) ;;
	*) fail "bad status: $first" ;;
esac
ZLYME_PULSE_RUNTIME="$bad" pulse_stop_ours
if [ -n "$lpid" ]; then
	wait "$lpid" 2>/dev/null || true
	lpid=
fi
if pulse_our_daemon; then
	fail "bad startup left a daemon"
fi
runtime=
echo "pulse-daemon ok"
