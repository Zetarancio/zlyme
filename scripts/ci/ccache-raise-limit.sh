#!/bin/sh
# Raise the max size stored in the cache directory. ccache -M writes
# $CCACHE_DIR/ccache.conf and does not delete cached objects. Do not pass
# --cleanup here: a restored 1.5G configuration must stay on disk while the
# limit changes.
set -eu

dir=${1:?cache directory required}
size=${2:?size required}
mkdir -p "$dir"
export CCACHE_DIR="$dir"

ccache -M "$size"
got=$(ccache -k max_size)
root=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
if ! sh "$root/ccache-limit-matches.sh" "$size" "$got"; then
	echo "ccache max_size is '$got', expected '$size'" >&2
	exit 1
fi
if ! grep -Fx "max_size = $size" "$dir/ccache.conf"; then
	echo "ccache.conf does not record max_size = $size" >&2
	exit 1
fi
echo "ccache max_size=$(printf '%s' "$got" | tr -d '[:space:]') dir=$CCACHE_DIR"
ccache -p || true
