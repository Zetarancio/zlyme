include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

ZLYME_LINUX_DIR = $(BR2_EXTERNAL_ZLYME_PATH)/board/my355/linux

# Panel driver has no Kconfig symbol. Copy it in and add the Makefile line.
define ZLYME_LINUX_COPY_PANEL
	$(INSTALL) -D -m 0644 $(ZLYME_LINUX_DIR)/sources/panel-generic-dsi.c \
		$(@D)/drivers/gpu/drm/panel/panel-generic-dsi.c
endef
LINUX_PRE_BUILD_HOOKS += ZLYME_LINUX_COPY_PANEL

# Extra dtsi files the kernel patches expect. Not installed as our dtb.
define ZLYME_LINUX_COPY_DTS_OVERRIDES
	$(Q)$(call SYSTEM_RSYNC,$(ZLYME_LINUX_DIR)/dts-overrides,$(@D)/arch/arm64/boot/dts/)
endef
LINUX_PRE_BUILD_HOOKS += ZLYME_LINUX_COPY_DTS_OVERRIDES

define ZLYME_LINUX_INJECT
	grep -q panel-generic-dsi $(@D)/drivers/gpu/drm/panel/Makefile || \
		echo 'obj-y += panel-generic-dsi.o' >> $(@D)/drivers/gpu/drm/panel/Makefile
	grep -q rk3566-miyoo-flip $(@D)/arch/arm64/boot/dts/rockchip/Makefile || \
		echo 'dtb-$$(CONFIG_ARCH_ROCKCHIP) += rk3566-miyoo-flip.dtb' \
			>> $(@D)/arch/arm64/boot/dts/rockchip/Makefile
endef
LINUX_POST_PATCH_HOOKS += ZLYME_LINUX_INJECT

define ZLYME_LINUX_ASSERT_CONFIG
	$(Q)for opt in CONFIG_RD_GZIP=y CONFIG_RD_ZSTD=y \
	               CONFIG_ROCKCHIP_THERMAL=y CONFIG_DRM_PANFROST=m \
	               CONFIG_MODULE_UNLOAD=y CONFIG_SQUASHFS=y \
	               CONFIG_EFI_PARTITION=y CONFIG_MMC_SDHCI_OF_DWCMSHC=y \
	               CONFIG_MMC_DW_ROCKCHIP=y; do \
		grep -qx "$$opt" $(@D)/.config || { \
			echo "zlyme: $$opt did not survive olddefconfig" >&2; exit 1; }; \
	done
	$(Q)! grep -q '@[A-Z_]*@' $(@D)/.config || { \
		echo "zlyme: unsubstituted placeholder in kernel .config" >&2; \
		exit 1; }
endef
LINUX_PRE_BUILD_HOOKS += ZLYME_LINUX_ASSERT_CONFIG

define ZLYME_LINUX_ASSERT_DTB
	$(Q)test -s $(LINUX_ARCH_PATH)/boot/dts/rockchip/rk3566-miyoo-flip.dtb || { \
		echo "zlyme: rk3566-miyoo-flip.dtb was not built" >&2; \
		exit 1; }
endef
LINUX_POST_BUILD_HOOKS += ZLYME_LINUX_ASSERT_DTB

target-post-image: host-exfatprogs

# Panfrost does not need LLVM in the GL client.
MESA3D_CONF_OPTS += -Ddraw-use-llvm=false

# host-clang is wrapped for the target; libclc needs the unwrapped binary.
ZLYME_LIBCLC_UNWRAPPED_CLANG = \
	-DLLVM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real \
	-DLLVM_CUSTOM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real

HOST_LIBCLC_CONF_OPTS += $(ZLYME_LIBCLC_UNWRAPPED_CLANG)

LIBCLC_CONF_OPTS += \
	$(ZLYME_LIBCLC_UNWRAPPED_CLANG) \
	-DLIBCLC_TARGETS_TO_BUILD=spirv64-mesa3d-
