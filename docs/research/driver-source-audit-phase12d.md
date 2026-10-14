# Driver source audit, Phase 12D

Read-only comparison on 2026-10-13, after the Linux 7.2.10 host build. No package pin, patch, DTS, firmware, or kernel version was changed. Phase 12D stays open. The image has still not been booted.

The migration record is `linux-7.2.10-migration.md`. This file corrects one sentence in it: `wdev_to_ndev()` is a macro in the RTL driver, not a missing Linux helper.

## 1. RTL8733BU: the `wdev_to_ndev()` correction

`package/drivers/rtl8733bu/rtl8733bu.mk` still says a newer tip calls `wdev_to_ndev()`, which Linux 7.2 does not provide. The migration record said the same about commit `6821d547`. Both sentences confuse a driver macro with a kernel API.

`os_dep/linux/ioctl_cfg80211.h` in the pinned tree defines:

```c
#define wdev_to_ndev(w) ((w)->netdev)
```

That line is present at `c46aa25e237cb43f33390cf58eee5c69d9b32883` and at `6821d547f9facea4dfae83890ebcd15e2e254eac`, both at line 271. The header already uses the macro for `cfg80211_rx_mgmt`, connect, and disconnect wrappers. Linux 7.2.10's `struct wireless_dev` has a `netdev` member. The macro is the driver's name for that member.

`6821d547` is one file, `os_dep/linux/ioctl_cfg80211.c`, +60/−11. It does three things:

- `cfg80211_new_sta` and `cfg80211_del_sta` take `ndev->ieee80211_ptr`.
- Nine `_wdev` forwarders call the existing `net_device` implementations through `wdev_to_ndev()`.
- `rtw_cfg80211_ops` points at those forwarders. `set_default_key`, `change_bss`, and `start_ap` stay on `net_device`.

The nine callbacks match `include/net/cfg80211.h` in the built 7.2.10 tree: `add_key`, `get_key`, `del_key`, `set_default_mgmt_key`, `add_station`, `del_station`, `change_station`, `get_station`, `dump_station`. Each signature in `6821d547` matches the 7.2.10 function-pointer type, including `link_id`. The forwarders are unconditional. The commit message says this tree's only kernel is 7.1, and the author reports association on an onboard RTL8733BU there. That report is not a Zlyme test.

Zlyme's `007-linux-7.2-cfg80211.patch` repeats those nine forwarders and the two station notifications. The forwarders are the same calls. Upstream writes `wdev_to_ndev(wdev)`. The local patch writes `wdev->netdev`. The macro makes those the same expression. Upstream does not version-guard them. The local patch guards them with `LINUX_VERSION_CODE >= KERNEL_VERSION(6, 14, 0)`, which is true for 7.2.10 and is extra text on a kernel Zlyme no longer builds.

`007` also contains three changes `6821d547` does not:

- a padded `strncpy` stand-in, because 7.2.10's `linux/string.h` no longer declares `strncpy`;
- `remain_on_channel`'s new `const u8 *rx_addr` argument;
- `WIPHY_FLAG_SUPPORTS_5_10_MHZ` compiled out on 7.2, because the flag is gone.

The tip `2b72111f68d4cfafa27f189761448c61a8b325c8` is `6821d547` plus `LICENSE`, `.gitignore`, and `README.md`. The driver C is the same.

### Patch application

Disposable checkouts, `patch -p1 -F0`, patches applied in order:

| Base | 001–006 | Full `007` |
| --- | --- | --- |
| `c46aa25` (the pin) | Each hunk applied | Applied |
| `2b72111` (the tip) | Each hunk applied | The `strncpy` hunk in `osdep_service_linux.h` applied. All six hunks in `ioctl_cfg80211.c` were then skipped as already applied, including the `rx_addr` and wiphy hunks that are not in the tip |

Applying the whole of `007` on the tip is the wrong operation. The forwarder hunks make `patch` treat the file as already patched and drop the 7.2-only hunks with them.

A reduced patch with only the `strncpy` block, the `rx_addr` argument, and the wiphy guard applied cleanly on `2b72111` after 001–006.

### Isolated module build

The reduced tree was compiled against the existing `output/build/linux-7.2.10` tree with the Buildroot `aarch64-buildroot-linux-gnu-` toolchain, `CONFIG_RTL8733BU=m`, `KCFLAGS=-Wno-attribute-alias`, and `WERROR=0`. Those are the flags the product build already uses. Nothing was installed into `output/target`.

| Result | Value |
| --- | --- |
| Object | `/tmp/zlyme-audit/tip-red/8733bu.ko` |
| Size | 5765864 bytes, the same size as the installed module |
| SHA-256 | `3e7a728f97ccf8e212455b017d2faaa3bb0ca6c028d539cbed66d90c0017bbd0` |
| Installed module | `7b55504a3dbc9d58f76e7d9dbf9d82edbad4984bd92cd32afdca0766141ce049` |
| vermagic | `7.2.10 SMP preempt mod_unload aarch64` |
| `error:` lines | none |
| Driver warnings | The same set as the product `rtl8733bu` build. This host also printed the existing pahole version warning |

The hashes differ, so the forwarder spelling is not byte-identical in the object. The warning set did not grow a new driver diagnostic.

Moving the pin to `2b72111` would let `007` shrink to those three 7.2 hunks, and 001–006 would stay. It would not remove the `strncpy` or `remain_on_channel` work. It is a maintenance reduction, not a behavior fix, and it was not applied to the package.

## 2. `strncpy`

`007` defines `rtw_strncpy` and then `#define strncpy rtw_strncpy` for `LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)` in `include/osdep_service_linux.h`. The copy writes each byte until `n` or a NUL, then zero-fills the rest, and returns `dst`. That is `strncpy`. `strscpy` and `strscpy_pad` always plant a NUL inside the count, so a call whose count equals the string length drops the last byte. Several call sites use `strncpy` that way on purpose.

The Zlyme module compiles `CONFIG_WIFI_MONITOR`, `CONFIG_PROC_DEBUG`, `CONFIG_RTW_DEBUG`, and `CONFIG_IOCTL_CFG80211`. It does not pass `CONFIG_SUPPORT_MULTI_BCN`, `CONFIG_CLIENT_PORT_CFG`, or `RTK_DMP_PLATFORM`.

| Site | Compiled | Class | Why `strscpy` is the wrong swap |
| --- | --- | --- | --- |
| `core/rtw_debug.c` hex dump, the `strncpy(p, str_val, len)` calls after `snprintf` | Yes | Counted concatenation. `len` is the characters written, not including the NUL. The destination buffer was zeroed. | A count of `len` would keep `len-1` characters and write a NUL in the middle of the line. `memcpy(p, str_val, len)` matches this site. |
| `core/rtw_debug.c` around 779–805, `ap_id` / `c_pid` | No. Those blocks need `CONFIG_SUPPORT_MULTI_BCN` or `CONFIG_CLIENT_PORT_CFG`. | Same counted concatenation | Same |
| `core/rtw_wlan_util.c` `strncpy(member, input, len)` | Yes, the function is in a built file | Counted token. `len` is the prefix before `:`, and the source was just terminated one byte later. | Same off-by-one if the count stays `len`. |
| `hal/hal_com.c` `ParseQualifiedString` | Yes | Fixed-width slice of `j - i + 1` bytes between delimiters. The slice is not a C string. | `strscpy` stops at an interior NUL and writes its own. |
| `hal/hal_com_phycfg.c` `band` / `path` / `sign` | Yes | Fixed-width 2-, 1-, and 1-byte slices into 5-byte arrays that were initialized to empty strings. The tail NUL is already there. | `strscpy_pad(band, src, 2)` keeps one character. |
| `hal/phydm/phydm_debug.c:6127` | No. It sits under `#if 0`. | Firmware-debug bytes |  |
| `hal/phydm/phydm_debug.c:6158` | Yes | `cmd_len - 1` firmware-debug bytes. The driver plants a NUL later. | An interior NUL would stop `strscpy` early. |
| `ioctl_cfg80211.c` and `ioctl_linux.c`, `param->u.crypt.alg` | Yes | Padded field, `IEEE_CRYPT_ALG_NAME_LEN` is 16. The names are short C strings (`CCMP`, `TKIP`, `WEP`, `SMS4`). | `strscpy_pad(dst, alg_name, 16)` matches these two sites. |
| `ioctl_cfg80211.c` monitor `netdev` name, and `os_intfs.c` `old_ifname` | Yes. Monitor is compiled. | C strings. Each site then writes a NUL at `IFNAMSIZ - 1`. | `strscpy` matches, because the explicit NUL is already there. |
| `rtw_cfgvendor.c` ring name | Yes. The file is under `CONFIG_IOCTL_CFG80211` and kernel 3.14 or newer, both true here. | Netlink payload, copied for `min(31, nla_len)` into a 32-byte zeroed array. The attribute is not required to be a C string. | `strscpy` may read past `nla_len` looking for a NUL. The counted copy must stay. |
| `usb_intf.c` `strncpy(ifname, "wlan10", 6)` | No. `RTK_DMP_PLATFORM` is not set. | C string |  |

The global macro is what makes the module compile, and it preserves every one of those byte counts. It is also broader than the call sites: any later `strncpy` in a file that includes the header becomes the local function. Replacing each site with `memcpy`, `strscpy`, or `strscpy_pad` as classified above would make the intent visible and would allow the macro to go away. That is a cleanup, not a behavior change, and it was not done here.

## 3. cfg80211 behavior

`cfg80211_new_sta` and `cfg80211_del_sta` in 7.2.10 take `struct wireless_dev *`. Both the local patch and `6821d547` pass `ndev->ieee80211_ptr`. For a netdev that cfg80211 has attached, that pointer is the interface's wdev. Neither side adds a NULL test. The previous code passed `ndev` itself, so a NULL `ndev` was already fatal.

The nine forwarders do not test `wdev` or `wdev->netdev`. Other functions in the same file do (`if (wdev_to_ndev(wdev))` before `rtw_netdev_priv`). A P2P-device wdev has a NULL `netdev`. The module is still built with `-DCONFIG_P2P`. Patch 005 removes the second virtual interface, not the P2P compile flag. A key or station call on a P2P-device wdev would pass NULL into the `net_device` implementation. The local patch and `6821d547` share that assumption. Zlyme does not exercise P2P; the risk is untested, and it is not new with 7.2.10.

`set_default_key`, `change_bss`, `start_ap`, `auth`, `assoc`, and `connect` still take `struct net_device *` in 7.2.10. Neither patch rewrites them.

`remain_on_channel` gained `const u8 *rx_addr`. `nl80211_remain_on_channel()` sets that pointer from `NL80211_ATTR_MAC`. If the attribute is present and the wiphy does not advertise `NL80211_EXT_FEATURE_ROC_ADDR_FILTER`, nl80211 returns `-EOPNOTSUPP` before the driver runs. The driver sets `WIPHY_FLAG_HAS_REMAIN_ON_CHANNEL` and does not set `NL80211_EXT_FEATURE_ROC_ADDR_FILTER`. The only calls that reach the driver have `rx_addr == NULL`. Ignoring the pointer keeps the previous dwell and channel. It does not implement address filtering, and the driver does not claim that feature. The 7.0.2 callback had no address argument, so this is not a dropped filter.

`WIPHY_FLAG_SUPPORTS_5_10_MHZ` is absent from 7.2.10. The assignment is under `CONFIG_WIFI_MONITOR`, which this module enables, so the guard is required for the compile. The flag was a monitor-debug bit. 5 MHz and 10 MHz operation was not a Flip Wi-Fi mode.

`wdev->connected` in patch 004 is the cfg80211 flag `__cfg80211_disconnected()` clears. The patched indication returns when that flag is already clear, so the first disconnect still runs and a second indication does not release the BSS again. An earlier form of the patch blocked the first indication and left randomized scans refused. That form is not what 004 contains. 004 applied unchanged on both the pin and the tip.

## 4. RTL patches 001–006

On `2b72111`, 001 through 006 each apply with `patch -F0`. They are not already in that tree. The tip is the same C as `6821d547`.

| Patch | On the Charliechen tip | On ROCKNIX `308919f`, wirenboard `2d9048b`, libc0607 `2ec19e1` |
| --- | --- | --- |
| 001 USB shutdown | Still required. The tip still assigns `driver.shutdown`, which `usb_register_driver()` replaces from 6.8 on. | Same broken assignment, written as `.usbdrv.driver.shutdown` in the `>= 6.8` branch. |
| 002 suspend wait and `reset_resume` | Still required. The unbounded `bips_processing` wait and the `reset_resume = rtw_resume` alias are still there until the patch. | The wait is still unbounded. `reset_resume` is still `rtw_resume`. |
| 003 shutdown disconnect race | Still required. It is the flag that stops a second driver-side disconnect during `rtw_dev_shutdown()`. | The helper exists. The shutdown-time arming in 003 does not. |
| 004 one disconnect indication | Still required. The `wdev->connected` test is not upstream. | No `wdev->connected` test. |
| 005 one interface | Still required. The static Kbuild still passes `-DCONFIG_CONCURRENT_MODE` until 005 deletes it. | ROCKNIX's commit message says concurrent mode was disabled. The Makefile still has `EXTRA_CFLAGS += -DCONFIG_CONCURRENT_MODE` in several platform blocks. |
| 006 SAE / WPA3 | Still required. STA external-auth still records the status and returns, and `set_pmksa` still starts an association, until 006 moves `start_clnt_assoc()` and removes the extra one. | ROCKNIX still starts association from `set_pmksa` and does not start it from the STA external-auth result. That is the pair 006 exists to undo. |

004's first-indication behavior is the one that was confirmed on a Flip running 7.0.2. Nothing in this audit retests it.

## 5. Other RTL trees

| | Charliechen pin | Charliechen tip | ROCKNIX/RTL8733BU | wirenboard/rtl8733bu | libc0607/rtl8733bu-20240806 |
| --- | --- | --- | --- | --- | --- |
| Commit | `c46aa25e237cb43f33390cf58eee5c69d9b32883` | `2b72111f68d4cfafa27f189761448c61a8b325c8` | `308919f005f439de433aac977f925bb57f59acf4` | `2d9048be60759206b8db5e2370420333ef0b8478` | `2ec19e154cffbc2abd98d43d59278dffa6e50d49` |
| Date | 2026-06-20 | 2026-06-20 | 2025-01-04 | 2024-02-13 | 2025-06-07 |
| `DRIVERVERSION` | `v5.15.12-264-gdd9219782.20250922_COEX20241204-390f` | same | `v5.15.12-126-gb999e6008.20240911_COEX20230616-330e` | `v5.13.0.1-112-g10248f4f3.20230626_COEX20230616-330e` | `v5.15.12-123-g23d8f6271.20240806_COEX20230616-330e` |
| Build | Static Kbuild, `ccflags-y`, `CONFIG_RTL8733BU=m` | same | Old multi-platform Makefile. No `ccflags-y`. | Same old Makefile | Same old Makefile |
| 7.2 build | Product module, with 001–007 | Isolated module, with 001–006 and a reduced 007. Linked. | `M=` and `CONFIG_RTL8733BU=m` fails at once: `drv_types.h` is not on the include path. No `.ko`. | Not built. Same Makefile shape as ROCKNIX, and an older vendor drop. | Not built separately. No `ccflags-y`, so the same include-path failure applies. |
| License | `SPDX-License-Identifier: GPL-2.0` on the Makefile. Source files say GPL version 2. The tip adds a GPL-2.0 `LICENSE` file. | GPL-2.0 `LICENSE` | No `LICENSE` file | No `LICENSE` file | A GPL-3 `LICENSE` file next to GPL-2 source headers. The two texts disagree. |
| Wi-Fi / Bluetooth | Wi-Fi only. Bluetooth stays the kernel `btrtl` patch and `rtl8723fu` firmware. Power stays `rtl8733bu-power`. | Unchanged from the pin | Same split | Same split | Same split |
| Firmware | `-DREALTEK_CONFIG_PATH=\"/lib/firmware/\"` and the efuse path in `ccflags-y`. The tip does not change those strings. | same | Older coex string `COEX20230616-330e` | Older still | `COEX20230616-330e` |

The Charliechen tip is the only newer source that is the same driver plus the forwarders Zlyme already reimplemented. The other three are older vendor snapshots. They do not contain 001–006, and they do not build as a Kbuild module against 7.2.10.

## 6. libmali

The package pin is JeffyCN/mirrors `4233031d818e97a19e8a9cdbbd5c15795ededd93` (2026-06-26). The commit message updates Valhall G310/G610 blobs to g29p1. The G52 file was already in that tree and is what Zlyme installs: `lib/aarch64-linux-gnu/libmali-bifrost-g52-g29p1.so`.

| | Shipped blob | Jeffy `libmali` tip | ROCKNIX/libmali | tsukumijima/libmali-rockchip |
| --- | --- | --- | --- | --- |
| Commit | `4233031d818e97a19e8a9cdbbd5c15795ededd93` | `34f626298b0e8f884545365b66bb47678266e8d7` (2026-09-20) | `0fe30426b822699f0a660268a6040fdafce229d1` (2026-01-01) | `ec78b74adc038f97cf173f4061fe3856efc0dc74` (2026-09-22), a merge of Jeffy's `libmali` branch |
| G52 file Zlyme uses | `libmali-bifrost-g52-g29p1.so` | That filename is absent | That filename is absent | That filename is absent |
| Size | 59855128 bytes in the git tree. The installed file is 59853152 after strip. | Closest aarch64 G52 GBM build is `libmali-bifrost-g52-g24p0-gbm.so`, 56287608 bytes | Same g24p0 GBM file | Same g24p0 GBM file |
| Git blob | `10523086280cb767721d9389905aca61b3075e39` | g24p0 GBM blob `f78a3620ce58573fddd5aa5f5afa103d7949a134` | same `f78a3620ce58…` blob | same `f78a3620ce58…` blob |
| SHA-256 of the unstripped file Zlyme builds | `605e3a5caf1be62bb48d97b1168434257355d56db5e3be9b515cfa742c173118` | Not the same bytes. Different size and blob. | Not the same bytes | Not the same bytes |
| ELF | aarch64, `SONAME` `libmali.so.1`, `NEEDED` `libdrm.so.2` plus libstdc++, libm, libc, libgcc, libpthread, libdl | Not inspected. It is a different file. | Same blob as the Jeffy tip g24p0 GBM file | Same blob |
| Strings in the shipped blob | `arm_release_ver: g29p1-12eac0, rk_so_ver: 5` and `1.5 Bifrost-"g29p1-12eac0"` | A g24p0 name is a different DDK label. No claim that it speaks the same ioctl ABI. |  |  |
| Exports in the shipped blob | `egl*`, `gl*`, `gbm_*` (39), OpenCL `cl*` (153), `vk_icdGetInstanceProcAddr`, `vk_icdNegotiateLoaderICDInterfaceVersion` |  |  |  |
| License | Arm `END_USER_LICENCE_AGREEMENT.txt`, LES-PRE-20769, 25 November 2015. The package marks it Proprietary. Redistribution is the Arm EULA's distribution clause, not a GPL grant. | Same upstream tree, later commit. The EULA was not re-read as a new grant. | Describes itself as a mirror of Jeffy's `libmali` branch | Same description |

The three later trees share one g24p0 GBM blob and do not contain the g29p1 file Zlyme ships. g24p0 is a different binary, not a rebuild of g29p1. G610/Valhall files in the same commits are a different GPU family. There is no measurement here that g24p0 runs on the Flip's G52 with the pinned kbase.

## 7. mali-kbase

The package pin is `rocknix/mali_kbase` `39da994bb6fc8819e5e8c1873907dd21d17e53c1` on `bifrost_port` (2026-04-06, "dma fence 7.0 compatibility"). `gh api repos/rocknix/mali_kbase/commits?per_page=8` returns that commit as the newest. There is no later commit on that repository to move to.

The built module's version string is `r54p2-02eac0` (`MALI_RELEASE_NAME` in the midgard `Kbuild`, UK version 11.46). The userspace blob identifies itself as `g29p1-12eac0`. Those are different DDK labels. Zlyme ships the pair together. This audit did not find an ioctl table that proves they are interchangeable with some other pair, and it did not find a newer kbase that claims the g29p1 userspace. Replacing either side alone is an untested ABI change.

`002-lowercase-interrupts-first.patch` tries `job`, `mmu`, `gpu` before `JOB`, `MMU`, `GPU`. The built `rk356x-base.dtsi` names the GPU interrupts `job`, `mmu`, `gpu`. The pin's unpatched source tries the capital names first. The patch is still the thing that matches the DT. No upstream equivalent appeared in a later kbase commit, because there is no later commit.

GPU voltage and clocks were not touched. The board DTS `mali-supply` is still `vdd_gpu`. Panfrost remains the other stack, selected by `/storage/.config/zlyme/gpu`, with libmali as the default. Mesa 26.1.8's PanVK still returns `VK_ERROR_INCOMPATIBLE_DRIVER` for Mali-G52 unless `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1`. This audit did not set that. Later source exports it only for an exact `panfrost` choice. Making Panfrost the default would be a separate product decision with its own GLES and power measurements. This audit does not make it.

## 8. The 7.2.10 commits, re-read

Commits `3891798e88a4a61187bffa5ed1b58e6c5d4efb84`, `76ab1233e395b6056c7ae1287e78b11e65833360`, and `8b066182f6131ed91231953630cedf6f16d9ddd3`.

The panel probe uses `devm_drm_panel_alloc()`. In 7.2.10 that helper `kzalloc`s the container, takes a kref, registers `drm_panel_put` as a devm action, and calls the now-static `drm_panel_init()` with the DSI connector type. `drm_panel_init` fills the list heads, the device, the funcs, and the connector type. It does not take a second kref. `mipi_dsi_set_drvdata` is still called. `drm_panel_add` still runs after backlight setup. `generic_panel_remove` still shuts the panel down, detaches DSI, and calls `drm_panel_remove`. Mode timing, reset GPIO, and the regulator sequence are the same lines as before the allocation change. `drm_panel_add`'s own comment says the panel must have come from `devm_drm_panel_alloc()`.

The Bluetooth patch adds `USB_DEVICE(0x0bda, 0xb733)` with `BTUSB_REALTEK` in the built `btusb.c`. It does not replace that id with the existing Realtek interface wildcard. The built kernel tree's `panel-generic-dsi.c` matches the file in this commit. The built `8733bu` sources match a fresh apply of 001–007 from this commit onto `c46aa25`.

`CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=10` is in the fragment and in the built `.config`. Both defconfigs select `BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_7_1` because Buildroot 2026.08 has no 7.2 series symbol. That choice is what makes the headers check loose. The headers themselves are the 7.2.10 tree.

`/lib/modules` contains only `7.2.10`. The five out-of-tree modules and `panfrost.ko` have vermagic `7.2.10 SMP preempt mod_unload aarch64`.

`.gitattributes` turns off `space-before-tab` and `trailing-space` for `*.patch`. A unified-diff context line is a leading space plus the kernel tab, and a blank source line is a single space, so those two checks fire on every normal kernel patch. `git diff --check` on the three commits, excluding `*.patch`, is clean. Added lines inside the patches do not contain a `+` source line whose indent is space-then-tab. The attribute would also hide a real trailing space on a future added source line inside a patch. These three commits do not have one.

`make-update-tar.sh` writes `git describe --always --dirty` into the tar's `VERSION` file and into the filename. The artifact from the host build is `zlyme-my355-20261013-0a96c787607b-dirty.tar`. Its `VERSION` is `0a96c787607b-dirty` and `20261013`. `kernel.release` is `7.2.10`. The kernel and RTL sources in the build tree match the commits above. `output/build/rk3568-dmc-local/rk3568_dmc.c` differs from the committed file only in the comment that the docs commit updated. The compiled DMC code is the pre-comment text. A later clean build would compile that comment and would name the tar from `8b06618` or whatever HEAD is then.

## 9. Verdicts

- Keep the RTL pin `c46aa25` for the hardware candidate. The module is already built and matches the committed patches.
- Moving to `2b72111` and shrinking `007` to `strncpy`, `rx_addr`, and the wiphy guard is a real reduction. 001–006 still apply, and an isolated 7.2.10 module linked. It is not required for the first boot, and it changes the Wi-Fi object hash, so it wants its own build before it is the module under test.
- Do not replace the RTL tree with ROCKNIX `308919f`, wirenboard `2d9048b`, or libc0607 `2ec19e1`. They are older vendor drops, they lack 001–006, and they do not build as this package's Kbuild module.
- Keep libmali `4233031` and `libmali-bifrost-g52-g29p1.so`. The newer Jeffy, ROCKNIX, and tsukumijima trees no longer contain that file. Their shared G52 GBM blob is g24p0 and is not this binary.
- Do not replace mali-kbase. `39da994` is the tip of `rocknix/mali_kbase`. The userspace DDK string is `g29p1-12eac0` and the module string is `r54p2-02eac0`. Swapping one side is not justified by a filename or a date.

## 10. What a later change would be

None of this is authorized by the audit.

1. If the forwarders should live upstream, pin `rtl8733bu` at `2b72111f68d4cfafa27f189761448c61a8b325c8`, keep 001–006, and replace `007` with the three 7.2 hunks. Correct the `wdev_to_ndev()` comment in `rtl8733bu.mk`. Rebuild only that module and check vermagic before any image that is meant to boot it.
2. Leave the `strncpy` macro until a separate patch replaces the counted sites with `memcpy` and the 16-byte algorithm name with `strscpy_pad`. Do not do that by global substitution.
3. Leave libmali and mali-kbase on the current pair. A g24p0 userspace experiment needs its own kbase evidence and a Flip GLES run. It is not a cleanup of the current pin.
4. Rebuild the product image from a clean tree when the OTA name and the `VERSION` file need to name the commit under test. The kernel and module sources of the existing image already match these commits, apart from the DMC comment.

## 11. Hardware candidate

No source correction came out of this audit that the existing 7.2.10 image needs before a first boot. The image is still a dirty-tree tar: its name and its `VERSION` file say `0a96c787607b-dirty`, not `8b066182f6131ed91231953630cedf6f16d9ddd3`. Use it as the host-built 7.2.10 candidate, and record that name. Rebuild from a clean HEAD before treating a tar as the artifact of the final commit.

Still untested on this image: boot, display, audio, both SD slots, the pad, Wi-Fi, Bluetooth, Mali, DMC, charging, deep suspend, the upper USB host, and lower-port MTP. Wi-Fi association after either RTL arrangement is in that list. The upstream author's 7.1 association note does not cover it.
