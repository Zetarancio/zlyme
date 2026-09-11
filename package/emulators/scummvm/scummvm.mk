################################################################################
#
# scummvm
#
################################################################################

SCUMMVM_VERSION = v2.9.1
SCUMMVM_SITE = $(call github,scummvm,scummvm,$(SCUMMVM_VERSION))
SCUMMVM_LICENSE = GPL-3.0
SCUMMVM_LICENSE_FILES = COPYING
SCUMMVM_DEPENDENCIES = \
	sdl2 zlib libpng freetype jpeg libogg libvorbis flac libmad faad2 \
	libmpeg2 libtheora fluidsynth

SCUMMVM_CONF_OPTS = \
	--host=$(GNU_TARGET_NAME) \
	--prefix=/usr \
	--enable-release \
	--enable-optimizations \
	--disable-debug \
	--opengl-mode=gles \
	--enable-vkeybd \
	--enable-flac \
	--enable-mad \
	--enable-vorbis \
	--enable-fluidsynth \
	--enable-mpeg2 \
	--disable-alsa \
	--disable-taskbar \
	--disable-timidity \
	--disable-eventrecorder \
	--enable-all-engines \
	--with-sdl-prefix="$(STAGING_DIR)/usr"

# Their configure is not autotools.
define SCUMMVM_CONFIGURE_CMDS
	(cd $(@D) && rm -f config.cache && \
		$(TARGET_CONFIGURE_OPTS) \
		./configure $(SCUMMVM_CONF_OPTS))
endef

define SCUMMVM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define SCUMMVM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install DESTDIR=$(TARGET_DIR)
endef

$(eval $(generic-package))
