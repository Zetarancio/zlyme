################################################################################
#
# rtl8733bu-power
#
# Enable GPIO for the combo chip (GPIO0_A0, active low). Two rfkill
# devices; power drops only when both are blocked.
################################################################################

# Local source. SITE is src/ so the .mk is not copied into the build tree.
RTL8733BU_POWER_VERSION = local
RTL8733BU_POWER_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/drivers/rtl8733bu-power/src
RTL8733BU_POWER_SITE_METHOD = local
RTL8733BU_POWER_LICENSE = GPL-2.0
RTL8733BU_POWER_LICENSE_FILES = LICENSE

# DTS: compatible "rockchip,rtl8733bu-power", enable-gpios GPIO0_A0 active-low.

$(eval $(kernel-module))
$(eval $(generic-package))
