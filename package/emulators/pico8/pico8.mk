################################################################################
#
# pico8
#
# No upstream tarball. Installs a launcher that runs the user-supplied
# pico8_64 binary from Bios/PICO.
#
################################################################################

PICO8_VERSION = 4
PICO8_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/emulators/pico8
PICO8_SITE_METHOD = local
# Launcher only. Pico-8 itself is proprietary Lexaloffle; not shipped.
PICO8_LICENSE = MIT
PICO8_LICENSE_FILES = LICENSE
PICO8_DEPENDENCIES = sdl2

define PICO8_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -O2 -o $(@D)/pico8-splore-pad \
		$(PICO8_PKGDIR)/pico8-splore-pad.c
endef

define PICO8_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(PICO8_PKGDIR)/start_pico8.sh \
		$(TARGET_DIR)/usr/bin/pico8
	$(INSTALL) -D -m 0755 $(@D)/pico8-splore-pad \
		$(TARGET_DIR)/usr/bin/pico8-splore-pad
endef

$(eval $(generic-package))
