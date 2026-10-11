# Sourced by nextui-session, ra-run, and login shells.
# vulkan-loader reads VK_DRIVER_FILES, then the older VK_ICD_FILENAMES.
# libmali ships mali_icd.json. Mesa PanVK ships panfrost_icd.aarch64.json.
# Each stack exports only its own ICD, so the loader does not try both.
# card0 is rockchip-drm and card1 is the Mali GPU. Forcing
# MESA_LOADER_DRIVER_OVERRIDE=panfrost makes GBM init fail on that
# split. Leave the override unset so Mesa pairs kmsro with Panfrost.
# Mali-G52 is Panfrost arch v7. Mesa 26.1.8 returns
# VK_ERROR_INCOMPATIBLE_DRIVER for that device unless
# PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1. This file does not set it.
# GLES does not read either variable.

gpu=""
if [ -r /storage/.config/zlyme/gpu ]; then
	gpu=$(tr -d ' \t\r\n' < /storage/.config/zlyme/gpu)
fi
[ -n "$gpu" ] || gpu=libmali

case "$gpu" in
	libmali|mali|mali_kbase)
		unset MESA_LOADER_DRIVER_OVERRIDE
		if [ -r /usr/share/vulkan/icd.d/mali_icd.json ]; then
			export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/mali_icd.json
			export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/mali_icd.json
		else
			unset VK_ICD_FILENAMES
			unset VK_DRIVER_FILES
		fi
		;;
	*)
		unset MESA_LOADER_DRIVER_OVERRIDE
		if [ -r /usr/share/vulkan/icd.d/panfrost_icd.aarch64.json ]; then
			export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/panfrost_icd.aarch64.json
			export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/panfrost_icd.aarch64.json
		else
			unset VK_ICD_FILENAMES
			unset VK_DRIVER_FILES
		fi
		;;
esac
