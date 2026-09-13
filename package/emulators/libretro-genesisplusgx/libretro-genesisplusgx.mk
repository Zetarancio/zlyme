################################################################################
#
# libretro-genesisplusgx
################################################################################

LIBRETRO_GENESISPLUSGX_VERSION = 302fe82fccbe2e036c3e13891db6513982a497ac
LIBRETRO_GENESISPLUSGX_SITE = $(call github,ekeeke,Genesis-Plus-GX,$(LIBRETRO_GENESISPLUSGX_VERSION))
LIBRETRO_GENESISPLUSGX_LICENSE = Non-commercial
LIBRETRO_GENESISPLUSGX_DEPENDENCIES = retroarch

# ROCKNIX builds this with NO_OPTIMIZE; pin -O2 under global -O3.
LIBRETRO_GENESISPLUSGX_CFLAGS = $(filter-out -O3,$(TARGET_CFLAGS)) -O2
LIBRETRO_GENESISPLUSGX_CXXFLAGS = $(filter-out -O3,$(TARGET_CXXFLAGS)) -O2

define LIBRETRO_GENESISPLUSGX_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) CFLAGS="$(LIBRETRO_GENESISPLUSGX_CFLAGS)" \
		CXXFLAGS="$(LIBRETRO_GENESISPLUSGX_CXXFLAGS)" \
		$(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
		-C $(@D) -f Makefile.libretro platform="$(LIBRETRO_PLATFORM)"
endef

define LIBRETRO_GENESISPLUSGX_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/genesis_plus_gx_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/genesis_plus_gx_libretro.so
endef

$(eval $(generic-package))
