include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

# quartz64 defaults to 2 s and probes PCI, Ethernet, SATA, USB, and the
# eMMC SDHCI host. The Flip boots SD via DW MMC and keeps SPI NAND on SFC.
# olddefconfig can resurrect selected symbols; pin the result here.
# Routine OTA does not write u-boot.itb; `zlyme-update uboot` does.
# Control tree is board/my355/uboot/dts/rk3566-miyoo-flip.dts (not quartz64).
define ZLYME_UBOOT_FLIP_CONFIG
	$(SED) 's/^CONFIG_BOOTDELAY=.*/CONFIG_BOOTDELAY=-2/' $(@D)/.config
	grep -qx 'CONFIG_BOOTDELAY=-2' $(@D)/.config || \
		echo 'CONFIG_BOOTDELAY=-2' >> $(@D)/.config
	grep -qx 'CONFIG_GZIP=y' $(@D)/.config || \
		echo 'CONFIG_GZIP=y' >> $(@D)/.config
	$(SED) 's/^CONFIG_DEFAULT_DEVICE_TREE=.*/CONFIG_DEFAULT_DEVICE_TREE="rk3566-miyoo-flip"/' $(@D)/.config
	grep -qx 'CONFIG_DEFAULT_DEVICE_TREE="rk3566-miyoo-flip"' $(@D)/.config || \
		echo 'CONFIG_DEFAULT_DEVICE_TREE="rk3566-miyoo-flip"' >> $(@D)/.config
	$(SED) 's/^CONFIG_DEFAULT_FDT_FILE=.*/CONFIG_DEFAULT_FDT_FILE="rk3566-miyoo-flip.dtb"/' $(@D)/.config
	$(SED) 's/^CONFIG_OF_UPSTREAM=y/# CONFIG_OF_UPSTREAM is not set/' $(@D)/.config
	grep -qx '# CONFIG_OF_UPSTREAM is not set' $(@D)/.config || \
		echo '# CONFIG_OF_UPSTREAM is not set' >> $(@D)/.config
	$(SED) '/^CONFIG_USE_PREBOOT=/d' $(@D)/.config
	$(SED) '/^CONFIG_PREBOOT=/d' $(@D)/.config
	echo 'CONFIG_USE_PREBOOT=y' >> $(@D)/.config
	echo 'CONFIG_PREBOOT="blkcache configure 32 32; my355 fg"' >> $(@D)/.config
	grep -qx 'CONFIG_BOOTSTAGE=y' $(@D)/.config || \
		echo 'CONFIG_BOOTSTAGE=y' >> $(@D)/.config
	grep -qx 'CONFIG_CMD_MY355=y' $(@D)/.config || \
		echo 'CONFIG_CMD_MY355=y' >> $(@D)/.config
	grep -qx 'CONFIG_CMD_BLOCK_CACHE=y' $(@D)/.config || \
		echo 'CONFIG_CMD_BLOCK_CACHE=y' >> $(@D)/.config
	$(SED) 's/^CONFIG_PCI=y/# CONFIG_PCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_CMD_PCI=y/# CONFIG_CMD_PCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_PCIE_DW_ROCKCHIP=y/# CONFIG_PCIE_DW_ROCKCHIP is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_NVME_PCI=y/# CONFIG_NVME_PCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_AHCI=y/# CONFIG_AHCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_SCSI_AHCI=y/# CONFIG_SCSI_AHCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_AHCI_PCI=y/# CONFIG_AHCI_PCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_SCSI=y/# CONFIG_SCSI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_PHY_MOTORCOMM=y/# CONFIG_PHY_MOTORCOMM is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_DWC_ETH_QOS=y/# CONFIG_DWC_ETH_QOS is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_DWC_ETH_QOS_ROCKCHIP=y/# CONFIG_DWC_ETH_QOS_ROCKCHIP is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_MMC_SDHCI=y/# CONFIG_MMC_SDHCI is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_MMC_SDHCI_SDMA=y/# CONFIG_MMC_SDHCI_SDMA is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_MMC_SDHCI_ROCKCHIP=y/# CONFIG_MMC_SDHCI_ROCKCHIP is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_SUPPORT_EMMC_RPMB=y/# CONFIG_SUPPORT_EMMC_RPMB is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB=y/# CONFIG_USB is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_CMD_USB=y/# CONFIG_CMD_USB is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_XHCI_HCD=y/# CONFIG_USB_XHCI_HCD is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_EHCI_HCD=y/# CONFIG_USB_EHCI_HCD is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_EHCI_GENERIC=y/# CONFIG_USB_EHCI_GENERIC is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_OHCI_HCD=y/# CONFIG_USB_OHCI_HCD is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_OHCI_GENERIC=y/# CONFIG_USB_OHCI_GENERIC is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_DWC3=y/# CONFIG_USB_DWC3 is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_USB_DWC3_GENERIC=y/# CONFIG_USB_DWC3_GENERIC is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_PHY_ROCKCHIP_INNO_USB2=y/# CONFIG_PHY_ROCKCHIP_INNO_USB2 is not set/' $(@D)/.config
	$(SED) 's/^CONFIG_PHY_ROCKCHIP_NANENG_COMBOPHY=y/# CONFIG_PHY_ROCKCHIP_NANENG_COMBOPHY is not set/' $(@D)/.config
	grep -qx 'CONFIG_ROCKCHIP_SFC=y' $(@D)/.config || { \
		echo "zlyme: U-Boot .config lost CONFIG_ROCKCHIP_SFC=y" >&2; exit 1; }
	grep -qx 'CONFIG_DEFAULT_DEVICE_TREE="rk3566-miyoo-flip"' $(@D)/.config || { \
		echo "zlyme: U-Boot .config lost Flip control tree" >&2; exit 1; }
	if grep -q '^CONFIG_OF_UPSTREAM=y' $(@D)/.config; then \
		echo "zlyme: CONFIG_OF_UPSTREAM came back; Flip DTS is local" >&2; exit 1; \
	fi
endef
UBOOT_POST_CONFIGURE_HOOKS += ZLYME_UBOOT_FLIP_CONFIG

ZLYME_UBOOT_DTS = $(BR2_EXTERNAL_ZLYME_PATH)/board/my355/uboot/dts

# Copied every build so a DTS edit is picked up without uboot-dirclean.
define ZLYME_UBOOT_COPY_DTS
	$(INSTALL) -D -m 0644 $(ZLYME_UBOOT_DTS)/rk3566-miyoo-flip.dts \
		$(@D)/arch/arm/dts/rk3566-miyoo-flip.dts
	$(INSTALL) -D -m 0644 $(ZLYME_UBOOT_DTS)/rk3566-miyoo-flip-u-boot.dtsi \
		$(@D)/arch/arm/dts/rk3566-miyoo-flip-u-boot.dtsi
endef
UBOOT_PRE_BUILD_HOOKS += ZLYME_UBOOT_COPY_DTS

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
	               CONFIG_VFAT_FS=y CONFIG_BLK_DEV_LOOP=y \
	               CONFIG_EFI_PARTITION=y CONFIG_MMC_SDHCI_OF_DWCMSHC=y \
	               CONFIG_MMC_DW_ROCKCHIP=y \
	               CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER=y; do \
		grep -qx "$$opt" $(@D)/.config || { \
			echo "zlyme: $$opt did not survive olddefconfig" >&2; exit 1; }; \
	done
	$(Q)! grep -q '@[A-Z_]*@' $(@D)/.config || { \
		echo "zlyme: unsubstituted placeholder in kernel .config" >&2; \
		exit 1; }
endef
LINUX_PRE_BUILD_HOOKS += ZLYME_LINUX_ASSERT_CONFIG

ifeq ($(BR2_PACKAGE_ZLYME_INITRAMFS),y)
# linux/linux.mk $(eval)s before this file; LINUX_DEPENDENCIES += is ignored.
$(LINUX_DIR)/.stamp_built: $(ZLYME_INITRAMFS_DIR)/.stamp_target_installed
define ZLYME_LINUX_SET_INITRAMFS
	$(Q)if [ ! -x $(BINARIES_DIR)/initramfs/init ]; then \
		rm -f $(ZLYME_INITRAMFS_DIR)/.stamp_target_installed; \
		$(MAKE) zlyme-initramfs; \
	fi
	$(Q)test -x $(BINARIES_DIR)/initramfs/init || { \
		echo "zlyme: initramfs is missing (BR2_PACKAGE_ZLYME_INITRAMFS)" >&2; \
		exit 1; }
	$(Q)sed -i 's|^CONFIG_INITRAMFS_SOURCE=.*|CONFIG_INITRAMFS_SOURCE="$(BINARIES_DIR)/initramfs"|' \
		$(@D)/.config
	$(Q)grep -qF 'CONFIG_INITRAMFS_SOURCE="$(BINARIES_DIR)/initramfs"' $(@D)/.config || { \
		echo "zlyme: failed to set CONFIG_INITRAMFS_SOURCE" >&2; exit 1; }
endef
LINUX_PRE_BUILD_HOOKS += ZLYME_LINUX_SET_INITRAMFS
endif

define ZLYME_LINUX_ASSERT_DTB
	$(Q)test -s $(LINUX_ARCH_PATH)/boot/dts/rockchip/rk3566-miyoo-flip.dtb || { \
		echo "zlyme: rk3566-miyoo-flip.dtb was not built" >&2; \
		exit 1; }
endef
LINUX_POST_BUILD_HOOKS += ZLYME_LINUX_ASSERT_DTB

target-post-image: host-exfatprogs

# Panfrost does not need LLVM in the GL client.
MESA3D_CONF_OPTS += -Ddraw-use-llvm=false

# mkxp-z's meson wrap leaked SDL3 into staging; fluidsynth then linked it
# and the image had no libSDL3.so.0. EasyRPG/mkxp MIDI does not need SDL
# audio — ALSA is enough.
FLUIDSYNTH_CONF_OPTS += -Denable-sdl3=OFF -Denable-sdl2=OFF

# host-clang is wrapped for the target; libclc needs the unwrapped binary.
ZLYME_LIBCLC_UNWRAPPED_CLANG = \
	-DLLVM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real \
	-DLLVM_CUSTOM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real

HOST_LIBCLC_CONF_OPTS += $(ZLYME_LIBCLC_UNWRAPPED_CLANG)

LIBCLC_CONF_OPTS += \
	$(ZLYME_LIBCLC_UNWRAPPED_CLANG) \
	-DLIBCLC_TARGETS_TO_BUILD=spirv64-mesa3d-

# Host compileall can write a 3.14 sysconfigdata .pyc the target refuses
# (loguru → ValueError: bad marshal data). Keep the .py and drop that pyc.
ifeq ($(BR2_PACKAGE_PYTHON3),y)
define ZLYME_PYTHON3_FIX_SYSCONFIG
	py="$(PYTHON3_DIR)/build/lib.linux-aarch64-$(PYTHON3_VERSION_MAJOR)/_sysconfigdata__linux_aarch64-linux-gnu.py"; \
	dst="$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)"; \
	if [ -f "$$py" ]; then \
		$(INSTALL) -D -m 0644 "$$py" "$$dst/_sysconfigdata__linux_aarch64-linux-gnu.py"; \
	fi; \
	rm -f "$$dst/_sysconfigdata__linux_aarch64-linux-gnu.pyc"; \
	rm -f "$$dst/__pycache__"/_sysconfigdata*.pyc
endef
TARGET_FINALIZE_HOOKS += ZLYME_PYTHON3_FIX_SYSCONFIG
endif
