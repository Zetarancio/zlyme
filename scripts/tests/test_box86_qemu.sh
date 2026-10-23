#!/bin/sh
# Execute the legal i386 probe through ARMHF Box86 under qemu-arm.
# This proves the CPU/private-glibc layer, not Flip graphics.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
OUT=${ZLYME_ARMHF_OUTPUT:-$ROOT/output-armhf}
SYS=$OUT/target
BOX86=$SYS/usr/bin/box86
STAGE=$ROOT/package/system/zlyme-armhf-runtime/stage-runtime.sh
IMAGE=zlyme-qemu-armhf
DIGEST=sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
fail() { echo "box86-qemu: $*" >&2; exit 1; }
blocked() { echo "box86-qemu blocked: $*" >&2; exit 2; }

[ -x "$BOX86" ] || blocked "Box86 is not built at $BOX86"
[ -f "$OUT/zlyme-box86.manifest" ] || blocked "Box86 manifest is missing"
command -v docker >/dev/null 2>&1 || blocked "docker is unavailable"
command -v gcc >/dev/null 2>&1 || blocked "gcc is unavailable"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/lib" "$work/root/usr/lib" "$work/root/usr/bin"
ZLYME_ARMHF_SYSROOT=$SYS ZLYME_ARMHF_DEST_ROOT=$work \
	"$STAGE" "$work/root"
cp -a "$BOX86" "$work/root/usr/bin/box86"

gcc -m32 -O2 -fno-ident -fno-asynchronous-unwind-tables \
	-Wl,--build-id=none -no-pie -Wall -Wextra -Werror \
	-o "$work/root/usr/bin/box86-probe" \
	"$ROOT/scripts/tests/box86_probe.c"
printf '%s\n' 'not an ELF' > "$work/root/usr/bin/not-elf"
if ZLYME_BOX86_BIN=/bin/true \
	sh "$ROOT/package/system/zlyme-box86/zlyme-box86-run" \
	"$work/root/usr/bin/not-elf" >"$work/invalid.out" 2>"$work/invalid.err"; then
	fail "invalid ELF returned success"
fi
grep -q 'not a little-endian ELF32 i386' "$work/invalid.err" ||
	fail "invalid ELF diagnostic: $(cat "$work/invalid.err")"

cat > "$work/missing.c" << 'EOF'
int zlyme_missing(void) { return 1; }
EOF
gcc -m32 -shared -fPIC -Wl,--build-id=none \
	-o "$work/libzlyme-missing.so" "$work/missing.c"
gcc -m32 -O2 -fno-ident -fno-asynchronous-unwind-tables \
	-Wl,--build-id=none -no-pie -Wl,--no-as-needed \
	-L"$work" -Wl,-rpath,/zlyme-missing -lzlyme-missing \
	-o "$work/root/usr/bin/box86-missing" \
	"$ROOT/scripts/tests/box86_probe.c"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	docker build -t "$IMAGE" - << EOF
FROM debian:trixie-slim@${DIGEST}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install -y --no-install-recommends qemu-user \
	&& rm -rf /var/lib/apt/lists/*
EOF
fi

run_box86() {
	name=$1
	shift
	docker run --rm -v "$work/root:/rootfs:ro" "$IMAGE" \
		qemu-arm -L /rootfs -E BOX86_NOBANNER=1 -E BOX86_LOG=1 \
		/rootfs/usr/bin/box86 "$@" \
		> "$work/$name.out" 2> "$work/$name.err"
}

run_box86 probe /rootfs/usr/bin/box86-probe ||
	fail "probe failed: $(cat "$work/probe.err")"
grep -qx 'box86-x86 4 475f677f' "$work/probe.out" ||
	fail "probe output: $(cat "$work/probe.out")"

if run_box86 missing /rootfs/usr/bin/box86-missing; then
	fail "missing library returned success"
fi
cat "$work/missing.out" "$work/missing.err" > "$work/missing.log"
grep -q 'libzlyme-missing.so' "$work/missing.log" ||
	fail "missing library was not named: $(cat "$work/missing.log")"

echo "box86 qemu ok"
