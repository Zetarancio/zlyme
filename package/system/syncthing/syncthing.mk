################################################################################
#
# syncthing
#
# 2.0.13. golang-package; no upgrade check.
################################################################################

SYNCTHING_VERSION = 2.0.13
SYNCTHING_SOURCE = syncthing-source-v$(SYNCTHING_VERSION).tar.gz
SYNCTHING_SITE = https://github.com/syncthing/syncthing/releases/download/v$(SYNCTHING_VERSION)
SYNCTHING_LICENSE = MPL-2.0
SYNCTHING_LICENSE_FILES = LICENSE
# golang-package prepends GOMOD; the target is the path under the module.
SYNCTHING_BUILD_TARGETS = cmd/syncthing
SYNCTHING_TAGS = noupgrade

define SYNCTHING_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/syncthing $(TARGET_DIR)/usr/bin/syncthing
endef

$(eval $(golang-package))
