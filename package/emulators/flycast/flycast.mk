################################################################################
#
# flycast
################################################################################

FLYCAST_VERSION = v2.5
FLYCAST_SITE = https://github.com/flyinghead/flycast.git
FLYCAST_SITE_METHOD = git
FLYCAST_GIT_SUBMODULES = YES
FLYCAST_LICENSE = GPL-2.0
FLYCAST_DEPENDENCIES = sdl2 libpng libzip libcurl zlib
FLYCAST_SUPPORTS_IN_SOURCE_BUILD = NO

FLYCAST_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
FLYCAST_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
FLYCAST_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
FLYCAST_CONF_OPTS += -DLIBRETRO=OFF
FLYCAST_CONF_OPTS += -DUSE_HOST_SDL=ON
FLYCAST_CONF_OPTS += -DUSE_DX9=OFF
FLYCAST_CONF_OPTS += -DUSE_DX11=OFF
FLYCAST_CONF_OPTS += -DUSE_GLES=ON
FLYCAST_CONF_OPTS += -DUSE_GLES2=OFF
FLYCAST_CONF_OPTS += -DUSE_OPENGL=ON
ifeq ($(BR2_PACKAGE_VULKAN_HEADERS)$(BR2_PACKAGE_VULKAN_LOADER),yy)
FLYCAST_CONF_OPTS += -DUSE_VULKAN=ON
FLYCAST_DEPENDENCIES += vulkan-headers vulkan-loader
else
FLYCAST_CONF_OPTS += -DUSE_VULKAN=OFF
endif

define FLYCAST_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/buildroot-build/flycast $(TARGET_DIR)/usr/bin/flycast
endef

$(eval $(cmake-package))
