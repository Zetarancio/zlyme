# Linux 7.2.10 migration

Host build on 2026-10-13. The my355 kernel pin moved from Linux 7.0.2 to Linux 7.2.10. The product image was built. It was not installed. It has not been booted on a Flip. Phase 12D stays open.

This is not an MTP fix. USB userspace, the gadget configuration, DWC3, and the Rockchip USB2 PHY were not modified. The preflight is `linux-7.2.10-preflight.md`. The enumeration record is `usb-mtp-phase12d.md`. A later source audit is `driver-source-audit-phase12d.md`. It corrects the `wdev_to_ndev()` sentence below and reviews the dirty image name.

## Release and hash

kernel.org on 2026-10-13 still listed stable 7.2.10 and mainline 7.3-rc7. The RC was not taken. Buildroot stays 2026.08. U-Boot, BL31, TPL, Mesa, glibc, GCC, and `ZLYME_VERSION` were not version-bumped.

Official `sha256sums.asc` and the downloaded tarball both hash to:

`2feaa70453e91f541be6a5c9078d8168e081af45a3d9718054850538cff2ebf3`

That is the line in `board/my355/linux/patches/10-mainline/linux/linux.hash`. Buildroot printed `linux-7.2.10.tar.xz: OK` for that hash. The linux-headers package warns that it has no separate hash file. Headers are the same tarball. The linux package is the check.

Buildroot 2026.08 has no 7.2 headers series. Both defconfigs select `BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_7_1`, whose prompt is "7.1.x or later". That selects `BR2_TOOLCHAIN_HEADERS_LATEST`, so the headers check is loose and accepts 7.2.10. `BR2_KERNEL_HEADERS_AS_KERNEL` still takes the headers from this kernel tree. GCC stays 15.3.0 and glibc stays the Buildroot 2026.08 2.44 snapshot. The existing toolchain was not rebuilt.

## Deferred probe

Linux 7.0.2 sets `driver_deferred_probe_timeout` to 10 when `CONFIG_MODULES` is enabled, and leaves it zero otherwise (`drivers/base/dd.c`). Zero means the timeout condition is already true once initcalls finish. Ten schedules the timeout work for ten seconds. It is not a ten-second stall of the boot.

Linux 7.2.10 moves that into `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT`, default 0 if `!MODULES` and 10 if `MODULES`. Zlyme has `CONFIG_MODULES=y` and no `deferred_probe_timeout=` command line. The fragment sets the symbol to 10 so the policy stays explicit. The preflight's suggestion to force 0 was not followed.

## Patches

All retained patches apply with `patch -F0`. Offsets are allowed. Fuzz is not. `40-kernel-7.0` is empty and is no longer in `BR2_GLOBAL_PATCH_DIR`.

| Patch | Result |
| --- | --- |
| `0005` RTL8733BU Bluetooth | Kept. `btrtl.c` applied with offset. The `btusb.c` hunk was rebased onto the 7.2.10 Realtek table. The id is still `USB_DEVICE(0x0bda, 0xb733)` with `BTUSB_REALTEK`. Attribution stays spycat88. |
| `0001` 1992 MHz OPP | Kept. The 1992 MHz OPP is in `rk3566.dtsi`. |
| `0002` RK817 supply names | Kept. |
| `0003` NVRAM SoC ceiling | Kept. |
| `0007` clear `SYS_CAN_SD` | Kept. The clear is still in the charger probe path. |
| `0008` Mali Bifrost compatible | Kept. The GPU node is `rockchip,rk3568-mali`, `arm,mali-bifrost`. |
| `0021` DMA names | Kept. |
| `0030` RK817 on/off source log | Kept. It only reads the source registers. |
| `0666` CMA | Kept. 256 MiB `linux,cma` default, 4 MiB alignment. |
| `1001` idle states | Kept. |
| `1010` DFI suspend/resume | Kept. `dev_pm_ops` are still registered. |
| `1011a` / `1011b` RK3568 PM | Kept. The SIP subcommands are `0x01`, `0x02`, `0x05`, and `0x09` on `ROCKCHIP_SIP_SUSPEND_MODE`. |
| `1013` VOP2 BCSH | Kept. `vop2_bcsh_update()` still runs from the atomic path. |
| `9901` async suspend off | Kept. `pm_async_enabled` is 0. |
| `0006` DualSense Edge | Removed. Linux 7.2.10 defines `DS_EDGE_BUTTONS_FN1` through `RIGHT_PADDLE` as bits 4–7 and reports them on `BTN_TRIGGER_HAPPY1`–`4` when `ds->is_edge` is set. |

No DWC3 or USB2 PHY patch was added.

## Built-in panel

`drm_panel_init()` is no longer declared for drivers in 7.2.10. `panel-generic-dsi.c` now uses `devm_drm_panel_alloc()`, which zeroes the struct and calls the same init with `DRM_MODE_CONNECTOR_DSI`. That allocator already existed on 7.0.2. Mode timing, reset GPIO, and regulator sequencing were not changed. The kernel build compiled `panel-generic-dsi.c` and produced `rk3566-miyoo-flip.dtb`.

The board DTS was not edited. USB role, PHY topology, VBUS, SD bias, headphone bias, Wi-Fi PHY supply, OPP tables, and U-Boot DTS are the previous values. `dtbs_check` was not run. The schema tools were not part of this build.

## Out-of-tree modules

| Module | Pin | Source change | Compile |
| --- | --- | --- | --- |
| mali-kbase | `39da994bb6fc8819e5e8c1873907dd21d17e53c1` | None. Existing version guards cover `timer_delete_sync` and the void `dma_fence_signal()`. | `mali_kbase.ko`, vermagic `7.2.10 SMP preempt mod_unload aarch64` |
| rk3568-dmc | local | Comment only. Frequencies, voltage, and the six local SIP commands are unchanged. Upstream `0x08` remains `SET_ODT_PD`, so `GET_VERSION` stays a module define. | `rk3568_dmc.ko`, same vermagic |
| miyoo-flip-gamepad | local | None. | `miyoo-flip-gamepad.ko`, same vermagic |
| rtl8733bu-power | local | None. | `rtl8733bu_power.ko`, same vermagic |
| rtl8733bu | `c46aa25e237cb43f33390cf58eee5c69d9b32883` | New `007-linux-7.2-cfg80211.patch`. The six older patches still apply. | `8733bu.ko`, same vermagic |
| panfrost | in-tree `=m` | None. | `panfrost.ko`, same vermagic |

The first RTL compile failed with 16 errors: implicit `strncpy` in three files, `cfg80211_new_sta` / `cfg80211_del_sta` taking `struct wireless_dev *`, `WIPHY_FLAG_SUPPORTS_5_10_MHZ` removed, nine `cfg80211_ops` members changed from `net_device` to `wireless_dev`, and `remain_on_channel` gaining `const u8 *rx_addr`.

`007` keeps a local padded `strncpy` because several copies are counted substrings, not C strings. Station notifications pass `ndev->ieee80211_ptr`. Key and station operations keep their `net_device` implementations and forward from `wdev->netdev`. `remain_on_channel` accepts the new address and ignores it, so the dwell and channel are unchanged. The 5/10 MHz monitor flag is omitted on 7.2 because the enum value is gone. That flag was only under `CONFIG_WIFI_MONITOR`.

The following upstream commit `6821d547` was not taken. It adds similar forwarders, but they call `wdev_to_ndev()`, which 7.2.10 does not provide, and it does not fix `strncpy`, the wiphy flag, or `remain_on_channel`.

That `wdev_to_ndev()` sentence is wrong. The name is a macro in the driver's own `os_dep/linux/ioctl_cfg80211.h` (`#define wdev_to_ndev(w) ((w)->netdev)`), at both `c46aa25` and `6821d547`. Linux does not provide it, and it does not need to. The rest of the sentence stands: that commit does not touch `strncpy`, the removed wiphy flag, or `remain_on_channel`. Detail is `driver-source-audit-phase12d.md`.

`/lib/modules` contains only `7.2.10`. `modules.dep` has 273 lines and no `7.0.2` path.

## Configuration drift

`olddefconfig` used the Buildroot GCC. USB, PHY, gadget, configfs FunctionFS, MMC, Panfrost, RK817, suspend, and module unload did not flip. `CONFIG_MMC_TEST`, `CONFIG_SND_TEST_COMPONENT`, and `CONFIG_SND_AUDIO_GRAPH_CARD2_CUSTOM_SAMPLE` stayed off.

New `=y` architecture and crypto symbols were left on. They are upstream defaults or selects of options Zlyme already had, not new device drivers:

- Arm errata and workarounds: `ARM64_ERRATUM_3821522`, `4118414`, `4193714`, `4311569`, `ARM64_LSUI`, `ARM64_WORKAROUND_BROKEN_AMU_CONSTCNT`, `ARM64_WORKAROUND_DISABLE_CNP`. `HISILICON_ERRATUM_162100125` is also `=y`. It is not a Rockchip driver.
- `CRYPTO_KRB5`, `CRYPTO_KRB5ENC`, and `CRYPTO_CAMELLIA` are selected by the existing `SUNRPC` / NFS GSS path. `CRYPTO_LIB_AES_CBC_MACS` and `CRYPTO_LIB_GF128HASH` replace older library symbols (`CRYPTO_GHASH`, `CRYPTO_DRBG_HMAC`, `CRYPTO_RNG_DEFAULT`) that are no longer separate options.
- `PPPOX=m` is now a visible symbol. `PPPOE=m` was already selected on 7.0.2 and selects it.
- `NET_VENDOR_ALIBABA=y` is the new vendor menu default. `ALIBABA_EEA` depends on `PCI_MSI` and is not built.
- `SCHED_CACHE`, `TIME_NS_VDSO`, `RAID6_PQ_ARCH`, and `XOR_BLOCKS_ARCH` are new arch defaults.

`READ_ONLY_THP_FOR_FS` and `RPCSEC_GSS_KRB5_ENCTYPES_AES_SHA1` disappeared as symbols. They were not turned off in the fragment.

## Build

Commands, in order:

```text
./build.sh --config zlyme_my355_defconfig linux-dirclean mali-kbase-dirclean rk3568-dmc-dirclean miyoo-flip-gamepad-dirclean rtl8733bu-dirclean rtl8733bu-power-dirclean
./build.sh --config zlyme_my355_defconfig
```

The first full build stopped in `panel-generic-dsi.c` (`drm_panel_init` undeclared). After that fix it stopped in `rtl8733bu`. The last command dircleaned `rtl8733bu` so Buildroot applied `007`, then completed the product image. Exit code 0. A separate minimal image was not built. The minimal defconfig carries the same kernel version, headers series, hash, and patch directories.

Boot format is an ARM64 `Image`, gzipped as `Image.gz`, with `rk3566-miyoo-flip.dtb`. The embedded initramfs source directory is 3654486 bytes.

| Artifact | 7.0.2 image, 2026-10-12 | 7.2.10 image |
| --- | --- | --- |
| `Image` | 25843720 | 26273800 |
| `Image.gz` | 12080450 | 12245964 |
| `rk3566-miyoo-flip.dtb` | not remeasured here | 67834 |
| root squashfs | 672571392 | 672739328 |
| `zlyme.img` | 1409306624 | 1409306624 |
| OTA | 735242240 | 735569920 |

`zlyme.img` did not grow, so the boot partition geometry was not changed. The uncompressed kernel grew by 430080 bytes. The squashfs grew by 167936 bytes. The OTA grew by 327680 bytes.

The OTA from this build is `output/images/zlyme-my355-20261013-0a96c787607b-dirty.tar`, SHA-256 `8c77ff9ea2f999587ffe8e46a6fa416704a08eb1da2a4b8894c82d1216b76f90`. The `-dirty` suffix is because the tree was dirty when `make-update-tar` ran. `Image` SHA-256 is `0e84cc7c6797dc76a617ef269ac2f1674eb795ab9b506e8bf7dcd445c5e4c759`. The DTB SHA-256 is `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18`. The squashfs SHA-256 is `f1ceccd9c7d71633304a2f75c61d9d1a98b93bd1ad99c81fd5fcf752363aa595`.

## Hardware still open

Not accepted, and not exercised on this image: boot to NextUI, panel, audio, both SD slots, gamepad, Wi-Fi, Bluetooth, Mali, DMC, charging, deep suspend and wake, the upper USB host, and lower-port MTP enumeration. File transfer stays blocked until enumeration works.
