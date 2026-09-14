################################################################################
#
# libxmp
#
# Knulli package/batocera/libraries/libxmp. Dropped their
# LIBXMP_SOURCE = enet-${VERSION}.tar.gz (copy-paste from enet); the
# github helper already names the archive.
#
################################################################################

LIBXMP_VERSION = libxmp-4.6.0
LIBXMP_SITE = $(call github,libxmp,libxmp,$(LIBXMP_VERSION))
LIBXMP_LICENSE = LGPL-2.1+
LIBXMP_LICENSE_FILES = docs/COPYING.LIB
LIBXMP_INSTALL_STAGING = YES
LIBXMP_AUTORECONF = YES
LIBXMP_DEPENDENCIES = host-pkgconf

$(eval $(autotools-package))
