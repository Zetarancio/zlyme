#!/bin/sh
# A failed cheat-archive download must not replace a good database.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
patch=$ROOT/package/system/cheat-downloader/0002-tls-and-atomic-download.patch
grep -q 'commitPartial' "$patch"
if grep -E -q '^\+.*"-k' \
	"$patch" "$ROOT/package/system/cheat-downloader/0001-follow-union-symlinks.patch"
then
	echo "a cheat patch still disables TLS" >&2
	exit 1
fi
bin=${CHEAT_MANAGER:-/tmp/cheat_manager_host}
if [ ! -x "$bin" ]; then
	echo "cheat download test needs a host cheat_manager at $bin" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/roms" "$work/cache" "$work/cheats"
final=$work/cheats/cheats.zip
partial=$final.partial
printf 'OLDDATA' > "$final"

cat > "$work/bin/curl" << 'EOF'
#!/bin/sh
mode=${CHEAT_CURL_MODE:-fail}
case "$mode" in
	fail) exit 1 ;;
	html) printf '<html>error' ; exit 0 ;;
	zip) printf 'PK\003\004NEWDATA' ; exit 0 ;;
	*) exit 1 ;;
esac
EOF
chmod 0755 "$work/bin/curl"

run() {
	PATH="$work/bin:$PATH" \
	ROM_DIR=$work/roms CACHE_DIR=$work/cache CHEAT_DIR=$work/cheats \
	SDCARD_PATH=$work \
	ZLYME_COMMIT_TMP=$partial ZLYME_COMMIT_OUT=$final \
	ZLYME_FETCH_URL=https://example.invalid/libretro-database.zip \
	"$bin" "$@"
}

CHEAT_CURL_MODE=fail
if run fetch-partial; then
	echo "failed curl was treated as success" >&2
	exit 1
fi
test "$(cat "$final")" = OLDDATA
test ! -e "$partial"

CHEAT_CURL_MODE=html
if run fetch-partial; then
	echo "html body replaced the archive" >&2
	exit 1
fi
test "$(cat "$final")" = OLDDATA
test ! -e "$partial"

printf 'NOTAZIP' > "$partial"
if run commit-partial; then
	echo "non-zip partial replaced the archive" >&2
	exit 1
fi
test "$(cat "$final")" = OLDDATA
test ! -e "$partial"

printf 'PK\003\004NEWDATA' > "$partial"
run commit-partial
test "$(cat "$final")" = "$(printf 'PK\003\004NEWDATA')"
test ! -e "$partial"

echo "cheat download ok"
