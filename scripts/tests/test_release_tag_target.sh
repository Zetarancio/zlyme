#!/bin/sh
# A newly created product release tag must point at the workflow source SHA.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
wf=$ROOT/.github/workflows/build.yml
python3 - "$wf" << 'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
start = text.find("      - name: Release\n")
if start < 0:
    sys.exit("product Release step not found")
end = text.find("\n        env:\n", start)
block = text[start:end if end > start else None]
pin = "softprops/action-gh-release@8a0cd651e5b2365bd640854a3fa5dfc70e4875f3 # v3"
if pin not in block:
    sys.exit("product release is not the verified action-gh-release v3 commit")
if "target_commitish: ${{ github.sha }}" not in block:
    sys.exit("product release tag is not pinned to github.sha")
if "tag_name:" not in block:
    sys.exit("product release tag name missing")
print("release tag target ok")
PY
# The ccache release stays a moving cache tag. Do not pin it to one SHA.
if grep -n 'tag_name: ccache' -A 12 "$ROOT/.github/workflows/build-stage.yml" | grep -q 'target_commitish:'; then
	echo "ccache release was given a source SHA pin" >&2
	exit 1
fi
echo "ccache tag left unpinned"
