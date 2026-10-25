include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

# PulseAudio 17 installs src/daemon/pulseaudio with the client libraries.
# BR2_PACKAGE_PULSEAUDIO_DAEMON only adds S50pulseaudio. pipewire-pulse
# is the server, so the extra binary does not belong on the target.
ifeq ($(BR2_PACKAGE_PULSEAUDIO),y)
ifneq ($(BR2_PACKAGE_PULSEAUDIO_DAEMON),y)
define ZLYME_DROP_PULSE_DAEMON_BINARY
	rm -f $(TARGET_DIR)/usr/bin/pulseaudio
	# pulseaudio-system.conf allows the pulse user to own
	# org.pulseaudio.Server. That user is not created, and
	# pipewire-pulse does not need the policy. dbus-daemon warns
	# about the unknown name and then ignores the policy.
	rm -f $(TARGET_DIR)/usr/share/dbus-1/system.d/pulseaudio-system.conf
endef
TARGET_FINALIZE_HOOKS += ZLYME_DROP_PULSE_DAEMON_BINARY
endif
endif

# libtool writes the build sysroot into DT_RPATH and the .la file.
# The loader must not search that path, and the .la is not used on target.
define SDL2_NET_DROP_SYSROOT_RPATH
	find $(TARGET_DIR)/usr/lib -name 'libSDL2_net-2.0.so.*' -type f \
		-exec $(HOST_DIR)/bin/patchelf --remove-rpath {} \;
	rm -f $(TARGET_DIR)/usr/lib/libSDL2_net.la
endef
SDL2_NET_POST_INSTALL_TARGET_HOOKS += SDL2_NET_DROP_SYSROOT_RPATH

# Board hooks register only for the selected device. my355 is the only
# one today; a second board adds another clause, not a plugin loader.
ifeq ($(BR2_ZLYME_DEVICE_MY355),y)
include $(BR2_EXTERNAL_ZLYME_PATH)/board/my355/board.mk
endif

# Panfrost does not need LLVM in the GL client.
MESA3D_CONF_OPTS += -Ddraw-use-llvm=false

# The ARMHF defconfig is a side sysroot. Its glibc must not search the
# product /lib or /usr/lib, which are AArch64. Unmodified ARMHF binaries
# keep the interpreter /lib/ld-linux-armhf.so.3, so the loader stays
# there. libdir and slibdir are the same private directory: glibc's
# built-in search path is slibdir:libdir when they differ, and that
# would still include /usr/lib. This is not an LD_LIBRARY_PATH override.
ifeq ($(BR2_arm),y)
GLIBC_CONF_ENV += \
	libc_cv_slibdir=/usr/lib/zlyme-armhf \
	libc_cv_rtlddir=/lib
GLIBC_CONF_OPTS += --libdir=/usr/lib/zlyme-armhf

# --libdir puts crti.o, the libc.so linker script, and the static
# archives in the private directory. gcc-final looks for those in the
# sysroot's /usr/lib, so a clean build fails with "cannot find -lc".
# Symlink linker inputs and versioned shared objects back in the staging
# sysroot. GNU ld resolves transitive DT_NEEDED names such as libm.so.6
# while linking target LLVM/Clang and does not search the private runtime
# directory by itself. This staging directory is not the target rootfs;
# shipped ARMHF objects remain confined to /usr/lib/zlyme-armhf.
define ZLYME_ARMHF_GLIBC_LINKER_LINKS
	src="$(STAGING_DIR)/usr/lib/zlyme-armhf"; \
	dst="$(STAGING_DIR)/usr/lib"; \
	mkdir -p "$$dst"; \
	for file in "$$src"/*; do \
		[ -e "$$file" ] || continue; \
		[ -d "$$file" ] && continue; \
		base=$$(basename "$$file"); \
		ln -sfn "zlyme-armhf/$$base" "$$dst/$$base"; \
	done
endef
GLIBC_POST_INSTALL_STAGING_HOOKS += ZLYME_ARMHF_GLIBC_LINKER_LINKS

# glibc's shared objects land in the private directory. libgcc and
# libatomic are still installed in /lib by the compiler. Move those
# into the private directory so the loader can see them. If a name is
# already there, the /lib copy is the old layout and is removed.
#
# Panfrost's Buildroot dependency graph builds target LLVM, Clang, and
# SPIR-V tools for Mesa's precompile step. The installed EGL/GLES graph
# needs libSPIRV-Tools.so but not the compiler or utility libraries
# removed below. stage-runtime.sh checks every remaining ELF's NEEDED
# closure before the private runtime is published.
define ZLYME_ARMHF_PRIVATE_RUNTIME
	dest="$(TARGET_DIR)/usr/lib/zlyme-armhf"; \
	mkdir -p "$$dest"; \
	for dir in "$(TARGET_DIR)/lib" "$(TARGET_DIR)/usr/lib"; do \
		[ -d "$$dir" ] || continue; \
		find "$$dir" -mindepth 1 -maxdepth 1 \
			! -name 'ld-linux-armhf.so.3' \
			! -name 'zlyme-armhf' \
			! -name 'os-release' \
			\( -type f -o -type l \) -print | while IFS= read -r leftover; do \
			base=$$(basename "$$leftover"); \
			if [ -e "$$dest/$$base" ]; then \
				rm -f "$$leftover"; \
			else \
				mv "$$leftover" "$$dest/$$base"; \
			fi; \
		done; \
	done; \
	for subdir in dri gbm; do \
		src="$(TARGET_DIR)/usr/lib/$$subdir"; \
		[ -d "$$src" ] || continue; \
		mkdir -p "$$dest/$$subdir"; \
		find "$$src" -mindepth 1 -maxdepth 1 \
			\( -type f -o -type l \) -exec mv -f {} "$$dest/$$subdir/" \;; \
		rmdir "$$src" 2>/dev/null || true; \
	done; \
	rm -f \
		"$$dest"/libclang*.so* \
		"$$dest"/libLLVM*.so* \
		"$$dest"/libLTO.so* \
		"$$dest"/libRemarks.so* \
		"$$dest"/libLLVMSPIRVLib.so* \
		"$$dest"/libSPIRV-Tools-diff.so* \
		"$$dest"/libSPIRV-Tools-link.so* \
		"$$dest"/libSPIRV-Tools-lint.so* \
		"$$dest"/libSPIRV-Tools-opt.so* \
		"$$dest"/libSPIRV-Tools-reduce.so* \
		"$$dest"/libSPIRV-Tools-shared.so* \
		"$$dest"/libstdc++.so.*-gdb.py \
		"$$dest"/os-release
endef
TARGET_FINALIZE_HOOKS += ZLYME_ARMHF_PRIVATE_RUNTIME
endif

# Upstream sdl2.mk always passes --disable-video-vulkan. This file is
# included after package/*/*.mk, so the filter sees that flag.
# PPSSPP's Vulkan path needs SDL_CreateWindow(SDL_WINDOW_VULKAN) on
# KMSDRM; the surface itself is VK_KHR_display, which this Mali ICD
# implements. Wayland WSI is not in the ICD.
ifeq ($(BR2_PACKAGE_VULKAN_LOADER),y)
SDL2_DEPENDENCIES += vulkan-headers vulkan-loader
SDL2_CONF_OPTS := $(filter-out --disable-video-vulkan,$(SDL2_CONF_OPTS))
SDL2_CONF_OPTS += --enable-video-vulkan
endif

# host-clang is wrapped for the target. Buildroot points libclc at
# HOST_DIR/bin, where `clang` is that wrapper. find_program keeps a
# pre-set LLVM_CUSTOM_TOOL_clang, so name the unwrapped binary.
# Host libclc already builds only spirv64-mesa3d-. The target package
# does not, so keep that limit there too.
ZLYME_LIBCLC_UNWRAPPED_CLANG = \
	-DLLVM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real \
	-DLLVM_CUSTOM_TOOL_clang=$(HOST_DIR)/bin/clang.br_real

HOST_LIBCLC_CONF_OPTS += $(ZLYME_LIBCLC_UNWRAPPED_CLANG)

LIBCLC_CONF_OPTS += \
	$(ZLYME_LIBCLC_UNWRAPPED_CLANG) \
	-DLIBCLC_TARGETS_TO_BUILD=spirv64-mesa3d-

# Host compileall can write a 3.14 sysconfigdata .pyc the target refuses
# (loguru → ValueError: bad marshal data). Keep the .py and drop that pyc.
ifeq ($(BR2_PACKAGE_PYTHON3),y)
define ZLYME_PYTHON3_FIX_SYSCONFIG
	py="$(PYTHON3_DIR)/build/lib.linux-aarch64-$(PYTHON3_VERSION_MAJOR)/_sysconfigdata__linux_aarch64-linux-gnu.py"; \
	dst="$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)"; \
	if [ -f "$$py" ]; then \
		$(INSTALL) -D -m 0644 "$$py" "$$dst/_sysconfigdata__linux_aarch64-linux-gnu.py"; \
	fi; \
	rm -f "$$dst/_sysconfigdata__linux_aarch64-linux-gnu.pyc"; \
	rm -f "$$dst/__pycache__"/_sysconfigdata*.pyc
endef
TARGET_FINALIZE_HOOKS += ZLYME_PYTHON3_FIX_SYSCONFIG
endif
