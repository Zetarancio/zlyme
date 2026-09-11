################################################################################
#
# pico8
#
# No upstream tarball. Installs a launcher that runs the user-supplied
# pico8_64 binary from the PICO-8 roms folder.
#
################################################################################

PICO8_VERSION = 1
PICO8_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/emulators/pico8
PICO8_SITE_METHOD = local
PICO8_LICENSE = GPL-2.0
PICO8_DEPENDENCIES = sdl2

define PICO8_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(PICO8_PKGDIR)/start_pico8.sh \
		$(TARGET_DIR)/usr/bin/pico8
endef

$(eval $(generic-package))
