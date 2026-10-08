# Shrink /chosen's u-boot,spl-boot-order to /dwmmc@fe2b0000.
# stdin: one lowercase hex string of the SPL device tree.
# stdout: the edited tree, same form.
# exit 2: the property is already that one entry.
# Zlyme addition. The tree walk follows apommel's fdtpatch.awk style.
BEGIN {
    HEX = "0123456789abcdef"
    EXPECT = "2f64776d6d63406665326230303030002f7364686369406665333130303030002f6e616e6463406665333330303030002f7366634066653330303030302f666c6173684030002f7366634066653330303030302f666c617368403100"
    ONLY = "2f64776d6d6340666532623030303000"
}
function h2d(s,   i, c, n, v) {
    n = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        v = index(HEX, c) - 1
        if (v < 0) {
            print "bad hex digit " c > "/dev/stderr"
            exit 1
        }
        n = n * 16 + v
    }
    return n
}
function u32(b) { return h2d(substr(H, 2 * b + 1, 8)) }
function d2h(n) { return sprintf("%08x", n) }
function align4(n) { return int((n + 3) / 4) * 4 }
function hexat(b, n) { return substr(H, 2 * b + 1, 2 * n) }
function poke(hex, b, val) {
    return substr(hex, 1, 2 * b) d2h(val) substr(hex, 2 * b + 9)
}
{
    H = $0
    if (substr(H, 1, 8) != "d00dfeed") {
        print "not a device tree" > "/dev/stderr"
        exit 1
    }
    totalsize = u32(4)
    off_struct = u32(8)
    off_strings = u32(12)
    size_strings = u32(32)
    size_struct = u32(36)
    if (off_strings + size_strings != totalsize) {
        print "strings block is not last" > "/dev/stderr"
        exit 1
    }
    struct_end = off_struct + size_struct
    if (off_strings != struct_end) {
        print "struct and strings are not adjacent" > "/dev/stderr"
        exit 1
    }

    p = off_struct
    depth = 0
    at = -1
    while (p < struct_end) {
        tok = hexat(p, 4)
        if (tok == "00000001") {
            name = ""
            i = p + 4
            while (1) {
                h = hexat(i, 1)
                if (h == "00" || h == "") break
                name = name sprintf("%c", h2d(h))
                i++
            }
            depth++
            node[depth] = name
            p = align4(i + 1)
        } else if (tok == "00000002") {
            if (depth < 1) {
                print "FDT node nesting is invalid" > "/dev/stderr"
                exit 1
            }
            depth--
            p += 4
        } else if (tok == "00000003") {
            len = u32(p + 4)
            nameoff = u32(p + 8)
            pname = ""
            i = off_strings + nameoff
            while (1) {
                h = hexat(i, 1)
                if (h == "00" || h == "") break
                pname = pname sprintf("%c", h2d(h))
                i++
            }
            path = ""
            for (d = 1; d <= depth; d++) if (node[d] != "") path = path "/" node[d]
            if (path == "/chosen" && pname == "u-boot,spl-boot-order") {
                if (at != -1) {
                    print "SPL boot-order property is ambiguous" > "/dev/stderr"
                    exit 1
                }
                at = p
                oldlen = len
            }
            p = align4(p + 12 + len)
        } else if (tok == "00000004") {
            p += 4
        } else if (tok == "00000009") {
            break
        } else {
            print "bad FDT token " tok > "/dev/stderr"
            exit 1
        }
    }
    if (at < 0) {
        print "SPL boot-order property is missing" > "/dev/stderr"
        exit 1
    }
    data = hexat(at + 12, oldlen)
    if (data == ONLY) exit 2
    if (data != EXPECT) {
        print "SPL boot order is not the Nov 02 list" > "/dev/stderr"
        exit 1
    }
    old_end = align4(at + 12 + oldlen)
    new_end = align4(at + 28)
    delta = new_end - old_end
    if (delta >= 0) {
        print "recovery device tree did not shrink" > "/dev/stderr"
        exit 1
    }
    prop = "00000003" d2h(16) hexat(at + 8, 4) ONLY
    OUT = hexat(0, at) prop hexat(old_end, struct_end - old_end) hexat(off_strings, size_strings)
    OUT = poke(OUT, 4, totalsize + delta)
    OUT = poke(OUT, 12, off_strings + delta)
    OUT = poke(OUT, 36, size_struct + delta)
    if (length(OUT) != 2 * (totalsize + delta)) {
        print "rebuilt device tree size is inconsistent" > "/dev/stderr"
        exit 1
    }
    print OUT
}
