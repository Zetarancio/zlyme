#!/bin/sh
# Codec and HDMI use one interrupt-mode buffer. Bluetooth stays shorter.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-buffer: $*" >&2; exit 1; }

audio=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
for conf in "$ROOT/configs/zlyme_my355_defconfig" "$ROOT/configs/zlyme_my355_minimal_defconfig"; do
	grep -q '^BR2_PACKAGE_PIPEWIRE=y$' "$conf" || fail "pipewire is not selected in $conf"
	grep -q '^BR2_PACKAGE_WIREPLUMBER=y$' "$conf" || fail "wireplumber is not selected in $conf"
	grep -q '^BR2_PACKAGE_PULSEAUDIO=y$' "$conf" || fail "libpulse is not selected in $conf"
	grep -q '^BR2_PACKAGE_SBC=y$' "$conf" || fail "sbc is not selected in $conf"
	if grep -q '^BR2_PACKAGE_PULSEAUDIO_DAEMON=y$' "$conf"; then
		fail "pulse daemon is still selected in $conf"
	fi
	if grep -q '^BR2_PACKAGE_BLUEZ_ALSA=y$' "$conf"; then
		fail "bluealsa is still selected in $conf"
	fi
done
grep -q 'pipewire-cubic' "$audio" || fail "volume curve marker missing"
if grep -q 'load-module module-alsa-sink' "$audio"; then
	fail "zlyme-audio still loads Pulse sinks"
fi
echo "pulse buffer ok"
