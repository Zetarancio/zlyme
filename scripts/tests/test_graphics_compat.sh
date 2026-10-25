#!/bin/sh
# Source/package contract for SDL3 and isolated GL4ES validation.
# shellcheck disable=SC1007,SC2016
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CFG=$ROOT/configs/zlyme_my355_defconfig
GLMK=$ROOT/package/system/gl4es/gl4es.mk
RUN=$ROOT/package/system/gl4es/zlyme-gl4es-run
ARM_MK=$ROOT/package/system/gl4es-armhf/gl4es-armhf.mk
ARM_RUN=$ROOT/package/system/zlyme-box86/zlyme-box86-gl4es-run
PROBES=$ROOT/package/system/zlyme-graphics-probes
FIXTURES=$ROOT/scripts/device/phase14-probe-paks.sh
OBSERVER=$ROOT/scripts/device/phase14-port-observer.sh
fail() { echo "graphics-compat: $*" >&2; exit 1; }

for option in BR2_PACKAGE_GL4ES BR2_PACKAGE_ZLYME_GRAPHICS_PROBES \
	BR2_PACKAGE_SDL3 BR2_PACKAGE_SDL3_KMSDRM; do
	grep -qx "$option=y" "$CFG" || fail "$option is not selected"
done
grep -q '/usr/lib/portmaster/gl4es/aarch64/libGL.so.1' "$GLMK" ||
	fail "GL4ES is not installed in its isolated path"
grep -q '81547d986798e876de8b434193920b606a72363f' "$GLMK" ||
	fail "AArch64 GL4ES is not the ROCKNIX pin"
grep -q -- '-DNOEGL=ON' "$GLMK" || fail "AArch64 GL4ES is missing NOEGL"
grep -q -- '-DODROID=ON' "$GLMK" || fail "AArch64 GL4ES is missing ODROID"
grep -q -- '-DNOX11=ON' "$GLMK" || fail "AArch64 GL4ES is missing NOX11"
grep -q 'GLX_STUBS\|EGL_WRAPPER\|NO_INIT_CONSTRUCTOR' "$GLMK" &&
	fail "AArch64 GL4ES enables a rejected option"
grep -q '2037865590d410bcd7b8d1f22b841472ed6d39ac' "$ARM_MK" ||
	fail "ARMHF GL4ES pin changed"
grep -q '/usr/lib/zlyme-armhf/gl4es/libGL.so.1' "$ARM_MK" ||
	fail "ARMHF GL4ES is not installed in its isolated private path"
grep -q -- '-DCMAKE_SKIP_RPATH=ON' "$GLMK" ||
	fail "AArch64 GL4ES can retain a build-tree RPATH"
grep -q -- '-DCMAKE_SKIP_RPATH=ON' "$ARM_MK" ||
	fail "ARMHF GL4ES can retain a build-tree RPATH"
if grep -q '/usr/lib/compat' "$GLMK" "$ARM_MK" ||
	grep -q '$(TARGET_DIR)/usr/lib/libGL' "$GLMK" "$ARM_MK" ||
	grep -q '$(STAGING_DIR)/usr/lib/libGL' "$GLMK" "$ARM_MK"; then
	fail "GL4ES is exposed as an implicit shared fallback"
fi
grep -q 'ZLYME_GL4ES_RUN=/usr/bin/zlyme-gl4es-run' \
	"$ROOT/package/system/portmaster/control.txt" ||
	fail "PortMaster has no explicit GL4ES selector"
grep -q 'ZLYME_BOX86_NATIVE_LIBRARY_PATH=.*:\$gl4es' "$ARM_RUN" ||
	fail "ARMHF port-bundled library precedence is not preserved"
grep -q 'SDL_CreateWindowAndRenderer' "$PROBES/sdl3-kms-probe.c" ||
	fail "SDL3 probe does not create a window and renderer"
grep -q 'SDL_EVENT_GAMEPAD_BUTTON_DOWN' "$PROBES/sdl3-kms-probe.c" ||
	fail "SDL3 probe does not observe gamepad input"
grep -q 'glBegin(GL_TRIANGLES)' "$PROBES/gl4es-probe.c" ||
	fail "GL4ES probe is not a desktop OpenGL workload"
if grep -Rq '/etc/init\.d\|systemd' "$PROBES" "$ROOT/package/system/gl4es"; then
	fail "graphics probes install a service"
fi
grep -q 'Zlyme SDL3 Validation\.pak' "$FIXTURES" ||
	fail "normal NextUI SDL3 fixture is missing"
grep -q 'Zlyme GL4ES Validation\.pak' "$FIXTURES" ||
	fail "normal NextUI GL4ES fixture is missing"
grep -q 'refusing non-test entry' "$FIXTURES" ||
	fail "probe fixture removal does not verify ownership"
grep -q 'scripts/device/phase14-probe-paks\.sh' \
	"$PROBES/zlyme-graphics-probes.mk" ||
	fail "probe fixtures are not installed with the diagnostics"
if grep -Eq '(/dev/uinput|EVIOCGRAB|input_event)' "$FIXTURES"; then
	fail "probe fixture injects or grabs input"
fi
grep -Fq 'NR > 1 && $2 ~ /^[0-9]+$/ { print $2 }' "$OBSERVER" ||
	fail "DRM observer does not read the debugfs TGID column"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/drm-clients" << 'EOF'
command	tgid	dev	master	a	uid	magic
nextui.elf	4242	0	y	y	0	1
EOF
got=$(awk 'NR > 1 && $2 ~ /^[0-9]+$/ { print $2 }' "$work/drm-clients")
[ "$got" = 4242 ] || fail "DRM clients fixture parsed PID $got"
mkdir -p "$work/gl4es"
: > "$work/gl4es/libGL.so.1"
cat > "$work/show-path" << 'EOF'
#!/bin/sh
printf '%s\n' "$LD_LIBRARY_PATH"
if [ -n "${LIBGL_FB+x}" ]; then
	printf 'FB=%s\n' "$LIBGL_FB"
else
	printf 'FB=unset\n'
fi
EOF
chmod 0755 "$work/show-path"
got=$(
	ZLYME_GL4ES_DIR="$work/gl4es" \
	LD_LIBRARY_PATH=/port/first:/usr/lib:/port/second:/usr/lib/compat:/storage/.config/zlyme/lib \
		sh "$RUN" "$work/show-path"
)
[ "$got" = "/port/first:/port/second:$work/gl4es:/usr/lib:/usr/lib/compat:/storage/.config/zlyme/lib
FB=unset" ] ||
	fail "GL4ES selector precedence is $got"
got=$(
	ZLYME_GL4ES_DIR="$work/gl4es" \
	LIBGL_FB=4 \
	LD_LIBRARY_PATH=/port/local:/usr/lib \
		sh "$RUN" "$work/show-path"
)
[ "$got" = "/port/local:$work/gl4es:/usr/lib
FB=4" ] || fail "preset LIBGL_FB was replaced: $got"
grep -q 'LIBGL_FB:=3' "$RUN" &&
	fail "AArch64 GL4ES selector still defaults to mode 3"
grep -q 'PBuffer' "$RUN" &&
	fail "AArch64 GL4ES selector still describes mode 3 as PBuffer"
grep -q 'SDL_VIDEODRIVER:=kmsdrm' "$RUN" ||
	fail "AArch64 GL4ES selector does not prefer KMSDRM"
grep -q 'GL4ES_VIDEO_DRIVER' "$PROBES/gl4es-probe.c" ||
	fail "GL4ES probe does not report the active video driver"
[ -f "$ROOT/board/my355/patches/sdl2/0003-kmsdrm-soft-fail-move-cursor.patch" ] ||
	fail "SDL2 KMSDRM cursor soft-fail patch is missing"
grep -q 'disabling HW cursor' \
	"$ROOT/board/my355/patches/sdl2/0003-kmsdrm-soft-fail-move-cursor.patch" ||
	fail "SDL2 cursor patch does not disable HW cursor on MoveCursor failure"

echo "graphics compatibility ok"
