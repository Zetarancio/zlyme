#!/bin/sh
# Release notes come from one changelog entry, not from git history.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/scripts/changelog-release-notes.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
	echo "changelog release notes: $*" >&2
	exit 1
}

notes() {
	python3 "$BIN" --changelog "$1" --version "$2"
}

cat > "$work/log.md" << 'EOF'
# Changelog

Engineering history stays in ROADMAP and LOGBOOK.

## [Unreleased]

Unreleased work is zlyme50.1 and is not a release.

## [zlyme44.2] - 2026-10-11

Point release notes.

- keeps `markdown`
- second item

## [zlyme44] - 2026-10-04

Baseline notes.

### Added

- first stable item

## [zlyme44.10] - 2026-11-01

Later point.

[Unreleased]: https://example.invalid/compare/old...HEAD
[zlyme44]: https://example.invalid/releases/tag/zlyme44
EOF

point=$(notes "$work/log.md" zlyme44.2)
printf '%s\n' "$point" | head -n 1 | grep -Fx '## [zlyme44.2] - 2026-10-11' >/dev/null \
	|| fail "point heading was rewritten"
# shellcheck disable=SC2016
printf '%s\n' "$point" | grep -Fx -- '- keeps `markdown`' >/dev/null \
	|| fail "markdown list item was dropped"
printf '%s\n' "$point" | grep -q 'Baseline notes' && fail "point notes included the baseline"
printf '%s\n' "$point" | grep -q 'Unreleased work' && fail "point notes included Unreleased"
printf '%s\n' "$point" | grep -q 'ROADMAP' && fail "point notes included the preamble"
printf '%s\n' "$point" | grep -q 'LOGBOOK' && fail "point notes included the preamble"
printf '%s\n' "$point" | grep -q 'example.invalid' && fail "point notes included the footer"

base=$(notes "$work/log.md" zlyme44)
printf '%s\n' "$base" | head -n 1 | grep -Fx '## [zlyme44] - 2026-10-04' >/dev/null \
	|| fail "baseline heading mismatch"
printf '%s\n' "$base" | grep -q 'first stable item' || fail "baseline body missing"
printf '%s\n' "$base" | grep -q 'Point release' && fail "baseline included the point release"
printf '%s\n' "$base" | grep -q 'Later point' && fail "baseline included a later version"
printf '%s\n' "$base" | grep -q 'example.invalid' && fail "baseline included the footer"

later=$(notes "$work/log.md" zlyme44.10)
printf '%s\n' "$later" | grep -qx 'Later point.' || fail "later point body mismatch"
printf '%s\n' "$later" | grep -q 'example.invalid' && fail "later point included the footer"

if notes "$work/log.md" zlyme44.1 >"$work/out" 2>"$work/err"; then
	fail "missing version succeeded"
fi
test ! -s "$work/out"
grep -q 'no changelog entry' "$work/err"

printf '%s\n%s\n' '## [zlyme45] - 2026-12-01' '' > "$work/empty.md"
if notes "$work/empty.md" zlyme45 >"$work/out" 2>"$work/err"; then
	fail "empty entry succeeded"
fi
grep -q 'empty' "$work/err"

printf '%s\n' zlyme44.2 > "$work/version"
got=$(python3 "$BIN" --changelog "$work/log.md" --version-file "$work/version")
test "$got" = "$point"

if notes "$work/log.md" Unreleased >"$work/out" 2>"$work/err"; then
	fail "Unreleased was accepted as a version"
fi
if notes "$work/log.md" zlyme44.2.1 >"$work/out" 2>"$work/err"; then
	fail "three-part version was accepted"
fi

# The published baseline in this tree. zlyme44.2 stays Unreleased here.
real=$(notes "$ROOT/CHANGELOG.md" zlyme44)
printf '%s\n' "$real" | grep -q 'The first stable release' \
	|| fail "real zlyme44 entry was not selected"
printf '%s\n' "$real" | grep -q 'Known limitations' \
	|| fail "real zlyme44 entry dropped a section"
printf '%s\n' "$real" | grep -q 'Unreleased work is' \
	&& fail "real notes included Unreleased"
printf '%s\n' "$real" | grep -q 'ROADMAP' && fail "real notes included ROADMAP"
printf '%s\n' "$real" | grep -q 'compare/zlyme-' \
	&& fail "real notes included the compare footer"
if notes "$ROOT/CHANGELOG.md" zlyme44.2 >"$work/out" 2>"$work/err"; then
	fail "unpublished zlyme44.2 was extracted from Unreleased"
fi

echo "changelog release notes ok"
