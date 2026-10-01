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
grep -q zlyme_splash_wanted "$ROOT/board/my355/fsoverlay/etc/init.d/S16display"
grep -q zlyme_splash_wanted "$ROOT/package/system/nextui/nextui-session"
init=$ROOT/package/boot/zlyme-initramfs/init
awk '
	/read -r cmdline/ { seen = 1 }
	seen && /zlyme-splash \/splash/ { ok = 1 }
	END { exit ok ? 0 : 1 }
' "$init"
# The only splash_wanted=1 is the quiet-token branch.
awk '
	/= quiet/ { quiet = 1; next }
	/splash_wanted=1/ { if (!quiet) bad = 1; quiet = 0 }
	{ quiet = 0 }
	END { exit bad ? 1 : 0 }
' "$init"
grep -q 'console=tty1 console=ttyS2' "$ROOT/board/my355/extlinux.conf"
grep -q '/dev/tty1' "$ROOT/board/my355/fsoverlay/etc/init.d/rcS"
if grep -n splash_ok=1 "$ROOT/board/my355/fsoverlay/etc/init.d/S16display" | grep -v zlyme_splash_wanted; then
	echo "S16 starts the splash for a reason other than quiet" >&2
	exit 1
fi
echo "splash quiet ok"
