################################################################################
#
# aethersx2
#
# Knulli recipe: ROCKNIX prebuilt tarball + Qt6. BIOS is /storage/Bios/PS2.
################################################################################

AETHERSX2_VERSION = 1.0.0
AETHERSX2_SITE = https://github.com/ROCKNIX/packages/raw/main
AETHERSX2_SOURCE = aethersx2.tar.gz
AETHERSX2_LICENSE = LGPL-3.0

AETHERSX2_DEPENDENCIES = qt6base libgpg-error libfuse xz libpcap libaio host-patchelf
AETHERSX2_TOOLCHAIN = manual

define AETHERSX2_CONFIGURE_CMDS
	true
endef

define AETHERSX2_BUILD_CMDS
	true
endef

define AETHERSX2_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin $(TARGET_DIR)/usr/share/aethersx2
	if [ -d $(@D)/usr/share ]; then \
		cp -a $(@D)/usr/share/. $(TARGET_DIR)/usr/share/aethersx2/; \
	fi
	if [ -d $(@D)/usr/lib ]; then \
		mkdir -p $(TARGET_DIR)/usr/share/aethersx2/lib; \
		cp -a $(@D)/usr/lib/. $(TARGET_DIR)/usr/share/aethersx2/lib/; \
	fi
	if [ -f $(@D)/aethersx2 ]; then \
		$(INSTALL) -D -m 0755 $(@D)/aethersx2 \
			$(TARGET_DIR)/usr/share/aethersx2/aethersx2; \
	fi
	if [ -f $(@D)/usr/bin/aethersx2 ]; then \
		$(INSTALL) -D -m 0755 $(@D)/usr/bin/aethersx2 \
			$(TARGET_DIR)/usr/share/aethersx2/aethersx2; \
	fi
	if [ -f $(@D)/usr/share/aethersx2/aethersx2 ]; then \
		$(INSTALL) -D -m 0755 $(@D)/usr/share/aethersx2/aethersx2 \
			$(TARGET_DIR)/usr/share/aethersx2/aethersx2; \
	fi
	$(INSTALL) -D -m 0644 $(AETHERSX2_PKGDIR)/qt.conf \
		$(TARGET_DIR)/usr/share/aethersx2/qt.conf
	$(INSTALL) -D -m 0644 $(AETHERSX2_PKGDIR)/patches.zip \
		$(TARGET_DIR)/usr/share/aethersx2/patches.zip
	$(INSTALL) -D -m 0755 $(AETHERSX2_PKGDIR)/start_aethersx2.sh \
		$(TARGET_DIR)/usr/bin/aethersx2
	# ROCKNIX binary links X11/GLX/Wayland. EGLFS does not ship those.
	$(HOST_DIR)/bin/patchelf \
		--remove-needed libXrandr.so.2 \
		--remove-needed libwayland-egl.so.1 \
		--remove-needed libGLX.so.0 \
		--remove-needed libOpenGL.so.0 \
		--replace-needed libpcap.so.0.8 libpcap.so.1 \
		$(TARGET_DIR)/usr/share/aethersx2/aethersx2
endef

$(eval $(generic-package))
