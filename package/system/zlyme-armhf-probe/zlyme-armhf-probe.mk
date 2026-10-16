################################################################################
#
# zlyme-armhf-probe
#
# Dynamically linked ARMHF program for the separate sysroot. Not part of
# the AArch64 rootfs.
#
################################################################################

ZLYME_ARMHF_PROBE_VERSION = local
ZLYME_ARMHF_PROBE_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-armhf-probe
ZLYME_ARMHF_PROBE_SITE_METHOD = local
ZLYME_ARMHF_PROBE_LICENSE = MIT
ZLYME_ARMHF_PROBE_LICENSE_FILES = LICENSE

define ZLYME_ARMHF_PROBE_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror \
		-o $(@D)/zlyme-armhf-probe $(@D)/probe.c
endef

define ZLYME_ARMHF_PROBE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-armhf-probe \
		$(TARGET_DIR)/usr/bin/zlyme-armhf-probe
endef

$(eval $(generic-package))
