################################################################################
#
# gl4es-armhf
#
################################################################################

# Isolated OpenGL-over-GLES layer for explicit Box86 graphical runs.

GL4ES_ARMHF_VERSION = 2037865590d410bcd7b8d1f22b841472ed6d39ac
GL4ES_ARMHF_SITE = $(call github,ptitSeb,gl4es,$(GL4ES_ARMHF_VERSION))
GL4ES_ARMHF_LICENSE = MIT
GL4ES_ARMHF_LICENSE_FILES = LICENSE
GL4ES_ARMHF_DEPENDENCIES = mesa3d

GL4ES_ARMHF_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_SKIP_RPATH=ON \
	-DNOX11=ON \
	-DGBM=ON \
	-DDEFAULT_ES=2 \
	-DDEFAULT_EGL=libEGL.so.1 \
	-DDEFAULT_GLES=libGLESv2.so.2

define GL4ES_ARMHF_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/lib/libGL.so.1 \
		$(TARGET_DIR)/usr/lib/zlyme-armhf/gl4es/libGL.so.1
	ln -sfn libGL.so.1 \
		$(TARGET_DIR)/usr/lib/zlyme-armhf/gl4es/libGL.so
endef

$(eval $(cmake-package))
