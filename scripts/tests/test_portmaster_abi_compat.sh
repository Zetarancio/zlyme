#!/bin/sh
# X-Moto and JVGS ABI gaps are source-built, not the ROCKNIX blob.
set -eu
# shellcheck disable=SC1007
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "portmaster-abi-compat: $*" >&2
	exit 1
}

mk=$ROOT/package/system/portmaster-xml2-compat/portmaster-xml2-compat.mk
install=$ROOT/package/system/portmaster-xml2-compat/install-compat-libs.sh
product=$ROOT/configs/zlyme_my355_defconfig
minimal=$ROOT/configs/zlyme_my355_minimal_defconfig
glmk=$ROOT/package/system/gl4es/gl4es.mk
arm=$ROOT/package/system/gl4es-armhf/gl4es-armhf.mk

grep -q 'PORTMASTER_XML2_COMPAT_VERSION = 2.13.9' "$mk" || fail "xml2 pin is not 2.13.9"
grep -q -- '--without-icu' "$mk" || fail "xml2 compat can link ICU"
grep -q -- '--libdir=/usr/lib/compat' "$mk" || fail "xml2 compat is not isolated"
body=$(grep -v '^[[:space:]]*#' "$mk" || true)
printf '%s\n' "$body" | grep -q 'compat.tar.gz' && fail "xml2 recipe fetches the ROCKNIX archive"
printf '%s\n' "$body" | grep -q 'libxml2.so.16' && fail "xml2 recipe aliases the system SONAME"
grep -q 'install-compat-libs.sh' "$mk" || fail "xml2 recipe has no allowlist installer"
# shellcheck disable=SC2016
if grep -F 'rm -rf $(TARGET_DIR)/usr/lib/compat' "$mk"; then
	fail "xml2 install removes the whole compat directory"
fi
grep -qx 'BR2_PACKAGE_PORTMASTER_XML2_COMPAT=y' "$product" || fail "product defconfig omits xml2 compat"
grep -qx 'BR2_PACKAGE_SDL2_NET=y' "$product" || fail "product defconfig omits SDL2_net"
grep -qx 'BR2_PACKAGE_LIBMODPLUG=y' "$product" || fail "product defconfig omits libmodplug"
if grep -q 'PORTMASTER_XML2_COMPAT\|SDL2_NET\|LIBMODPLUG' "$minimal"; then
	fail "minimal defconfig gained a PortMaster ABI package"
fi
grep -q '81547d986798e876de8b434193920b606a72363f' "$glmk" || fail "AArch64 GL4ES pin changed"
grep -q 'gl4es.tar.gz' "$glmk" && fail "AArch64 GL4ES uses the binary archive"
grep -q '2037865590d410bcd7b8d1f22b841472ed6d39ac' "$arm" || fail "ARMHF GL4ES pin changed"

compat_root=$(mktemp -d)
trap 'rm -rf "$compat_root"' EXIT
mkdir -p "$compat_root/target/usr/lib/compat" "$compat_root/target/usr/lib" \
	"$compat_root/staged/usr/lib/compat"
printf '%s\n' 'sentinel' > "$compat_root/target/usr/lib/compat/libtheoradec.so.1.1.4"
printf '%s\n' 'system-16' > "$compat_root/target/usr/lib/libxml2.so.16"
printf '%s\n' 'unversioned' > "$compat_root/staged/usr/lib/compat/libxml2.so"
printf '%s\n' 'decoder' > "$compat_root/staged/usr/lib/compat/libxml2.so.2.13.9"
ln -s libxml2.so.2.13.9 "$compat_root/staged/usr/lib/compat/libxml2.so.2"
sh "$install" "$compat_root/target" "$compat_root/staged"
test "$(cat "$compat_root/target/usr/lib/compat/libtheoradec.so.1.1.4")" = sentinel
test "$(cat "$compat_root/target/usr/lib/compat/libxml2.so.2.13.9")" = decoder
test "$(readlink "$compat_root/target/usr/lib/compat/libxml2.so.2")" = libxml2.so.2.13.9
test ! -e "$compat_root/target/usr/lib/compat/libxml2.so"
test "$(cat "$compat_root/target/usr/lib/libxml2.so.16")" = system-16
test ! -e "$compat_root/target/usr/lib/libxml2.so.2"
rm -rf "$compat_root"
trap - EXIT

target=${1:-$ROOT/output/target}
re=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-readelf
nm=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-nm
xml=$target/usr/lib/compat/libxml2.so.2
mod=$target/usr/lib/libmodplug.so.1
net=$target/usr/lib/libSDL2_net-2.0.so.0
if [ ! -f "$xml" ] || [ ! -f "$mod" ] || [ ! -f "$net" ]; then
	echo "portmaster-abi-compat: source check ok; built libraries not in $target"
	exit 0
fi
if [ ! -x "$re" ] || [ ! -x "$nm" ]; then
	fail "target libraries exist but readelf is missing"
fi

dyn=$("$re" -d "$xml")
printf '%s\n' "$dyn" | grep -q 'SONAME.*\[libxml2\.so\.2\]' || fail "xml2 SONAME"
printf '%s\n' "$dyn" | grep -q 'libicu' && fail "xml2 compat needs ICU"
"$nm" -D "$xml" | grep -q 'xmlParseFile@@LIBXML2_2.4.30' || fail "missing LIBXML2_2.4.30"
for sym in xmlFreeDoc xmlGetProp xmlStrcmp xmlNodeGetContent xmlParseMemory \
	xmlDocGetRootElement xmlCleanupParser xmlSetGenericErrorFunc; do
	"$nm" -D "$xml" | grep -q "${sym}@@LIBXML2_2.4.30" || fail "missing $sym"
done
if [ -e "$target/usr/lib/libxml2.so.2" ]; then
	fail "system directory has libxml2.so.2"
fi
if [ -f "$target/usr/lib/libxml2.so.16" ]; then
	"$re" -d "$target/usr/lib/libxml2.so.16" | grep -q 'SONAME.*\[libxml2\.so\.16\]' ||
		fail "system libxml2 SONAME changed"
fi

"$re" -d "$mod" | grep -q 'SONAME.*\[libmodplug\.so\.1\]' || fail "modplug SONAME"
for sym in ModPlug_Load ModPlug_Read ModPlug_Unload ModPlug_Seek \
	ModPlug_GetSettings ModPlug_SetSettings ModPlug_SetMasterVolume; do
	"$nm" -D "$mod" | grep -q " ${sym}$" || fail "missing $sym"
done

"$re" -d "$net" | grep -q 'SONAME.*\[libSDL2_net-2\.0\.so\.0\]' || fail "SDL2_net SONAME"
if "$re" -d "$xml" "$mod" "$net" | grep -E -q 'RPATH|RUNPATH'; then
	fail "a compatibility library keeps a build RPATH"
fi
if [ -e "$target/usr/lib/libSDL2_net.la" ]; then
	fail "SDL2_net left a libtool file on the target"
fi
"$re" -h "$xml" "$mod" "$net" | grep -q 'AArch64' || fail "a built library is not AArch64"
if [ -e "$target/usr/lib/portmaster/gl4es/aarch64/libEGL.so.1" ]; then
	fail "AArch64 GL4ES directory gained an EGL wrapper"
fi

echo "portmaster-abi-compat: built libraries ok"
