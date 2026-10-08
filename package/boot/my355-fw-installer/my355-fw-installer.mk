################################################################################
#
# my355-fw-installer
#
# Pinned apommel/baseos-my355 source. mkfwimg.py packs the stock-side
# multiboot installer. pack-fwimg.py packs the recovery and restore
# helpers from that same container format. All three are image artifacts,
# not preloaders and not rootfs files. Only miyoo355_fw.img is placed
# on a fresh card. The other names are release artifacts.
#
################################################################################

MY355_FW_INSTALLER_VERSION = e09d37bb0f03c34e564d61bd02164f332d8515a8
MY355_FW_INSTALLER_SITE = https://github.com/apommel/baseos-my355/archive
MY355_FW_INSTALLER_SOURCE = $(MY355_FW_INSTALLER_VERSION).tar.gz
MY355_FW_INSTALLER_LICENSE = MIT
MY355_FW_INSTALLER_LICENSE_FILES = LICENSE
MY355_FW_INSTALLER_INSTALL_TARGET = NO
MY355_FW_INSTALLER_INSTALL_IMAGES = YES
MY355_FW_INSTALLER_DEPENDENCIES = host-python3

define MY355_FW_INSTALLER_INSTALL_IMAGES_CMDS
	$(HOST_DIR)/bin/python3 \
		$(@D)/tools/preloader-installer/mkfwimg.py \
		$(BINARIES_DIR)/miyoo355_fw.img
	cp -a $(BINARIES_DIR)/miyoo355_fw.img $(BINARIES_DIR)/miyoo355_fw-multiboot.img
	$(HOST_DIR)/bin/python3 \
		$(BR2_EXTERNAL_ZLYME_PATH)/package/boot/my355-fw-installer/zlyme/pack-fwimg.py \
		--apommel $(@D)/tools/preloader-installer \
		--mode maskrom --version zlyme-maskrom-1 \
		$(BINARIES_DIR)/miyoo355_fw-maskrom.img
	$(HOST_DIR)/bin/python3 \
		$(BR2_EXTERNAL_ZLYME_PATH)/package/boot/my355-fw-installer/zlyme/pack-fwimg.py \
		--apommel $(@D)/tools/preloader-installer \
		--mode restore --version zlyme-restore-1 \
		$(BINARIES_DIR)/miyoo355_fw-restore.img
endef

$(eval $(generic-package))
