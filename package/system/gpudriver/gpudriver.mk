################################################################################
#
# gpudriver
#
# Load panfrost or mali_kbase at boot. Default panfrost.
################################################################################

GPUDRIVER_VERSION = local
GPUDRIVER_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/gpudriver
GPUDRIVER_SITE_METHOD = local
GPUDRIVER_LICENSE = GPL-2.0

define GPUDRIVER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(GPUDRIVER_PKGDIR)/gpudriver \
		$(TARGET_DIR)/usr/sbin/gpudriver
	$(INSTALL) -D -m 0755 $(GPUDRIVER_PKGDIR)/S12gpudriver \
		$(TARGET_DIR)/etc/init.d/S12gpudriver
endef

$(eval $(generic-package))
