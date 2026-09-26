#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ext=$dir/80-zlyme_external_gamepad.yaml
flip=$dir/20-zlyme_miyoo_flip.yaml
grep -q 'name: External Gamepad' "$ext"
grep -q 'maximum_sources: 1' "$ext"
grep -q 'auto_manage: false' "$ext"
grep -q 'persist: false' "$ext"
grep -q '  - xb360' "$ext"
grep -q 'ID_INPUT_JOYSTICK' "$ext"
grep -q 'sys_name: "event\*"' "$ext"
if grep -q 'mouse\|keyboard' "$ext"; then
	echo "external target must be xb360 only" >&2
	exit 1
fi
# Sorted config load: the specific Flip file is considered first.
printf '%s\n%s\n' "$(basename "$flip")" "$(basename "$ext")" | sort -C
echo EXTERNAL_OK
