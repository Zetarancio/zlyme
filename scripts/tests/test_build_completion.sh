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
grep -q 'Build window closed without an image; next stage continues from ccache.' "$stage" || fail "continuation message removed"
if ! grep -q 'product-image-present.sh' "$stage"; then
	fail "stage no longer uses the image predicate"
fi

# A timeout with neither artifact is not an image. A tar without the card
# image is not an image. Both files let the releasing stage proceed.
sh "$present" "$work/missing" && fail "missing directory counted as an image"
mkdir -p "$work/images"
sh "$present" "$work/images" && fail "empty directory counted as an image"
: > "$work/images/zlyme-my355-19990101-abc.tar"
sh "$present" "$work/images" && fail "empty OTA counted as an image"
printf 'ota' > "$work/images/zlyme-my355-19990101-abc.tar"
sh "$present" "$work/images" && fail "OTA without zlyme.img counted as an image"
: > "$work/images/zlyme.img"
sh "$present" "$work/images" && fail "empty zlyme.img counted as an image"
printf 'img' > "$work/images/zlyme.img"
sh "$present" "$work/images" || fail "OTA and zlyme.img were rejected"

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

python3 - "$ROOT/.github/workflows/build.yml" "$stage" << 'PY'
import re
import sys
build = open(sys.argv[1], encoding="utf-8").read()
stage = open(sys.argv[2], encoding="utf-8").read()

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
window = stage[stage.find(marker):stage.find(marker) + 160]
if "exit 0" not in window:
    sys.exit("timeout stage no longer continues")
if "require-product-image.sh" in stage:
    sys.exit("a stage job runs the terminal assertion")
print("build completion ok")
PY
