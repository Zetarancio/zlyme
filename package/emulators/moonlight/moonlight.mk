################################################################################
#
# moonlight (moonlight-embedded)
#
################################################################################

MOONLIGHT_VERSION = a6bf7154a743d4f74a1b377e730f188352a1b80c
MOONLIGHT_SITE = https://github.com/moonlight-stream/moonlight-embedded
MOONLIGHT_SITE_METHOD = git
MOONLIGHT_GIT_SUBMODULES = YES
MOONLIGHT_LICENSE = GPL-3.0
MOONLIGHT_LICENSE_FILES = LICENSE
MOONLIGHT_SUPPORTS_IN_SOURCE_BUILD = NO

MOONLIGHT_DEPENDENCIES = \
	opus libevdev libudev-zero avahi alsa-lib libcurl enet ffmpeg sdl2

MOONLIGHT_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
MOONLIGHT_CONF_OPTS += -DENABLE_CEC=OFF
MOONLIGHT_CONF_OPTS += -DENABLE_X11=OFF
MOONLIGHT_CONF_OPTS += -DCMAKE_INSTALL_SYSCONFDIR=/etc
MOONLIGHT_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5

define MOONLIGHT_INSTALL_CONF
	mkdir -p $(TARGET_DIR)/usr/share/moonlight
	$(INSTALL) -m 0644 $(MOONLIGHT_PKGDIR)/moonlight.conf \
		$(TARGET_DIR)/usr/share/moonlight/moonlight.conf
endef
MOONLIGHT_POST_INSTALL_TARGET_HOOKS += MOONLIGHT_INSTALL_CONF

$(eval $(cmake-package))
