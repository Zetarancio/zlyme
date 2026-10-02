#!/bin/sh
# Credential helper tests use dummy values only.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
helper=$ROOT/package/system/zcrapegoat/gen-credentials-header.py
mk=$ROOT/package/system/zcrapegoat/zcrapegoat.mk
build=$ROOT/build.sh
workflow=$ROOT/.github/workflows/build-stage.yml
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

unset SCREENSCRAPER_DEV_ID SCREENSCRAPER_DEV_PASSWORD ZLYME_REQUIRE_SCRAPEGOAT_CREDENTIALS
python3 "$helper" "$work/none.h" "$work/missing.local" >"$work/out" 2>"$work/err"
test ! -s "$work/out"
grep -q 'not provided' "$work/none.h"

printf '%s\n' "SCREENSCRAPER_DEV_ID='local-id'" "SCREENSCRAPER_DEV_PASSWORD='local-pw'" \
	> "$work/local"
env -u SCREENSCRAPER_DEV_ID -u SCREENSCRAPER_DEV_PASSWORD \
	python3 "$helper" "$work/local.h" "$work/local" >"$work/out"
test ! -s "$work/out"
grep -q 'local-id' "$work/local.h"
grep -q 'local-pw' "$work/local.h"

SCREENSCRAPER_DEV_ID=env-id SCREENSCRAPER_DEV_PASSWORD=env-pw \
	python3 "$helper" "$work/env.h" "$work/local" >/dev/null
grep -q 'env-id' "$work/env.h"
grep -q 'env-pw' "$work/env.h"
if grep -q 'local-id' "$work/env.h"; then
	echo "environment credentials did not win" >&2
	exit 1
fi

if SCREENSCRAPER_DEV_ID=only-id python3 "$helper" "$work/half.h" "$work/missing.local" \
	>"$work/out" 2>"$work/err"
then
	echo "half a credential pair was accepted" >&2
	exit 1
fi
if grep -q 'only-id' "$work/err" "$work/out"; then
	echo "helper printed a credential" >&2
	exit 1
fi

if ZLYME_REQUIRE_SCRAPEGOAT_CREDENTIALS=1 \
	python3 "$helper" "$work/req.h" "$work/missing.local" >/dev/null 2>&1
then
	echo "official build accepted missing credentials" >&2
	exit 1
fi

grep -q 'CCACHE_DISABLE=1' "$mk"
if grep -q 'DSCREENSCRAPER_DEV_ID' "$mk"; then
	echo "recipe still passes credentials on the compiler command" >&2
	exit 1
fi
grep -q 'ZCRAPEGOAT_CREDENTIALS_HEADER' "$mk"
grep -q 'SCREENSCRAPER_DEV_ID' "$workflow"
grep -q 'SCREENSCRAPER_DEV_PASSWORD' "$workflow"
grep -q 'ZLYME_REQUIRE_SCRAPEGOAT_CREDENTIALS' "$workflow"
grep -q -- '-e SCREENSCRAPER_DEV_ID' "$build"
grep -q -- '-e SCREENSCRAPER_DEV_PASSWORD' "$build"

# A fake ccache must not record the compile when CCACHE_DISABLE=1.
cat > "$work/ccache" << 'EOF'
#!/bin/sh
if [ "${CCACHE_DISABLE:-}" = 1 ]; then
	exec "$@"
fi
echo used > "$FAKE_CCACHE_MARK"
exit 99
EOF
chmod 0755 "$work/ccache"
echo 'int main(void){return 0;}' > "$work/t.c"
FAKE_CCACHE_MARK=$work/mark CCACHE_DISABLE=1 "$work/ccache" gcc -c "$work/t.c" -o "$work/t.o"
test ! -e "$work/mark"

if git -C "$ROOT" ls-files --error-unmatch package/system/zcrapegoat/credentials.local \
	>/dev/null 2>&1
then
	echo "credentials.local is tracked" >&2
	exit 1
fi
echo "zcrapegoat credentials ok"
