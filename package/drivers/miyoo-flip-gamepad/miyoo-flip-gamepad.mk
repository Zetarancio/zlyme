################################################################################
#
# miyoo-flip-gamepad
#
# Local source. The Flip DTS binds miyoo,flip-gamepad.
#
################################################################################

MIYOO_FLIP_GAMEPAD_VERSION = local
MIYOO_FLIP_GAMEPAD_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/drivers/miyoo-flip-gamepad/src
MIYOO_FLIP_GAMEPAD_SITE_METHOD = local
MIYOO_FLIP_GAMEPAD_LICENSE = GPL-2.0-only
MIYOO_FLIP_GAMEPAD_LICENSE_FILES = LICENSE

$(eval $(kernel-module))
$(eval $(generic-package))
