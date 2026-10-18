#!/bin/sh
# Host policy for the PulseAudio sink switch. No daemon is started.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-policy: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/cfg" "$work/run" "$work/pcms"
cat > "$work/bin/pactl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PULSE_LOG"
case "$1" in
	info) exit 0 ;;
	load-module) echo 42 ;;
	get-sink-volume) echo "Volume: front-left: 1 / 40% / 0 dB" ;;
	*) exit 0 ;;
esac
EOF
chmod 755 "$work/bin/pactl"
export PATH="$work/bin:$PATH"
export PULSE_LOG=$work/log
export PULSE_RUNTIME_PATH=$work/run
export ZLYME_CFG=$work/cfg
export ZLYME_CONF=/dev/null
# zlyme-audio sources zlyme.conf. Give it an empty one.
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/zlyme.conf"
export ZLYME_CONF=$work/zlyme.conf
: > "$PULSE_LOG"
out=$(sh "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" export)
[ "$out" = "ZLYME_SINK=codec; export ZLYME_SINK" ] || fail "export: $out"
sh "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" set hdmi >/dev/null
grep -q 'set-default-sink hdmi' "$PULSE_LOG" || fail "default sink was not moved"
sh "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" setSystemVolume 30 >/dev/null
grep -q 'set-sink-volume codec 30%' "$PULSE_LOG" || fail "volume did not reach every sink"
grep -q 'set-sink-volume hdmi 30%' "$PULSE_LOG" || fail "hdmi volume missed"
grep -q 'set-sink-volume bt 30%' "$PULSE_LOG" || fail "bt volume missed"
printf '%s\n' '/org/bluealsa/hci0/dev_AA_BB_CC_DD_EE_FF/a2dpsrc' > "$work/pcms/list"
export ZLYME_BLUEALSA_LIST=$work/pcms/list
# Drive one decision through the sink helper the daemon uses.
# shellcheck disable=SC1091
mac=$(sed -n 's/.*dev_\([0-9A-Fa-f][0-9A-Fa-f]_\([0-9A-Fa-f][0-9A-Fa-f]_\)\{4\}[0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' "$ZLYME_BLUEALSA_LIST" | head -n 1 | tr _ :)
[ "$mac" = "AA:BB:CC:DD:EE:FF" ] || fail "mac: $mac"
sh "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" sink-up bt "$mac"
grep -q 'bluealsa:DEV=AA:BB:CC:DD:EE:FF,PROFILE=a2dp' "$PULSE_LOG" || fail "bt module"
sh "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" sink-down bt
grep -q 'unload-module 42' "$PULSE_LOG" || fail "bt module stayed"
# HID-only list has no a2dp device address of that form.
printf '%s\n' 'hog-hid' > "$work/pcms/list"
mac=$(sed -n 's/.*dev_\([0-9A-Fa-f][0-9A-Fa-f]_\([0-9A-Fa-f][0-9A-Fa-f]_\)\{4\}[0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' "$ZLYME_BLUEALSA_LIST" | head -n 1 | tr _ :)
[ -z "$mac" ] || fail "hid produced a mac"
grep -q 'module-switch-on-connect' "$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa" && fail "auto-switch module is loaded"
grep -q 'auth-anonymous=1 socket=/run/zlyme/pulse/native' "$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa" || fail "socket"
grep -q 'flat-volumes = no' "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" || fail "flat volumes"
grep -q '2048/48000 = 42.7 ms' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "period comment"
grep -q 'type pulse' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "default pcm"
if grep -q 'killall -9' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-btsink"; then
	fail "a sink change still kills clients"
fi
echo "pulse policy ok"
