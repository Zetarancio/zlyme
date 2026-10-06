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

LIBRETRO_MKXP_Z_EXTRA_DOWNLOADS = \
	https://github.com/ruby/ruby/archive/refs/tags/v3_3_10.tar.gz \
	https://github.com/WebAssembly/wabt/archive/refs/tags/1.0.37.tar.gz \
	https://github.com/yaml/libyaml/archive/refs/tags/0.2.5.tar.gz \
	https://raw.githubusercontent.com/okdshin/PicoSHA2/161cb3fc4170fa7a3eca9e582cebd27cc4d1fe29/picosha2.h \
	https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-14.2.0/config.guess \
	https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-14.2.0/config.sub \
	https://github.com/kthohr/gcem/archive/012ae73c6d0a2cb09ffe86475f5c6fba3926e200.zip \
	https://rubygems.org/downloads/minitest-5.20.0.gem \
	https://rubygems.org/downloads/power_assert-2.0.3.gem \
	https://rubygems.org/downloads/rake-13.1.0.gem \
	https://rubygems.org/downloads/test-unit-3.6.1.gem \
	https://rubygems.org/downloads/rexml-3.4.4.gem \
	https://rubygems.org/downloads/rss-0.3.1.gem \
	https://rubygems.org/downloads/net-ftp-0.3.4.gem \
	https://rubygems.org/downloads/net-imap-0.4.21.gem \
	https://rubygems.org/downloads/net-pop-0.1.2.gem \
	https://rubygems.org/downloads/net-smtp-0.5.1.gem \
	https://rubygems.org/downloads/matrix-0.4.2.gem \
	https://rubygems.org/downloads/prime-0.1.2.gem \
	https://rubygems.org/downloads/rbs-3.4.0.gem \
	https://rubygems.org/downloads/typeprof-0.21.9.gem \
	https://rubygems.org/downloads/debug-1.9.2.gem \
	https://rubygems.org/downloads/racc-1.7.3.gem \
	https://github.com/boostorg/predef/archive/e1211a4ca467bb6512e99025772ca25afa8d6159.tar.gz \
	https://github.com/libretro/libretro-common/archive/7caf0cd9448d5d745924c7e64e7365fb61ecda55.tar.gz \
	https://deb.debian.org/debian/pool/main/u/uchardet/uchardet_0.0.8.orig.tar.xz \
	https://mirrors.kernel.org/gnu/libiconv/libiconv-1.18.tar.gz \
	https://mirrors.kernel.org/gnu/libidn/libidn-1.43.tar.gz \
	https://github.com/boostorg/asio/archive/8b22ca054c15f32b5aea8649c0189f48f8ad874e.tar.gz \
	https://github.com/boostorg/assert/archive/e107bd7b556d72ef5273c17f4099198a28edaa4d.tar.gz \
	https://github.com/boostorg/config/archive/a7d5a9b05d70c9cfea980dc3539ca3d3461411b3.tar.gz \
	https://github.com/boostorg/core/archive/239953da9f0f11883f96548032b13ff0fd6453bb.tar.gz \
	https://github.com/boostorg/throw_exception/archive/74bea78a391ccbba61d5287925c31a4ead1114d1.tar.gz \
	https://github.com/boostorg/describe/archive/ee215421cb33a915620855cd892377e6d16c0fad.tar.gz \
	https://github.com/boostorg/mp11/archive/fe7447470d96b80eefed91b6206a4a240b664b73.tar.gz \
	https://github.com/boostorg/container_hash/archive/060d4aea6b5b59d2c9146b7d8e994735b2c0a582.tar.gz \
	https://github.com/boostorg/optional/archive/121f3efde91de78ca018019904732f55d33b5788.tar.gz \
	https://github.com/boostorg/preprocessor/archive/cd1b1bd03900b68505822cfa25cb16851bd6caf1.tar.gz \
	https://github.com/boostorg/type_traits/archive/67a6c32499866ea4485e249e8e406fb1348eb5d2.tar.gz \
	https://github.com/boostorg/static_assert/archive/9a6a86efc8dea37083ed1a78fb0998673517cf4e.tar.gz \
	https://github.com/madler/zlib/archive/51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf.tar.gz \
	https://github.com/icculus/physfs/archive/eb3383b532c5f74bfeb42ec306ba2cf80eed988c.tar.gz \
	https://github.com/kcat/openal-soft/archive/dc7d7054a5b4f3bec1dc23a42fd616a0847af948.tar.gz \
	https://github.com/FluidSynth/fluidsynth/archive/df432e151dcaf463b1ecc7e873803bfa19733fd3.tar.gz \
	https://github.com/xiph/ogg/archive/be05b13e98b048f0b5a0f5fa8ce514d56db5f822.tar.gz \
	https://github.com/xiph/vorbis/archive/0657aee69dec8508a0011f47f3b69d7538e9d262.tar.gz \
	https://github.com/xiph/flac/archive/1507800de4b70e21be71f38caa0d9079d0bc6e45.tar.gz \
	https://github.com/xiph/opus/archive/ddbe48383984d56acd9e1ab6a090c54ca6b735a6.tar.gz \
	https://github.com/madebr/mpg123/archive/fe143d4e9c885ec34596c561481dff96357fd797.tar.gz \
	https://github.com/libsndfile/libsndfile/archive/72f6af15e8f85157bd622ed45b979025828b7001.tar.gz \
	https://github.com/adamdmoss/pixman-region/archive/6380f6e0fa6fdeed921cef39eb1d22d76f3f7014.tar.gz \
	https://github.com/nothings/stb/archive/f1c79c02822848a9bed4315b12c8c8f3761e1296.tar.gz \
	https://github.com/KhronosGroup/OpenGL-Registry/archive/d38ff693f3e99ac5a61e3858de76c6c02976fa67.tar.gz \
	https://github.com/KhronosGroup/EGL-Registry/archive/3ae2b7c48690d2ce13cc6db3db02dfc0572be65e.tar.gz \
	https://github.com/freetype/freetype/archive/526ec5c47b9ebccc4754c85ac0c0cdf7c85a5e9b.tar.gz \
	https://github.com/xiph/theora/archive/8e4808736e9c181b971306cc3f05df9e61354004.tar.gz \
	https://github.com/nmcclatchey/Priority-Deque/archive/7475dacb65d112a4de7e5c24fe32cfffc2264fa9.tar.gz \
	https://github.com/icculus/theoraplay/archive/672cf6d7591009612123e90a192e6f3cd9f532c2.tar.gz

HOST_LIBRETRO_MKXP_Z_EXTRA_DOWNLOADS = \
	https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-30/$(LIBRETRO_MKXP_Z_WASI_SDK) \
	https://github.com/WebAssembly/binaryen/releases/download/version_123/$(LIBRETRO_MKXP_Z_BINARYEN) \
	https://github.com/ruby/ruby/archive/refs/tags/v3_3_10.tar.gz \
	https://github.com/WebAssembly/wabt/archive/refs/tags/1.0.37.tar.gz \
	https://github.com/yaml/libyaml/archive/refs/tags/0.2.5.tar.gz \
	https://raw.githubusercontent.com/okdshin/PicoSHA2/161cb3fc4170fa7a3eca9e582cebd27cc4d1fe29/picosha2.h \
	https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-14.2.0/config.guess \
	https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-14.2.0/config.sub \
	https://github.com/kthohr/gcem/archive/012ae73c6d0a2cb09ffe86475f5c6fba3926e200.zip \
	https://rubygems.org/downloads/minitest-5.20.0.gem \
	https://rubygems.org/downloads/power_assert-2.0.3.gem \
	https://rubygems.org/downloads/rake-13.1.0.gem \
	https://rubygems.org/downloads/test-unit-3.6.1.gem \
	https://rubygems.org/downloads/rexml-3.4.4.gem \
	https://rubygems.org/downloads/rss-0.3.1.gem \
	https://rubygems.org/downloads/net-ftp-0.3.4.gem \
	https://rubygems.org/downloads/net-imap-0.4.21.gem \
	https://rubygems.org/downloads/net-pop-0.1.2.gem \
	https://rubygems.org/downloads/net-smtp-0.5.1.gem \
	https://rubygems.org/downloads/matrix-0.4.2.gem \
	https://rubygems.org/downloads/prime-0.1.2.gem \
	https://rubygems.org/downloads/rbs-3.4.0.gem \
	https://rubygems.org/downloads/typeprof-0.21.9.gem \
	https://rubygems.org/downloads/debug-1.9.2.gem \
	https://rubygems.org/downloads/racc-1.7.3.gem \
	https://github.com/boostorg/predef/archive/e1211a4ca467bb6512e99025772ca25afa8d6159.tar.gz \
	https://github.com/libretro/libretro-common/archive/7caf0cd9448d5d745924c7e64e7365fb61ecda55.tar.gz \
	https://deb.debian.org/debian/pool/main/u/uchardet/uchardet_0.0.8.orig.tar.xz \
	https://mirrors.kernel.org/gnu/libiconv/libiconv-1.18.tar.gz \
	https://mirrors.kernel.org/gnu/libidn/libidn-1.43.tar.gz \
	https://github.com/boostorg/asio/archive/8b22ca054c15f32b5aea8649c0189f48f8ad874e.tar.gz \
	https://github.com/boostorg/assert/archive/e107bd7b556d72ef5273c17f4099198a28edaa4d.tar.gz \
	https://github.com/boostorg/config/archive/a7d5a9b05d70c9cfea980dc3539ca3d3461411b3.tar.gz \
	https://github.com/boostorg/core/archive/239953da9f0f11883f96548032b13ff0fd6453bb.tar.gz \
	https://github.com/boostorg/throw_exception/archive/74bea78a391ccbba61d5287925c31a4ead1114d1.tar.gz \
	https://github.com/boostorg/describe/archive/ee215421cb33a915620855cd892377e6d16c0fad.tar.gz \
	https://github.com/boostorg/mp11/archive/fe7447470d96b80eefed91b6206a4a240b664b73.tar.gz \
	https://github.com/boostorg/container_hash/archive/060d4aea6b5b59d2c9146b7d8e994735b2c0a582.tar.gz \
	https://github.com/boostorg/optional/archive/121f3efde91de78ca018019904732f55d33b5788.tar.gz \
	https://github.com/boostorg/preprocessor/archive/cd1b1bd03900b68505822cfa25cb16851bd6caf1.tar.gz \
	https://github.com/boostorg/type_traits/archive/67a6c32499866ea4485e249e8e406fb1348eb5d2.tar.gz \
	https://github.com/boostorg/static_assert/archive/9a6a86efc8dea37083ed1a78fb0998673517cf4e.tar.gz \
	https://github.com/madler/zlib/archive/51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf.tar.gz \
	https://github.com/icculus/physfs/archive/eb3383b532c5f74bfeb42ec306ba2cf80eed988c.tar.gz \
	https://github.com/kcat/openal-soft/archive/dc7d7054a5b4f3bec1dc23a42fd616a0847af948.tar.gz \
	https://github.com/FluidSynth/fluidsynth/archive/df432e151dcaf463b1ecc7e873803bfa19733fd3.tar.gz \
	https://github.com/xiph/ogg/archive/be05b13e98b048f0b5a0f5fa8ce514d56db5f822.tar.gz \
	https://github.com/xiph/vorbis/archive/0657aee69dec8508a0011f47f3b69d7538e9d262.tar.gz \
	https://github.com/xiph/flac/archive/1507800de4b70e21be71f38caa0d9079d0bc6e45.tar.gz \
	https://github.com/xiph/opus/archive/ddbe48383984d56acd9e1ab6a090c54ca6b735a6.tar.gz \
	https://github.com/madebr/mpg123/archive/fe143d4e9c885ec34596c561481dff96357fd797.tar.gz \
	https://github.com/libsndfile/libsndfile/archive/72f6af15e8f85157bd622ed45b979025828b7001.tar.gz \
	https://github.com/adamdmoss/pixman-region/archive/6380f6e0fa6fdeed921cef39eb1d22d76f3f7014.tar.gz \
	https://github.com/nothings/stb/archive/f1c79c02822848a9bed4315b12c8c8f3761e1296.tar.gz \
	https://github.com/KhronosGroup/OpenGL-Registry/archive/d38ff693f3e99ac5a61e3858de76c6c02976fa67.tar.gz \
	https://github.com/KhronosGroup/EGL-Registry/archive/3ae2b7c48690d2ce13cc6db3db02dfc0572be65e.tar.gz \
	https://github.com/freetype/freetype/archive/526ec5c47b9ebccc4754c85ac0c0cdf7c85a5e9b.tar.gz \
	https://github.com/xiph/theora/archive/8e4808736e9c181b971306cc3f05df9e61354004.tar.gz \
	https://github.com/nmcclatchey/Priority-Deque/archive/7475dacb65d112a4de7e5c24fe32cfffc2264fa9.tar.gz \
	https://github.com/icculus/theoraplay/archive/672cf6d7591009612123e90a192e6f3cd9f532c2.tar.gz
# Cross file sets wrap_mode=nodownload; the CLI wins. Every wrap the GLES
# libretro build actually configures is extracted by stage-offline.py from
# EXTRA_DOWNLOADS. A missing tree fails configure instead of cloning.
LIBRETRO_MKXP_Z_CONF_OPTS = \
	-Dlibretro=true \
	-Dlibretro_save_states=true \
	-Dgfx_backend=gles \
	-Dlibretro_stage1_path=$(HOST_DIR)/share/mkxp-z-stage1 \
	-Dstatic_executable=false \
	-Db_lto=false \
	--wrap-mode=nodownload

define LIBRETRO_MKXP_Z_STAGE_WRAP_FILES
	python3 $(LIBRETRO_MKXP_Z_PKGDIR)/stage-offline.py target \
		$(LIBRETRO_MKXP_Z_DL_DIR) $(@D)
endef
LIBRETRO_MKXP_Z_PRE_CONFIGURE_HOOKS += LIBRETRO_MKXP_Z_STAGE_WRAP_FILES

define HOST_LIBRETRO_MKXP_Z_CONFIGURE_CMDS
	mkdir -p $(@D)/.wasi-sdk $(@D)/.binaryen
	tar -xzf $(HOST_LIBRETRO_MKXP_Z_DL_DIR)/$(LIBRETRO_MKXP_Z_WASI_SDK) \
		-C $(@D)/.wasi-sdk --strip-components=1
	tar -xzf $(HOST_LIBRETRO_MKXP_Z_DL_DIR)/$(LIBRETRO_MKXP_Z_BINARYEN) \
		-C $(@D)/.binaryen --strip-components=1
	python3 $(HOST_LIBRETRO_MKXP_Z_PKGDIR)/stage-offline.py host \
		$(HOST_LIBRETRO_MKXP_Z_DL_DIR) $(@D)
endef

# PWD must be libretro/: the stage1 Makefile uses $(PWD). Outer make leaves
# PWD=/zlyme/buildroot. GIT_DIR=. would break git apply of the staged patches.
define HOST_LIBRETRO_MKXP_Z_BUILD_CMDS
	$(HOST_MAKE_ENV) env -u GIT_DIR $(MAKE) -C $(@D)/libretro \
		PWD=$(@D)/libretro \
		WASI_SDK=$(@D)/.wasi-sdk \
		WASM_OPT=$(@D)/.binaryen/bin/wasm-opt \
		CTAGS=ctags \
		RUBY=ruby
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
