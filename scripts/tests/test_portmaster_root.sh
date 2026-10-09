#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-portmaster-root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd2=$work/sd2
usb="$work/usb disk"
mkdir -p "$sd2" "$usb"
export ZLYME_PM_FLAG="$work/flag"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_PM_RUN="$work/run"
printf '%s\n' /storage "$sd2" "$usb" > "$work/libraries"

"$BIN" set /storage
test ! -s "$work/flag"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "/storage/Roms/.portmaster"
# The GUI is a child process. The assignment must be exported.
sh -c 'test "$HM_TOOLS_DIR" = "/storage/Roms/.portmaster"'
test "$HM_PORTS_DIR" = "/storage/Roms/Ports (PORTS)"
test "$HM_SCRIPTS_DIR" = "$HM_PORTS_DIR"

if "$BIN" set "$work/not-a-library"; then
	echo "unknown root was accepted" >&2
	exit 1
fi

"$BIN" set "$sd2"
test ! -d "$sd2/Roms/.portmaster"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "$sd2/Roms/.portmaster"
test "$HM_PORTS_DIR" = "$sd2/Roms/Ports (PORTS)"
test "$HM_SCRIPTS_DIR" = "$HM_PORTS_DIR"

if "$BIN" link-libs; then
	echo "link-libs is still a root command" >&2
	exit 1
fi
test ! -d "$sd2/Roms/.portmaster"

rm -rf "$sd2"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "missing disk installed somewhere" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
echo "portmaster root ok"
