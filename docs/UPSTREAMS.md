# Upstream and package-update policy

This document tells an agent how to research package/emulator updates without blindly copying another distribution. The short index is `docs/MAINTENANCE.md`.

## Source hierarchy

Different sources answer different questions.

### Emulator/core version and source behavior

Primary authority:

```text
the emulator/core's own upstream repository and release history
```

Use this to establish:
- latest stable release/tag;
- supported build options;
- dependency changes;
- license changes;
- relevant upstream fixes.

For an upstream without releases, a commit that ROCKNIX or KNULLI already carries may be chosen. Record both the upstream commit and the distribution revision that carries it. gpSP is the current example (see Compared revisions).

### Buildroot packaging patterns for handhelds

Strong references:

```text
KNULLI
ROCKNIX
upstream Buildroot
```

Use them to learn:
- known-good commits;
- handheld-specific patches;
- cross-compilation flags;
- dependencies;
- ARM64 quirks;
- KMS/DRM/Wayland options;
- controller/audio fixes.

Do not assume their architecture is Zlyme's architecture.

### Miyoo Flip hardware

This document owns the hardware-authority model. Other documents link here.

| Source | Role |
| --- | --- |
| `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` (the device wiki) and the primary evidence it cites | Hardware and firmware authority |
| This Zlyme repository | Authority for current implementation state |
| Upstream Linux for the selected kernel | Whether kernel behavior is upstream, backported, changed, or obsolete |
| Official ROCKNIX (`next`) | Comparison evidence for RK3566 kernel, DTS, and driver work |
| `Zetarancio/distribution` | Historical evidence only |
| KNULLI | Not a hardware source |

The device wiki is distribution-independent after its documentation refactor. Treat its hardware/firmware conclusions as the canonical device reference.

`Zetarancio/distribution` is archived. It remains useful historical evidence for known-working Miyoo Flip kernel/DTS/driver solutions, but it is not current project state and must not be maintained or synchronized.

Do not take board facts from KNULLI or another RK3566 handheld simply because the SoC is similar.

### Policy data from another distribution

`zlyme-governor emu <tag>` uses the per-system `scaling_min_freq` values from SpruceOS `2b7bc4a79359de14ea4d4f00da9801a937e2846d` (`Emu/*/config.json`). Each value is resolved to the lowest my355 OPP at or above it. That table is the only thing taken from SpruceOS. Do not copy Spruce's governor, core layout, or DMC policy.

## KNULLI repository

Use the active repository:

```text
https://github.com/knulli-cfw/knulli-linux
```

The older `knulli-cfw/distribution` repository was archived in 2026.

If a local checkout is available, prefer it for fast searching, but do not encode a developer-specific absolute path as the only source.

## ROCKNIX repositories

External upstream reference:

```text
https://github.com/ROCKNIX/distribution
```

Use official ROCKNIX for generic RK3566, kernel, driver, emulator, and packaging comparisons when relevant. Use its `next` branch and pin the commit you compared.

Historical Miyoo Flip implementation evidence:

```text
https://github.com/Zetarancio/distribution
```

That fork is archived. Consult it only when a historical implementation detail or commit is relevant, preferably through provenance recorded by the device wiki. Do not infer current Zlyme state from it.

## Package update workflow

When asked to update an emulator/core/package:

### 1. Establish current Zlyme state

Report:
- current Zlyme version/commit;
- current patches;
- current dependencies;
- current build flags;
- current license metadata.

### 2. Determine current upstream release

Check the project's own upstream.

Do not infer "latest" from KNULLI or ROCKNIX.

### 3. Inspect KNULLI and ROCKNIX

Search both for the same package.

Compare:
- version/commit;
- package recipe;
- patches;
- CMake/Meson options;
- dependencies;
- architecture-specific changes.

If one distribution has a newer recipe, that does not automatically make it correct for Zlyme.

### 4. Classify every borrowed patch

For each patch say:

```text
needed by Zlyme
not needed
already upstream
distribution-specific
unknown — requires test
```

Do not copy a patch stack wholesale.

### 5. Preserve Zlyme constraints

Normal Zlyme assumptions include:

- AArch64 / Cortex-A55;
- direct DRM/KMS where supported;
- no permanent X11/Wayland stack;
- one PulseAudio server, ALSA hardware, BlueALSA A2DP, and `zlyme-audio` routing;
- Buildroot cross compilation;
- curated emulator choices;
- no hidden runtime package manager;
- reproducible pinned source.

Do not enable desktop dependencies merely because another distro does.

### 6. Update reproducibility metadata

Update as applicable:
- version;
- source URL;
- hash;
- license;
- license file hash;
- dependencies;
- patches.

### 7. Build narrowly first

Prefer:

```text
package rebuild
```

before a full image.

Then perform the relevant runtime smoke test.

### 8. Report before/after

An agent should summarize:

```text
Zlyme old -> new
upstream latest
KNULLI version
ROCKNIX version
patches added/removed
dependency changes
validation performed
hardware testing still required
```

## Unspecified vendor binaries

Some artifacts have no usable license text. An unknown license does not grant redistribution. Zlyme ships one only when the maintainer has accepted that specific file and the provenance record can stand on its own.

All of the following are required:

- the maintainer explicitly chose to redistribute that artifact;
- the exact bytes or build are identified;
- origin and provenance are documented;
- SHA-256 is recorded where practical;
- whether the file is unmodified or modified is explicit;
- its purpose is documented;
- package metadata uses a `LicenseRef-...-unspecified` identifier rather than MIT, GPL, or another known license;
- the provenance record says that it is not a license grant and that redistribution rights are unverified;
- the exception is artifact-specific.

Without meaningful provenance, do not ship the file. Accepted wording: `Redistribution status: maintainer-approved as-is; upstream/vendor license unspecified.` That sentence is a Zlyme distribution decision, not a legal conclusion.

The current exception is `package/system/zlyme-preloader/preloader-stock.img`.

| Field | Record |
| --- | --- |
| Bytes | unmodified 2 MiB image, SHA-256 `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922` |
| Origin | hardware wiki `preloader-stock-rocknix/App/apommel-multiboot/preloader-stock.img`, introducing commit `8ef495f5711ce13645e9c68df63b7d7a9934cf7e`, recorded again at wiki commit `c126d3235face9ddca5bf021258a84758dca543c` |
| Purpose | Zlyme-side restore of that one stock revision, and only when the live preloader is its paired apommel image and the DDR payloads match |
| Metadata | `LicenseRef-Miyoo-vendor-preloader-unspecified` beside MIT for the script and checker |
| Record | `preloader-stock.PROVENANCE`, which includes `This record is not a license grant.` |

The stock-side helper images `miyoo355_fw.img`, `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img` are generated from pinned `apommel/baseos-my355` `e09d37bb0f03c34e564d61bd02164f332d8515a8` plus Zlyme scripts. They are MIT. They do not contain `preloader-stock.img` or any other preloader binary.

`apommel/baseos-my355` is three separate records. They are not one review.

The installer pin above is a build dependency. Moving `MY355_FW_INSTALLER_VERSION` takes the procedure in the table: read the upstream diff, change the pin and the hash, rebuild, compare `miyoo355_fw.img`, and rerun `scripts/tests/test_fw_helpers.sh` and `scripts/tests/test_phase11c.sh`. The Phase 14 HDMI work did not move it.

The HDMI comparison is only display routing. At `898590462020` that tree assigns RK3566 VOP2 plane masks so the panel and HDMI can scan out together. Zlyme did not copy those masks, the `.hdmi` device tree, or any U-Boot change. The note is in `docs/research/portmaster-capability-phase14.md`.

A general comparison of BaseOS improvements, its U-Boot commits, and the rest of its Miyoo Flip boot work is still open. It is not a Phase 14 gate and the HDMI comparison does not close it or reject it.

## Compared revisions

These are recorded comparisons, not a promise to track any tree. Local clone paths are not part of the contract; the remotes are.

### Revisions current code depends on

| Role | Remote | Revision | Used for |
| --- | --- | --- | --- |
| Buildroot | `gitlab.com/buildroot.org/buildroot` tag `2026.08` | `d5180309b1b66ef3b8eaccca70ad69be8e0729a1` | `BUILDROOT_VERSION` in `build.sh`. Annotated release tag. Mesa `26.1.8` comes from that release. The product defconfig selects `BR2_PACKAGE_MESA3D_VULKAN_DRIVER_PANFROST`. The minimal defconfig keeps Panfrost GLES and does not select PanVK. Linux 7.2.10 and U-Boot 2026.01 stay on the Zlyme pins |
| uMTP-Responder | `github.com/viveris/uMTP-Responder` tag `umtprd-1.8.1` | `1.8.1` | Buildroot's `umtprd` package, selected by the product defconfig. Tarball SHA-256 `6f57f61a1993059bcdd5f598d8c2a3888991497ef42ba3594947f00bd7746b1f`, license file SHA-256 `8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903`. GPL-3.0+. Zlyme ships that recipe unchanged. Phase 12C below |
| Stock preloader installer | `apommel/baseos-my355` | `e09d37bb0f03c34e564d61bd02164f332d8515a8` | `MY355_FW_INSTALLER_VERSION`. MIT. `mkfwimg.py` writes `miyoo355_fw.img`. `pack-fwimg.py` writes `miyoo355_fw-maskrom.img` and `miyoo355_fw-restore.img` in the same container. `miyoo355_fw-multiboot.img` is a copy of `miyoo355_fw.img`. `post-image.sh` writes a `.sha256` for each. The Build workflow uploads all four images and their checksums. A fresh card receives only `miyoo355_fw.img`. The OTA receives none. To bump: review the upstream diff, change the pin and `.hash`, rebuild, compare `miyoo355_fw.img`, rerun `scripts/tests/test_fw_helpers.sh` and `scripts/tests/test_phase11c.sh`. Do not track `main` |
| NextUI fork | `Zetarancio/NextUI` | `0adc5b6dd787b5e538227a59c4eb981fa4343973` | `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`. This development pin is on NextUI `zlyme44.4-phase-14`. It has to reach NextUI `zlyme` before it is the pin on Zlyme `main`. Published `zlyme44.3` keeps the previous pin, which is on NextUI `zlyme`. `main` on that fork is the separate upstream line. Closing the lid calls the same mem sleep as the power button. The screen timeout stays a hybrid wait. Game settings can restore the stock RetroArch configuration. Reset PortMaster is on Game. A verified Recovery write offers shutdown or restart and does not write again in that Settings session. The selected description sits above the hint pills. Settings can set the root SSH password and About shows it, plus the Samba account status and the Syncthing status from `zlyme-syncthing-gui`, when that page opens. Settings → Network → Samba Password sets the share password through `zlyme-samba-auth` on stdin. Game art prefers a PNG and also reads a JPEG in the same `.media` directory. The updater says an install may reboot more than once and shows a recent download rate. PAK launches are a ZLYME1 text file carrying the launch.sh path and an optional ROM. A rejected launch removes a leftover /tmp/next and stays in the menu |
| PortMaster | `PortsMaster/PortMaster-GUI` | `2026.06.23-0015` | `PORTMASTER_VERSION`. Stable channel through 2026-10-16. SHA-256 `772f2d56fc1abfbf79a3404ca78f240776c81c5a5b92786a0a748ae554339b7b` in `portmaster.hash`. The image ships the zip as a seed. Prepare maps `zlyme` to `PlatformZlyme`, a `PlatformBase` subclass. Review a newer stable release when one is published. A compatibility fix from a beta or alpha tag needs a named benefit and a named regression risk, and it does not move this pin by itself. GitHub does not mark `2026.10.03-1041` as a prerelease; its release text says alpha. ROCKNIX `next` at `5e81daa9748b5139eaca899578da43c4e10e8724` was compared for the unpack-on-storage pattern. ROCKNIX `7cffc96617df2a051af091182e8a3d270fd794a4` installs PortMaster `2026.09.13-0343` with `/usr/lib/compat` from `compat.tar.gz` and `clibs=/usr/lib/compat/`. That archive is not shipped. ROCKNIX is not the version authority |
| PortMaster Theora compatibility | Xiph libtheora | `1.1.1` | `PORTMASTER_THEORA_COMPAT_VERSION`. Tarball SHA-256 `f36da409947aa2b3dcc6af0a8c2e3144bc19db2ed547d64e9171c59c66561c61` from `downloads.xiph.org` `SHA256SUMS`. BSD-3-Clause, `COPYING` and `LICENSE`. Built from source. Only `libtheoradec.so.1` is installed, under `/usr/lib/compat`. The system libtheora stays 1.2 |
| NextUI base | `LoveRetro/NextUI` | `ae652648548edf6ab24cbb816cf4e4194e609fb3` | `UPSTREAM` file inside the fork pin |
| OpenBOR | `DCurrent/openbor` | `v7533` | `OPENBOR_VERSION`. Directory overrides are `package/emulators/openbor/0003-runtime-directories.patch` |
| mkxp-z | `white-axe/mkxp-z` | `650cb0888a07d0b5044e131160ddfa53feaf595b` | `LIBRETRO_MKXP_Z_VERSION`. One wrapper directory is `0001-one-wrapper-archive-root.patch` |
| Wine | `Kron4ek/Wine-Builds` | `11.6` asset `wine-11.6-amd64-wow64.tar.xz` | SHA-256 `045549657b513c2fb191734b0434c81000b36ba4d482d1688bf99f80a8ee07a5` in `wine-amd64.hash`. Vanilla `amd64-wow64`, not staging |
| Box64 | `ptitSeb/box64` | `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` (v0.4.4) | `BOX64_VERSION`. `BOX32=OFF` |
| ROCKNIX | `ROCKNIX/distribution` `next` | `a55d58a1209b35e287dd55a3aad67a5543b467ce` | carries gpSP `8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f`, the `package/emulators/libretro-gpsp` pin |
| KNULLI | `knulli-cfw/knulli-linux` `knulli-main` | `6a23957a19a1df18989ac6aa5e9fff003ae611ed` | carries the older gpSP `d6decfa3`; compared, not adopted |
| SpruceOS | `spruceUI/spruceOS` | `2b7bc4a79359de14ea4d4f00da9801a937e2846d` | CPU floor table in `package/system/nextui/zlyme/governor.sh` |
| ROCKNIX | `ROCKNIX/distribution` | `fe127fad01f6006bea1734ebde87d1c02cc6d256` | RK817 patch `001`, applied as local `0003`; `002`, `005`, `008` not adopted |

The gpSP comparison is in `docs/research/product-phase9.md`. The RK817 dispositions are in `docs/research/kernel-patch-audit-phase5.md` and `docs/research/deep-suspend-phase6.md`. ZcrapeGoat's import is recorded below.

### Phase 12B1 emulator source pins

These replaced the GCC 15 and glibc 2.44 build patches added for Buildroot 2026.08. The Buildroot, Mesa, Linux, and U-Boot pins above did not move.

Flycast standalone moved from tag `v2.5` (`5f4eefab5852d1c832ad8ffdf514fef8c217f1ac`) to v2.7, pinned by commit `5aa091fde632fb332c8d8c34e280d62dc951954c` (19 August 2026). The removed patch, 0001-glslang-cstdint.patch, lived in `package/emulators/flycast`. It added `<cstdint>` to glslang `SPIRV/SpvBuilder.h` at submodule `76b52ebf77833908dc4c0dd6c70a9c357ac720bd`. The v2.6 and v2.7 submodule is `fc9889c889561c5882e83819dcaffef5ed45529b`, which already includes that header. The recipe still builds the standalone SDL2 binary, not the libretro core: host SDL2, GLES with OpenGL left on, Vulkan when the loader is selected, and DirectX off. v2.7 also compiles the bundled DreamPicoPort client. Lua, libao, PulseAudio, and MiniUPnPc were absent from the sysroot, so those backends stayed off. ALSA and libzip stayed on. The install path is still `/usr/bin/flycast`, and `DC.pak/launch.sh` is unchanged. The recipe uses that commit because upstream has both a tag and a branch named v2.7. Batocera packages tag `v2.7`. ROCKNIX packages libretro Flycast `c3763d8fc4208dd6f8f0bc456383543b8406a8a0` with its own GCC 15 patch. That is a different source line and was not adopted. KNULLI `knulli-main` at `57afa662009641d181f57241bcc480119b131530` packages libretro `flycastvl` `4a913e063c95d1fae98afc64645831de0bcad57e`, not standalone Flycast.

MAME2003-Plus moved from `3bfa9f89ab1ff4ac73a94e8ed1a9a7dbeb18d564` (27 February 2024) to `5da0428c7f9536577febfa092543c98d3b5767b4` (15 September 2026). The removed patch, 0001-glibc-narrow-math-names.patch, lived in `package/emulators/libretro-mame2003-plus` and macro-aliased `fadd`, `fsub`, `fmul`, and `fdiv` in `src/machine/model1_machine.c`. The upstream fix is `4a9aec73e59df9ed7399c2825fa8905cce5169d0`, "fix build with gcc 15 (#1900)", by Rudi Heitbaum. It renames those helpers to `l_fadd`, `l_fsub`, `l_fmul`, and `l_fdiv` and updates the function-table entries. That commit is 369 commits after the old pin. The selected revision is the Batocera pin, which contains the fix and is 266 commits after it. ROCKNIX `packages/emulation/libretro-mame2003_plus` pins `5373e38e1091eb28f075513ecdc2575bafc8a5e3` (2 May 2026). ROCKNIX `projects/ROCKNIX/packages/emulators/libretro/mame2003-plus-lr` pins `a045126dad33d70ce555e7e7fe22a69d3a1efcc7` (24 August 2026). Both are ancestors of `5da0428c`. Upstream `master` was `e05caba0aa33cae580d104c45c6caa6406617e3b` (9 October 2026), 20 commits newer, and was not taken because no compared distribution had integrated it. The installed names stay `mame078plus_libretro.so` and the `mame2003_plus_libretro.so` symlink. Metadata still lands in `/usr/share/batocera/datainit/bios/mame2003-plus`, including samples. The Makefile `-O3` to `-O2` rewrite remains. The UI-text substitution for "to continue" no longer matches the pinned source and was removed. KNULLI does not package this core. Its arcade core is `mame2003-xtreme` from `KMFDManic/mame2003-xtreme` at `ca7712a5488b27ab7fdec1c51a17a8edf21f9f23`.

Mupen64Plus-Next moved from `c7cd8edcd015ddcbd4a2e984573c9c1d1ddd0b6e` (19 July 2024) to `6752836de8b224febfd5708444755b77712ac939` (11 September 2026). The removed patch, 0001-hires-cstdint.patch, lived in `package/emulators/libretro-mupen64plus-next`. The upstream fix is `916c7cfa57def1d83c6bd5a42effc27c1af61856`, "GLideN64: fix a build error by adding the missing #include <cstdint>", by pstef. The selected revision is 9 commits after that fix and is the Batocera pin. It built with the existing Zlyme flags: aarch64 dynarec, `FORCE_GLES3=1`, `EGL_NO_X11`, and `-lmali` when libmali is selected. Batocera also passes `-std=gnu17`, `-Wno-error=incompatible-pointer-types`, `-Wno-error=implicit-function-declaration`, `-Wno-error=int-conversion`, and `-include stdint.h`. Those were not copied. The installed names stay `mupen64plus-next_libretro.so` and the `mupen64plus_next_libretro.so` symlink. 000-makefile.patch was removed. It added platform stanzas for s905gen2, s905gen3, rk3326, h5, h616, and odin. The Flip passes platform `unix arm64`, which takes the upstream unix block: `ARCH=aarch64` selects the aarch64 dynarec and `FORCE_GLES3=1` selects GLES3. ROCKNIX `packages/emulation/libretro-mupen64plus-nx` pins `47eb46ea8dbaacf3e1d817e3d0869dad8a91d863` from `kodi-game/mupen64plus-libretro-nx`. That history has diverged from the official fix (2 ahead, 3 behind) and still carries a local `<stdint.h>` patch. ROCKNIX `projects/ROCKNIX/packages/emulators/libretro/mupen64plus-nx-lr` pins official `f275caf4b2bfa1e6d1c51636746ea793f3d80320`, which is an ancestor of the selected revision and already contains `916c7cfa`. KNULLI does not package this core. Its N64 core is `parallel-n64` at `1b57f9199b1f8a4510f7f89f14afa9cabf9b3bdd`.

### Phase 12C USB file transfer

uMTP-Responder 1.8.1 is Buildroot 2026.08's `umtprd` package. The recipe downloads the tag tarball from `viveris/uMTP-Responder` and installs `/usr/sbin/umtprd`. Zlyme does not fork that repository, vendor the source, or carry a patch. `zlyme-usb-transfer` starts it with `umtprd -conf` and a configuration written under `/run/zlyme/usb-transfer`. The product defconfig selects `BR2_PACKAGE_UMTPRD`. The minimal defconfig does not.

ROCKNIX `next` packages uMTP-Responder 1.6.8 and a multi-board gadget script, `usbgadget`, that can start MTP, mass storage, and several network functions. The 12C comparison used that script's MTP FunctionFS order: create the `ffs.mtp` function, mount FunctionFS, start the responder, then write the UDC. Zlyme also sets `max_speed` to `high-speed` for the same reason that script does: the responder's FunctionFS descriptors have no SuperSpeed set, and a SuperSpeed-capable DWC3 stalls the host on the missing descriptor. The rest of that script was not copied. Zlyme does not pick the first UDC name, call `killall`, sleep before bind, switch USB role, or start ECM, RNDIS, or NCM.

ROCKNIX `usbgadget` is GPL-2.0. Its `usb_trigger` documents that binding an RK3566 gadget with the cable unplugged logs `dwc3 fcc00000.usb: failed to enable ep0out` and that the host then cannot enumerate. It recovers by writing `disconnect` or `connect` to the UDC `soft_connect` file, using the USB2 PHY extcon: SDP and CDP are data-capable, and DCP is not. A udev rule runs that trigger on extcon changes. Zlyme does not install that script or that rule. `zlyme-usb-transfer` keeps the same `soft_connect` sequence inside the MTP session: one soft-disconnect while SDP and CDP are clear, one soft-connect when either is set, and no further write until the cable changes. The session ends the watcher. Debugfs is not required. That sequence was host-tested and, on 2026-10-12, hardware-exercised on `fcc00000.usb`. Both sysfs writes were accepted and the host did not enumerate the gadget, so the ROCKNIX sequence is not treated as a fix. Linux 7.2.10 still has the UDC `soft_connect` attribute and the 2020 DWC3 endpoint-command timeout of 5000 polls (`dwc3_send_gadget_ep_cmd`). That timeout does not cover a PHY that is powered off because VBUS is absent.

The USB id is `1d6b:0100`, the Linux Foundation PTP gadget id in the uMTP 1.8.1 sample configuration. It is not assigned to Zlyme. It is also not Miyoo's vendor id `2207` and not the Rockchip MASKROM id `2207:350a`. The serial string is the constant `zlyme`, so the gadget does not publish a board serial. Two uMTP devices on one host can collide on `1d6b:0100`.

`src/fs_handles_db.c` in that tag follows symlinks. `fs_entry_stat` uses `stat64`, and `entry_open` uses `open` without `O_NOFOLLOW`. A link inside a share is followed, including one created after the session starts. Zlyme does not patch the responder for that. The latest GitHub release is still tag `umtprd-1.8.1`. Unreleased `master` adds `src/mtp_sanitize.c` `check_realpath` and a `build_full_path` check. Both call `realpath` and then compare a string prefix. The prefix loop in `check_realpath` does not advance its index, and a prefix comparison accepts a sibling directory whose name starts with the share path. `realpath` followed by `open` is also a path-replacement race. That revision was not adopted and the package stays 1.8.1 with no Zlyme patch.

Filesystem roots are exported because `/usr/sbin/zlyme-usb-enter` (`package/system/zlyme-usb-transfer/zlyme-usb-enter.c`) puts the responder in a private mount namespace. The kernel already has `CONFIG_NAMESPACES`. Landlock is not enabled and was not turned on. User namespaces are not enabled. The helper walks each export with `O_NOFOLLOW`, clones that mount with `open_tree` without `AT_RECURSIVE`, and `pivot_root`s away the old root before exec. A directory on the cloned filesystem, including a hidden directory on `/storage`, is visible. A symlink to a path that was not cloned is not. A nested mount is not copied. Kernel exFAT and VFAT are exported the same way. A read-only volume uses the responder's `ro` option and is not remounted. NTFS, FUSE, and the other types stay mounted and are not shared. The card is not reformatted and not unmounted. `/boot` is not an export.

### Phase 0 comparison snapshot

| Role | Remote | Revision seen |
| --- | --- | --- |
| Hardware wiki | `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` | `b08e335` |
| Archived ROCKNIX fork | `Zetarancio/distribution` (`flip`) | `d249b09bd9` |
| SpruceOS | `spruceUI/spruceOS` | `90a10ed1a` |
| NextUI | `LoveRetro/NextUI` | `ae652648` |
| BaseOS | `apommel/baseos-my355` | `85b67b4` |
| KNULLI | `knulli-cfw/knulli-linux` | `0b1fd94` |

The SpruceOS row is the Phase 0 snapshot. The governor table uses `2b7bc4a` above. The longer Phase 0 notes, including which tip each clone was behind, stay in `docs/archive/NOTES.md`.

## Safe agent request

A maintainer can ask:

> Check whether `<package>` has a newer stable upstream version. Compare Zlyme's current recipe with the active KNULLI `knulli-linux` repository and ROCKNIX `distribution`. Do not modify anything yet. Report versions, relevant patches, build-option changes, license changes, and what you would update in Zlyme.

Then, after reviewing the report:

> Apply the `<package>` update following `AGENTS.md`, `docs/ENGINEERING_PRINCIPLES.md`, and `docs/UPSTREAMS.md`. Preserve Zlyme's direct KMS path and the one PulseAudio server with an ALSA backend. Do not import unrelated distro integration.

This two-step workflow is safer than telling an agent to "update everything".

## Art Book wallpapers

`package/system/zlyme-artbook` downloads Art Book Next commit `d772d07109701d9bd7c9fda305bfef6601105ab8` as `d772d07109701d9bd7c9fda305bfef6601105ab8.tar.gz`, SHA-256 `430110584bafa614b7a3f4af1891c675e58de60e6658e3758d0724554f77ebd3`. License CC BY-NC-SA 2.0, stated in that repository's README. The host composes transparent 640×480 system overlays from `_inc/systems/artwork` and `_inc/systems/logos` and installs them into the squashfs. They are firmware assets, not a runtime download. The nine Tool backgrounds are original illustrations supplied for Zlyme. RPG Maker XP is a Zlyme drawing. `resources/system-art-mask.svg` is that commit's `resources/artwork-masks/system-art-mask.svg`, viewBox 453×1080. `resources/system-art-alpha.png` is the shared alpha of the Tool backgrounds, 454×1080, not an SVG raster. The upstream image set is not vendored. Pico-8 and fake-08 share `pico8`. There is no bundled list wallpaper. Theme Manager is not shipped. The retired Timothy Bueno pack `f5fe9929148748d0d5039b993c4815818fbb921a` is recorded in `docs/research/nextui-theme-manager-phase14.md`.

## ZcrapeGoat

Vendored source, not a git submodule and not a patch stack.

```text
upstream: https://github.com/Helaas/nextui-scrapegoat-pak
tag: v2.3.0
commit: c52f749eae21a4c02c767e485fef2abbb773f2d7
license: MIT
tree: package/system/zcrapegoat/src
record: package/system/zcrapegoat/src/UPSTREAM
```

Zlyme modifications after that import are ordinary commits in this repository. A later update compares a new pinned upstream revision with this tree and imports that revision. Do not follow upstream HEAD.
