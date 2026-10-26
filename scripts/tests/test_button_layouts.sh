#!/bin/sh
# Stock face-button defaults. A saved file stays. Reset restores the
# packaged file and does not touch a save or a RetroArch remap.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "button-layouts: $*" >&2; exit 1; }

MAP=$ROOT/package/system/inputplumber/zlyme_miyoo_flip.yaml
RA=$ROOT/board/my355/fsoverlay/usr/share/zlyme/retroarch/retroarch.cfg
AUTO=$ROOT/package/emulators/retroarch/zlyme/autoconfig/sdl2/Microsoft\ X-Box\ 360\ pad.cfg
PP=$ROOT/board/my355/fsoverlay/usr/share/zlyme/emu-defaults/ppsspp.ini
DOL=$ROOT/package/emulators/dolphin-emu/start_dolphin.sh
AE=$ROOT/package/emulators/aethersx2/start_aethersx2.sh
SEED=$ROOT/package/system/nextui/zlyme/zlyme-stock-seed
CLEAN=$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh

awk '
	$0 ~ /name: A$/ { a = 1 }
	a && /button: South/ { print "a-south"; exit }
' "$MAP" | grep -q a-south || fail "printed A is no longer virtual South"
awk '
	$0 ~ /name: B$/ { b = 1 }
	b && /button: East/ { print "b-east"; exit }
' "$MAP" | grep -q b-east || fail "printed B is no longer virtual East"
grep -q 'input_menu_swap_ok_cancel_buttons = "false"' "$RA" \
	|| fail "RGUI no longer confirms on RetroPad A"
grep -q 'input_a_btn = "0"' "$AUTO" || fail "RetroPad A left button 0"
grep -q 'input_b_btn = "1"' "$AUTO" || fail "RetroPad B left button 1"
grep -q 'input_x_btn = "2"' "$AUTO" || fail "RetroPad X left button 2"
grep -q 'input_y_btn = "3"' "$AUTO" || fail "RetroPad Y left button 3"
if grep -q input_menu_swap_ok_cancel_buttons "$AUTO"; then
	fail "the gameplay autoconfig carries the menu swap"
fi

grep -q 'Circle = 10-189' "$PP" || fail "PPSSPP Circle is not the east button"
grep -q 'Cross = 10-190' "$PP" || fail "PPSSPP Cross is not the south button"
grep -q 'Square = 10-188' "$PP" || fail "PPSSPP Square is not the west button"
grep -q 'Triangle = 10-191' "$PP" || fail "PPSSPP Triangle is not the north button"
if grep -q 'Cross = 10-189' "$PP"; then
	fail "PPSSPP Cross is still the east button"
fi
grep -q 'Buttons/A = `Button E`' "$DOL" || fail "GameCube A is not south"
grep -q 'Buttons/B = `Button N`' "$DOL" || fail "GameCube B is not west"
grep -q 'Buttons/X = `Button S`' "$DOL" || fail "GameCube X is not east"
grep -q 'Buttons/Y = `Button W`' "$DOL" || fail "GameCube Y is not north"
if grep -q 'Buttons/A = `Button S`' "$DOL"; then
	fail "GameCube A is still Button S"
fi
grep -c 'Cross = SDL-0/B' "$AE" | grep -qx 2 || fail "AetherSX2 Cross is not south in both templates"
grep -c 'Circle = SDL-0/A' "$AE" | grep -qx 2 || fail "AetherSX2 Circle is not east in both templates"
grep -c 'Square = SDL-0/Y' "$AE" | grep -qx 2 || fail "AetherSX2 Square is not west in both templates"
grep -c 'Triangle = SDL-0/X' "$AE" | grep -qx 2 || fail "AetherSX2 Triangle is not north in both templates"
if grep -q 'Cross = SDL-0/A' "$AE"; then
	fail "AetherSX2 Cross is still SDL A"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_STOCK_ROOT="$work/storage"
export ZLYME_STOCK_SHARE="$ROOT/board/my355/fsoverlay/usr/share/zlyme"
export ZLYME_DRASTIC_SEED="$ROOT/package/emulators/drastic/config/drastic.cfg"
mkdir -p "$work/storage/.config/ppsspp/PSP/SYSTEM" \
	"$work/storage/.config/retroarch/config/remaps" \
	"$work/storage/Saves"
printf '%s\n' 'CPUSpeed = 222' 'Cross = 10-1' \
	> "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
printf '%s\n' 'audio_latency = "9"' 'keep-me' \
	> "$work/storage/.config/retroarch/retroarch.cfg"
printf '%s\n' 'user remap' \
	> "$work/storage/.config/retroarch/config/remaps/custom.cfg"
printf '%s\n' 'save' > "$work/storage/Saves/game.sav"
sh "$SEED" seed
grep -q 'CPUSpeed = 222' "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini" \
	|| fail "seed rewrote a custom PPSSPP ini"
grep -q 'keep-me' "$work/storage/.config/retroarch/retroarch.cfg" \
	|| fail "seed rewrote a custom RetroArch configuration"
rm -f "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
sh "$SEED" seed
grep -q 'Cross = 10-190' "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini" \
	|| fail "a missing PPSSPP ini was not restored"
if grep -q 'CPUSpeed = 222' "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"; then
	fail "the restored PPSSPP ini kept the custom speed"
fi

sh "$SEED" reset-ra
grep -q 'input_menu_swap_ok_cancel_buttons = "false"' \
	"$work/storage/.config/retroarch/retroarch.cfg" \
	|| fail "Reset RetroArch configuration did not restore the menu"
if grep -q 'keep-me' "$work/storage/.config/retroarch/retroarch.cfg"; then
	fail "Reset RetroArch configuration kept the custom line"
fi
grep -q 'user remap' "$work/storage/.config/retroarch/config/remaps/custom.cfg" \
	|| fail "Reset RetroArch configuration deleted a remap"

printf '%s\n' 'CPUSpeed = 222' \
	> "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
mkdir -p "$work/storage/.config/dolphin-emu"
printf '%s\n' 'custom pad' > "$work/storage/.config/dolphin-emu/GCPadNew.ini"
export ZLYME_CLEANUP_ROOT="$work/storage"
export ZLYME_STOCK_SEED="$SEED"
export ZLYME_LIBRARIES_FILE="$work/none"
sh "$CLEAN" standalones >/dev/null
grep -q 'Cross = 10-190' "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini" \
	|| fail "standalone reset did not restore PPSSPP"
if grep -q 'CPUSpeed = 222' "$work/storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"; then
	fail "standalone reset kept the custom PPSSPP speed"
fi
grep -q 'save' "$work/storage/Saves/game.sav" || fail "standalone reset removed a save"
if [ -e "$work/storage/.config/dolphin-emu/GCPadNew.ini" ]; then
	fail "standalone reset left the Dolphin pad file"
fi

export SDCARD_PATH="$work/card"
export BIOS_PATH="$work/card/Bios"
export USERDATA_PATH="$work/home"
export XDG_CONFIG_HOME="$work/cfg"
export SAVES_PATH="$work/not-a-directory"
: > "$SAVES_PATH"
set +e
sh "$DOL" >/dev/null 2>&1
st=$?
set -e
[ "$st" = 1 ] || fail "dolphin launcher did not stop before the program ($st)"
grep -q 'Buttons/A = `Button E`' "$work/cfg/dolphin-emu/GCPadNew.ini" \
	|| fail "the first Dolphin pad is not the stock south A"
printf '%s\n' 'Buttons/A = `Button S`' > "$work/cfg/dolphin-emu/GCPadNew.ini"
set +e
sh "$DOL" >/dev/null 2>&1
set -e
grep -q 'Buttons/A = `Button S`' "$work/cfg/dolphin-emu/GCPadNew.ini" \
	|| fail "a second launch rewrote the saved Dolphin pad"
rm -f "$work/cfg/dolphin-emu/GCPadNew.ini"
set +e
sh "$DOL" >/dev/null 2>&1
set -e
grep -q 'Buttons/A = `Button E`' "$work/cfg/dolphin-emu/GCPadNew.ini" \
	|| fail "removing the Dolphin pad did not restore the stock file"
if mount | grep -q "$work"; then
	fail "the dolphin launcher mounted a test path"
fi

echo "button layouts ok"
