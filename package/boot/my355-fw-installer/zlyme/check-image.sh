#!/bin/sh
# Structural check for a 2 MiB my355 preloader. Does not modify the file.
# usage: check-image.sh IN.img
#        check-image.sh --ddr-cmp LEFT.img RIGHT.img
# Zlyme. The RKNS offsets match apommel's patch-preloader.sh.
set -e

die() { echo "refused: $*" >&2; exit 1; }

u16le() {
    h=$(xxd -s "$2" -l 2 -p "$1")
    echo $(( 0x$(echo "$h" | cut -c3-4)$(echo "$h" | cut -c1-2) ))
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
        for i in 0 1; do
            e=$(( base + 0x78 + i * 0x58 ))
            off=$(u16le "$file" "$e")
            cnt=$(u16le "$file" $(( e + 2 )))
            [ "$cnt" -gt 0 ] || die "empty IDB entry $i at $base"
            want=$(stored_hash "$file" "$e")
            got=$(sha_range "$file" $(( base + off * 512 )) $(( cnt * 512 )))
            [ "$want" = "$got" ] || die "IDB entry $i at $base fails its own SHA-256"
            case "$base:$i" in
                "$first:0") DDR_OFF=$off; DDR_CNT=$cnt ;;
                "$first:1") SPL_OFF=$off; SPL_CNT=$cnt ;;
            esac
        done
    done
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
    ddr_of "$2" "$t/a"
    ddr_of "$3" "$t/b"
    cmp -s "$t/a" "$t/b" || die "DDR payload differs"
    exit 0
fi

[ "$#" -eq 1 ] || die "usage: check-image.sh IN.img"
check_one "$1"
