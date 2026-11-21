#!/bin/sh
# Record ccache counters for one product stage.
#   begin DIR OUT   print the restored counters, then zero them
#   end   DIR OUT   print the counters accumulated since the zero
# --zero-stats clears counters only. It does not delete cached objects.
set -eu

mode=${1:?begin or end}
dir=${2:?cache directory required}
out=${3:?output file required}
root=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
export CCACHE_DIR="$dir"
mkdir -p "$(dirname "$out")"

ccache -s > "$out.raw"
max=$(ccache -k max_size | tr -d '[:space:]' | sed -E 's/^([0-9]+)\.0([A-Za-z]+)$/\1\2/')
python3 "$root/scripts/ci/ccache_stats.py" "$mode" "$max" "$out.raw" | tee "$out"
if [ "$mode" = begin ]; then
	ccache -z
fi
