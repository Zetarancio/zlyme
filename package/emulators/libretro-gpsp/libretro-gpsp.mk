
################################################################################
#
#
# libretro-gpsp
################################################################################
# ROCKNIX next a55d58a1 carries this revision (2026-08-25).
# Newer than KNULLI knulli-main d6decfa3. Not libretro/gpSP HEAD.
# Default sound output rate at this pin is 32768. gpSP.opt does not override it.
LIBRETRO_GPSP_VERSION = 8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f
LIBRETRO_GPSP_SITE = $(call github,libretro,gpsp,$(LIBRETRO_GPSP_VERSION))
LIBRETRO_GPSP_LICENSE = GPLv2
LIBRETRO_GPSP_DEPENDENCIES += retroarch

LIBRETRO_GPSP_PLATFORM = unix

ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_GPSP_PLATFORM = rpi1

else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_GPSP_PLATFORM = rpi2

else ifeq ($(BR2_aarch64),y)
LIBRETRO_GPSP_PLATFORM = arm64
endif

define LIBRETRO_GPSP_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
	    -C $(@D) platform=$(LIBRETRO_GPSP_PLATFORM) -j"$(PARALLEL_JOBS)"   \
        GIT_VERSION="-$(shell echo $(LIBRETRO_GPSP_VERSION) | cut -c 1-7)"
endef

define LIBRETRO_GPSP_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/gpsp_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/gpsp_libretro.so
endef

$(eval $(generic-package))
