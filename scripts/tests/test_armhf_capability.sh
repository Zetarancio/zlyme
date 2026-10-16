#!/bin/sh
# PortMaster's device_info.txt treats the ARMHF loader as a capability.
# Zlyme's control.txt turns that bit back off. The GUI library path is
# unchanged.
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
EOF
out=$(
	controlfolder=$work/PortMaster \
	HM_TOOLS_DIR=$work \
	HM_PORTS_DIR=$work/ports \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	bash -c '. "$1"; printf "%s %s %s\n" "$DEVICE_ARCH" "$DEVICE_HAS_ARMHF" "$DEVICE_HAS_AARCH64"' \
		sh "$CONTROL"
)
[ "$out" = "aarch64 N Y" ] || fail "capability bits: $out"
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
