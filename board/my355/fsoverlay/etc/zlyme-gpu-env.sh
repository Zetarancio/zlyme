# Sourced by nextui-session, ra-run, and login shells.
# vulkan-loader reads VK_ICD_FILENAMES. libmali ships mali_icd.json.
# Buildroot 2026.02 mesa3d has no PanVK option; panfrost stays GLES.
# MESA_LOADER_DRIVER_OVERRIDE is the ROCKNIX panfrost hint; unset on libmali.

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
		export MESA_LOADER_DRIVER_OVERRIDE=panfrost
		unset VK_ICD_FILENAMES
		for f in /usr/share/vulkan/icd.d/panfrost_icd*.json \
			 /usr/share/vulkan/icd.d/panvk_icd*.json; do
			if [ -r "$f" ]; then
				export VK_ICD_FILENAMES="$f"
				break
			fi
		done
		;;
esac
