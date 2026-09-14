################################################################################
#
# wildmidi
#
# Knulli package/batocera/libraries/wildmidi.
#
################################################################################

# Version.: Release on Jan 14, 2023
WILDMIDI_VERSION = wildmidi-0.4.5
WILDMIDI_SITE = $(call github,Mindwerks,wildmidi,$(WILDMIDI_VERSION))
WILDMIDI_LICENSE = LGPL-3.0+
WILDMIDI_LICENSE_FILES = docs/license/LGPLv3.txt
WILDMIDI_INSTALL_STAGING = YES

WILDMIDI_CONF_OPTS += -DBUILD_TESTING=OFF -DWANT_STATIC=ON -DWANT_PLAYER=OFF
WILDMIDI_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5

$(eval $(cmake-package))
