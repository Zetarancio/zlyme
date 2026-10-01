################################################################################
#
# pico8-data-extractor
#
# josegonzalez/pico8-data-extractor 0.1.0. MIT.
# Static AArch64, no cgo. Used by zlyme-pico-bbs for cart titles.
#
################################################################################

PICO8_DATA_EXTRACTOR_VERSION = 0.1.0
PICO8_DATA_EXTRACTOR_SITE = https://github.com/josegonzalez/pico8-data-extractor/archive/refs/tags
PICO8_DATA_EXTRACTOR_SOURCE = $(PICO8_DATA_EXTRACTOR_VERSION).tar.gz
PICO8_DATA_EXTRACTOR_LICENSE = MIT
PICO8_DATA_EXTRACTOR_LICENSE_FILES = LICENSE
PICO8_DATA_EXTRACTOR_DEPENDENCIES = host-go

define PICO8_DATA_EXTRACTOR_BUILD_CMDS
	cd $(@D) && \
	GO111MODULE=on GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
	GOPROXY=https://proxy.golang.org,direct \
	$(GO_BIN) build -trimpath -mod=mod \
		-ldflags '-s -w -X main.Version=$(PICO8_DATA_EXTRACTOR_VERSION)' \
		-o $(@D)/pico8-data-extractor .
endef

define PICO8_DATA_EXTRACTOR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/pico8-data-extractor \
		$(TARGET_DIR)/usr/bin/pico8-data-extractor
endef

$(eval $(generic-package))
