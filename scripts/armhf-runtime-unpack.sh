#!/bin/sh
# Extract one ARMHF runtime tar into the directory check-manifest.sh
# expects. Reject absolute paths and traversal before writing.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
arc=${1:?archive path}
dest=${2:?destination directory}
die() { echo "armhf-unpack: $*" >&2; exit 1; }

[ -f "$arc" ] || die "archive missing"
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

tar -tf "$arc" > "$tmp/members" || die "archive cannot be listed"
tar -tvf "$arc" > "$tmp/verbose" || die "archive cannot be listed"
if grep -E ' -> (/|\.\.)' "$tmp/verbose" > "$tmp/badlinks"; then
	die "refusing symlink $(head -n 1 "$tmp/badlinks")"
fi
while IFS= read -r member; do
	[ -n "$member" ] || continue
	case "$member" in
		/*) die "refusing member $member" ;;
	esac
	rest=${member#./}
	case "$rest" in
		.. | ../* | */.. | */../*) die "refusing member $member" ;;
	esac
done < "$tmp/members"

rm -rf "$dest"
mkdir -p "$dest"
tar -xf "$arc" -C "$dest" || die "extract failed"
"$ROOT/package/system/zlyme-armhf-runtime/check-manifest.sh" "$dest"

loader=$dest/target/lib/ld-linux-armhf.so.3
magic=$(od -An -t x1 -N 4 "$loader" | tr -d ' \n')
if [ "$magic" = "7f454c46" ]; then
	command -v readelf >/dev/null 2>&1 || die "readelf is required for the loader"
	readelf -h "$loader" | grep -q 'ELF32' || die "loader is not ELF32"
	readelf -h "$loader" | grep -q 'hard-float' || die "loader is not hard-float"
fi
echo "armhf unpack ok"
