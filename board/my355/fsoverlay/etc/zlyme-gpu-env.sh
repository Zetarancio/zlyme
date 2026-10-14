# Sourced by nextui-session, ra-run, and login shells.
# vulkan-loader reads VK_DRIVER_FILES, then the older VK_ICD_FILENAMES.
# libmali ships mali_icd.json. Mesa PanVK ships
# panfrost_icd.cortex-a55.json (the manifest is named for the
# Buildroot CPU, not the ELF machine).
# Each stack exports only its own ICD, so the loader does not try both.
# card0 is rockchip-drm and card1 is the Mali GPU. Forcing
# MESA_LOADER_DRIVER_OVERRIDE=panfrost makes GBM init fail on that
# split. Leave the override unset so Mesa pairs kmsro with Panfrost.
# Mali-G52 is Panfrost arch v7. Mesa 26.1.8 returns
# VK_ERROR_INCOMPATIBLE_DRIVER for that device unless
# PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1. Export that only when the
# saved choice is exactly panfrost. libmali and an unrecognized
# choice unset it, including a value inherited from the parent.
# PPSSPP's VK_KHR_display path does not acquire the DRM display,
# so this export is not a PPSSPP Vulkan result. GLES does not
# read the variable.

gpu=""
if [ -r /storage/.config/zlyme/gpu ]; then
	gpu=$(tr -d ' \t\r\n' < /storage/.config/zlyme/gpu)
fi
[ -n "$gpu" ] || gpu=libmali

panvk_optin=0
case "$gpu" in
	libmali|mali|mali_kbase)
		icd=mali
		;;
	panfrost)
		icd=panfrost
		panvk_optin=1
		;;
	*)
		icd=panfrost
		;;
esac

unset MESA_LOADER_DRIVER_OVERRIDE
if [ "$icd" = mali ]; then
	if [ -r /usr/share/vulkan/icd.d/mali_icd.json ]; then
		export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/mali_icd.json
		export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/mali_icd.json
	else
		unset VK_ICD_FILENAMES
		unset VK_DRIVER_FILES
	fi
elif [ -r /usr/share/vulkan/icd.d/panfrost_icd.cortex-a55.json ]; then
	export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/panfrost_icd.cortex-a55.json
	export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/panfrost_icd.cortex-a55.json
else
	unset VK_ICD_FILENAMES
	unset VK_DRIVER_FILES
fi
if [ "$panvk_optin" = 1 ]; then
	export PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1
else
	unset PAN_I_WANT_A_BROKEN_VULKAN_DRIVER
fi
unset icd panvk_optin
