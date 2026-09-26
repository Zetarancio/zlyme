#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc=${CC:-gcc}
out=$(mktemp)
trap 'rm -f "$out"' EXIT
"$cc" -Wall -Wextra -Werror -I"$dir/../src/workspace/my355/platform" -o "$out" "$dir/pad_policy_test.c"
"$out"
