# zlyme-cache

The product compiler cache has two stores. GitHub Actions cache is the
primary one. `.github/workflows/build-stage.yml` restores and saves
`.ccache` with `actions/cache`. The save key is
`ccache-my355-<run id>-<stage>`. A later stage restores
`ccache-my355-<run id>-`, then `ccache-my355-`. After that restore, and
before compilation, the stage sets the maximum to `8GiB` and does not
delete cached objects. A warm ccache is not a Buildroot output tree.
The ARMHF job keeps its own `.ccache-armhf` and runtime-export caches.
`docs/DEVELOPMENT.md` owns the size, eviction, and statistics contract.

The `zlyme-cache` repository is an optional fallback seed, the same
moving-tag idea as ROCKNIX `distribution-cache`. Its prerelease tag is
`ccache`. `scripts/ci/pack-ccache-fallback.sh` writes
`ccache-my355.tar.zst` only when `du -sb` of the cache directory and the
compressed archive are both under 2 GiB. A larger cache skips the upload
and leaves the existing asset in place. That skip does not shrink the
Actions cache. The workflow restores the asset with unauthenticated
`curl`. A private cache repository is not reachable by that command.

1. Create a repository named `zlyme-cache` under the same owner as this
   tree. The fallback download does not send a token, so the asset has
   to be readable without authentication.
2. Add a classic PAT with `repo` and `workflow` as the Actions secret
   `GH_PAT` on the OS repository. That token uploads the fallback
   archive. Set the Actions variable `CACHE_REPO` when the repository
   is not named `zlyme-cache`.

A cold build is long. A later stage or run uses the Actions cache first.
