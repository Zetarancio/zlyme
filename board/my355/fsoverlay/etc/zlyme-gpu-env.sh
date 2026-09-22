# Sourced by nextui-session, ra-run, and login shells.
# vulkan-loader reads VK_ICD_FILENAMES. libmali ships mali_icd.json.
# Buildroot 2026.02 mesa3d has no PanVK option; panfrost stays GLES.
# card0 is rockchip-drm and card1 is the Mali GPU. Forcing
# MESA_LOADER_DRIVER_OVERRIDE=panfrost makes GBM init fail on that
# split. Leave the override unset so Mesa pairs kmsro with Panfrost.

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
		fi
		;;
	*)
		unset MESA_LOADER_DRIVER_OVERRIDE
		unset VK_ICD_FILENAMES
		;;
esac
