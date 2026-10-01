################################################################################
#
# ruffle-handheld
#
# SilverPsychoo/Ruffle-Handheld v4.2
# (d6e6e4527e97e6d25ba034de29754086a3eb5a9b).
# Upstream appliance. The emulator binary is not patched.
# MIT, plus bundled Ruffle MIT OR Apache-2.0.
#
################################################################################

RUFFLE_HANDHELD_VERSION = 4.2
RUFFLE_HANDHELD_SITE = https://github.com/SilverPsychoo/Ruffle-Handheld/releases/download/v$(RUFFLE_HANDHELD_VERSION)
RUFFLE_HANDHELD_SOURCE = Ruffle-Handheld.zip
RUFFLE_HANDHELD_LICENSE = MIT, MIT OR Apache-2.0
RUFFLE_HANDHELD_LICENSE_FILES = \
	rufflehandheld/licenses/LICENSE.Ruffle-Handheld.txt \
	rufflehandheld/licenses/THIRD_PARTY.txt

define RUFFLE_HANDHELD_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/share/zlyme/rufflehandheld
	mkdir -p $(TARGET_DIR)/usr/share/zlyme
	cp -a $(@D)/rufflehandheld $(TARGET_DIR)/usr/share/zlyme/rufflehandheld
	rm -f $(TARGET_DIR)/usr/share/zlyme/rufflehandheld/setup.sh \
		$(TARGET_DIR)/usr/share/zlyme/rufflehandheld/core-install.sh
	rm -rf $(TARGET_DIR)/usr/share/zlyme/rufflehandheld/logs
	ln -s /storage/.config/zlyme/ruffle/logs \
		$(TARGET_DIR)/usr/share/zlyme/rufflehandheld/logs
endef

$(eval $(generic-package))
