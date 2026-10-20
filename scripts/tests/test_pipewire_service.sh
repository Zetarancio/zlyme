#!/bin/sh
# PipeWire launcher identity, deferred volume, and tab-separated nodes.
# No live Flip and no host PipeWire daemon.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pipewire-service: $*" >&2; exit 1; }
LAUNCH=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pipewire-launch
AUDIO=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/rt" "$work/cfg" "$work/proc"

cat > "$work/bin/start-stop-daemon" << 'EOF'
#!/bin/sh
# Record argv and fork the named program. -K kills only that pidfile's pid.
pidf=
execp=
killmode=0
while [ $# -gt 0 ]; do
	case "$1" in
		-p) pidf=$2; shift 2 ;;
		--exec) execp=$2; shift 2 ;;
		-K) killmode=1; shift ;;
		*) shift ;;
	esac
done
if [ "$killmode" = 1 ]; then
	if [ -f "$pidf" ]; then
		kill "$(cat "$pidf")" 2>/dev/null || true
	fi
	exit 0
fi
"$execp" &
echo $! > "$pidf"
EOF
chmod 755 "$work/bin/start-stop-daemon"

for name in pipewire wireplumber pipewire-pulse; do
	cat > "$work/bin/$name" << EOF
#!/bin/sh
sleep 30
EOF
	chmod 755 "$work/bin/$name"
done

export PATH="$work/bin:$PATH"
export ZLYME_PW_RUNTIME=$work/rt
export ZLYME_PIPEWIRE=$work/bin/pipewire
export ZLYME_WIREPLUMBER=$work/bin/wireplumber
export ZLYME_PIPEWIRE_PULSE=$work/bin/pipewire-pulse
# Sockets the launcher waits for.
mkdir -p "$work/rt/pulse"
# Created after start by a helper; the launcher polls. Touch them from
# a background copier once the pids exist. Simpler: pre-create, the
# wait returns immediately.
: > "$work/rt/pipewire-0"
: > "$work/rt/pulse/native"
# wait_sock tests -S, so make sockets.
rm -f "$work/rt/pipewire-0" "$work/rt/pulse/native"
python3 - << PY
import os, socket
for path in ("$work/rt/pipewire-0", "$work/rt/pulse/native"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
    s.listen(1)
    # leave the socket; the process can exit, the inode remains
    s.close()
PY

export ZLYME_CFG=$work/cfg
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/z.conf"
export ZLYME_CONF=$work/z.conf
export ZLYME_AUDIO=$AUDIO
printf 'ZLYME_VOLUME=40\nZLYME_PREMUTE=15\n' > "$work/cfg/audio.conf"
# No codec node yet.
printf '' > "$work/nodes"
export ZLYME_PW_NODES=$work/nodes
export ZLYME_WPCTL=$work/bin/wpctl
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
exit 0
EOF
chmod 755 "$work/bin/wpctl"
export WP_LOG=$work/wp.log
: > "$WP_LOG"

sh "$LAUNCH" start
grep -qx codec-waiting "$work/rt/service" || fail "status $(cat "$work/rt/service")"
grep -q '^ZLYME_VOLUME_SRC=pipewire-cubic$' "$work/cfg/audio.conf" || fail "data not converted"
grep -q '^ZLYME_GAIN_STATE=deferred$' "$work/cfg/audio.conf" || fail "gain marked applied with no codec"
grep -q '^ZLYME_PREMUTE=15$' "$work/cfg/audio.conf" || fail "premute dropped"
# The pipewire pid must not be the pipewire-pulse process.
ppid=$(cat "$work/rt/pipewire.pid")
tr '\0' '\n' < "/proc/$ppid/cmdline" | sed 's|.*/||' | grep -qx pipewire || fail "pipewire identity $(tr '\0' ' ' < /proc/$ppid/cmdline)"
spid=$(cat "$work/rt/pulse.pid")
tr '\0' '\n' < "/proc/$spid/cmdline" | sed 's|.*/||' | grep -qx pipewire-pulse || fail "pulse identity"
[ "$ppid" != "$spid" ] || fail "one process counted as both servers"

# Stale pid file naming this shell must not be killed.
echo "$$" > "$work/rt/pipewire.pid"
sh "$LAUNCH" stop
kill -0 $$ || fail "stop killed an unrelated pid"
kill "$ppid" 2>/dev/null || true

# Late codec. Restart pieces are dead; just the audio helper.
printf 'codec\t7\nhdmi\t8\nbt\t9\n' > "$work/nodes"
sh "$AUDIO" migrate-volume
grep -q '^ZLYME_GAIN_STATE=applied$' "$work/cfg/audio.conf" || fail "late codec did not receive gain"
grep -q 'set-volume 7 0.064000' "$WP_LOG" || fail "cubic gain $(cat "$WP_LOG")"
# Three nodes, tab separated, all seen by node-id.
[ "$(sh "$AUDIO" node-id bt)" = 9 ] || fail "bt id"
[ "$(sh "$AUDIO" node-id hdmi)" = 8 ] || fail "hdmi id"

conf=$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf
grep -q 'main-embedded' "$conf" || fail "profile"
grep -q 'api.alsa.card.id = "rk817ext"' "$conf" || fail "rk817 id"
grep -q 'a2dp_source' "$conf" || fail "a2dp source role"
grep -q 'linking.follow-default-target = true' "$conf" || fail "stream follow"
grep -q 'XDG_RUNTIME_DIR' "$ROOT/package/system/nextui/nextui-session" || fail "session env"
if grep -q 'PULSE_RUNTIME_PATH=' "$ROOT/package/system/nextui/nextui-session"; then
	fail "session still exports the old pulse path"
fi
echo "pipewire service ok"
