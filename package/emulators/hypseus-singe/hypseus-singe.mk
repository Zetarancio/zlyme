################################################################################
#
# hypseus-singe
#
################################################################################

HYPSEUS_SINGE_VERSION = v2.11.5
HYPSEUS_SINGE_SITE = $(call github,DirtBagXon,hypseus-singe,$(HYPSEUS_SINGE_VERSION))
HYPSEUS_SINGE_LICENSE = GPL-3.0
HYPSEUS_SINGE_LICENSE_FILES = LICENSE
HYPSEUS_SINGE_DEPENDENCIES = \
	libmpeg2 libogg libvorbis libzip sdl2 sdl2_image sdl2_mixer sdl2_ttf zlib
HYPSEUS_SINGE_SUBDIR = src
HYPSEUS_SINGE_SUPPORTS_IN_SOURCE_BUILD = NO

HYPSEUS_SINGE_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
HYPSEUS_SINGE_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
HYPSEUS_SINGE_CONF_OPTS += -DABSTRACT_SINGE=OFF

define HYPSEUS_SINGE_INSTALL_TARGET_CMDS
	if [ -f $(@D)/src/buildroot-build/hypseus ]; then \
		$(INSTALL) -D $(@D)/src/buildroot-build/hypseus \
			$(TARGET_DIR)/usr/bin/hypseus; \
	else \
		$(INSTALL) -D $(@D)/src/hypseus $(TARGET_DIR)/usr/bin/hypseus; \
	fi
	mkdir -p $(TARGET_DIR)/usr/share/hypseus-singe
	cp -a $(@D)/pics $(TARGET_DIR)/usr/share/hypseus-singe/
	cp -a $(@D)/fonts $(TARGET_DIR)/usr/share/hypseus-singe/
	cp -a $(@D)/sound $(TARGET_DIR)/usr/share/hypseus-singe/
	cp -a $(@D)/doc/*.ini $(TARGET_DIR)/usr/share/hypseus-singe/
endef

$(eval $(cmake-package))
