#!/bin/sh
# Hosted stages may time out without an image. The workflow may not.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
present=$ROOT/scripts/ci/product-image-present.sh
require=$ROOT/scripts/ci/require-product-image.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
	echo "build completion: $*" >&2
	exit 1
}

# Intermediate evidence is the stage workflow: a closed window still exits 0.
stage=$ROOT/.github/workflows/build-stage.yml
grep -q '124|137|143' "$stage" || fail "timeout continuation removed"
grep -q 'Build window closed without an image; next stage continues from ccache.' \
	"$ROOT/scripts/ci/stage-outcome.sh" || fail "continuation message removed"
grep -q 'ccache-raise-limit.sh .ccache 8GiB' "$stage" || fail "8GiB limit is not applied"
if grep -q 'ccache -M 1.5G' "$stage"; then
	fail "the pack step still clamps the Actions cache to 1.5G"
fi
grep -q 'pack-ccache-fallback.sh' "$stage" || fail "fallback pack script missing"
grep -q "steps.fallback.outputs.upload == 'true'" "$stage" || fail "oversized fallback can replace the release asset"
grep -q 'stage-outcome.sh' "$stage" || fail "stage result no longer checks the build status"

fill_image() {
	images=$1
	mkdir -p "$images"
	for name in \
		zlyme.img zlyme.img.sha256 \
		miyoo355_fw.img miyoo355_fw.img.sha256 \
		miyoo355_fw-multiboot.img miyoo355_fw-multiboot.img.sha256 \
		miyoo355_fw-maskrom.img miyoo355_fw-maskrom.img.sha256 \
		miyoo355_fw-restore.img miyoo355_fw-restore.img.sha256
	do
		printf 'x' > "$images/$name"
	done
	printf 'ota' > "$images/zlyme-my355-19990101-abc.tar"
	printf 'sum' > "$images/zlyme-my355-19990101-abc.tar.sha256"
}

# A timeout with neither artifact is not an image. A tar without the card
# image is not an image. The card image alone is not the stage set.
sh "$present" "$work/missing" && fail "missing directory counted as an image"
mkdir -p "$work/images"
sh "$present" "$work/images" && fail "empty directory counted as an image"
printf 'ota' > "$work/images/zlyme-my355-19990101-abc.tar"
printf 'sum' > "$work/images/zlyme-my355-19990101-abc.tar.sha256"
printf 'img' > "$work/images/zlyme.img"
sh "$present" "$work/images" && fail "OTA and zlyme.img without helpers counted as an image"
fill_image "$work/images"
sh "$present" "$work/images" || fail "complete stage artifact set was rejected"
printf 'delta' > "$work/images/zlyme-my355-delta-old.tar"
printf 'dsum' > "$work/images/zlyme-my355-delta-old.tar.sha256"
rm -f "$work/images/zlyme-my355-19990101-abc.tar" "$work/images/zlyme-my355-19990101-abc.tar.sha256"
sh "$present" "$work/images" && fail "a delta tar counted as the product OTA"

# A failed or interrupted build does not become an image because files exist.
outcome=$ROOT/scripts/ci/stage-outcome.sh
if sh "$outcome" 124 "$work/full" >/dev/null 2>"$work/err"; then
	:
else
	fail "timeout without files did not continue"
fi
mkdir -p "$work/full"
fill_image "$work/full"
out=$(sh "$outcome" 124 "$work/full" 2>"$work/err") || fail "timeout with files did not continue"
printf '%s\n' "$out" | grep -qx 'have_image=false' || fail "interrupted build was accepted"
grep -q 'next stage continues from ccache' "$work/err" || fail "continuation message missing"
if sh "$outcome" 2 "$work/full" >"$work/out" 2>"$work/err"; then
	fail "failed build with a complete file set was accepted"
fi
grep -qx 'have_image=false' "$work/out" || fail "failed build reported an image"
rm -f "$work/full/zlyme.img"
if sh "$outcome" 0 "$work/full" >"$work/out" 2>"$work/err"; then
	fail "successful build with incomplete files was accepted"
fi
fill_image "$work/full"
out=$(sh "$outcome" 0 "$work/full") || fail "successful complete build was rejected"
printf '%s\n' "$out" | grep -qx 'have_image=true' || fail "successful build did not report an image"

# Final stage, and any run whose outputs are all false or empty, fails.
if STAGE_A_HAVE_IMAGE=false STAGE_B_HAVE_IMAGE=false STAGE_C_HAVE_IMAGE=false \
	sh "$require" 2>/dev/null; then
	fail "final stage with no image succeeded"
fi
if env -u STAGE_A_HAVE_IMAGE -u STAGE_B_HAVE_IMAGE -u STAGE_C_HAVE_IMAGE \
	sh "$require" 2>/dev/null; then
	fail "unset stage outputs succeeded"
fi
if STAGE_A_HAVE_IMAGE=yes STAGE_B_HAVE_IMAGE=1 STAGE_C_HAVE_IMAGE=false \
	sh "$require" 2>/dev/null; then
	fail "non-true outputs succeeded"
fi

# An image from an earlier stage is enough for the terminal check.
STAGE_A_HAVE_IMAGE=true STAGE_B_HAVE_IMAGE='' STAGE_C_HAVE_IMAGE='' \
	sh "$require" >/dev/null || fail "earlier image did not satisfy the terminal check"
STAGE_A_HAVE_IMAGE=false STAGE_B_HAVE_IMAGE=true STAGE_C_HAVE_IMAGE=false \
	sh "$require" >/dev/null || fail "middle image did not satisfy the terminal check"
# An image from the last stage is enough for the release path's predecessor.
STAGE_A_HAVE_IMAGE=false STAGE_B_HAVE_IMAGE=false STAGE_C_HAVE_IMAGE=true \
	sh "$require" >/dev/null || fail "last-stage image did not satisfy the terminal check"

python3 - "$ROOT/.github/workflows/build.yml" "$stage" "$ROOT/scripts/ci/stage-outcome.sh" << 'PY'
import re
import sys
build = open(sys.argv[1], encoding="utf-8").read()
stage = open(sys.argv[2], encoding="utf-8").read()
outcome = open(sys.argv[3], encoding="utf-8").read()

def job(text, name):
    marks = list(re.finditer(r"(?m)^  ([A-Za-z0-9-]+):\s*$", text))
    for i, mark in enumerate(marks):
        if mark.group(1) != name:
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        return text[mark.start():end]
    sys.exit("missing job %s" % name)

for name, prev in (("stage-b", "stage-a"), ("stage-c", "stage-b")):
    body = job(build, name)
    if "needs.%s.outputs.have_image != 'true'" % prev not in body:
        sys.exit("%s can run after %s already has an image" % (name, prev))
    if "needs.%s.result == 'success'" % prev not in body:
        sys.exit("%s no longer waits for a successful previous stage" % name)

req = job(build, "require-image")
if "scripts/ci/require-product-image.sh" not in req:
    sys.exit("terminal assertion is not require-product-image.sh")
header = req.split("steps:", 1)[0]
for name in ("stage-a", "stage-b", "stage-c"):
    if name not in header:
        sys.exit("require-image does not need %s" % name)
if "always() && !cancelled()" not in req:
    sys.exit("require-image does not run after a timeout stage")

rel = job(build, "release")
header = rel.split("steps:", 1)[0]
if "needs.require-image.result == 'success'" not in header:
    sys.exit("release can run when the image assertion failed")
if "inputs.publish_release == true" not in header:
    sys.exit("release lost the publish gate")
for name in ("stage-a", "stage-b", "stage-c"):
    if "needs.%s.outputs.have_image == 'true'" % name not in header:
        sys.exit("release can run without %s having an image" % name)
if "require-image" not in header.split("if:", 1)[0]:
    sys.exit("release does not need the image assertion")
body = rel.split("steps:", 1)[1]
if '--source-sha "${{ github.sha }}"' not in body:
    sys.exit("release source SHA is no longer github.sha")
if "--repo ." not in body:
    sys.exit("release asset check lost the checkout")
if body.find("scripts/check-release-assets.py") > body.find("softprops/action-gh-release"):
    sys.exit("asset check moved after publication")

# The stage timeout remains success. The terminal job is the failure.
marker = "Build window closed without an image"
window = outcome[outcome.find(marker):outcome.find(marker) + 200]
if "exit 0" not in window:
    sys.exit("timeout stage no longer continues")
if "stage-outcome.sh" not in stage:
    sys.exit("the stage does not use the build-status decision")
if "require-product-image.sh" in stage:
    sys.exit("a stage job runs the terminal assertion")
print("build completion ok")
PY
