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
[ "$out" = "ZLYME_SINK=codec; export ZLYME_SINK" ] || fail "export: $out"
sh "$AUDIO" set hdmi >/dev/null
grep -q 'set-default-sink hdmi' "$PULSE_LOG" || fail "default sink was not moved"
sh "$AUDIO" setSystemVolume 30 >/dev/null
grep -q 'set-sink-volume codec 30%' "$PULSE_LOG" || fail "volume did not reach every sink"
grep -q 'set-sink-volume hdmi 30%' "$PULSE_LOG" || fail "hdmi volume missed"
grep -q 'set-sink-volume bt 30%' "$PULSE_LOG" || fail "bt volume missed"
# Writing the same volume again must not rewrite the state file.
cp "$work/cfg/audio.conf" "$work/cfg/audio.conf.before"
sh "$AUDIO" setSystemVolume 30 >/dev/null
cmp "$work/cfg/audio.conf.before" "$work/cfg/audio.conf" || fail "unchanged volume rewrote audio.conf"
printf '%s\n' '/org/bluealsa/hci0/dev_AA_BB_CC_DD_EE_FF/a2dpsrc' > "$work/pcms/list"
export ZLYME_BLUEALSA_LIST=$work/pcms/list
mac=$(sed -n 's/.*dev_\([0-9A-Fa-f][0-9A-Fa-f]_\([0-9A-Fa-f][0-9A-Fa-f]_\)\{4\}[0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' "$ZLYME_BLUEALSA_LIST" | head -n 1 | tr _ :)
[ "$mac" = "AA:BB:CC:DD:EE:FF" ] || fail "mac: $mac"
sh "$AUDIO" sink-up bt "$mac"
grep -q 'bluealsa:DEV=AA:BB:CC:DD:EE:FF,PROFILE=a2dp' "$PULSE_LOG" || fail "bt module"
sh "$AUDIO" sink-up bt "$mac"
loads=$(grep -c 'load-module module-alsa-sink' "$PULSE_LOG" || true)
[ "$loads" = 1 ] || fail "second load of the same headset: $loads"
sh "$AUDIO" sink-ok bt "$mac"
printf '%s\n' '/org/bluealsa/hci0/dev_11_22_33_44_55_66/a2dpsrc' > "$work/pcms/list"
mac2=$(sed -n 's/.*dev_\([0-9A-Fa-f][0-9A-Fa-f]_\([0-9A-Fa-f][0-9A-Fa-f]_\)\{4\}[0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' "$ZLYME_BLUEALSA_LIST" | head -n 1 | tr _ :)
sh "$AUDIO" sink-up bt "$mac2"
grep -q 'bluealsa:DEV=11:22:33:44:55:66,PROFILE=a2dp' "$PULSE_LOG" || fail "second headset was not loaded"
grep -q 'unload-module' "$PULSE_LOG" || fail "previous headset was not unloaded"
loads=$(grep -c 'load-module module-alsa-sink' "$PULSE_LOG" || true)
[ "$loads" = 2 ] || fail "headset switch loaded $loads modules"
sh "$AUDIO" sink-down bt
[ ! -s "$work/state/modules" ] || fail "bt module stayed"
printf '%s\n' 'hog-hid' > "$work/pcms/list"
mac=$(sed -n 's/.*dev_\([0-9A-Fa-f][0-9A-Fa-f]_\([0-9A-Fa-f][0-9A-Fa-f]_\)\{4\}[0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' "$ZLYME_BLUEALSA_LIST" | head -n 1 | tr _ :)
[ -z "$mac" ] || fail "hid produced a mac"
PA=$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa
grep -q 'module-switch-on-connect' "$PA" && fail "auto-switch module is loaded"
grep -q 'module-bluez5' "$PA" && fail "Pulse owns A2DP"
grep -q 'module-native-protocol-tcp' "$PA" && fail "tcp listener"
grep -q 'auth-anonymous=0' "$PA" || fail "anonymous auth"
grep -q 'auth-anonymous=1' "$PA" && fail "anonymous auth is on"
grep -q 'auth-cookie=/run/zlyme/pulse/cookie' "$PA" || fail "cookie path"
grep -q 'flat-volumes = no' "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" || fail "flat volumes"
grep -q '2048/48000 = 42.7 ms' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "period comment"
grep -q 'type pulse' "$ROOT/board/my355/fsoverlay/etc/asound.conf" || fail "default pcm"
grep -q 'hw:rk817ext,0' "$PA" || fail "codec sink does not open the hardware device"
grep -q 'autospawn = no' "$ROOT/board/my355/fsoverlay/etc/pulse/client.conf" || fail "autospawn"
grep -q 'cookie-file = /run/zlyme/pulse/cookie' "$ROOT/board/my355/fsoverlay/etc/pulse/client.conf" || fail "client cookie"
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
