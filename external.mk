include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

# quartz64 defaults to 2 s. The defconfig patch can lose that line across
# re-extracts; keep 0 in .config. Etcher of zlyme.img writes u-boot.itb;
# OTA does not.
define ZLYME_UBOOT_BOOTDELAY
	$(SED) 's/^CONFIG_BOOTDELAY=.*/CONFIG_BOOTDELAY=0/' $(@D)/.config
	grep -qx 'CONFIG_BOOTDELAY=0' $(@D)/.config || \
		echo 'CONFIG_BOOTDELAY=0' >> $(@D)/.config
endef
UBOOT_POST_CONFIGURE_HOOKS += ZLYME_UBOOT_BOOTDELAY

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
