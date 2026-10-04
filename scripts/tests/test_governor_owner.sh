#!/bin/sh
# Frontend clocks are applied by the session, not by the LED service.
# A late reapply restores the profile already chosen.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
led=$ROOT/board/my355/fsoverlay/etc/init.d/S27led
session=$ROOT/package/system/nextui/nextui-session
update=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update
gov=$ROOT/package/system/nextui/zlyme/governor.sh
keylid=$ROOT/package/system/zlyme-keylidmon/zlyme-keylidmon.c
floors=$ROOT/package/system/nextui/zlyme/test-governor-floors.sh

if grep -n 'apply-gov' "$led"; then
	echo "S27led still applies the governor" >&2
	exit 1
fi

awk '
	/apply_frontend_governor\(\)/ { def = NR }
	/^[[:space:]]*apply_frontend_governor$/ { call = NR }
	/nextui\.elf/ { elf = NR }
	END {
		if (!def || !call || !elf || !(call < elf)) {
			print "smart apply is not on the frontend start path" > "/dev/stderr"
			exit 1
		}
	}
' "$session"
grep -q 'zlyme-governor resume' "$session"
grep -q 'zlyme-governor smart' "$session"

awk '
	/^reapply_once\(\)/ { in_fn = 1 }
	in_fn && /^}/ { in_fn = 0 }
	in_fn && /apply-gov/ { bad = 1 }
	in_fn && /zlyme-governor resume/ { resume = 1 }
	END {
		if (bad || !resume) exit 1
	}
' "$update"

awk '
	/do_mem_sleep/ { fn = 1 }
	fn && /zlyme-governor idle/ && !idle { idle = NR }
	fn && /bin\/suspend/ && !sus { sus = NR }
	fn && /zlyme-governor resume/ && !res { res = NR }
	fn && /zlyme-radios resume/ && !rad { rad = NR }
	END {
		if (!(idle && sus && res && rad && idle < sus && sus < res && res < rad))
			exit 1
	}
' "$keylid"

sh "$floors"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_GOVERNOR_DRY=1
export ZLYME_GOVERNOR_LOCK=$work/lock
export ZLYME_GOVERNOR_PROFILE=$work/profile
export ZLYME_CPU_FREQS="408000 600000 816000 1104000 1416000 1608000 1800000 1992000"
test "$("$gov" smart)" = smart
grep -qx smart "$work/profile"
test "$("$gov" idle)" = idle
grep -qx smart "$work/profile"
test "$("$gov" resume)" = smart
test "$("$gov" emu GBA)" = "emu gba"
grep -qx "emu gba" "$work/profile"
test "$("$gov" resume)" = "emu gba"
test "$("$gov" idle)" = idle
grep -qx "emu gba" "$work/profile"

echo "governor owner ok"
