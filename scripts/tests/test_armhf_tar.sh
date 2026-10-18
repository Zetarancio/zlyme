#!/bin/sh
# The ARMHF runtime crosses GitHub as one tar. Modes and relative
# symlinks have to survive. A bad member or a changed byte fails.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "armhf-tar: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
src=$work/src
mkdir -p "$src/target/lib" "$src/target/usr/lib/zlyme-armhf"
printf '%s\n' zlyme_my355_armhf_defconfig > "$src/.zlyme-defconfig"
printf '%s\n' 'BR2_arm=y' 'BR2_ARM_EABIHF=y' > "$src/.config"
loader=$ROOT/output-armhf/target/lib/ld-linux-armhf.so.3
[ -f "$loader" ] || fail "real ARMHF loader is not built"
cp -a "$loader" "$src/target/lib/ld-linux-armhf.so.3"
chmod 755 "$src/target/lib/ld-linux-armhf.so.3"
printf 'libc\n' > "$src/target/usr/lib/zlyme-armhf/libc.so.6"
printf 'libm\n' > "$src/target/usr/lib/zlyme-armhf/libm.so.6"
printf 'libgcc\n' > "$src/target/usr/lib/zlyme-armhf/libgcc_s.so.1"
printf 'atomic\n' > "$src/target/usr/lib/zlyme-armhf/libatomic.so.1"
ln -s libatomic.so.1 "$src/target/usr/lib/zlyme-armhf/libatomic.so"
ZLYME_ARMHF_OUTPUT=$src "$ROOT/scripts/armhf-runtime-manifest.sh" >/dev/null
"$ROOT/scripts/armhf-runtime-pack.sh" "$src" "$work/runtime.tar"
"$ROOT/scripts/armhf-runtime-unpack.sh" "$work/runtime.tar" "$work/out"
[ "$(stat -c '%a' "$work/out/target/lib/ld-linux-armhf.so.3")" = 755 ] \
	|| fail "loader mode changed"
[ -L "$work/out/target/usr/lib/zlyme-armhf/libatomic.so" ] \
	|| fail "libatomic.so was not a symlink"
[ "$(readlink "$work/out/target/usr/lib/zlyme-armhf/libatomic.so")" = libatomic.so.1 ] \
	|| fail "libatomic.so target changed"
cmp -s "$src/.config" "$work/out/.config" || fail ".config changed"
cmp -s "$src/.zlyme-defconfig" "$work/out/.zlyme-defconfig" || fail "stamp changed"

printf 'tampered\n' > "$work/out/target/usr/lib/zlyme-armhf/libc.so.6"
if "$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh" "$work/out" >/dev/null 2>&1; then
	fail "changed bytes were accepted"
fi

python3 - "$work/runtime.tar" "$work/bad-bytes.tar" << 'PY'
import sys, tarfile
src, dest = sys.argv[1:]
with tarfile.open(src) as inn, tarfile.open(dest, "w") as out:
    for member in inn.getmembers():
        if member.isfile() and member.name.endswith("libc.so.6"):
            data = b"not-libc\n"
            member.size = len(data)
            out.addfile(member, __import__("io").BytesIO(data))
        elif member.issym():
            out.addfile(member)
        elif member.isfile():
            out.addfile(member, inn.extractfile(member))
        else:
            out.addfile(member)
PY
if "$ROOT/scripts/armhf-runtime-unpack.sh" "$work/bad-bytes.tar" "$work/bad-bytes" >/dev/null 2>&1; then
	fail "tampered archive was accepted"
fi

make_bad() {
	name=$1
	python3 - "$work/runtime.tar" "$work/$name.tar" "$2" << 'PY'
import sys, tarfile, io
src, dest, kind = sys.argv[1:]
with tarfile.open(src) as inn, tarfile.open(dest, "w") as out:
    for member in inn.getmembers():
        if member.isfile():
            out.addfile(member, inn.extractfile(member))
        else:
            out.addfile(member)
    if kind == "escape":
        info = tarfile.TarInfo("../outside")
        payload = b"nope\n"
        info.size = len(payload)
        out.addfile(info, io.BytesIO(payload))
    elif kind == "absolute":
        info = tarfile.TarInfo("/tmp/zlyme-armhf-abs")
        payload = b"nope\n"
        info.size = len(payload)
        out.addfile(info, io.BytesIO(payload))
    elif kind == "link":
        info = tarfile.TarInfo("usr/lib/zlyme-armhf/libevil.so")
        info.type = tarfile.SYMTYPE
        info.linkname = "/etc/passwd"
        out.addfile(info)
PY
}
make_bad escape escape
make_bad absolute absolute
make_bad link link
if "$ROOT/scripts/armhf-runtime-unpack.sh" "$work/escape.tar" "$work/escape" >/dev/null 2>&1; then
	fail "traversal member was extracted"
fi
if [ -e "$work/outside" ] || [ -e /tmp/outside ]; then
	fail "traversal wrote outside the destination"
fi
if "$ROOT/scripts/armhf-runtime-unpack.sh" "$work/absolute.tar" "$work/absolute" >/dev/null 2>&1; then
	fail "absolute member was extracted"
fi
if "$ROOT/scripts/armhf-runtime-unpack.sh" "$work/link.tar" "$work/link" >/dev/null 2>&1; then
	fail "escaping symlink was accepted"
fi
printf 'notelf\n' > "$src/target/lib/ld-linux-armhf.so.3"
chmod 755 "$src/target/lib/ld-linux-armhf.so.3"
ZLYME_ARMHF_OUTPUT=$src "$ROOT/scripts/armhf-runtime-manifest.sh" >/dev/null
"$ROOT/scripts/armhf-runtime-pack.sh" "$src" "$work/notelf.tar"
if "$ROOT/scripts/armhf-runtime-unpack.sh" "$work/notelf.tar" "$work/notelf" >/dev/null 2>"$work/notelf.err"; then
	fail "a non-ELF loader was accepted"
fi
grep -q 'loader is not an ELF' "$work/notelf.err" || fail "non-ELF loader was not named: $(cat "$work/notelf.err")"
echo "armhf tar ok"
