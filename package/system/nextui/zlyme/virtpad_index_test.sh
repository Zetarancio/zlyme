#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$dir/virtpad-index.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/dev/input" \
	"$root/sys/class/input" \
	"$root/sys/devices/virtual/input/input5/js1/device" \
	"$root/sys/devices/platform/serial/input/input4/js0/device"
: > "$root/dev/input/js0"
: > "$root/dev/input/js1"
printf '%s\n' 'Miyoo Flip Gamepad' > "$root/sys/devices/platform/serial/input/input4/js0/device/name"
printf '%s\n' 'Microsoft X-Box 360 pad' > "$root/sys/devices/virtual/input/input5/js1/device/name"
ln -s ../../devices/platform/serial/input/input4/js0 "$root/sys/class/input/js0"
ln -s ../../devices/virtual/input/input5/js1 "$root/sys/class/input/js1"

got=$(zlyme_virtpad_js_index "$root")
[ "$got" = 1 ] || {
	echo "builtin virtual index: got '$got' want 1" >&2
	exit 1
}

rm -rf "$root/dev/input" "$root/sys/class/input" "$root/sys/devices"
mkdir -p "$root/dev/input" "$root/sys/class/input" \
	"$root/sys/devices/virtual/input/input9/js0/device"
: > "$root/dev/input/js0"
printf '%s\n' 'Microsoft X-Box 360 pad' > "$root/sys/devices/virtual/input/input9/js0/device/name"
ln -s ../../devices/virtual/input/input9/js0 "$root/sys/class/input/js0"
got=$(zlyme_virtpad_js_index "$root")
[ "$got" = 0 ] || {
	echo "only virtual index: got '$got' want 0" >&2
	exit 1
}

echo VIRTINDEX_OK
