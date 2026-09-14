################################################################################
#
# portmaster
#
# PortMaster-GUI zip. Tools/PortMaster.pak execs /usr/bin/portmaster.
# https://github.com/ben16w/minui-portmaster is TrimUI-only (tg5040,
# /usr/trimui/lib) — not used on Flip. pugwash needs a python3 that
# actually built _ssl/_sqlite3 and ships a .py sysconfigdata (host
# compileall wrote a 3.14 .pyc the target refused).
################################################################################

PORTMASTER_VERSION = 2026.05.04-1202
PORTMASTER_SOURCE = PortMaster.zip
PORTMASTER_SITE = https://github.com/PortsMaster/PortMaster-GUI/releases/download/$(PORTMASTER_VERSION)
PORTMASTER_LICENSE = MIT
PORTMASTER_LICENSE_FILES = LICENSE
PORTMASTER_DEPENDENCIES = python3 box64 openssl sqlite ca-certificates

define PORTMASTER_EXTRACT_CMDS
	mkdir -p $(@D)
	$(UNZIP) -q -o $(PORTMASTER_DL_DIR)/$(PORTMASTER_SOURCE) -d $(@D)
	cp -f $(PORTMASTER_PKGDIR)/LICENSE $(@D)/LICENSE
endef

define PORTMASTER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/portmaster
	cp -a $(@D)/PortMaster $(TARGET_DIR)/usr/share/portmaster/
	$(INSTALL) -D -m 0644 $(PORTMASTER_PKGDIR)/LICENSE \
		$(TARGET_DIR)/usr/share/portmaster/LICENSE
	# pugwash extracts pylibs.zip next to itself; squashfs cannot be written.
	if [ -f $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs.zip ]; then \
		$(UNZIP) -q -o $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs.zip \
			-d $(TARGET_DIR)/usr/share/portmaster/PortMaster; \
		rm -f $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs.zip; \
	fi
	if [ -f $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs/resources/NotoSans.tar.xz ]; then \
		tar -C $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs/resources \
			-xf $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs/resources/NotoSans.tar.xz \
			|| true; \
	fi
	$(INSTALL) -D -m 0755 $(PORTMASTER_PKGDIR)/portmaster-launch \
		$(TARGET_DIR)/usr/bin/portmaster
	# pugwash lists extra themes from PortMaster/themes/<name>/theme.json
	# (pylibs/default_theme is the built-in). Copy the stock assets, then
	# inject a Zlyme colour scheme as the default.
	rm -rf $(TARGET_DIR)/usr/share/portmaster/PortMaster/themes/Zlyme
	mkdir -p $(TARGET_DIR)/usr/share/portmaster/PortMaster/themes/Zlyme
	cp -a $(TARGET_DIR)/usr/share/portmaster/PortMaster/pylibs/default_theme/. \
		$(TARGET_DIR)/usr/share/portmaster/PortMaster/themes/Zlyme/
	python3 $(PORTMASTER_PKGDIR)/zlyme-theme/inject-scheme.py \
		$(TARGET_DIR)/usr/share/portmaster/PortMaster/themes/Zlyme/theme.json
	if [ -f $(PORTMASTER_PKGDIR)/zlyme-theme/logo.png ]; then \
		$(INSTALL) -m 0644 $(PORTMASTER_PKGDIR)/zlyme-theme/logo.png \
			$(TARGET_DIR)/usr/share/portmaster/PortMaster/themes/Zlyme/logo.png; \
	fi
endef

$(eval $(generic-package))
