################################################################################
#
#
# libretro-puae
################################################################################
# Version: Commits on Feb 22, 2024
LIBRETRO_PUAE_VERSION = 5f683ae67b998fcadd69fa8f65f2440fa8ef135f
LIBRETRO_PUAE_SITE = $(call github,libretro,libretro-uae,$(LIBRETRO_PUAE_VERSION))
LIBRETRO_PUAE_LICENSE = GPLv2
LIBRETRO_PUAE_DEPENDENCIES += retroarch

LIBRETRO_PUAE_PLATFORM=$(LIBRETRO_PLATFORM)

ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PUAE_PLATFORM = rpi1
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PUAE_PLATFORM = rpi2
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PUAE_PLATFORM = rpi3_64
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PUAE_PLATFORM = rpi4
else ifeq ($(BR2_PACKAGE_FLIP_NEVER),y)
LIBRETRO_PUAE_PLATFORM = rpi5
endif

# GCC 14 treats uae_u64* vs uint64_t* in softfloat as an error.
define LIBRETRO_PUAE_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) \
	    CFLAGS="$(TARGET_CFLAGS) -Wno-error=incompatible-pointer-types" \
	    $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
	    -C $(@D)/ -f Makefile platform="$(LIBRETRO_PUAE_PLATFORM)" \
	    GIT_VERSION="-$(shell echo $(LIBRETRO_PUAE_VERSION) | cut -c 1-7)"
endef

define LIBRETRO_PUAE_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/puae_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/puae_libretro.so
endef

$(eval $(generic-package))
