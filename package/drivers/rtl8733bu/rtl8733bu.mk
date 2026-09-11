################################################################################
#
# rtl8733bu
#
# WiFi half of the RTL8733BU combo chip.
################################################################################

# Pin is for kernel 7.0.2. Tip rewires cfg80211_ops for 7.1 and will not compile.
RTL8733BU_VERSION = c46aa25e237cb43f33390cf58eee5c69d9b32883
RTL8733BU_SITE = $(call github,Charliechen114514,rtl8733bu-linux-driver,$(RTL8733BU_VERSION))

# SPDX-License-Identifier at the top of the Makefile; the tree ships no LICENSE.
RTL8733BU_LICENSE = GPL-2.0

# Static Kbuild: CONFIG_RTL8733BU must be set or no module is produced.
RTL8733BU_MODULE_MAKE_OPTS = CONFIG_RTL8733BU=m

# Patches live next to this .mk. Assert 005 landed (drops CONFIG_CONCURRENT_MODE).
define RTL8733BU_ASSERT_PATCHED
	$(Q)if grep -q 'DCONFIG_CONCURRENT_MODE' $(@D)/Makefile; then \
		echo "rtl8733bu: patches were not applied" >&2; \
		exit 1; \
	fi
endef
RTL8733BU_POST_PATCH_HOOKS += RTL8733BU_ASSERT_PATCHED

$(eval $(kernel-module))
$(eval $(generic-package))
