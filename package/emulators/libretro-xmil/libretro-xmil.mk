################################################################################
#
#
# libretro-xmil
################################################################################
# Version: Commits on Nov 1, 2023
LIBRETRO_XMIL_VERSION = 04b3c90af710b66b31df3c9621fa8da13b24e123
LIBRETRO_XMIL_SITE_METHOD=git
LIBRETRO_XMIL_SITE=https://github.com/libretro/xmil-libretro
LIBRETRO_XMIL_GIT_SUBMODULES=YES
LIBRETRO_XMIL_LICENSE = BSD-3
LIBRETRO_XMIL_DEPENDENCIES += retroarch

LIBRETRO_XMIL_PLATFORM = unix

ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_XMIL_PLATFORM = rpi1
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_XMIL_PLATFORM = rpi2
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_XMIL_PLATFORM = rpi3_64
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_XMIL_PLATFORM = rpi4
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_XMIL_PLATFORM = rpi5
endif

define LIBRETRO_XMIL_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" -C $(@D)/libretro -f Makefile.libretro platform=$(LIBRETRO_XMIL_PLATFORM)
endef

define LIBRETRO_XMIL_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/libretro/x1_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/x1_libretro.so
endef

$(eval $(generic-package))
