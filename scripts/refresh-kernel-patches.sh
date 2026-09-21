#!/usr/bin/env bash
#
# Refresh kernel patch context so Buildroot's apply-patches (-F0) accepts
# them. GNU patch allows fuzz; Buildroot does not. Only the diff below the
# first `diff --git` line is regenerated. Patches that already apply are left
# alone. Copy new patches in, then run this.

set -euo pipefail

readonly REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

DEFCONFIG_NAME="${ZLYME_DEFCONFIG:-zlyme_my355_minimal_defconfig}"
TARBALL_ARG=""
while [ $# -gt 0 ]; do
	case "$1" in
		--config)
			DEFCONFIG_NAME="${2:?--config needs a defconfig name}"
			shift 2
			;;
		-*)
			die "unknown option $1"
			;;
		*)
			TARBALL_ARG="$1"
			shift
			;;
	esac
done

readonly DEFCONFIG="${REPO}/configs/${DEFCONFIG_NAME}"
[ -f "${DEFCONFIG}" ] || die "no configs/${DEFCONFIG_NAME}"

# Take the patch directories, in order, from the defconfig rather than listing
# them here. The order is load-bearing -- later patches build on earlier ones --
# and a second copy of it in this file is a second thing to forget to update.
# Keep directories that actually contain kernel patches. U-Boot patch dirs
# in the same BR2_GLOBAL_PATCH_DIR line are skipped.
readonly TARBALL="${TARBALL_ARG:-$(echo "${REPO}"/dl/linux/linux-*.tar.xz)}"
[ -f "${TARBALL}" ] || die "no kernel tarball: ${TARBALL}
run ./build.sh --minimal source first, or pass one as \$1"

mapfile -t PATCH_DIRS < <(
	sed -n 's/^BR2_GLOBAL_PATCH_DIR="\(.*\)"$/\1/p' "${DEFCONFIG}" |
		tr ' ' '\n' |
		sed "s|\$(BR2_EXTERNAL_ZLYME_PATH)|${REPO}|" |
		while IFS= read -r d; do
			[ -n "${d}" ] || continue
			compgen -G "${d}/linux/"*.patch >/dev/null && printf '%s\n' "${d}"
		done
)
[ "${#PATCH_DIRS[@]}" -gt 0 ] ||
	die "found no kernel patch directories in ${DEFCONFIG#"${REPO}"/}"

readonly WORK="${REPO}/output/patch-refresh"
trap 'rm -rf "${WORK}"' EXIT
rm -rf "${WORK}"
mkdir -p "${WORK}/tree"

say "extracting $(basename "${TARBALL}")"
tar --strip-components=1 -C "${WORK}/tree" -xf "${TARBALL}"

cd "${WORK}/tree"

# A throwaway repository is the whole trick: it is what lets us ask "what did
# that patch actually do to this tree" and get a diff with correct context back.
# -c so nothing here depends on the caller's git config.
git=(git -c user.name=zlyme -c user.email=zlyme@localhost
     -c commit.gpgsign=false -c core.autocrlf=false)

say "snapshotting the pristine tree"
"${git[@]}" init -q .
# -f because the kernel ships .gitignore files that would otherwise swallow
# some of the files these patches add.
"${git[@]}" add -Af .
"${git[@]}" commit -qm pristine

declare -a refreshed=() untouched=()

for dir in "${PATCH_DIRS[@]}"; do
	for patch in "${dir}"/linux/*.patch; do
		[ -f "${patch}" ] || continue
		rel="$(basename "$(dirname "$(dirname "${patch}")")")/$(basename "${patch}")"

		common=(-g0 -p1 --no-backup-if-mismatch -t -N)

		# Exactly Buildroot's invocation. If it is happy, we are.
		if patch -F0 "${common[@]}" -s --dry-run <"${patch}" >/dev/null 2>&1; then
			patch -F0 "${common[@]}" -s <"${patch}" >/dev/null
			untouched+=("${rel}")
		elif patch "${common[@]}" -s --dry-run <"${patch}" >/dev/null 2>&1; then
			patch "${common[@]}" -s <"${patch}" >/dev/null

			# patch leaves these behind on a partial hunk; they are not
			# ours and must not reach the regenerated diff.
			find . -name '*.orig' -o -name '*.rej' -delete

			"${git[@]}" add -Af .
			if "${git[@]}" diff --cached | grep -q '^GIT binary patch'; then
				die "${rel} touches a binary file; refusing to regenerate it
regenerating would need git apply rather than a unified diff"
			fi

			{
				# Everything above the diff, byte for byte.
				sed '/^diff --git /,$d' "${patch}"
				"${git[@]}" diff --cached
			} >"${WORK}/regenerated"
			mv "${WORK}/regenerated" "${patch}"
			refreshed+=("${rel}")
		else
			die "${rel} does not apply to this kernel even with fuzz.
This is not the problem the script solves -- the patch is wrong for this
version, or an earlier one in the sequence changed what it expected."
		fi

		"${git[@]}" add -Af .
		"${git[@]}" commit -qm "${rel}"
	done
done

echo
say "${#untouched[@]} patches already applied with -F0 and were not touched"
say "${#refreshed[@]} refreshed:"
printf '      %s\n' "${refreshed[@]}"
echo
say "now re-run the build; git diff will show only context lines changed"
