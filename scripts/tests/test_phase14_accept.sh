#!/bin/sh
# shellcheck disable=SC1007
# Phase 14 acceptance inventory.
# Columns are SOURCE, HOST, HARDWARE, and USER-AUDIBLE.
# A SOURCE pass is a text check. It is not a Flip result.
# HARDWARE and USER-AUDIBLE values below are a static inventory.
# This script does not SSH. A linked PipeWire stream is not a listen.
# HDMI and Bluetooth audibility on 6ea59c stay PENDING until the
# maintainer records hearing that image.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail=0
row() { printf '%-44s %-8s %-8s %-10s %-12s\n' "$1" "$2" "$3" "$4" "$5"; }

need() {
	if grep -q "$2" "$1"; then
		row "$3" PASS PASS n/a n/a
	else
		row "$3" FAIL FAIL n/a n/a
		fail=1
	fi
}
absent() {
	if grep -q "$2" "$1"; then
		row "$3" FAIL FAIL n/a n/a
		fail=1
	else
		row "$3" PASS PASS n/a n/a
	fi
}

row CHECK SOURCE HOST HARDWARE USER-AUDIBLE

if [ -e "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" ]; then
	row "no Pulse daemon.conf" FAIL FAIL n/a n/a
	fail=1
else
	row "no Pulse daemon.conf" PASS PASS n/a n/a
fi
need "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf" 'alsa.id = "rk817ext"' \
	"codec match uses alsa.id"
need "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pipewire-launch" 'pipewire-pulse' \
	"pipewire-pulse is started as its own argv"
need "$ROOT/package/system/nextui/nextui.mk" 'b0960dcde4d69d32871d6605c354b1b901621eb5' \
	"NextUI pin separates a radio link from the playing sink"
need "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio" '@DEFAULT_AUDIO_SINK@' \
	"route reads the PipeWire default"
NEXT=${ZLYME_NEXTUI_SRC:-$ROOT/../NextUI}
need "$NEXT/workspace/all/nextui/nextui.c" 'zlyme_recent_bg_choice' \
	"Recently Played resolves without the folder"
if [ -e "$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio" ]; then
	row "no Pulse init script in the overlay" FAIL FAIL n/a n/a
	fail=1
else
	row "no Pulse init script in the overlay" PASS PASS n/a n/a
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/USB Transfer.pak" ]; then
	row "USB Transfer pak is the stock name" PASS PASS n/a n/a
else
	row "USB Transfer pak is the stock name" FAIL FAIL n/a n/a
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/USB File Transfer.pak" ]; then
	row "old USB File Transfer pak is gone" FAIL FAIL n/a n/a
	fail=1
else
	row "old USB File Transfer pak is gone" PASS PASS n/a n/a
fi
need "$ROOT/package/system/portmaster/control.txt" '^DEVICE_HAS_ARMHF=Y$' \
	"ARMHF capability bit is on"

row "speaker/headphones on 0d8a3cf" n/a n/a HEARD HEARD
row "headphone jack on 0d8a3cf" n/a n/a HEARD HEARD
row "speaker quality on 00e6c343" n/a n/a FAIL FAIL
row "HDMI quality on 00e6c343" n/a n/a HEARD FAIL
row "BT audio on 00e6c343" n/a n/a HEARD HEARD
row "A2DP transport on 6ea59c" n/a n/a OBSERVED n/a
row "HDMI graph on 6ea59c" n/a n/a OBSERVED n/a
row "BT audibility on 6ea59c" n/a n/a PENDING PENDING
row "HDMI audibility on 6ea59c" n/a n/a PENDING PENDING
row "RetroArch BT listen" n/a n/a PENDING PENDING
row "RetroArch HDMI listen" n/a n/a PENDING PENDING
row "A2DP default on 7eb86d2" n/a n/a OBSERVED n/a
row "BT routed to RK817 on 7eb86d2" n/a n/a OBSERVED FAIL
row "HDMI audibility on 7eb86d2" n/a n/a PENDING PENDING
row "RetroArch BT on b8b490" n/a n/a n/a PASS
row "PPSSPP BT on b8b490" n/a n/a n/a PASS
row "BT headset indicator on b8b490" n/a n/a FAIL n/a
row "volume response on b8b490" n/a n/a FAIL n/a
row "HDMI audibility on b8b490" n/a n/a FAIL FAIL
row "HDMI fell back to speaker on b8b490" n/a n/a OBSERVED n/a
row "volume UI on 1178d5" n/a n/a PASS n/a
row "Recent firmware art on 1178d5" n/a n/a PASS n/a
row "BT latency on 1178d5" n/a n/a FAIL n/a
row "BT cold-boot route on 1178d5" n/a n/a FAIL n/a
row "BT headset icon on 1178d5" n/a n/a FAIL n/a
row "HDMI audibility on 1178d5" n/a n/a FAIL FAIL
row "HDMI 720p picture and panel restore" n/a n/a PASS n/a
row "Abombniball MENU+START" n/a n/a FAIL n/a
if awk '
	/^row "BT audibility on 6ea59c"/ && /PASS/ { bad = 1 }
	/^row "HDMI audibility on 6ea59c"/ && /PASS/ { bad = 1 }
	/^row "RetroArch BT listen"/ && /PASS/ { bad = 1 }
	/^row "RetroArch HDMI listen"/ && /PASS/ { bad = 1 }
	/^row "A2DP transport on 6ea59c"/ && /PASS/ { bad = 1 }
	/^row "HDMI graph on 6ea59c"/ && /PASS/ { bad = 1 }
	/^row "BT routed to RK817 on 7eb86d2"/ && /PASS/ { bad = 1 }
	/^row "HDMI audibility on 7eb86d2"/ && /PASS/ { bad = 1 }
	/^row "BT headset indicator on b8b490"/ && /PASS/ { bad = 1 }
	/^row "volume response on b8b490"/ && /PASS/ { bad = 1 }
	/^row "HDMI audibility on b8b490"/ && /PASS/ { bad = 1 }
	/^row "HDMI fell back to speaker on b8b490"/ && /PASS/ { bad = 1 }
	/^row "BT latency on 1178d5"/ && /PASS/ { bad = 1 }
	/^row "BT cold-boot route on 1178d5"/ && /PASS/ { bad = 1 }
	/^row "BT headset icon on 1178d5"/ && /PASS/ { bad = 1 }
	/^row "HDMI audibility on 1178d5"/ && /PASS/ { bad = 1 }
	/^row "A2DP default on 7eb86d2"/ && /PASS/ { bad = 1 }
	END { exit !bad }
' "$0"; then
	echo "phase14 accept: a 6ea59c listen was marked PASS" >&2
	fail=1
fi
row "Bluetooth disconnect falls back" n/a n/a PASS PASS
row "Wi-Fi off and on" n/a n/a PASS n/a
row "volume and mute on 0b35a90" n/a n/a PASS PASS
row "charger suppression of 0% shutdown" n/a n/a PASS n/a

sh "$ROOT/scripts/tests/test_armhf_capability.sh"
sh "$ROOT/scripts/tests/test_pulse_buffer.sh"
sh "$ROOT/scripts/tests/test_pulse_card.sh"
sh "$ROOT/scripts/tests/test_pak_launch.sh"

[ "$fail" -eq 0 ]
echo "phase14 accept host ok"
