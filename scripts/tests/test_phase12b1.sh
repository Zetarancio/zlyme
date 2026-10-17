#!/bin/sh
# shellcheck disable=SC1007
# Phase 12B1 host contract: Buildroot pin, PanVK only on the product
# defconfig, and one Vulkan ICD per GPU stack. Nothing here is installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "phase12b1: $*" >&2
	exit 1
}

grep -q '^readonly BUILDROOT_VERSION="2026.08"$' "$ROOT/build.sh" \
	|| fail "build.sh is not pinned to 2026.08"

prod=$ROOT/configs/zlyme_my355_defconfig
mini=$ROOT/configs/zlyme_my355_minimal_defconfig
grep -qx 'BR2_PACKAGE_MESA3D_VULKAN_DRIVER_PANFROST=y' "$prod" \
	|| fail "product defconfig has no PanVK"
grep -qx 'BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_PANFROST=y' "$prod" \
	|| fail "product defconfig has no Panfrost GLES"
grep -qx 'BR2_PACKAGE_MESA3D_VULKAN_DRIVER_PANFROST=y' "$mini" \
	&& fail "minimal defconfig selects PanVK"
grep -qx 'BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_PANFROST=y' "$mini" \
	|| fail "minimal defconfig has no Panfrost GLES"
grep -qx 'BR2_PACKAGE_VULKAN_LOADER=y' "$prod" || fail "product has no Vulkan loader"
grep -qx 'BR2_PACKAGE_VULKAN_LOADER=y' "$mini" && fail "minimal selects the Vulkan loader"

grep -q -- '-Ddraw-use-llvm=false' "$ROOT/external.mk" \
	|| fail "draw-use-llvm override missing"
grep -q 'enable-sdl2' "$ROOT/external.mk" && fail "obsolete fluidsynth sdl2 override"
grep -q 'clang.br_real' "$ROOT/external.mk" || fail "libclc unwrapped clang override missing"

env_src=$ROOT/board/my355/fsoverlay/etc/zlyme-gpu-env.sh
grep -q 'PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1' "$env_src" \
	|| fail "gpu env does not record the Mali-G52 opt-in"
grep -q '^[[:space:]]*export PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1' "$env_src" \
	|| fail "gpu env does not export the broken-driver flag"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sed "s|/usr/share/vulkan/icd.d|$work/icd|g; s|/storage/.config/zlyme/gpu|$work/gpu|g" \
	"$env_src" > "$work/env.sh"
mkdir -p "$work/icd"
printf '%s\n' '{"file_format_version":"1.0.0","ICD":{"library_path":"libmali"}}' \
	> "$work/icd/mali_icd.json"
printf '%s\n' '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_panfrost.so"}}' \
	> "$work/icd/panfrost_icd.cortex-a55.json"

read_icd() {
	# shellcheck disable=SC2016
	env -u VK_ICD_FILENAMES -u VK_DRIVER_FILES -u PAN_I_WANT_A_BROKEN_VULKAN_DRIVER \
		sh -c '. "$1"
			printf "%s\n" "${VK_ICD_FILENAMES-}" "${VK_DRIVER_FILES-}" "${PAN_I_WANT_A_BROKEN_VULKAN_DRIVER-}"' \
		sh "$work/env.sh"
}

rm -f "$work/gpu"
got=$(read_icd)
line1=$(printf '%s\n' "$got" | sed -n '1p')
line2=$(printf '%s\n' "$got" | sed -n '2p')
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ "$line1" = "$work/icd/mali_icd.json" ] || fail "default ICD is '$line1'"
[ "$line2" = "$work/icd/mali_icd.json" ] || fail "default driver files is '$line2'"
[ -z "$line3" ] || fail "default set the broken-driver flag"

printf '%s' panfrost > "$work/gpu"
got=$(read_icd)
line1=$(printf '%s\n' "$got" | sed -n '1p')
line2=$(printf '%s\n' "$got" | sed -n '2p')
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ "$line1" = "$work/icd/panfrost_icd.cortex-a55.json" ] || fail "panfrost ICD is '$line1'"
[ "$line2" = "$work/icd/panfrost_icd.cortex-a55.json" ] || fail "panfrost driver files is '$line2'"
[ -z "$line3" ] || fail "panfrost GLES opted into PanVK: '$line3'"
printf '%s\n' "$got" | grep -q mali_icd && fail "panfrost selected the Mali ICD"

printf '%s' panvk > "$work/gpu"
got=$(read_icd)
line1=$(printf '%s\n' "$got" | sed -n '1p')
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ "$line1" = "$work/icd/panfrost_icd.cortex-a55.json" ] || fail "panvk ICD is '$line1'"
[ "$line3" = 1 ] || fail "panvk opt-in is '$line3'"

for name in libmali mali mali_kbase; do
	printf '%s' "$name" > "$work/gpu"
	got=$(read_icd)
	line1=$(printf '%s\n' "$got" | sed -n '1p')
	line3=$(printf '%s\n' "$got" | sed -n '3p')
	[ "$line1" = "$work/icd/mali_icd.json" ] || fail "$name ICD is '$line1'"
	[ -z "$line3" ] || fail "$name set the broken-driver flag"
	printf '%s\n' "$got" | grep -q panfrost_icd && fail "$name selected PanVK"
done

printf '%s' something-else > "$work/gpu"
got=$(read_icd)
line1=$(printf '%s\n' "$got" | sed -n '1p')
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ "$line1" = "$work/icd/panfrost_icd.cortex-a55.json" ] || fail "unknown ICD is '$line1'"
[ -z "$line3" ] || fail "unknown GPU opted into PanVK"

# An inherited opt-in must not survive a Mali or unknown selection.
# shellcheck disable=SC2016
read_inherited() {
	env -u VK_ICD_FILENAMES -u VK_DRIVER_FILES \
		PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1 \
		sh -c '. "$1"
			printf "%s\n" "${VK_ICD_FILENAMES-}" "${PAN_I_WANT_A_BROKEN_VULKAN_DRIVER-}"' \
		sh "$work/env.sh"
}
printf '%s' libmali > "$work/gpu"
got=$(read_inherited)
line2=$(printf '%s\n' "$got" | sed -n '2p')
[ -z "$line2" ] || fail "libmali kept an inherited opt-in"
printf '%s' something-else > "$work/gpu"
got=$(read_inherited)
line2=$(printf '%s\n' "$got" | sed -n '2p')
[ -z "$line2" ] || fail "unknown GPU kept an inherited opt-in"

rm -f "$work/icd/panfrost_icd.cortex-a55.json"
printf '%s' panfrost > "$work/gpu"
got=$(read_icd)
line1=$(printf '%s\n' "$got" | sed -n '1p')
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ -z "$line1" ] || fail "missing PanVK ICD still exported '$line1'"
[ -z "$line3" ] || fail "panfrost GLES set the opt-in without an ICD"
printf '%s' panvk > "$work/gpu"
got=$(read_icd)
line3=$(printf '%s\n' "$got" | sed -n '3p')
[ "$line3" = 1 ] || fail "explicit panvk dropped the opt-in"

echo "phase12b1 ok"
