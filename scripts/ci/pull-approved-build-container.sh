#!/bin/sh
# Pull the approved GHCR build image by digest and tag it zlyme-build.
# A hosted Build fails if that digest is not available. This script does
# not pull a tag and does not build a substitute image.
set -eu
owner=${GITHUB_REPOSITORY_OWNER:?}
here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
file=$here/build-container.digest
owner=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
digest=$(sed -e 's/[[:space:]]//g' -e '/^$/d' "$file")
lines=$(printf '%s\n' "$digest" | grep -c .)
test "$lines" -eq 1
printf '%s\n' "$digest" | grep -Eq '^sha256:[0-9a-f]{64}$'
img="ghcr.io/${owner}/zlyme-build@${digest}"
docker pull "$img"
docker tag "$img" zlyme-build
