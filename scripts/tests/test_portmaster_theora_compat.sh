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

mk=$ROOT/package/system/portmaster-theora-compat/portmaster-theora-compat.mk
install=$ROOT/package/system/portmaster-theora-compat/install-compat-libs.sh
# The make variable is the text we are searching for, not a shell expansion.
# shellcheck disable=SC2016
if grep -F 'rm -rf $(TARGET_DIR)/usr/lib/compat' "$mk"; then
	fail "theora compat install still removes the whole directory"
fi
grep -q 'install-compat-libs.sh' "$mk" || fail "mk does not use the compat installer"

compat_root=$(mktemp -d)
trap 'rm -rf "$compat_root"' EXIT
mkdir -p "$compat_root/target/usr/lib/compat" "$compat_root/target/usr/lib" \
	"$compat_root/staged/usr/lib/compat"
printf '%s\n' 'sentinel' > "$compat_root/target/usr/lib/compat/libother.so"
printf '%s\n' 'old-decoder' > "$compat_root/target/usr/lib/compat/libtheoradec.so.1.1.4"
ln -s libtheoradec.so.1.1.4 "$compat_root/target/usr/lib/compat/libtheoradec.so.1"
printf '%s\n' 'system-1.2' > "$compat_root/target/usr/lib/libtheoradec.so.2"
printf '%s\n' 'encoder' > "$compat_root/staged/usr/lib/compat/libtheoraenc.so.1"
printf '%s\n' 'new-decoder' > "$compat_root/staged/usr/lib/compat/libtheoradec.so.1.1.4"
ln -s libtheoradec.so.1.1.4 "$compat_root/staged/usr/lib/compat/libtheoradec.so.1"
sh "$install" "$compat_root/target" "$compat_root/staged"
test "$(cat "$compat_root/target/usr/lib/compat/libother.so")" = sentinel
test "$(cat "$compat_root/target/usr/lib/compat/libtheoradec.so.1.1.4")" = new-decoder
test "$(readlink "$compat_root/target/usr/lib/compat/libtheoradec.so.1")" = libtheoradec.so.1.1.4
test ! -e "$compat_root/target/usr/lib/compat/libtheoraenc.so.1"
test "$(cat "$compat_root/target/usr/lib/libtheoradec.so.2")" = system-1.2
printf '%s\n' 'reinstall-decoder' > "$compat_root/staged/usr/lib/compat/libtheoradec.so.1.1.4"
sh "$install" "$compat_root/target" "$compat_root/staged"
test "$(cat "$compat_root/target/usr/lib/compat/libother.so")" = sentinel
test "$(cat "$compat_root/target/usr/lib/compat/libtheoradec.so.1.1.4")" = reinstall-decoder
test "$(readlink "$compat_root/target/usr/lib/compat/libtheoradec.so.1")" = libtheoradec.so.1.1.4
rm -rf "$compat_root"
trap - EXIT

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
