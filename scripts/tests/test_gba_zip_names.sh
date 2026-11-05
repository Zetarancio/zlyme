#!/bin/sh
# Synthetic GBA names through the pinned RetroArch ZIP reader.
# The fixtures are not ROMs. A missing RetroArch tree blocks the ZIP cases.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
RA=$ROOT/output/build/retroarch-v1.22.2
SRC=$RA/libretro-common/file/archive_file_zlib.c
fail() { echo "gba-zip: $*" >&2; exit 1; }
blocked() { echo "gba-zip blocked: $*" >&2; exit 2; }

[ -f "$SRC" ] || blocked "pinned RetroArch tree is not at $RA"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$work" << 'PY'
import struct, sys, zlib
from pathlib import Path

work = Path(sys.argv[1])
text = "洛克人"
utf8 = text.encode("utf-8")
gbk = text.encode("gbk")
payload = b"ZLYMEGBA\n"

def store_zip(path, name: bytes, flags: int):
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    size = len(payload)
    n = len(name)
    local = struct.pack(
        "<IHHHHHIIIHH",
        0x04034B50, 20, flags, 0, 0, 0, crc, size, size, n, 0,
    ) + name + payload
    central = struct.pack(
        "<IHHHHHHIIIHHHHHII",
        0x02014B50, 20, 20, flags, 0, 0, 0, crc, size, size,
        n, 0, 0, 0, 0, 0, len(local),
    ) + name
    eocd = struct.pack(
        "<IHHHHIIH",
        0x06054B50, 0, 0, 1, 1, len(central), len(local), 0,
    )
    path.write_bytes(local + central + eocd)

def central(path: Path):
    data = path.read_bytes()
    eocd = data.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise SystemExit("no central directory")
    offset = struct.unpack_from("<I", data, eocd + 16)[0]
    flags = struct.unpack_from("<H", data, offset + 8)[0]
    namelen = struct.unpack_from("<H", data, offset + 28)[0]
    name = data[offset + 46:offset + 46 + namelen]
    return flags, name

store_zip(work / "utf8.zip", utf8 + b".gba", 0x0800)
store_zip(work / "gbk.zip", gbk + b".gba", 0)
store_zip(work / "ascii.zip", b"game.gba", 0)
(work / "expect-utf8").write_bytes(utf8 + b".gba")
(work / "expect-gbk").write_bytes(gbk + b".gba")
(work / "expect-ascii").write_bytes(b"game.gba")
for label, name in (("utf8", "utf8.zip"), ("gbk", "gbk.zip"), ("ascii", "ascii.zip")):
    flags, got = central(work / name)
    print(f"meta {label} flags={flags:04x} name={got.hex()}")
PY

cc -std=c11 -Wall -Wextra -D_GNU_SOURCE \
	-I"$RA" -I"$RA/libretro-common/include" \
	-c -o "$work/archive_file_zlib.o" "$SRC" || fail "could not compile the pinned ZIP reader"
cc -std=c11 -Wall -Wextra -Werror -D_GNU_SOURCE \
	-I"$RA" -I"$RA/libretro-common/include" \
	-o "$work/gba-zip-parse" \
	"$ROOT/scripts/tests/gba_zip_parse.c" \
	"$work/archive_file_zlib.o" -lz || fail "could not link the pinned ZIP reader"

parse() {
	"$work/gba-zip-parse" "$1"
}

# Case A. The launcher assigns the argument and quotes it. No recoding.
case_a=$work/CN048\ 洛克人EXE\ 2.gba
printf 'ZLYMEGBA\n' > "$case_a"
got_a=$(sh -c 'ROM="$1"; printf %s "$ROM"' sh "$case_a" | od -An -tx1 | tr -d ' \n')
want_a=$(printf '%s' "$case_a" | od -An -tx1 | tr -d ' \n')
name_a=$(printf '%s' '洛克人' | od -An -tx1 | tr -d ' \n')
[ "$got_a" = "$want_a" ] || fail "case A pathname bytes changed"
case "$got_a" in
	*"$name_a"*) ;;
	*) fail "case A lost the UTF-8 name" ;;
esac
[ -f "$case_a" ] || fail "case A removed the file"

# Case B. UTF-8 flag and UTF-8 member bytes.
meta_b=$(python3 -c '
import struct, pathlib
p=pathlib.Path("'"$work"'/utf8.zip").read_bytes()
e=p.rfind(b"PK\x05\x06")
o=struct.unpack_from("<I", p, e+16)[0]
f=struct.unpack_from("<H", p, o+8)[0]
n=struct.unpack_from("<H", p, o+28)[0]
print(f"{f:04x} {p[o+46:o+46+n].hex()}")
')
[ "$meta_b" = "0800 $(od -An -tx1 "$work/expect-utf8" | tr -d ' \n')" ] || fail "case B central directory is $meta_b"
got_b=$(parse "$work/utf8.zip")
want_b=$(od -An -tx1 "$work/expect-utf8" | tr -d ' \n')
[ "$got_b" = "$want_b" ] || fail "case B parser returned $got_b"
[ -f "$work/utf8.zip" ] || fail "case B removed the archive"

# Case C. GBK member, UTF-8 flag unset. The reader keeps the raw bytes.
meta_c=$(python3 -c '
import struct, pathlib
p=pathlib.Path("'"$work"'/gbk.zip").read_bytes()
e=p.rfind(b"PK\x05\x06")
o=struct.unpack_from("<I", p, e+16)[0]
f=struct.unpack_from("<H", p, o+8)[0]
n=struct.unpack_from("<H", p, o+28)[0]
print(f"{f:04x} {p[o+46:o+46+n].hex()}")
')
[ "$meta_c" = "0000 $(od -An -tx1 "$work/expect-gbk" | tr -d ' \n')" ] || fail "case C central directory is $meta_c"
got_c=$(parse "$work/gbk.zip")
want_c=$(od -An -tx1 "$work/expect-gbk" | tr -d ' \n')
[ "$got_c" = "$want_c" ] || fail "case C parser returned $got_c"
case "$got_c" in
	*efbfbd*) fail "case C inserted Unicode replacement bytes" ;;
esac
[ "$got_c" != "$want_b" ] || fail "case C was transcoded to UTF-8"
[ -f "$work/gbk.zip" ] || fail "case C removed the archive"

# Case D. ASCII control.
got_d=$(parse "$work/ascii.zip")
[ "$got_d" = "67616d652e676261" ] || fail "case D parser returned $got_d"
[ -f "$work/ascii.zip" ] || fail "case D removed the archive"

echo "gba zip names ok"
echo "case A $got_a"
echo "case B $got_b"
echo "case C $got_c"
echo "case D $got_d"
