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
# The first frame is earlier than both services. A card that exists
# before WirePlumber, one that appears after PipeWire is ready, and one
# that appears after that frame all use the same device rule.
awk '
	/nextui-first-flip/ && !frame { frame = NR }
	/S40bluetoothd/ && !bt { bt = NR }
	/S33pipewire/ && !pw { pw = NR }
	END {
		if (!(frame && bt && pw)) exit 1
		if (frame > bt || frame > pw) exit 1
	}
' "$LATE" || fail "bluetooth or pipewire starts before the first frame"
if grep -q 'S33pipewire\|S40bluetoothd' "$RCS"; then
	fail "rcS starts audio or bluetooth before the frontend"
fi
conf=$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf
grep -q 'device.name = "~bluez_card.\*"' "$conf" || fail "auto-connect is not a card rule"
if grep -q 'a2dp-connect' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pipewire-launch"; then
	fail "ready path still connects once"
fi
if grep -q 'S21pulse\|S45bluealsa\|S46btsink\|zlyme-btsink\|flip-jackd' "$ROOT/board/my355/post-build.sh"; then
	fail "post-build still deletes retired files"
fi
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
