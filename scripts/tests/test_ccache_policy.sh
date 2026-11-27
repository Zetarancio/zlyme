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

# ARMHF compiler-cache recovery. GitHub applies success() unless the if
# names a status function. cancelled() is that function. Exit 124 is
# outcome failure, so it still saves. A skipped or cancelled compile does not.
python3 - "$build" << 'PY'
import sys

build_path = sys.argv[1]
lines = open(build_path, encoding="utf-8").read().splitlines()

def die(message):
    sys.exit("armhf cache recovery: " + message)

def job(name):
    start = None
    for i, line in enumerate(lines):
        if line == "  %s:" % name:
            start = i
            break
    if start is None:
        die("missing job %s" % name)
    end = len(lines)
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if line.startswith("  ") and not line.startswith("   ") and line.endswith(":"):
            end = i
            break
    return "\n".join(lines[start:end]) + "\n"

def steps(body):
    return ["      - " + part for part in body.split("\n      - ")[1:]]

def one(body, name):
    found = [step for step in steps(body) if step.startswith("      - name: %s\n" % name)]
    if len(found) != 1:
        die("expected one %s step, found %d" % (name, len(found)))
    return found[0]

def value(step, key):
    prefix = key + ": "
    for line in step.splitlines():
        stripped = line.strip()
        if stripped.startswith(prefix):
            return stripped[len(prefix):].strip()
    return ""

armhf = job("armhf")
if "\n    timeout-minutes: 360\n" not in armhf:
    die("ARMHF job limit is not 360 minutes")
compile_step = one(armhf, "Build ARMHF sysroot")
save_step = one(armhf, "Save ARMHF ccache")
export_step = one(armhf, "Save ARMHF runtime export")
restore_step = one(armhf, "Restore ARMHF ccache")
upload_step = one(armhf, "Upload ARMHF runtime")
pack_step = one(armhf, "Pack ARMHF runtime tar")

if value(compile_step, "id") != "armhf_compile":
    die("compile step id changed")
if value(compile_step, "if") != "steps.cached.outputs.hit != 'true'":
    die("compile step no longer depends only on an export miss")
if any(line.strip().startswith("continue-on-error:") for line in compile_step.splitlines()):
    die("a failed compile can be reported as job success")
if "set -euo pipefail" not in compile_step:
    die("compile step no longer stops on a failed command")
timeout_at = compile_step.find("timeout --signal=TERM -k 3m 310m ./scripts/build-armhf-sysroot.sh")
export_at = compile_step.find("./scripts/armhf-runtime-export.sh output-armhf-export")
if not (0 <= timeout_at < export_at):
    die("runtime export is no longer sequenced after the compile timeout")

save_if = "${{ !cancelled() && steps.cached.outputs.hit != 'true' && (steps.armhf_compile.outcome == 'success' || steps.armhf_compile.outcome == 'failure') }}"
if value(save_step, "if") != save_if:
    die("compiler-cache save condition changed")
if "cancelled(" not in save_if:
    die("compiler-cache save does not override implicit success()")
for fn in ("success(", "failure(", "always("):
    if fn in save_if:
        die("compiler-cache save uses %s" % fn)
if "actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9" not in save_step:
    die("compiler-cache save action pin changed")
if not any(line.strip() == "continue-on-error: true" for line in save_step.splitlines()):
    die("compiler-cache save no longer tolerates its own error")
if value(save_step, "path") != ".ccache-armhf" or value(restore_step, "path") != ".ccache-armhf":
    die("compiler-cache path changed")
key = "ccache-armhf-${{ github.run_id }}"
if value(save_step, "key") != key or value(restore_step, "key") != key:
    die("compiler-cache run key changed")
if not any(line.strip() == "ccache-armhf-" for line in restore_step.splitlines()):
    die("compiler-cache restore prefix changed")

export_if = value(export_step, "if")
if export_if != "steps.cached.outputs.hit != 'true'":
    die("runtime export save gate changed")
for fn in ("success(", "failure(", "always(", "cancelled("):
    if fn in export_if or fn in value(compile_step, "if"):
        die("export or compile condition overrides implicit success()")
if "\n        if:" in "\n" + upload_step or "\n        if:" in "\n" + pack_step:
    die("runtime pack or upload no longer uses the implicit success gate")
if "if-no-files-found: error" not in upload_step:
    die("runtime upload can succeed without an artifact")

def save_ccache(cancelled, hit, outcome):
    return (not cancelled) and hit != "true" and outcome in ("success", "failure")

def save_export(prior_success, hit):
    return prior_success and hit != "true"

# Columns: cancelled, hit, outcome, prior success, save ccache, save export.
# A reused export keeps prior success true and does not write a new export.
rows = (
    ("compile succeeds", False, "false", "success", True, True, True),
    ("compile fails", False, "false", "failure", False, True, False),
    ("compile times out, exit 124", False, "false", "failure", False, True, False),
    ("valid export reused", False, "true", "skipped", True, False, False),
    ("container pull fails", False, "false", "skipped", False, False, False),
    ("checkout fails", False, "false", "skipped", False, False, False),
    ("workflow cancelled", True, "false", "cancelled", False, False, False),
)
for name, cancelled, hit, outcome, prior_success, want_save, want_export in rows:
    if save_ccache(cancelled, hit, outcome) != want_save:
        die("%s save mismatch" % name)
    if save_export(prior_success, hit) != want_export:
        die("%s export mismatch" % name)
if save_ccache(False, "false", "cancelled"):
    die("a cancelled compile outcome can save")
print("armhf cache recovery ok")
PY

echo "ccache policy ok"
