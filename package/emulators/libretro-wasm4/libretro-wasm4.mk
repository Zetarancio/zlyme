################################################################################
#
#
# libretro-wasm4
################################################################################

LIBRETRO_WASM4_VERSION = v2.7.1
LIBRETRO_WASM4_SITE = https://github.com/aduros/wasm4
LIBRETRO_WASM4_SITE_METHOD = git
LIBRETRO_WASM4_GIT_SUBMODULES = yes
LIBRETRO_WASM4_LICENSE = ISC
LIBRETRO_WASM4_DEPENDENCIES += retroarch

LIBRETRO_WASM4_SUBDIR = runtimes/native

LIBRETRO_WASM4_CONF_OPTS = -DCMAKE_BUILD_TYPE=Release
LIBRETRO_WASM4_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
# Skip the desktop minifb/X11 backend; we only ship the libretro core.
LIBRETRO_WASM4_CONF_OPTS += -DLIBRETRO=ON

define LIBRETRO_WASM4_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/runtimes/native/wasm4_libretro.so \
	    $(TARGET_DIR)/usr/lib/libretro/wasm4_libretro.so
endef

$(eval $(cmake-package))
