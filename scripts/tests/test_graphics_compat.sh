#!/bin/sh
# Production graphics/runtime closure after the Phase 14 probes were retired.
# shellcheck disable=SC1007,SC2016
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CFG=$ROOT/configs/zlyme_my355_defconfig
ARM_CFG=$ROOT/configs/zlyme_my355_armhf_defconfig
ARM_MK=$ROOT/package/system/gl4es-armhf/gl4es-armhf.mk
ARM_RUN=$ROOT/package/system/zlyme-box86/zlyme-box86-gl4es-run
POST=$ROOT/board/my355/post-update.sh
fail() { echo "graphics-compat: $*" >&2; exit 1; }

for option in BR2_PACKAGE_SDL3 BR2_PACKAGE_SDL3_KMSDRM \
	BR2_PACKAGE_SDL3_OPENGLES BR2_PACKAGE_MESA3D_OPENGL_EGL \
	BR2_PACKAGE_MESA3D_OPENGL_ES; do
	grep -qx "$option=y" "$CFG" || fail "$option is not selected"
done
grep -qx 'BR2_PACKAGE_GL4ES_ARMHF=y' "$ARM_CFG" ||
	fail "ARMHF GL4ES is not selected"
grep -q '2037865590d410bcd7b8d1f22b841472ed6d39ac' "$ARM_MK" ||
	fail "ARMHF GL4ES pin changed"
grep -q '/usr/lib/zlyme-armhf/gl4es/libGL.so.1' "$ARM_MK" ||
	fail "ARMHF GL4ES is not installed in its private path"
grep -q -- '-DCMAKE_SKIP_RPATH=ON' "$ARM_MK" ||
	fail "ARMHF GL4ES can retain a build-tree RPATH"
grep -q 'ZLYME_BOX86_NATIVE_LIBRARY_PATH=.*:\$gl4es' "$ARM_RUN" ||
	fail "ARMHF port-bundled library precedence is not preserved"

if grep -q '^BR2_PACKAGE_GL4ES=y\|^BR2_PACKAGE_ZLYME_GRAPHICS_PROBES=y' "$CFG"; then
	fail "retired AArch64 GL4ES or graphics probes are selected"
fi
if grep -Rqs 'ZLYME_GL4ES_RUN\|zlyme-gl4es-run' \
	"$ROOT/package" "$ROOT/configs" "$ROOT/board" "$ROOT/build.sh"; then
	fail "retired AArch64 GL4ES selector remains in production source"
fi
if [ -f "$ROOT/package/system/gl4es/Config.in" ] ||
	[ -f "$ROOT/package/system/gl4es/gl4es.mk" ]; then
	fail "retired AArch64 GL4ES recipe remains"
fi
if [ -f "$ROOT/package/system/zlyme-graphics-probes/Config.in" ] ||
	[ -f "$ROOT/package/system/zlyme-graphics-probes/zlyme-graphics-probes.mk" ]; then
	fail "retired graphics-probe recipe remains"
fi
[ ! -e "$ROOT/scripts/device/phase14-probe-paks.sh" ] ||
	fail "retired probe PAK installer remains"
[ -x "$ROOT/scripts/device/phase14-port-observer.sh" ] ||
	fail "read-only PortMaster observer was removed"

make_probe() {
	dir=$1
	kind=$2
	mkdir -p "$dir"
	printf '%s\n' phase14-graphics-v1 > "$dir/.zlyme-phase14-probe"
	case "$kind" in
	sdl)
		cat > "$dir/launch.sh" << 'EOF'
#!/bin/sh
set -eu
export ZLYME_PROBE_SECONDS=120
exec /usr/libexec/zlyme-tests/zlyme-sdl3-kms-probe
EOF
		;;
	gl)
		cat > "$dir/launch.sh" << 'EOF'
#!/bin/sh
set -eu
export ZLYME_PROBE_SECONDS=120
exec /usr/bin/zlyme-gl4es-run /usr/libexec/zlyme-tests/zlyme-gl4es-probe
EOF
		;;
	pm)
		cat > "$dir/launch.sh" << 'EOF'
#!/bin/sh
set -eu
VALIDATE=${ZLYME_PHASE14_VALIDATE:-/usr/libexec/zlyme-tests/phase14-portmaster-validate}
exec "$VALIDATE" run
EOF
		;;
	esac
	chmod 0755 "$dir/launch.sh"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tools=$work/Tools/my355
make_probe "$tools/Zlyme SDL3 Validation.pak" sdl
make_probe "$tools/Zlyme GL4ES Validation.pak" gl
make_probe "$tools/Zlyme PortMaster Validation.pak" pm

changed="$work/changed"
mkdir -p "$changed/Tools/my355"
make_probe "$changed/Tools/my355/Zlyme SDL3 Validation.pak" sdl
printf '# user change\n' >> \
	"$changed/Tools/my355/Zlyme SDL3 Validation.pak/launch.sh"
make_probe "$changed/Tools/my355/Zlyme GL4ES Validation.pak" gl
printf 'save\n' > "$changed/Tools/my355/Zlyme GL4ES Validation.pak/user.dat"
mkdir -p "$changed/Tools/my355/Zlyme PortMaster Validation.pak"
printf 'user tool\n' > \
	"$changed/Tools/my355/Zlyme PortMaster Validation.pak/launch.sh"

ZLYME_STORAGE_ROOT=$work sh "$POST"
for name in 'Zlyme SDL3 Validation.pak' 'Zlyme GL4ES Validation.pak' \
	'Zlyme PortMaster Validation.pak'; do
	[ ! -e "$tools/$name" ] || fail "owned probe was not removed: $name"
done

ZLYME_STORAGE_ROOT=$changed sh "$POST"
for name in 'Zlyme SDL3 Validation.pak' 'Zlyme GL4ES Validation.pak' \
	'Zlyme PortMaster Validation.pak'; do
	[ -e "$changed/Tools/my355/$name" ] ||
		fail "changed or user-created probe was removed: $name"
done

echo "graphics compatibility ok"
