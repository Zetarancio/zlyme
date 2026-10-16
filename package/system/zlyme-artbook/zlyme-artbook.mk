################################################################################
#
# zlyme-artbook
#
# Downloads one pinned Art Book Next archive, composes the Zlyme
# overlays on the host, and installs only those PNGs.
#
################################################################################

ZLYME_ARTBOOK_VERSION = d772d07109701d9bd7c9fda305bfef6601105ab8
ZLYME_ARTBOOK_SITE = https://github.com/anthonycaccese/art-book-next-es-de/archive
ZLYME_ARTBOOK_SOURCE = $(ZLYME_ARTBOOK_VERSION).tar.gz
ZLYME_ARTBOOK_LICENSE = CC-BY-NC-SA-2.0
ZLYME_ARTBOOK_LICENSE_FILES = README.md
# host-python3 is already required by Buildroot. host-librsvg 2.50
# provides rsvg-convert. python-pillow is target-only in 2026.08.
ZLYME_ARTBOOK_DEPENDENCIES = host-python3 host-librsvg

define ZLYME_ARTBOOK_BUILD_CMDS
	$(HOST_DIR)/bin/python3 $(ZLYME_ARTBOOK_PKGDIR)/compose.py \
		--upstream $(@D) \
		--out $(@D)/out \
		--map $(ZLYME_ARTBOOK_PKGDIR)/systems.txt \
		--tools $(ZLYME_ARTBOOK_PKGDIR)/tools \
		--font $(ZLYME_ARTBOOK_PKGDIR)/fonts/DejaVuSans-Bold.ttf \
		--rsvg $(HOST_DIR)/bin/rsvg-convert
endef

define ZLYME_ARTBOOK_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/artbook/system
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/artbook/tools
	$(INSTALL) -D -m 0644 $(ZLYME_ARTBOOK_PKGDIR)/NOTICE.md \
		$(TARGET_DIR)/usr/share/nextui/artbook/NOTICE.md
	cp -a $(@D)/out/system/. $(TARGET_DIR)/usr/share/nextui/artbook/system/
	cp -a $(@D)/out/tools/. $(TARGET_DIR)/usr/share/nextui/artbook/tools/
endef

$(eval $(generic-package))
