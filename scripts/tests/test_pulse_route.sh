#!/bin/sh
# Retry and one-time volume migration. pactl and amixer are fakes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-route: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/cfg" "$work/run" "$work/state" "$work/pcms"
printf '0\n' > "$work/state/nextid"
printf '0\n' > "$work/state/info-count"
: > "$work/state/modules"
cat > "$work/bin/pactl" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PULSE_LOG"
case "$1" in
	info)
		n=$(cat "$PULSE_STATE/info-count")
		n=$((n + 1))
		printf '%s\n' "$n" > "$PULSE_STATE/info-count"
		[ "$n" -ge "${PULSE_INFO_OK_AFTER:-1}" ]
		;;
	list)
		if [ "$2" = short ] && [ "$3" = sinks ]; then
			printf '%s\n' "0	codec	module"
			exit 0
		fi
		if [ "$2" = short ] && [ "$3" = modules ]; then
			[ -s "$PULSE_STATE/modules" ] && cat "$PULSE_STATE/modules"
			exit 0
		fi
		exit 0
		;;
	load-module)
		if [ "${PULSE_LOAD_FAIL:-}" = 1 ]; then
			echo "load failed" >&2
			exit 1
		fi
		id=$(cat "$PULSE_STATE/nextid")
		id=$((id + 1))
		printf '%s\n' "$id" > "$PULSE_STATE/nextid"
		printf '%s\tmodule-alsa-sink\t%s\n' "$id" "$*" >> "$PULSE_STATE/modules"
		printf '%s\n' "$id"
		;;
	unload-module)
		grep -v "^${2}	" "$PULSE_STATE/modules" > "$PULSE_STATE/modules.new" || true
		mv "$PULSE_STATE/modules.new" "$PULSE_STATE/modules"
		;;
	get-sink-volume) echo "Volume: front-left: 1 / 40% / 0 dB" ;;
	*) exit 0 ;;
esac
EOF
cat > "$work/bin/amixer" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AMIXER_LOG"
if [ "${AMIXER_PERCENT:-}" = "" ]; then
	exit 1
fi
echo "Mono: [${AMIXER_PERCENT}%]"
EOF
cat > "$work/bin/bluealsa-cli" << 'EOF'
#!/bin/sh
n=0
[ -f "$PULSE_STATE/bt-calls" ] && n=$(cat "$PULSE_STATE/bt-calls")
n=$((n + 1))
printf '%s\n' "$n" > "$PULSE_STATE/bt-calls"
after=${BLUEALSA_BT_AFTER:-999}
if [ "$n" -ge "$after" ]; then
	cat "$ZLYME_BLUEALSA_LIST"
else
	printf '%s\n' 'hog-hid'
fi
EOF
chmod 755 "$work/bin/pactl" "$work/bin/amixer" "$work/bin/bluealsa-cli"
export PATH="$ROOT/board/my355/fsoverlay/usr/sbin:$work/bin:$PATH"
export PULSE_LOG=$work/log
export PULSE_STATE=$work/state
export AMIXER_LOG=$work/amixer.log
export PULSE_RUNTIME_PATH=$work/run
export ZLYME_CFG=$work/cfg
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/zlyme.conf"
export ZLYME_CONF=$work/zlyme.conf
: > "$PULSE_LOG"
: > "$AMIXER_LOG"

# Server down on the first probe. The choice must not stick.
export PULSE_INFO_OK_AFTER=99
out=$(ZLYME_BTSINK_LIMIT=1 ZLYME_BTSINK_SLEEP=0 zlyme-btsink)
[ "$out" = "prev=" ] || fail "failed apply was remembered: $out"
infos=$(grep -c '^info$' "$PULSE_LOG" || true)
[ "$infos" = 1 ] || fail "first pass info count $infos"

# The next passes see a server and must apply, not skip.
export PULSE_INFO_OK_AFTER=1
printf '0\n' > "$work/state/info-count"
: > "$PULSE_LOG"
out=$(ZLYME_BTSINK_LIMIT=1 ZLYME_BTSINK_SLEEP=0 zlyme-btsink)
[ "$out" = "prev=codec" ] || fail "retry did not apply codec: $out"

# Codec is applied on the first pass. The headset has to be seen twice
# before it replaces codec, and a later pass must not load it again.
printf '%s\n' '/org/bluealsa/hci0/dev_AA_BB_CC_DD_EE_FF/a2dpsrc' > "$work/pcms/list"
export ZLYME_BLUEALSA_LIST=$work/pcms/list
export BLUEALSA_BT_AFTER=2
printf '0\n' > "$work/state/bt-calls"
: > "$PULSE_LOG"
: > "$work/state/modules"
printf '0\n' > "$work/state/nextid"
out=$(ZLYME_BTSINK_LIMIT=4 ZLYME_BTSINK_SLEEP=0 zlyme-btsink)
[ "$out" = "prev=bt" ] || fail "headset was not selected: $out"
loads=$(grep -c 'load-module module-alsa-sink' "$PULSE_LOG" || true)
[ "$loads" = 1 ] || fail "headset module loads: $loads"

# A failed headset load must not drop the HDMI sink first.
printf '9\tmodule-alsa-sink\tdevice=hw:HDMI,0 sink_name=hdmi\n' > "$work/state/modules"
export PULSE_LOAD_FAIL=1
export BLUEALSA_BT_AFTER=1
printf '0\n' > "$work/state/bt-calls"
: > "$PULSE_LOG"
out=$(ZLYME_BTSINK_LIMIT=1 ZLYME_BTSINK_SLEEP=0 ZLYME_BTSINK_SLOW=0 zlyme-btsink)
[ "$out" = "prev=" ] || fail "failed headset was remembered: $out"
grep -q '^9	' "$work/state/modules" || fail "HDMI sink was removed before Bluetooth existed"
unset PULSE_LOAD_FAIL

# Volume migration is once, keeps a mute, and does not rewrite after.
printf '%s\n' "state.rk817ext { name 'FlipVolume' }" > "$work/cfg/asound.state"
printf '%s\n' 'ZLYME_PREMUTE=15' > "$work/cfg/audio.conf"
export AMIXER_PERCENT=0
sh zlyme-audio migrate-volume
grep -q '^ZLYME_VOLUME=0$' "$work/cfg/audio.conf" || fail "mute was not migrated"
grep -q '^ZLYME_VOLUME_SRC=flipvolume$' "$work/cfg/audio.conf" || fail "migration flag"
grep -q '^ZLYME_PREMUTE=15$' "$work/cfg/audio.conf" || fail "pre-mute was dropped"
cp "$work/cfg/audio.conf" "$work/cfg/audio.conf.once"
export AMIXER_PERCENT=90
sh zlyme-audio migrate-volume
cmp "$work/cfg/audio.conf.once" "$work/cfg/audio.conf" || fail "migration ran twice"
# No saved FlipVolume: 40, not the plugin default of 100.
rm -f "$work/cfg/audio.conf" "$work/cfg/asound.state"
unset AMIXER_PERCENT
sh zlyme-audio migrate-volume
grep -q '^ZLYME_VOLUME=40$' "$work/cfg/audio.conf" || fail "missing mixer did not use 40"
# A saved mixer level is copied, including a value above 100 clamped.
printf '%s\n' "name 'FlipVolume'" > "$work/cfg/asound.state"
rm -f "$work/cfg/audio.conf"
export AMIXER_PERCENT=140
sh zlyme-audio migrate-volume
grep -q '^ZLYME_VOLUME=100$' "$work/cfg/audio.conf" || fail "volume was not clamped"
echo "pulse route ok"
