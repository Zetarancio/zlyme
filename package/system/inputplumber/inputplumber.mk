################################################################################
#
# inputplumber
#
################################################################################

INPUTPLUMBER_VERSION = ea60d873cca17edd1cb655ede26f557108135252
INPUTPLUMBER_SITE = https://github.com/ShadowBlip/InputPlumber
INPUTPLUMBER_SITE_METHOD = git
INPUTPLUMBER_LICENSE = GPL-3.0-or-later
INPUTPLUMBER_LICENSE_FILES = LICENSE

# uhidrs-sys runs bindgen, which loads host libclang.
# libudev, hidapi, and libiio are the native libraries the crates link.
INPUTPLUMBER_DEPENDENCIES = eudev hidapi libiio host-clang

INPUTPLUMBER_CARGO_ENV = LIBCLANG_PATH=$(HOST_DIR)/lib

ifeq ($(BR2_ENABLE_DEBUG),y)
INPUTPLUMBER_CARGO_PROFILE = debug
else
INPUTPLUMBER_CARGO_PROFILE = release
endif

define INPUTPLUMBER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(@D)/target/$(RUSTC_TARGET_NAME)/$(INPUTPLUMBER_CARGO_PROFILE)/inputplumber \
		$(TARGET_DIR)/usr/bin/inputplumber
	$(INSTALL) -D -m 0644 \
		$(INPUTPLUMBER_PKGDIR)/org.shadowblip.InputPlumber.conf \
		$(TARGET_DIR)/usr/share/dbus-1/system.d/org.shadowblip.InputPlumber.conf
	$(INSTALL) -D -m 0644 \
		$(@D)/rootfs/usr/share/inputplumber/profiles/default.yaml \
		$(TARGET_DIR)/usr/share/inputplumber/profiles/default.yaml
	$(INSTALL) -D -m 0644 \
		$(INPUTPLUMBER_PKGDIR)/20-zlyme_miyoo_flip.yaml \
		$(TARGET_DIR)/usr/share/inputplumber/devices/20-zlyme_miyoo_flip.yaml
	$(INSTALL) -D -m 0644 \
		$(INPUTPLUMBER_PKGDIR)/zlyme_miyoo_flip.yaml \
		$(TARGET_DIR)/usr/share/inputplumber/capability_maps/zlyme_miyoo_flip.yaml
	$(INSTALL) -D -m 0755 \
		$(INPUTPLUMBER_PKGDIR)/S31inputplumber \
		$(TARGET_DIR)/etc/init.d/S31inputplumber
endef

$(eval $(cargo-package))
