# zlyme-cache

GitHub Actions does not use `actions/cache` for the compiler cache. Same
pattern as ROCKNIX `distribution-cache`: a second repo whose only job is a
prerelease named `ccache`.

1. Create a repo named `zlyme-cache` (private is fine) under the same owner
   as this tree.
2. Add a classic PAT with `repo` + `workflow` as the Actions secret `GH_PAT`
   on the OS repo. The workflow uploads `ccache-my355.tar` to
   `OWNER/zlyme-cache` tag `ccache`.
3. Optional Actions variable `CACHE_REPO` if the cache repo is not named
   `zlyme-cache`.

First cold build is long. Later runs restore the tar with curl.
