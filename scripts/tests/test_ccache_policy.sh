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

# ARMHF compiler-cache recovery. GitHub applies success() to an if that
# names no status function, so a failed or timed-out compile used to skip
# the save. timeout(1) exit 124 fails the step; it does not cancel the run.
python3 - "$build" "$stage" << 'PY'
import sys

import yaml

build_path, stage_path = sys.argv[1], sys.argv[2]
build = yaml.safe_load(open(build_path, encoding="utf-8"))
stage = yaml.safe_load(open(stage_path, encoding="utf-8"))
raw_build = open(build_path, encoding="utf-8").read()

def die(message):
    sys.exit("armhf cache recovery: " + message)

perms = build.get("permissions")
if perms != {"contents": "write", "packages": "read"}:
    die("workflow permissions changed: %r" % perms)
stage_perms = stage.get("permissions")
if stage_perms != {"contents": "write", "packages": "read"}:
    die("product stage permissions changed: %r" % stage_perms)

armhf = build["jobs"]["armhf"]
if armhf.get("timeout-minutes") != 360:
    die("ARMHF job limit is not 360 minutes")
if "permissions" in armhf:
    die("ARMHF job permissions changed")

def step_name(raw):
    if raw.get("name"):
        return raw["name"]
    uses = raw.get("uses") or ""
    if "actions/checkout" in uses:
        return "checkout"
    return uses or "unnamed"

steps = []
for raw in armhf["steps"]:
    steps.append({
        "name": step_name(raw),
        "id": raw.get("id"),
        "if": "" if raw.get("if") is None else str(raw.get("if")),
        "continue": raw.get("continue-on-error") is True,
        "uses": raw.get("uses") or "",
        "run": raw.get("run") or "",
        "with": raw.get("with") or {},
    })

by_name = {}
for step in steps:
    if step["name"] in by_name:
        die("duplicate step name %s" % step["name"])
    by_name[step["name"]] = step

compile_step = by_name["Build ARMHF sysroot"]
save_step = by_name["Save ARMHF ccache"]
export_step = by_name["Save ARMHF runtime export"]
restore_step = by_name["Restore ARMHF ccache"]
if compile_step["id"] != "armhf_compile":
    die("compile step id is %r" % compile_step["id"])
if "timeout --signal=TERM -k 3m 310m ./scripts/build-armhf-sysroot.sh" not in compile_step["run"]:
    die("310-minute ARMHF command limit changed")
if "set -euo pipefail" not in compile_step["run"]:
    die("compile step no longer stops after a failed command")
timeout_at = compile_step["run"].find("timeout --signal=TERM -k 3m 310m ./scripts/build-armhf-sysroot.sh")
export_at = compile_step["run"].find("./scripts/armhf-runtime-export.sh output-armhf-export")
if not (0 <= timeout_at < export_at):
    die("runtime export is no longer sequenced after the compile timeout")
expected_save = "${{ !cancelled() && steps.cached.outputs.hit != 'true' && steps.armhf_compile.outcome != 'skipped' }}"
if save_step["if"] != expected_save:
    die("compiler-cache save condition is %r" % save_step["if"])
if "have_image" in save_step["if"]:
    die("compiler-cache save depends on an image")
if save_step["uses"] != "actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9":
    die("compiler-cache save action pin changed")
if save_step["continue"] is not True:
    die("compiler-cache save no longer continues on its own error")
if save_step["with"].get("path") != ".ccache-armhf":
    die("compiler-cache path changed")
if save_step["with"].get("key") != "ccache-armhf-${{ github.run_id }}":
    die("compiler-cache save key changed")
if restore_step["with"].get("key") != "ccache-armhf-${{ github.run_id }}":
    die("compiler-cache restore key changed")
restore_prefixes = restore_step["with"].get("restore-keys") or ""
if "ccache-armhf-" not in restore_prefixes:
    die("compiler-cache restore prefix changed")
for fn in ("success(", "failure(", "always(", "cancelled("):
    if fn in export_step["if"] or fn in compile_step["if"]:
        die("export or compile condition gained a status function")
if "steps.cached.outputs.hit != 'true'" not in export_step["if"]:
    die("runtime export save no longer requires a cache miss")
if "actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9" not in export_step["uses"]:
    die("runtime export save pin changed")

product_steps = stage["jobs"]["image"]["steps"]
product_save = [s for s in product_steps if s.get("name") == "Save ccache (Actions cache)"]
if len(product_save) != 1 or str(product_save[0].get("if")) != "always()":
    die("product compiler-cache save is no longer unconditional")
if any("have_image" in str(s.get("if") or "") for s in product_save):
    die("product compiler-cache save now requires an image")

release = build["jobs"]["release"]
release_if = str(release.get("if") or "")
for phrase in (
    "always() && !cancelled()",
    "needs.require-image.result == 'success'",
    "inputs.publish_release == true",
    "needs.stage-a.outputs.have_image == 'true'",
    "needs.stage-b.outputs.have_image == 'true'",
    "needs.stage-c.outputs.have_image == 'true'",
):
    if phrase not in release_if:
        die("release gate lost %s" % phrase)
require_if = str(build["jobs"]["require-image"].get("if") or "")
if "always() && !cancelled()" not in require_if:
    die("require-image gate changed")
if "contents: write" not in raw_build.split("jobs:", 1)[0]:
    die("workflow-level contents permission changed")

def has_status(expr):
    return any(fn in expr for fn in ("success(", "failure(", "always(", "cancelled("))

def unwrap(expr):
    expr = expr.strip()
    if expr.startswith("${{") and expr.endswith("}}"):
        expr = expr[3:-2].strip()
    return expr

class Parser(object):
    def __init__(self, text, env):
        self.text = text
        self.env = env
        self.i = 0

    def skip(self):
        while self.i < len(self.text) and self.text[self.i].isspace():
            self.i += 1

    def take(self, token):
        self.skip()
        if self.text.startswith(token, self.i):
            self.i += len(token)
            return True
        return False

    def parse(self):
        value = self.parse_or()
        self.skip()
        if self.i != len(self.text):
            die("unparsed %r in %r" % (self.text[self.i:], self.text))
        return value

    def parse_or(self):
        value = self.parse_and()
        while self.take("||"):
            value = bool(value) or bool(self.parse_and())
        return value

    def parse_and(self):
        value = self.parse_unary()
        while self.take("&&"):
            rhs = self.parse_unary()
            value = bool(value) and bool(rhs)
        return value

    def parse_unary(self):
        self.skip()
        if self.take("!"):
            return not bool(self.parse_unary())
        return self.parse_primary()

    def parse_primary(self):
        self.skip()
        if self.take("("):
            value = self.parse_or()
            if not self.take(")"):
                die("missing ) in %r" % self.text)
            return value
        if self.take("success("):
            if not self.take(")"):
                die("bad success() call")
            return self.env["success"]
        if self.take("failure("):
            if not self.take(")"):
                die("bad failure() call")
            return self.env["failure"]
        if self.take("always("):
            if not self.take(")"):
                die("bad always() call")
            return True
        if self.take("cancelled("):
            if not self.take(")"):
                die("bad cancelled() call")
            return self.env["cancelled"]
        if self.take("steps."):
            return self.parse_comparison()
        die("unsupported expression %r" % self.text[self.i:])

    def parse_comparison(self):
        ident = self.identifier()
        if not self.take("."):
            die("step context missing a field")
        field = self.identifier()
        output = None
        if field == "outputs":
            if not self.take("."):
                die("step output missing a name")
            output = self.identifier()
        elif field != "outcome":
            die("unsupported step field %s" % field)
        if self.take("!="):
            op = "!="
        elif self.take("=="):
            op = "=="
        else:
            die("missing comparison")
        self.skip()
        if self.i >= len(self.text) or self.text[self.i] != "'":
            die("comparison is not a quoted string")
        self.i += 1
        end = self.text.find("'", self.i)
        if end < 0:
            die("unterminated string")
        expected = self.text[self.i:end]
        self.i = end + 1
        if output is None:
            actual = self.env["outcomes"].get(ident, "")
        else:
            actual = self.env["outputs"].get(ident, {}).get(output, "")
        same = actual.casefold() == expected.casefold()
        return same if op == "==" else not same

    def identifier(self):
        self.skip()
        start = self.i
        while self.i < len(self.text) and (self.text[self.i].isalnum() or self.text[self.i] in "_-"):
            self.i += 1
        if start == self.i:
            die("missing identifier in %r" % self.text)
        return self.text[start:self.i]

def enabled(step, env):
    expr = unwrap(step["if"])
    if not has_status(expr):
        expr = "success()" if not expr else "success() && (" + expr + ")"
    return bool(Parser(expr, env).parse())

def simulate(scenario):
    outcomes = {}
    outputs = {}
    conclusions = []
    seen = {}
    cancelled = False
    for step in steps:
        def env_now():
            return {
                "success": all(item in ("success", "skipped") for item in conclusions),
                "failure": any(item == "failure" for item in conclusions),
                "cancelled": cancelled,
                "outcomes": outcomes,
                "outputs": outputs,
            }
        # Cancelling the workflow while this step is running gives that step
        # outcome cancelled. Later steps then see cancelled().
        if scenario.get("cancel_at") == step["name"] and enabled(step, env_now()):
            seen[step["name"]] = "ran"
            outcome = "cancelled"
            conclusion = "cancelled"
            cancelled = True
        elif not enabled(step, env_now()):
            outcome = "skipped"
            conclusion = "skipped"
            seen[step["name"]] = "skipped"
        else:
            spec = scenario.get("result", {}).get(step["name"], "success")
            seen[step["name"]] = "ran"
            if spec == "fail":
                outcome = "failure"
                conclusion = "success" if step["continue"] else "failure"
            elif spec == "success":
                outcome = "success"
                conclusion = "success"
                if step["id"] and step["id"] in scenario.get("outputs", {}):
                    outputs[step["id"]] = scenario["outputs"][step["id"]]
            else:
                die("bad step result %r" % spec)
        if step["id"]:
            outcomes[step["id"]] = outcome
        conclusions.append(conclusion)
    if cancelled or any(item == "cancelled" for item in conclusions):
        job = "cancelled"
    elif any(item == "failure" for item in conclusions):
        job = "failure"
    else:
        job = "success"
    for name, want in scenario["expect"].items():
        if name == "job":
            got = job
        else:
            got = seen.get(name)
        if got != want:
            die("%s: %s is %s, expected %s" % (scenario["name"], name, got, want))
    return job

# The documented default: no status function, so a failed compile skips the save.
legacy_steps_if = save_step["if"]
save_step["if"] = "steps.cached.outputs.hit != 'true'"
simulate({
    "name": "legacy implicit success",
    "outputs": {"cached": {"hit": "false"}},
    "result": {"Build ARMHF sysroot": "fail"},
    "expect": {
        "Save ARMHF ccache": "skipped",
        "job": "failure",
    },
})
save_step["if"] = legacy_steps_if

checks = [
    {
        "name": "successful compile",
        "outputs": {"cached": {"hit": "false"}},
        "result": {},
        "expect": {
            "Build ARMHF sysroot": "ran",
            "Save ARMHF ccache": "ran",
            "Save ARMHF runtime export": "ran",
            "Pack ARMHF runtime tar": "ran",
            "Upload ARMHF runtime": "ran",
            "job": "success",
        },
    },
    {
        "name": "compile failure",
        "outputs": {"cached": {"hit": "false"}},
        "result": {"Build ARMHF sysroot": "fail"},
        "expect": {
            "Build ARMHF sysroot": "ran",
            "Save ARMHF ccache": "ran",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "skipped",
            "Upload ARMHF runtime": "skipped",
            "job": "failure",
        },
    },
    {
        "name": "compile timeout 124",
        "outputs": {"cached": {"hit": "false"}},
        "result": {
            "Build ARMHF sysroot": "fail",
            "Save ARMHF ccache": "fail",
        },
        "expect": {
            "Build ARMHF sysroot": "ran",
            "Save ARMHF ccache": "ran",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "skipped",
            "Upload ARMHF runtime": "skipped",
            "job": "failure",
        },
    },
    {
        "name": "validated export reused",
        "outputs": {"cached": {"hit": "true"}},
        "result": {},
        "expect": {
            "Build ARMHF sysroot": "skipped",
            "Save ARMHF ccache": "skipped",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "ran",
            "Upload ARMHF runtime": "ran",
            "job": "success",
        },
    },
    {
        "name": "container prerequisite failed",
        "outputs": {"cached": {"hit": "false"}},
        "result": {"Pull or build zlyme-build": "fail"},
        "expect": {
            "Build ARMHF sysroot": "skipped",
            "Save ARMHF ccache": "skipped",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "skipped",
            "Upload ARMHF runtime": "skipped",
            "job": "failure",
        },
    },
    {
        "name": "checkout prerequisite failed",
        "outputs": {},
        "result": {"checkout": "fail"},
        "expect": {
            "Build ARMHF sysroot": "skipped",
            "Save ARMHF ccache": "skipped",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "skipped",
            "Upload ARMHF runtime": "skipped",
            "job": "failure",
        },
    },
    {
        "name": "workflow cancelled during compile",
        "outputs": {"cached": {"hit": "false"}},
        "cancel_at": "Build ARMHF sysroot",
        "result": {},
        "expect": {
            "Build ARMHF sysroot": "ran",
            "Save ARMHF ccache": "skipped",
            "Save ARMHF runtime export": "skipped",
            "Pack ARMHF runtime tar": "skipped",
            "Upload ARMHF runtime": "skipped",
            "job": "cancelled",
        },
    },
    {
        "name": "ccache restore failed open",
        "outputs": {"cached": {"hit": "false"}},
        "result": {
            "Restore ARMHF ccache": "fail",
            "Build ARMHF sysroot": "fail",
        },
        "expect": {
            "Restore ARMHF ccache": "ran",
            "Build ARMHF sysroot": "ran",
            "Save ARMHF ccache": "ran",
            "Save ARMHF runtime export": "skipped",
            "job": "failure",
        },
    },
]
for scenario in checks:
    simulate(scenario)
print("armhf cache recovery ok")
PY

echo "ccache policy ok"
