################################################################################
#
# zlyme-maskrom
#
# Writes one ZLYMEBOOT request and then asks for an ordinary restart.
# Not a NAND writer and not a boot service.
#
################################################################################

ZLYME_MASKROM_VERSION = local
ZLYME_MASKROM_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-maskrom
ZLYME_MASKROM_SITE_METHOD = local
ZLYME_MASKROM_LICENSE = MIT
ZLYME_MASKROM_LICENSE_FILES = LICENSE

define ZLYME_MASKROM_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror -std=gnu99 \
		-o $(@D)/zlyme-maskrom $(@D)/zlyme-maskrom.c
endef

define ZLYME_MASKROM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-maskrom \
		$(TARGET_DIR)/usr/sbin/zlyme-maskrom
endef

$(eval $(generic-package))
