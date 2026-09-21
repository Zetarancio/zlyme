include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

# Board hooks register only for the selected device. my355 is the only
# one today; a second board adds another clause, not a plugin loader.
ifeq ($(BR2_ZLYME_DEVICE_MY355),y)
include $(BR2_EXTERNAL_ZLYME_PATH)/board/my355/board.mk
endif

# Panfrost does not need LLVM in the GL client.
MESA3D_CONF_OPTS += -Ddraw-use-llvm=false

# mkxp-z's meson wrap leaked SDL3 into staging; fluidsynth then linked it
# and the image had no libSDL3.so.0. EasyRPG/mkxp MIDI does not need SDL
# audio — ALSA is enough.
FLUIDSYNTH_CONF_OPTS += -Denable-sdl3=OFF -Denable-sdl2=OFF

# host-clang is wrapped for the target; libclc needs the unwrapped binary.
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
