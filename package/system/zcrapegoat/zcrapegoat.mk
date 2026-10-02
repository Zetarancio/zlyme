################################################################################
#
# zcrapegoat
#
# Downstream Zlyme integration of Helaas/nextui-scrapegoat-pak v2.3.0,
# commit c52f749eae21a4c02c767e485fef2abbb773f2d7, MIT.
# The tracked tree is src/. Zlyme changes are commits after the import.
# Apostrophe headers are the vendored Zlyme copy.
#
# Developer credentials are written to a private header under the
# Buildroot build directory. They are not compiler -D values.
# That compile runs with CCACHE_DISABLE=1.
#
################################################################################

ZCRAPEGOAT_VERSION = c52f749eae21a4c02c767e485fef2abbb773f2d7
ZCRAPEGOAT_SITE = $(ZCRAPEGOAT_PKGDIR)/src
ZCRAPEGOAT_SITE_METHOD = local
ZCRAPEGOAT_LICENSE = MIT
ZCRAPEGOAT_LICENSE_FILES = LICENSE
ZCRAPEGOAT_DEPENDENCIES = sdl2 sdl2_ttf sdl2_image libcurl openssl zlib

define ZCRAPEGOAT_BUILD_CMDS
	python3 $(ZCRAPEGOAT_PKGDIR)/gen-credentials-header.py \
		$(@D)/zlyme_credentials.h \
		$(ZCRAPEGOAT_PKGDIR)/credentials.local
	$(TARGET_MAKE_ENV) CCACHE_DISABLE=1 \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig" \
	$(TARGET_CC) $(TARGET_CFLAGS) -std=gnu11 -Wall -Wextra -Wno-unused-parameter \
		-DPLATFORM_MY355 -DAP_ENABLE_CURL \
		-DZCRAPEGOAT_CREDENTIALS_HEADER=\"zlyme_credentials.h\" \
		-I$(@D) \
		-I$(@D)/src \
		-I$(@D)/third_party/cJSON \
		-I$(@D)/third_party/md5 \
		-I$(@D)/third_party/miniz \
		-I$(@D)/third_party/stb \
		-I$(BR2_EXTERNAL_ZLYME_PATH)/package/system/nextui/apostrophe/include \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags sdl2 SDL2_ttf SDL2_image libcurl) \
		-o $(@D)/zcrapegoat \
		$$(find $(@D)/src $(@D)/third_party/cJSON $(@D)/third_party/md5 $(@D)/third_party/miniz -name '*.c' -print | sort) \
		$(TARGET_LDFLAGS) \
		$$($(PKG_CONFIG_HOST_BINARY) --libs sdl2 SDL2_ttf SDL2_image libcurl) \
		-lm -lpthread
	rm -f $(@D)/zlyme_credentials.h
	$(TARGET_STRIP) $(@D)/zcrapegoat
endef

define ZCRAPEGOAT_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/lib/zlyme/scrapegoat
	$(INSTALL) -D -m 0755 $(@D)/zcrapegoat \
		$(TARGET_DIR)/usr/lib/zlyme/zcrapegoat/zcrapegoat
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/zcrapegoat/LICENSE
endef

$(eval $(generic-package))
