#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
. "$ROOT/board/my355/fsoverlay/usr/share/zlyme/splash-quiet.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
check() {
	printf '%s\n' "$1" > "$work/cmd"
	ZLYME_CMDLINE=$work/cmd
	if zlyme_splash_wanted; then
		got=yes
	else
		got=no
	fi
	if [ "$got" != "$2" ]; then
		echo "cmdline '$1' wanted $2 got $got" >&2
		exit 1
	fi
}
check "quiet" yes
check "root=/dev/mmcblk0p2 quiet" yes
check "quiet loglevel=3" yes
check "notquiet" no
check "foo=quiet" no
check "quietly" no
check "root=/dev/mmcblk0p2" no
grep -q zlyme_splash_wanted "$ROOT/board/my355/fsoverlay/etc/init.d/S12splash"
grep -q zlyme_splash_wanted "$ROOT/package/system/nextui/nextui-session"
echo "splash quiet ok"
