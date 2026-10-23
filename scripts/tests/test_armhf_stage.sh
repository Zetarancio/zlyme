#!/bin/sh
# ARMHF staging failure and rollback. The donor sysroot is output-armhf,
# the tree produced by scripts/build-armhf-sysroot.sh.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
STAGE=$ROOT/package/system/zlyme-armhf-runtime/stage-runtime.sh
SYS=${ZLYME_ARMHF_SYSROOT:-$ROOT/output-armhf/target}
fail() { echo "armhf-stage-test: $*" >&2; exit 1; }
blocked() { echo "armhf-stage-test blocked: $*" >&2; exit 2; }
[ -f "$SYS/lib/ld-linux-armhf.so.3" ] || blocked "ARMHF sysroot is not at $SYS"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

prime() {
	name=$1
	rm -rf "${work:?}/${name:?}"
	mkdir -p "$work/$name/target/lib" "$work/$name/target/usr/lib"
	cp -a "$SYS/lib/ld-linux-armhf.so.3" "$work/$name/target/lib/"
	cp -a "$SYS/usr/lib/zlyme-armhf" "$work/$name/target/usr/lib/"
	mkdir -p "$work/$name/target/usr/lib/zlyme-armhf/dri"
	cp -a "$SYS/usr/lib/zlyme-armhf/libgcc_s.so.1" \
		"$work/$name/target/usr/lib/zlyme-armhf/dri/"
	printf '%s\n' zlyme_my355_armhf_defconfig > "$work/$name/.zlyme-defconfig"
	printf '%s\n' 'BR2_arm=y' 'BR2_ARM_EABIHF=y' > "$work/$name/.config"
}

aarch64_standin() {
	python3 - "$1" << 'PY'
import sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[5] = 1
header[18] = 0xB7
open(sys.argv[1], "wb").write(header + b"aarch64-libc")
PY
}

new_root() {
	root=$work/roots/$1
	mkdir -p "$root/lib"
	aarch64_standin "$root/lib/libc.so.6"
	printf '%s\n' "$root"
}

run_stage() {
	root=$1
	shift
	# shellcheck disable=SC2086
	env "$@" ZLYME_ARMHF_SYSROOT="$sys_target" ZLYME_ARMHF_DEST_ROOT="$root" \
		"$STAGE" "$root"
}

expect_fail() {
	root=$1
	needle=$2
	shift 2
	before=$(sha256sum "$root/lib/libc.so.6")
	if out=$(run_stage "$root" "$@" 2>&1); then
		fail "expected failure ($needle)"
	fi
	printf '%s\n' "$out" | grep -q "$needle" || fail "missing [$needle] in: $out"
	[ "$(sha256sum "$root/lib/libc.so.6")" = "$before" ] || fail "AArch64 libc changed on: $needle"
}

# Provenance: a directory without the defconfig stamp is not a sysroot.
mkdir -p "$work/bogus/target/lib" "$work/bogus/target/usr/lib/zlyme-armhf"
cp -a "$SYS/lib/ld-linux-armhf.so.3" "$work/bogus/target/lib/"
root=$(new_root provenance)
sys_target=$work/bogus/target
expect_fail "$root" "not the ARMHF defconfig"

prime good
sys_target=$work/good/target
root=$(new_root ok)
before_ok=$(sha256sum "$root/lib/libc.so.6")
run_stage "$root"
[ "$(sha256sum "$root/lib/libc.so.6")" = "$before_ok" ] || fail "success changed AArch64 libc"
[ -f "$root/lib/ld-linux-armhf.so.3" ] || fail "loader missing"
[ -f "$root/usr/lib/zlyme-armhf/libc.so.6" ] || fail "private libc missing"
[ -f "$root/usr/lib/zlyme-armhf/dri/libgcc_s.so.1" ] ||
	fail "nested ARMHF graphics library missing"
[ ! -e "$root/usr/lib/libc.so.6" ] || fail "libc copied to /usr/lib"
printf 'stale\n' > "$root/usr/lib/zlyme-armhf/libstale.so.1"
run_stage "$root"
[ ! -e "$root/usr/lib/zlyme-armhf/libstale.so.1" ] || fail "stale file survived"
[ "$(sha256sum "$root/lib/libc.so.6")" = "$before_ok" ] || fail "second stage changed AArch64 libc"

# ELF64 is rejected before publication, and an existing private file stays.
prime evil
python3 - "$work/evil/target/usr/lib/zlyme-armhf/libevil.so.1" << 'PY'
import sys
header = bytearray(64)
header[0:4] = b"\x7fELF"
header[4] = 2
header[5] = 1
header[18] = 0xB7
open(sys.argv[1], "wb").write(header)
PY
root=$(new_root evil)
mkdir -p "$root/usr/lib/zlyme-armhf"
printf 'keepme\n' > "$root/usr/lib/zlyme-armhf/libkeep.so.1"
sys_target=$work/evil/target
expect_fail "$root" "ELF64"
[ "$(cat "$root/usr/lib/zlyme-armhf/libkeep.so.1")" = "keepme" ] || fail "ELF64 publish changed the destination"

# Wrong interpreter in libc.
prime interp
python3 - "$work/interp/target/usr/lib/zlyme-armhf/libc.so.6" << 'PY'
import sys
path = sys.argv[1]
data = open(path, "rb").read()
old = b"/lib/ld-linux-armhf.so.3"
new = b"/lib/ld-linux-badhf.so.9"
if old not in data or len(old) != len(new):
    raise SystemExit("interpreter string missing")
open(path, "wb").write(data.replace(old, new, 1))
PY
root=$(new_root interp)
sys_target=$work/interp/target
expect_fail "$root" "interpreter is /lib/ld-linux-badhf.so.9"

# A library that needs libc, with libc removed.
prime nolibc
rm -f "$work/nolibc/target/usr/lib/zlyme-armhf/libc.so.6"
root=$(new_root nolibc)
sys_target=$work/nolibc/target
expect_fail "$root" "needs libc.so.6"

# A symlink that leaves the private directory.
prime link
ln -s /etc/passwd "$work/link/target/usr/lib/zlyme-armhf/libescape.so.1"
root=$(new_root link)
sys_target=$work/link/target
expect_fail "$root" "symlink escapes"

# Destination lib/ is a symlink to somewhere else.
prime good
sys_target=$work/good/target
root=$(new_root destlink)
mkdir -p "$work/outside"
rm -rf "${root:?}/lib"
ln -s "$work/outside" "$root/lib"
if out=$(run_stage "$root" 2>&1); then
	fail "destination symlink was accepted"
fi
printf '%s\n' "$out" | grep -q 'symlink' || fail "symlink escape was not named: $out"
[ ! -e "$work/outside/ld-linux-armhf.so.3" ] || fail "loader was written through the symlink"

# Injected publication failures restore the previous private tree.
root=$(new_root rollback)
run_stage "$root"
printf 'previous\n' > "$root/usr/lib/zlyme-armhf/libmarker.so.1"
marker=$(sha256sum "$root/usr/lib/zlyme-armhf/libmarker.so.1" "$root/lib/ld-linux-armhf.so.3")
for inject in publish-lib publish-loader final; do
	expect_fail "$root" "injected" ZLYME_ARMHF_FAIL_AT="$inject"
	[ "$(cat "$root/usr/lib/zlyme-armhf/libmarker.so.1")" = "previous" ] \
		|| fail "$inject did not restore the private tree"
	now=$(sha256sum "$root/usr/lib/zlyme-armhf/libmarker.so.1" "$root/lib/ld-linux-armhf.so.3")
	[ "$now" = "$marker" ] || fail "$inject changed the published loader or marker"
done

# A catchable signal during publication restores the previous tree.
ZLYME_ARMHF_SYSROOT=$sys_target ZLYME_ARMHF_DEST_ROOT=$root \
	ZLYME_ARMHF_PAUSE_AT=after-lib ZLYME_ARMHF_PAUSE_SEC=30 \
	"$STAGE" "$root" > "$work/pause.log" 2>&1 &
pid=$!
i=0
while [ "$i" -lt 50 ]; do
	grep -q 'pausing after-lib' "$work/pause.log" 2>/dev/null && break
	sleep 0.1
	i=$((i + 1))
done
grep -q 'pausing after-lib' "$work/pause.log" || fail "pause did not start: $(cat "$work/pause.log")"
kill -TERM "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
[ "$(cat "$root/usr/lib/zlyme-armhf/libmarker.so.1")" = "previous" ] \
	|| fail "signal during publication left a partial tree"
if find "$root" \( -name '.armhf-stage.*' -o -name '.zlyme-armhf-old.*' \) | grep -q .; then
	fail "rollback left a staging directory"
fi

echo "armhf stage ok"
