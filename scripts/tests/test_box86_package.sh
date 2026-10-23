#!/bin/sh
# Static package contract plus the legal dynamically linked i386 probe.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
ARM_MK=$ROOT/package/system/box86-armhf/box86-armhf.mk
IMPORT_MK=$ROOT/package/system/zlyme-box86/zlyme-box86.mk
CHECK=$ROOT/package/system/zlyme-box86/check-manifest.sh
RUN=$ROOT/package/system/zlyme-box86/zlyme-box86-run
SRC=$ROOT/scripts/tests/box86_probe.c
fail() { echo "box86-package: $*" >&2; exit 1; }

grep -qx 'BR2_PACKAGE_BOX86_ARMHF=y' \
	"$ROOT/configs/zlyme_my355_armhf_defconfig" ||
	fail "ARMHF defconfig does not select Box86"
grep -qx 'BR2_PACKAGE_ZLYME_BOX86=y' "$ROOT/configs/zlyme_my355_defconfig" ||
	fail "product defconfig does not import Box86"
grep -q -- '-DARM64=ON' "$ARM_MK" || fail "generic ARMv8 profile is missing"
grep -q -- '-DARM_DYNAREC=ON' "$ARM_MK" || fail "ARM dynarec is missing"
grep -q -- '-DNOGIT=ON' "$ARM_MK" || fail "archive build is not reproducible"
grep -q -- '-DNO_CONF_INSTALL=ON' "$ARM_MK" ||
	fail "Box86 installs a global config"
grep -q -- '-DNO_LIB_INSTALL=ON' "$ARM_MK" ||
	fail "Box86 imports unreviewed x86 libraries"
if grep -Eiq '/etc/binfmt|systemd|/etc/init\.d|/etc/rc' "$ARM_MK" "$IMPORT_MK"; then
	fail "Box86 registers a service or interpreter"
fi
grep -q 'ZLYME_BOX86_DEPENDENCIES = zlyme-armhf-runtime' "$IMPORT_MK" ||
	fail "Box86 importer does not depend on the private runtime"
grep -q 'LD_LIBRARY_PATH=/usr/lib/zlyme-armhf' "$RUN" ||
	fail "Box86 does not isolate its native ARMHF library search"
# shellcheck disable=SC2016
if grep -q 'LD_LIBRARY_PATH=\$LD_LIBRARY_PATH' "$RUN"; then
	fail "Box86 inherits the AArch64 native library search"
fi
grep -q 'ZLYME_BOX86_RUN=/usr/bin/zlyme-box86-run' \
	"$ROOT/package/system/portmaster/control.txt" ||
	fail "PortMaster has no explicit Box86 selector"
grep -q 'ZLYME_BOX86_GL4ES_RUN=/usr/bin/zlyme-box86-gl4es-run' \
	"$ROOT/package/system/portmaster/control.txt" ||
	fail "PortMaster has no explicit graphical Box86 selector"
grep -qx 'BR2_PACKAGE_GL4ES_ARMHF=y' \
	"$ROOT/configs/zlyme_my355_armhf_defconfig" ||
	fail "ARMHF GL4ES is not selected"
grep -q -- '-DBOX32=OFF' "$ROOT/package/system/box64/box64.mk" ||
	fail "Box64 BOX32 changed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc=${BOX86_X86_CC:-gcc}
"$cc" -m32 -O2 -fno-ident -fno-asynchronous-unwind-tables \
	-Wl,--build-id=none -no-pie -Wall -Wextra -Werror \
	-o "$work/box86-probe" "$SRC"
readelf -h "$work/box86-probe" | grep -q 'Class:.*ELF32' ||
	fail "probe is not ELF32"
readelf -h "$work/box86-probe" | grep -q 'Machine:.*Intel 80386' ||
	fail "probe is not i386"
interp=$(readelf -l "$work/box86-probe" | awk '
	/Requesting program interpreter/ { gsub(/[][]/, "", $NF); print $NF }
')
[ "$interp" = /lib/ld-linux.so.2 ] || fail "probe interpreter is $interp"
readelf -d "$work/box86-probe" | grep -q 'Shared library: \[libc.so.6\]' ||
	fail "probe does not exercise wrapped libc"
cat > "$work/fake-box86" << 'EOF'
#!/bin/sh
printf '%s\n' "$LD_LIBRARY_PATH"
EOF
chmod 0755 "$work/fake-box86"
native=$work/native-armhf
got=$(
	LD_LIBRARY_PATH=/usr/lib/aarch64-only \
	ZLYME_BOX86_NATIVE_LIBRARY_PATH="$native" \
	ZLYME_BOX86_BIN="$work/fake-box86" \
	sh "$RUN" "$work/box86-probe"
)
[ "$got" = "$native:/usr/lib/zlyme-armhf" ] ||
	fail "Box86 native search is $got"

OUT=${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}
if [ -f "$OUT/zlyme-box86.manifest" ]; then
	"$CHECK" "$OUT"
fi

echo "box86 package ok"
