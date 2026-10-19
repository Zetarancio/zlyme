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
export ZLYME_AUDIO_BACKEND=alsa
export PULSE_LOG=$work/log
export PULSE_STATE=$work/state
export AMIXER_LOG=$work/amixer.log
export PULSE_RUNTIME_PATH=$work/run
export ZLYME_CFG=$work/cfg
printf 'ZLYME_CFG=%s\n' "$work/cfg" > "$work/zlyme.conf"
export ZLYME_CONF=$work/zlyme.conf
: > "$PULSE_LOG"
: > "$AMIXER_LOG"

# Volume migration is once, keeps a mute, and does not rewrite after.
printf '%s\n' "state.rk817ext { name 'FlipVolume' }" > "$work/cfg/asound.state"
printf '%s\n' 'ZLYME_PREMUTE=15' > "$work/cfg/audio.conf"
export AMIXER_PERCENT=0
sh zlyme-audio migrate-volume
grep -q '^ZLYME_VOLUME=0$' "$work/cfg/audio.conf" || fail "mute was not migrated"
grep -q '^ZLYME_VOLUME_SRC=pipewire-cubic$' "$work/cfg/audio.conf" || fail "migration flag"
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
