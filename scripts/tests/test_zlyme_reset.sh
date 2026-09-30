#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset"
TZBIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-timezone"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_RESET_ROOT="$work"
export ZLYME_RESET_SKIP_APPLY=1
export ZLYME_TZ_BIN="$TZBIN"
zi=$work/zoneinfo
mkdir -p "$zi"
printf 'TZifUTC' > "$zi/UTC"
export ZLYME_ZONEINFO="$zi"
unset ZLYME_CFG

cfg=$work/storage/.config
shared=$cfg/nextui/shared
zlyme=$cfg/zlyme
mkdir -p "$zlyme/miyoo-flip-gamepad" "$cfg/ssh" \
	"$shared/vtree" "$shared/configs/gzdoom" \
	"$shared/Pico-8-native" \
	"$work/storage/Roms/Ports" "$work/storage/Saves" "$work/storage/Bios" \
	"$work/storage/Tools/my355/Extra.pak" \
	"$work/storage/Tools/my355/Files.pak" \
	"$work/storage/Emus/my355/GBA.pak" \
	"$cfg/ppsspp" "$cfg/PortMaster" \
	"$work/storage/.wine"

printf '%s\n' 'color1=0x1' > "$shared/minuisettings.txt"
printf '%s\n' 'TZifROME' > "$shared/localtime"
printf '%s\n' 'Europe/Rome' > "$shared/localtime.zone"
printf '%s\n' 'ShowHidden=false' 'FontFile=custom.ttf' > "$shared/vtree/config.ini"
: > "$shared/vtree/.zlyme-vtree-v1"
printf '%s\n' 'network={' > "$cfg/wpa_supplicant.conf"
printf '%s\n' 'paired' > "$cfg/bluetooth.tar"
printf '%s\n' 'off' > "$zlyme/hdmi"
printf '%s\n' 'on' > "$zlyme/ab_swap"
printf '%s\n' 'l2' > "$zlyme/undervolt"
printf '%s\n' 'gain=70' > "$zlyme/miyoo-flip-gamepad/rumble.config"
printf '%s\n' 'off' > "$zlyme/ssh"
printf '%s\n' 'hostkey' > "$cfg/ssh/key"
printf '%s\n' 'gzdoom-user' > "$shared/configs/gzdoom/gzdoom.ini"
printf '%s\n' 'cart' > "$shared/Pico-8-native/cdata.p8"
printf '%s\n' 'rom' > "$work/storage/Roms/game.gba"
printf '%s\n' 'save' > "$work/storage/Saves/game.sav"
printf '%s\n' 'bios' > "$work/storage/Bios/bios.bin"
printf '%s\n' 'port' > "$work/storage/Roms/Ports/port.sh"
printf '%s\n' 'wine' > "$work/storage/.wine/system.reg"
printf '%s\n' 'extra' > "$work/storage/Tools/my355/Extra.pak/launch.sh"
printf '%s\n' 'stock' > "$work/storage/Tools/my355/Files.pak/launch.sh"
printf '%s\n' 'gba' > "$work/storage/Emus/my355/GBA.pak/launch.sh"
printf '%s\n' 'psp' > "$cfg/ppsspp/ppsspp.ini"
printf '%s\n' 'pm' > "$cfg/PortMaster/control.txt"

"$BIN" settings

test ! -e "$zlyme/hdmi"
test ! -e "$zlyme/ssh"
test ! -e "$zlyme/ab_swap"
test ! -e "$zlyme/undervolt"
test ! -e "$shared/minuisettings.txt"
test ! -e "$shared/vtree/config.ini"
test ! -e "$shared/vtree/.zlyme-vtree-v1"
cmp "$shared/localtime" "$zi/UTC"
test ! -e "$shared/localtime.zone"
test ! -e "$zlyme/factory-reset"

grep -q 'network={' "$cfg/wpa_supplicant.conf"
grep -q paired "$cfg/bluetooth.tar"
grep -q 'gain=70' "$zlyme/miyoo-flip-gamepad/rumble.config"
grep -q hostkey "$cfg/ssh/key"
grep -q gzdoom-user "$shared/configs/gzdoom/gzdoom.ini"
grep -q cart "$shared/Pico-8-native/cdata.p8"
grep -q rom "$work/storage/Roms/game.gba"
grep -q save "$work/storage/Saves/game.sav"
grep -q bios "$work/storage/Bios/bios.bin"
grep -q port "$work/storage/Roms/Ports/port.sh"
grep -q wine "$work/storage/.wine/system.reg"
grep -q extra "$work/storage/Tools/my355/Extra.pak/launch.sh"
grep -q stock "$work/storage/Tools/my355/Files.pak/launch.sh"
grep -q gba "$work/storage/Emus/my355/GBA.pak/launch.sh"
grep -q psp "$cfg/ppsspp/ppsspp.ini"
grep -q pm "$cfg/PortMaster/control.txt"

"$BIN" factory
test -f "$zlyme/factory-reset"
grep -q extra "$work/storage/Tools/my355/Extra.pak/launch.sh"
grep -q stock "$work/storage/Tools/my355/Files.pak/launch.sh"
grep -q 'network={' "$cfg/wpa_supplicant.conf"
grep -q paired "$cfg/bluetooth.tar"
grep -q rom "$work/storage/Roms/game.gba"
test ! -e "$shared/minuisettings.txt"

echo "reset ok"
