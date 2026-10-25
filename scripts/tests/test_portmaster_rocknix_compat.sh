#!/bin/sh
# The pinned ROCKNIX compat archive accounts for 49 SONAMEs.
# Source checks always run. --built requires the installed closure.
set -eu
# shellcheck disable=SC1007
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "portmaster-rocknix-compat: $*" >&2
	exit 1
}
built=0
if [ "${1:-}" = --built ]; then
	built=1
	shift
fi
pkg=$ROOT/package/system/portmaster-rocknix-compat
tsv=$pkg/sonames.tsv
allow=$pkg/allowlist.sha256
product=$ROOT/configs/zlyme_my355_defconfig
minimal=$ROOT/configs/zlyme_my355_minimal_defconfig
mk=$pkg/portmaster-rocknix-compat.mk

grep -q '691f24bceb72228f20d41ddb4a1e76ed76a1b0b8' "$mk" || fail "archive is not pinned"
# The $(...) text is the makefile, not this shell.
# shellcheck disable=SC2016
grep -q 'packages/raw/$(PORTMASTER_ROCKNIX_COMPAT_VERSION)' "$mk" || fail "archive URL is not pinned"
grep -q 'main/compat.tar.gz' "$mk" && fail "archive URL tracks main"
grep -qx 'BR2_PACKAGE_PORTMASTER_ROCKNIX_COMPAT=y' "$product" || fail "product defconfig omits the compat set"
grep -qx 'BR2_GCC_ENABLE_OPENMP=y' "$product" || fail "product defconfig has no libgomp"
if grep -q 'PORTMASTER_ROCKNIX_COMPAT\|BR2_GCC_ENABLE_OPENMP\|BR2_PACKAGE_XORG7' "$minimal"; then
	fail "minimal defconfig gained the compat set"
fi
# shellcheck disable=SC2016
grep -q 'clibs="/usr/lib/compat"' "$ROOT/package/system/portmaster/control.txt" ||
	fail "compat directory is not the PortMaster path"

files=$(awk -F '\t' 'NR > 1 { print $1 }' "$tsv" | wc -l | tr -d ' ')
sonames=$(awk -F '\t' 'NR > 1 { print $3 }' "$tsv" | sort -u | wc -l | tr -d ' ')
[ "$files" -eq 50 ] || fail "inventory has $files files"
[ "$sonames" -eq 49 ] || fail "inventory has $sonames SONAMEs"
dup=$(awk -F '\t' 'NR > 1 { print $3 }' "$tsv" | sort | uniq -d)
[ "$dup" = "libSDL2-2.0.so.0" ] || fail "unexpected duplicate SONAME $dup"
for cls in A B C; do
	awk -F '\t' -v c="$cls" 'NR > 1 && $4 == c { found = 1 } END { exit !found }' "$tsv" ||
		fail "class $cls is empty"
done
# Every SONAME is in exactly one coverage class, aside from the SDL pair.
awk -F '\t' 'NR > 1 {
	if ($3 in cls && cls[$3] != $4) bad = 1
	cls[$3] = $4
} END { exit bad }' "$tsv" || fail "one SONAME is in two classes"

allow_n=$(grep -c '^[0-9a-f]' "$allow" || true)
c_n=$(awk -F '\t' 'NR > 1 && $4 == "C" { n++ } END { print n + 0 }' "$tsv")
[ "$allow_n" -eq "$c_n" ] || fail "allowlist $allow_n does not match class C $c_n"
if grep -E 'libSDL2-2\.0\.so\.0|libxml2\.so\.2|libtheoradec\.so\.1' "$allow"; then
	fail "allowlist replaces a library Zlyme already builds"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/src"
: > "$work/src/kept"
python3 - "$work" << 'PY'
import hashlib, tarfile, sys
from pathlib import Path
work = Path(sys.argv[1])
allow = (work / "src" / "kept")
# Build a tiny archive with one good member and one unsafe member.
good = b"good-bytes"
digest = hashlib.sha256(good).hexdigest()
(work / "allow").write_text(f"{digest}  good.so\n")
tar_path = work / "ok.tar.gz"
with tarfile.open(tar_path, "w:gz") as tf:
    data = good
    import io
    info = tarfile.TarInfo("compat/good.so")
    info.size = len(data)
    tf.addfile(info, io.BytesIO(data))
bad = work / "bad.tar.gz"
with tarfile.open(bad, "w:gz") as tf:
    info = tarfile.TarInfo("../evil.so")
    info.size = 1
    tf.addfile(info, io.BytesIO(b"x"))
print("made")
PY
python3 "$pkg/extract-allowlist.py" "$work/allow" "$work/ok.tar.gz" "$work/out"
test "$(cat "$work/out/good.so")" = good-bytes
if python3 "$pkg/extract-allowlist.py" "$work/allow" "$work/bad.tar.gz" "$work/badout" 2>"$work/err"; then
	fail "extractor accepted a parent path"
fi
grep -q 'unsafe path' "$work/err"
rm -rf "$work"
trap - EXIT

target=${1:-$ROOT/output/target}
if [ "$built" -ne 1 ]; then
	echo "portmaster-rocknix-compat: source check ok"
	exit 0
fi
re=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-readelf
[ -x "$re" ] || fail "readelf is missing"
compat=$target/usr/lib/compat
[ -d "$compat" ] || fail "compat directory is missing"
while read -r digest name; do
	[ -n "$digest" ] || continue
	case "$digest" in \#*) continue ;; esac
	file=$compat/$name
	[ -f "$file" ] || fail "missing $name"
	got=$(sha256sum "$file" | awk '{ print $1 }')
	[ "$got" = "$digest" ] || fail "hash changed for $name"
	"$re" -h "$file" | grep -q 'AArch64' || fail "$name is not AArch64"
	if "$re" -d "$file" | grep -E -q 'RPATH|RUNPATH'; then
		fail "$name has an RPATH"
	fi
done < "$allow"
if [ -e "$compat/libSDL2-2.0.so.0" ] || [ -e "$compat/libSDL2-2.0.so.0.gles" ]; then
	fail "compat directory contains SDL2"
fi
[ -f "$target/usr/lib/libxml2.so.16" ] || fail "system libxml2.so.16 is missing"
[ -f "$compat/libxml2.so.2" ] || fail "source-built libxml2.so.2 is missing"
[ -f "$compat/libtheoradec.so.1" ] || fail "source-built libtheoradec.so.1 is missing"
[ -f "$target/usr/lib/libSDL2_net-2.0.so.0" ] || fail "SDL2_net is missing"
[ -f "$target/usr/lib/libmodplug.so.1" ] || fail "libmodplug is missing"
[ -f "$target/usr/lib/libgomp.so.1" ] || fail "libgomp.so.1 is missing"
for son in libX11.so.6 libXext.so.6 libXfixes.so.3 libspeex.so.1 \
	libpango-1.0.so.0 libpangocairo-1.0.so.0 libpangoft2-1.0.so.0 \
	libgcrypt.so.20 libvdpau.so.1; do
	[ -e "$target/usr/lib/$son" ] || fail "closure library $son is missing"
done
# Every class C SONAME is loadable from compat or, for its NEEDED, from
# compat, the system library directories, or the basic C library.
python3 - "$tsv" "$target" "$re" << 'PY'
import collections, os, subprocess, sys
tsv, target, readelf = sys.argv[1:]
basic = {
    "libc.so.6", "libm.so.6", "libdl.so.2", "libpthread.so.0", "librt.so.1",
    "libgcc_s.so.1", "libstdc++.so.6", "ld-linux-aarch64.so.1", "libresolv.so.2",
}
present = set(basic)
for base in ("lib", "usr/lib", "usr/lib/compat"):
    directory = os.path.join(target, base)
    if not os.path.isdir(directory):
        continue
    for name in os.listdir(directory):
        present.add(name)
missing = []
with open(tsv) as handle:
    next(handle)
    for line in handle:
        file_name, _digest, soname, klass, needed = line.rstrip("\n").split("\t")
        if klass != "C":
            continue
        if soname not in present:
            missing.append(soname)
        for dep in filter(None, needed.split(",")):
            if dep not in present:
                missing.append(f"{file_name} -> {dep}")
if missing:
    raise SystemExit("unresolved: " + ", ".join(missing[:20]))
PY
echo "portmaster-rocknix-compat: built closure ok"
