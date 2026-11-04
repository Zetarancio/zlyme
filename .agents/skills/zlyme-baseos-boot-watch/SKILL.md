---
name: zlyme-baseos-boot-watch
description: Check apommel BaseOS for new U-Boot commits, boot-chain fixes, and Miyoo Flip improvements, and propose a Zlyme adaptation without applying it. Use when asked to watch BaseOS, compare U-Boot, or review boot and recovery changes.
---

# BaseOS boot watch

This procedure is optional. Follow `AGENTS.md`. It does not replace `docs/UPSTREAMS.md`, `docs/DEVELOPMENT.md`, `docs/DEVICE_PORTING.md`, or `docs/OPERATIONS.md`. Hardware facts come from the device wiki.

The default operation is read-only. Do not edit source, compile U-Boot, build an image, write NAND or storage, enter MASKROM, make an OTA, or run a hardware test. A newer BaseOS commit does not move Zlyme's U-Boot version. Discovery is not implementation.

These identities are different. Read each one.

- `apommel/baseos-my355` branch `main` is the live tip.
- The BaseOS row in [phase-17-upstream-monitor.md](../../../docs/research/phase-17-upstream-monitor.md) holds the last observed HEAD and the reviewed-through cursor. An observed HEAD is not a review.
- `MY355_FW_INSTALLER_VERSION` is the stock-installer pin. It is not that cursor.
- Zlyme's U-Boot pin is `BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE` in `configs/zlyme_my355_defconfig`, with the hash in `board/my355/uboot/patches/uboot/uboot.hash`.
- `board/my355/uboot/patches/uboot/` holds Zlyme's U-Boot patches. Production patches stay `001` through `007`.
- `BR2_PACKAGE_ROCKCHIP_RKBIN_TPL_FILENAME` and `BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME` are the DDR/TPL and BL31 pair.
- `package/system/zlyme-preloader/preloader-stock.img` is the known vendor preloader. The recovery preloader is the one-entry image recorded in `docs/ARCHITECTURE.md`. Erasing the preloader is not MASKROM recovery.
- Archived `Zetarancio/distribution` is historical evidence, not live upstream.

Before a comparison, read the documents above and the checkpoint. Read the wiki when a hardware fact is required.

Then:

1. Read Zlyme's U-Boot configuration, patches, boot scripts, and the pins above.
2. Verify the live `main` tip. List the interval after the recorded comparison start. Do not treat the installer pin as a completed review, and do not treat an earlier observation as proof that every commit through it was reviewed.
3. Read subjects, paths, and the diffs. Prefer U-Boot, the boot chain, SD boot, charging, and recovery. Include a later correction or revert. A mainline U-Boot change outside the interval is historical context, not a new commit in the range.
4. Check whether selected upstream U-Boot or Zlyme already has the behavior. Do not copy BaseOS's updater, vendor-kernel DTB rewrite, init, or filesystem layout. Classify with the classes in `docs/UPSTREAMS.md`.
5. For a potentially useful commit, name the BaseOS SHA, date, and paths; the problem; whether Zlyme is affected; the Zlyme files and the smallest adaptation; dependencies and patch conflicts; the benefit and the regression; the host check; a device test only when one is needed; and the rollback or rejection test. End with one recommendation: investigate, adapt later, already present, or do not import. Do not apply it.

Mark a candidate hardware-critical when it touches DDR, TPL/SPL, BL31, BootROM order, U-Boot boot targets, recovery or MASKROM, stock firmware install, NAND, raw block writes, SD enumeration, regulators, or boot voltage and charging. Recommending implementation then requires the current and proposed source, wiki evidence, expected Flip behavior, boot-media compatibility, recovery, the host check, the proposed device test, and the brick case. That recommendation is not authorization. A host check is not Miyoo Flip acceptance.
