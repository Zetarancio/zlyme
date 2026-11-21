#!/bin/sh
# The product Actions cache keeps restored objects and can grow past 1.5G.
# The release-file fallback does not get to shrink that cache.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
raise=$ROOT/scripts/ci/ccache-raise-limit.sh
stats=$ROOT/scripts/ci/ccache-stage-stats.sh
pack=$ROOT/scripts/ci/pack-ccache-fallback.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
	echo "ccache policy: $*" >&2
	exit 1
}

mkdir -p "$work/bin" "$work/cache/objects"
printf 'kept\n' > "$work/cache/objects/keep"
printf 'max_size = 1.5G\n' > "$work/cache/ccache.conf"
cat > "$work/bin/ccache" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${FAKE_CCACHE_LOG:?}"
case "$1" in
-M)
	printf 'max_size = %s\n' "$2" > "${CCACHE_DIR:?}/ccache.conf"
	;;
-k)
	# Ubuntu ccache 4.9 prints a formatted size, not the conf text.
	if grep -qx 'max_size = 8GiB' "${CCACHE_DIR:?}/ccache.conf"; then
		printf '8.0 GiB\n'
	else
		sed -n 's/^max_size = //p' "${CCACHE_DIR:?}/ccache.conf"
	fi
	;;
-z)
	printf 'zero\n' >> "${CCACHE_DIR:?}/stats-reset"
	;;
-s)
	cat << 'STATS'
Cacheable calls:   3 / 4 (75.00%)
  Hits:            2 / 3 (66.67%)
    Direct:        1 / 2 (50.00%)
    Preprocessed:  1 / 2 (50.00%)
  Misses:          1 / 3 (33.33%)
Uncacheable calls: 1 / 4 (25.00%)
Local storage:
  Cache size (GiB): 0.1 / 1.5 (6.67%)
  Cleanups:        4
STATS
	;;
-p)
	echo "max_size (cache.specific) ccache.conf"
	;;
-c|--cleanup|-C|--clear)
	echo cleaned >&2
	exit 9
	;;
*)
	echo "unexpected ccache $*" >&2
	exit 9
	;;
esac
EOF
chmod 755 "$work/bin/ccache"

export FAKE_CCACHE_LOG="$work/ccache.log"
export PATH="$work/bin:$PATH"

sh "$raise" "$work/cache" 8GiB || fail "could not raise a restored 1.5G cache"
grep -qx 'max_size = 8GiB' "$work/cache/ccache.conf" || fail "limit was not stored in the cache"
grep -qx 'kept' "$work/cache/objects/keep" || fail "raising the limit deleted a cached object"
if grep -Eq '(^| )(-c|--cleanup|-C|--clear)( |$)' "$FAKE_CCACHE_LOG"; then
	fail "raising the limit cleaned the cache"
fi

sh "$stats" begin "$work/cache" "$work/begin.txt" >/dev/null || fail "begin stats failed"
grep -q 'restored_max_size=8GiB' "$work/begin.txt" || fail "begin stats lost the new limit"
grep -q 'restored_direct_hits=1' "$work/begin.txt" || fail "begin stats lost direct hits"
grep -q 'restored_preprocessed_hits=1' "$work/begin.txt" || fail "begin stats lost preprocessed hits"
grep -q 'restored_misses=1' "$work/begin.txt" || fail "begin stats lost misses"
grep -q 'restored_hit_rate=66.67' "$work/begin.txt" || fail "begin hit rate is not the stage delta"
grep -q 'restored_cleanups=4' "$work/begin.txt" || fail "begin stats lost cleanups"
grep -qx 'zero' "$work/cache/stats-reset" || fail "statistics were not reset"
grep -qx 'kept' "$work/cache/objects/keep" || fail "resetting statistics deleted a cached object"

# The same directory, read again, is the next stage's restored cache.
sh "$stats" end "$work/cache" "$work/end.txt" >/dev/null || fail "end stats failed"
grep -q 'stage_max_size=8GiB' "$work/end.txt" || fail "end stats lost the limit"
grep -q 'stage_cacheable=3' "$work/end.txt" || fail "end stats did not report cacheable calls"
grep -qx 'kept' "$work/cache/objects/keep" || fail "reading stats deleted a cached object"

mkdir -p "$work/big"
printf 'old-seed\n' > "$work/old-seed.tar.zst"
printf '0123456789abcdef' > "$work/big/payload"
if ZLYME_CCACHE_FALLBACK_LIMIT=8 sh "$pack" "$work/big" "$work/old-seed.tar.zst" > "$work/pack.out"; then
	:
else
	fail "oversized fallback pack failed"
fi
grep -qx 'upload=false' "$work/pack.out" || fail "oversized cache requested an upload"
grep -qx 'old-seed' "$work/old-seed.tar.zst" || fail "oversized pack replaced the previous fallback"
if [ -e "$work/big.tar.zst" ]; then
	fail "oversized pack created an archive"
fi

mkdir -p "$work/small"
printf 'seed\n' > "$work/small/payload"
sh "$pack" "$work/small" "$work/small.tar.zst" > "$work/small.out" || fail "small fallback pack failed"
grep -qx 'upload=true' "$work/small.out" || fail "small fallback was not uploadable"
[ -s "$work/small.tar.zst" ] || fail "small fallback archive missing"

# Compress, then reject that archive without replacing an older file.
packed=$(wc -c < "$work/small.tar.zst" | tr -d ' ')
printf 'previous\n' > "$work/second.tar.zst"
rm -f "$work/small.tar.zst"
if ZLYME_CCACHE_FALLBACK_LIMIT="$packed" sh "$pack" "$work/small" "$work/second.tar.zst" > "$work/second.out"; then
	:
else
	fail "archive-limit pack failed"
fi
grep -qx 'upload=false' "$work/second.out" || fail "an archive at the release limit was accepted"
grep -qx 'previous' "$work/second.tar.zst" || fail "a too-large archive replaced the previous fallback"

cat > "$work/build.log" << 'EOF'
2026-11-21T00:00:00Z >>> llvm 22 Building
2026-11-21T00:00:01Z   CC foo.c
2026-11-21T00:10:00Z >>> llvm 22 Installing to target
2026-11-21T00:10:01Z >>> small 1 Building
2026-11-21T00:10:02Z >>> small 1 Installing to target
EOF
python3 "$ROOT/scripts/ci/summarize_build_durations.py" "$work/build.log" > "$work/durations.txt"
grep -q '10.0 min  llvm 22' "$work/durations.txt" || fail "long package duration missing"
grep -q '0.0 min  small 1' "$work/durations.txt" || fail "short package duration missing"
cat > "$work/open.log" << 'EOF'
2026-11-21T00:00:00Z >>> gcc-final 15 Building
2026-11-21T00:05:00Z   CC foo.c
EOF
python3 "$ROOT/scripts/ci/summarize_build_durations.py" "$work/open.log" > "$work/open.txt"
grep -q '5.0 min  gcc-final 15' "$work/open.txt" || fail "an open build step was dropped"
python3 "$ROOT/scripts/ci/summarize_build_durations.py" "$work/missing.log" > "$work/missing.txt"
grep -qx 'no build log' "$work/missing.txt" || fail "a missing build log failed the summary"

stage=$ROOT/.github/workflows/build-stage.yml
build=$ROOT/.github/workflows/build.yml
# shellcheck disable=SC2016
grep -q 'key: ccache-my355-${{ github.run_id }}-${{ inputs.stage }}' "$stage" || fail "stage cache key changed"
# shellcheck disable=SC2016
grep -q 'ccache-my355-${{ github.run_id }}-' "$stage" || fail "same-run restore prefix missing"
grep -q 'ccache-my355-' "$stage" || fail "cross-run restore prefix missing"
# shellcheck disable=SC2016
grep -q 'key: ccache-armhf-${{ github.run_id }}' "$build" || fail "ARMHF ccache key changed"
# shellcheck disable=SC2016
grep -q 'armhf-runtime-${{ hashFiles' "$build" || fail "ARMHF runtime cache key changed"

echo "ccache policy ok"
