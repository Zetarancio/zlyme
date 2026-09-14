################################################################################
#
# liblcf
#
# Knulli package/batocera/emulators/easyrpg/liblcf (Player 0.8.1).
################################################################################

LIBLCF_VERSION = 0.8.1
LIBLCF_LICENSE = MIT
LIBLCF_LICENSE_FILES = COPYING
LIBLCF_SITE = $(call github,EasyRPG,liblcf,$(LIBLCF_VERSION))
LIBLCF_DEPENDENCIES = expat icu inih
LIBLCF_INSTALL_STAGING = YES
LIBLCF_SUPPORTS_IN_SOURCE_BUILD = NO

LIBLCF_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
LIBLCF_CONF_ENV += LDFLAGS="-lpthread -fPIC" CFLAGS="-fPIC" CXXFLAGS="-fPIC"

$(eval $(cmake-package))
