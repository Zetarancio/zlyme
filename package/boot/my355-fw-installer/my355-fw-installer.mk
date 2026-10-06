################################################################################
#
# my355-fw-installer
#
# Pinned apommel/baseos-my355 source. mkfwimg.py packs the stock-side
# installer. The result is an image artifact, not a preloader and not
# a rootfs file.
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
endef

$(eval $(generic-package))
