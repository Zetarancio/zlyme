################################################################################
#
# music-player
#
# nborodikhin/nextui-music-player v1.17.0
# commit a77cdf69cd19e3313dc2b906e19b5be34715375a
# Built with the Zlyme toolchain. GLES comes from pkg-config glesv2
# (-lGLESv2), not libmali. Audio is SDL. The pak launcher disables
# the in-app updater and does not write cpufreq.
#
################################################################################

MUSIC_PLAYER_VERSION = 1.17.0
MUSIC_PLAYER_SITE = https://github.com/nborodikhin/nextui-music-player/archive/refs/tags
MUSIC_PLAYER_SOURCE = v$(MUSIC_PLAYER_VERSION).tar.gz
MUSIC_PLAYER_LICENSE = MIT
MUSIC_PLAYER_LICENSE_FILES = LICENSE
MUSIC_PLAYER_DEPENDENCIES = nextui sdl2 sdl2_image sdl2_ttf fdk-aac libzip \
	libsamplerate alsa-lib

define MUSIC_PLAYER_BUILD_CMDS
	sed -i '/-ltinyalsa/d' $(@D)/src/Makefile
	sed -i 's|all/common/scaler.c|all/common/scaler.c $$(NEXTUI_ROOT)/all/common/palette.c|' \
		$(@D)/src/Makefile
	$(TARGET_MAKE_ENV) \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig" \
	$(MAKE) -C $(@D)/src PLATFORM=my355 KIND=release \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		PREFIX="$(STAGING_DIR)/usr" \
		PREFIX_LOCAL="$(STAGING_DIR)/usr" \
		NEXTUI_ROOT="$(NEXTUI_DIR)/workspace"
endef

define MUSIC_PLAYER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/my355/musicplayer.elf \
		$(TARGET_DIR)/usr/lib/zlyme/music-player/musicplayer.elf
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/music-player/LICENSE
endef

$(eval $(generic-package))
