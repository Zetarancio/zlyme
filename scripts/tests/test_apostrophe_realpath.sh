#!/bin/sh
# POSIX file-picker resolution must not hand a short buffer to realpath().
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
header=$ROOT/package/system/nextui/apostrophe/include/apostrophe_widgets.h

if grep -q 'realpath(path, resolved)' "$header"; then
	echo "file picker still passes a caller buffer to realpath" >&2
	exit 1
fi
grep -q 'realpath(path, NULL)' "$header"
grep -q 'free(resolved)' "$header"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gcc -std=gnu11 -O2 -D_FORTIFY_SOURCE=2 -Wall -Wextra -o "$work/resolve" -x c - << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/* Same contract as ap__file_picker_resolve_existing_path on POSIX. */
static int copy_path(char *dst, size_t dst_size, const char *src) {
    size_t n = strlen(src);
    if (n >= dst_size) {
        dst[0] = '\0';
        return -1;
    }
    memcpy(dst, src, n + 1);
    return 0;
}

static int resolve(const char *path, char *out, size_t out_size) {
    char *resolved = realpath(path, NULL);
    int rc;
    if (!out || out_size == 0)
        return -1;
    out[0] = '\0';
    if (!resolved)
        return -1;
    rc = copy_path(out, out_size, resolved);
    free(resolved);
    return rc;
}

int main(int argc, char **argv) {
    char out[64];
    char tiny[4];
    char long_out[8];
    char deep[512];
    size_t i;

    if (argc < 2)
        return 9;
    if (resolve("/tmp", out, sizeof out) != 0)
        return 1;
    if (out[0] != '/')
        return 2;
    if (resolve("/tmp", tiny, sizeof tiny) == 0)
        return 3;

    snprintf(deep, sizeof deep, "%s/root", argv[1]);
    if (mkdir(deep, 0700) != 0)
        return 5;
    for (i = 0; i < 8; i++) {
        size_t n = strlen(deep);
        snprintf(deep + n, sizeof deep - n, "/segment%02zu", i);
        if (mkdir(deep, 0700) != 0)
            return 6;
    }
    if (resolve(deep, long_out, sizeof long_out) == 0)
        return 7;
    if (resolve(deep, out, sizeof out) == 0)
        return 8;
    return 0;
}
EOF
"$work/resolve" "$work"
echo "apostrophe realpath ok"
