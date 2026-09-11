################################################################################
#
# zmusic
#
################################################################################

ZMUSIC_VERSION = 1.1.14
ZMUSIC_SITE = $(call github,ZDoom,ZMusic,$(ZMUSIC_VERSION))
ZMUSIC_LICENSE = GPL-3.0
ZMUSIC_INSTALL_STAGING = YES
ZMUSIC_DEPENDENCIES = alsa-lib fluidsynth libglib2 libsndfile mpg123 zlib
ZMUSIC_SUPPORTS_IN_SOURCE_BUILD = NO

ZMUSIC_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
ZMUSIC_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5

$(eval $(cmake-package))
