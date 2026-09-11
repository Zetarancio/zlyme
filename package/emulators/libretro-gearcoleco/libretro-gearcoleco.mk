################################################################################
#
# libretro-gearcoleco
#
################################################################################

LIBRETRO_GEARCOLECO_VERSION = f336da73f64917a2889b183e7e5025485bcd0e79
LIBRETRO_GEARCOLECO_SITE = $(call github,drhelius,Gearcoleco,$(LIBRETRO_GEARCOLECO_VERSION))
LIBRETRO_GEARCOLECO_LICENSE = GPL
LIBRETRO_GEARCOLECO_DEPENDENCIES = retroarch

define LIBRETRO_GEARCOLECO_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" -C $(@D)/platforms/libretro/ platform="unix"
endef

define LIBRETRO_GEARCOLECO_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/platforms/libretro/gearcoleco_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/gearcoleco_libretro.so
endef

$(eval $(generic-package))
