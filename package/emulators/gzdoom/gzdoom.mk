################################################################################
#
# gzdoom
#
# Recipe and patches from Knulli (g4.14.2). Patches live next to this
# file (Buildroot does not apply package/foo/patches/). 0001 maps
# Knulli's /userdata paths onto NextUI's SD card userdata.
#
################################################################################

GZDOOM_VERSION = g4.14.2
GZDOOM_HASH = 99aa489
GZDOOM_SITE = https://github.com/ZDoom/gzdoom
GZDOOM_SITE_METHOD = git
GZDOOM_GIT_SUBMODULES = YES
GZDOOM_LICENSE = GPL-3.0
GZDOOM_LICENSE_FILES = LICENSE
GZDOOM_DEPENDENCIES = host-gzdoom sdl2 bzip2 openal zmusic libvpx webp jpeg zlib
GZDOOM_SUPPORTS_IN_SOURCE_BUILD = NO

HOST_GZDOOM_DEPENDENCIES = host-zlib host-bzip2 host-webp
HOST_GZDOOM_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
HOST_GZDOOM_CONF_OPTS += -DSKIP_INSTALL_ALL=ON
HOST_GZDOOM_CONF_OPTS += -DTOOLS_ONLY=ON
HOST_GZDOOM_CONF_OPTS += -DHAVE_VULKAN=OFF
HOST_GZDOOM_CONF_OPTS += -DHAVE_GLES2=OFF
HOST_GZDOOM_CONF_OPTS += -DNO_GTK=ON
HOST_GZDOOM_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
HOST_GZDOOM_SUPPORTS_IN_SOURCE_BUILD = NO

define HOST_GZDOOM_INSTALL_CMDS
	:
endef

GZDOOM_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
GZDOOM_CONF_OPTS += -DFORCE_CROSSCOMPILE=ON
GZDOOM_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
GZDOOM_CONF_OPTS += -DNO_GTK=ON
GZDOOM_CONF_OPTS += -DHAVE_VULKAN=OFF
GZDOOM_CONF_OPTS += -DHAVE_GLES2=ON
GZDOOM_CONF_OPTS += -DNO_SDL_JOYSTICK=OFF
GZDOOM_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
GZDOOM_CONF_OPTS += -DIMPORT_EXECUTABLES="$(HOST_GZDOOM_BUILDDIR)/ImportExecutables.cmake"

# GLES2 on a KMSDRM board: gzdoom otherwise wants a desktop GL context.
define GZDOOM_PATCH_USE_GLES2
	$(SED) 's%#define USE_GLES2 0%#define USE_GLES2 1%' \
		$(@D)/src/common/rendering/gles/gles_system.h
	$(SED) '1i #define __ANDROID__' $(@D)/src/common/rendering/gles/gles_system.cpp
endef
GZDOOM_POST_PATCH_HOOKS += GZDOOM_PATCH_USE_GLES2

define GZDOOM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/gzdoom
	$(INSTALL) -m 0755 $(@D)/buildroot-build/gzdoom $(TARGET_DIR)/usr/bin/gzdoom
	$(INSTALL) -m 0644 $(@D)/buildroot-build/*.pk3 $(TARGET_DIR)/usr/share/gzdoom/
	cp -a $(@D)/buildroot-build/fm_banks $(TARGET_DIR)/usr/share/gzdoom/
	cp -a $(@D)/buildroot-build/soundfonts $(TARGET_DIR)/usr/share/gzdoom/
endef

define GZDOOM_PREPARE_VERSION_INFO
	export FALLBACK_GIT_TAG=$(GZDOOM_VERSION); \
	export FALLBACK_GIT_HASH=$(GZDOOM_HASH); \
	export FALLBACK_GIT_TIMESTAMP="$(shell date -u -Iseconds)"; \
	$(BR2_CMAKE) -P $(@D)/tools/updaterevision/UpdateRevision.cmake \
		$(@D)/src/gitinfo.h; \
	$(BR2_CMAKE) -P $(@D)/tools/updaterevision/UpdateRevision.cmake \
		$(GZDOOM_BUILDDIR)/src/gitinfo.h
endef
GZDOOM_POST_CONFIGURE_HOOKS += GZDOOM_PREPARE_VERSION_INFO

$(eval $(cmake-package))
$(eval $(host-cmake-package))
