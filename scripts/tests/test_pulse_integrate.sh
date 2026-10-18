#!/bin/sh
# Real libpulse client. A private daemon is used when the host has one.
# This does not open the host's default sound card.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-integrate: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/run" "$work/state" "$work/cfg"
cat > "$work/client.conf" << EOF
autospawn = no
default-server = unix:$work/run/native
cookie-file = $work/run/cookie
EOF
cat > "$work/noserver.c" << 'EOF'
#include <pulse/simple.h>
#include <pulse/error.h>
int main(void)
{
    pa_sample_spec ss = { PA_SAMPLE_S16LE, 48000, 2 };
    int err = 0;
    pa_simple *s = pa_simple_new(NULL, "zlyme-test", PA_STREAM_PLAYBACK,
                                 NULL, "tone", &ss, NULL, NULL, &err);
    if (s) {
        pa_simple_free(s);
        return 0;
    }
    return 1;
}
EOF
cc -std=c11 -Wall -Wextra -Werror -o "$work/noserver" "$work/noserver.c" -lpulse-simple
if PULSE_CLIENTCONFIG="$work/client.conf" "$work/noserver"; then
	fail "libpulse connected or autospawned without a server"
fi
echo "pulse-integrate: autospawn refused"

if ! command -v pulseaudio >/dev/null 2>&1; then
	echo "pulse-integrate: LIVE hardware-pending (this host has no pulseaudio daemon)"
	exit 0
fi

cat > "$work/null.pa" << EOF
.fail
load-module module-native-protocol-unix auth-anonymous=0 auth-cookie=$work/run/cookie auth-cookie-enabled=1 socket=$work/run/native
load-module module-null-sink sink_name=codec channels=2 rate=48000 format=s16le
set-default-sink codec
EOF
if ! pulseaudio --daemonize=yes --exit-idle-time=-1 --fail \
	--use-pid-file=no \
	--file="$work/null.pa" \
	--log-target=stderr \
	-n; then
	fail "private daemon did not start"
fi
cleanup() {
	PULSE_CLIENTCONFIG="$work/client.conf" pactl exit >/dev/null 2>&1 || true
}
trap 'cleanup; rm -rf "$work"' EXIT
PULSE_CLIENTCONFIG="$work/client.conf" pactl info >/dev/null
PULSE_CLIENTCONFIG="$work/client.conf" "$work/noserver" || fail "libpulse-simple did not connect"
# ALSA's pulse plugin is optional on the host. Skip that one client if the
# plugin is absent; the native client above already connected.
if [ -e /usr/lib/alsa-lib/libasound_module_pcm_pulse.so ] ||
	[ -e /usr/lib64/alsa-lib/libasound_module_pcm_pulse.so ]; then
	printf '%s\n' "pcm.!default { type pulse }" > "$work/asound.conf"
	ALSA_CONFIG_PATH="$work/asound.conf" speaker-test -D default -c 2 -r 48000 -f S16_LE -t sine -l 1 >/dev/null 2>&1 ||
		fail "ALSA pulse plugin did not play"
else
	echo "pulse-integrate: host ALSA pulse plugin absent"
fi
PULSE_CLIENTCONFIG="$work/client.conf" pactl set-default-sink codec
PULSE_CLIENTCONFIG="$work/client.conf" pactl set-sink-volume codec 30%
PULSE_CLIENTCONFIG="$work/client.conf" pactl set-sink-mute codec 1
PULSE_CLIENTCONFIG="$work/client.conf" pactl set-sink-mute codec 0
mod=$(PULSE_CLIENTCONFIG="$work/client.conf" pactl load-module module-null-sink sink_name=extra)
PULSE_CLIENTCONFIG="$work/client.conf" pactl unload-module "$mod"
# Restart and confirm the client does not autospawn a second server.
PULSE_CLIENTCONFIG="$work/client.conf" pactl exit || true
sleep 0.2
if PULSE_CLIENTCONFIG="$work/client.conf" "$work/noserver"; then
	fail "client autospawned after the daemon exited"
fi
echo "pulse-integrate: private server ok"
