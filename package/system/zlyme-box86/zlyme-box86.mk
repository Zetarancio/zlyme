################################################################################
#
# zlyme-box86
#
################################################################################

# Imports Box86 from the separately built ARMHF target. The artifact
# manifest is the package version so a rebuilt binary invalidates the
# product package without importing the rest of that target tree.

ZLYME_BOX86_MANIFEST = /zlyme/armhf/zlyme-box86.manifest
ZLYME_BOX86_VERSION = $(shell \
	if [ -f $(ZLYME_BOX86_MANIFEST) ]; then \
		sha256sum $(ZLYME_BOX86_MANIFEST) | awk '{print $$1}'; \
	else \
		echo missing; \
	fi)
ZLYME_BOX86_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-box86
ZLYME_BOX86_SITE_METHOD = local
ZLYME_BOX86_LICENSE = MIT
ZLYME_BOX86_LICENSE_FILES = LICENSE
ZLYME_BOX86_DEPENDENCIES = zlyme-armhf-runtime
# Buildroot's exclusion matcher accepts directory prefixes. The package
# file list contains only Box86 and the two POSIX shell selectors here.
ZLYME_BOX86_BIN_ARCH_EXCLUDE = /usr/bin

define ZLYME_BOX86_BUILD_CMDS
	$(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-box86/check-manifest.sh \
		/zlyme/armhf
endef

define ZLYME_BOX86_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 /zlyme/armhf/target/usr/bin/box86 \
		$(TARGET_DIR)/usr/bin/box86
	$(INSTALL) -D -m 0755 $(ZLYME_BOX86_PKGDIR)/zlyme-box86-run \
		$(TARGET_DIR)/usr/bin/zlyme-box86-run
	$(INSTALL) -D -m 0755 $(ZLYME_BOX86_PKGDIR)/zlyme-box86-gl4es-run \
		$(TARGET_DIR)/usr/bin/zlyme-box86-gl4es-run
endef

$(eval $(generic-package))
