#!/bin/sh
# Host policy for the PulseAudio sink switch. The pactl here is a fake.
# A live server is scripts/tests/test_pulse_integrate.sh.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-policy: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/cfg" "$work/run" "$work/pcms" "$work/state"
printf '0\n' > "$work/state/nextid"
: > "$work/state/modules"
cat > "$work/bin/pactl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PULSE_LOG"
case "$1" in
	info) exit 0 ;;
	list)
		if [ "$2" = short ] && [ "$3" = sinks ]; then
			printf '%s\n' "0	codec	module"
			exit 0
		fi
		if [ "$2" = short ] && [ "$3" = modules ]; then
			[ -s "$PULSE_STATE/modules" ] && cat "$PULSE_STATE/modules"
			exit 0
		fi
		if [ "$2" = short ] && [ "$3" = sink-inputs ]; then
			printf '%s\n' "7	0	0	native"
			exit 0
		fi
		exit 0
		;;
	load-module)
		id=$(cat "$PULSE_STATE/nextid")
		id=$((id + 1))
		printf '%s\n' "$id" > "$PULSE_STATE/nextid"
		printf '%s\tmodule-alsa-sink\t%s\n' "$id" "$*" >> "$PULSE_STATE/modules"
		printf '%s\n' "$id"
		;;
	unload-module)
		id=$2
		grep -v "^${id}	" "$PULSE_STATE/modules" > "$PULSE_STATE/modules.new" || true
		mv "$PULSE_STATE/modules.new" "$PULSE_STATE/modules"
		;;
	get-sink-volume) echo "Volume: front-left: 1 / 40% / 0 dB" ;;
	*) exit 0 ;;
esac
EOF
chmod 755 "$work/bin/pactl"
export PATH="$work/bin:$PATH"
export PULSE_LOG=$work/log
export PULSE_STATE=$work/state
export PULSE_RUNTIME_PATH=$work/run
export ZLYME_CFG=$work/cfg
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/zlyme.conf"
export ZLYME_CONF=$work/zlyme.conf
: > "$PULSE_LOG"
AUDIO=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
out=$(sh "$AUDIO" export)
printf '%s\n' "$out" | grep -qx 'ZLYME_SINK=codec; export ZLYME_SINK' || fail "export: $out"
cat > "$work/bin/wpctl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PULSE_LOG"
exit 0
EOF
chmod 755 "$work/bin/wpctl"
printf '%s\n' 'codec	1' 'hdmi	2' 'bt	3' > "$work/nodes"
export ZLYME_WPCTL=$work/bin/wpctl
export ZLYME_PW_NODES=$work/nodes
export ZLYME_HDMI_AUDIO=1
sh "$AUDIO" set hdmi >/dev/null
grep -q 'set-default 2' "$PULSE_LOG" || fail "default sink was not moved"
sh "$AUDIO" setSystemVolume 30 >/dev/null
grep -q 'set-volume 1 0.027000' "$PULSE_LOG" || fail "cubic gain was not applied"
cp "$work/cfg/audio.conf" "$work/cfg/audio.conf.before"
sh "$AUDIO" setSystemVolume 30 >/dev/null
cmp "$work/cfg/audio.conf.before" "$work/cfg/audio.conf" || fail "unchanged volume rewrote audio.conf"
sh "$AUDIO" set auto >/dev/null
grep -q 'set-default 3' "$PULSE_LOG" || fail "auto did not prefer bluetooth"
PA=$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa
grep -q 'module-switch-on-connect' "$PA" && fail "auto-switch module is loaded"
grep -q 'module-bluez5' "$PA" && fail "Pulse owns A2DP"
grep -q 'module-native-protocol-tcp' "$PA" && fail "tcp listener"
grep -q 'auth-anonymous=0' "$PA" || fail "anonymous auth"
grep -q 'auth-anonymous=1' "$PA" && fail "anonymous auth is on"
grep -q 'flat-volumes = no' "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" || fail "flat volumes"
grep -q '2048/48000 = 42.7 ms' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "period comment"
grep -q 'flipdmix_codec' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "overlay default pcm"
grep -q 'hw:rk817ext,0' "$PA" || fail "codec sink does not open the hardware device"
grep -q 'autospawn = no' "$ROOT/board/my355/fsoverlay/etc/pulse/client.conf" || fail "autospawn"
grep -q 'unix:/run/zlyme/pipewire/pulse/native' "$ROOT/board/my355/fsoverlay/etc/pulse/client.conf" || fail "pulse socket"
S21=$ROOT/board/my355/fsoverlay/etc/init.d/S21pulse
LAUNCH=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pulse-launch
grep -q 'zlyme-pulse-launch' "$S21" || fail "S21pulse does not use the launcher"
if grep -v '^[[:space:]]*#' "$LAUNCH" | grep -q -- '--system'; then
	fail "launcher passes --system"
fi
grep -q -- '-n' "$LAUNCH" || fail "system.pa would also load"
grep -q -- '--file=' "$LAUNCH" || fail "startup file is not passed"
grep -q -- '--disallow-module-loading' "$S21" && fail "dynamic sinks are blocked"
grep -q 'echo OK' "$S21" && fail "startup says OK"
grep -q 'pulse-service' "$S21" || fail "no usable-sink check"
grep -q 'codec-up' "$S21" || fail "codec sink is not retried"
grep -q 'ready_check "$token" &' "$S21" || fail "readiness blocks the caller"
grep -q 'chmod 0700' "$S21" || fail "socket directory is not private"
grep -q '^exit 0$' "$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio" || fail "second server script"
if grep -q 'killall -9' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-btsink"; then
	fail "a sink change still kills clients"
fi
echo "pulse policy ok"
