################################################################################
#
# miyoo-flip-gamepad
#
# Local source. The old rocknix-joypad package stays
# buildable for rollback and must not bind: the Flip DTS no longer has
# a rocknix-singleadc-joypad node.
#
################################################################################

MIYOO_FLIP_GAMEPAD_VERSION = local
MIYOO_FLIP_GAMEPAD_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/drivers/miyoo-flip-gamepad/src
MIYOO_FLIP_GAMEPAD_SITE_METHOD = local
MIYOO_FLIP_GAMEPAD_LICENSE = GPL-2.0-only
MIYOO_FLIP_GAMEPAD_LICENSE_FILES = LICENSE

$(eval $(kernel-module))
$(eval $(generic-package))
