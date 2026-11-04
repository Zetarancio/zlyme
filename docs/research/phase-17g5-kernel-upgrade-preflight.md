# Phase 17G5 kernel upgrade preflight

2026-11-04. Read-only. No pin, patch, config, module, or image was changed. No host build and no Flip test was run. This file is not the runtime contract.

## Identities

Product and minimal defconfigs set `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` to 7.2.10 and `BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE` to 2026.01. Both set `BR2_KERNEL_HEADERS_AS_KERNEL` and `BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_7_1`. The ARMHF defconfig sets `BR2_KERNEL_HEADERS_7_1` and does not set the 7.2.10 kernel version. `build.sh` pins Buildroot `2026.08`.

`board/my355/linux/patches/10-mainline/linux/linux.hash` records SHA-256 `2feaa70453e91f541be6a5c9078d8168e081af45a3d9718054850538cff2ebf3` for `linux-7.2.10.tar.xz`. kernel.org `sha256sums.asc`, read 2026-11-04T09:10:56Z, has that same line. The tarball's `Last-Modified` was Sun, 11 Oct 2026 13:43:13 GMT. Tag `v7.2.10` is annotated tag object `57eee103859fa039a1f2bf343c4453ef40661be8`; the peeled commit is `7b20d05fd38de8e0be168956f6fd241d750c7d69`.

`BR2_GLOBAL_PATCH_DIR` orders `10-mainline`, then `20-rk3566`, then `30-default`, then the U-Boot and board patch directories. DDR/TPL is `rk3566_ddr_1056MHz_v1.23.bin`. BL31 is `rk3568_bl31_v1.44.elf`. Those boot pins were not compared and were not moved.

## Candidates

Same-series tags present at that read run through `v7.2.15`. Its tarball `Last-Modified` was Sun, 01 Nov 2026 12:55:22 GMT. SHA-256 `d0f6b1d7324c937ccaeb5c4ca7084bfcf71db2edb3e2d3a31f0ad83a681809ab`. Annotated tag `5b4b7d230e9992c9791c0f235412e8347e0317cd`. Peeled commit `497791a0a96b866d90add64041c47acdff49cae6`.

`v7.3.1` also exists. Tarball `Last-Modified` Fri, 30 Oct 2026 12:40:35 GMT. SHA-256 `fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231`. Peeled commit `79a907609d53d5cd645b42c11550d295d43abf99`. It is a different minor. It is not the preferred planning target.

ROCKNIX `next` at `93c889bb853f2a11e51cecb0a9a75221219a2cce`, same UTC read, still sets RK3566 and RK3576 `PKG_VERSION` to 7.2.11. That is behind 7.2.15 and is not Zlyme's kernel authority. This observation does not move the ROCKNIX checkpoint. Archived `Zetarancio/distribution` was not used.

No Flip defect in this scan requires a newer kernel. Recommendation: **defer** the pin. The version a later task should diff against is 7.2.15, not 7.3.1. The commits between 7.2.10 and 7.2.15 were not fully reviewed.

## Patches

Fifteen patches. None were refreshed or deleted. Classes can stack. "Checked" means the named string or default was read in the v7.2.10 and v7.2.15 files below. It is not a full patch rebase.

| Patch | Purpose | Class | What was checked |
| --- | --- | --- | --- |
| `10-mainline` `0005` | RTL8733BU Bluetooth ID, firmware name `rtl8723fu` | Backport, still required | `btrtl.c` has no `8733` string in either tag |
| `20-rk3566` `0001` | 1.992 GHz OPP at 1.150 V, turbo | Board-specific, still required, needs investigation before any voltage change | `rk3566.dtsi` has no `1992000000` in either tag |
| `20-rk3566` `0002` | Supply names `battery` and `charger` | Board-specific, still required | Both tags still say `rk817-battery`. `package/boot/my355-fw-installer/zlyme/common.sh` reads `power_supply/battery/capacity` |
| `20-rk3566` `0003` | NVRAM SoC cap 100000, not 10000 | Backport, still required | Both tags still use `charger->soc > 10000` |
| `20-rk3566` `0007` | Clear `SYS_CAN_SD` | Still required | String absent in `rk817_charger.c` at both tags. The patch records a drain measurement. This scan did not repeat it |
| `20-rk3566` `0008` | Mali reset and power-model nodes | Board-specific, needs investigation | Not diffed against the 7.2.15 GPU node. Keep it separate from Panfrost |
| `20-rk3566` `0021` | Add `dma-names` | Needs investigation | Not diffed against 7.2.15 |
| `20-rk3566` `0030` | Log RK817 on/off source | Board-specific diagnostic, potentially obsolete as a functional requirement | Do not delete until a log consumer is checked |
| `20-rk3566` `0666` | 256 MiB default `linux,cma` node | Board-specific, needs investigation | The fragment also documents `CONFIG_CMA_SIZE_MBYTES` 128. Which size the composed tree uses was not measured. Do not drop the patch because another distribution dropped a CMA node |
| `20-rk3566` `1001` | RK356x idle states | Board-specific, needs investigation | Not diffed against 7.2.15 |
| `20-rk3566` `1010` | DFI suspend and resume | Needs investigation, treat as still required until that diff | Deep-suspend path |
| `20-rk3566` `1011a` and `1011b` | PM suspend binding and driver | Needs investigation, treat as still required until that diff | Pair stays together |
| `20-rk3566` `1013` | VOP2 BCSH through DRM TV properties | Board-specific, needs investigation | Zlyme display controls use it. Not diffed against 7.2.15 |
| `30-default` `9901` | `pm_async_enabled = 0` | Still required | Both tags still set `int pm_async_enabled = 1` |

`scripts/refresh-kernel-patches.sh` rewrites context so Buildroot's `-F0` apply accepts a patch. It is for an authorized implementation after new patches are copied in. It was not run.

## DTS

`rk3566-miyoo-flip.dts` includes `rk3566.dtsi`. The board file enables the upper-port OHCI `usb_host0_ohci` and the Wi-Fi EHCI `usb_host1_ehci`. It does not contain a node for `usb_host1_ohci`. The comment says `fd8c0000` is disabled. In `rk356x-base.dtsi` at v7.2.10 and v7.2.15, `usb_host1_ohci` is `usb@fd8c0000` with `status = "disabled"`. No patch in `board/my355/linux/patches` mentions that node. The effective status is the upstream disabled default. This scan did not boot a composed DTB.

Shared `vqmmc` on the two SD slots, the panel, HDMI, RK817, and the gamepad stay board properties. Their nodes were not rebased onto 7.2.15. A later migration diffs those nodes. It does not copy another distribution's DTS.

## Modules

`package/` has five `kernel-module` recipes, all under `package/drivers/`:

| Package | Kind | Pin | Note |
| --- | --- | --- | --- |
| `mali-kbase` | Module | `rocknix/mali_kbase` `39da994bb6fc8819e5e8c1873907dd21d17e53c1` | Recipe says the pin matches 7.2.10. GPL-2.0. `WQ_PERCPU` is present in `include/linux/workqueue.h` at both tags. Whether this pin builds on 7.2.15 was not tested |
| `rtl8733bu` | Module | `c46aa25e237cb43f33390cf58eee5c69d9b32883` | GPL-2.0. The recipe says a newer driver tip does not match Linux 7.2. Do not move that pin with the kernel |
| `rtl8733bu-power` | Module | Local | GPIO0_A0 enable. GPL-2.0-only |
| `miyoo-flip-gamepad` | Module | Local | GPL-2.0-only |
| `rk3568-dmc` | Module | Local | GPL-2.0-only |
| `rtl8723fu-firmware` | Firmware, not a module | Local `rtl_bt` files | Proprietary. `REDISTRIBUTE = NO`. Loaded as `rtl_bt/rtl8723fu_{fw,config}.bin` |

`my355.fragment` records that a `DEBUG_SPINLOCK` change resizes `struct module`. Joypad, 8733bu, and mali_kbase must be rebuilt with the kernel. Panfrost is `CONFIG_DRM_PANFROST=m` in that fragment. It is not a substitute for mali-kbase.

## Userspace

A kernel move does not by itself change PipeWire, the direct KMS path, or the lack of a permanent compositor. Real interface risks are the `battery` supply name, module vermagic, the initramfs source that `external.mk` fills in, the RTL firmware name, and the VOP2 BCSH properties if `1013` fails to apply. Header packaging still uses the 7.1-or-later symbol while the kernel is 7.2.10. A later task checks whether that symbol still matches.

## Later implementation

Not authorized now.

Stage A. Keep 7.2.10 until a task selects 7.2.15. Record the kernel.org hash above. Edit the product and minimal version lines and `linux.hash` together. Leave U-Boot, BL31, and TPL alone.

Stage B. Rebase the fifteen patches in the existing order. Delete one only after its behavior is shown to be in the candidate. Run `scripts/refresh-kernel-patches.sh` only then.

Stage C. Host checks, not run here: patch apply with Buildroot `-F0`, olddefconfig against renamed symbols, the board DTS build, and a rebuild of the five modules. A clean compile is not Flip acceptance.

Stage D. A later authorized image would record the kernel version, `linux.hash`, the module package versions, and the image checksum. This phase produces none of those artifacts.

Stage E. If a build is later authorized, the Flip checks that match this inventory are cold boot, the `battery` supply, both SD slots, upper-port low-speed USB, the Wi-Fi chip, one Panfrost and one mali path, speaker and HDMI audio, the gamepad and lid, suspend and resume, and shutdown. Unrelated Phase 16 tests are not repeated only because the version number changed.

Stage F. Rejection is a patch that only applies by deleting a still-required behavior, a module that fails `insmod`, or a DTS that enables `fd8c0000` or drops the upper-port OHCI. Rollback is the previous known-good image. Do not use NAND or U-Boot writes to recover a kernel experiment.

## Open

The changelog from 7.2.10 to 7.2.15 was not reviewed commit by commit. `0008`, `0021`, `1001`, `1010`, `1011a`, `1011b`, and `1013` were not diffed against 7.2.15. The composed CMA size was not measured. mali-kbase was not built. Reviewed-through stays unknown.

## Maintenance status, 2026-11-04

kernel.org `releases.json`, read 2026-11-04T09:26:15Z, marks Linux 7.2.15 with `iseol` true. Its moniker field is still `stable`. Linux 7.3.1 is `stable` and is not end of life. Linux 6.18.60 is the current point in the 6.18 longterm series, which is not end of life. 6.12, 6.6, 6.1, 5.15, and 5.10 are also longterm.

The earlier choice stands: 7.2.15 is the immediate same-series comparison baseline. It is not an accepted pin. A move only to 7.2.15 would not put Zlyme on a series kernel.org still maintains. Staying on 7.2.10 keeps the known patches and modules, and it also stays on a series that no longer receives stable updates. A hardware-sensitive migration stays deferred until a maintained stable or longterm target is evaluated and tested. 7.3.1 and the longterm series are comparison candidates, not pins. No migration is authorized.
