#!/bin/sh
# Phase 13D2. Mocked lid and power events. No hardware suspend.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
keylid=$ROOT/package/system/zlyme-keylidmon/zlyme-keylidmon.c
policy=$ROOT/package/system/zlyme-keylidmon/lid_policy.h
testc=$ROOT/package/system/zlyme-keylidmon/lid_policy_test.c
suspend=$ROOT/package/system/nextui/zlyme/suspend

if grep -n 'wakealarm' "$keylid" "$suspend" "$policy"; then
	echo "suspend path touches the RTC wakealarm" >&2
	exit 1
fi
if grep -n 'do_lid_sleep\|FB_BLANK_POWERDOWN' "$keylid"; then
	echo "lid path still has the shallow sleep" >&2
	exit 1
fi
if grep -n 'kill(' "$keylid"; then
	echo "keylidmon terminates a process" >&2
	exit 1
fi
if ! grep -q 'zlyme_lid_observe(&lid_policy, hall_switch_closed' "$keylid"; then
	echo "owner sync does not reconcile the hall switch" >&2
	exit 1
fi

awk '
	/do_mem_sleep/ { fn = 1 }
	fn && /zlyme-governor idle/ && !idle { idle = NR }
	fn && /zlyme-radios pre/ && !pre { pre = NR }
	fn && /bin\/suspend/ && !sus { sus = NR }
	fn && /zlyme-governor resume/ && !res { res = NR }
	fn && /zlyme-radios resume/ && !rad { rad = NR }
	END {
		if (!(idle && pre && sus && res && rad && idle < pre && pre < sus && sus < res && res < rad))
			exit 1
	}
' "$keylid"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc=${CC:-gcc}
"$cc" -Wall -Wextra -Werror -I"$ROOT/package/system/zlyme-keylidmon" \
	-o "$work/lid_policy_test" "$testc"
"$work/lid_policy_test"
echo "phase 13D lid policy ok"
