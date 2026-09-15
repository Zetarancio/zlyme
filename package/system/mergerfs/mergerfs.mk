################################################################################
#
# mergerfs
#
################################################################################

# Batocera 43 Storage Manager recipe (trapexit/mergerfs). Knulli scarab
# has no mergerfs package; this is the parts-bin equivalent.
MERGERFS_VERSION = 2.40.2
MERGERFS_SITE = https://github.com/trapexit/mergerfs.git
MERGERFS_SITE_METHOD = git
MERGERFS_GIT_SUBMODULES = YES
MERGERFS_LICENSE = ISC
MERGERFS_LICENSE_FILES = LICENSE
MERGERFS_DEPENDENCIES = host-pkgconf

MERGERFS_LDFLAGS = $(TARGET_LDFLAGS)
MERGERFS_CXXFLAGS = $(TARGET_CXXFLAGS) -O2 -fno-plt -fPIC

ifeq ($(BR2_STATIC_LIBS),y)
MERGERFS_LDFLAGS += -static
endif

define MERGERFS_BUILD_CMDS
	printf '%s\n' $(MERGERFS_VERSION) > $(@D)/VERSION
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR)" LD="$(TARGET_LD)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		CXXFLAGS="$(MERGERFS_CXXFLAGS)" \
		LDFLAGS="$(MERGERFS_LDFLAGS)" \
		mergerfs
endef

define MERGERFS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/mergerfs $(TARGET_DIR)/usr/bin/mergerfs
endef

$(eval $(generic-package))
