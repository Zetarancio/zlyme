#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc=${CC:-gcc}
out=$(mktemp)
trap 'rm -f "$out"' EXIT
"$cc" -Wall -Wextra -o "$out" "$dir/order_test.c" "$dir/order.c"
"$out"
