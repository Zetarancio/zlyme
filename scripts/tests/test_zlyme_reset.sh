#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset"
TZBIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-timezone"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_RESET_ROOT="$work"
export ZLYME_RESET_APPLY_LOG="$work/apply.log"
export ZLYME_CARD_DEFAULTS="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-card-defaults"
export ZLYME_TZ_BIN="$TZBIN"
: > "$work/apply.log"
mkdir -p "$work/bin"
cat > "$work/bin/zlyme-ctl" <<'EOF'
#!/bin/sh
if [ "$1" = want ]; then
	case "$2" in
		samba|syncthing) exit 1 ;;
	esac
	exit 0
fi
exit 0
EOF
chmod 0755 "$work/bin/zlyme-ctl"
export PATH="$work/bin:$PATH"
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
test ! -e "$zlyme/undervolt"
test ! -e "$shared/vtree/config.ini"
test ! -e "$shared/vtree/.zlyme-vtree-v1"
grep -q '^screentimeout=120$' "$shared/minuisettings.txt"
grep -q '^suspendTimeout=600$' "$shared/minuisettings.txt"
grep -q '^batteryperc=1$' "$shared/minuisettings.txt"
grep -q '^showclock=1$' "$shared/minuisettings.txt"
grep -q '/etc/init.d/S30wifi start' "$work/apply.log"
grep -q '/etc/init.d/S70samba stop' "$work/apply.log"
grep -q 'zlyme-ctl apply-zram' "$work/apply.log"
grep -q 'zlyme-ctl apply-led' "$work/apply.log"
grep -q 'zlyme-ctl apply-overlays' "$work/apply.log"
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
grep -q '^screentimeout=120$' "$shared/minuisettings.txt"
grep -q extra "$work/storage/Tools/my355/Extra.pak/launch.sh"
grep -q stock "$work/storage/Tools/my355/Files.pak/launch.sh"
grep -q 'network={' "$cfg/wpa_supplicant.conf"
grep -q paired "$cfg/bluetooth.tar"
grep -q rom "$work/storage/Roms/game.gba"

echo "reset ok"
