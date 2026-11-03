# Phase 17 upstream monitor

Status, 2026-11-03: a checkpoint format and one ROCKNIX observation. This file does not move a pin, apply a patch, or authorize a build or a device test. Policy stays in `docs/UPSTREAMS.md`.

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

A failed or partial scan does not move "Reviewed through". A rewritten upstream history is reported. It does not silently reset the cursor. The Phase 0 snapshot in `docs/UPSTREAMS.md` is historical. The Compared revisions table records specific comparisons, including pins the current tree still uses. Neither table is one of these cursors.

## Checkpoints

| Source | Last observed HEAD | Observed at | Reviewed through | Triage date | Scope | Outstanding |
| --- | --- | --- | --- | --- | --- | --- |
| ROCKNIX `ROCKNIX/distribution` branch `next` | `ca1093d0ae055453fcdd67f5f9515a214230de2c` | 2026-11-03T00:30:47Z | Unknown | | 415 commits enumerated after `f2148e8061e38a44d1b71bac3efeddb0c9385084`. Subjects and paths read. Diffs read for the ten named candidates, the Mali cleanup, and one RK3566 config cleanup. | See the ROCKNIX section. Not an integration point. |
| KNULLI `knulli-linux` branch `knulli-main` | Not observed in 17G1 | | Unknown | | | |
| Batocera `batocera.linux` branch `master` | Not observed in 17G1 | | Unknown | | | |
| LoveRetro `NextUI` branch `main` | Not observed in 17G1 | | Unknown | | Zlyme's NextUI pin is a package pin, not this cursor. | |
| apommel `baseos-my355` branch `main` | Not observed in 17G1 | | Unknown | | | |
| Selected Linux | Version 7.2.10, tarball named in `board/my355/linux/patches/10-mainline/linux/linux.hash` | 2026-11-03, from the Zlyme pin, not a kernel.org git read | Unknown | | `configs/zlyme_my355_defconfig` sets `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` to 7.2.10. No kernel branch was invented. | |

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
