################################################################################
#
# portmaster-xml2-compat
#
# libxml2 2.13.9 is the last release whose SONAME is libxml2.so.2.
# 2.14 renamed that to libxml2.so.16. X-Moto needs libxml2.so.2 and
# the versioned symbol LIBXML2_2.4.30. Zlyme's system libxml2 is 2.15
# and exports those names without that version node, so a symlink is
# not that library.
#
# ROCKNIX/packages 691f24bceb72228f20d41ddb4a1e76ed76a1b0b8 ships a
# libxml2.so.2 inside compat.tar.gz (SHA-256
# 4eba88bf7fef74489fc7d113005aec5b335519a8901e776f7d6203bbcc58b791).
# That archive has no license, no upstream version, and no source
# recipe. It is not installed.
#
################################################################################

PORTMASTER_XML2_COMPAT_VERSION = 2.13.9
PORTMASTER_XML2_COMPAT_SOURCE = libxml2-$(PORTMASTER_XML2_COMPAT_VERSION).tar.xz
PORTMASTER_XML2_COMPAT_SITE = https://download.gnome.org/sources/libxml2/2.13
PORTMASTER_XML2_COMPAT_LICENSE = MIT
PORTMASTER_XML2_COMPAT_LICENSE_FILES = Copyright
PORTMASTER_XML2_COMPAT_DEPENDENCIES = host-pkgconf zlib
PORTMASTER_XML2_COMPAT_INSTALL_STAGING = NO

# --with-zlib is off by default. ICU and Python stay off so this
# library does not depend on libicuuc or a Python runtime.
PORTMASTER_XML2_COMPAT_CONF_OPTS = \
	--without-python \
	--without-icu \
	--without-lzma \
	--without-http \
	--with-zlib \
	--libdir=/usr/lib/compat

define PORTMASTER_XML2_COMPAT_INSTALL_TARGET_CMDS
	$(MAKE) -C $(@D) DESTDIR=$(@D)/compat-root install
	sh $(PORTMASTER_XML2_COMPAT_PKGDIR)/install-compat-libs.sh \
		$(TARGET_DIR) $(@D)/compat-root
	test ! -e $(TARGET_DIR)/usr/lib/libxml2.so.2; \
	test ! -e $(TARGET_DIR)/usr/lib/compat/libxml2.so; \
	readlink $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'libxml2\.so\.2\.' ; \
	"$(TARGET_CROSS)readelf" -h $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'AArch64'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'SONAME.*\[libxml2\.so\.2\]'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'NEEDED.*\[libz\.so\.1\]'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'libicu' && exit 1 || true; \
	"$(TARGET_CROSS)nm" -D $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'xmlParseFile@@LIBXML2_2.4.30'; \
	"$(TARGET_CROSS)nm" -D $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'xmlFreeDoc@@LIBXML2_2.4.30'; \
	"$(TARGET_CROSS)nm" -D $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'xmlGetProp@@LIBXML2_2.4.30'; \
	"$(TARGET_CROSS)nm" -D $(TARGET_DIR)/usr/lib/compat/libxml2.so.2 | grep -q 'xmlStrcmp@@LIBXML2_2.4.30'
endef

$(eval $(autotools-package))
