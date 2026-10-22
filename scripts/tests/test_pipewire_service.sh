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
if sh "$AUDIO" hold 40; then
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
grep -q -F 'bluez5.auto-connect = [ a2dp_sink ]' "$conf" || fail "remote sink is not auto-connected"
if grep -q -F 'bluez5.auto-connect = [ a2dp_source ]' "$conf"; then
	fail "auto-connect uses the local sender role"
fi
if grep -q 'a2dp-connect' "$LAUNCH"; then
	fail "PipeWire ready still starts a second A2DP recovery"
fi
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
grep -q 'channelVolumes' "$lua" || fail "a new sink does not take the saved gain"
if grep -q 'node-removed' "$lua"; then
	fail "volume hook still reroutes on removal"
fi
grep -q 'hdmi-event' "$rules" || fail "HDMI event does not publish ELD"
if grep -q 'zlyme-audio route' "$rules"; then
	fail "udev still chooses a sink"
fi
if grep -q ' &' "$rules"; then
	fail "udev still backgrounds the route"
fi
if grep -q 'zlyme-audio route' "$lua"; then
	fail "volume hook still spawns a router"
fi
if grep -q 'os.execute' "$lua"; then
	fail "volume hook still shells out"
fi
pol=$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-policy.lua
grep -q 'function policy.choose' "$pol" || fail "sink policy is not one function"
if grep -q 'set-default' "$AUDIO"; then
	fail "shell still calls wpctl set-default"
fi
export ZLYME_POLICY=$pol
grep -q 'hold)' "$AUDIO" || fail "transient gain"
if grep -q 'S21pulse' "$ROOT/board/my355/post-build.sh"; then
	fail "post-build still deletes a retired init script"
fi

# Live playback nodes publish alsa.id and do not publish api.alsa.card.id.
# set-default records the node. inspect of the default prints that id.
export WP_DEFAULT=$work/wp-default
rm -f "$WP_DEFAULT"
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
case "$1" in
	set-default)
		printf '%s\n' "$2" > "$WP_DEFAULT"
		;;
	inspect)
		if [ "$2" = "@DEFAULT_AUDIO_SINK@" ] && [ -s "$WP_DEFAULT" ]; then
			printf 'id %s, type PipeWire:Interface:Node\n' "$(cat "$WP_DEFAULT")"
		fi
		;;
esac
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
[ "$(sh "$AUDIO" policy)" = codec ] || fail "silent HDMI was selected"
# Publishing the ELD does not call wpctl set-default.
sh "$AUDIO" route || fail "route"
if grep -q 'set-default' "$WP_LOG"; then
	fail "route set a configured default $(cat "$WP_LOG")"
fi
# Kernel ELD uses tabs. A space-only match treated this display as silent.
unset ZLYME_HDMI_AUDIO
printf 'sad_count\t\t2\n' > "$work/eld"
export ZLYME_HDMI_ELD=$work/eld
[ "$(sh "$AUDIO" policy)" = hdmi ] || fail "tab ELD did not select HDMI"
printf 'sad_count\t\t0\n' > "$work/eld"
[ "$(sh "$AUDIO" policy)" = codec ] || fail "sad_count 0 left HDMI"
unset ZLYME_HDMI_ELD
export ZLYME_HDMI_AUDIO=1
[ "$(sh "$AUDIO" policy)" = hdmi ] || fail "ELD did not select HDMI"
# Late A2DP node. Same graph, one more sink. Auto prefers it.
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
[ "$(sh "$AUDIO" node-id bt)" = 70 ] || fail "bt id"
[ "$(sh "$AUDIO" policy)" = bt ] || fail "A2DP did not become the auto sink"
# An explicit speaker choice is not overridden by the headset.
printf 'ZLYME_VOLUME=40\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=codec\n' > "$work/cfg/audio.conf"
[ "$(sh "$AUDIO" policy)" = codec ] || fail "explicit codec lost to A2DP"
printf 'ZLYME_VOLUME=0\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 0 || fail "mute"
i=0
while [ "$i" -lt 40 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
grep -Eq 'set-volume 33 0$' "$WP_LOG" || grep -q 'set-volume 33 0.000000' "$WP_LOG" || fail "saved 0 was audible $(cat "$WP_LOG")"
: > "$WP_LOG"
sh "$AUDIO" route || fail "repeat route"
if grep -q 'set-default\|set-volume' "$WP_LOG"; then
	fail "unchanged route rewrote the graph $(cat "$WP_LOG")"
fi
# A stale active file is not the preference. Auto still follows the nodes.
printf 'codec\n' > "$work/rt/active"
[ "$(sh "$AUDIO" policy)" = bt ] || fail "stale active file hid the headset"
rm -f "$work/rt/active"
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
: > "$WP_LOG"
if ! sh "$AUDIO" setSystemVolume 10 >/dev/null 2>&1; then
	fail "a down PipeWire service rejected the saved volume"
fi
grep -q '^ZLYME_VOLUME=10$' "$work/cfg/audio.conf" || fail "a down service dropped the saved volume"
if grep -q 'set-volume' "$WP_LOG"; then
	fail "a down service called wpctl $(cat "$WP_LOG")"
fi
sh "$AUDIO" route >/dev/null 2>&1 || fail "ELD publication needs a running graph"
if grep -q 'set-default' "$WP_LOG"; then
	fail "offline publication set a sink $(cat "$WP_LOG")"
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
# No bluez node yet. Auto stays on the codec while the ELD is pending.
# ConnectProfile is PipeWire's one-shot, not a shell command.
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
export ZLYME_PW_NODES=$work/nodes
export ZLYME_PW_RUNTIME=$work/rt
unset ZLYME_HDMI_AUDIO ZLYME_HDMI_ELD
rm -f "$work/rt/active"
printf 'ZLYME_VOLUME=30\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' > "$work/cfg/audio.conf"
[ "$(sh "$AUDIO" policy)" = codec ] || fail "pending ELD entered HDMI"
if grep -q 'ConnectProfile' "$AUDIO"; then
	fail "shell still requests an A2DP profile"
fi
printf 'hdmi\n' > "$work/rt/active"
[ "$(sh "$AUDIO" policy)" = hdmi ] || fail "pending ELD left HDMI"
printf 'codec\n' > "$work/rt/active"
[ "$(sh "$AUDIO" policy)" = codec ] || fail "pending ELD entered HDMI from the codec"
export ZLYME_HDMI_AUDIO=1
rm -f "$work/rt/active"
[ "$(sh "$AUDIO" policy)" = hdmi ] || fail "valid ELD left the speaker"
printf 'bt\t62\n' >> "$work/nodes"
[ "$(sh "$AUDIO" policy)" = bt ] || fail "late A2DP node did not take auto"
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
[ "$(sh "$AUDIO" policy)" = hdmi ] || fail "A2DP removal did not fall back"
out=$(sh "$AUDIO" set bt)
[ "$out" = "preference: bt" ] || fail "set printed a graph claim: $out"
printf 'bt\t62\n' >> "$work/nodes"
[ "$(sh "$AUDIO" policy)" = bt ] || fail "explicit headset was not selected"
printf 'ZLYME_VOLUME=30\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=codec\n' > "$work/cfg/audio.conf"
[ "$(sh "$AUDIO" policy)" = codec ] || fail "explicit codec was overridden"
# Volume apply is not on the caller's clock. One worker applies the
# latest saved percent. A second press does not start a second wpctl.
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
case "$1" in
	set-volume)
		if ! mkdir "$WP_BUSY" 2>/dev/null; then
			echo OVERLAP >> "$WP_LOG"
		fi
		sleep 0.25
		rmdir "$WP_BUSY" 2>/dev/null || true
		;;
esac
exit 0
EOF
chmod 755 "$work/bin/wpctl"
export WP_BUSY=$work/wp-busy
rm -rf "$WP_BUSY" "$ZLYME_PW_RUNTIME/volume.life" "$ZLYME_PW_RUNTIME/volume.state"
printf 'codec\t55\n' > "$work/nodes"
printf 'ZLYME_VOLUME=0\nZLYME_VOLUME_SRC=pipewire-cubic\nZLYME_SINK_PREF=auto\n' > "$work/cfg/audio.conf"
: > "$WP_LOG"
start=$(date +%s%N)
sh "$AUDIO" setSystemVolume 10 || fail "fast volume"
sh "$AUDIO" setSystemVolume 50 || fail "reversed volume"
end=$(date +%s%N)
elapsed=$((end - start))
if [ "$elapsed" -gt 200000000 ]; then
	fail "volume calls blocked on wpctl (${elapsed}ns)"
fi
i=0
while [ "$i" -lt 40 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true || fail "volume worker did not exit"
grep -q '^ZLYME_VOLUME=50$' "$work/cfg/audio.conf" || fail "latest volume was not saved"
if grep -q OVERLAP "$WP_LOG"; then
	fail "two volume workers ran at once"
fi
last=$(grep 'set-volume 55' "$WP_LOG" | tail -n 1)
printf '%s\n' "$last" | grep -q '0.125000' || fail "an older volume won: $last"
# Many reversals still end on the last saved percent.
: > "$WP_LOG"
n=0
while [ "$n" -lt 20 ]; do
	if [ $((n % 2)) -eq 0 ]; then
		sh "$AUDIO" setSystemVolume 5 || fail "rapid down"
	else
		sh "$AUDIO" setSystemVolume 90 || fail "rapid up"
	fi
	n=$((n + 1))
done
i=0
while [ "$i" -lt 80 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true || fail "rapid worker did not exit"
grep -q '^ZLYME_VOLUME=90$' "$work/cfg/audio.conf" || fail "rapid presses lost the last value"
last=$(grep 'set-volume 55' "$WP_LOG" | tail -n 1)
printf '%s\n' "$last" | grep -q '0.729000' || fail "rapid presses applied an older gain: $last"
if grep -q OVERLAP "$WP_LOG"; then
	fail "rapid presses overlapped workers"
fi
# The life lock is the ownership. A caller that arrives before it can
# be taken still saves, and the next caller applies.
exec 8>>"$ZLYME_PW_RUNTIME/volume.life"
flock -n 8 || fail "test could not hold the life lock"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 12 || fail "blocked worker rejected the save"
grep -q '^ZLYME_VOLUME=12$' "$work/cfg/audio.conf" || fail "blocked worker dropped the save"
if grep -q 'set-volume' "$WP_LOG"; then
	fail "a held life lock still started wpctl"
fi
flock -u 8
exec 8>&-
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 12 || fail "released lock rejected the save"
i=0
while [ "$i" -lt 40 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
grep -q 'set-volume 55' "$WP_LOG" || fail "the released lock did not apply"
# Kill the worker mid-apply. The kernel drops the lock. The next press applies.
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
case "$1" in
	set-volume) sleep 2 ;;
esac
exit 0
EOF
chmod 755 "$work/bin/wpctl"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 18 || fail "kill setup"
i=0
while [ "$i" -lt 40 ]; do
	grep -q 'set-volume' "$WP_LOG" && break
	i=$((i + 1))
	sleep 0.05
done
pid=$(ps -eo pid,args | awk '/apply-saved/ && !/awk/ { print $1; exit }')
[ -n "$pid" ] || fail "no volume worker to kill"
kill -9 "$pid" 2>/dev/null || true
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
exit 0
EOF
chmod 755 "$work/bin/wpctl"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 19 || fail "press after kill"
i=0
while [ "$i" -lt 40 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
grep -q 'set-volume 55 0.006859' "$WP_LOG" || fail "a killed worker left the old gain $(cat "$WP_LOG")"
if ps -eo args | awk '/apply-saved/ && !/awk/ { found=1 } END { exit !found }'; then
	fail "a volume worker was left behind"
fi
# A failing wpctl leaves the saved percent and does not retry forever.
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$WP_LOG"
exit 1
EOF
chmod 755 "$work/bin/wpctl"
: > "$WP_LOG"
sh "$AUDIO" setSystemVolume 0 || fail "failed apply rejected the save"
i=0
while [ "$i" -lt 40 ]; do
	flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true && break
	i=$((i + 1))
	sleep 0.05
done
flock -n "$ZLYME_PW_RUNTIME/volume.life" -c true || fail "a failed apply kept running"
grep -q '^ZLYME_VOLUME=0$' "$work/cfg/audio.conf" || fail "saved zero was rewritten"
calls=$(grep -c 'set-volume' "$WP_LOG" || true)
[ "$calls" -eq 1 ] || fail "a failed apply retried ($calls)"
# One HDMI launch can record the event. Twelve lines retire the flag.
trace=$work/hdmi-trace
log=$work/hdmi-trace.log
: > "$trace"
export ZLYME_HDMI_TRACE=$trace ZLYME_HDMI_TRACE_LOG=$log
printf 'codec\t55\nhdmi\t51\n' > "$work/nodes"
export ZLYME_HDMI_AUDIO=1
sh "$AUDIO" hdmi-event || fail "traced event"
grep -q 'eld=yes' "$log" || fail "HDMI trace was empty $(cat "$log")"
grep -q 'choice=' "$log" || fail "HDMI trace omitted the policy $(cat "$log")"
[ -f "$trace" ] || fail "one trace line retired the flag"
printf '%s\n' line line line line line line line line line line line > "$log"
sh "$AUDIO" hdmi-event || fail "retiring event"
[ ! -e "$trace" ] || fail "the HDMI trace flag survived twelve lines"
unset ZLYME_HDMI_TRACE ZLYME_HDMI_TRACE_LOG ZLYME_HDMI_AUDIO
if grep -q 'io.open' "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-policy.lua"; then
	fail "policy hook still opens files"
fi
if grep -q 'io.open' "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-volume.lua"; then
	fail "volume hook still opens files"
fi
lua "$ROOT/scripts/tests/wp_policy_hook.lua" \
	"$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-policy.lua" \
	"$ROOT/board/my355/fsoverlay/usr/share/wireplumber/scripts/zlyme-volume.lua" \
	|| fail "sandbox hook"
# The route file follows the effective default, after apply.
cat > "$work/bin/pw-metadata" << 'EOF'
#!/bin/sh
printf '%s\n' "update: id:0 key:'default.audio.sink' value:'{\"name\":\"alsa_output._sys_devices_platform_hdmi-sound_sound_card0.stereo-fallback\"}' type:'Spa:String:JSON'"
EOF
chmod 755 "$work/bin/pw-metadata"
rm -f "$work/rt/active"
sh "$AUDIO" follow || fail "follow exited"
grep -qx hdmi "$work/rt/active" || fail "follow did not publish hdmi $(cat "$work/rt/active" 2>/dev/null)"
cat > "$work/bin/pw-metadata" << 'EOF'
#!/bin/sh
printf '%s\n' "update: id:0 key:'default.audio.sink' value:'{\"name\":\"bluez_output.TEST\"}' type:'Spa:String:JSON'"
EOF
sh "$AUDIO" follow || fail "follow headset"
grep -qx bt "$work/rt/active" || fail "follow did not publish bt"
# A connected connector can report sad_count 0 and gain a format later.
# The recheck publishes the new ELD and then stops.
drm=$work/drm/card0-HDMI-A-1
mkdir -p "$drm"
printf '%s\n' connected > "$drm/status"
printf 'sad_count 0\n' > "$work/eld"
export ZLYME_HDMI_ELD=$work/eld ZLYME_HDMI_SYSFS=$work/drm
export ZLYME_HDMI_RECHECK_TRIES=5 ZLYME_HDMI_RECHECK_INTERVAL=0.2
unset ZLYME_HDMI_AUDIO ZLYME_HDMI_RECHECK
sh "$AUDIO" hdmi-event || fail "initial ELD"
grep -qx no "$work/rt/hdmi-audio" || fail "parsed empty ELD was not no"
( sleep 0.3; printf 'sad_count\t2\n' > "$work/eld" ) &
sh "$AUDIO" hdmi-recheck || fail "recheck"
grep -qx yes "$work/rt/hdmi-audio" || fail "late ELD stayed unpublished"
echo "pipewire service ok"
