################################################################################
#
# libmali
#
# JeffyCN/mirrors 4233031, bifrost-g52 g29p1. Files in /usr/lib/mali.
# The fat (non -gles) blob exports GLES and Vulkan. ICD JSON is installed
# for vulkan-loader; gpudriver / zlyme-gpu-env.sh pick it when gpu=libmali.
################################################################################

LIBMALI_VERSION = 4233031d818e97a19e8a9cdbbd5c15795ededd93
LIBMALI_SITE = $(call github,JeffyCN,mirrors,$(LIBMALI_VERSION))
LIBMALI_LICENSE = Proprietary
LIBMALI_DEPENDENCIES = libdrm

LIBMALI_SO = libmali-bifrost-g52-g29p1.so

define LIBMALI_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/mali
	if [ -f $(@D)/$(LIBMALI_SO) ]; then \
		$(INSTALL) -m 0755 $(@D)/$(LIBMALI_SO) \
			$(TARGET_DIR)/usr/lib/mali/$(LIBMALI_SO); \
	else \
		$(INSTALL) -m 0755 $(@D)/lib/aarch64-linux-gnu/$(LIBMALI_SO) \
			$(TARGET_DIR)/usr/lib/mali/$(LIBMALI_SO) 2>/dev/null || \
		find $(@D) -name '$(LIBMALI_SO)' -exec \
			$(INSTALL) -m 0755 {} $(TARGET_DIR)/usr/lib/mali/$(LIBMALI_SO) \;; \
	fi
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libEGL.so
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libEGL.so.1
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libGLESv1_CM.so
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libGLESv1_CM.so.1
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libGLESv2.so
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libGLESv2.so.2
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libgbm.so
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libgbm.so.1
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libmali.so.1
	ln -sf $(LIBMALI_SO) $(TARGET_DIR)/usr/lib/mali/libMaliVulkan.so
	$(INSTALL) -D -m 0644 $(LIBMALI_PKGDIR)/mali_icd.json \
		$(TARGET_DIR)/usr/share/vulkan/icd.d/mali_icd.json
endef

$(eval $(generic-package))
