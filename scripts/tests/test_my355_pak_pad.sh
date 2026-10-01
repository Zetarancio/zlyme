#!/bin/sh
# my355 PAK input is the virtual Xbox pad. A is button 0.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
h=$ROOT/package/system/nextui/apostrophe/include/apostrophe.h

# The my355 raw fallback, and only that switch.
awk '
	/virtual Xbox 360 pad/ { inb=1 }
	inb && /switch \(btn\)/ { ins=1 }
	ins { print }
	ins && /default: return AP_BTN_NONE/ { exit }
' "$h" > /tmp/zlyme-my355-pad.$$
trap 'rm -f /tmp/zlyme-my355-pad.$$' EXIT
mapf=/tmp/zlyme-my355-pad.$$

need() {
	grep -F -q "$1" "$mapf" || {
		echo "missing raw map: $1" >&2
		exit 1
	}
}
need 'case 0:  return AP_BTN_A;'
need 'case 1:  return AP_BTN_B;'
need 'case 2:  return AP_BTN_X;'
need 'case 3:  return AP_BTN_Y;'
need 'case 4:  return AP_BTN_L1;'
need 'case 5:  return AP_BTN_R1;'
need 'case 6:  return AP_BTN_SELECT;'
need 'case 7:  return AP_BTN_START;'
need 'case 8:  return AP_BTN_MENU;'
if grep -F -q 'case 0:  return AP_BTN_B;' "$mapf"; then
	echo "raw map still swaps A and B" >&2
	exit 1
fi

# GameController names, which are what the open pad actually delivers.
for pair in \
	'SDL_CONTROLLER_BUTTON_A:AP_BTN_A' \
	'SDL_CONTROLLER_BUTTON_B:AP_BTN_B' \
	'SDL_CONTROLLER_BUTTON_X:AP_BTN_X' \
	'SDL_CONTROLLER_BUTTON_Y:AP_BTN_Y' \
	'SDL_CONTROLLER_BUTTON_LEFTSHOULDER:AP_BTN_L1' \
	'SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:AP_BTN_R1' \
	'SDL_CONTROLLER_BUTTON_BACK:AP_BTN_SELECT' \
	'SDL_CONTROLLER_BUTTON_START:AP_BTN_START' \
	'SDL_CONTROLLER_BUTTON_GUIDE:AP_BTN_MENU' \
	'SDL_CONTROLLER_BUTTON_DPAD_UP:AP_BTN_UP' \
	'SDL_CONTROLLER_BUTTON_DPAD_DOWN:AP_BTN_DOWN' \
	'SDL_CONTROLLER_BUTTON_DPAD_LEFT:AP_BTN_LEFT' \
	'SDL_CONTROLLER_BUTTON_DPAD_RIGHT:AP_BTN_RIGHT'
do
	key=${pair%%:*}
	val=${pair#*:}
	grep -F -q "$key" "$h" || { echo "missing $key" >&2; exit 1; }
	awk -v k="$key" -v v="$val" '
		$0 ~ k && $0 ~ v { found=1 }
		END { exit !found }
	' "$h" || { echo "$key does not map to $val" >&2; exit 1; }
done

grep -F -q 'SDL_INIT_GAMECONTROLLER' "$h"
grep -F -q 'SDL_IsGameController' "$h"
grep -F -q 'my355 pad: virtual xbox gamecontroller' "$h"
grep -F -q 'zlyme-governor owns my355 clocks' "$h"
# The my355 cpu function returns before any sysfs write.
awk '
	/zlyme-governor owns my355 clocks/ { inb=1 }
	inb { print }
	inb && /return AP_OK/ { exit }
' "$h" | grep -q 'return AP_OK'
if awk '
	/zlyme-governor owns my355 clocks/ { inb=1 }
	inb && /scaling_governor/ { bad=1 }
	inb && /return AP_OK/ { exit }
	END { exit bad }
' "$h"; then
	:
else
	echo "my355 cpu path still writes the governor" >&2
	exit 1
fi
echo "my355 pak pad ok"
