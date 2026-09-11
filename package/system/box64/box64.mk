################################################################################
#
# box64
#
# v0.4.4. No gtk/X11. ARM dynarec.
################################################################################

BOX64_VERSION = 2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a
BOX64_SITE = $(call github,ptitSeb,box64,$(BOX64_VERSION))
BOX64_LICENSE = MIT
BOX64_DEPENDENCIES = sdl2

BOX64_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
BOX64_CONF_OPTS += -DARM_DYNAREC=ON
BOX64_CONF_OPTS += -DBOX32=OFF

define BOX64_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/box64 $(TARGET_DIR)/usr/bin/box64
	mkdir -p $(TARGET_DIR)/usr/share/box64/lib
	cp -a $(@D)/x64lib/. $(TARGET_DIR)/usr/share/box64/lib/ 2>/dev/null || true
endef

$(eval $(cmake-package))
