#!/bin/sh
# Host check for independent zlyme-gamepad-cal restore. Not installed.
set -u

helper=$(CDPATH= cd -- "$(dirname "$0")/../../../../../board/my355/fsoverlay/usr/sbin" && pwd)/zlyme-gamepad-cal
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
cal=$root/cal
sys=$root/sys/dev
mkdir -p "$cal" "$sys"
: >"$sys/calibration_left"
: >"$sys/calibration_right"
: >"$sys/deadzone_left"
: >"$sys/deadzone_right"
export ZLYME_CAL_DIR=$cal
export ZLYME_GAMEPAD_SYS=$root/sys

good='x_min=2
x_max=223
y_min=25
y_max=239
x_zero=103
y_zero=139
'
bad='x_min=2
x_max=223
'

fail=0
check() {
	if [ "$1" = "$2" ]; then
		return
	fi
	echo "FAIL $3 (got $1 want $2)" >&2
	fail=1
}

"$helper" restore
check $? 0 "no files"

printf '%s' "$good" >"$cal/joypad.config"
"$helper" restore
check $? 0 "left only"
check "$(wc -c <"$sys/calibration_left")" "$(wc -c <"$sys/calibration_left")" "left written"
test -s "$sys/calibration_left" || { echo "FAIL left empty" >&2; fail=1; }
: >"$sys/calibration_left"
: >"$sys/calibration_right"

printf '%s' "$good" >"$cal/joypad_right.config"
rm -f "$cal/joypad.config"
"$helper" restore
check $? 0 "right only"
test -s "$sys/calibration_right" || { echo "FAIL right empty" >&2; fail=1; }
test ! -s "$sys/calibration_left" || { echo "FAIL left touched" >&2; fail=1; }

printf '%s' "$bad" >"$cal/joypad.config"
printf '%s' "$good" >"$cal/joypad_right.config"
: >"$sys/calibration_right"
"$helper" restore
check $? 1 "bad left"
test -s "$sys/calibration_right" || { echo "FAIL right blocked" >&2; fail=1; }

printf '%s' "$good" >"$cal/joypad.config"
printf '%s' "$bad" >"$cal/joypad_right.config"
: >"$sys/calibration_left"
"$helper" restore
check $? 1 "bad right"
test -s "$sys/calibration_left" || { echo "FAIL left undone" >&2; fail=1; }

rm -f "$sys/calibration_left"
mkdir "$sys/calibration_left"
printf '%s' "$bad" >"$cal/joypad.config"
printf '%s' "$good" >"$cal/joypad_right.config"
: >"$sys/calibration_right"
"$helper" restore
check $? 1 "left reject"
test -s "$sys/calibration_right" || { echo "FAIL right after reject" >&2; fail=1; }

rmdir "$sys/calibration_left"
: >"$sys/calibration_left"
rm -f "$sys/calibration_right"
mkdir "$sys/calibration_right"
printf '%s' "$good" >"$cal/joypad.config"
printf '%s' "$good" >"$cal/joypad_right.config"
"$helper" restore
check $? 1 "right reject"
test -s "$sys/calibration_left" || { echo "FAIL left stays" >&2; fail=1; }

rm -f "$cal/joypad.config" "$cal/joypad_right.config" "$cal/deadzone.config"
: >"$sys/deadzone_left"
: >"$sys/deadzone_right"
"$helper" restore
check $? 0 "no files including deadzone"

printf 'left=12\n' >"$cal/deadzone.config"
"$helper" restore
check $? 0 "left deadzone only"
check "$(cat "$sys/deadzone_left")" "12" "left pct"
check "$(cat "$sys/deadzone_right")" "0" "right default"

printf 'right=30\n' >"$cal/deadzone.config"
: >"$sys/deadzone_left"
"$helper" restore
check $? 0 "right deadzone only"
check "$(cat "$sys/deadzone_right")" "30" "right pct"
check "$(cat "$sys/deadzone_left")" "0" "left default"

printf 'left=40\nright=7\n' >"$cal/deadzone.config"
: >"$sys/deadzone_left"
: >"$sys/deadzone_right"
"$helper" restore
check $? 1 "left out of range"
check "$(cat "$sys/deadzone_right")" "7" "right after bad left"
check "$(cat "$sys/deadzone_left")" "" "left not written"

printf 'left=4\nright=abc\n' >"$cal/deadzone.config"
: >"$sys/deadzone_left"
: >"$sys/deadzone_right"
"$helper" restore
check $? 1 "right nonnumeric"
check "$(cat "$sys/deadzone_left")" "4" "left after bad right"

exit "$fail"
