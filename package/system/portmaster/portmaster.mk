################################################################################
#
# portmaster
#
# Immutable seed: PortMaster-GUI stable zip. The live tree is unpacked on
# the selected library by zlyme-portmaster-prepare, not into this image.
# https://github.com/ben16w/minui-portmaster is TrimUI-only (tg5040,
# /usr/trimui/lib) — not used on Flip. pugwash needs a python3 that
# actually built _ssl/_sqlite3 and ships a .py sysconfigdata (host
# compileall wrote a 3.14 .pyc the target refused).
################################################################################

PORTMASTER_VERSION = 2026.06.23-0015
PORTMASTER_SOURCE = PortMaster.zip
PORTMASTER_SITE = https://github.com/PortsMaster/PortMaster-GUI/releases/download/$(PORTMASTER_VERSION)
PORTMASTER_LICENSE = MIT
PORTMASTER_LICENSE_FILES = LICENSE
PORTMASTER_DEPENDENCIES = python3 box64 openssl sqlite ca-certificates

define PORTMASTER_EXTRACT_CMDS
	mkdir -p $(@D)
	cp -f $(PORTMASTER_DL_DIR)/$(PORTMASTER_SOURCE) $(@D)/PortMaster.zip
	cp -f $(PORTMASTER_PKGDIR)/LICENSE $(@D)/LICENSE
endef

define PORTMASTER_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/share/portmaster/PortMaster
	mkdir -p $(TARGET_DIR)/usr/share/portmaster/zlyme \
		$(TARGET_DIR)/usr/config/PortMaster
	$(INSTALL) -D -m 0644 $(@D)/PortMaster.zip \
		$(TARGET_DIR)/usr/share/portmaster/PortMaster.zip
	$(INSTALL) -D -m 0644 $(PORTMASTER_PKGDIR)/LICENSE \
		$(TARGET_DIR)/usr/share/portmaster/LICENSE
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/portmaster-launch \
		$(TARGET_DIR)/usr/bin/portmaster
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/zlyme-portmaster-cleanup \
		$(TARGET_DIR)/usr/sbin/zlyme-portmaster-cleanup
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/zlyme-portmaster-exec \
		$(TARGET_DIR)/usr/sbin/zlyme-portmaster-exec
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/zlyme-portmaster-prepare \
		$(TARGET_DIR)/usr/sbin/zlyme-portmaster-prepare
	$(INSTALL) -m 0644 $(PORTMASTER_PKGDIR)/control.txt \
		$(TARGET_DIR)/usr/share/portmaster/zlyme/control.txt
	$(INSTALL) -m 0644 $(PORTMASTER_PKGDIR)/mod_Zlyme.txt \
		$(TARGET_DIR)/usr/share/portmaster/zlyme/mod_Zlyme.txt
	$(INSTALL) -m 0755 $(PORTMASTER_PKGDIR)/patch-hardware.py \
		$(TARGET_DIR)/usr/share/portmaster/zlyme/patch-hardware.py
	$(INSTALL) -m 0755 $(PORTMASTER_PKGDIR)/zlyme-theme/inject-scheme.py \
		$(TARGET_DIR)/usr/share/portmaster/zlyme/inject-scheme.py
	$(INSTALL) -m 0755 $(PORTMASTER_PKGDIR)/zlyme-theme/select-scheme.py \
		$(TARGET_DIR)/usr/share/portmaster/zlyme/select-scheme.py
	$(INSTALL) -m 0644 $(PORTMASTER_PKGDIR)/control.txt \
		$(TARGET_DIR)/usr/config/PortMaster/control.txt
	: > $(TARGET_DIR)/usr/config/PortMaster/mapper.txt
	$(UNZIP) -p $(@D)/PortMaster.zip PortMaster/gamecontrollerdb.txt \
		> $(TARGET_DIR)/usr/config/PortMaster/gamecontrollerdb.txt
	test -s $(TARGET_DIR)/usr/config/PortMaster/gamecontrollerdb.txt
	rm -f $(TARGET_DIR)/usr/share/portmaster/patch-hardware.py \
		$(TARGET_DIR)/usr/share/portmaster/zlyme-theme-config.py
endef

$(eval $(generic-package))
