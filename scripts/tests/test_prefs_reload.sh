#!/bin/sh
# In-memory preferences reload after an external rewrite, and a failed save.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cc -std=c11 -Wall -Wextra -D_GNU_SOURCE \
	-I"$ROOT/../NextUI/workspace/all/common" \
	-I"$ROOT/../NextUI/workspace/my355/platform" \
	-I"$ROOT/package/system/nextui/zlyme" \
	-o /tmp/zlyme-prefs-reload \
	"$ROOT/package/system/nextui/zlyme/zlyme_prefs.c" \
	"$ROOT/scripts/tests/test_prefs_reload.c"
/tmp/zlyme-prefs-reload
rm -f /tmp/zlyme-prefs-reload
