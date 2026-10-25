################################################################################
#
# gl4es
#
################################################################################

# PortMaster-only OpenGL compatibility. The library and headers stay
# in isolated paths and never replace the system GL/EGL/GLES ABI.

# ROCKNIX next gl4es package.mk, pin 81547d986798e876de8b434193920b606a72363f.
# PortMaster's bundled GL4ES is a separate contract and is not this pin.
GL4ES_VERSION = 81547d986798e876de8b434193920b606a72363f
GL4ES_SITE = $(call github,ptitSeb,gl4es,$(GL4ES_VERSION))
GL4ES_LICENSE = MIT
GL4ES_LICENSE_FILES = LICENSE
# ROCKNIX lists only its toolchain. This Buildroot package depends
# on mesa3d so the GLES provider the NOEGL loader opens is present.
# That dependency does not add a GBM or EGL cmake option.
GL4ES_DEPENDENCIES = mesa3d
GL4ES_INSTALL_STAGING = YES

# ROCKNIX configure_package: -DODROID=1 -DNOX11=1 -DNOEGL=1.
# CMAKE_SKIP_RPATH is Buildroot isolation, not a GL4ES option.
GL4ES_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_SKIP_RPATH=ON \
	-DODROID=ON \
	-DNOX11=ON \
	-DNOEGL=ON

define GL4ES_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 $(@D)/lib/libGL.so.1 \
		$(STAGING_DIR)/usr/lib/portmaster/gl4es/aarch64/libGL.so.1
	ln -sfn libGL.so.1 \
		$(STAGING_DIR)/usr/lib/portmaster/gl4es/aarch64/libGL.so
	mkdir -p $(STAGING_DIR)/usr/include/gl4es
	cp -a $(@D)/include/GL $(STAGING_DIR)/usr/include/gl4es/
endef

define GL4ES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/lib/libGL.so.1 \
		$(TARGET_DIR)/usr/lib/portmaster/gl4es/aarch64/libGL.so.1
	ln -sfn libGL.so.1 \
		$(TARGET_DIR)/usr/lib/portmaster/gl4es/aarch64/libGL.so
	$(INSTALL) -D -m 0755 $(GL4ES_PKGDIR)/zlyme-gl4es-run \
		$(TARGET_DIR)/usr/bin/zlyme-gl4es-run
endef

$(eval $(cmake-package))
