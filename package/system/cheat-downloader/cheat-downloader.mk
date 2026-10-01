################################################################################
#
# cheat-downloader
#
# nborodikhin/nextui-cheat-downloader-alt v1.6.0
# commit 4e673432cb3e92c8a34907cf5740aafacbbc3f47
# MIT. The my355 release binary is AArch64 despite its bin/arm path.
# minui-list and minui-presenter are the image copies, not the zip's.
# The Libretro cheat database is downloaded at runtime, not packaged.
#
################################################################################

CHEAT_DOWNLOADER_VERSION = 1.6.0
CHEAT_DOWNLOADER_SITE = https://github.com/nborodikhin/nextui-cheat-downloader-alt/releases/download/v$(CHEAT_DOWNLOADER_VERSION)
CHEAT_DOWNLOADER_SOURCE = CheatDownloaderOffline-my355.pak.zip
CHEAT_DOWNLOADER_LICENSE = MIT
CHEAT_DOWNLOADER_LICENSE_FILES = LICENSE

define CHEAT_DOWNLOADER_COPY_LICENSE
	cp $(CHEAT_DOWNLOADER_PKGDIR)/LICENSE $(@D)/LICENSE
endef
CHEAT_DOWNLOADER_POST_EXTRACT_HOOKS += CHEAT_DOWNLOADER_COPY_LICENSE

define CHEAT_DOWNLOADER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		"$(@D)/Cheat Downloader Offline.pak/bin/arm/cheat_manager" \
		$(TARGET_DIR)/usr/lib/zlyme/cheat-downloader/cheat_manager
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/cheat-downloader/LICENSE
endef

$(eval $(generic-package))
