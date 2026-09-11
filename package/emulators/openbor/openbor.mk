################################################################################
#
# openbor
#
################################################################################

OPENBOR_VERSION = v7533
OPENBOR_SITE = $(call github,DCurrent,openbor,$(OPENBOR_VERSION))
OPENBOR_LICENSE = BSD-3-Clause
OPENBOR_LICENSE_FILES = LICENSE
OPENBOR_DEPENDENCIES = libvpx sdl2 sdl2_gfx libpng libogg libvorbis host-yasm

define OPENBOR_PRE_CONFIGURE_VERSION
	$(SED) 's/VERSION_BUILD="[^"]*"/VERSION_BUILD="$(subst v,,$(OPENBOR_VERSION))"/' \
		$(@D)/engine/version.sh
endef
OPENBOR_PRE_CONFIGURE_HOOKS += OPENBOR_PRE_CONFIGURE_VERSION

define OPENBOR_BUILD_CMDS
	cd $(@D)/engine && chmod +x $(@D)/engine/version.sh && $(@D)/engine/version.sh
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
		-C $(@D)/engine -f Makefile BUILD_LINUX_LE_arm=1 VERBOSE=1
endef

define OPENBOR_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/engine/OpenBOR $(TARGET_DIR)/usr/bin/OpenBOR
endef

$(eval $(generic-package))
