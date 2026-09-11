################################################################################
#
# libretro-beetle-supafaust
#
################################################################################

LIBRETRO_BEETLE_SUPAFAUST_VERSION = e25f66765938d33f9ad5850e8d6cd597e55b7299
LIBRETRO_BEETLE_SUPAFAUST_SITE = https://github.com/libretro/supafaust
LIBRETRO_BEETLE_SUPAFAUST_SITE_METHOD = git
LIBRETRO_BEETLE_SUPAFAUST_LICENSE = GPLv2
LIBRETRO_BEETLE_SUPAFAUST_DEPENDENCIES = retroarch

define LIBRETRO_BEETLE_SUPAFAUST_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" -C $(@D) platform="unix"
endef

define LIBRETRO_BEETLE_SUPAFAUST_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/mednafen_supafaust_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/mednafen_supafaust_libretro.so
endef

$(eval $(generic-package))
