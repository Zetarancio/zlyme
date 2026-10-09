#!/bin/sh
# PortMaster's private Theora 1.1 decoder is not the system libtheora 1.2.
set -eu
# shellcheck disable=SC1007
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CONTROL=$ROOT/package/system/portmaster/control.txt
target=${1:-$ROOT/output/target}
fail() {
	echo "portmaster-theora-compat: $*" >&2
	exit 1
}

grep -q 'clibs="/usr/lib/compat"' "$CONTROL" || fail "control.txt has no compat path"
if grep -q 'libtheoradec.so.1 -> libtheoradec.so.2' "$CONTROL"; then
	fail "control.txt symlinks the Theora SONAMEs"
fi
ldpath=$(
	controlfolder=$ROOT/package/system/portmaster \
	HM_TOOLS_DIR=/tmp \
	HM_PORTS_DIR=/tmp \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	LD_LIBRARY_PATH=/opt/runtime/libs \
	bash -c '. "$1"; get_controls; printf "%s" "$LD_LIBRARY_PATH"' sh "$CONTROL"
)
test "$ldpath" = "/usr/lib/compat:/opt/runtime/libs" || fail "LD_LIBRARY_PATH was replaced: $ldpath"
ldpath=$(
	controlfolder=$ROOT/package/system/portmaster \
	HM_TOOLS_DIR=/tmp \
	HM_PORTS_DIR=/tmp \
	SDL_GAMECONTROLLERCONFIG_FILE=/dev/null \
	LD_LIBRARY_PATH=/usr/lib/compat:/opt/runtime/libs \
	bash -c '. "$1"; get_controls; get_controls; printf "%s" "$LD_LIBRARY_PATH"' sh "$CONTROL"
)
test "$ldpath" = "/usr/lib/compat:/opt/runtime/libs" || fail "compat path was duplicated: $ldpath"

compat=$target/usr/lib/compat/libtheoradec.so.1
system=$target/usr/lib/libtheoradec.so.2
if [ ! -e "$compat" ] || [ ! -e "$system" ]; then
	if [ "${ZLYME_REQUIRE_THEORA:-}" = 1 ]; then
		fail "compat decoder or system decoder is missing under $target"
	fi
	echo "portmaster-theora-compat: image tree not built, source check only"
	exit 0
fi

[ -L "$compat" ] || fail "compat SONAME is not a symlink to the 1.1.1 library"
[ -f "$system" ] || fail "system libtheoradec.so.2 is missing"
if [ -e "$target/usr/lib/libtheoradec.so.1" ]; then
	fail "system libtheoradec.so.1 exists"
fi
link=$(readlink "$compat")
case "$link" in
	*so.2*) fail "compat library points at SONAME .2: $link" ;;
esac
case "$link" in
	libtheoradec.so.1.*) ;;
	*) fail "compat library target is $link" ;;
esac
[ -f "$target/usr/lib/compat/$link" ] || fail "versioned compat library is missing"

readelf=${READELF:-readelf}
if ! command -v "$readelf" >/dev/null 2>&1; then
	if [ -x "$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-readelf" ]; then
		readelf=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-readelf
	else
		fail "readelf is required"
	fi
fi

header=$("$readelf" -h "$target/usr/lib/compat/$link")
printf '%s\n' "$header" | grep -q 'AArch64' || fail "compat library is not AArch64"
dyn=$("$readelf" -d "$target/usr/lib/compat/$link")
printf '%s\n' "$dyn" | grep -q 'SONAME.*\[libtheoradec\.so\.1\]' || fail "SONAME is not libtheoradec.so.1"
printf '%s\n' "$dyn" | grep -q 'NEEDED.*\[libc\.so\.6\]' || fail "decoder does not need libc.so.6"
if printf '%s\n' "$dyn" | grep -q 'NEEDED.*libtheoradec\.so\.2'; then
	fail "compat decoder depends on libtheoradec.so.2"
fi
if printf '%s\n' "$dyn" | grep 'NEEDED' | grep -q '/'; then
	fail "compat decoder has a path-shaped NEEDED entry"
fi
sys=$("$readelf" -d "$system")
printf '%s\n' "$sys" | grep -q 'SONAME.*\[libtheoradec\.so\.2\]' || fail "system SONAME changed"

echo "portmaster theora compat ok"
