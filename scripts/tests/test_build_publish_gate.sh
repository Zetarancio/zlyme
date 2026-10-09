#!/bin/sh
# A manual Build dispatch is a candidate unless publication is requested.
# This checks that contract in the workflow text. It is not a YAML parser.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
wf=$ROOT/.github/workflows/build.yml

python3 - "$wf" << 'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
key = text.find("\n      publish_release:\n")
if key < 0:
    sys.exit("publish_release input is missing")
window = text[key:text.find("\njobs:", key)]
if "\n        type: boolean\n" not in window:
    sys.exit("publish_release is not a boolean input")
default = None
for line in window.splitlines():
    stripped = line.strip()
    if stripped.startswith("default:"):
        default = stripped.split(":", 1)[1].strip()
        break
if default != "false":
    sys.exit("publish_release default is %r, expected false" % default)
rel = text.find("\n  release:\n")
if rel < 0:
    sys.exit("release job is missing")
steps = text.find("\n    steps:\n", rel)
header = text[rel:steps if steps > rel else None]
if "inputs.publish_release == true" not in header:
    sys.exit("release job lost the explicit publish gate")
body = text[rel:]
if "prerelease: false" not in body or "make_latest: true" not in body:
    sys.exit("publication no longer keeps a stable latest release")
for name in ("zlyme.img\n", "zlyme.img.sha256\n"):
    if name not in body:
        sys.exit("release assets omit %s" % name.strip())
stage = open(sys.argv[1].rsplit("/.github/", 1)[0] + "/.github/workflows/build-stage.yml", encoding="utf-8").read()
if "output/images/zlyme.img\n" not in stage or "output/images/zlyme.img.sha256\n" not in stage:
    sys.exit("candidate artifact omits zlyme.img or zlyme.img.sha256")
post = open(sys.argv[1].rsplit("/.github/", 1)[0] + "/board/my355/post-image.sh", encoding="utf-8").read()
if "sha256sum zlyme.img > zlyme.img.sha256" not in post:
    sys.exit("post-image does not write zlyme.img.sha256")
ota = open(sys.argv[1].rsplit("/.github/", 1)[0] + "/board/my355/make-update-tar.sh", encoding="utf-8").read()
if "zlyme.img" in ota:
    sys.exit("OTA packer mentions zlyme.img")
print("build publish gate ok")
PY
