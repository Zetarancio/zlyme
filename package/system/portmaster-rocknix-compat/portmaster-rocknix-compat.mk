################################################################################
#
# portmaster-rocknix-compat
#
# Legacy PortMaster SONAMEs from one pinned ROCKNIX archive. Files Zlyme
# already provides are not copied. The two SDL2 objects are not copied:
# they share libSDL2-2.0.so.0 with the system SDL2. libxml2.so.2 and
# libtheoradec.so.1 stay the source-built compat libraries.
#
################################################################################

PORTMASTER_ROCKNIX_COMPAT_VERSION = 691f24bceb72228f20d41ddb4a1e76ed76a1b0b8
PORTMASTER_ROCKNIX_COMPAT_SOURCE = compat.tar.gz
PORTMASTER_ROCKNIX_COMPAT_SITE = https://github.com/ROCKNIX/packages/raw/$(PORTMASTER_ROCKNIX_COMPAT_VERSION)
PORTMASTER_ROCKNIX_COMPAT_LICENSE = LicenseRef-ROCKNIX-portmaster-compat-unspecified
PORTMASTER_ROCKNIX_COMPAT_LICENSE_FILES = PROVENANCE

# These are the SONAMEs the archive libraries need and Zlyme does not
# already install. libgomp comes from the toolchain OpenMP option, not
# from this list. X11 here is libraries only; no X server is selected.
PORTMASTER_ROCKNIX_COMPAT_DEPENDENCIES = \
	pango \
	speex \
	libgcrypt \
	libvdpau \
	xlib_libX11 \
	xlib_libXext \
	xlib_libXfixes

define PORTMASTER_ROCKNIX_COMPAT_EXTRACT_CMDS
	python3 $(PORTMASTER_ROCKNIX_COMPAT_PKGDIR)/extract-allowlist.py \
		$(PORTMASTER_ROCKNIX_COMPAT_PKGDIR)/allowlist.sha256 \
		$(PORTMASTER_ROCKNIX_COMPAT_DL_DIR)/$(PORTMASTER_ROCKNIX_COMPAT_SOURCE) \
		$(@D)/compat
	cp -f $(PORTMASTER_ROCKNIX_COMPAT_PKGDIR)/PROVENANCE $(@D)/PROVENANCE
endef

define PORTMASTER_ROCKNIX_COMPAT_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/compat
	cp -a $(@D)/compat/. $(TARGET_DIR)/usr/lib/compat/
	$(INSTALL) -D -m 0644 $(@D)/PROVENANCE \
		$(TARGET_DIR)/usr/share/portmaster/rocknix-compat.PROVENANCE
	test ! -e $(TARGET_DIR)/usr/lib/compat/libSDL2-2.0.so.0
	test ! -e $(TARGET_DIR)/usr/lib/compat/libSDL2-2.0.so.0.gles
	test ! -e $(TARGET_DIR)/usr/lib/libFLAC.so.8
	test ! -e $(TARGET_DIR)/usr/lib/libcrypto.so.1.1
endef

$(eval $(generic-package))
