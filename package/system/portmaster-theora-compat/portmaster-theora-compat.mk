################################################################################
#
# portmaster-theora-compat
#
# Xiph libtheora 1.1.1 decoder only. LÖVE 11.5 needs SONAME
# libtheoradec.so.1. Zlyme's system libtheora is 1.2 and keeps
# SONAME libtheoradec.so.2. The 1.1.1 release added --disable-encode.
# That still installs a stub libtheoraenc and the combined libtheora
# into the package's own DESTDIR. The target copy is only
# libtheoradec.so.1 and libtheoradec.so.1.1.4. The decoder does not
# link libogg; LÖVE links the system libogg itself. libogg stays a
# build dependency because configure looks for it. The .so.1 name is
# the real 1.1.1 library, not a symlink to .so.2.
#
################################################################################

PORTMASTER_THEORA_COMPAT_VERSION = 1.1.1
PORTMASTER_THEORA_COMPAT_SOURCE = libtheora-$(PORTMASTER_THEORA_COMPAT_VERSION).tar.xz
PORTMASTER_THEORA_COMPAT_SITE = https://downloads.xiph.org/releases/theora
PORTMASTER_THEORA_COMPAT_LICENSE = BSD-3-Clause
PORTMASTER_THEORA_COMPAT_LICENSE_FILES = COPYING LICENSE
PORTMASTER_THEORA_COMPAT_DEPENDENCIES = host-pkgconf libogg
# The 2009 config.sub does not know aarch64. Use Buildroot's copy.
PORTMASTER_THEORA_COMPAT_INSTALL_STAGING = NO

PORTMASTER_THEORA_COMPAT_CONF_OPTS = \
	--disable-encode \
	--disable-examples \
	--disable-spec \
	--disable-oggtest \
	--disable-vorbistest \
	--disable-sdltest \
	--libdir=/usr/lib/compat

define PORTMASTER_THEORA_COMPAT_UPDATE_CONFIG
	cp -f $(TOPDIR)/support/gnuconfig/config.sub $(@D)/config.sub
	cp -f $(TOPDIR)/support/gnuconfig/config.guess $(@D)/config.guess
endef
PORTMASTER_THEORA_COMPAT_PRE_CONFIGURE_HOOKS += PORTMASTER_THEORA_COMPAT_UPDATE_CONFIG

# make install relinks libtool's build-directory RPATH away. Copy only
# the decoder SONAME and its versioned target into the target tree.
# Do not remove /usr/lib/compat: other compat libraries may live there.
define PORTMASTER_THEORA_COMPAT_INSTALL_TARGET_CMDS
	$(MAKE) -C $(@D) DESTDIR=$(@D)/compat-root install
	sh $(PORTMASTER_THEORA_COMPAT_PKGDIR)install-compat-libs.sh \
		$(TARGET_DIR) $(@D)/compat-root
	test ! -e $(TARGET_DIR)/usr/lib/compat/libtheoradec.so; \
	test ! -e $(TARGET_DIR)/usr/lib/compat/libtheoraenc.so.1; \
	test ! -e $(TARGET_DIR)/usr/lib/compat/libtheora.so.0; \
	test ! -e $(TARGET_DIR)/usr/lib/libtheoradec.so.1; \
	test -e $(TARGET_DIR)/usr/lib/libtheoradec.so.2; \
	readlink $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -q '\.so\.2' && exit 1 || true; \
	"$(TARGET_CROSS)readelf" -h $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -q 'AArch64'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -q 'SONAME.*\[libtheoradec\.so\.1\]'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -q 'NEEDED.*\[libc\.so\.6\]'; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -E 'NEEDED' | grep -q '/' && exit 1 || true; \
	"$(TARGET_CROSS)readelf" -d $(TARGET_DIR)/usr/lib/compat/libtheoradec.so.1 | grep -q 'libtheoradec\.so\.2' && exit 1 || true
endef

$(eval $(autotools-package))
