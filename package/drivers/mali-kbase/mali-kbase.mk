################################################################################
#
# mali-kbase
#
# Out-of-tree mali_kbase for RK3566. Pin must match kernel 7.0.2.
################################################################################

MALI_KBASE_VERSION = 39da994bb6fc8819e5e8c1873907dd21d17e53c1
MALI_KBASE_SITE = $(call github,rocknix,mali_kbase,$(MALI_KBASE_VERSION))
MALI_KBASE_LICENSE = GPL-2.0
MALI_KBASE_MODULE_SUBDIRS = product/kernel/drivers/gpu/arm/midgard
MALI_KBASE_MODULE_MAKE_OPTS = \
	CONFIG_MALI_MIDGARD=m \
	CONFIG_MALI_PLATFORM_NAME=devicetree \
	CONFIG_MALI_REAL_HW=y \
	CONFIG_MALI_DEVFREQ=y \
	CONFIG_MALI_GATOR_SUPPORT=y

$(eval $(kernel-module))
$(eval $(generic-package))
