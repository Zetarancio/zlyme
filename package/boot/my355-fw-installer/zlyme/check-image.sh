#!/bin/sh
# Structural check for a 2 MiB my355 preloader. Does not modify the file.
# usage: check-image.sh IN.img
#        check-image.sh --ddr-cmp LEFT.img RIGHT.img
# Zlyme. The RKNS offsets match apommel's patch-preloader.sh.
set -e

die() { echo "refused: $*" >&2; exit 1; }

u16le() {
    h=$(xxd -s "$2" -l 2 -p "$1")
    case "$h" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *) die "short IDB field" ;;
    esac
    echo $(( 0x$(echo "$h" | cut -c3-4)$(echo "$h" | cut -c1-2) ))
}

# Sector offset and count are relative to this RKNS copy. The known my355
# layout puts the copies at 0x20000 and 0x80000, so a payload stays inside
# its own copy: up to the next copy, or the end of the 2 MiB image.
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
    [ "$end" -le 2097152 ] || die "IDB entry is outside the image"
}
sha_range() {
    dd if="$1" bs=512 skip=$(( $2 / 512 )) count=$(( $3 / 512 )) 2>/dev/null | sha256sum | cut -c1-64
}
stored_hash() {
    xxd -s $(( $2 + 0x18 )) -l 32 -p "$1" | tr -d '\n'
}

ddr_of() {
    file=$1
    out=$2
    base=131072
    e=$(( base + 0x78 ))
    off=$(u16le "$file" "$e")
    cnt=$(u16le "$file" $(( e + 2 )))
    [ "$cnt" -gt 0 ] || die "empty DDR entry"
    dd if="$file" bs=512 skip=$(( base / 512 + off )) count="$cnt" of="$out" 2>/dev/null
}

check_one() {
    file=$1
    size=2097152
    [ -f "$file" ] || die "no such file: $file"
    [ "$(wc -c < "$file" | tr -d ' ')" -eq "$size" ] || die "input is not $size bytes"
    first=131072
    for base in $first 524288; do
        [ "$(xxd -s "$base" -l 4 -p "$file")" = "524b4e53" ] || die "no RKNS magic at $base"
        if [ "$base" -eq "$first" ]; then
            limit=524288
        else
            limit=$size
        fi
        for i in 0 1; do
            e=$(( base + 0x78 + i * 0x58 ))
            off=$(u16le "$file" "$e")
            cnt=$(u16le "$file" $(( e + 2 )))
            entry_in_copy "$base" "$off" "$cnt" "$limit"
            want=$(stored_hash "$file" "$e")
            got=$(sha_range "$file" $(( base + off * 512 )) $(( cnt * 512 )))
            [ "$want" = "$got" ] || die "IDB entry $i at $base fails its own SHA-256"
            case "$base:$i" in
                "$first:0") d0_off=$off; d0_cnt=$cnt ;;
                "$first:1") s0_off=$off; s0_cnt=$cnt ;;
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
    spl=$(( first + SPL_OFF * 512 ))
    spl_len=$(( SPL_CNT * 512 ))
    a=$(sha_range "$file" "$spl" "$spl_len")
    b=$(sha_range "$file" $(( 524288 + SPL_OFF * 512 )) "$spl_len")
    [ "$a" = "$b" ] || die "SPL copies disagree"
    a=$(sha_range "$file" $(( first + DDR_OFF * 512 )) $(( DDR_CNT * 512 )))
    b=$(sha_range "$file" $(( 524288 + DDR_OFF * 512 )) $(( DDR_CNT * 512 )))
    [ "$a" = "$b" ] || die "DDR copies disagree"
}

if [ "${1:-}" = "--ddr-cmp" ]; then
    [ "$#" -eq 3 ] || die "usage: check-image.sh --ddr-cmp LEFT RIGHT"
    t=$(mktemp -d)
    trap 'rm -rf "$t"' EXIT
    check_one "$2"
    check_one "$3"
    ddr_of "$2" "$t/a"
    ddr_of "$3" "$t/b"
    cmp -s "$t/a" "$t/b" || die "DDR payload differs"
    exit 0
fi

[ "$#" -eq 1 ] || die "usage: check-image.sh IN.img"
check_one "$1"
