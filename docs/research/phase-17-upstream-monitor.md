# Phase 17 upstream monitor

Status, 2026-11-03: ROCKNIX remains a partial scan. 17G2 records the KNULLI and Batocera tips and a two-recipe pilot. 17G3 records the LoveRetro tip. Reviewed-through stays unknown. This file does not move a pin, apply a patch, or authorize a build or a device test. Policy stays in `docs/UPSTREAMS.md`.

## Checkpoint fields

Each source has two cursors. They are not the same value.

| Field | Meaning |
| --- | --- |
| Last observed HEAD | The tip read from that source. Not a review. |
| Observed at | UTC time of that read. |
| Reviewed through | The last commit whose interval was fully enumerated and whose relevant candidates were triaged. Unknown until that happens. |
| Triage date | UTC date of that complete triage. Blank when the cursor is unknown. |
| Scope | What the review covered, and what it did not. |
| Outstanding | Candidates not accepted and not rejected. |

A failed or partial scan does not move "Reviewed through". A rewritten upstream history is reported. It does not silently reset the cursor. A later scan separates new commits since the last observed HEAD, unresolved candidates already recorded, and the unreviewed backlog. It does not repeat a candidate investigation whose evidence is still valid and which upstream has not superseded. Zero commits after a verified base are evidence of no new candidate. They are not an audit of the history before that base. The Phase 0 snapshot in `docs/UPSTREAMS.md` is historical. The Compared revisions table records specific comparisons, including pins the current tree still uses. Neither table is one of these cursors.

## Checkpoints

| Source | Last observed HEAD | Observed at | Reviewed through | Triage date | Scope | Outstanding |
| --- | --- | --- | --- | --- | --- | --- |
| ROCKNIX `ROCKNIX/distribution` branch `next` | `ca1093d0ae055453fcdd67f5f9515a214230de2c` | 2026-11-03T00:30:47Z | Unknown | | 415 commits enumerated after `f2148e8061e38a44d1b71bac3efeddb0c9385084`. Subjects and paths read. Diffs read for the ten named candidates, the Mali cleanup, and one RK3566 config cleanup. | See the ROCKNIX section. Not an integration point. |
| KNULLI `knulli-cfw/knulli-linux` branch `knulli-main` | `57afa662009641d181f57241bcc480119b131530` | 2026-11-03T01:09:51Z | Unknown | | PPSSPP and standalone Yabasanshiro recipes at that tip. Not a repository interval. | No PPSSPP version change. Standalone Saturn patches do not transfer. |
| Batocera `batocera-linux/batocera.linux` branch `master` | `a89288d0979cdf578b2ce69d686a823c06c29d32` | 2026-11-03T01:09:51Z | Unknown | | PPSSPP and libretro Yabasanshiro recipes at that tip. Not a repository interval. | PPSSPP v1.20.4 is unverified. The libretro pin is a proposal. |
| LoveRetro `NextUI` branch `main` | `5291344b3aceae5fa197437a70824afb41e2d338` | 2026-11-03T01:58:45Z | Unknown | | Equals the `UPSTREAM` file in pin `f595d7862d8f5dac722aaa9960307609be903db8`. Zero commits after that base. History before the base was not audited. | No upstream import. |
| apommel `baseos-my355` branch `main` | Not observed in 17G1 | | Unknown | | | |
| Selected Linux | Not observed | | Unknown | | `configs/zlyme_my355_defconfig` sets `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` to 7.2.10. The tarball is named in `board/my355/linux/patches/10-mainline/linux/linux.hash`. That pin is not an upstream HEAD. No kernel branch was invented. | |

`f2148e8061e38a44d1b71bac3efeddb0c9385084` is an approximate earlier ROCKNIX reference. Its subject is a DuckStation AppImage change, committed 2026-09-30T01:47:46Z. It is not evidence that every commit through that SHA was reviewed. The reviewed-through cursor stays unknown.

## ROCKNIX observation, 2026-11-03

`git ls-remote` of `https://github.com/ROCKNIX/distribution.git` `refs/heads/next` returned `ca1093d0ae055453fcdd67f5f9515a214230de2c` at 2026-11-03T00:30:47Z. A local shallow clone of that tip contained the same SHA. `f2148e8061e38a44d1b71bac3efeddb0c9385084` is an ancestor. `git rev-list --count` of the range is 415. First-parent count is 178. The 415 includes merges. Coverage of that interval is not complete.

The clone's `git log --name-only` listed a subject and the changed paths for every commit in the range. The ten named candidates were diff-read. So were `ebacdb002920ea51ab373c9ec99d9e55626fddca` (Mali package cleanup; it does not delete the workqueue patch) and `b51c126c09c407d5a62ca8c419270a7de3eae897` (RK3566 config deletions for SCSI, PPP, USB touch, PTP, and camera options). Most path entries are under `projects/`. Other-SoC ports, emulator and package bumps, documentation, and GitHub workflow edits were not diff-reviewed. The RK3566 InputPlumber series beginning at `a1ea79474bb44b2cda7a0445ba7bc55db2941dcc`, and the `3ab675ddbd5c2bdc1ebbc706961b3418e937780f` port of RK3566 to Linux 7.2.7, were seen by subject only. Zlyme is already on 7.2.10, so that 7.2.7 port is behind the pin. It was not patch-reviewed.

## Candidates

The words below are this record. They map to the classes in `docs/UPSTREAMS.md`: already present covers a fix Zlyme already has, and already upstream covers a fix in the selected upstream; potentially adaptable means suitable to adapt; distribution-specific stays that class; inapplicable means inappropriate; needs more evidence means unverified. None of these commits is an accepted Zlyme patch. No device test was run. Times on the candidates are committer dates in UTC.

### `142df62157b2aa0a868942abd1e4d3bc7ffe5b08`

2026-10-02T23:51:06Z. [Commit](https://github.com/ROCKNIX/distribution/commit/142df62157b2aa0a868942abd1e4d3bc7ffe5b08). Adds the same SD resume patch under the RK3326 and RK3566 linux patch directories, and a `rocknix-automount` restart in `99-automount.rules`. No later commit in the range reverts the patch file. The patch retries `mmc_sd_init_card` once, after `mmc_power_cycle`, when an old suspended card fails to read its CID.

The patch is inside `mmc_sd_init_card`. A failed CID read, and a later failure that reaches the same label, power-cycles the host once and retries when the old card is still suspended. Zlyme's `board/my355/linux` tree has no `resume_retried` or `mmc_power_cycle` change. `rk3566-miyoo-flip.dts` sets `keep-power-in-suspend` on `sdmmc0` and `sdmmc1`. The DTS comment says a UHS 1.8 V switch on slot 1 drops the card in the other slot because the slots share `vqmmc`. The resume patch's power cycle is not that switch, and its effect on a mounted card was not tested. Needs more evidence. Later udev commits change the automount rule and do not revert the kernel patch. That rule is distribution-specific and inapplicable. No Flip test is proposed until a patch is shown not to power-cycle a mounted card. Rollback is not shipping the patch.

### `be4ef46474d7624195f84d3a20fcdb2903f0b17a`

2026-10-04T19:55:26Z. [Commit](https://github.com/ROCKNIX/distribution/commit/be4ef46474d7624195f84d3a20fcdb2903f0b17a). Sets `# CONFIG_RT_GROUP_SCHED is not set` in the RK3566, RK3576, RK3588, and S922X configs. No later commit in the range restores it. Zlyme's `board/my355/linux/linux.config` has `CONFIG_RT_GROUP_SCHED=y`. Needs more evidence. A kernel rebuild would require rebuilding out-of-tree modules. No Flip test is proposed until a cgroup or latency reason is shown.

### `636c3f98ab2103477c5b701b271ef4448b0692c6`

2026-10-14T20:49:44Z. [Commit](https://github.com/ROCKNIX/distribution/commit/636c3f98ab2103477c5b701b271ef4448b0692c6). Sets `CONFIG_CMA_SIZE_MBYTES=32` and deletes `0666-cma-region.patch`, which had added a 256 MiB default CMA node. Superseded for the config value by the next CMA commit. Inapplicable as a current candidate. Zlyme's fragment records 128 MiB for Panfrost and KMS scanout, and `linux.config` has `CONFIG_CMA_SIZE_MBYTES=128`.

### `bc486ad0cb384555f8fb23a785b182ad52b2e905`

2026-10-30T21:18:01Z. [Commit](https://github.com/ROCKNIX/distribution/commit/bc486ad0cb384555f8fb23a785b182ad52b2e905). Sets the RK3566 config from 32 to 48 MiB. No later CMA commit in the range. Needs more evidence before any reduction from Zlyme's 128 MiB. No Flip test is proposed for a smaller CMA.

### `98a9f5cc37ab81400b8ad5b9c6726af7aeb890f3`

2026-10-14T20:49:44Z. [Commit](https://github.com/ROCKNIX/distribution/commit/98a9f5cc37ab81400b8ad5b9c6726af7aeb890f3). Sets `HEAP_NAME=system` for RK3566 in ROCKNIX's `vulkan-wsi-layer` package. Zlyme has no such package. Graphics are direct KMS, with libmali or Panfrost. Distribution-specific. Inapplicable. No device test.

### `c803640655497a862188f22905b1d90b04fcb130`

2026-10-18T10:47:19Z. [Commit](https://github.com/ROCKNIX/distribution/commit/c803640655497a862188f22905b1d90b04fcb130). Moves the RK3566 and RK3576 linux package from 7.2.7 to 7.2.11, and moves S922X from 7.2.9 to the same version. The tip still has RK3566 and RK3576 at 7.2.11. A later commit, `996c03e706c1c03e1ff6b982603345a3abd117ce`, was not patch-reviewed. At the tip, S922X is 7.3.1. Zlyme is already on 7.2.10, so the 7.2.11 change is not a patch to copy and it is not behind Zlyme's pin. Potentially adaptable only as a later kernel-upgrade plan: rebase patches, configuration, DTB, and out-of-tree modules. No build or Flip test is authorized by this note.

### `1598dcb6ed71efcb3cbe52bed7e4aa5648e895f8`

2026-10-21T17:47:07Z. [Commit](https://github.com/ROCKNIX/distribution/commit/1598dcb6ed71efcb3cbe52bed7e4aa5648e895f8). Lowers the typical voltages in `rk3566.dtsi` and `rk3568.dtsi` for 1.416, 1.608, and 1.800 GHz toward the named 6.12 levels. The maximum stays 1.150 V. No later OPP commit in the range reverts it. Needs more evidence. Zlyme's board DTS does not carry this patch. No voltage experiment and no Flip test are proposed until the current opp table is compared in source. Rollback is not shipping the patch.

### `cd5d66e44e6bd29928b69300c45fddf3dcaaff25`

2026-10-28T01:22:36Z. [Commit](https://github.com/ROCKNIX/distribution/commit/cd5d66e44e6bd29928b69300c45fddf3dcaaff25). Adds `WQ_PERCPU` to six `alloc_workqueue` calls in the Mali Bifrost midgard tree, and defines the flag as 0 before 6.17. `ebacdb002920ea51ab373c9ec99d9e55626fddca` changes that package's make path and does not delete this patch. Zlyme's `package/drivers/mali-kbase/mali-kbase.mk` pins `rocknix/mali_kbase` `39da994bb6fc8819e5e8c1873907dd21d17e53c1`. That pin's `version_compat_defs.h` does not define `WQ_PERCPU`. Potentially adaptable after the six call sites in that pin are diffed. The next check is a host module build, not a Flip run. The module would have to be rebuilt with the kernel.

### `e48ea0f5b525076e733dd5e01082440a5d2c28f5`

2026-10-21T17:48:27Z. [Commit](https://github.com/ROCKNIX/distribution/commit/e48ea0f5b525076e733dd5e01082440a5d2c28f5). Exports `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1` in the libmali branch of the RK3566 UI script. Superseded by the next commit, which moves that export to the other branch. Inapplicable as written.

### `9f76176e85db0cd9d8b142491d8d0d191fc5dbb3`

2026-10-26T19:40:06Z. [Commit](https://github.com/ROCKNIX/distribution/commit/9f76176e85db0cd9d8b142491d8d0d191fc5dbb3). Moves the PanVK export to the non-libmali branch and does the same for RK3576. Zlyme already exports that variable only when the saved GPU choice is `panvk`, in `board/my355/fsoverlay/etc/zlyme-gpu-env.sh`. The product defconfig builds Mesa's Panfrost Vulkan driver. The minimal image does not. Already present for that choice. PanVK stays experimental in the existing records. No new device test.

## What this scan did not review

The other commits in the 415 were not patch-reviewed. That includes the RK3566 InputPlumber series, non-Flip board ports, and ordinary package bumps. The reviewed-through cursor stays unknown. `ca1093d0ae055453fcdd67f5f9515a214230de2c` is only the observed tip.

## Package pilot, 2026-11-03

`git ls-remote` at 2026-11-03T01:09:51Z returned the KNULLI and Batocera tips in the table. Archived `knulli-cfw/distribution` was not used. The pilot read two recipe families at those tips. It did not enumerate either repository's history, so both reviewed-through cursors stay unknown. Classes below are the names in `docs/UPSTREAMS.md`. No package was changed, downloaded, or built.

### PPSSPP

Zlyme `package/emulators/ppsspp` is standalone PPSSPP, tag `v1.19.3`, commit `e49c0bd8836a8a8f678565357773386f1174d3f5`, from `hrydgard/ppsspp`. There is no local patch. The recipe keeps `HEADLESS` off, turns `USING_EGL` off, selects Vulkan only when the loader is present, uses `USE_VULKAN_DISPLAY_KHR`, and installs `/usr/bin/PPSSPPSDL`. License field `GPL-2.0`.

KNULLI's recipe at the observed tip uses the same tag and the same upstream. Batocera's recipe uses tag `v1.20.4`, commit `fa50bb1976065c4f8b1b47af227d367fe9771555`, published 2026-05-16. That tag is 2523 commits after `v1.19.3`. Those commits were not reviewed. KNULLI did not take the bump. The component upstream is the version authority.

The tag bump is unverified. It is the only PPSSPP change that could later be suitable. A package build has to keep Zlyme's flags. Upstream CMake in `v1.20.4` still turns `USING_EGL` on for an ARM device, and it still links `SDL2_ttf::SDL2_ttf`, so Zlyme's EGL override and `CMAKE_DISABLE_FIND_PACKAGE_SDL2_ttf` stay necessary. There is no Zlyme patch to conflict with. Do not rename the installed binary. Saves stay on the paths in `package/system/nextui/zlyme/ppsspp-binds.sh`.

Proposed check, not run: build the `ppsspp` package with the tag changed and the current options kept. Acceptance is a built `PPSSPPSDL` and the same options in the recipe. Rollback is `v1.19.3`. The 2523-commit range stays unreviewed. A later device check is justified only after that build, because Panfrost display acquisition is already a recorded limitation. It is not authorized here, and it is not a full image rebuild as the first gate.

These patches are not candidates:

- `001-batocera-path.patch` and the save-state name patches hard-code `/userdata`. Distribution-specific. Inappropriate for Zlyme's storage contract.
- `003-fullscreen_drm.patch` replaces `SDL_WINDOW_FULLSCREEN_DESKTOP` with `SDL_WINDOW_FULLSCREEN`. `v1.20.4` still has the desktop flag. It does not address Zlyme's recorded EGL blank display. Unverified, and not proposed.
- `005-reduce_vulkan_checks.patch` forces Vulkan availability true. Inappropriate without a measured load-time defect.
- `002-cmake-arm-conversion-fix.patch` adds `-flax-vector-conversions`. It is not in the upstream CMake at `v1.20.4`. The current Zlyme pin does not use it. Unverified.
- `006-cmake-sdl2-ttf-fix.patch` changes the imported SDL2_ttf target. Zlyme already skips that find. Not needed.
- `007-disable-home-pause.patch` is Batocera-only. It drops the guide button's pause mapping. Inappropriate.
- Both trees set `HEADLESS` on, which builds the extra `PPSSPPHeadless` target. Zlyme leaves it off. Not needed.
- Both trees install `wqy-microhei.ttc` over a Roboto filename. The comment cites wenq.org. No license file was in the recipe directory. Do not import it.
- Batocera sets `ARM_NO_VULKAN` on for AArch64 except its Pi boards. That contradicts Zlyme's Vulkan display option. Inappropriate.

### Yabasanshiro

Zlyme `package/emulators/libretro-yabasanshiro` builds the libretro core from `libretro/yabause` branch `yabasanshiro` at `39535a6abcad5abf9f71c8b2a7975f005ee12ed6`, committed 2024-05-23. The recipe comment says June 2023. The commit date is the pin. AArch64 selects platform `odroid-c4` so the unix platform does not pick desktop GL. `000-makefile.patch` adds Pi 5 and RK3588 stanzas and corrects RockPro64. The selected platform is `odroid-c4`, so those stanzas are not the Zlyme build. License field `GPLv2`.

Batocera's corresponding package is `package/batocera/emulators/retroarch/libretro/libretro-yabasanshiro`. It is the same core at `09ed8e5b2e97e7a848ea2514545c34c7b809e399`, committed 2026-08-23. That commit is 14 commits after Zlyme's pin, and the pin is an ancestor. Batocera's `000-makefile.patch` is the same file as Zlyme's, and Batocera applies it on the newer pin. Its RK3568 selection also uses `odroid-c4`. Its generic AArch64 selection uses `unix`, which Zlyme avoids. `001-makefile-add-sm8250.patch` is another SoC. `002-makefile-respect-arch.patch` exists because that unix path takes `uname`. Neither patch applies to Zlyme's selected platform.

The 14-commit diff was read. `0c72d2e506ffb1c4e5efb3efb0c06bdb2fb55201` adds a prototype for `SH2DynShowSttaics` in `yabause.c`. Zlyme currently compiles that call with `-Wno-error=implicit-function-declaration`. That prototype is suitable to adapt by moving the pin to `09ed8e5b2e97e7a848ea2514545c34c7b809e399`. The other diffs are Apple guards, webOS, CI, or the unix dynarec path. They do not change the Linux GLES `odroid-c4` build. Proposed check, not run: build `libretro-yabasanshiro` at that pin with the current patch and confirm `odroid-c4` is still selected. Acceptance is a built `yabasanshiro_libretro.so`. No device test is justified for a prototype and Apple guards. Rollback is the current pin. The build was not run.

KNULLI `package/emulators/yabasanshiro` is standalone. `YABASANSHIRO_VERSION` is the branch name `pi4-update` on `sydarn/yabause`, not a commit. That branch tip was `a40dace1ae0af3ebd45848549fdf396f40e3930f` at 2026-11-03T01:09:42Z. The recipe builds the `retro_arena` SDL binary with EGL, libcurl, Boost, and GLFW. It is not the libretro core. Its patches do not transfer: `001` and `011` are its libchdr external project, `002` is an EmulationStation path, `003` is an SDL audio normalizer, `004` through `009` are that port's NanoVG, menu, FPS, affinity, and CPU flags, and `005` is a SIGUSR1 handler in `thr-linux.cpp`. The libretro interval touches `thr-rthreads.c`, not that file. Batocera has no standalone Yabasanshiro recipe. `libretro-kronos` is a different core and was not compared.

No shared Saturn behavior fix was found in the KNULLI standalone tree. The one transferable source change is the libretro prototype above.

## NextUI pilot, 2026-11-03

`git ls-remote` at 2026-11-03T01:58:45Z returned LoveRetro `NextUI` `main` as `5291344b3aceae5fa197437a70824afb41e2d338`. That is the same SHA as the `UPSTREAM` file in `NEXTUI_VERSION` `f595d7862d8f5dac722aaa9960307609be903db8`. The GitHub compare of that base with itself is identical, so there are zero newer LoveRetro commits. No upstream import is recommended. Nothing in either NextUI repository was edited, and the pin was not moved.

The same read returned `Zetarancio/NextUI` `zlyme` as `f595d7862d8f5dac722aaa9960307609be903db8`, which is the pin. Its subject is a my355 Quickswitcher change, committed 2026-10-27T02:12:55Z. On that fork, the pin is 99 commits ahead of `5291344b3aceae5fa197437a70824afb41e2d338` and zero behind, so the embedded base is an ancestor of the pin. Those 99 commits were not reviewed. They are fork history, not a new LoveRetro interval.

`Zetarancio/NextUI` `main` was `a0628cdc0cee8e173a9bb94144f5c8baa22ab8e7` at the same time. That branch is not the pin, not `zlyme`, and not LoveRetro `main`.

Reviewed-through stays unknown. A zero-commit comparison does not audit LoveRetro history before `5291344b3aceae5fa197437a70824afb41e2d338`. The ROCKNIX survey and its candidate results are unchanged.
