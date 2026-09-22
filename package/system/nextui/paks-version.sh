#!/bin/sh
# Hash the stock Emus and Tools pak set.
# The result is relative paths plus file bytes. It does not include
# timestamps or the checkout's absolute path.
# Tools/Update.pak is not part of the set the image installs.
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: paks-version.sh paks-dir output-file" >&2
	exit 2
fi

root=$1
out=$2

if [ ! -d "$root/Emus" ] || [ ! -d "$root/Tools" ]; then
	echo "paks-version: missing Emus or Tools under $root" >&2
	exit 1
fi

list=$(mktemp)
manifest=$(mktemp)
trap 'rm -f "$list" "$manifest"' EXIT

(
	cd "$root"
	find Emus Tools \
		\( -path Tools/Update.pak -o -path 'Tools/Update.pak/*' \) -prune \
		-o -print
) | LC_ALL=C sort > "$list"

while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	path=$root/$rel
	if [ -L "$path" ]; then
		printf 'link %s %s\n' "$rel" "$(readlink "$path")"
	elif [ -f "$path" ]; then
		sum=$(sha256sum "$path" | awk '{print $1}')
		printf 'file %s %s\n' "$rel" "$sum"
	elif [ -d "$path" ]; then
		printf 'dir %s\n' "$rel"
	else
		printf 'other %s\n' "$rel"
	fi
done < "$list" > "$manifest"

sum=$(sha256sum "$manifest" | awk '{print $1}')
printf '%s\n' "$sum" > "$out"
