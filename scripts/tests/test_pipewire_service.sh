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
export ZLYME_PW_CHECK_PULSE=0
export ZLYME_PW_CODEC_TRIES=1
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
if grep -q '^ZLYME_GAIN_STATE=' "$work/cfg/audio.conf"; then
	fail "runtime gain state was stored on disk"
fi
grep -q '^ZLYME_PREMUTE=15$' "$work/cfg/audio.conf" || fail "premute dropped"
grep -q '^ZLYME_SINK_PREF=auto$' "$work/cfg/audio.conf" || fail "old sink became a manual preference"
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
: > "$WP_LOG"
sh "$AUDIO" migrate-volume
grep -q 'set-volume 7 0.064000' "$WP_LOG" || fail "first graph $(cat "$WP_LOG")"
grep -q 'set-volume 8 0.064000' "$WP_LOG" || fail "hdmi missed the saved gain"
grep -q 'set-volume 9 0.064000' "$WP_LOG" || fail "bt missed the saved gain"
: > "$WP_LOG"
sh "$AUDIO" migrate-volume
grep -q 'set-volume 7 0.064000' "$WP_LOG" || fail "second graph skipped the saved gain"
printf 'ZLYME_VOLUME=0\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_GAIN_STATE=applied\nZLYME_PREMUTE=15\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
sh "$AUDIO" migrate-volume
grep -q 'set-volume 7 0$' "$WP_LOG" || grep -q 'set-volume 7 0.000000' "$WP_LOG" || fail "mute was not reapplied $(cat "$WP_LOG")"
if grep -q '^ZLYME_GAIN_STATE=' "$work/cfg/audio.conf"; then
	fail "old applied marker survived"
fi
for spec in "1 0.000001" "10 0.001000" "50 0.125000" "100 1"; do
	set -- $spec
	printf 'ZLYME_VOLUME=%s\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' "$1" > "$work/cfg/audio.conf"
	: > "$WP_LOG"
	sh "$AUDIO" migrate-volume
	grep -q "set-volume 7 $2" "$WP_LOG" || fail "percent $1 gain $(cat "$WP_LOG")"
done
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
exit 1
EOF
if sh "$AUDIO" route; then
	fail "failed wpctl was treated as success"
fi
# Three nodes, tab separated, all seen by node-id.
[ "$(sh "$AUDIO" node-id bt)" = 9 ] || fail "bt id"
[ "$(sh "$AUDIO" node-id hdmi)" = 8 ] || fail "hdmi id"

conf=$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf
grep -q 'main-embedded' "$conf" || fail "profile"
grep -q 'alsa.id = "rk817ext"' "$conf" || fail "rk817 id"
if grep -q 'api.alsa.card.id =' "$conf"; then
	fail "rule still matches a property playback nodes do not have"
fi
grep -q 'priority.session = 2000' "$conf" || fail "codec priority"
grep -q 'priority.session = 1000' "$conf" || fail "hdmi priority"
grep -q 'priority.session = 3000' "$conf" || fail "a2dp priority"
grep -q 'default-sink-volume = 0.064' "$conf" || fail "silent route default"
grep -q 'a2dp_source' "$conf" || fail "a2dp source role"
grep -q 'linking.follow-default-target = true' "$conf" || fail "stream follow"
grep -q 'policy.zlyme-volume = required' "$conf" || fail "volume hook not required"
rules=$ROOT/board/my355/fsoverlay/etc/udev/rules.d/90-zlyme-audio.rules
grep -q 'SUBSYSTEM=="drm"' "$rules" || fail "hdmi cable is not a sound event"
if grep -q 'SUBSYSTEM=="sound"' "$rules"; then
	fail "udev still routes on sound-card events"
fi
if grep -q 'a2dp-connect\|SUBSYSTEM=="bluetooth"' "$rules"; then
	fail "udev still runs Bluetooth recovery"
fi
lua=$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-volume.lua
grep -q 'node-id bt' "$lua" || fail "late A2DP node is not waited for"
grep -q 'node-removed' "$lua" || fail "sink removal does not reroute"
if grep -q 'while \[ "\$i" -lt 8 \]; do /usr/sbin/zlyme-audio route' "$lua"; then
	fail "route still retries unconditionally"
fi
if grep -q ' &' "$rules"; then
	fail "udev still backgrounds the route"
fi
grep -q 'zlyme-audio route' "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-volume.lua" || fail "late sink does not reroute"
grep -q 'hold)' "$AUDIO" || fail "transient gain"
if grep -q 'S21pulse' "$ROOT/board/my355/post-build.sh"; then
	fail "post-build still deletes a retired init script"
fi

# Live playback nodes publish alsa.id and do not publish api.alsa.card.id.
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
exit 0
EOF
chmod 755 "$work/bin/wpctl"
unset ZLYME_PW_NODES
cat > "$work/dump.json" << 'EOF'
[
  {"type":"PipeWire:Interface:Node","id":33,"info":{"props":{
    "media.class":"Audio/Sink",
    "node.name":"alsa_output.rk817-sound.stereo-fallback",
    "alsa.id":"rk817ext",
    "alsa.card_name":"rk817_ext",
    "api.alsa.card.name":"rk817_ext"
  }}},
  {"type":"PipeWire:Interface:Node","id":55,"info":{"props":{
    "media.class":"Audio/Sink",
    "node.name":"alsa_output.hdmi-sound.stereo-fallback",
    "alsa.id":"HDMI",
    "alsa.card_name":"HDMI",
    "api.alsa.card.name":"HDMI"
  }}},
  {"type":"PipeWire:Interface:Node","id":44,"info":{"props":{
    "media.class":"Audio/Source",
    "node.name":"alsa_input.rk817-sound.stereo-fallback",
    "alsa.id":"rk817ext"
  }}}
]
EOF
export ZLYME_PW_DUMP=$work/dump.json
export ZLYME_HDMI_AUDIO=0
printf 'ZLYME_VOLUME=40\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
[ "$(sh "$AUDIO" node-id codec)" = 33 ] || fail "codec id from alsa.id"
[ "$(sh "$AUDIO" node-id hdmi)" = 55 ] || fail "hdmi id from alsa.id"
sh "$AUDIO" route || fail "route"
grep -q 'set-default 33' "$WP_LOG" || fail "default stayed on HDMI $(cat "$WP_LOG")"
# Kernel ELD uses tabs. A space-only match treated this display as silent.
unset ZLYME_HDMI_AUDIO
printf 'sad_count\t\t2\n' > "$work/eld"
export ZLYME_HDMI_ELD=$work/eld
: > "$WP_LOG"
sh "$AUDIO" route || fail "tab eld route"
grep -q 'set-default 55' "$WP_LOG" || fail "tab ELD did not select HDMI $(cat "$WP_LOG")"
printf 'sad_count\t\t0\n' > "$work/eld"
: > "$WP_LOG"
sh "$AUDIO" route || fail "empty eld route"
grep -q 'set-default 33' "$WP_LOG" || fail "sad_count 0 left HDMI $(cat "$WP_LOG")"
unset ZLYME_HDMI_ELD
export ZLYME_HDMI_AUDIO=0
grep -q 'set-volume 33 0.064000' "$WP_LOG" || fail "codec gain $(cat "$WP_LOG")"
grep -q 'set-volume 55 0.064000' "$WP_LOG" || fail "hdmi gain"
export ZLYME_HDMI_AUDIO=1
: > "$WP_LOG"
sh "$AUDIO" route || fail "hdmi route"
grep -q 'set-default 55' "$WP_LOG" || fail "ELD did not select HDMI $(cat "$WP_LOG")"
# Late A2DP node. Same graph, one more sink.
python3 - "$work/dump.json" << 'PY'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data.append({"type":"PipeWire:Interface:Node","id":70,"info":{"props":{
    "media.class":"Audio/Sink",
    "node.name":"bluez_output.AA_BB_CC_DD_EE_FF.1",
    "api.alsa.card.id":"rk817ext"
}}})
json.dump(data, open(p, "w"))
PY
: > "$WP_LOG"
sh "$AUDIO" route || fail "bt route"
[ "$(sh "$AUDIO" node-id bt)" = 70 ] || fail "bt id"
grep -q 'set-default 70' "$WP_LOG" || fail "A2DP did not become default $(cat "$WP_LOG")"
grep -q 'set-volume 70 0.064000' "$WP_LOG" || fail "late sink missed the gain"
printf 'ZLYME_VOLUME=0\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 0 || fail "mute"
grep -Eq 'set-volume 33 0$' "$WP_LOG" || grep -q 'set-volume 33 0.000000' "$WP_LOG" || fail "saved 0 was audible $(cat "$WP_LOG")"
: > "$WP_LOG"
sh "$AUDIO" route || fail "repeat route"
if grep -q 'set-default\|set-volume' "$WP_LOG"; then
	fail "unchanged route rewrote the graph $(cat "$WP_LOG")"
fi
: > "$WP_LOG"
sh "$AUDIO" hold 40 || fail "hold"
grep -q '^ZLYME_VOLUME=0$' "$work/cfg/audio.conf" || fail "hold rewrote the saved volume"
grep -q 'set-volume 33 0.064000' "$WP_LOG" || fail "hold did not apply $(cat "$WP_LOG")"
# The old key, present or not, must not be what identifies the codec.
cat > "$work/dump.json" << 'EOF'
[
  {"type":"PipeWire:Interface:Node","id":7,"info":{"props":{
    "media.class":"Audio/Sink",
    "node.name":"alsa_output.rk817-sound.stereo-fallback",
    "api.alsa.card.id":"rk817ext",
    "api.alsa.card.name":"rk817_ext"
  }}}
]
EOF
if sh "$AUDIO" node-id codec >/dev/null 2>&1; then
	fail "api.alsa.card.id was treated as the card id"
fi
pinned=$ROOT/output/build/wireplumber-0.5.14/src/scripts/monitors/alsa.lua
if [ -f "$pinned" ]; then
	grep -q 'add api.alsa.card.\* and alsa.\* properties for rule matching' "$pinned" || fail "pinned monitor no longer copies alsa.* before rules"
fi
grep -q 'XDG_RUNTIME_DIR' "$ROOT/package/system/nextui/nextui-session" || fail "session env"
if grep -q 'PULSE_RUNTIME_PATH=' "$ROOT/package/system/nextui/nextui-session"; then
	fail "session still exports the old pulse path"
fi
# Live discovery uses wpctl inspect, not Python. alsa.id is present.
# api.alsa.card.id is not.
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
case "$1" in
	status)
		printf '%s\n' 'Audio' ' ├─ Sinks:' ' │      33. Built-in Audio Stereo               [vol: 0.09]' ' │  *   55. Built-in Audio Stereo               [vol: 0.09]' ' ├─ Sources:' ' │      44. Built-in Audio Stereo               [vol: 1.00]' 'Video' ' ├─ Sinks:'
		;;
	inspect)
		case "$2" in
			33)
				printf '%s\n' 'media.class = "Audio/Sink"' 'alsa.id = "rk817ext"' 'node.name = "alsa_output.rk817-sound.stereo-fallback"' 'api.alsa.card.name = "rk817_ext"'
				;;
			55)
				printf '%s\n' 'media.class = "Audio/Sink"' 'alsa.id = "HDMI"' 'node.name = "alsa_output.hdmi-sound.stereo-fallback"' 'api.alsa.card.name = "HDMI"'
				;;
		esac
		;;
	*)
		printf '%s\n' "$*" >> "$WP_LOG"
		;;
esac
exit 0
EOF
chmod 755 "$work/bin/wpctl"
unset ZLYME_PW_DUMP ZLYME_PW_NODES
[ "$(sh "$AUDIO" node-id codec)" = 33 ] || fail "wpctl codec id"
[ "$(sh "$AUDIO" node-id hdmi)" = 55 ] || fail "wpctl hdmi id"
saved=$ZLYME_PW_RUNTIME
export ZLYME_PW_RUNTIME=$work/down
mkdir -p "$ZLYME_PW_RUNTIME"
unset ZLYME_PW_NODES ZLYME_PW_DUMP
if sh "$AUDIO" setSystemVolume 10 >/dev/null 2>&1; then
	fail "a down PipeWire service was treated as success"
fi
grep -q '^ZLYME_VOLUME=0$' "$work/cfg/audio.conf" || fail "a down service rewrote the saved volume"
if sh "$AUDIO" route >/dev/null 2>&1; then
	fail "route succeeded without PipeWire"
fi
cat > "$work/bin/speaker-test" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$work/bin/speaker-test"
if sh "$AUDIO" test >/dev/null 2>&1; then
	fail "a failed playback test was success"
fi
export ZLYME_PW_RUNTIME=$saved
# Connected headset with the A2DP Sink UUID, and no bluez node yet.
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
export ZLYME_PW_NODES=$work/nodes
export ZLYME_PW_RUNTIME=$work/rt
unset ZLYME_HDMI_AUDIO ZLYME_HDMI_ELD
cat > "$work/bin/bluetoothctl" << 'EOF'
#!/bin/sh
if [ "$1" = devices ]; then
	echo "Device AA:BB:CC:DD:EE:FF Headset"
	exit 0
fi
if [ "$1" = info ]; then
	echo "Connected: yes"
	echo "UUID: Audio Sink (0000110b-0000-1000-8000-00805f9b34fb)"
	exit 0
fi
exit 0
EOF
cat > "$work/bin/dbus-send" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DBUS_LOG"
exit 0
EOF
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
exit 0
EOF
chmod 755 "$work/bin/bluetoothctl" "$work/bin/dbus-send" "$work/bin/wpctl"
export DBUS_LOG=$work/dbus.log
: > "$DBUS_LOG"
: > "$WP_LOG"
sh "$AUDIO" a2dp-connect || fail "a2dp-connect"
grep -q 'ConnectProfile' "$DBUS_LOG" || fail "A2DP profile was not requested $(cat "$DBUS_LOG")"
grep -q '0000110b-0000-1000-8000-00805f9b34fb' "$DBUS_LOG" || fail "wrong profile"
grep -q 'set-default 55' "$WP_LOG" || fail "route did not keep a sink $(cat "$WP_LOG")"
printf 'codec\t55\nbt\t62\n' > "$work/nodes"
: > "$DBUS_LOG"
sh "$AUDIO" a2dp-connect || fail "a2dp-connect with sink"
if grep -q 'ConnectProfile' "$DBUS_LOG"; then
	fail "ConnectProfile ran although the sink exists"
fi
grep -q 'set-default 62' "$WP_LOG" || fail "existing A2DP sink was not selected"
: > "$WP_LOG"
sh "$AUDIO" route || fail "second route"
if grep -q 'set-default\|set-volume' "$WP_LOG"; then
	fail "second route rewrote a settled sink $(cat "$WP_LOG")"
fi
# A connected HID pad is not an audio sink.
cat > "$work/bin/bluetoothctl" << 'EOF'
#!/bin/sh
if [ "$1" = devices ]; then
	echo "Device 11:22:33:44:55:66 Controller"
	exit 0
fi
if [ "$1" = info ]; then
	echo "Connected: yes"
	echo "UUID: Human Interface Device (00001124-0000-1000-8000-00805f9b34fb)"
	exit 0
fi
exit 0
EOF
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
printf 'codec\n' > "$work/rt/active"
: > "$DBUS_LOG"
sh "$AUDIO" a2dp-connect || fail "hid recovery"
if grep -q 'ConnectProfile' "$DBUS_LOG"; then
	fail "HID pad was asked for A2DP $(cat "$DBUS_LOG")"
fi
# The node appears after the first lookup, as wpctl can lag the hook.
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
printf 'hdmi\n' > "$work/rt/active"
export ZLYME_HDMI_AUDIO=1
printf 'ZLYME_VOLUME=30\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\nZLYME_SINK=codec\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
i=0
while [ "$i" -lt 8 ]; do
	if sh "$AUDIO" node-id bt >/dev/null 2>&1; then
		break
	fi
	if [ "$i" -eq 1 ]; then
		printf 'bt\t62\n' >> "$work/nodes"
	fi
	i=$((i + 1))
done
sh "$AUDIO" route || fail "late visible route"
grep -q 'set-default 62' "$WP_LOG" || fail "late A2DP node did not take auto $(cat "$WP_LOG")"
out=$(sh "$AUDIO" set bt)
[ "$out" = "sink: bt" ] || fail "set printed historical sink: $out"
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
: > "$WP_LOG"
sh "$AUDIO" route || fail "removal route"
grep -q 'set-default 51' "$WP_LOG" || fail "A2DP removal did not fall back $(cat "$WP_LOG")"
echo "pipewire service ok"
