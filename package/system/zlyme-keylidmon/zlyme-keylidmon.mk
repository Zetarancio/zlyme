################################################################################
#
# zlyme-keylidmon
#
# Volume, brightness, lid, and power while a pak owns the screen.
################################################################################

ZLYME_KEYLIDMON_VERSION = local
ZLYME_KEYLIDMON_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-keylidmon
ZLYME_KEYLIDMON_SITE_METHOD = local
ZLYME_KEYLIDMON_LICENSE = GPL-2.0
ZLYME_KEYLIDMON_LICENSE_FILES = LICENSE
ZLYME_KEYLIDMON_DEPENDENCIES = nextui libdrm

define ZLYME_KEYLIDMON_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) \
		-I$(STAGING_DIR)/usr/include \
		-o $(@D)/zlyme-keylidmon $(@D)/zlyme-keylidmon.c \
		-L$(STAGING_DIR)/usr/lib -lmsettings -lrt -ldrm
endef

define ZLYME_KEYLIDMON_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-keylidmon \
		$(TARGET_DIR)/usr/sbin/zlyme-keylidmon
	rm -f $(TARGET_DIR)/usr/bin/keymon.elf \
		$(TARGET_DIR)/usr/sbin/zlyme-volmon \
		$(TARGET_DIR)/etc/init.d/S26keymon \
		$(TARGET_DIR)/etc/init.d/S26volmon \
		$(TARGET_DIR)/etc/udev/rules.d/60-zlyme-volume-keys.rules
endef

$(eval $(generic-package))
