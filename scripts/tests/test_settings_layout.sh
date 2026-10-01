#!/bin/sh
# my355 Settings order and the product version row.
set -eu
ui=/home/ale/zlyme-nextui/workspace/all/settings/settings.cpp
# Top of System on my355: Display, then the three Zlyme submenus, then Volume.
awk '
	/systemItems = \{/ { on = 1 }
	on && /Zlyme_appendJoystickItem/ { joy = 1 }
	on && joy && /Zlyme_appendStorageItems/ { stor = 1 }
	on && stor && /Zlyme_appendSystemItems/ { adv = 1 }
	on && adv && /"Volume"/ { vol = 1; exit }
	END { exit (joy && stor && adv && vol) ? 0 : 1 }
' "$ui"
# Those three are not appended again on my355.
awk '
	/getPlatform\(\) != DeviceInfo::my355/ { on = 1 }
	on && /Zlyme_appendJoystickItem/ { ok = 1 }
	END { exit ok ? 0 : 1 }
' "$ui"
# 24h, then Time zone, then Haptic. Default view is not in that span.
awk '
	/"Show 24h time format"/ { a = NR }
	/"Time zone"/ { if (a && !b) b = NR }
	/"Haptic feedback"/ { if (b && !c) c = NR }
	END { exit (a && b && c && a < b && b < c) ? 0 : 1 }
' "$ui"
if awk '
	/"Show 24h time format"/ { a = 1 }
	a && /"Default view"/ { bad = 1 }
	/"Haptic feedback"/ { a = 0 }
	END { exit bad ? 0 : 1 }
' "$ui"; then
	echo "Default view is still between the clock rows" >&2
	exit 1
fi
# One Default view, and it is in the appearance list (before Show Recents).
n=$(grep -c '"Default view"' "$ui")
test "$n" = 1
awk '
	/"Default view"/ { d = NR }
	/"Show Recents"/ { r = NR }
	END { exit (d && r && d < r) ? 0 : 1 }
' "$ui"
grep -q '/usr/share/zlyme/version' "$ui"
grep -q 'product_version_token' "$ui"
if grep -q nextui_short_version "$ui"; then
	echo "About still uses the frontend pin" >&2
	exit 1
fi
grep -q 'Enable or disable haptic feedback on certain actions in the OS' "$ui"
echo "settings layout ok"
