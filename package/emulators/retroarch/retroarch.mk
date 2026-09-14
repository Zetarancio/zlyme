################################################################################
#
# retroarch
#
# KMS + EGL + GLES + SDL2 + ALSA. RGUI only (ozone/xmb are not built).
# 1.22 libchdr needs vendored dr_flac; Knulli's --disable-builtinflac is for 1.21.
################################################################################

RETROARCH_VERSION = v1.22.2
RETROARCH_SITE = $(call github,libretro,RetroArch,$(RETROARCH_VERSION))
RETROARCH_LICENSE = GPL-3.0+
RETROARCH_LICENSE_FILES = COPYING
RETROARCH_DEPENDENCIES = host-pkgconf sdl2 alsa-lib libdrm libegl libgles zlib udev xz

# RetroArch's qb configure is not autotools. It honours CROSS_COMPILE and
# PKG_CONF_PATH; without the latter it looks for ${CROSS_COMPILE}pkg-config,
# which does not exist in a Buildroot host dir (the wrapper is just pkg-config).
RETROARCH_CONF_OPTS = \
	--prefix=/usr \
	--disable-oss \
	--disable-qt \
	--disable-discord \
	--disable-cdrom \
	--disable-pulse \
	--disable-x11 \
	--disable-wayland \
	--disable-videocore \
	--disable-ffmpeg \
	--disable-sdl \
	--disable-opengles3_2 \
	--enable-sdl2 \
	--enable-alsa \
	--enable-kms \
	--enable-egl \
	--enable-opengles \
	--enable-opengles3 \
	--enable-opengles3_1 \
	--enable-threads \
	--enable-rgui \
	--disable-ozone \
	--disable-xmb \
	--enable-zlib \
	--enable-builtinflac \
	--enable-udev \
	--disable-hid \
	--disable-update_cores \
	--disable-update_core_info

define RETROARCH_CONFIGURE_CMDS
	(cd $(@D); rm -rf config.cache; \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS) -DEGL_NO_X11" \
		LDFLAGS="$(TARGET_LDFLAGS) -lc" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		PKG_CONF_PATH="$(HOST_DIR)/bin/pkg-config" \
		./configure \
		$(RETROARCH_CONF_OPTS) \
	)
endef

define RETROARCH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" LD="$(TARGET_LD)"
endef

define RETROARCH_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) install
endef

$(eval $(generic-package))

# Shared with every libretro core. unix+arm64 for aarch64.
LIBRETRO_PLATFORM = unix arm64
