################################################################################
#
# drastic
#
################################################################################

DRASTIC_VERSION = 1.0
DRASTIC_SOURCE = drastic.tar.gz
DRASTIC_SITE = https://github.com/ROCKNIX/packages/raw/main
DRASTIC_LICENSE = Proprietary
DRASTIC_DEPENDENCIES = sdl2

define DRASTIC_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -shared -fPIC -o $(@D)/libdrastouch.so \
		$(DRASTIC_PKGDIR)/sources/libdrastouch.c -ldl
endef

define DRASTIC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libdrastouch.so \
		$(TARGET_DIR)/usr/lib/libdrastouch.so
	mkdir -p $(TARGET_DIR)/usr/share/drastic
	if [ -d $(@D)/drastic_aarch64 ]; then \
		cp -a $(@D)/drastic_aarch64/* $(TARGET_DIR)/usr/share/drastic/; \
	fi
	if [ -f $(@D)/drastic_aarch64/drastic ]; then \
		$(INSTALL) -D -m 0755 $(@D)/drastic_aarch64/drastic \
			$(TARGET_DIR)/usr/bin/drastic; \
	elif [ -f $(@D)/drastic ]; then \
		$(INSTALL) -D -m 0755 $(@D)/drastic $(TARGET_DIR)/usr/bin/drastic; \
	fi
	$(INSTALL) -D -m 0644 $(DRASTIC_PKGDIR)/config/drastic.cfg \
		$(TARGET_DIR)/usr/share/drastic/config/drastic.cfg
	$(INSTALL) -D -m 0755 $(DRASTIC_PKGDIR)/start_drastic.sh \
		$(TARGET_DIR)/usr/bin/start_drastic
endef

$(eval $(generic-package))
