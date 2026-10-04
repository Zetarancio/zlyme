#!/bin/sh
# GHCR repository names must be lowercase. The GitHub owner is not.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
docker=$ROOT/.github/workflows/docker-image.yml
stage=$ROOT/.github/workflows/build-stage.yml

for f in "$docker" "$stage"; do
	grep -q 'GITHUB_REPOSITORY_OWNER: ${{ github.repository_owner }}' "$f"
	grep -q 'owner="${GITHUB_REPOSITORY_OWNER,,}"' "$f"
	grep -q 'img="ghcr.io/${owner}/zlyme-build:latest"' "$f"
	if grep -q 'ghcr.io/${{ github.repository_owner }}' "$f"; then
		echo "raw owner in GHCR image reference: $f" >&2
		exit 1
	fi
	grep -q 'username: ${{ github.actor }}' "$f"
done

img=$(GITHUB_REPOSITORY_OWNER=Zetarancio bash -c 'owner="${GITHUB_REPOSITORY_OWNER,,}"; printf "%s\n" "ghcr.io/${owner}/zlyme-build:latest"')
test "$img" = "ghcr.io/zetarancio/zlyme-build:latest"
echo "ci container image ok"
