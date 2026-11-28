#!/bin/sh
# The Docker workflow publishes a mutable tag. Hosted Builds pull one digest.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
docker=$ROOT/.github/workflows/docker-image.yml
stage=$ROOT/.github/workflows/build-stage.yml
build=$ROOT/.github/workflows/build.yml
pull=$ROOT/scripts/ci/pull-approved-build-container.sh
digest=$ROOT/scripts/ci/build-container.digest
approved=sha256:49f895822d0aed98c591c221a8382b62cb2c5fceec3228c8e45cdd12bc7fec2c

printf '%s\n' "$approved" | cmp -s - "$digest"

grep -q 'GITHUB_REPOSITORY_OWNER: ${{ github.repository_owner }}' "$docker"
grep -q 'owner="${GITHUB_REPOSITORY_OWNER,,}"' "$docker"
grep -q 'img="ghcr.io/${owner}/zlyme-build:latest"' "$docker"
grep -q 'username: ${{ github.actor }}' "$docker"
if grep -q 'ghcr.io/${{ github.repository_owner }}' "$docker"; then
	echo "raw owner in GHCR image reference: $docker" >&2
	exit 1
fi
grep -q 'id=$(sha256sum Dockerfile | awk '"'"'{print $1}'"'"')' "$docker"
grep -q 'docker build --label "zlyme.dockerfile=${id}"' "$docker"
grep -q 'index .Config.Labels "zlyme.dockerfile"' "$docker"
grep -q 'test "$have" = "$id"' "$docker"
grep -q 'sha256sum "${REPO}/Dockerfile"' "$ROOT/build.sh"
grep -q -- '--label "zlyme.dockerfile=${id}"' "$ROOT/build.sh"

grep -q 'build-container.digest' "$pull"
grep -F -q "tr '[:upper:]' '[:lower:]'" "$pull"
grep -F -q 'test "$lines" -eq 1' "$pull"
grep -q 'ghcr.io/${owner}/zlyme-build@${digest}' "$pull"
grep -q 'docker pull "$img"' "$pull"
if grep -q 'docker build' "$pull" || grep -q ':latest' "$pull"; then
	echo "approved pull script has a tag or a local build" >&2
	exit 1
fi

for f in "$build" "$stage"; do
	grep -q 'GITHUB_REPOSITORY_OWNER: ${{ github.repository_owner }}' "$f"
	grep -q 'sh scripts/ci/pull-approved-build-container.sh' "$f"
	if grep -q 'zlyme-build:latest' "$f" || grep -q 'docker build -t zlyme-build' "$f"; then
		echo "hosted Build consumes an unpinned image: $f" >&2
		exit 1
	fi
	if grep -q 'ghcr.io/${{ github.repository_owner }}' "$f"; then
		echo "raw owner in GHCR image reference: $f" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
printf '#!/bin/sh\necho DOCKER-CALLED\nexit 0\n' > "$tmp/docker"
chmod 755 "$tmp/docker"
if GITHUB_REPOSITORY_OWNER='' PATH="$tmp:$PATH" sh "$pull"; then
	echo "empty owner was accepted" >&2
	rm -rf "$tmp"
	exit 1
fi
rm -rf "$tmp"

img=$(GITHUB_REPOSITORY_OWNER=Zetarancio bash -c 'owner="${GITHUB_REPOSITORY_OWNER,,}"; printf "%s\n" "ghcr.io/${owner}/zlyme-build:latest"')
test "$img" = "ghcr.io/zetarancio/zlyme-build:latest"
pinned=$(GITHUB_REPOSITORY_OWNER=Zetarancio sh -c '
	set -eu
	file="$1"
	owner=$(printf "%s" "$GITHUB_REPOSITORY_OWNER" | tr "[:upper:]" "[:lower:]")
	digest=$(sed -e "s/[[:space:]]//g" -e "/^$/d" "$file")
	printf "%s\n" "ghcr.io/${owner}/zlyme-build@${digest}"
' sh "$digest")
test "$pinned" = "ghcr.io/zetarancio/zlyme-build@$approved"
echo "ci container image ok"
