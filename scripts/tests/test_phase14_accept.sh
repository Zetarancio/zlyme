#!/bin/sh
# shellcheck disable=SC1007
# Phase 14 acceptance inventory.
# Columns are SOURCE, HOST, HARDWARE, and USER-AUDIBLE.
# A SOURCE pass is a text check. It is not a Flip result.
# HARDWARE and USER-AUDIBLE values below are recorded observations.
# This script does not SSH, turn Wi-Fi off, reboot, or stop PulseAudio.
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

need "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" 'flat-volumes = no' \
	"flat volumes stay off"
absent "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" '^enable-remixing' \
	"remixing is the PulseAudio default"
need "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf" 'api.alsa.card.id = "rk817ext"' \
	"codec match uses the ALSA card id"
need "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pipewire-launch" 'pipewire-pulse' \
	"pipewire-pulse is started as its own argv"
need "$ROOT/package/system/nextui/nextui.mk" '0bb030ef6f44c005df4f4942a2fa3701ae0f7121' \
	"NextUI pin is the paired-device snapshot"
need "$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio" '^exit 0$' \
	"Buildroot Pulse service stays a no-op"
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

row "speaker and headphone audibility" n/a n/a PASS PASS
row "headphone reconnect" n/a n/a PASS PASS
row "speaker sound quality" n/a n/a FAIL FAIL
row "HDMI sound quality" n/a n/a FAIL FAIL
row "HDMI 720p picture and panel restore" n/a n/a PENDING n/a
row "Abombniball MENU+START" n/a n/a FAIL n/a
row "Bluetooth headphone audio" n/a n/a PASS PASS
row "Bluetooth disconnect falls back" n/a n/a PENDING n/a
row "Wi-Fi off and on" n/a n/a NOTRUN n/a
row "charger suppression of 0% shutdown" n/a n/a NOTRUN n/a

sh "$ROOT/scripts/tests/test_armhf_capability.sh"
sh "$ROOT/scripts/tests/test_pulse_buffer.sh"
sh "$ROOT/scripts/tests/test_pulse_card.sh"
sh "$ROOT/scripts/tests/test_pak_launch.sh"

[ "$fail" -eq 0 ]
echo "phase14 accept host ok"
