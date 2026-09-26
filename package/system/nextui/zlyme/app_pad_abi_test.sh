#!/bin/sh
# Fails if a shipped application launcher depends on the physical pad
# or if pak launch stops arming zlyme-pak-hotkey.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../../../.." && pwd)
fail=0

say() {
	printf '%s\n' "$1"
}

scan() {
	# shellcheck disable=SC2086
	hit=$(grep -R -n -E -I \
		-e 'Miyoo Flip Gamepad' \
		-e '/dev/input/js0' \
		-e '/dev/js0' \
		-e '/dev/input/event[0-9]' \
		-e 'retrogame_joypad' \
		--exclude=gamecontrollerdb.txt \
		--exclude=app_pad_abi_test.sh \
		--exclude-dir=gamepad-ff \
		"$root/package/system/nextui/paks" \
		"$root/package/system/nextui/zlyme" \
		"$root/package/system/portmaster" \
		"$root/package/emulators" \
		"$root/board/my355/fsoverlay/usr" \
		2>/dev/null || true)
	if [ -n "$hit" ]; then
		say "$hit"
		fail=1
	fi
}

scan

if grep -R -n 'pico8-splore-pad' \
	"$root/package" "$root/board/my355/fsoverlay" >/dev/null 2>&1; then
	say "pico8-splore-pad is still referenced"
	fail=1
fi

session=$root/package/system/nextui/nextui-session
if ! grep -q 'zlyme-pak-hotkey' "$session"; then
	say "session does not arm zlyme-pak-hotkey"
	fail=1
fi
if ! grep -q 'setsid sh' "$session"; then
	say "session does not setsid the pak"
	fail=1
fi
if ! grep -q 'Settings.pak' "$session"; then
	say "session does not exclude Settings from the SDL filter"
	fail=1
fi
# The filter is a string inside the child shell, not a source in the parent.
if grep -n '^[[:space:]]*\. /usr/share/zlyme/pak-input.sh' "$session" >/dev/null 2>&1; then
	say "session sources pak-input.sh in the parent shell"
	fail=1
fi

if [ "$fail" -ne 0 ]; then
	say "APP_PAD_ABI_FAIL"
	exit 1
fi
say "APP_PAD_ABI_OK"
