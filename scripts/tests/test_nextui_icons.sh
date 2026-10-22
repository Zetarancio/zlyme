#!/bin/sh
# Asset choice for the status bar and the volume pill.
# This is the LoveRetro/NextUI 5291344 rule, with one layout correction:
# an external sink is drawn even when it is the only extra mark.
set -eu
fail() { echo "nextui-icons: $*" >&2; exit 1; }
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
api=$ROOT/../NextUI/workspace/all/common/api.c
[ -f "$api" ] || api=/home/ale/NextUI/workspace/all/common/api.c
[ -f "$api" ] || fail "api.c missing"

grep -q 'GetAudioSink() == AUDIO_SINK_BLUETOOTH' "$api" || fail "volume pill ignores the sink"
grep -q 'setting_value > 0 ? ASSET_BLUETOOTH : ASSET_BLUETOOTH_OFF' "$api" || fail "bluetooth volume assets"
grep -q 'int show_bt = BT_isConnected();' "$api" || fail "status bar radio mark"
grep -q 'GetAudioSink() != AUDIO_SINK_DEFAULT' "$api" || fail "external sink mark"
if grep -q 'GFX_zlymeRoute' "$api"; then
	fail "status bar still uses the route character"
fi

# bt radio, sink, volume -> status marks, pill asset
# sink: default bluetooth hdmi
# radio: 0 1
# volume: 0 40
decide() {
	radio=$1
	sink=$2
	volume=$3
	bar_bt=none
	bar_ext=none
	pill=volume
	[ "$radio" = 1 ] && bar_bt=bluetooth
	[ "$sink" != default ] && bar_ext=audio
	if [ "$sink" = bluetooth ]; then
		if [ "$volume" -gt 0 ]; then
			pill=bluetooth
		else
			pill=bluetooth_off
		fi
	else
		if [ "$volume" -gt 0 ]; then
			pill=volume
		else
			pill=mute
		fi
	fi
	printf '%s %s %s\n' "$bar_bt" "$bar_ext" "$pill"
}

check() {
	got=$(decide "$1" "$2" "$3")
	[ "$got" = "$4" ] || fail "$1 $2 $3: got '$got' want '$4'"
}

check 0 default 40 "none none volume"
check 0 default 0 "none none mute"
check 1 default 40 "bluetooth none volume"
check 1 default 0 "bluetooth none mute"
check 1 bluetooth 40 "bluetooth audio bluetooth"
check 1 bluetooth 0 "bluetooth audio bluetooth_off"
check 0 bluetooth 40 "none audio bluetooth"
check 0 hdmi 40 "none audio volume"
check 0 hdmi 0 "none audio mute"
check 1 hdmi 40 "bluetooth audio volume"
echo "nextui icons ok"
