################################################################################
#
# minui-list
#
# https://github.com/josegonzalez/minui-list
# JSON via kgabis/parson (the upstream Makefile clones it at build time).
#
################################################################################

MINUI_LIST_VERSION = 0.15.2
MINUI_LIST_SITE = https://github.com/josegonzalez/minui-list
MINUI_LIST_SITE_METHOD = git
MINUI_LIST_LICENSE = MIT
MINUI_LIST_LICENSE_FILES = LICENSE
# Linked against NextUI objects (PolyForm NC). See $(MINUI_LIST_PKGDIR)/LICENSE.
MINUI_LIST_DEPENDENCIES = nextui sdl2 sdl2_image sdl2_ttf libpng freetype zlib libsamplerate libdrm

MINUI_LIST_PARSON_VERSION = ec53fb6528b45811df9db0db22cab96a94a96a11
MINUI_LIST_EXTRA_DOWNLOADS = https://github.com/kgabis/parson/archive/$(MINUI_LIST_PARSON_VERSION).tar.gz

MINUI_LIST_CFLAGS = $(TARGET_CFLAGS) -std=gnu11 \
	-DPLATFORM=\"my355\" -DPLATFORM_NEXTUI -DUSE_SDL2 -DUSE_GLES \
	-DGL_GLEXT_PROTOTYPES -DEGL_NO_X11=1 \
	-I$(STAGING_DIR)/usr/include/libdrm \
	-I$(NEXTUI_DIR)/workspace/all/common \
	-I$(NEXTUI_DIR)/workspace/my355/platform \
	-I$(NEXTUI_DIR)/workspace/my355/libmsettings \
	-I$(@D) -I$(@D)/include

MINUI_LIST_OBJS = \
	$(NEXTUI_DIR)/scaler.o $(NEXTUI_DIR)/utils.o $(NEXTUI_DIR)/config.o \
	$(NEXTUI_DIR)/api.o $(NEXTUI_DIR)/palette.o $(NEXTUI_DIR)/platform.o

define MINUI_LIST_BUILD_CMDS
	mkdir -p $(@D)/include
	tar -C $(@D) -xzf $(MINUI_LIST_DL_DIR)/$(MINUI_LIST_PARSON_VERSION).tar.gz
	rm -rf $(@D)/include/parson
	mv $(@D)/parson-$(MINUI_LIST_PARSON_VERSION) $(@D)/include/parson
	$(TARGET_CC) $(MINUI_LIST_CFLAGS) \
		-o $(@D)/minui-list \
		$(@D)/minui-list.c \
		$(@D)/list_filter.c \
		$(@D)/list_hint.c \
		$(@D)/list_image.c \
		$(@D)/list_keyboard.c \
		$(@D)/list_nav.c \
		$(@D)/list_scroll.c \
		$(@D)/list_theme.c \
		$(@D)/include/parson/parson.c \
		$(MINUI_LIST_OBJS) \
		$(TARGET_LDFLAGS) -L$(NEXTUI_DIR) -lmsettings \
		-lsamplerate -lSDL2 -lSDL2_image -lSDL2_ttf \
		-lGLESv2 -lEGL -ldl -lpthread -lm -lz -lrt -ldrm
endef

define MINUI_LIST_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/minui-list $(TARGET_DIR)/usr/bin/minui-list
	$(INSTALL) -D -m 0755 $(@D)/minui-list \
		$(TARGET_DIR)/usr/share/nextui/paks/Tools/Artwork\ Scraper.pak/bin/my355/minui-list
	$(INSTALL) -D -m 0755 $(@D)/minui-list \
		$(TARGET_DIR)/usr/share/nextui/paks/Tools/Overlays.pak/bin/my355/minui-list
	$(INSTALL) -D -m 0644 $(MINUI_LIST_PKGDIR)/LICENSE \
		$(TARGET_DIR)/usr/share/minui-list/LICENSE
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/minui-list/LICENSE.upstream
endef

$(eval $(generic-package))
