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
		--font $(@D)/_inc/fonts/ChangaOne-Italic.ttf \
		--rsvg /usr/bin/rsvg-convert
endef

# These two directories are the firmware defaults in the image staging
# tree. A renamed or removed picture must not survive an incremental
# rebuild. A person's own pictures are not in this tree.
define ZLYME_ARTBOOK_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/share/nextui/artbook/system
	rm -rf $(TARGET_DIR)/usr/share/nextui/artbook/tools
	rm -rf $(TARGET_DIR)/usr/share/nextui/artbook/special
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/artbook/system
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/artbook/tools
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/artbook/special
	$(INSTALL) -D -m 0644 $(ZLYME_ARTBOOK_PKGDIR)/NOTICE.md \
		$(TARGET_DIR)/usr/share/nextui/artbook/NOTICE.md
	cp -a $(@D)/out/system/. $(TARGET_DIR)/usr/share/nextui/artbook/system/
	cp -a $(@D)/out/tools/. $(TARGET_DIR)/usr/share/nextui/artbook/tools/
	cp -a $(@D)/out/special/. $(TARGET_DIR)/usr/share/nextui/artbook/special/
endef

$(eval $(generic-package))

# The downloaded archive does not contain the compositor or the tool
# pictures. Paths here contain spaces, so this hashes them instead of
# listing them as make prerequisites. The build stamp is remade only
# when that hash changes.
.PHONY: zlyme-artbook-local-inputs-check
$(BUILD_DIR)/zlyme-artbook.local-inputs: zlyme-artbook-local-inputs-check
	mkdir -p $(dir $@)
	{ \
		find $(ZLYME_ARTBOOK_PKGDIR) -type f ! -name '.*' -print0 \
			| LC_ALL=C sort -z | xargs -0 sha256sum; \
		find $(BR2_EXTERNAL_ZLYME_PATH)/package/system/nextui/paks/Tools \
			-mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort; \
	} | sha256sum | cut -d' ' -f1 > $@.new
	if ! cmp -s $@.new $@; then mv $@.new $@; else rm -f $@.new; fi

$(ZLYME_ARTBOOK_TARGET_BUILD): $(BUILD_DIR)/zlyme-artbook.local-inputs
