################################################################################
#
#
# libretro-prboom
################################################################################
# Version: Commits on May 27, 2023
LIBRETRO_PRBOOM_VERSION = 6ec854969fd9dec33bb2cab350f05675d1158969
LIBRETRO_PRBOOM_SITE = $(call github,libretro,libretro-prboom,$(LIBRETRO_PRBOOM_VERSION))
LIBRETRO_PRBOOM_LICENSE = GPLv2
LIBRETRO_PRBOOM_DEPENDENCIES += retroarch

LIBRETRO_PRBOOM_PLATFORM = $(LIBRETRO_PLATFORM)

ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PRBOOM_PLATFORM = armv

else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PRBOOM_PLATFORM = armv neon

else ifeq ($(BR2_aarch64),y)
LIBRETRO_PRBOOM_PLATFORM = unix
endif

# -std=c99 hides POSIX ftruncate/fileno unless a feature-test macro is set.
define LIBRETRO_PRBOOM_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) \
	    CFLAGS="$(TARGET_CFLAGS) -D_DEFAULT_SOURCE" \
	    $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" -C $(@D)/ \
	    -f Makefile platform="$(LIBRETRO_PRBOOM_PLATFORM)" \
	    GIT_VERSION="-$(shell echo $(LIBRETRO_PRBOOM_VERSION) | cut -c 1-7)"
endef

define LIBRETRO_PRBOOM_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/prboom_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/prboom_libretro.so
endef

$(eval $(generic-package))
