################################################################################
#
# minui-presenter
#
# Vendored snapshot of josegonzalez/minui-presenter 0.13.2.
# See UPSTREAM.
#
################################################################################

MINUI_PRESENTER_VERSION = 0.13.2
MINUI_PRESENTER_SITE = $(MINUI_PRESENTER_PKGDIR)/src
MINUI_PRESENTER_SITE_METHOD = local
MINUI_PRESENTER_LICENSE = MIT
MINUI_PRESENTER_LICENSE_FILES = LICENSE
# Linked against NextUI objects (PolyForm NC). See $(MINUI_PRESENTER_PKGDIR)/LICENSE.
MINUI_PRESENTER_DEPENDENCIES = nextui minui-list sdl2 sdl2_image sdl2_ttf libpng freetype zlib libsamplerate libdrm

MINUI_PRESENTER_PLATFORM = $(call qstrip,$(BR2_PACKAGE_NEXTUI_PLATFORM))
ifeq ($(MINUI_PRESENTER_PLATFORM),)
$(error BR2_PACKAGE_NEXTUI_PLATFORM is empty; select a Zlyme target device)
endif

MINUI_PRESENTER_CFLAGS = $(TARGET_CFLAGS) -std=gnu11 \
	-DPLATFORM=\"$(MINUI_PRESENTER_PLATFORM)\" -DPLATFORM_NEXTUI -DUSE_SDL2 -DUSE_GLES \
	-DGL_GLEXT_PROTOTYPES -DEGL_NO_X11=1 \
	-I$(STAGING_DIR)/usr/include/libdrm \
	-I$(NEXTUI_DIR)/workspace/all/common \
	-I$(NEXTUI_DIR)/workspace/$(MINUI_PRESENTER_PLATFORM)/platform \
	-I$(NEXTUI_DIR)/workspace/$(MINUI_PRESENTER_PLATFORM)/libmsettings \
	-I$(@D) -I$(MINUI_LIST_DIR)/include

MINUI_PRESENTER_OBJS = \
	$(NEXTUI_DIR)/scaler.o $(NEXTUI_DIR)/utils.o $(NEXTUI_DIR)/config.o \
	$(NEXTUI_DIR)/api.o $(NEXTUI_DIR)/palette.o $(NEXTUI_DIR)/platform.o

define MINUI_PRESENTER_BUILD_CMDS
	$(TARGET_CC) $(MINUI_PRESENTER_CFLAGS) \
		-o $(@D)/minui-presenter \
		$(@D)/minui-presenter.c \
		$(@D)/presenter_theme.c \
		$(MINUI_LIST_DIR)/include/parson/parson.c \
		$(MINUI_PRESENTER_OBJS) \
		$(TARGET_LDFLAGS) -L$(NEXTUI_DIR) -lmsettings \
		-lsamplerate -lSDL2 -lSDL2_image -lSDL2_ttf \
		-lGLESv2 -lEGL -ldl -lpthread -lm -lz -lrt -ldrm
endef

define MINUI_PRESENTER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/minui-presenter $(TARGET_DIR)/usr/bin/minui-presenter
	$(INSTALL) -D -m 0755 $(@D)/minui-presenter \
		$(TARGET_DIR)/usr/share/nextui/paks/Tools/Artwork\ Scraper.pak/bin/$(MINUI_PRESENTER_PLATFORM)/minui-presenter
	$(INSTALL) -D -m 0755 $(@D)/minui-presenter \
		$(TARGET_DIR)/usr/share/nextui/paks/Tools/Overlays.pak/bin/$(MINUI_PRESENTER_PLATFORM)/minui-presenter
	$(INSTALL) -D -m 0644 $(MINUI_PRESENTER_PKGDIR)/LICENSE \
		$(TARGET_DIR)/usr/share/minui-presenter/LICENSE
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/minui-presenter/LICENSE.upstream
endef

$(eval $(generic-package))
