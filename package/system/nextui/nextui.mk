################################################################################
#
# nextui
#
# Vendored LoveRetro/NextUI (see src/UPSTREAM), edited here. When this
# fork is proven it will become its own repo and Zlyme will fetch it.
# Cores stay /usr/lib/libretro; emu paks exec RetroArch until minarch
# is built from this tree.
#
# NextUI: https://github.com/LoveRetro/NextUI
# Originally MinUI by Shaun Inman: https://github.com/shauninman/MinUI
# License: PolyForm Noncommercial 1.0.0
################################################################################

NEXTUI_VERSION = ae652648548edf6ab24cbb816cf4e4194e609fb3-zlyme31
NEXTUI_SITE = $(NEXTUI_PKGDIR)/src
NEXTUI_SITE_METHOD = local
NEXTUI_LICENSE = LicenseRef-PolyForm-Noncommercial-1.0.0
NEXTUI_LICENSE_FILES = LICENSE NOTICE
NEXTUI_DEPENDENCIES = sdl2 sdl2_image sdl2_ttf libpng freetype zlib libsamplerate openssl libdrm

NEXTUI_PLATFORM = my355

NEXTUI_CFLAGS = $(TARGET_CFLAGS) -std=gnu99 \
	-DPLATFORM=\"$(NEXTUI_PLATFORM)\" -DUSE_SDL2 -DUSE_GLES \
	-DGL_GLEXT_PROTOTYPES -DEGL_NO_X11=1 \
	-I$(STAGING_DIR)/usr/include/libdrm
NEXTUI_CXXFLAGS = $(TARGET_CXXFLAGS) -std=c++17 \
	-DPLATFORM=\"$(NEXTUI_PLATFORM)\" -DUSE_SDL2 -DUSE_GLES \
	-DGL_GLEXT_PROTOTYPES -DEGL_NO_X11=1 \
	-I$(@D)/workspace/all/settings \
	-I$(STAGING_DIR)/usr/include/libdrm
NEXTUI_INCLUDES = \
	-I$(@D)/workspace/all/common \
	-I$(@D)/workspace/$(NEXTUI_PLATFORM)/platform \
	-I$(@D)/workspace/$(NEXTUI_PLATFORM)/libmsettings
NEXTUI_LIBS = -L$(@D) -lmsettings -lsamplerate \
	-lSDL2 -lSDL2_image -lSDL2_ttf -lGLESv2 -lEGL \
	-ldl -lpthread -lm -lz -lrt -ldrm

define NEXTUI_BUILD_CMDS
	printf '%s\n' $(NEXTUI_VERSION) > $(@D)/workspace/hash.txt
	$(TARGET_CC) $(NEXTUI_CFLAGS) -fPIC -shared \
		-o $(@D)/libmsettings.so \
		$(@D)/workspace/$(NEXTUI_PLATFORM)/libmsettings/msettings.c \
		$(TARGET_LDFLAGS) -lrt -ldrm
	$(TARGET_CC) $(NEXTUI_CFLAGS) $(NEXTUI_INCLUDES) \
		-o $(@D)/zlyme-bcsh \
		$(NEXTUI_PKGDIR)/zlyme/zlyme-bcsh.c \
		-L$(@D) -lmsettings $(TARGET_LDFLAGS) -lrt -ldrm
	$(TARGET_CC) $(NEXTUI_CFLAGS) -o $(@D)/zlyme-pak-hotkey \
		$(NEXTUI_PKGDIR)/zlyme/zlyme-pak-hotkey.c
	$(TARGET_CC) $(NEXTUI_CFLAGS) $(NEXTUI_INCLUDES) \
		-o $(@D)/keymon.elf \
		$(@D)/workspace/$(NEXTUI_PLATFORM)/keymon/keymon.c \
		-L$(@D) -lmsettings $(TARGET_LDFLAGS) -lrt -ldrm
	$(foreach src,scaler utils config api palette,\
		$(TARGET_CC) $(NEXTUI_CFLAGS) -c $(NEXTUI_INCLUDES) \
			-o $(@D)/$(src).o $(@D)/workspace/all/common/$(src).c$(sep))
	$(TARGET_CC) $(NEXTUI_CFLAGS) -c $(NEXTUI_INCLUDES) \
		-o $(@D)/platform.o \
		$(@D)/workspace/$(NEXTUI_PLATFORM)/platform/platform.c
	$(TARGET_CC) $(NEXTUI_CFLAGS) -c $(NEXTUI_INCLUDES) \
		-I$(@D)/workspace/all/nextui \
		-o $(@D)/nextui.o $(@D)/workspace/all/nextui/nextui.c
	$(TARGET_CC) $(TARGET_CFLAGS) -o $(@D)/nextui.elf \
		$(@D)/nextui.o $(@D)/scaler.o $(@D)/utils.o $(@D)/config.o \
		$(@D)/api.o $(@D)/palette.o $(@D)/platform.o \
		$(TARGET_LDFLAGS) $(NEXTUI_LIBS)
	$(foreach src,http ra_auth ra_offline ra_sync ra_event_queue,\
		$(TARGET_CC) $(NEXTUI_CFLAGS) -c $(NEXTUI_INCLUDES) \
			-o $(@D)/$(src).o $(@D)/workspace/all/common/$(src).c$(sep))
	$(TARGET_CXX) $(NEXTUI_CXXFLAGS) $(NEXTUI_INCLUDES) \
		-o $(@D)/settings.elf \
		$(@D)/workspace/all/settings/settings.cpp \
		$(@D)/workspace/all/settings/menu.cpp \
		$(@D)/workspace/all/settings/colorpickermenu.cpp \
		$(@D)/workspace/all/settings/palettemenu.cpp \
		$(@D)/workspace/all/settings/fnbuttonmenu.cpp \
		$(@D)/workspace/all/settings/wifimenu.cpp \
		$(@D)/workspace/all/settings/btmenu.cpp \
		$(@D)/workspace/all/settings/keyboardprompt.cpp \
		$(@D)/workspace/all/settings/zlymemenu.cpp \
		$(@D)/utils.o $(@D)/api.o $(@D)/config.o $(@D)/scaler.o \
		$(@D)/palette.o $(@D)/http.o $(@D)/ra_auth.o $(@D)/ra_offline.o \
		$(@D)/ra_sync.o $(@D)/ra_event_queue.o $(@D)/platform.o \
		$(TARGET_LDFLAGS) $(NEXTUI_LIBS) -lcrypto -lstdc++
	$(TARGET_CC) $(TARGET_CFLAGS) -o $(@D)/show.elf \
		$(NEXTUI_PKGDIR)/zlyme/show.c \
		$(TARGET_LDFLAGS) -lSDL2 -lSDL2_ttf
endef

define NEXTUI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/nextui.elf $(TARGET_DIR)/usr/bin/nextui.elf
	$(INSTALL) -D -m 0755 $(@D)/settings.elf $(TARGET_DIR)/usr/bin/settings.elf
	$(INSTALL) -D -m 0755 $(@D)/show.elf $(TARGET_DIR)/usr/bin/show.elf
	$(INSTALL) -D -m 0755 $(@D)/libmsettings.so $(TARGET_DIR)/usr/lib/libmsettings.so
	$(INSTALL) -D -m 0755 $(@D)/zlyme-bcsh $(TARGET_DIR)/usr/sbin/zlyme-bcsh
	$(INSTALL) -D -m 0755 $(@D)/zlyme-pak-hotkey $(TARGET_DIR)/usr/sbin/zlyme-pak-hotkey
	$(INSTALL) -D -m 0755 $(@D)/keymon.elf $(TARGET_DIR)/usr/bin/keymon.elf
	rm -f $(TARGET_DIR)/usr/sbin/zlyme-volmon \
		$(TARGET_DIR)/etc/init.d/S26volmon \
		$(TARGET_DIR)/etc/udev/rules.d/60-zlyme-volume-keys.rules
	ln -sf nextui.elf $(TARGET_DIR)/usr/bin/minui.elf
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/minarch.sh \
		$(TARGET_DIR)/usr/bin/minarch.elf
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/gametimectl.sh \
		$(TARGET_DIR)/usr/bin/gametimectl.elf
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/nextui-session \
		$(TARGET_DIR)/usr/sbin/nextui-session
	ln -sf nextui-session $(TARGET_DIR)/usr/sbin/minui-session
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/res
	cp -a $(NEXTUI_PKGDIR)/res/. $(TARGET_DIR)/usr/share/nextui/res/
	rm -f $(TARGET_DIR)/usr/share/nextui/res/branding/*.svg
	$(INSTALL) -d $(TARGET_DIR)/usr/share/nextui/paks
	cp -a $(NEXTUI_PKGDIR)/paks/Emus $(TARGET_DIR)/usr/share/nextui/paks/
	cp -a $(NEXTUI_PKGDIR)/paks/Tools $(TARGET_DIR)/usr/share/nextui/paks/
	cp -a $(NEXTUI_PKGDIR)/paks/MinUI.pak $(TARGET_DIR)/usr/share/nextui/paks/
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/system.cfg \
		$(TARGET_DIR)/usr/share/nextui/system.cfg
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/rom-dirs.txt \
		$(TARGET_DIR)/usr/share/nextui/rom-dirs.txt
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/rom-exts.txt \
		$(TARGET_DIR)/usr/share/nextui/rom-exts.txt
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/ra-run.sh \
		$(TARGET_DIR)/usr/bin/ra-run
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/zlyme/gamecontrollerdb.txt \
		$(TARGET_DIR)/usr/lib/gamecontrollerdb.txt
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/zlyme/gamecontrollerdb.txt \
		$(TARGET_DIR)/usr/share/zlyme/gamecontrollerdb.txt
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/src/UPSTREAM \
		$(TARGET_DIR)/usr/share/nextui/UPSTREAM
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(TARGET_DIR)/usr/share/nextui/LICENSE
	$(INSTALL) -D -m 0644 $(@D)/NOTICE \
		$(TARGET_DIR)/usr/share/nextui/NOTICE
	$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/CREDITS \
		$(TARGET_DIR)/usr/share/nextui/CREDITS
	printf '%s\n' $(NEXTUI_VERSION) > $(TARGET_DIR)/usr/share/nextui/version.txt
	date -u +%Y-%m-%d > $(TARGET_DIR)/usr/share/nextui/build-date.txt
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/wifi_init.sh \
		$(TARGET_DIR)/usr/share/nextui/etc/wifi/wifi_init.sh
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/bt_init.sh \
		$(TARGET_DIR)/usr/share/nextui/etc/bluetooth/bt_init.sh
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/governor.sh \
		$(TARGET_DIR)/usr/share/nextui/bin/governor.sh
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/suspend \
		$(TARGET_DIR)/usr/share/nextui/bin/suspend
	$(INSTALL) -D -m 0755 $(NEXTUI_PKGDIR)/zlyme/governor.sh \
		$(TARGET_DIR)/usr/sbin/zlyme-governor
	$(INSTALL) -D -m 0755 $(@D)/show.elf \
		$(TARGET_DIR)/usr/share/nextui/bin/show.elf
	if [ -f /usr/share/zoneinfo/zone.tab ]; then \
		$(INSTALL) -D -m 0644 /usr/share/zoneinfo/zone.tab \
			$(TARGET_DIR)/usr/share/nextui/zone.tab; \
		$(INSTALL) -D -m 0644 /usr/share/zoneinfo/zone.tab \
			$(TARGET_DIR)/usr/share/zoneinfo/zone.tab; \
	elif [ -f $(NEXTUI_PKGDIR)/zlyme/zone.tab ]; then \
		$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/zlyme/zone.tab \
			$(TARGET_DIR)/usr/share/nextui/zone.tab; \
		$(INSTALL) -D -m 0644 $(NEXTUI_PKGDIR)/zlyme/zone.tab \
			$(TARGET_DIR)/usr/share/zoneinfo/zone.tab; \
	fi
	if [ -d /usr/share/zoneinfo ]; then \
		mkdir -p $(TARGET_DIR)/usr/share/zoneinfo; \
		cp -a /usr/share/zoneinfo/. $(TARGET_DIR)/usr/share/zoneinfo/; \
	fi
	rm -rf $(TARGET_DIR)/usr/share/minui
	ln -sfn nextui $(TARGET_DIR)/usr/share/minui
endef

$(eval $(generic-package))
