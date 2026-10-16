################################################################################
#
# zlyme-artbook
#
# Downloads one pinned Art Book Next archive and composes the overlays
# with the build container's Python and rsvg-convert. Those tools are
# not installed on the Flip.
#
################################################################################

ZLYME_ARTBOOK_VERSION = d772d07109701d9bd7c9fda305bfef6601105ab8
ZLYME_ARTBOOK_SITE = https://github.com/anthonycaccese/art-book-next-es-de/archive
ZLYME_ARTBOOK_SOURCE = $(ZLYME_ARTBOOK_VERSION).tar.gz
ZLYME_ARTBOOK_LICENSE = CC-BY-NC-SA-2.0
ZLYME_ARTBOOK_LICENSE_FILES = README.md

# Debian python3-pil and librsvg2-bin, pinned in the Dockerfile.
# Buildroot's Rust SVG package is not used. Its host Python has no Pillow.
define ZLYME_ARTBOOK_BUILD_CMDS
	/usr/bin/python3 -c 'import PIL'
	/usr/bin/rsvg-convert --version
	/usr/bin/python3 $(ZLYME_ARTBOOK_PKGDIR)/compose.py \
		--upstream $(@D) \
		--out $(@D)/out \
		--map $(ZLYME_ARTBOOK_PKGDIR)/systems.txt \
		--tools $(ZLYME_ARTBOOK_PKGDIR)/tools \
		--paks $(BR2_EXTERNAL_ZLYME_PATH)/package/system/nextui/paks/Tools \
		--font $(ZLYME_ARTBOOK_PKGDIR)/fonts/DejaVuSans-Bold.ttf \
		--rsvg /usr/bin/rsvg-convert
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
