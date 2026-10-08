#!/bin/sh
# Apply the one-entry right-slot boot order to a 2 MiB preloader image.
# usage: apply-boot-order.sh IN.img OUT.img
# Does not erase or program NAND.
# Exit 2: the image is already a right-slot recovery preloader.
#
# The RKNS layout and the reseal steps follow apommel's patch-preloader.sh
# (MIT, apommel/baseos-my355 e09d37bb). The boot-order edit is Zlyme's.
set -e

IN="$1"
OUT="$2"
AWK="${AWK_SCRIPT:-$(dirname "$0")/bootorder.awk}"
SIZE=2097152
FIRST=131072
COPIES="$FIRST 524288"
DTB_OFF=239040
BOOT_CALL=10196
BANNER="U-Boot SPL 2017.09 (Nov 02 2024 - 15:59:04)"

die() { echo "refused: $*" >&2; exit 1; }

u16le() {
    h=$(xxd -s "$2" -l 2 -p "$1")
    case "$h" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *) die "short IDB field" ;;
    esac
    echo $(( 0x$(echo "$h" | cut -c3-4)$(echo "$h" | cut -c1-2) ))
}

# Same copy bounds as check-image.sh. This transformer checks them itself.
entry_in_copy() {
    base=$1
    off=$2
    cnt=$3
    limit=$4
    [ "$off" -ge 1 ] || die "IDB entry overlaps its header"
    [ "$off" -lt 4096 ] || die "IDB entry is outside the image"
    [ "$cnt" -ge 1 ] || die "empty IDB entry"
    [ "$cnt" -le 4096 ] || die "IDB entry is outside the image"
    start=$(( base + off * 512 ))
    end=$(( start + cnt * 512 ))
    [ "$end" -gt "$start" ] || die "IDB entry length overflow"
    [ "$start" -ge "$base" ] || die "IDB entry is outside its copy"
    [ "$end" -le "$limit" ] || die "IDB entry is outside its copy"
    [ "$end" -le "$SIZE" ] || die "IDB entry is outside the image"
}
sha_range() {
    dd if="$1" bs=512 skip=$(( $2 / 512 )) count=$(( $3 / 512 )) 2>/dev/null | sha256sum | cut -c1-64
}
stored_hash() {
    xxd -s $(( $2 + 0x18 )) -l 32 -p "$1" | tr -d '\n'
}

[ -f "$IN" ] || die "no such file: $IN"
[ "$(wc -c < "$IN")" -eq "$SIZE" ] || die "input is not $SIZE bytes"

for base in $COPIES; do
    [ "$(xxd -s "$base" -l 4 -p "$IN")" = "524b4e53" ] || die "no RKNS magic at $base"
    if [ "$base" -eq "$FIRST" ]; then
        limit=524288
    else
        limit=$SIZE
    fi
    for i in 0 1; do
        e=$(( base + 0x78 + i * 0x58 ))
        off=$(u16le "$IN" "$e")
        cnt=$(u16le "$IN" $(( e + 2 )))
        entry_in_copy "$base" "$off" "$cnt" "$limit"
        want=$(stored_hash "$IN" "$e")
        got=$(sha_range "$IN" $(( base + off * 512 )) $(( cnt * 512 )))
        [ "$want" = "$got" ] || die "IDB entry $i at $base fails its own SHA-256"
        case "$base:$i" in
            "$FIRST:0") d0_off=$off; d0_cnt=$cnt ;;
            "$FIRST:1") s0_off=$off; s0_cnt=$cnt ;;
            "524288:0") d1_off=$off; d1_cnt=$cnt ;;
            "524288:1") s1_off=$off; s1_cnt=$cnt ;;
        esac
    done
done
if [ "$d0_off" != "$d1_off" ] || [ "$d0_cnt" != "$d1_cnt" ] \
    || [ "$s0_off" != "$s1_off" ] || [ "$s0_cnt" != "$s1_cnt" ]; then
    die "IDB copies disagree on entry geometry"
fi
d_end=$(( d0_off + d0_cnt ))
s_end=$(( s0_off + s0_cnt ))
if [ "$d0_off" -lt "$s_end" ] && [ "$s0_off" -lt "$d_end" ]; then
    die "DDR and SPL entries overlap"
fi
DDR_OFF=$d0_off
DDR_CNT=$d0_cnt
SPL_OFF=$s0_off
SPL_CNT=$s0_cnt

SPL=$(( FIRST + SPL_OFF * 512 ))
SPL_LEN=$(( SPL_CNT * 512 ))
OTHER=$(( 524288 + SPL_OFF * 512 ))
A=$(sha_range "$IN" "$SPL" "$SPL_LEN")
B=$(sha_range "$IN" "$OTHER" "$SPL_LEN")
[ "$A" = "$B" ] || die "SPL copies disagree"
A=$(sha_range "$IN" $(( FIRST + DDR_OFF * 512 )) $(( DDR_CNT * 512 )))
B=$(sha_range "$IN" $(( 524288 + DDR_OFF * 512 )) $(( DDR_CNT * 512 )))
[ "$A" = "$B" ] || die "DDR copies disagree"

[ "$(xxd -s $(( SPL + 16 )) -l 4 -p "$IN")" = "c0a50300" ] || die "SPL device tree offset is not the Nov 02 build"
[ "$(xxd -s $(( SPL + BOOT_CALL )) -l 4 -p "$IN")" = "50f8ff97" ] || die "SPL boot-order call is not the Nov 02 instruction"
dd if="$IN" bs=1 skip="$SPL" count="$DTB_OFF" 2>/dev/null | grep -a -F -q "$BANNER" || die "SPL banner is not the Nov 02 2024 Miyoo build"
[ "$(xxd -s $(( SPL + DTB_OFF )) -l 4 -p "$IN")" = "d00dfeed" ] || die "SPL device tree magic is missing"

TOTAL=$(( 0x$(xxd -s $(( SPL + DTB_OFF + 4 )) -l 4 -p "$IN") ))
if [ "$TOTAL" -le 0 ] || [ $(( SPL + DTB_OFF + TOTAL )) -gt $(( SPL + SPL_LEN )) ]; then
    die "device tree overruns its payload"
fi
TAIL=$(dd if="$IN" bs=1 skip=$(( SPL + DTB_OFF + TOTAL )) count=$(( SPL + SPL_LEN - SPL - DTB_OFF - TOTAL )) 2>/dev/null | tr -d '\000' | wc -c)
[ "$TAIL" -eq 0 ] || die "bytes after the SPL device tree are not zero"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
dd if="$IN" bs=1 skip=$(( SPL + DTB_OFF )) count="$TOTAL" of="$T/old.dtb" 2>/dev/null
set +e
xxd -p "$T/old.dtb" | tr -d '\n' | awk -f "$AWK" > "$T/new.hex"
aw=$?
set -e
if [ "$aw" -eq 2 ]; then
    echo "image is already a right-slot recovery preloader" >&2
    exit 2
fi
[ "$aw" -eq 0 ] || die "boot-order edit failed"
xxd -r -p "$T/new.hex" > "$T/new.dtb"
NEW=$(wc -c < "$T/new.dtb")
[ "$NEW" -lt "$TOTAL" ] || die "recovery device tree did not shrink"
[ "$(xxd -s 0 -l 4 -p "$T/new.dtb")" = "d00dfeed" ] || die "edited device tree lost its magic"

cp "$IN" "$OUT"
for base in $COPIES; do
    at=$(( SPL + DTB_OFF + base - FIRST ))
    dd if="$T/new.dtb" of="$OUT" bs=1 seek="$at" conv=notrunc 2>/dev/null
    dd if=/dev/zero of="$OUT" bs=1 seek=$(( at + NEW )) count=$(( TOTAL - NEW )) conv=notrunc 2>/dev/null
done

H=$(sha_range "$OUT" "$SPL" "$SPL_LEN")
echo "$H" | xxd -r -p > "$T/h.bin"
for base in $COPIES; do
    dd if="$T/h.bin" of="$OUT" bs=1 seek=$(( base + 0x78 + 0x58 + 0x18 )) conv=notrunc 2>/dev/null
done

[ "$(wc -c < "$OUT")" -eq "$SIZE" ] || die "output changed size"
for base in $COPIES; do
    for i in 0 1; do
        e=$(( base + 0x78 + i * 0x58 ))
        off=$(u16le "$OUT" $e)
        cnt=$(u16le "$OUT" $(( e + 2 )))
        want=$(stored_hash "$OUT" $e)
        got=$(sha_range "$OUT" $(( base + off * 512 )) $(( cnt * 512 )))
        [ "$want" = "$got" ] || die "output IDB entry $i at $base fails its SHA-256"
    done
done
A=$(dd if="$IN" bs=512 skip=$(( FIRST / 512 + DDR_OFF )) count="$DDR_CNT" 2>/dev/null | sha256sum)
B=$(dd if="$OUT" bs=512 skip=$(( FIRST / 512 + DDR_OFF )) count="$DDR_CNT" 2>/dev/null | sha256sum)
[ "$A" = "$B" ] || die "the DDR blob changed"
A=$(dd if="$IN" bs=1 skip="$SPL" count="$DTB_OFF" 2>/dev/null | sha256sum)
B=$(dd if="$OUT" bs=1 skip="$SPL" count="$DTB_OFF" 2>/dev/null | sha256sum)
[ "$A" = "$B" ] || die "the SPL code changed"
[ "$(xxd -s $(( SPL + BOOT_CALL )) -l 4 -p "$OUT")" = "50f8ff97" ] || die "the boot-order call changed"

echo "boot order is /dwmmc@fe2b0000 only, both IDB copies resealed"
echo "ok: $OUT"
