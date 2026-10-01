#!/bin/sh
# The non-quiet LCD console experiment was dropped. Product boot is
# the graphical splash, with serial as the only console.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ext=$ROOT/board/my355/extlinux.conf
init=$ROOT/package/boot/zlyme-initramfs/init
if [ -e "$ROOT/board/my355/fsoverlay/usr/share/zlyme/splash-quiet.sh" ]; then
	echo "splash-quiet helper still exists" >&2
	exit 1
fi
grep -q 'quiet console=ttyS2,1500000n8' "$ext"
if grep -q 'console=tty1' "$ext"; then
	echo "extlinux still has tty1" >&2
	exit 1
fi
if grep -q 'tty1' "$ROOT/board/my355/fsoverlay/etc/init.d/rcS"; then
	echo "rcS still mirrors the LCD console" >&2
	exit 1
fi
if grep -q 'splash-quiet' \
	"$ROOT/board/my355/fsoverlay/etc/init.d/S12splash" \
	"$ROOT/board/my355/fsoverlay/etc/init.d/S16display" \
	"$ROOT/package/system/nextui/nextui-session" \
	"$init"; then
	echo "quiet gate still referenced" >&2
	exit 1
fi
if grep -q 'splash_wanted' "$init"; then
	echo "initramfs still has a quiet splash gate" >&2
	exit 1
fi
grep -q '/zlyme-splash /splash.rgb565' "$init"
grep -q 'zlyme-splash.progress' "$init"
echo "splash chain ok"
