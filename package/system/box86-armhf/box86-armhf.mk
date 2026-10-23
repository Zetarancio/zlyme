################################################################################
#
# box86-armhf
#
################################################################################

# Native ARMHF Box86 for the separate side sysroot. The AArch64 image
# imports only the verified executable; no binfmt or global config.

BOX86_ARMHF_VERSION = bb716a2a6576cc06da811bf55e31e2f6f03b7596
BOX86_ARMHF_SITE = $(call github,ptitSeb,box86,$(BOX86_ARMHF_VERSION))
BOX86_ARMHF_LICENSE = MIT
BOX86_ARMHF_LICENSE_FILES = LICENSE
BOX86_ARMHF_DEPENDENCIES = host-python3

BOX86_ARMHF_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DARM64=ON \
	-DARM_DYNAREC=ON \
	-DNOGIT=ON \
	-DNO_CONF_INSTALL=ON \
	-DNO_LIB_INSTALL=ON

define BOX86_ARMHF_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/box86 \
		$(TARGET_DIR)/usr/bin/box86
endef

$(eval $(cmake-package))
