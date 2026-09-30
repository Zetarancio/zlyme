#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ab-map"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_CFG="$work/config"
export ZLYME_AB_SRC="$ROOT/package/system/inputplumber/zlyme_miyoo_flip_ab.yaml"
export ZLYME_AB_OVR="$work/ovr"
mkdir -p "$ZLYME_CFG/zlyme"
"$BIN" sync
test ! -e "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
printf '%s\n' off > "$ZLYME_CFG/zlyme/ab_swap"
"$BIN" sync
test ! -e "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
printf '%s\n' on > "$ZLYME_CFG/zlyme/ab_swap"
"$BIN" sync
grep -q 'id: zlyme_miyoo_flip' "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
grep -q 'event_code: BTN_EAST' "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
awk '
	/event_code: BTN_EAST/ { east = 1 }
	/event_code: BTN_SOUTH/ { south = 1; east = 0 }
	east && /button: East/ { eok = 1 }
	south && /button: South/ { sok = 1 }
	END { if (!eok || !sok) exit 1 }
' "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
printf '%s\n' off > "$ZLYME_CFG/zlyme/ab_swap"
"$BIN" sync
test ! -e "$ZLYME_AB_OVR/zlyme_miyoo_flip.yaml"
echo "ab map ok"
