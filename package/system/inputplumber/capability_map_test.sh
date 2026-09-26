#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
map=$dir/zlyme_miyoo_flip.yaml
dev=$dir/20-zlyme_miyoo_flip.yaml
got=$(mktemp)
want=$(mktemp)
trap 'rm -f "$got" "$want"' EXIT
awk '
	/event_code:/ { code = $2; vt = "" }
	/value_type:/ { vt = $2 }
	/button:/ { print code, vt, "button", $2 }
	/name: LeftTrigger/ { print code, vt, "trigger", "LeftTrigger" }
	/name: RightTrigger/ { print code, vt, "trigger", "RightTrigger" }
' "$map" >"$got"
printf '%s\n' \
	"BTN_DPAD_UP button button DPadUp" \
	"BTN_DPAD_DOWN button button DPadDown" \
	"BTN_DPAD_LEFT button button DPadLeft" \
	"BTN_DPAD_RIGHT button button DPadRight" \
	"BTN_TL2 trigger trigger LeftTrigger" \
	"BTN_TR2 trigger trigger RightTrigger" >"$want"
cmp -s "$want" "$got"
grep -q 'id: zlyme_miyoo_flip' "$map"
grep -q 'capability_map_id: zlyme_miyoo_flip' "$dev"
grep -q 'auto_manage: false' "$dev"
grep -q 'persist: false' "$dev"
grep -q '  - xb360' "$dev"
echo MAP_OK
