#!/bin/sh
# The ARMHF export key covers the container and the SDL2 patches.
# Product ccache stays a separate store, including a stage with no image.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)

python3 - "$ROOT" << 'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
build = (root / ".github" / "workflows" / "build.yml").read_text(encoding="utf-8")
stage = (root / ".github" / "workflows" / "build-stage.yml").read_text(encoding="utf-8")

def fail(message):
    sys.exit(message)

keys = re.findall(r"armhf-runtime-\$\{\{ hashFiles\((.*)\) \}\}", build)
if len(keys) != 2:
    fail("expected two ARMHF export keys, found %d" % len(keys))
if keys[0] != keys[1]:
    fail("ARMHF export restore and save keys differ")
key = keys[0]
for required in ("'Dockerfile'", "'board/my355/patches/sdl2/**'"):
    if required not in key:
        fail("ARMHF export key omits %s" % required)
if "board.mk" in key or "board/my355/linux" in key or "board/my355/uboot" in key:
    fail("ARMHF export key includes an unrelated board path")

# Product compiler cache is unchanged.
if "key: ccache-my355-${{ github.run_id }}-${{ inputs.stage }}" not in stage:
    fail("product ccache key changed")
if "ccache-my355-${{ github.run_id }}-" not in stage:
    fail("same-run ccache restore prefix missing")
if re.search(r"(?m)^            ccache-my355-$", stage) is None:
    fail("cross-run ccache restore prefix missing")
if "sh scripts/ci/ccache-raise-limit.sh .ccache 8GiB" not in stage:
    fail("product ccache limit changed")
if "key: ccache-armhf-${{ github.run_id }}" not in build:
    fail("ARMHF compiler cache key changed")

def step(text, name):
    marker = "- name: %s\n" % name
    start = text.find(marker)
    if start < 0:
        fail("missing step %s" % name)
    rest = text[start + len(marker):]
    nxt = rest.find("\n      - name: ")
    return rest if nxt < 0 else rest[:nxt]

save = step(stage, "Save ccache (Actions cache)")
if "if: always()" not in save:
    fail("a stage does not save ccache when it has no image")
if "have_image" in save:
    fail("product ccache save is gated on an image")
restore = step(stage, "Restore ccache (Actions cache)")
if "ccache-my355-${{ github.run_id }}-" not in restore:
    fail("later stages cannot restore this run's ccache")

# Stage B and C still run the same workflow when the previous stage has no image.
for earlier, later in (("stage-a", "stage-b"), ("stage-b", "stage-c")):
    needle = (
        "  %s:\n"
        "    needs: %s\n"
        "    if: needs.%s.result == 'success' && needs.%s.outputs.have_image != 'true'\n"
    ) % (later, earlier, earlier, earlier)
    if needle not in build:
        fail("%s no longer continues from a stage without an image" % later)

print("armhf export key ok")
PY
