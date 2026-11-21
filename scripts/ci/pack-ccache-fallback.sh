#!/bin/sh
# Pack the optional zlyme-cache release seed.
# The Actions cache is the primary store. This archive is only a fallback
# for a later run that finds no Actions cache. A GitHub release file must
# be under 2 GiB. If this cache cannot fit, print upload=false and do not
# create or replace the archive. The existing remote asset stays where it is.
set -eu

dir=${1:?cache directory required}
archive=${2:?archive path required}
limit=${ZLYME_CCACHE_FALLBACK_LIMIT:-2147483648}

say() {
	printf '%s\n' "$1"
}

if [ ! -d "$dir" ]; then
	say "upload=false"
	echo "no ccache directory; fallback asset left unchanged" >&2
	exit 0
fi

bytes=$(du -sb "$dir" | awk '{print $1}')
if [ "$bytes" -ge "$limit" ]; then
	say "upload=false"
	echo "ccache fallback skipped: directory is ${bytes} bytes and a release file must be under ${limit}" >&2
	exit 0
fi

tmp=$(mktemp)
tarfile=$(mktemp)
trap 'rm -f "$tmp" "$tarfile"' EXIT
tar --exclude='.ccache/tmp' --exclude="$(basename "$dir")/tmp" -C "$(dirname "$dir")" -cf "$tarfile" "$(basename "$dir")"
zstd -f -T0 -3 -o "$tmp" "$tarfile"
rm -f "$tarfile"
packed=$(wc -c < "$tmp" | tr -d ' ')
if [ "$packed" -ge "$limit" ]; then
	say "upload=false"
	echo "ccache fallback skipped: archive is ${packed} bytes" >&2
	exit 0
fi
mv "$tmp" "$archive"
trap - EXIT
say "upload=true"
ls -lh "$archive" >&2
