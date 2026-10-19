#!/bin/sh
# shellcheck disable=SC1007
# Phase 14 acceptance inventory. Host checks are PASS or FAIL.
# Perceptual and physical checks are MANUAL. This script does not
# turn Wi-Fi off, reboot, unplug HDMI, or stop PulseAudio.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail=0
say() { printf '%s\n' "$1"; }

need() {
	if grep -q "$2" "$1"; then
		say "PASS  $3"
	else
		say "FAIL  $3"
		fail=1
	fi
}
absent() {
	if grep -q "$2" "$1"; then
		say "FAIL  $3"
		fail=1
	else
		say "PASS  $3"
	fi
}

need "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" 'flat-volumes = no' \
	"flat volumes stay off"
absent "$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf" '^enable-remixing' \
	"remixing is the PulseAudio default"
need "$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa" 'hw:rk817ext,0' \
	"codec sink uses the ALSA card id"
need "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-pulse-launch" 'level=notice' \
	"routine Pulse log level is notice"
need "$ROOT/package/system/nextui/nextui.mk" '0bb030ef6f44c005df4f4942a2fa3701ae0f7121' \
	"NextUI pin is the paired-device snapshot"
need "$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio" '^exit 0$' \
	"Buildroot Pulse service stays a no-op"
if [ -d "$ROOT/package/system/nextui/paks/Tools/USB Transfer.pak" ]; then
	say "PASS  USB Transfer pak is the stock name"
else
	say "FAIL  USB Transfer pak is the stock name"
	fail=1
fi
if [ -d "$ROOT/package/system/nextui/paks/Tools/USB File Transfer.pak" ]; then
	say "FAIL  old USB File Transfer pak is still the stock tree"
	fail=1
else
	say "PASS  old USB File Transfer pak is not the stock tree"
fi

say "MANUAL  speaker and headphone audibility"
say "MANUAL  headphone reconnect"
say "MANUAL  HDMI sound quality"
say "MANUAL  HDMI 720p picture and panel restore"
say "MANUAL  one PortMaster game with sound, then MENU+START"
say "MANUAL  Bluetooth audio disconnect falls back to the speaker"
say "MANUAL  Wi-Fi off and on; do not run this over the only SSH session"
say "NOTRUN charger-suppression of the 0% shutdown"

[ "$fail" -eq 0 ]
echo "phase14 accept host ok"
