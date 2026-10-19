#!/bin/sh
# Codec and HDMI use one interrupt-mode buffer. Bluetooth stays shorter.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-buffer: $*" >&2; exit 1; }

pa=$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa
audio=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
long='fragments=12 fragment_size=1024'
short='fragments=4 fragment_size=1024'

n=$(grep -F -c "$long" "$pa" "$audio" | awk -F: '{s+=$2} END {print s}')
[ "$n" = 3 ] || fail "expected 3 long buffers, got $n"
grep -q "sink_name=codec .*${long}" "$pa" || fail "boot codec buffer"
grep -q "sink_name=codec .*${long}" "$audio" || fail "codec-up buffer"
grep -q "sink_name=hdmi .*${long}" "$audio" || fail "hdmi buffer"
grep -q "sink_name=bt .*${short}" "$audio" || fail "bluetooth buffer changed"
if grep -E 'sink_name=(codec|hdmi).*fragments=4' "$pa" "$audio"; then
	fail "codec or hdmi still uses 4 fragments"
fi
# Migration copies the percent. It does not turn that percent into dB.
grep -q 'set-sink-volume "$s" "$now%"' "$audio" || fail "migration rescales the percent"
grep -q 'set-sink-volume "$s" "$v%"' "$audio" || fail "volume write is not the saved percent"
echo "pulse buffer ok"
