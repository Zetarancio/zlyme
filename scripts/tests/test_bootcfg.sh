#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-bootcfg"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_CFG="$work/config"
mkdir -p "$ZLYME_CFG/zlyme"
snap=$work/snap

"$BIN" capture "$snap"
grep -qx 'gpu=libmali' "$snap"
grep -qx 'undervolt=off' "$snap"
grep -qx 'otg=on' "$snap"
grep -qx 'hdmi=on' "$snap"
grep -qx 'sd2=on' "$snap"
if grep -q ab_swap "$snap"; then
	echo "ab_swap is not a boot setting" >&2
	exit 1
fi
if "$BIN" dirty "$snap"; then
	echo "fresh snapshot was dirty" >&2
	exit 1
fi

printf '%s\n' off > "$ZLYME_CFG/zlyme/hdmi"
printf '%s\n' on > "$ZLYME_CFG/zlyme/hdmi"
if "$BIN" dirty "$snap"; then
	echo "hdmi toggled back to on was dirty" >&2
	exit 1
fi

printf '%s\n' off > "$ZLYME_CFG/zlyme/hdmi"
"$BIN" dirty "$snap"
printf '%s\n' l1 > "$ZLYME_CFG/zlyme/undervolt"
"$BIN" capture "$snap"
if "$BIN" dirty "$snap"; then
	echo "captured undervolt was still dirty" >&2
	exit 1
fi
rm -f "$ZLYME_CFG/zlyme/undervolt"
"$BIN" dirty "$snap"
echo "bootcfg ok"
