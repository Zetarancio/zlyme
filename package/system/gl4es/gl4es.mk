################################################################################
#
# gl4es
#
################################################################################

# PortMaster-only OpenGL compatibility. The library and headers stay
# in isolated paths and never replace the system GL/EGL/GLES ABI.

GL4ES_VERSION = 2037865590d410bcd7b8d1f22b841472ed6d39ac
GL4ES_SITE = $(call github,ptitSeb,gl4es,$(GL4ES_VERSION))
GL4ES_LICENSE = MIT
GL4ES_LICENSE_FILES = LICENSE
GL4ES_DEPENDENCIES = mesa3d
GL4ES_INSTALL_STAGING = YES

GL4ES_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_SKIP_RPATH=ON \
	-DNOX11=ON \
	-DGBM=ON \
	-DDEFAULT_ES=2 \
	-DDEFAULT_EGL=libEGL.so.1 \
	-DDEFAULT_GLES=libGLESv2.so.2

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
