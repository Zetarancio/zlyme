################################################################################
#
# libretro-mkxp-z
#
# No Knulli/Batocera/ROCKNIX recipe. white-axe/mkxp-z branch libretro
# (PR mkxp-z/mkxp-z#255). Host stage1 embeds Ruby 3.3 via WASI SDK 30
# (autobuild build-libretro-stage1). Target meson -Dlibretro=true
# -Dgfx_backend=gles. Do not vendor a prebuilt .so.
#
################################################################################

LIBRETRO_MKXP_Z_VERSION = 650cb0888a07d0b5044e131160ddfa53feaf595b
LIBRETRO_MKXP_Z_SITE = https://github.com/white-axe/mkxp-z
LIBRETRO_MKXP_Z_SITE_METHOD = git
LIBRETRO_MKXP_Z_GIT_SUBMODULES = YES
LIBRETRO_MKXP_Z_LICENSE = GPL-2.0
LIBRETRO_MKXP_Z_LICENSE_FILES = COPYING
LIBRETRO_MKXP_Z_DEPENDENCIES = host-libretro-mkxp-z host-cmake openssl zlib \
	libpng freetype fluidsynth retroarch

ifeq ($(HOSTARCH),aarch64)
LIBRETRO_MKXP_Z_WASI_SDK = wasi-sdk-30.0-arm64-linux.tar.gz
LIBRETRO_MKXP_Z_BINARYEN = binaryen-version_123-aarch64-linux.tar.gz
else
LIBRETRO_MKXP_Z_WASI_SDK = wasi-sdk-30.0-x86_64-linux.tar.gz
LIBRETRO_MKXP_Z_BINARYEN = binaryen-version_123-x86_64-linux.tar.gz
endif

HOST_LIBRETRO_MKXP_Z_EXTRA_DOWNLOADS = \
	https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-30/$(LIBRETRO_MKXP_Z_WASI_SDK) \
	https://github.com/WebAssembly/binaryen/releases/download/version_123/$(LIBRETRO_MKXP_Z_BINARYEN)

# Cross file sets wrap_mode=nodownload; mkxp-z vendors SDL/OpenAL/etc via
# meson wraps (no system libretro-common). CLI overrides the machine file.
LIBRETRO_MKXP_Z_CONF_OPTS = \
	-Dlibretro=true \
	-Dlibretro_save_states=true \
	-Dgfx_backend=gles \
	-Dlibretro_stage1_path=$(HOST_DIR)/share/mkxp-z-stage1 \
	-Dstatic_executable=false \
	-Db_lto=false \
	--wrap-mode=default

# Host Python has no CA bundle; wrap-file (uchardet/libiconv/libidn) uses urllib.
LIBRETRO_MKXP_Z_CONF_ENV = \
	SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
	SSL_CERT_DIR=/etc/ssl/certs \
	REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Host python has no lzma, so meson cannot unpack uchardet.tar.xz. libiconv
# and libidn wraps need packagefiles/meson.build applied by meson itself —
# only stage those tarballs into packagecache, do not extract them.
define LIBRETRO_MKXP_Z_STAGE_WRAP_FILES
	mkdir -p $(@D)/subprojects/packagecache
	if [ ! -d $(@D)/subprojects/uchardet-0.0.8 ]; then \
		[ -s $(@D)/subprojects/packagecache/uchardet.tar.xz ] || \
			wget -O $(@D)/subprojects/packagecache/uchardet.tar.xz \
			https://deb.debian.org/debian/pool/main/u/uchardet/uchardet_0.0.8.orig.tar.xz; \
		tar -C $(@D)/subprojects -xf $(@D)/subprojects/packagecache/uchardet.tar.xz; \
	fi
	if [ ! -s $(@D)/subprojects/packagecache/libiconv.tar.gz ]; then \
		wget -O $(@D)/subprojects/packagecache/libiconv.tar.gz \
			https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz; \
	fi
	if [ ! -s $(@D)/subprojects/packagecache/libidn.tar.gz ]; then \
		wget -O $(@D)/subprojects/packagecache/libidn.tar.gz \
			https://ftp.gnu.org/gnu/libidn/libidn-1.43.tar.gz; \
	fi
	if [ ! -f $(@D)/subprojects/libiconv-1.18/meson.build ]; then \
		rm -rf $(@D)/subprojects/libiconv-1.18; \
	fi
	if [ ! -f $(@D)/subprojects/libidn-1.43/meson.build ]; then \
		rm -rf $(@D)/subprojects/libidn-1.43; \
	fi
	if [ ! -f $(@D)/.vendor/gcem/include/gcem.hpp ]; then \
		[ -s $(@D)/subprojects/packagecache/gcem.zip ] || \
			wget -O $(@D)/subprojects/packagecache/gcem.zip \
			https://github.com/kthohr/gcem/archive/012ae73c6d0a2cb09ffe86475f5c6fba3926e200.zip; \
		rm -rf $(@D)/.vendor/gcem $(@D)/subprojects/packagecache/gcem-extract; \
		mkdir -p $(@D)/subprojects/packagecache/gcem-extract $(@D)/.vendor; \
		unzip -q -o $(@D)/subprojects/packagecache/gcem.zip \
			-d $(@D)/subprojects/packagecache/gcem-extract; \
		mv $(@D)/subprojects/packagecache/gcem-extract/gcem-012ae73c6d0a2cb09ffe86475f5c6fba3926e200 \
			$(@D)/.vendor/gcem; \
	fi
	mkdir -p $(@D)/subprojects/packagefiles/fluidsynth-gcem/cmake_admin
	rm -rf $(@D)/subprojects/packagefiles/fluidsynth-gcem/gcem $(@D)/subprojects/fluidsynth
	cp -a $(@D)/.vendor/gcem $(@D)/subprojects/packagefiles/fluidsynth-gcem/gcem
	cp -f $(LIBRETRO_MKXP_Z_PKGDIR)/fluidsynth-FindGCEM.cmake \
		$(@D)/subprojects/packagefiles/fluidsynth-gcem/cmake_admin/FindGCEM.cmake
	grep -q 'patch_directory = fluidsynth-gcem' $(@D)/subprojects/fluidsynth.wrap || \
		printf '\npatch_directory = fluidsynth-gcem\n' >> $(@D)/subprojects/fluidsynth.wrap
endef
LIBRETRO_MKXP_Z_PRE_CONFIGURE_HOOKS += LIBRETRO_MKXP_Z_STAGE_WRAP_FILES

define HOST_LIBRETRO_MKXP_Z_CONFIGURE_CMDS
	mkdir -p $(@D)/.wasi-sdk $(@D)/.binaryen
	tar -xzf $(HOST_LIBRETRO_MKXP_Z_DL_DIR)/$(LIBRETRO_MKXP_Z_WASI_SDK) \
		-C $(@D)/.wasi-sdk --strip-components=1
	tar -xzf $(HOST_LIBRETRO_MKXP_Z_DL_DIR)/$(LIBRETRO_MKXP_Z_BINARYEN) \
		-C $(@D)/.binaryen --strip-components=1
endef

# PWD must be libretro/: the stage1 Makefile uses $(PWD) for downloads and
# wasm2c-data-segments.patch. Outer make leaves PWD=/zlyme/buildroot.
# GIT_DIR=. would break the Makefile's git clone/apply of ruby/wabt.
define HOST_LIBRETRO_MKXP_Z_BUILD_CMDS
	$(HOST_MAKE_ENV) env -u GIT_DIR $(MAKE) -C $(@D)/libretro \
		PWD=$(@D)/libretro \
		WASI_SDK=$(@D)/.wasi-sdk \
		WASM_OPT=$(@D)/.binaryen/bin/wasm-opt \
		CTAGS=ctags \
		RUBY=ruby \
		CURL=curl
endef

define HOST_LIBRETRO_MKXP_Z_INSTALL_CMDS
	mkdir -p $(HOST_DIR)/share/mkxp-z-stage1
	cp -a $(@D)/libretro/build/libretro-stage1/. $(HOST_DIR)/share/mkxp-z-stage1/
endef

define LIBRETRO_MKXP_Z_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/buildroot-build/mkxp-z_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/mkxp-z_libretro.so
endef

$(eval $(meson-package))
$(eval $(host-generic-package))
