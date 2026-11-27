#!/bin/sh
# Dependabot proposes reviewable updates. It does not merge them,
# and a Dockerfile change still publishes only from main.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)

python3 - "$ROOT" << 'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])

def fail(message):
    sys.exit(message)

text = (root / ".github" / "dependabot.yml").read_text(encoding="utf-8")
if "version: 2\n" not in text:
    fail("dependabot.yml is not version 2")
blocks = re.findall(
    r"- package-ecosystem: (\S+)\n"
    r"    directory: (\S+)\n"
    r"    schedule:\n"
    r"      interval: (\S+)\n"
    r"      day: (\S+)\n"
    r"    open-pull-requests-limit: (\d+)\n",
    text,
)
expected = [
    ("github-actions", "/", "weekly", "monday", "5"),
    ("docker", "/", "weekly", "monday", "2"),
]
if blocks != expected:
    fail("dependabot updates are %s" % blocks)
for banned in ("buildroot", "auto-merge", "automerge", "npm", "pip", "gitsubmodule"):
    if banned in text:
        fail("dependabot.yml contains %s" % banned)

workflows = (root / ".github" / "workflows")
sha_use = re.compile(
    r"uses:\s+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}\b"
)
for path in sorted(workflows.glob("*.yml")):
    for line in path.read_text(encoding="utf-8").splitlines():
        if sha_use.search(line) and not re.search(r"#\s+v\d", line):
            fail("SHA pin has no version comment: %s: %s" % (path.name, line.strip()))

docker = (root / ".github" / "workflows" / "docker-image.yml").read_text(encoding="utf-8")
if "if: github.ref == 'refs/heads/main'" not in docker:
    fail("Docker publication is not limited to main")
if 'img="ghcr.io/${owner}/zlyme-build:latest"' not in docker:
    fail("production image reference changed")

dockerfile = (root / "Dockerfile").read_text(encoding="utf-8")
if not re.search(r"^FROM debian:trixie-slim@sha256:[0-9a-f]{64}\s*$", dockerfile, re.M):
    fail("Dockerfile base image is not a digest-pinned trixie-slim")

print("dependabot config ok")
PY
