################################################################################
#
# zlyme-armhf-runtime
#
# Installs the loader and /usr/lib/zlyme-armhf from the side sysroot.
# The version is the manifest hash, so a new sysroot invalidates this
# package. A missing manifest fails the build. This recipe does not
# start Buildroot or Docker.
#
################################################################################

ZLYME_ARMHF_RUNTIME_MANIFEST = /zlyme/armhf/zlyme-armhf-runtime.manifest
ZLYME_ARMHF_RUNTIME_VERSION = $(shell \
	if [ -f $(ZLYME_ARMHF_RUNTIME_MANIFEST) ]; then \
		sha256sum $(ZLYME_ARMHF_RUNTIME_MANIFEST) | awk '{print $$1}'; \
	else \
		echo missing; \
	fi)
ZLYME_ARMHF_RUNTIME_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-armhf-runtime
ZLYME_ARMHF_RUNTIME_SITE_METHOD = local
ZLYME_ARMHF_RUNTIME_LICENSE = LGPL-2.1+ GPL-2.0+ GPL-3.0-or-later WITH GCC-exception-3.1
ZLYME_ARMHF_RUNTIME_LICENSE_FILES = LICENSE
# These files are ARM, on purpose. Buildroot's target check expects
# AArch64. The exclude is this package only.
ZLYME_ARMHF_RUNTIME_BIN_ARCH_EXCLUDE = /usr/lib/zlyme-armhf /lib

define ZLYME_ARMHF_RUNTIME_BUILD_CMDS
	$(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-armhf-runtime/check-manifest.sh /zlyme/armhf
endef

define ZLYME_ARMHF_RUNTIME_INSTALL_TARGET_CMDS
	ZLYME_ARMHF_SYSROOT=/zlyme/armhf/target \
		$(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-armhf-runtime/stage-runtime.sh \
		$(TARGET_DIR)
endef

$(eval $(generic-package))
