################################################################################
#
# amiberry
#
################################################################################

AMIBERRY_VERSION = v7.1.0
AMIBERRY_SITE = $(call github,BlitterStudio,amiberry,$(AMIBERRY_VERSION))
AMIBERRY_LICENSE = GPL-3.0
AMIBERRY_LICENSE_FILES = LICENSE
AMIBERRY_SUPPORTS_IN_SOURCE_BUILD = NO

AMIBERRY_DEPENDENCIES = \
	sdl2 sdl2_image sdl2_ttf mpg123 libpcap libxml2 libmpeg2 \
	flac libpng libserialport zlib enet libportmidi

AMIBERRY_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
AMIBERRY_CONF_OPTS += -DWITH_LTO=OFF
AMIBERRY_CONF_OPTS += -DUSE_OPENGL=OFF
AMIBERRY_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5

define AMIBERRY_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/buildroot-build/amiberry $(TARGET_DIR)/usr/bin/amiberry
	mkdir -p $(TARGET_DIR)/usr/share/amiberry
	cp -a $(@D)/buildroot-build/whdboot $(TARGET_DIR)/usr/share/amiberry/
	cp -a $(@D)/buildroot-build/data $(TARGET_DIR)/usr/share/amiberry/
	mkdir -p $(TARGET_DIR)/usr/share/amiberry/roms
	cp -a $(@D)/buildroot-build/roms/aros-ext.bin \
		$(TARGET_DIR)/usr/share/amiberry/roms/
	cp -a $(@D)/buildroot-build/roms/aros-rom.bin \
		$(TARGET_DIR)/usr/share/amiberry/roms/
endef

$(eval $(cmake-package))
