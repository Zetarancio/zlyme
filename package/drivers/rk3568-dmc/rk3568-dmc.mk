################################################################################
#
# rk3568-dmc
#
# Local source. The Flip DTS binds rockchip,rk3568-dmc.
#
################################################################################

RK3568_DMC_VERSION = local
RK3568_DMC_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/drivers/rk3568-dmc/src
RK3568_DMC_SITE_METHOD = local
RK3568_DMC_LICENSE = GPL-2.0-only
RK3568_DMC_LICENSE_FILES = LICENSE

$(eval $(kernel-module))
$(eval $(generic-package))
