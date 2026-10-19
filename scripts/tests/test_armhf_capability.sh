#!/bin/sh
# PortMaster's device_info.txt treats the ARMHF loader as a capability.
# control.txt exports the same Y after a Flip ran an ARMHF program.
# Sourcing device_info again must not leave a second, contradictory bit.
# The GUI library path is unchanged.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CONTROL=$ROOT/package/system/portmaster/control.txt
fail() { echo "armhf-capability: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/PortMaster"
cat > "$work/PortMaster/device_info.txt" << 'EOF'
DEVICE_ARCH=aarch64
DEVICE_HAS_ARMHF=Y
DEVICE_HAS_AARCH64=Y
DEVICE_HAS_VULKAN=Y
EOF
out=$(
	controlfolder=$work/PortMaster \
	HM_TOOLS_DIR=$work \
	HM_PORTS_DIR=$work/ports \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	bash -c '. "$1"; printf "%s %s %s [%s]\n" "$DEVICE_ARCH" "$DEVICE_HAS_ARMHF" "$DEVICE_HAS_AARCH64" "${DEVICE_HAS_VULKAN-}"' \
		sh "$CONTROL"
)
[ "$out" = "aarch64 Y Y []" ] || fail "capability bits: $out"
again=$(
	controlfolder=$work/PortMaster \
	HM_TOOLS_DIR=$work \
	HM_PORTS_DIR=$work/ports \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	bash -c '. "$1"; . "$2"; printf "%s %s\n" "$DEVICE_ARCH" "$DEVICE_HAS_ARMHF"' \
		sh "$CONTROL" "$work/PortMaster/device_info.txt"
)
[ "$again" = "aarch64 Y" ] || fail "second source changed the bit: $again"
ldpath=$(
	controlfolder=$ROOT/package/system/portmaster \
	HM_TOOLS_DIR=$work \
	HM_PORTS_DIR=$work/ports \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	LD_LIBRARY_PATH=/usr/lib \
	bash -c '. "$1"; get_controls; printf "%s" "$LD_LIBRARY_PATH"' sh "$CONTROL"
)
[ "$ldpath" = "/usr/lib/compat:/usr/lib" ] || fail "library path changed: $ldpath"
echo "armhf capability ok"
