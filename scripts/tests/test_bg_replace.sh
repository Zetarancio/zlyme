#!/bin/sh
# Pixel rule for replacing a blended background. No SDL and no device.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc -std=c11 -Wall -Wextra -Werror -o "$work/bg-replace" \
	"$ROOT/scripts/tests/test_bg_replace.c"
"$work/bg-replace"
