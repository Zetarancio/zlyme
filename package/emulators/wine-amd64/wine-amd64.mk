################################################################################
#
# wine-amd64
#
# Kron4ek prebuilt x86_64 Wine. Lives under /usr/lib/wine-amd64 so it
# does not mix with aarch64 /usr/lib. box64 runs the loader.
#
################################################################################

WINE_AMD64_VERSION = 11.0
WINE_AMD64_SOURCE = wine-$(WINE_AMD64_VERSION)-amd64.tar.xz
WINE_AMD64_SITE = https://github.com/Kron4ek/Wine-Builds/releases/download/$(WINE_AMD64_VERSION)
WINE_AMD64_LICENSE = LGPL-2.1+
WINE_AMD64_DEPENDENCIES = box64 libxkbcommon

# external.mk is included after package/*/*.mk, so this runs after
# upstream libxkbcommon has set -Denable-xkbregistry=false. Wine's
# winewayland.so needs that library. libxml2 is the registry parser.
# Do not enable the X11 backend.
LIBXKBCOMMON_CONF_OPTS := $(filter-out -Denable-xkbregistry=false,$(LIBXKBCOMMON_CONF_OPTS))
LIBXKBCOMMON_CONF_OPTS += -Denable-xkbregistry=true
LIBXKBCOMMON_DEPENDENCIES += libxml2
WINE_AMD64_STRIP_COMPONENTS = 1
# Kron4ek tree is x86_64 + i386; box64 runs it. Same idiom as Knulli's
# python-adafruit-blinka (Buildroot check-bin-arch -i).
WINE_AMD64_BIN_ARCH_EXCLUDE = /usr/lib/wine-amd64

define WINE_AMD64_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/wine-amd64
	cp -a $(@D)/bin $(@D)/lib $(@D)/share $(TARGET_DIR)/usr/lib/wine-amd64/
	$(INSTALL) -D -m 0755 $(WINE_AMD64_PKGDIR)/wine.sh \
		$(TARGET_DIR)/usr/bin/wine
	$(INSTALL) -D -m 0755 $(WINE_AMD64_PKGDIR)/wineserver.sh \
		$(TARGET_DIR)/usr/bin/wineserver
	$(INSTALL) -D -m 0755 $(WINE_AMD64_PKGDIR)/zlyme-wine-prefix \
		$(TARGET_DIR)/usr/sbin/zlyme-wine-prefix
	# Do not symlink ntdll.so into lib/wine/. Wine 11 finds PE
	# builtins next to unix ntdll (../x86_64-windows). A parent
	# ntdll.so makes it look in lib/x86_64-windows instead.
endef

$(eval $(generic-package))
