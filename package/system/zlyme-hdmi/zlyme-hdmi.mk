################################################################################
#
# zlyme-hdmi
#
# Reads HDMI-A modes and prints the gated output policy. It does not
# modeset and it does not take DRM master on purpose.
#
################################################################################

ZLYME_HDMI_VERSION = local
ZLYME_HDMI_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-hdmi
ZLYME_HDMI_SITE_METHOD = local
ZLYME_HDMI_LICENSE = MIT
ZLYME_HDMI_LICENSE_FILES = LICENSE
ZLYME_HDMI_DEPENDENCIES = libdrm

define ZLYME_HDMI_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror \
		-I$(@D) -I$(STAGING_DIR)/usr/include/libdrm \
		-o $(@D)/zlyme-hdmi $(@D)/zlyme-hdmi.c $(@D)/hdmi_mode.c \
		$(TARGET_LDFLAGS) -ldrm
endef

define ZLYME_HDMI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-hdmi $(TARGET_DIR)/usr/bin/zlyme-hdmi
	$(INSTALL) -D -m 0755 $(@D)/hdmi-session.sh \
		$(TARGET_DIR)/usr/share/zlyme/hdmi-session.sh
endef

$(eval $(generic-package))
