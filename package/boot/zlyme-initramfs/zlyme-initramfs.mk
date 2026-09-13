################################################################################
#
# zlyme-initramfs
#
# Tiny static busybox + /init, harvested from Knulli knulli-initramfs
# (busybox 1.36.1). Installed as a directory; the kernel packs it via
# CONFIG_INITRAMFS_SOURCE (see external.mk LINUX_PRE_BUILD_HOOKS).
#
################################################################################

ZLYME_INITRAMFS_VERSION = 1.36.1
ZLYME_INITRAMFS_SITE = https://busybox.net/downloads
ZLYME_INITRAMFS_SOURCE = busybox-$(ZLYME_INITRAMFS_VERSION).tar.bz2
ZLYME_INITRAMFS_LICENSE = GPL-2.0
ZLYME_INITRAMFS_LICENSE_FILES = LICENSE
ZLYME_INITRAMFS_DEPENDENCIES = libxcrypt

ZLYME_INITRAMFS_CFLAGS = $(TARGET_CFLAGS)
ZLYME_INITRAMFS_LDFLAGS = $(TARGET_LDFLAGS)

ZLYME_INITRAMFS_KCONFIG_FILE = $(ZLYME_INITRAMFS_PKGDIR)/busybox.config

# Do not name this ZLYME_INITRAMFS_DIR: Buildroot uses that for the
# extract directory (Knulli uses INITRAMFS_DIR for the same reason).
INITRAMFS_DIR = $(BINARIES_DIR)/initramfs

ZLYME_INITRAMFS_MAKE_ENV = \
	$(TARGET_MAKE_ENV) \
	CFLAGS="$(ZLYME_INITRAMFS_CFLAGS)"
ZLYME_INITRAMFS_MAKE_OPTS = \
	CC="$(TARGET_CC)" \
	ARCH=$(KERNEL_ARCH) \
	PREFIX="$(INITRAMFS_DIR)" \
	EXTRA_LDFLAGS="$(ZLYME_INITRAMFS_LDFLAGS)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	CONFIG_PREFIX="$(INITRAMFS_DIR)" \
	SKIP_STRIP=n

ZLYME_INITRAMFS_KCONFIG_OPTS = $(ZLYME_INITRAMFS_MAKE_OPTS)

define ZLYME_INITRAMFS_BUILD_CMDS
	$(ZLYME_INITRAMFS_MAKE_ENV) $(MAKE) $(ZLYME_INITRAMFS_MAKE_OPTS) -C $(@D)
endef

define ZLYME_INITRAMFS_INSTALL_TARGET_CMDS
	rm -rf $(INITRAMFS_DIR)
	mkdir -p $(INITRAMFS_DIR)
	$(INSTALL) -D -m 0755 $(ZLYME_INITRAMFS_PKGDIR)/init \
		$(INITRAMFS_DIR)/init
	$(ZLYME_INITRAMFS_MAKE_ENV) $(MAKE) $(ZLYME_INITRAMFS_MAKE_OPTS) -C $(@D) install
	$(TARGET_CC) -static -Os -o $(INITRAMFS_DIR)/zlyme-splash \
		$(ZLYME_INITRAMFS_PKGDIR)/splash.c
	$(INSTALL) -D -m 0644 $(ZLYME_INITRAMFS_PKGDIR)/splash.rgb565 \
		$(INITRAMFS_DIR)/splash.rgb565
	mkdir -p $(INITRAMFS_DIR)/proc \
		$(INITRAMFS_DIR)/sys \
		$(INITRAMFS_DIR)/dev \
		$(INITRAMFS_DIR)/boot_root \
		$(INITRAMFS_DIR)/storage_root \
		$(INITRAMFS_DIR)/new_root
endef

$(eval $(kconfig-package))
