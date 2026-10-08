################################################################################
#
# zlyme-preloader
#
# Userspace recovery for the one MTD partition Zlyme exports. Not a
# boot service.
#
################################################################################

ZLYME_PRELOADER_VERSION = local
ZLYME_PRELOADER_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-preloader
ZLYME_PRELOADER_SITE_METHOD = local
# MIT covers the script and the checker. The stock SPI preloader is Miyoo
# vendor firmware and is not installed. preloader-stock.PROVENANCE records
# why that binary stays out of the package.
ZLYME_PRELOADER_LICENSE = MIT
ZLYME_PRELOADER_LICENSE_FILES = LICENSE
ZLYME_PRELOADER_DEPENDENCIES = python3 mtd

define ZLYME_PRELOADER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-preloader \
		$(TARGET_DIR)/usr/sbin/zlyme-preloader
	$(INSTALL) -D -m 0755 $(@D)/preloader_image.py \
		$(TARGET_DIR)/usr/lib/zlyme/preloader_image.py
endef

$(eval $(generic-package))
