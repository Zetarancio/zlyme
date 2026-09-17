################################################################################
#
# zlyme-jackd
#
# Watch the headphone jack and set Playback Mux.
################################################################################

ZLYME_JACKD_VERSION = local
ZLYME_JACKD_SITE = $(BR2_EXTERNAL_ZLYME_PATH)/package/system/zlyme-jackd/src
ZLYME_JACKD_SITE_METHOD = local
ZLYME_JACKD_LICENSE = GPL-2.0
ZLYME_JACKD_LICENSE_FILES = LICENSE
ZLYME_JACKD_DEPENDENCIES = alsa-lib

define ZLYME_JACKD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define ZLYME_JACKD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zlyme-jackd $(TARGET_DIR)/usr/sbin/zlyme-jackd
	rm -f $(TARGET_DIR)/usr/sbin/flip-jackd
endef

$(eval $(generic-package))
