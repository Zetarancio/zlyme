#!/bin/sh
# Exit 0 when two ccache size strings are the same limit.
# ccache -M 8GiB stores "max_size = 8GiB" and ccache -k max_size prints "8.0 GiB".
set -eu

canon() {
	printf '%s' "$1" | tr -d '[:space:]' | sed -E 's/^([0-9]+)\.0([A-Za-z]+)$/\1\2/'
}

[ "$(canon "$1")" = "$(canon "$2")" ]
