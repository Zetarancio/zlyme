---
name: zlyme-kernel-upgrade-plan
description: Plan a Zlyme Linux kernel upgrade, compare a newer kernel with the current pin, and inventory patch, module, and Kconfig compatibility. Use when asked to plan a kernel migration, check whether patches still apply, or prepare kernel validation without building.
---

# Kernel upgrade plan

This procedure is optional. Follow `AGENTS.md`. It does not replace `docs/UPSTREAMS.md`, `docs/MAINTENANCE.md`, `docs/DEVELOPMENT.md`, `docs/DEVICE_PORTING.md`, or `docs/OPERATIONS.md`. Hardware facts come from the device wiki. The repository is the implementation.

The default operation is read-only planning. Invoking this skill does not authorize a pin change, a compile, an image, an OTA, or a hardware test. Read the active defconfig. Do not treat a version written in an old note as the current pin.

Before a plan, read those documents and [phase-17-upstream-monitor.md](../../../docs/research/phase-17-upstream-monitor.md). Separate the kernel version, the tarball hash, the upstream tag, the header configuration, the config and fragments, the board DTS, the patch order, in-tree drivers, out-of-tree modules, firmware, userspace interfaces, and the U-Boot pin. They are not one identity.

Then:

1. Read `configs/zlyme_my355_defconfig`, the minimal and ARMHF defconfigs, `board/my355/linux/linux.config`, `board/my355/linux/my355.fragment`, the board DTS, and `board/my355/linux/patches/`. The patch order in `BR2_GLOBAL_PATCH_DIR` is load-bearing.
2. Verify the current tarball hash against kernel.org. Before preferring another release in the same series, check whether that series is still maintained. A newer patch release in an end-of-life series is a comparison target, not automatically the implementation target. Evaluate a maintained stable or longterm candidate, the integration cost, and Miyoo Flip compatibility. Record the UTC time and the maintenance status. Official ROCKNIX `next` is an integration comparison after its live tip is read. It is not the kernel authority. Archived `Zetarancio/distribution` is historical.
3. Classify every local patch from its diff, not from a similar upstream subject. A similar commit is not permission to delete the patch. Use more than one class when they both apply: already upstream, backport, board-specific, still required, potentially obsolete, or needs investigation.
4. Compare the board DTS with the included upstream DTSI, including nodes the board file only comments on. Check out-of-tree modules under `package/drivers/` and any other `kernel-module` package. Keep Mali kbase separate from Panfrost and PanVK.
5. Name the files a later task would edit, the host checks, and the Flip checks that match the behavior that would change. A successful compile is not Flip acceptance. Rollback is the previous known-good image. An OTA does not repair NAND or the bootloader. Do not propose a NAND or U-Boot write as part of a kernel experiment.

`scripts/refresh-kernel-patches.sh` regenerates patch context for Buildroot's `-F0` apply. Use it only in an authorized implementation, after the new patches are copied in. Do not run it during a planning scan. A plan may conclude defer, no change, or needs investigation. Do not select a new pin unless the task explicitly authorizes that selection.
