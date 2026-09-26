################################################################################
#
# zlyme-input
#
# Player order and built-in controller release/reclaim.
#
################################################################################

ZLYME_INPUT_VERSION = local
ZLYME_INPUT_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-input
ZLYME_INPUT_SITE_METHOD = local
ZLYME_INPUT_LICENSE = GPL-2.0-or-later
ZLYME_INPUT_LICENSE_FILES = LICENSE
ZLYME_INPUT_DEPENDENCIES = host-pkgconf dbus inputplumber

define ZLYME_INPUT_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags dbus-1) \
		-o $(@D)/zlyme-input $(@D)/zlyme-input.c $(@D)/order.c $(@D)/lifecycle.c \
		$(TARGET_LDFLAGS) $$($(PKG_CONFIG_HOST_BINARY) --libs dbus-1)
endef

define ZLYME_INPUT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-input $(TARGET_DIR)/usr/sbin/zlyme-input
	$(INSTALL) -D -m 0755 $(@D)/S32zlyme-input $(TARGET_DIR)/etc/init.d/S32zlyme-input
endef

$(eval $(generic-package))
