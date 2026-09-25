#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
map=$dir/zlyme_miyoo_flip.yaml
dev=$dir/20-zlyme_miyoo_flip.yaml
for pair in "BTN_DPAD_UP DPadUp" "BTN_DPAD_DOWN DPadDown" "BTN_DPAD_LEFT DPadLeft" "BTN_DPAD_RIGHT DPadRight"; do
	set -- $pair
	grep -q "event_code: $1" "$map"
	grep -q "button: $2" "$map"
done
grep -q 'id: zlyme_miyoo_flip' "$map"
grep -q 'capability_map_id: zlyme_miyoo_flip' "$dev"
grep -q 'auto_manage: false' "$dev"
grep -q 'persist: false' "$dev"
grep -q '  - xb360' "$dev"
echo MAP_OK
