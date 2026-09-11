#!/usr/bin/env bash
#
# Zlyme build driver. Paths come from the environment (see storage.sh.example).
#
#   ZLYME_BUILDROOT   Buildroot source          (default ./buildroot)
#   ZLYME_OUTPUT      build tree and images     (default ./output)
#   ZLYME_DL          download cache            (default ./dl)
#   ZLYME_CCACHE      compiler cache             (default ./.ccache)
#   ZLYME_DEFCONFIG   defconfig name            (default zlyme_minimal_defconfig)

set -euo pipefail

readonly REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pin to a February LTS release, not master.
readonly BUILDROOT_VERSION="2026.02.3"
readonly BUILDROOT_URL="https://gitlab.com/buildroot.org/buildroot.git"

readonly IMAGE="zlyme-build"

ZLYME_BUILDROOT="${ZLYME_BUILDROOT:-${REPO}/buildroot}"
ZLYME_OUTPUT="${ZLYME_OUTPUT:-${REPO}/output}"
ZLYME_DL="${ZLYME_DL:-${REPO}/dl}"
ZLYME_CCACHE="${ZLYME_CCACHE:-${REPO}/.ccache}"
# The only defconfig names that exist. Default is the bring-up image.
ZLYME_DEFCONFIG="${ZLYME_DEFCONFIG:-zlyme_minimal_defconfig}"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
usage: build.sh [options] [make-target ...]

  --minimal        build zlyme_minimal_defconfig (bootable, no emulators)
  --config NAME    build a named defconfig
  --shell          interactive shell in the build container
  --check          report where everything is and change nothing
  --loops          detach loop devices this build leaked
  --clean          delete the build tree (keeps downloads and ccache)
  --rebuild-image  rebuild the container even if it exists
  -h, --help       this

With no make-target, builds the image. Any make target is passed through, so
`build.sh menuconfig`, `build.sh linux-rebuild` and `build.sh savedefconfig`
all work.

A full image build writes output/build.log (overwritten each run). Watch it
with `less +F output/build.log`.
EOF
}

# Safety: never write a real disk. Image assembly uses loop devices.
assert_no_raw_device_writes() {
    local hits
    hits="$(grep -rInE \
        '(dd[[:space:]]+[^|;]*of=|mkfs[.a-z]*[[:space:]]|parted[[:space:]]|sgdisk[[:space:]]|wipefs[[:space:]])[^|;]*/dev/(sd[a-z]|mmcblk[0-9]|nvme[0-9]|vd[a-z])' \
        "${REPO}/board" "${REPO}/package" "${REPO}/scripts" "${REPO}"/*.sh 2>/dev/null || true)"
    [ -z "${hits}" ] || die "refusing to start: something writes to a real disk

${hits}"
}

# Detach loop devices this build leaked (filename match, not host path).
sweep_loops() {
    local dev back found=0
    while read -r dev back; do
        [ -n "${dev}" ] || continue
        case "${back}" in
            "${ZLYME_OUTPUT}"/*|/zlyme/output/*|*/zlyme-*.img)
                say "detaching ${dev} (${back})"
                losetup -d "${dev}" 2>/dev/null || sudo losetup -d "${dev}"
                found=1
                ;;
        esac
    done < <(losetup -ln -O NAME,BACK-FILE 2>/dev/null || true)
    [ "${found}" = 1 ] || say "no leaked loop devices"
}

fetch_buildroot() {
    if [ ! -d "${ZLYME_BUILDROOT}/.git" ]; then
        say "cloning Buildroot ${BUILDROOT_VERSION}"
        git clone --depth 1 --branch "${BUILDROOT_VERSION}" \
            "${BUILDROOT_URL}" "${ZLYME_BUILDROOT}"
        return
    fi
    local have
    have="$(git -C "${ZLYME_BUILDROOT}" describe --tags --exact-match 2>/dev/null || echo none)"
    if [ "${have}" != "${BUILDROOT_VERSION}" ]; then
        say "moving Buildroot ${have} -> ${BUILDROOT_VERSION}"
        git -C "${ZLYME_BUILDROOT}" fetch --depth 1 origin "refs/tags/${BUILDROOT_VERSION}:refs/tags/${BUILDROOT_VERSION}"
        git -C "${ZLYME_BUILDROOT}" checkout -q "${BUILDROOT_VERSION}"
    fi
}

build_container() {
    if [ "${REBUILD_IMAGE}" != 1 ] && docker image inspect "${IMAGE}" >/dev/null 2>&1; then
        return
    fi
    say "building the ${IMAGE} container"
    # Fed on stdin deliberately: with a directory context and no COPY, docker
    # would ship the whole repo to the daemon before doing anything.
    docker build -t "${IMAGE}" - < "${REPO}/Dockerfile"
}

# Host gcc is still --prefix=/flip/output/host, so the same output tree is
# also mounted at /flip/output. Do not byte-replace those paths in ELFs.
in_container() {
    docker run --rm -i ${TTY_FLAG} \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e BR2_DL_DIR=/zlyme/dl \
        -e BR2_CCACHE_DIR=/zlyme/ccache \
        -v "${REPO}:/zlyme/src:ro" \
        -v "${ZLYME_BUILDROOT}:/zlyme/buildroot" \
        -v "${ZLYME_OUTPUT}:/zlyme/output" \
        -v "${ZLYME_OUTPUT}:/flip/output" \
        -v "${ZLYME_DL}:/zlyme/dl" \
        -v "${ZLYME_CCACHE}:/zlyme/ccache" \
        -w /zlyme/buildroot \
        "${IMAGE}" "$@"
}

# Full builds (and non-menuconfig make targets) also land in output/build.log
# so they can be watched with `less +F` while the container is running.
# docker -t is dropped here because a pipe would steal the tty anyway.
logged_make() {
    local log="${ZLYME_OUTPUT}/build.log"
    say "logging to ${log}"
    TTY_FLAG="" in_container "${MAKE[@]}" "$@" 2>&1 | tee -a "${log}"
}

report() {
    printf '%-16s %s\n' \
        "repo"      "${REPO}" \
        "buildroot" "${ZLYME_BUILDROOT}  (${BUILDROOT_VERSION})" \
        "output"    "${ZLYME_OUTPUT}" \
        "downloads" "${ZLYME_DL}" \
        "ccache"    "${ZLYME_CCACHE}" \
        "defconfig" "${ZLYME_DEFCONFIG}"
    echo
    local p
    for p in "${ZLYME_BUILDROOT}" "${ZLYME_OUTPUT}" "${ZLYME_DL}" "${ZLYME_CCACHE}"; do
        printf '%-10s %s\n' "$([ -d "${p}" ] && du -sh "${p}" 2>/dev/null | cut -f1 || echo '-')" "${p}"
    done
}

# ---------------------------------------------------------------------------

REBUILD_IMAGE=0
ACTION=build
declare -a MAKE_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --minimal)       ZLYME_DEFCONFIG=zlyme_minimal_defconfig ;;
        --config)        ZLYME_DEFCONFIG="${2:?--config needs a name}"; shift ;;
        --shell)         ACTION=shell ;;
        --check)         ACTION=check ;;
        --loops)         ACTION=loops ;;
        --clean)         ACTION=clean ;;
        --rebuild-image) REBUILD_IMAGE=1 ;;
        -h|--help)       usage; exit 0 ;;
        -*)              die "unknown option $1" ;;
        *)               MAKE_ARGS+=("$1") ;;
    esac
    shift
done

TTY_FLAG=""
[ -t 0 ] && TTY_FLAG="-t"

case "${ACTION}" in
    check) report; exit 0 ;;
    loops) sweep_loops; exit 0 ;;
    clean)
        say "deleting ${ZLYME_OUTPUT} (downloads and ccache kept)"
        rm -rf "${ZLYME_OUTPUT:?}"/*
        exit 0
        ;;
esac

assert_no_raw_device_writes
mkdir -p "${ZLYME_OUTPUT}" "${ZLYME_DL}" "${ZLYME_CCACHE}"
fetch_buildroot
build_container

if [ "${ACTION}" = shell ]; then
    exec in_container bash
fi

# Buildroot keeps output out of the source tree with O=.
declare -a MAKE=(make "O=/zlyme/output" "BR2_EXTERNAL=/zlyme/src")

# Reapply the defconfig when it is newer than .config, or when there is none.
CONFIG_SRC="${REPO}/configs/${ZLYME_DEFCONFIG}"

# A missing defconfig is a typo, not a licence to reuse the last .config.
if [ ! -f "${CONFIG_SRC}" ]; then
    die "there is no configs/${ZLYME_DEFCONFIG}

available:
$(cd "${REPO}/configs" && printf '  %s\n' *)

Pass --minimal, or --config <name>."
fi

LOG_STARTED=0
start_build_log() {
    if [ "${LOG_STARTED}" = 0 ]; then
        : > "${ZLYME_OUTPUT}/build.log"
        LOG_STARTED=1
    fi
}

if [ ! -f "${ZLYME_OUTPUT}/.config" ]; then
    say "configuring ${ZLYME_DEFCONFIG}"
    start_build_log
    logged_make "${ZLYME_DEFCONFIG}"
elif [ -f "${CONFIG_SRC}" ] && [ "${CONFIG_SRC}" -nt "${ZLYME_OUTPUT}/.config" ]; then
    say "${ZLYME_DEFCONFIG} changed -- reconfiguring"
    start_build_log
    logged_make "${ZLYME_DEFCONFIG}"
fi

# Every =y in the defconfig must survive kconfig. Buildroot drops unmet
# deps silently. Skip this for explicit make targets (menuconfig).
assert_defconfig_survived() {
    [ -f "${CONFIG_SRC}" ] && [ -f "${ZLYME_OUTPUT}/.config" ] || return 0

    local opt missing=""
    while read -r opt; do
        grep -qx "${opt}=y" "${ZLYME_OUTPUT}/.config" || missing="${missing}  ${opt}
"
    done < <(sed -n 's/^\(BR2_[A-Z0-9_]*\)=y$/\1/p' "${CONFIG_SRC}")

    [ -z "${missing}" ] || die "these ${ZLYME_DEFCONFIG} options did not survive kconfig
${missing}
Each was dropped because a dependency is unmet. Run 'build.sh menuconfig' and
search for one with '/' to see what it needs."
}

if [ ${#MAKE_ARGS[@]} -eq 0 ]; then
    assert_defconfig_survived
    say "building ${ZLYME_DEFCONFIG}"
    start_build_log
    logged_make
    say "images in ${ZLYME_OUTPUT}/images"
else
    case "${MAKE_ARGS[0]}" in
        *config)
            in_container "${MAKE[@]}" "${MAKE_ARGS[@]}"
            ;;
        *)
            start_build_log
            logged_make "${MAKE_ARGS[@]}"
            ;;
    esac
fi
