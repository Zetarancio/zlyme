#!/bin/sh
# Host checks for zlyme-timezone. Uses fixture zone files, not /storage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
TZBIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-timezone"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
zi=$work/zoneinfo
mkdir -p "$zi/Etc" "$zi/Europe"
printf 'TZifUTC' > "$zi/UTC"
printf 'TZifROME' > "$zi/Europe/Rome"
file=$work/localtime

ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" ensure
cmp "$file" "$zi/UTC"

printf 'TZifKEEP' > "$file"
ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" ensure
cmp "$file" "$file"
printf 'TZifKEEP' > "$work/expect-keep"
cmp "$file" "$work/expect-keep"

printf 'bad' > "$file"
ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" ensure
cmp "$file" "$zi/UTC"

: > "$file"
ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" ensure
cmp "$file" "$zi/UTC"

ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" apply Europe/Rome
cmp "$file" "$zi/Europe/Rome"

if ZLYME_ZONEINFO=$zi ZLYME_TZ_FILE=$file "$TZBIN" apply '../etc/passwd'; then
	echo "path escape was accepted" >&2
	exit 1
fi
cmp "$file" "$zi/Europe/Rome"

echo "timezone seed ok"
