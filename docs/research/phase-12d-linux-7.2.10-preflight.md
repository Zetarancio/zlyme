# Linux 7.2.10 preflight

Read-only review on 2026-10-13. The defconfig pin stays 7.0.2. `linux.hash` was not edited. No image was built. The temporary tree was `/tmp/zlyme-kpreflight` and is not part of the repository.

Later the same day the pin moved. `docs/research/phase-12d-linux-7.2.10-migration.md` is that host build. This file stays the preflight. Two corrections belong here so the original text is not read as the final decision:

- Section 3 and the decision said the migration should set `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=0`. That was not done. Linux 7.0.2 already uses 10 when `CONFIG_MODULES=y`. Linux 7.2.10's Kconfig default for that case is 10. The migration keeps 10.
- The DualSense Edge patch was removed, and the Bluetooth USB-id hunk was rebased. The other fourteen patches were kept.

This review does not claim that an upgrade repairs MTP. `docs/research/phase-12d-usb-mtp.md` is that failure. Section 7 separates the maintenance reason from the USB reason.

## 1. Release check

[kernel.org](https://www.kernel.org/) on 2026-10-13 listed mainline 7.3-rc7 and stable 7.2.10. The newest line on the page was 7.2.10. The RC was not selected.

Official `sha256sums.asc` from `https://cdn.kernel.org/pub/linux/kernel/v7.x/sha256sums.asc`:

| Tarball | SHA-256 |
| --- | --- |
| `linux-7.0.2.tar.xz` | `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662` |
| `linux-7.2.10.tar.xz` | `2feaa70453e91f541be6a5c9078d8168e081af45a3d9718054850538cff2ebf3` |

The local Buildroot download `dl/linux/linux-7.0.2.tar.xz` matches the first hash, and `board/my355/linux/patches/10-mainline/linux/linux.hash` records that same hash. The 7.2.10 tarball was downloaded from `cdn.kernel.org` and matches the second hash. Both defconfigs set `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="7.0.2"`. Buildroot has no separate hash for a custom version, so `linux.hash` is the check.

Patches apply from `BR2_GLOBAL_PATCH_DIR` in this order: `10-mainline`, `20-rk3566`, `30-default`, `40-kernel-7.0`. Buildroot uses `patch -F0`. This review used `patch -p1 -F0 --forward`. A clean apply means the context still matches. It does not mean the change is still the right one. A failed apply does not mean upstream took the patch.

Sixteen `.patch` files are active. The Phase 2 and Phase 5 research files describe older inventories. This table is the tree on `132b7e04fa6eb08f93ba6938f3b320a7556c2e9b`.

## 2. Patch matrix

Mechanical result is against pristine 7.2.10. Sequential apply on the disposable tree matched the independent dry-run: the Bluetooth and DualSense patches failed, and the other fourteen applied.

| File | Purpose | Provenance | Hardware | 7.0.2 | 7.2.10 mechanical | Semantic | Risk | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `10-mainline/linux/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | RTL8733BU firmware id and USB id `0bda:b733` | spycat88, 2025-01-01 | Onboard Bluetooth | Applied | `btrtl.c` hunks apply. `btusb.c` hunk fails: the id table context moved. `0xb733` is not in 7.2.10 `btusb.c` | Still needed. Not upstream | Bluetooth | Rebase the USB-id hunk. Keep the firmware table |
| `20-rk3566/linux/0001-arm64-dts-rockchip-rk356x-add-1992mhz-cpu-opp-with-t.patch` | 1992 MHz CPU OPP | sydarn | CPU clock | Applied | Clean | Still a local OPP | CPU / thermal | Keep |
| `20-rk3566/linux/0002-power-supply-rk817-update-battery-and-charger-name-s.patch` | Battery and charger supply names | ab0tj | Userspace supply names | Applied | Clean | Still needed for the names Zlyme reads | Battery UI | Keep |
| `20-rk3566/linux/0003-power-supply-rk817-charger-Fix-NVRAM-SoC-Value.patch` | RK817 NVRAM state of charge | Chris Morgan. ROCKNIX `001`, carried locally | Gauge after power-off | Applied | Clean | Still needed. Not the unapplied sleep-gauge patch | Gauge | Keep |
| `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | Clear `SYS_CAN_SD` so the PMIC does not sit at the ~8 mA path | Zetarancio | Off current | Applied | Clean | Still needed | Charging / off current | Keep. Revalidate off current on hardware after a migration |
| `20-rk3566/linux/0008-arm64-dts-rockchip-add-support-for-mali-bifrost-driv.patch` | Mali Bifrost compatible for the out-of-tree kbase | Danil Zagoskin | GPU | Applied | Clean | Still needed while kbase is the DRM/GPU driver in the product image | GPU | Keep |
| `20-rk3566/linux/0021-arm64-dts-rockchip-fix-missing-dma-names.patch` | DMA names on RK356x | spycat88 | DMA clients | Applied | Clean | Still a local DTS fix | Audio / DMA | Keep |
| `20-rk3566/linux/0030-mfd-rk8xx-log-on-off-source-for-RK817-RK809.patch` | Log `ON_SOURCE` / `OFF_SOURCE` at probe | Zetarancio | Power-on diagnosis | Applied | Clean | Diagnostic. Still useful | None at runtime beyond a log line | Keep |
| `20-rk3566/linux/0666-cma-region.patch` | 256 MiB default CMA in `rk356x-base.dtsi` | No `From` header in the file | Display and GPU allocations | Applied | Clean | Still the reserved size | Memory / display | Keep. Do not resize in the migration |
| `20-rk3566/linux/1001-arm64-dts-rockchip-Add-idle-states-for-rk356x.patch` | CPU idle states | Chris Morgan | Idle power | Applied | Clean | Still a local DTS addition | Suspend / idle | Keep |
| `20-rk3566/linux/1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch` | DFI suspend and resume for deep suspend | Zetarancio | DDR frequency across suspend | Applied | Clean | Still required by the Phase 6 suspend path | Deep suspend | Keep |
| `20-rk3566/linux/1011a-dt-bindings-soc-rockchip-add-rk3568-pm-config.patch` | Binding for the RK3568 PM config node | Zetarancio | BL31 suspend programming | Applied | Clean | Still the binding for 1011b | Deep suspend | Keep, with 1011b |
| `20-rk3566/linux/1011b-soc-rockchip-add-rk3568-pm-config.patch` | Program RK3568 BL31 suspend mode. Uses `builtin_platform_driver`, not the vendor late initcall | Zetarancio | `vdd_logic` off suspend | Applied | Clean | Still required. A missing SMCCC conduit fails probe before a call | Deep suspend / resume | Keep. Hardware suspend is a migration check |
| `20-rk3566/linux/1013-drm-rockchip-vop2-bcsh-tv-properties.patch` | VOP2 brightness, contrast, saturation, hue as DRM TV properties | Zetarancio | Panel picture controls | Applied | Clean | Still a local DRM addition | Display | Keep |
| `30-default/linux/9901-pm-disable-async-suspend-resume-by-default.patch` | Async suspend/resume off unless selected | Stefan Saraev | Suspend ordering | Applied | Clean | Policy. Still wanted | Suspend | Keep |
| `40-kernel-7.0/linux/0006-hid-playstation-expose-DualSense-Edge-Fn-and-back-paddles.patch` | Edge Fn and back paddles as `BTN_TRIGGER_HAPPY1`–`4`, bits 4–7 | Anze, 2026-07-07 | DualSense Edge only | Applied on 7.0.2 | Hunks at the old define and report sites fail. Hunk 2 can still apply and would duplicate a capability | 7.2.10 already reports those bits as `DS_EDGE_BUTTONS_FN1`, `FN2`, `LEFT_PADDLE`, `RIGHT_PADDLE` when `ds->is_edge` is set. Same bits, same keys | Extra gamepad buttons | Remove. Do not rebase it onto code that already has the buttons |

No patch in this set touches DWC3 or the USB2 PHY. The USB failure is not carried by a local kernel patch.

## 3. Kconfig

`make ARCH=arm64 CROSS_COMPILE=aarch64-buildroot-linux-gnu- olddefconfig` was run in the disposable 7.2.10 tree after the patches that apply had been applied. The input was `output/build/linux-7.0.2/.config`. The cross compiler was Buildroot GCC 15.3.0. A first run with the host GCC 16 was discarded because it rewrote compiler-capability symbols.

USB, PHY, extcon, gadget, configfs FunctionFS, MMC, Panfrost, Rockchip DRM, Bluetooth, suspend, and dual-role DWC3 stayed at the same enabled or disabled state. `CONFIG_USB_DWC3_DUAL_ROLE`, `CONFIG_PHY_ROCKCHIP_INNO_USB2`, `CONFIG_USB_CONFIGFS_F_FS`, and `CONFIG_EXTCON` stayed `y`. `CONFIG_TYPEC` stayed off. `CONFIG_USB_FUNCTIONFS` stayed off because configfs provides the function. Mali and the other out-of-tree drivers are not in-tree symbols.

Meaningful drift that is not a renamed compiler flag:

- `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT` appears and olddefconfig sets it to 10. 7.0.2 did not have the symbol. The migration should set it back to 0 unless a later check shows the timeout is harmless. A 10 second give-up can drop a slow device.
- Crypto symbols moved. `CONFIG_CRYPTO_CAMELLIA`, `CONFIG_CRYPTO_KRB5`, and `CONFIG_CRYPTO_KRB5ENC` went from `n` to `y`. Several 7.0.2 crypto options disappeared (`CONFIG_CRYPTO_DRBG_HMAC`, `CONFIG_CRYPTO_GHASH`, `CONFIG_CRYPTO_RNG_DEFAULT`). This is a subsystem rename and select change, not a Flip feature.
- `CONFIG_PPPOX` became `m`. `CONFIG_NET_VENDOR_ALIBABA` became `y`. `CONFIG_SCHED_CACHE` became `y`. `CONFIG_MDIO_BUS` disappeared as a symbol. New Arm errata defaults turned on (`CONFIG_ARM64_ERRATUM_3821522`, `4118414`, `4193714`, and two workarounds).
- `CONFIG_READ_ONLY_THP_FOR_FS` and `CONFIG_NF_CT_PROTO_UDPLITE` disappeared.

The migration should record this diff and pin the deferred-probe timeout. It should not silently accept every new `y`.

Image size, initramfs size, and update-tar size were not measured. No kernel was compiled. U-Boot, rkbin, and the image layout were not changed. The boot chain still expects an arm64 `Image` and `rk3566-miyoo-flip.dtb`. Nothing in this review shows that 7.2.10 breaks that contract. Nothing here proves the image still fits.

## 4. Out-of-tree modules

Not compiled in this review. `modules_prepare` was not run.

| Package | Finding | Migration |
| --- | --- | --- |
| `package/drivers/mali-kbase` | Pin `39da994bb6fc8819e5e8c1873907dd21d17e53c1`. The makefile says the pin must match kernel 7.0.2. `kbase_fence_out_signal()` uses the `KERNEL_VERSION(7, 0, 0)` branch, and 7.2.10 `dma_fence_signal()` is `void`, which that branch calls. That one call is compatible. The rest of the driver was not built. | Compile it in the migration. Do not move the pin unless the build fails. A failure stops that task. |
| `package/drivers/rk3568-dmc` | Uses `devm_devfreq_add_device`, `devfreq_recommended_opp`, and OPP helpers that still exist in 7.2.10. SIP DRAM ids that 7.0.2 already provided stay in `rockchip_sip.h` (`ROCKCHIP_SIP_DRAM_FREQ` is `0x82000008`). The six RK3568 subcommands remain local to the module. | Expected to compile. Still compile it. Deep suspend stays a hardware check. |
| `package/drivers/miyoo-flip-gamepad` | GPIO, input, and IRQ only. No version guard. | Expected to compile. Hardware check is the pad, not the compile. |
| `package/drivers/rtl8733bu-power` | GPIO and rfkill. No version guard. | Expected to compile. |
| `package/drivers/rtl8733bu` | Vendor driver plus six local patches in the package, not in the kernel patch directory. No `LINUX_VERSION` hit in the unpacked tree. The kernel Bluetooth id is the separate `0005` rebase. | Compile in the migration. Wi-Fi and Bluetooth stay hardware checks. Firmware packaging is unchanged by this review. |

Panfrost stays `=m` in the config. It is in-tree. It was not built.

## 5. Hardware regression matrix

Source risk only. A later image has to be exercised on a Flip. Compile and `olddefconfig` do not prove that.

| Subsystem | Source note | Later hardware check |
| --- | --- | --- |
| Boot and initramfs | No change to U-Boot, BL31, or the image layout in this review. Kernel image was not built. | Cold boot to the menu. |
| Panel, DRM, HDMI | VOP2 patch still applies. Panfrost stays modular. | Picture, HDMI if used. |
| Mali and PanVK | kbase must be rebuilt. PanVK userspace is unchanged. | GLES. PanVK stays a separate pass. |
| ALSA / RK817 | DMA-name patch still applies. No audio Kconfig flip. | Sound and headphone detect. |
| Wi-Fi and Bluetooth | RTL8733BU module not compiled. Bluetooth USB id needs a rebase. | Associate, and a Bluetooth device. |
| Gamepad | Small driver, likely unchanged. | Sticks, buttons, rumble. |
| Both SD slots | DTS electrical config is not part of this migration. Shared `vccio_sd` is unchanged. | Both cards, including a hot insert. |
| Upper USB host and USB Wi-Fi | No PHY patch. | A device on the upper port. |
| Lower gadget and charge detect | DWC3 pull-up behavior is unchanged. See section 7. | Enumeration is 12D, not a reason to expect this kernel to enumerate. Charging still on RK817. |
| Gauge and off current | `SYS_CAN_SD` patch still applies. | Off current after the migration image. |
| Governors | DMC module must be rebuilt. CPU OPP patch still applies. | Smart profile still takes effect. |
| Deep suspend | DFI and RK3568 PM patches still apply. Async suspend stays off. | Power button suspend and wake. |
| Storage and MTP jail | Userspace is not in this migration. | Only after enumeration, the ext4 share. |
| OTA / boot FAT | Layout not changed. | Not part of the first boot of a migration image. Do not install over the only card without a recovery path. |

## 6. DTS and pinctrl

No DTS edit. The lower node stays `dr_mode = "otg"`, extcon `usb2phy0`, PHY `usb2phy0_otg`, no VBUS supply.

### Peripheral-only, not done

Setting the lower controller to `peripheral` would change the DWC3 role from OTG to device. Device-role runtime resume calls `dwc3_gadget_resume()`. OTG autosuspend resume does not. That is a real state-machine difference. It does not by itself change PHY power: `of_usb_get_dr_mode_by_phy()` would then report peripheral, and the inno-usb2 driver still runs the OTG state machine for peripheral. The July 2026 RFC's power-off skip is a separate change and keys off that peripheral mode. Without it, the PHY can still power off.

Charging stays on RK817. The PHY charger detect still runs for a peripheral port. No current userspace path uses the lower port as a host. The wiki notes that ID grounding can select host and that nothing on this board raises VBUS for that mode. Recovery and MASKROM do not use this Linux `dr_mode`. The DWC3 driver already implements peripheral mode, so the DTS change does not need a new driver to be parsed. It is still a separate experiment from the kernel bump, and it is not authorized here.

### Pin bias

The pinctrl driver programs the bias from the `&pcfg_pull_*` phandle. These groups set `pinctrl-0` only. There is no sleep state on them. The pull is the undriven pad. A GPIO requested as an output overrides it while driven.

Stock source read only, not modified: `Extra/rockchip/rk3566-miyoo-355-v10-linux.dts` (the same file is also under `miyoo355_sdk_release/dts/`). It includes `rk3566.dtsi` and `rk3568-linux.dtsi`. The board groups use the named configs `&pcfg_pull_down` and `&pcfg_pull_none`. Those are the same labels Zlyme uses. The `0x100` and `0x109` figures in the Zlyme comments are phandles from a compiled blob, not a second electrical setting. `0x100` matches stock `&pcfg_pull_none` on the USB 5 V enable. `0x109` matches stock `&pcfg_pull_down` on both SD enables, which is the bias Zlyme already has.

| Pin | GPIO | Consumer | Polarity | Active DTS | Stock, as the board comment states | Undriven result | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gamepad buttons | GPIO3 A1, A3–A6, B1–B6, C0–C3 | `miyoo-flip-gamepad` | Active low | `pcfg_pull_up` | Comment says BSP pull | High, released | Matches an active-low button. No change. |
| L3 / R3 | GPIO2 PC1, GPIO2 PC0 | Same driver | Active high | `pcfg_pull_down` | Comment says BSP | Low, released | Matches active-high. No change. |
| Volume | GPIO3 A7, GPIO3 B0 | `gpio-keys` | Active low | `pcfg_pull_up` | Not re-decoded | High, released | No change. |
| Speaker enable | GPIO4 PC2 | `simple-audio-amplifier` | Active high | `pcfg_pull_down` | Comment: datasheet `_d` | Low, amp off | Matches "off when not driven". No change. |
| Headphone detect | GPIO4 PC6 | Card `hp-det` | Active low | `pcfg_pull_up` | `&pcfg_pull_down`. The stock `hp-det-gpio` property is commented out; the pinctrl group is still pull-down | High, released | Zlyme's pull-up is the idle level for an active-low jack. Stock's pull-down would look inserted while the pin is not driven. Leave Zlyme's pull-up. Do not copy the stock pull in the kernel migration. |
| Hall / lid | GPIO0 PC6 | `gpio-keys` wake | Active low | `pcfg_pull_up` | Not re-decoded | High | Wake polarity is already "open only". No change. |
| Wi-Fi enable | GPIO0 PA0 | `rtl8733bu-power` | Active low | `pcfg_pull_up` | Not re-decoded | High, radio off | Matches the comment. No change. |
| PMIC IRQ | GPIO0 PA3 | RK817 | Open drain, active low | `pcfg_pull_up` | Usual for an IRQ | High | No change. |
| USB 5 V enable | GPIO4 PC5 | `vcc5v0_host` | Active high | `pcfg_pull_down` | `&pcfg_pull_none` (`vcc5v0_host_en`) | Low, 5 V off | Zlyme holds the rail off while the pin is not driven. Stock does not pull it. Do not change this in the kernel migration. A later experiment can try pull-none only with the 5 V rail measured. |
| SD slot 0 enable | GPIO0 PA5 | `vcc_sd` | Active low | `pcfg_pull_down` | `&pcfg_pull_down` (`vcc_sd_h`). Same bias as Zlyme | Low, which is enabled | Stock and Zlyme agree. The Zlyme comment that this replaced stock `0x109` with pull-down is the phandle of that same pull-down, not a different bias. Pull-down on an active-low enable still asserts power while the pin is not driven. The regulator drives the pin after probe. Do not change it in the kernel migration, and do not treat a pull-up experiment as restoring stock. |
| SD slot 1 enable | GPIO2 PB1 | Second slot | Active low | `pcfg_pull_down` | `&pcfg_pull_down` (`vcc_sd2_h`). Same bias as Zlyme | Low, enabled | Same as slot 0. |
| Wi-Fi PHY supply | `usb2phy1_host` | RTL8733BU | Supply, not a bias | `vcc_3v3` | Comment: stock 5 V, the 5 V line is commented out | 3.3 V rail | Experimental, already marked in the DTS. Not part of the kernel bump. Do not flip it while enumerating MTP. |
| Lower OTG PHY | `usb2phy0_otg` | Gadget | No supply | No `phy-supply` | Stock also has no supply on this port | PHY power follows the state machine | Do not add a regulator to copy another board. |

Unused-pin hogs are a separate group and were not compared pin by pin with stock. They stay as they are. The eMMC hog stays out of the pinctrl set while SFC is enabled, which the DTS already explains.

## 7. USB and the upgrade

Linux 7.2.10 does not contain a fix for the Flip's failure.

- `dwc3_gadget_pullup()` still returns on `pm_runtime_get_sync()` result 0 or negative, and still treats 0 as "resume already started the controller".
- `__dwc3_gadget_start()` is still ignored in `dwc3_gadget_soft_connect()`.
- OTG autosuspend resume still does nothing.
- `phy-rockchip-inno-usb2.c` still calls `rockchip_usb2phy_power_off()` from the OTG state machine with no peripheral-mode exception. The ODROID RFC is not present.
- `dwc3-rockchip.c` is not present. The v16 glue series is not this kernel.
- A new mutex serializes soft-connect against error recovery. That is not the missing EP0 retry.

The upgrade is still a reasonable maintenance candidate: 7.0.2 to the current stable, fourteen patches apply, two have a known disposition, and the config drift is listable. It is not an MTP repair. A hardware boot of that kernel is justified as a new baseline. It is not justified as an expected enumeration fix.

## 8. Decision

GO for an isolated migration task. No safety blocker in this review requires a different kernel. The migration itself must:

- pin 7.2.10 in both defconfigs and record the hash above
- rebase the Bluetooth USB id and delete the DualSense patch
- set `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=0` unless the maintainer accepts 10
- review the crypto and `PPPOX` drift before leaving it
- compile mali, DMC, the gamepad, and both RTL modules
- leave the board DTS, `dr_mode`, and the MTP helper unchanged
- build and run host checks
- stop before installing

If mali or DMC fails to compile, that task stops. It does not switch to 7.3-rc7.
