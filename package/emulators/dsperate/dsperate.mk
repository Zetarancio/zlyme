################################################################################
#
# dsperate
#
# v3.4.0 is tag aabc4b065afaf582cbc43c16d579de431b808d57.
# GPL-3.0-or-later. No DraStic source is in that tree.
#
################################################################################

DSPERATE_VERSION = aabc4b065afaf582cbc43c16d579de431b808d57
DSPERATE_SITE = https://github.com/beebono/DSperate.git
DSPERATE_SITE_METHOD = git
# The emulator is GPL-3.0-or-later. FreeBIOS is the BSD-2-Clause notice in
# src/core/bios/LICENSE.freebios. The DSi stand-in fonts keep the OFL for
# the Noto glyphs and the GPL-3.0-or-later font exception for WenQuanYi.
# Zip inflation is the vendored MIT miniz. 0001 does not link
# usrcheat-analog.dat. Upstream says that file is not GPL.
DSPERATE_LICENSE = GPL-3.0-or-later, BSD-2-Clause, OFL-1.1, MIT
DSPERATE_LICENSE_FILES = \
	LICENSE \
	src/core/bios/LICENSE.freebios \
	src/core/io/dsi_font/LICENSE-NotoSans-OFL-1.1.txt \
	src/core/io/dsi_font/LICENSE-WenQuanYi-MicroHei.txt \
	src/core/cart/miniz/LICENSE
DSPERATE_DEPENDENCIES = sdl2 alsa-lib
DSPERATE_SUPPORTS_IN_SOURCE_BUILD = NO

# The launcher asks for software frames on the KMS sink. Vulkan and GLES
# default on upstream and would compile when headers are visible. Both stay
# off until a Flip run has shown the software picture. Wayland scanout,
# achievements, networking, and PGO stay off. RGA is a runtime V4L2 path
# and is not requested.
DSPERATE_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
DSPERATE_CONF_OPTS += -DDSPERATE_VERSION=v3.4.0
DSPERATE_CONF_OPTS += -DDSPERATE_JIT=ON
DSPERATE_CONF_OPTS += -DDSPERATE_NEON=ON
DSPERATE_CONF_OPTS += -DDSPERATE_TUNE=-mcpu=cortex-a55
DSPERATE_CONF_OPTS += -DDSPERATE_SDL=ON
DSPERATE_CONF_OPTS += -DDSPERATE_VULKAN=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_GLES=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_TESTS=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_HEADLESS=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_WAYLAND=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_CHEEVOS=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_NET=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_PGO=OFF
DSPERATE_CONF_OPTS += -DDSPERATE_HARDEN=OFF

define DSPERATE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/src/frontend/sdl/dsperate \
		$(TARGET_DIR)/usr/bin/dsperate
	$(INSTALL) -D -m 0755 $(DSPERATE_PKGDIR)/start_dsperate.sh \
		$(TARGET_DIR)/usr/bin/start_dsperate
endef

$(eval $(cmake-package))
