################################################################################
#
# ppsspp
################################################################################

PPSSPP_VERSION = v1.19.3
PPSSPP_SITE = https://github.com/hrydgard/ppsspp.git
PPSSPP_SITE_METHOD = git
PPSSPP_GIT_SUBMODULES = YES
PPSSPP_LICENSE = GPL-2.0
PPSSPP_DEPENDENCIES = sdl2 sdl2_ttf libzip zlib libpng

PPSSPP_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
PPSSPP_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
PPSSPP_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
PPSSPP_CONF_OPTS += -DUSE_SYSTEM_FFMPEG=OFF
PPSSPP_CONF_OPTS += -DUSE_FFMPEG=ON
PPSSPP_CONF_OPTS += -DUSING_FBDEV=ON
PPSSPP_CONF_OPTS += -DUSE_DISCORD=OFF
PPSSPP_CONF_OPTS += -DUSING_QT_UI=OFF
PPSSPP_CONF_OPTS += -DHEADLESS=OFF
PPSSPP_CONF_OPTS += -DUNITTEST=OFF
PPSSPP_CONF_OPTS += -DENABLE_CTEST=OFF
PPSSPP_CONF_OPTS += -DARM=ON
PPSSPP_CONF_OPTS += -DARM64=ON
PPSSPP_CONF_OPTS += -DUSING_GLES2=ON
PPSSPP_CONF_OPTS += -DUSING_EGL=ON
PPSSPP_CONF_OPTS += -DVULKAN=OFF
PPSSPP_CONF_OPTS += -DUSING_X11_VULKAN=OFF
# Staging sdl2_ttf-config.cmake sets FOUND but looks for /usr/lib/libSDL2_ttf.so
# (host path) and never creates SDL2_ttf::SDL2_ttf. Use pkg-config instead.
PPSSPP_CONF_OPTS += -DCMAKE_DISABLE_FIND_PACKAGE_SDL2_ttf=ON

PPSSPP_CONF_OPTS += -DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -DEGL_NO_X11=1"
PPSSPP_CONF_OPTS += -DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -DEGL_NO_X11=1"

define PPSSPP_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/PPSSPPSDL $(TARGET_DIR)/usr/bin/PPSSPPSDL
	if [ -d $(@D)/assets ]; then \
		mkdir -p $(TARGET_DIR)/usr/share/ppsspp; \
		cp -a $(@D)/assets $(TARGET_DIR)/usr/share/ppsspp/; \
	fi
endef

$(eval $(cmake-package))
