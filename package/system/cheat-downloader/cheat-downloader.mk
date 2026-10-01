################################################################################
#
# cheat-downloader
#
# nborodikhin/nextui-cheat-downloader-alt
# commit 4e673432cb3e92c8a34907cf5740aafacbbc3f47
# MIT. Built with Nim 2.2.8. The Libretro cheat database is downloaded
# at runtime, not packaged. minui-list and minui-presenter are the
# image copies.
#
################################################################################

CHEAT_DOWNLOADER_VERSION = 4e673432cb3e92c8a34907cf5740aafacbbc3f47
CHEAT_DOWNLOADER_SITE = https://github.com/nborodikhin/nextui-cheat-downloader-alt.git
CHEAT_DOWNLOADER_SITE_METHOD = git
# The shipped binary incorporates the MIT cheat manager, miniz 3.1.1, and
# Nim's db_connector sources. The Nim compiler is only a build tool.
# SQLite itself is dlopen("libsqlite3.so.0"), not linked into the binary.
CHEAT_DOWNLOADER_LICENSE = MIT
CHEAT_DOWNLOADER_LICENSE_FILES = LICENSE miniz-LICENSE db_connector-LICENSE
CHEAT_DOWNLOADER_DEPENDENCIES = host-python3 sqlite libcurl ca-certificates
CHEAT_DOWNLOADER_EXTRA_DOWNLOADS = \
	https://nim-lang.org/download/nim-2.2.8-linux_x64.tar.xz \
	https://github.com/richgel999/miniz/releases/download/3.1.1/miniz-3.1.1.zip

# This Buildroot's unzip package is a target cmake package and does not
# provide host-unzip. host-python3 is the pinned host tool that unpacks miniz.
define CHEAT_DOWNLOADER_EXTRACT_EXTRAS
	rm -rf $(@D)/.nim-host $(@D)/.miniz
	mkdir -p $(@D)/.nim-host $(@D)/.miniz
	tar -xJf $(CHEAT_DOWNLOADER_DL_DIR)/nim-2.2.8-linux_x64.tar.xz -C $(@D)/.nim-host
	$(HOST_DIR)/bin/python3 -m zipfile -e \
		$(CHEAT_DOWNLOADER_DL_DIR)/miniz-3.1.1.zip $(@D)/.miniz
	cp $(@D)/.miniz/LICENSE $(@D)/miniz-LICENSE
	cp $(@D)/.nim-host/nim-2.2.8/pkgs/db_connector/LICENSE \
		$(@D)/db_connector-LICENSE
endef
CHEAT_DOWNLOADER_POST_EXTRACT_HOOKS += CHEAT_DOWNLOADER_EXTRACT_EXTRAS

define CHEAT_DOWNLOADER_BUILD_CMDS
	cd $(@D) && $(@D)/.nim-host/nim-2.2.8/bin/nim c \
		--cpu:arm64 --os:linux \
		--nimcache=$(@D)/nimcache \
		--arm64.linux.gcc.exe=$(HOST_DIR)/bin/aarch64-buildroot-linux-gnu-gcc \
		--arm64.linux.gcc.linkerexe=$(HOST_DIR)/bin/aarch64-buildroot-linux-gnu-gcc \
		-d:release -d:strip --opt:size \
		-d:minizDir=$(@D)/.miniz \
		--passC:"-I$(@D)/.miniz --sysroot=$(STAGING_DIR)" \
		--passL:"--sysroot=$(STAGING_DIR)" \
		-p:$(@D)/.nim-host/nim-2.2.8/pkgs/db_connector/src \
		-o:$(@D)/cheat_manager \
		$(@D)/cheat_manager.nim
endef

define CHEAT_DOWNLOADER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/cheat_manager \
		$(TARGET_DIR)/usr/lib/zlyme/cheat-downloader/cheat_manager
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/licenses/cheat-downloader/LICENSE
endef

$(eval $(generic-package))
