################################################################################
#
# music-player
#
# nborodikhin/nextui-music-player v1.17.0
# commit a77cdf69cd19e3313dc2b906e19b5be34715375a
# MIT. The release binary is the pinned build. Zlyme does not ship its
# cpufreq launch.sh or its restart-after-update loop.
# libfdk-aac.so.1 comes from that same archive (Fraunhofer FDK AAC).
#
################################################################################

MUSIC_PLAYER_VERSION = 1.17.0
MUSIC_PLAYER_SITE = https://github.com/nborodikhin/nextui-music-player/releases/download/v$(MUSIC_PLAYER_VERSION)
MUSIC_PLAYER_SOURCE = Music.Player.pak.zip
MUSIC_PLAYER_LICENSE = MIT, Fraunhofer-FDK-AAC
MUSIC_PLAYER_LICENSE_FILES = LICENSE FDK-AAC-NOTICE

define MUSIC_PLAYER_COPY_LICENSE
	cp $(MUSIC_PLAYER_PKGDIR)/LICENSE $(@D)/LICENSE
	cp $(MUSIC_PLAYER_PKGDIR)/FDK-AAC-NOTICE $(@D)/FDK-AAC-NOTICE
endef
MUSIC_PLAYER_POST_EXTRACT_HOOKS += MUSIC_PLAYER_COPY_LICENSE

define MUSIC_PLAYER_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -shared -fPIC \
		-Wl,-soname,libmali_hook.so.1 \
		-o $(@D)/libmali_hook.so.1 \
		$(MUSIC_PLAYER_PKGDIR)/mali_hook.c
	$(TARGET_CC) $(TARGET_CFLAGS) -shared -fPIC \
		-Wl,-soname,libtinyalsa.so.2 \
		-o $(@D)/libtinyalsa.so.2 \
		$(MUSIC_PLAYER_PKGDIR)/tinyalsa_soname.c
endef

define MUSIC_PLAYER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/my355/musicplayer.elf \
		$(TARGET_DIR)/usr/lib/zlyme/music-player/musicplayer.elf
	$(INSTALL) -D -m 0755 $(@D)/bin/my355/libfdk-aac.so.1 \
		$(TARGET_DIR)/usr/lib/zlyme/music-player/libfdk-aac.so.1
	$(INSTALL) -D -m 0755 $(@D)/libmali_hook.so.1 \
		$(TARGET_DIR)/usr/lib/zlyme/music-player/libmali_hook.so.1
	$(INSTALL) -D -m 0755 $(@D)/libtinyalsa.so.2 \
		$(TARGET_DIR)/usr/lib/zlyme/music-player/libtinyalsa.so.2
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/music-player/LICENSE
	$(INSTALL) -D -m 0644 $(@D)/FDK-AAC-NOTICE \
		$(TARGET_DIR)/usr/share/licenses/music-player/FDK-AAC-NOTICE
endef

$(eval $(generic-package))
