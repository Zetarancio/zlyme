#!/bin/sh
# Run the ARMHF probe under qemu-arm in a disposable container.
# The production build image is not used, and qemu is not installed
# on the host or on the Flip.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SYS=${ZLYME_ARMHF_SYSROOT:-$ROOT/output-armhf/target}
PROBE=$SYS/usr/bin/zlyme-armhf-probe
STAGE=$ROOT/package/system/zlyme-armhf-runtime/stage-runtime.sh
IMAGE=zlyme-qemu-armhf
DIGEST=sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
fail() { echo "armhf-qemu: $*" >&2; exit 1; }
blocked() { echo "armhf-qemu blocked: $*" >&2; exit 2; }
[ -f "$PROBE" ] || blocked "probe is not at $PROBE"
[ -f "$ROOT/output-armhf/zlyme-armhf-runtime.manifest" ] || blocked "runtime manifest is missing"
command -v docker >/dev/null 2>&1 || blocked "docker is not available"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/lib" "$work/root/usr/lib"
python3 - "$work/root/lib/libc.so.6" "$work/root/usr/lib/libc.so.6" << 'PY'
import sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[5] = 1
header[18] = 0xB7
for path in sys.argv[1:]:
    open(path, "wb").write(header + b"aarch64-decoy")
PY
before=$(sha256sum "$work/root/lib/libc.so.6" "$work/root/usr/lib/libc.so.6")
ZLYME_ARMHF_SYSROOT=$SYS ZLYME_ARMHF_DEST_ROOT=$work \
	"$STAGE" "$work/root"
after=$(sha256sum "$work/root/lib/libc.so.6" "$work/root/usr/lib/libc.so.6")
[ "$before" = "$after" ] || fail "staging replaced an AArch64 libc"
mkdir -p "$work/root/usr/bin"
cp -a "$PROBE" "$work/root/usr/bin/zlyme-armhf-probe"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	docker build -t "$IMAGE" - << EOF
FROM debian:trixie-slim@${DIGEST}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install -y --no-install-recommends qemu-user \
	&& rm -rf /var/lib/apt/lists/*
EOF
fi

run_probe() {
	label=$1
	shift
	docker run --rm -v "$work/root:/rootfs:ro" "$IMAGE" \
		qemu-arm -L /rootfs "$@" /rootfs/usr/bin/zlyme-armhf-probe \
		> "$work/$label.out" 2> "$work/$label.err"
}

show_libs() {
	echo "----- $1 library trace -----"
	grep -E 'libc\.so|libgcc_s|ld-linux' "$work/$1.err" || true
}

run_probe clean -E LD_DEBUG=libs
grep -qx 'armhf 32 0.3' "$work/clean.out" \
	|| fail "clean output: $(cat "$work/clean.out")"
grep -q '/usr/lib/zlyme-armhf/libc.so.6' "$work/clean.err" \
	|| fail "loader did not name the private libc: $(cat "$work/clean.err")"
if grep -E '/usr/lib/libc\.so\.6|/lib/libc\.so\.6' "$work/clean.err"; then
	fail "loader used an AArch64 libc path"
fi
show_libs clean

run_probe inherited -E LD_DEBUG=libs -E LD_LIBRARY_PATH=/usr/lib
grep -qx 'armhf 32 0.3' "$work/inherited.out" \
	|| fail "inherited output: $(cat "$work/inherited.out") $(cat "$work/inherited.err")"
grep -q '/usr/lib/zlyme-armhf/libc.so.6' "$work/inherited.err" \
	|| fail "inherited run did not use the private libc: $(cat "$work/inherited.err")"
show_libs inherited

# The native ARMHF PortMaster set, plus what SDL2 and OpenAL open later.
# AArch64 copies of the same names come first on LD_LIBRARY_PATH; the
# loader has to skip them and take the private ELF32 objects.
CC=$ROOT/output-armhf/host/bin/arm-buildroot-linux-gnueabihf-gcc
[ -x "$CC" ] || blocked "ARMHF compiler is not at $CC"
cat > "$work/needs.c" << 'EOF'
extern void SDL_GetVersion(void *);
extern int alGetError(void);
extern int FT_Init_FreeType(void *);
extern const char *zlibVersion(void);
extern const char *BZ2_bzlibVersion(void);
extern void pa_simple_free(void *);
extern const char *pa_get_library_version(void);
extern void *gbm_create_device(int);
extern void *eglGetDisplay(void *);
extern const unsigned char *glGetString(unsigned int);
void *volatile keep[] = {
	(void *)SDL_GetVersion, (void *)alGetError, (void *)FT_Init_FreeType,
	(void *)zlibVersion, (void *)BZ2_bzlibVersion, (void *)pa_simple_free,
	(void *)pa_get_library_version, (void *)gbm_create_device,
	(void *)eglGetDisplay, (void *)glGetString,
};
int main(void) { return keep[0] == 0; }
EOF
"$CC" -Wall -Wextra -Werror -o "$work/root/usr/bin/zlyme-armhf-needs" "$work/needs.c" \
	-lSDL2 -lopenal -lfreetype -lz -lbz2 -lpulse-simple -lpulse -lgbm -lEGL -lGLESv2
python3 - "$work/root/usr/lib" << 'PY'
import os, sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[5] = 1
header[18] = 0xB7
for name in ("libSDL2-2.0.so.0", "libopenal.so.1", "libfreetype.so.6", "libbz2.so.1.0",
             "libpulse.so.0", "libpulse-simple.so.0", "libgbm.so.1", "libEGL.so.1",
             "libGLESv2.so.2", "libz.so.1"):
    open(os.path.join(sys.argv[1], name), "wb").write(header + b"aarch64-decoy")
PY
docker run --rm -v "$work/root:/rootfs:ro" "$IMAGE" \
	qemu-arm -L /rootfs -E LD_TRACE_LOADED_OBJECTS=1 -E LD_LIBRARY_PATH=/usr/lib \
	/rootfs/usr/bin/zlyme-armhf-needs > "$work/needs.out" 2> "$work/needs.err" ||
	fail "loader trace failed: $(cat "$work/needs.out" "$work/needs.err")"
echo "----- native PortMaster library trace -----"
cat "$work/needs.out"
if grep -E 'not found|wrong ELF class' "$work/needs.out" "$work/needs.err"; then
	fail "a native PortMaster library did not resolve"
fi
for soname in libSDL2-2.0.so.0 libopenal.so.1 libfreetype.so.6 libbz2.so.1.0 \
	libpulse.so.0 libpulse-simple.so.0 libgbm.so.1 libEGL.so.1 libGLESv2.so.2 libz.so.1
do
	grep -q "$soname => /usr/lib/zlyme-armhf/$soname " "$work/needs.out" ||
		fail "$soname did not resolve in /usr/lib/zlyme-armhf"
done
if grep -E '=> /usr/lib/lib|=> /lib/lib' "$work/needs.out"; then
	fail "a native PortMaster library resolved from an AArch64 directory"
fi
echo "armhf qemu ok"
