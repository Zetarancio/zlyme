################################################################################
#
# flip-jackd
#
# Watch the headphone jack and set Playback Mux.
################################################################################

FLIP_JACKD_VERSION = local
FLIP_JACKD_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/flip-jackd/src
FLIP_JACKD_SITE_METHOD = local
FLIP_JACKD_LICENSE = GPL-2.0
FLIP_JACKD_DEPENDENCIES = alsa-lib

define FLIP_JACKD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define FLIP_JACKD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/flip-jackd $(TARGET_DIR)/usr/sbin/flip-jackd
endef

$(eval $(generic-package))
