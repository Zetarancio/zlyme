################################################################################
#
# zlyme-usb-transfer
#
# MTP session for the lower USB-C port. Not a boot service.
#
################################################################################

ZLYME_USB_TRANSFER_VERSION = local
ZLYME_USB_TRANSFER_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-usb-transfer
ZLYME_USB_TRANSFER_SITE_METHOD = local
ZLYME_USB_TRANSFER_LICENSE = MIT
ZLYME_USB_TRANSFER_LICENSE_FILES = LICENSE
ZLYME_USB_TRANSFER_DEPENDENCIES = umtprd

define ZLYME_USB_TRANSFER_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror \
		-o $(@D)/zlyme-usb-enter $(@D)/zlyme-usb-enter.c
endef

define ZLYME_USB_TRANSFER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-usb-transfer \
		$(TARGET_DIR)/usr/sbin/zlyme-usb-transfer
	$(INSTALL) -D -m 0755 $(@D)/zlyme-usb-enter \
		$(TARGET_DIR)/usr/sbin/zlyme-usb-enter
endef

$(eval $(generic-package))
