#!/bin/sh
# The Pulse daemon configuration is gone. pipewire-pulse does not read it.
# A returned daemon.conf must not disable remixing: that mapping leaves
# a mono client silent on a stereo sink.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-remix: $*" >&2; exit 1; }
if [ -e "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" ]; then
	fail "daemon.conf is back"
fi
if [ -e "$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa" ]; then
	fail "zlyme.pa is back"
fi
echo "pulse remix ok"
