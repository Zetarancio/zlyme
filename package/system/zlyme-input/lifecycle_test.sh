#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc=${CC:-gcc}
out=$(mktemp)
trap 'rm -f "$out"' EXIT
"$cc" -Wall -Wextra -Werror -o "$out" "$dir/lifecycle_test.c" "$dir/lifecycle.c"
"$out"
