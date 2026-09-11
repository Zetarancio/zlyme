################################################################################
#
# portmaster
#
# PortMaster-GUI zip. The Tools pak is the launcher.
################################################################################

PORTMASTER_VERSION = 2026.05.04-1202
PORTMASTER_SOURCE = PortMaster.zip
PORTMASTER_SITE = https://github.com/PortsMaster/PortMaster-GUI/releases/download/$(PORTMASTER_VERSION)
PORTMASTER_LICENSE = MIT
PORTMASTER_DEPENDENCIES = python3 box64

define PORTMASTER_EXTRACT_CMDS
	mkdir -p $(@D)
	$(UNZIP) -q -o $(PORTMASTER_DL_DIR)/$(PORTMASTER_SOURCE) -d $(@D)
endef

define PORTMASTER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/portmaster
	cp -a $(@D)/. $(TARGET_DIR)/usr/share/portmaster/
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/portmaster-launch \
		$(TARGET_DIR)/usr/bin/portmaster
endef

$(eval $(generic-package))
