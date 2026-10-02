################################################################################
#
# scrapegoat
#
# Helaas/nextui-scrapegoat-pak v2.3.0
# commit c52f749eae21a4c02c767e485fef2abbb773f2d7
# MIT. Built with the Zlyme toolchain and the vendored Apostrophe
# headers (my355 pad map, no cpufreq writes).
#
# ScreenScraper developer credentials are compile-time -D flags.
# They are not in this repository. If package/system/zcrapegoat/credentials.local
# exists, it may set SCREENSCRAPER_DEV_ID and SCREENSCRAPER_DEV_PASSWORD
# for a local build. A missing file still builds; the binary then has
# empty developer credentials and warns at startup. Do not commit that file.
# User ScreenScraper accounts are optional and only raise the request rate.
#
################################################################################

ZCRAPEGOAT_VERSION = c52f749eae21a4c02c767e485fef2abbb773f2d7
ZCRAPEGOAT_SITE = $(ZCRAPEGOAT_PKGDIR)/src
ZCRAPEGOAT_SITE_METHOD = local
ZCRAPEGOAT_LICENSE = MIT
ZCRAPEGOAT_LICENSE_FILES = LICENSE
ZCRAPEGOAT_DEPENDENCIES = sdl2 sdl2_ttf sdl2_image libcurl openssl zlib

ZCRAPEGOAT_CREDENTIALS = $(ZCRAPEGOAT_PKGDIR)/credentials.local

define ZCRAPEGOAT_BUILD_CMDS
	defs=""; \
	if [ -f $(ZCRAPEGOAT_CREDENTIALS) ]; then \
		. $(ZCRAPEGOAT_CREDENTIALS); \
		if [ -n "$${SCREENSCRAPER_DEV_ID:-}" ]; then \
			defs="$$defs -DSCREENSCRAPER_DEV_ID=\\\"$$SCREENSCRAPER_DEV_ID\\\""; \
		fi; \
		if [ -n "$${SCREENSCRAPER_DEV_PASSWORD:-}" ]; then \
			defs="$$defs -DSCREENSCRAPER_DEV_PASSWORD=\\\"$$SCREENSCRAPER_DEV_PASSWORD\\\""; \
		fi; \
	fi; \
	$(TARGET_MAKE_ENV) \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig" \
	$(TARGET_CC) $(TARGET_CFLAGS) -std=gnu11 -Wall -Wextra -Wno-unused-parameter \
		-DPLATFORM_MY355 -DAP_ENABLE_CURL $$defs \
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
	$(TARGET_STRIP) $(@D)/zcrapegoat
endef

define ZCRAPEGOAT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zcrapegoat \
		$(TARGET_DIR)/usr/lib/zlyme/zcrapegoat/zcrapegoat
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/zcrapegoat/LICENSE
endef

$(eval $(generic-package))
