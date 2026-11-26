#!/bin/sh
# Job tokens stay at the scopes each Build job uses. The called stage
# workflow cannot ask for more than the caller grants.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)

python3 - "$ROOT" << 'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])

def fail(message):
    sys.exit(message)

def load(name):
    return (root / ".github" / "workflows" / name).read_text(encoding="utf-8")

def top_permissions(text):
    for line in text.splitlines():
        if line == "permissions:":
            return True
        if line == "jobs:":
            return False
    return False

def job_blocks(text):
    lines = text.splitlines()
    try:
        start = lines.index("jobs:")
    except ValueError:
        fail("workflow has no jobs")
    jobs = []
    name = None
    buf = []
    for line in lines[start + 1:]:
        if line.startswith("  ") and not line.startswith("   ") and line.endswith(":"):
            if name is not None:
                jobs.append((name, buf))
            name = line.strip()[:-1]
            buf = []
        elif name is not None:
            if line and not line.startswith(" "):
                break
            buf.append(line)
    if name is not None:
        jobs.append((name, buf))
    return jobs

def permissions_of(buf):
    found = False
    perms = {}
    for line in buf:
        if line == "    permissions:":
            if found:
                fail("a job declares permissions twice")
            found = True
            continue
        if found:
            if line.startswith("      ") and ":" in line:
                key, value = line.strip().split(":", 1)
                perms[key] = value.strip()
                continue
            break
    if not found:
        fail("a job has no permissions block")
    return perms

RANK = {"read": 1, "write": 2}

def covers(caller, callee):
    for scope, level in callee.items():
        have = caller.get(scope)
        if have is None or RANK[have] < RANK[level]:
            return False
    return True

build = load("build.yml")
stage = load("build-stage.yml")
docker = load("docker-image.yml")

if top_permissions(build) or top_permissions(stage):
    fail("Build workflows still grant one token to every job")
if "cache-mode:" in build or "cache-mode:" in stage:
    fail("cache-mode was changed")

expected = {
    "armhf": {"contents": "read"},
    "stage-a": {"contents": "read", "packages": "read"},
    "stage-b": {"contents": "read", "packages": "read"},
    "stage-c": {"contents": "read", "packages": "read"},
    "require-image": {"contents": "read"},
    "release": {"contents": "write"},
}
found = {name: permissions_of(buf) for name, buf in job_blocks(build)}
if set(found) != set(expected):
    fail("Build jobs are %s" % sorted(found))
for name, want in expected.items():
    if found[name] != want:
        fail("%s permissions are %s" % (name, found[name]))

stage_jobs = job_blocks(stage)
if [name for name, _ in stage_jobs] != ["image"]:
    fail("stage workflow jobs changed")
image = permissions_of(stage_jobs[0][1])
if image != {"contents": "read", "packages": "read"}:
    fail("stage image permissions are %s" % image)
for caller in ("stage-a", "stage-b", "stage-c"):
    if not covers(found[caller], image):
        fail("%s grants less than the called stage workflow" % caller)

release = dict(job_blocks(build))["release"]
header = "\n".join(release)
for needle in (
    "inputs.publish_release == true",
    "needs.require-image.result == 'success'",
    "needs.stage-a.outputs.have_image == 'true'",
    "needs.stage-b.outputs.have_image == 'true'",
    "needs.stage-c.outputs.have_image == 'true'",
):
    if needle not in header:
        fail("release gate lost %s" % needle)
if "permissions:" not in header or "contents: write" not in header:
    fail("product release lost contents: write")

if "token: ${{ secrets.GH_PAT }}" not in stage:
    fail("cross-repository ccache no longer uses GH_PAT")
if "sh scripts/ci/ccache-raise-limit.sh .ccache 8GiB" not in stage:
    fail("product ccache limit changed")

# The Docker publication workflow is outside this reduction.
if docker.split("jobs:", 1)[0].count("\npermissions:\n") != 1:
    fail("Docker workflow permission block changed shape")
docker_head = docker.split("jobs:", 1)[0]
if "contents: read" not in docker_head or "packages: write" not in docker_head:
    fail("Docker workflow permissions changed")

print("build job permissions ok")
PY
