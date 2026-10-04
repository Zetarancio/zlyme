#!/bin/sh
# boost and merge are not product settings. Leftover files are ignored.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ctl=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl
seed=$ROOT/board/my355/fsoverlay/etc/init.d/S15bootpart
reset=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset
gov=$ROOT/package/system/nextui/zlyme/governor.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if grep -q 'boost=' "$seed" || grep -q 'merge=' "$seed"; then
	echo "S15 still seeds boost or merge" >&2
	exit 1
fi
grep -q 'for n in boost merge' "$seed"
grep -q 'boost zram merge' "$reset"
if grep -q 'apply-merge' "$reset" || grep -q 'apply-boost' "$ctl"; then
	echo "retired apply commands are still wired" >&2
	exit 1
fi
if grep -q 'zlyme-ctl get boost' "$gov"; then
	echo "governor still reads the boost setting" >&2
	exit 1
fi

cat > "$work/zlyme.conf" <<EOF
ZLYME_STORAGE=$work/storage
ZLYME_CFG=\${ZLYME_STORAGE}/.config
ZLYME_DEFAULTS=/usr/share/zlyme
ZLYME_BOOT=$work/boot
EOF
mkdir -p "$work/storage/.config/zlyme"
printf '%s\n' on > "$work/storage/.config/zlyme/boost"
printf '%s\n' on > "$work/storage/.config/zlyme/merge"
export ZLYME_CONF=$work/zlyme.conf

test "$("$ctl" get boost)" = off
test "$("$ctl" get merge)" = off
"$ctl" set boost on
"$ctl" set merge on
test ! -e "$work/storage/.config/zlyme/boost"
test ! -e "$work/storage/.config/zlyme/merge"
"$ctl" status > "$work/status"
if grep -q '^boost=' "$work/status" || grep -q '^merge=' "$work/status"; then
	echo "status still lists retired settings" >&2
	exit 1
fi
if "$ctl" apply-boost >/dev/null 2>&1; then
	echo "apply-boost still succeeds" >&2
	exit 1
fi

echo "retired settings ok"
