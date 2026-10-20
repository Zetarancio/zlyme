#!/bin/sh
# Class A no longer starts a PulseAudio server. PipeWire is rc.late,
# beside input, not in front of it.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
RCS=$ROOT/board/my355/fsoverlay/etc/init.d/rcS
LATE=$ROOT/board/my355/fsoverlay/etc/init.d/rc.late
fail() { echo "pulse-boot: $*" >&2; exit 1; }

if grep -q 'S21pulse' "$RCS"; then
	fail "rcS still whitelists S21pulse"
fi
if [ -e "$ROOT/board/my355/fsoverlay/etc/init.d/S21pulse" ]; then
	fail "S21pulse is still installed"
fi
if [ -e "$ROOT/board/my355/fsoverlay/etc/init.d/S45bluealsa" ]; then
	fail "S45bluealsa is still installed"
fi
if [ -e "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-btsink" ]; then
	fail "zlyme-btsink is still installed"
fi
if [ -e "$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio" ]; then
	fail "S50pulseaudio is still installed"
fi
grep -q 'S33pipewire' "$LATE" || fail "rc.late does not start pipewire"
grep -q 'S21pulse' "$ROOT/board/my355/post-build.sh" || fail "post-build does not drop a stale S21pulse"
# The input block and the pipewire block are separate background groups.
awk '
	/inputplumber-start/ { input = 1 }
	/S33pipewire/ { pipe = NR }
	/inputplumber-start/ { inp = NR }
	END {
		if (!(pipe && inp)) exit 1
	}
' "$LATE" || fail "rc.late lost a service"
if ! timeout 3 sh -c '. "$1"; ZLYME_FRONTEND=/no/such/nextui.elf; wait_boot_list' _ \
	"$ROOT/board/my355/fsoverlay/etc/zlyme.conf"; then
	fail "minimal boot waited for a frontend"
fi
echo "pulse boot ok"
