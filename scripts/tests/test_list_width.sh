#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NEXT=${NEXTUI_SRC:-$ROOT/../NextUI}
fail() { echo "list-width: $*" >&2; exit 1; }

[ -f "$NEXT/workspace/all/nextui/list_width.c" ] || fail "missing list_width.c"
[ -f "$NEXT/workspace/all/nextui/test_list_width.c" ] || fail "missing test"
ui=$NEXT/workspace/all/nextui/nextui.c
grep -q 'zlyme_list_row_width' "$ui" || fail "list rows do not share a width"
grep -q 'zlyme_pill_scroll' "$ui" || fail "the scroll path does not use the pill"
if grep -n 'available_width -= ow' "$ui"; then
	fail "a row still subtracts the hardware hint from an already limited width"
fi
grep -q 'zlyme_game_art_percent' "$NEXT/workspace/all/common/config.c" \
	|| fail "Game art width still casts before the multiply"
grep -q 'artWidth=%i' "$NEXT/workspace/all/common/config.c" \
	|| fail "the settings file writer changed"
if grep -n 'trimSortingMeta(&entry->name)' "$ui"; then
	fail "sorting names are rewritten in place"
fi

cc=${CC:-gcc}
"$cc" -Wall -Wextra -Werror -std=gnu99 \
	-I"$NEXT/workspace/all/nextui" \
	-I"$NEXT/workspace/all/common" \
	-o /tmp/zlyme-list-width-test \
	"$NEXT/workspace/all/nextui/list_width.c" \
	"$NEXT/workspace/all/nextui/test_list_width.c"
/tmp/zlyme-list-width-test
rm -f /tmp/zlyme-list-width-test
echo "list-width ok"
