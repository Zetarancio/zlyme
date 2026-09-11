################################################################################
#
# rtl8723fu-firmware
#
# BT firmware for the RTL8733BU. Not in linux-firmware.
# Kernel loads rtl_bt/rtl8723fu_{fw,config}.bin (see btrtl patch 0005).
################################################################################

RTL8723FU_FIRMWARE_VERSION = local
RTL8723FU_FIRMWARE_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/drivers/rtl8723fu-firmware/rtl_bt
RTL8723FU_FIRMWARE_SITE_METHOD = local
RTL8723FU_FIRMWARE_LICENSE = PROPRIETARY
RTL8723FU_FIRMWARE_REDISTRIBUTE = NO

define RTL8723FU_FIRMWARE_INSTALL_TARGET_CMDS
	$(foreach f,rtl8723fu_fw.bin rtl8723fu_config.bin, \
		$(INSTALL) -D -m 0644 $(@D)/$(f) \
			$(TARGET_DIR)/lib/firmware/rtl_bt/$(f)$(sep))
endef

$(eval $(generic-package))
