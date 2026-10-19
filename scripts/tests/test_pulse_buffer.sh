#!/bin/sh
# Codec and HDMI use one interrupt-mode buffer. Bluetooth stays shorter.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-buffer: $*" >&2; exit 1; }

audio=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
conf=$ROOT/configs/zlyme_my355_defconfig
grep -q '^BR2_PACKAGE_PIPEWIRE=y$' "$conf" || fail "pipewire is not selected"
grep -q '^BR2_PACKAGE_WIREPLUMBER=y$' "$conf" || fail "wireplumber is not selected"
if grep -q '^BR2_PACKAGE_PULSEAUDIO_DAEMON=y$' "$conf"; then
	fail "pulse daemon is still selected"
fi
if grep -q '^BR2_PACKAGE_BLUEZ_ALSA=y$' "$conf"; then
	fail "bluealsa is still selected"
fi
grep -q 'pipewire-cubic' "$audio" || fail "volume curve marker missing"
if grep -q 'load-module module-alsa-sink' "$audio"; then
	fail "zlyme-audio still loads Pulse sinks"
fi
echo "pulse buffer ok"
