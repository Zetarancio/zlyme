#!/bin/sh
# shellcheck disable=SC1007
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
test "$("$BIN" get)" = "$sd2"

"$BIN" set "$usb"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "$usb/Roms/.portmaster"
test "$HM_PORTS_DIR" = "$usb/Roms/Ports (PORTS)"
test "$("$BIN" get)" = "$usb"

if "$BIN" link-libs; then
	echo "link-libs is still a root command" >&2
	exit 1
fi
test ! -d "$sd2/Roms/.portmaster"

# The mountpoint stays. Absent means it is not in the registry.
"$BIN" set "$sd2"
printf '%s\n' /storage > "$work/libraries"
test -d "$sd2"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered sd2 was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if "$BIN" get >"$work/out" 2>"$work/err"; then
	echo "unregistered sd2 fell back" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"

"$BIN" set "$usb" && echo "set accepted an unregistered usb path" >&2 && exit 1
printf '%s\n' "$usb" > "$work/flag"
test -d "$usb"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered usb was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if grep -q '/storage' "$work/out"; then
	echo "missing library fell back to /storage" >&2
	exit 1
fi

mkdir -p "$work/not-registered"
printf '%s\n' "$work/not-registered" > "$work/flag"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered directory was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"

printf '%s\n%s\n' "$sd2" "$usb" > "$work/flag"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "multi-line selection was concatenated" >&2
	exit 1
fi
grep -q "malformed" "$work/err"
test ! -s "$work/out"
if "$BIN" get >"$work/out" 2>"$work/err"; then
	echo "malformed get succeeded" >&2
	exit 1
fi
test ! -s "$work/out"

printf '%s\n' /storage "$sd2" "$usb" > "$work/libraries"
"$BIN" set /storage
test ! -s "$work/flag"
test "$("$BIN" get)" = /storage
echo "portmaster root ok"
