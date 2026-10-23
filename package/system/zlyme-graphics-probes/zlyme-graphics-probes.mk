################################################################################
#
# zlyme-graphics-probes
#
################################################################################

# Hidden diagnostics launched only through the normal PAK lifecycle.

ZLYME_GRAPHICS_PROBES_VERSION = local
ZLYME_GRAPHICS_PROBES_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-graphics-probes
ZLYME_GRAPHICS_PROBES_SITE_METHOD = local
ZLYME_GRAPHICS_PROBES_LICENSE = MIT
ZLYME_GRAPHICS_PROBES_LICENSE_FILES = LICENSE
ZLYME_GRAPHICS_PROBES_DEPENDENCIES = sdl2 sdl3 gl4es

define ZLYME_GRAPHICS_PROBES_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CPPFLAGS) $(TARGET_CFLAGS) \
		-Wall -Wextra -Werror \
		-o $(@D)/zlyme-sdl3-kms-probe $(@D)/sdl3-kms-probe.c \
		$(TARGET_LDFLAGS) -lSDL3
	$(TARGET_CC) $(TARGET_CPPFLAGS) $(TARGET_CFLAGS) \
		-I$(STAGING_DIR)/usr/include/SDL2 \
		-I$(STAGING_DIR)/usr/include/gl4es \
		-Wall -Wextra -Werror \
		-o $(@D)/zlyme-gl4es-probe $(@D)/gl4es-probe.c \
		$(TARGET_LDFLAGS) \
		-L$(STAGING_DIR)/usr/lib/portmaster/gl4es/aarch64 \
		-lSDL2 -lGL -lm
endef

define ZLYME_GRAPHICS_PROBES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-sdl3-kms-probe \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/zlyme-sdl3-kms-probe
	$(INSTALL) -D -m 0755 $(@D)/zlyme-gl4es-probe \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/zlyme-gl4es-probe
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_ZLYME_PATH)/scripts/device/phase14-probe-paks.sh \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/phase14-probe-paks
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_ZLYME_PATH)/scripts/device/phase14-port-observer.sh \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/phase14-port-observer
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_ZLYME_PATH)/scripts/device/phase14-portmaster-inventory.sh \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/phase14-portmaster-inventory
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_ZLYME_PATH)/scripts/device/phase14-portmaster-validate.sh \
		$(TARGET_DIR)/usr/libexec/zlyme-tests/phase14-portmaster-validate
endef

$(eval $(generic-package))
