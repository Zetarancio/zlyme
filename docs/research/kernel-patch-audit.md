# Kernel patch audit — Phase 2A

Research only. This note pins the evidence used to look at Zlyme's current my355 Linux patches. It does not classify those patches A–F, and it does not remove, replace, or import any patch.

Normative architecture stays in `docs/ARCHITECTURE.md` and `docs/UPSTREAMS.md`. ROCKNIX is comparison evidence.

## Baselines

| Source | Revision |
| --- | --- |
| Zlyme repository | `Zetarancio/zlyme` |
| Phase 2 branch | `phase-2-kernel-audit` |
| Phase 2 base (`main` after Phase 1) | `56cc4c38c5189b96e724c9227d69e6b92203339d` |
| Phase 2 branch after the roadmap commit | `7d844a3674890f81e8a1415c9fe783ea6e7d6598` |
| Selected Linux | `7.0.2`, tarball `dl/linux/linux-7.0.2.tar.xz` |
| Official ROCKNIX | `ROCKNIX/distribution`, branch `next`, commit `3993c6bb666022c3f10b7adbc27862103dfa959f` (2026-09-22, `wifictl: fix changing wifi networks, when already connected`) |
| Hardware wiki | `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` `b08e335d31fca41383e01176390914c3d4550ec5` (2026-09-21, `docs: align boot-chain evidence wording`) |
| Archived historical fork | `Zetarancio/distribution` `flip` `d249b09bd95120c65555b0c56bc381f72ce073bc` (2026-09-02, merge of `1ebff24f36`) |

`configs/zlyme_my355_defconfig` and `configs/zlyme_my355_minimal_defconfig` both set `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="7.0.2"`.

Linux patches are applied from `BR2_GLOBAL_PATCH_DIR` in this order, each from that directory's `linux/` subdirectory, filename sort:

1. `board/my355/linux/patches/10-mainline`
2. `board/my355/linux/patches/20-rk3566`
3. `board/my355/linux/patches/30-default`
4. `board/my355/linux/patches/40-kernel-7.0`

The same `BR2_GLOBAL_PATCH_DIR` also lists `board/my355/uboot/patches`. Those are U-Boot patches and are outside this Linux inventory.

Kernel config inputs are `board/my355/linux/linux.config` and `board/my355/linux/my355.fragment`. The Flip board DTS is `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`. It includes `rk3566.dtsi`, so a patch to `rk3566.dtsi` or `rk356x-base.dtsi` is on the Flip's tree. A patch that only edits an Anbernic or Powkiddy DTS is not.

`CONFIG_ARM_RK3568_DMC_DEVFREQ=y` is set. The Flip DTS contains a `rockchip,rk3568-dmc` node. The in-tree deep-suspend include is commented out, and `linux.config` records that the `1013a/b` rk3568-suspend patches are `.testing-disabled`.

Upstream checks below used the pristine `linux-7.0.2.tar.xz`, not `output/build/linux-7.0.2`, because the build tree already has Zlyme's patches applied. Presence of a symbol there is not evidence it is upstream. 2A did not test-apply every patch against the tarball.

## Previous comparison boundary

There is no Zlyme commit that records an exact official ROCKNIX SHA as the last kernel-patch diff. `docs/archive/NOTES.md` is a superseded note, and it does record two official revisions that still resolve:

| What the note recorded | Resolved commit | Date |
| --- | --- | --- |
| Last official commit merged into the archived flip fork | `1ebff24f36501fb6493beb2bf83bf2604536d9aa` | 2026-09-01 |
| Official `next` HEAD observed while that note was written | `6ec91044aad12c18c189ef1c8e59709bbab54cc1` | 2026-09-16 |
| Wiki revision in that same note | `cf6500c53fb9` | 2026-09-03 |

Those SHAs were confirmed through the GitHub commit API. This shallow ROCKNIX checkout contains only `3993c6bb`, so this audit does not claim a reviewed `1ebff24f36..3993c6bb` range. Material changes were identified from current Zlyme patch content, the archived fork pin, and the current official tree at `3993c6bb`.

## Current Zlyme patch order

45 Linux patches. Paths are relative to `board/my355/linux/patches/`. Order is application order. "Flip DT" means the patch edits `rk3566.dtsi` or `rk356x-base.dtsi`, which `rk3566-miyoo-flip.dts` includes. Final A–F labels are intentionally absent.

| # | Path | Subject | Files | Provenance | Flip relevance, preliminary |
| --- | --- | --- | --- | --- | --- |
| 1 | `10-mainline/linux/0002-input-add-input-polldev-driver.patch` | input: add input-polldev driver | `drivers/input/Kconfig`, `Makefile`, `input-polldev.c`, `include/linux/input-polldev.h` | brooksytech | File is absent from Linux 7.0.2. Joypad support code. Phase 3 owns any driver rewrite. |
| 2 | `10-mainline/linux/0003-pwm-add-pwm_set_period.patch` | pwm: add pwm_set_period | `include/linux/pwm.h` | brooksytech | `pwm_set_period` is absent from Linux 7.0.2 `include/linux/pwm.h`. |
| 3 | `10-mainline/linux/0004-input-adc-keys-redirect-keycode-316-to-rocknix-joypa.patch` | adc-keys: redirect keycode 316 to rocknix-joypad | `drivers/input/keyboard/adc-keys.c` | spycat88 | Joypad wiring. Phase 3. |
| 4 | `10-mainline/linux/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | btrtl: RTL8733BU | `drivers/bluetooth/btrtl.c`, `btusb.c` | spycat88 | `8733BU` is absent from Linux 7.0.2 `btrtl.c`. Flip DTS uses `rockchip,rtl8733bu-power`. |
| 5 | `20-rk3566/linux/0001-arm64-dts-rockchip-rk356x-add-1992mhz-cpu-opp-with-t.patch` | rk356x: 1992 MHz CPU OPP with turbo-mode | `rk3566.dtsi` | sydarn | Flip DT. The board DTS sets clock-latency on `opp-408000000` and does not delete higher OPPs. Frequency policy. |
| 6 | `20-rk3566/linux/0002-power-supply-rk817-update-battery-and-charger-name-s.patch` | rk817: battery and charger names for EmulationStation | `rk817_charger.c` | ab0tj | Driver change on the PMIC the Flip uses. The stated consumer is EmulationStation. |
| 7 | `20-rk3566/linux/0003-drm-panel-st7703-Fix-Panel-Initialization-for-Anbern.patch` | st7703 init for Anbernic RG353V-V2 | `panel-sitronix-st7703.c` | Ao Zhong | Flip panel compatible is `rocknix,generic-dsi`, not this panel. |
| 8 | `20-rk3566/linux/0004-arm64-dts-rockchip-fix-wifi-sdio-errors.patch` | fix wifi SDIO errors | `rk3566-anbernic-rgxx3.dtsi`, `rk3566-powkiddy-x55.dts` | Sparticuz | Other boards' DTS only. |
| 9 | `20-rk3566/linux/0005-arm64-dts-rockchip-fixup-anbernic-controls.patch` | fixup Anbernic controls | Anbernic RG353/RG503/RG-Arc DTS | sydarn | Other boards' DTS only. |
| 10 | `20-rk3566/linux/0006-drm-panel-nv3051d-fix-panel-timings-and-display-mode.patch` | nv3051d timings for RK2023 | `panel-newvision-nv3051d.c` | sydarn | Powkiddy panel driver. Flip panel is generic-dsi. |
| 11 | `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | clear SYS_CAN_SD, ~8 mA off-state drain | `rk817_charger.c`, `include/linux/mfd/rk808.h` | Zetarancio, 2026-04-05 | `SYS_CAN_SD` is absent from Linux 7.0.2 `rk817_charger.c`. Documented Flip power invariant. |
| 12 | `20-rk3566/linux/0008-arm64-dts-rockchip-add-support-for-mali-bifrost-driv.patch` | Mali Bifrost properties on the GPU node | `rk356x-base.dtsi` | Danil Zagoskin, patch id `6dc776df6e601d83129c6519d1387f94d6996232` | Flip DT. Adds resets and Mali power-model nodes on `&gpu`, which the Flip enables. |
| 13 | `20-rk3566/linux/0009-arm64-dts-rockchip-fix-shoulders-triggers-on-powkidd.patch` | Powkiddy RGB10 Max 3 shoulders | `rk3566-powkiddy-rgb10max3.dts` | sydarn | Other board DTS only. |
| 14 | `20-rk3566/linux/0010-drm-panel-st7703-request-higher-pixelclock-for-RGB30.patch` | st7703 pixel clock for RGB30 | `panel-sitronix-st7703.c` | sydarn | Other panel. |
| 15 | `20-rk3566/linux/0012-arm64-dts-rockchip-update-powkiddy-x55-dts-to-suppor.patch` | Powkiddy X55 joypad DTS | `rk3566-powkiddy-x55.dts` | Paul Reioux | Other board DTS. Joypad-related, still not the Flip DTS. |
| 16 | `20-rk3566/linux/0013-Bluetooth-Check-key-sizes-only-when-Secure-Simple-Pa.patch` | check key sizes only when SSP is enabled | `net/bluetooth/hci_conn.c` | Marcel Holtmann | Generic Bluetooth. Carried as a patch, so the hunk is not already the pristine file. Upstream commit not matched in 2A. |
| 17 | `20-rk3566/linux/0014-drm-panel-st7701-fixup-Anbernic-RG-Arc-panel-timings.patch` | st7701 RG-Arc timings | `panel-sitronix-st7701.c` | sydarn | Other panel. |
| 18 | `20-rk3566/linux/0015-arm64-dts-rockchip-use-linear-backlight-levels-to-im.patch` | linear backlight on Anbernic/Powkiddy DTS | RG-Arc, RG353x, X55 DTS | spycat88 | Other boards. Flip backlight is its own `pwm-backlight` node. |
| 19 | `20-rk3566/linux/0016-arm64-dts-rockchip-add-device-tree-for-powkiddy-x35s.patch` | Powkiddy X35S DTS | `rk3566-powkiddy-x35s.dts` | spycat88 | Other board. |
| 20 | `20-rk3566/linux/0018-arm64-dts-rockchip-add-device-tree-for-powkiddy-rgb2.patch` | Powkiddy RGB20 Pro DTS | `rk3566-powkiddy-rgb20-pro.dts` | spycat88 | Other board. |
| 21 | `20-rk3566/linux/0019-arm64-dts-rockchip-add-system-power-controller-attri.patch` | system-power-controller on RGxx3 | `rk3566-anbernic-rgxx3.dtsi` | sydarn | Other board DTS. |
| 22 | `20-rk3566/linux/0021-arm64-dts-rockchip-fix-missing-dma-names.patch` | missing dma-names | `rk356x-base.dtsi` | spycat88 | Flip DT. Shared SoC node, not an Anbernic-only file. |
| 23 | `20-rk3566/linux/0022-nvmem-rockchip-otp-Add-support-for-rk3568-otp.patch` | rk3568 OTP nvmem | `drivers/nvmem/rockchip-otp.c` | Finley Xiao | `rk3568` string absent from Linux 7.0.2 `rockchip-otp.c`. Driver code, not only a foreign DTS. |
| 24 | `20-rk3566/linux/0023-arm64-dts-rockchip-rk3568-Add-otp-device-node.patch` | OTP node | `rk356x-base.dtsi` | Finley Xiao | Flip DT, because the node is added to the shared dtsi. |
| 25 | `20-rk3566/linux/0024-sdmmc1-card-detect-delay.patch` | sdmmc1 card-detect delay | `rk3566-anbernic-rgxx3.dtsi` | no `From:` header | Other board DTS. Flip has its own sdmmc1 regulator comment. |
| 26 | `20-rk3566/linux/0025-arc-swap-touch-axes.patch` | swap RG-Arc touch axes | `rk3566-anbernic-rg-arc-d.dts` | no `From:` header | Other board. |
| 27 | `20-rk3566/linux/0026-ASoC-codecs-Add-aw87391-amplifier-driver.patch` | aw87391 amplifier driver | `sound/soc/codecs/aw87391.c` plus Kconfig/Makefile | Noxwell | New codec. Flip audio node is `simple-audio-amplifier`. |
| 28 | `20-rk3566/linux/0030-mfd-rk8xx-log-on-off-source-for-RK817-RK809.patch` | log RK817/RK809 ON/OFF source | `drivers/mfd/rk8xx-core.c` | Zetarancio | `RK8XX_OFF_SOURCE` string absent from Linux 7.0.2 `rk8xx-core.c`. Diagnostic. |
| 29 | `20-rk3566/linux/0666-cma-region.patch` | 256 MiB default CMA | `rk356x-base.dtsi` | no `From:` header | Flip DT. Adds `linux,cma` size `0x10000000`. |
| 30 | `20-rk3566/linux/1001-arm64-dts-rockchip-Add-idle-states-for-rk356x.patch` | idle-states for rk356x | `rk356x-base.dtsi` | Chris Morgan | Flip DT. |
| 31 | `20-rk3566/linux/1002-arm64-dts-rockchip-Add-spk_amp-regulator-for-Anberni.patch` | spk_amp regulator for RGxx3 | Anbernic DTS | Chris Morgan | Other boards. |
| 32 | `20-rk3566/linux/1004-arm64-dts-rockchip-Add-avdd_0v9-and-avdd_1v8-for-RGx.patch` | HDMI avdd for RGxx3 | `rk3566-anbernic-rgxx3.dtsi` | Chris Morgan | Other board. Flip HDMI supplies are on the Flip DTS itself. |
| 33 | `20-rk3566/linux/1006-arm64-dts-rockchip-Correct-boot-enabled-regulators-f.patch` | boot-enabled regulators for RGxx3 | `rk3566-anbernic-rgxx3.dtsi` | Chris Morgan | Other board. |
| 34 | `20-rk3566/linux/1008-arm64-dts-rockchip-Enable-DMA-for-uart1-on-RGxx3.patch` | UART1 DMA on RGxx3 | `rk3566-anbernic-rgxx3.dtsi` | Chris Morgan | Other board. Joypad UART on that board, not the Flip DTS. Phase 3 if revisited. |
| 35 | `20-rk3566/linux/1009-arm64-dts-rockchip-Map-wifi-host-wake-interrupt-for-.patch` | wifi host-wake on RGxx3 | `rk3566-anbernic-rgxx3.dtsi` | Chris Morgan | Other board. |
| 36 | `20-rk3566/linux/1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch` | rockchip-dfi PM suspend/resume for deep sleep | `drivers/devfreq/event/rockchip-dfi.c` | Zetarancio | `dev_pm_ops` is absent from Linux 7.0.2 `rockchip-dfi.c`. Deep suspend. Phase 6. |
| 37 | `20-rk3566/linux/1011-input-touchscreen-goodix-usability-fixes.patch` | goodix: skip firmware load from disk | `drivers/input/touchscreen/goodix.c` | no `From:` header; comment says it avoids a ~60 s timeout | Flip panel is DSI, not a Goodix node in the Flip DTS. |
| 38 | `20-rk3566/linux/1012a-dt-bindings-memory-controllers-rockchip-rk3568-dmc.patch` | rk3568-dmc binding | `Documentation/.../rockchip,rk3568-dmc.yaml` | Zetarancio | Binding for the DMC node in the Flip DTS. Phase 7 owns extraction. |
| 39 | `20-rk3566/linux/1012b-devfreq-rockchip-add-rk3568-dmc-devfreq-driver.patch` | RK3568 DMC devfreq driver | `drivers/devfreq/rk3568_dmc.c`, Kconfig, Makefile, `rockchip_sip.h` | Zetarancio | `rk3568_dmc.c` is absent from Linux 7.0.2. Phase 7. |
| 40 | `20-rk3566/linux/1013-drm-rockchip-vop2-bcsh-tv-properties.patch` | VOP2 BCSH via DRM TV properties | `drm_bridge_connector.c`, `rockchip_drm_drv.c`, `rockchip_drm_vop2.c` | Zetarancio | Flip display pipeline uses VOP2. Unified diff headers, so the file list is from the `+++` lines. |
| 41 | `30-default/linux/9901-pm-disable-async-suspend-resume-by-default.patch` | disable async suspend/resume by default | `kernel/power/main.c` | Stefan Saraev | Global PM policy. Affects the standard suspend path that already works. |
| 42 | `40-kernel-7.0/linux/0006-hid-playstation-expose-DualSense-Edge-Fn-and-back-paddles.patch` | DualSense Edge Fn and back paddles | `drivers/hid/hid-playstation.c` | Anze | External-controller HID, not the built-in pad. |
| 43 | `40-kernel-7.0/linux/0010-msm-resource-cleanup.patch` | MSM DPU resource cleanup, seven hunks | `drivers/gpu/drm/msm/disp/dpu1/*` | JS Deck | Qualcomm display controller. my355 is Rockchip VOP2. |
| 44 | `40-kernel-7.0/linux/9998-silence-initramfs-unpack-warn.patch` | initramfs unpack failure from `KERN_EMERG` to `KERN_DEBUG` | `init/initramfs.c` | no `From:` header | Build/boot log policy. |
| 45 | `40-kernel-7.0/linux/9999-fix-rust-build-error.patch` | perf Makefile rust build fix | `tools/perf/Makefile.config` | no `From:` header | Host/perf tooling. `linux.config` records rustc capability symbols; that does not by itself mean `CONFIG_RUST=y`. |

## Upstream-status findings

Checked in pristine Linux 7.0.2:

| Item | Result |
| --- | --- |
| `include/linux/pwm.h` contains `pwm_set_period` | no |
| `drivers/input/input-polldev.c` | file absent |
| `drivers/power/supply/rk817_charger.c` contains `SYS_CAN_SD` | no |
| `drivers/bluetooth/btrtl.c` contains `8733BU` | no |
| `drivers/devfreq/rk3568_dmc.c` | file absent |
| `drivers/devfreq/event/rockchip-dfi.c` contains `dev_pm_ops` | no |
| `drivers/mfd/rk8xx-core.c` contains `RK8XX_OFF_SOURCE` | no |
| `drivers/nvmem/rockchip-otp.c` contains `rk3568` | no |

No checked Zlyme patch is already contained in Linux 7.0.2. 2A did not find a current patch to delete because a newer mainline already has the same behavior.

Two carried patches look like backports whose upstream commit was not identified here: Marcel Holtmann's Bluetooth key-size check (`0013`) and the MSM DPU series (`0010`). They stay until 2B compares hunks. The MSM series is also the wrong display controller for this board.

On this ROCKNIX pin, handheld `RK3566` and `RK3576` use kernel.org Linux 7.0.2 (`projects/ROCKNIX/packages/linux/package.mk`). That is the same version Zlyme builds. Other ROCKNIX devices differ (`RK3326` is 7.1.2, `H700` is 7.2, `RK3588` is a vendor 6.1 tree, and `projects/Rockchip/devices/RK356X` is a separate chewitt 6.19 tree). The patch comparison in this note is the handheld RK3566 set, applied on 7.0.2, plus `mainline-rockchip` because that package file adds `mainline-rockchip` to `PKG_PATCH_DIRS` for every `RK*` device. A kernel bump is not a Phase 2 change.

## Relevant current ROCKNIX changes

Filtered from `next` at `3993c6bb`. H700, SM6115, SM8250, S922X, RK3576, EmulationStation, and emulator commits were not treated as my355 kernel candidates.

ROCKNIX's current RK3566 Linux patch directory still shares most of Zlyme's inherited `0001`–`0026` and `1001`–`1011` names. It does not contain Zlyme's `0007`, `0030`, `1010`, `1012a`, `1012b`, or `1013`. It adds `0027` (aw88166 firmware load) and replaces the `1012` number with a different GPU power-domain patch. The RK817 charger work moved to `projects/ROCKNIX/packages/linux/patches/mainline-rockchip/`.

### Candidate matrix

| Candidate | Source | Subsystem | Affected files | my355 relevance | Reason / evidence | Zlyme overlap | Selected-kernel status | Hardware-wiki evidence | Owner | Recommendation | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Clear RK817 `SYS_CAN_SD` by default | ROCKNIX `39b77d22afafa808f8489366deb55f006940ec2b` (Jacob Cook, 2026-09-17). Patch `mainline-rockchip/007-power-supply-rk817-clear-sys-can-sd-register-by-default.patch`. Patch author Chris Morgan, `From 5c74541b46510f2e5ca58a0a86a3678691f0c291`, 2026-04-22. `Reported-by: Zetarancio`. ROCKNIX imported it; it is not a ROCKNIX-original driver. | power supply | `rk817_charger.c`, `rk808.h` | yes | Same off-state drain bit Zlyme already clears. `diff -q` shows Zlyme `0007` and this file differ. Zlyme's writeup is dated 2026-04-05, before this patch. | `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | downstream-only on 7.0.2 | Zlyme architecture and operations already require this behavior. Wiki pin `b08e335` was not re-quoted line by line in 2A. | Phase 2 | compare; keep Zlyme's patch until the two hunks are shown to match | off-state current if a replacement is later adopted |
| RK817 `rockchip,gate-function-disable` binding | same ROCKNIX commit `39b77d22`, patch `006-dt-bindings-power-supply-rk817-charger-add-rockchip-gate-function-disable.patch`, author Chris Morgan | power supply DT | binding added by that commit | uncertain | Lets a board opt into the BSP-style gate disable. Zlyme clears the bit unconditionally. | none as a binding; overlaps the behavior of `0007` | downstream-only | not separately re-checked at `b08e335` | Phase 2 | compare; do not add the property in 2A | only if 2C replaces `0007` |
| RK817 NVRAM SoC fix | ROCKNIX `f03ec1352010cda78e0541429b3ef275b0f65977` (Jacob Cook, 2026-09-19) adds patch `001-power-supply-rk817-charger-Fix-NVRAM-SoC-Value.patch`, author Chris Morgan | fuel gauge | rk817 charger | yes, the Flip uses RK817 and a `simple-battery` node | Boot SoC value fix. Not a replacement for the drain bit. | none | downstream-only until 2B reads the hunk against 7.0.2 | not re-checked at this wiki pin | Phase 2 | compare; do not adopt in 2A | battery percentage across reboot, if later adopted |
| RK817 boot SoC from the coulomb counter | same import commit, patch `002-power-supply-rk817-battery-resolve-boot-soc-from-counter.patch`, author Chris Morgan | fuel gauge | rk817 battery | yes | Boot-time SoC source. | none | downstream-only | not re-checked at this wiki pin | Phase 2 | compare | same as the NVRAM row |
| RK817 gauge correction across sleep | same import commit, patch `005-power-supply-rk817-charger-correct-gauge-across-sleep.patch`, author Jacob Cook `<jacobmcook1984@gmail.com>` | fuel gauge / sleep | rk817 charger | uncertain | The subject includes sleep. Phase 2 can keep the evidence. Enabling or retuning sleep behavior belongs later. | none | downstream-only | not re-checked at this wiki pin | Phase 6 | defer | only under the Phase 6 suspend plan |
| Bound boot SoC with the OCV table | ROCKNIX `f79ac0182f367049802815680014f16fe8d322a8` (Jacob Cook, 2026-09-18), patch `008-power-supply-rk817-bound-the-boot-soc-with-the-ocv-table.patch`, author Jacob Cook | fuel gauge | rk817 charger | yes | Another boot-SoC correction, separate from drain. | none | downstream-only | not re-checked at this wiki pin | Phase 2 | compare | battery percentage at boot, if later adopted |
| Let `mali_kbase` own RK3568 GPU clocks | ROCKNIX `7153ebf9a43b630c9c169b24936eb6956f890446` (Jacob Cook, 2026-09-11, `RK3566: fix GPU clock ownership and regulator balance`). Patch `devices/RK3566/patches/linux/1012-pmdomain-rockchip-let-mali_kbase-own-the-rk3568-GPU-clocks.patch`, author Jacob Cook | GPU power domain | `pmdomain` rockchip code described in the patch: `rockchip_pd_attach_dev()` plus GPU clocks `SCMI_CLK_GPU` and `CLK_GPU` | yes for the libmali/`mali_kbase` stack; Panfrost does not use that driver | The patch explains genpd `pm_clk` and `mali_kbase` both tracking the same clocks across suspend/resume, including when the domain itself stays on. That is existing runtime PM, not a request to enable deep suspend. | none. Zlyme `0008` only adds Mali DT properties. Zlyme's `1012a/b` are the DMC driver and are unrelated. | downstream-only; not compared line by line with 7.0.2 pmdomain code | Flip DTS enables `&gpu` for Panfrost or kbase | Phase 2 | compare; do not apply in 2A | both GPU stacks, including ordinary suspend, if later adopted |
| Mali Bifrost unbalanced regulator | same ROCKNIX commit `7153ebf9`, file `devices/RK3566/patches/mali-bifrost/003-fix-unbalanced-regulator.patch` | out-of-tree Mali module | mali-bifrost module patch | yes for libmali only | Packaged with the clock-ownership fix. Zlyme's in-tree Mali package is separate (`package/drivers/mali-kbase`, pin `39da994bb6fc8819e5e8c1873907dd21d17e53c1`). | none in `board/my355/linux/patches` | downstream module patch; kernel 7.0.2 does not contain this driver | libmali is one of the two supported GPU stacks | Phase 2 | compare against Zlyme's mali-kbase package; do not import in 2A | libmali suspend/resume if later adopted |
| `rocknix-joypad` update | ROCKNIX `c0eb8dc928a71bb57db9656fbc70ab1d8a52581e` (Mike, 2026-09-16, `rocknix-joypad: update version, needed for linux 7.3`). Package pin `d02ed13aae08113f6f9e0e9d699cb29bb3450fa2` | input | `projects/ROCKNIX/packages/linux-drivers/rocknix-joypad/package.mk` | yes, Zlyme uses this driver | The commit message cites Linux 7.3. Handheld RK3566 in this same tree is still Linux 7.0.2. Zlyme pins `3bc3ef644`. Whether `d02ed13` is required on 7.0.2 was not proven. | `package/drivers/rocknix-joypad` | not a Linux 7.0.2 patch | built-in pad is in the Flip DTS as `rocknix-singleadc-joypad` | Phase 3 | defer the version bump and any UART/GPIO/rumble work | Phase 3 joypad gate |
| RK3566 wifi modules kept across sleep | ROCKNIX `9560c795ac490c11cbe5ea3dc11ee056fec8bb63` (merge of Jacob Cook, 2026-09-14) | suspend userspace | `platforms/RK3566/modules.keep`, `packages/sysutils/sleep/sources/sleep.sh` | uncertain | Sleep script policy, not a kernel patch. | none | n/a | standard suspend already works; deep suspend is Phase 6 | Phase 6 | defer | Phase 6 |

Reviewed and set aside for this phase:

- Other ROCKNIX kernel versions (7.1.2, 7.2, vendor 6.1, chewitt 6.19). Handheld RK3566 at this pin is 7.0.2, matching Zlyme. Not a Phase 2 kernel bump.
- `0027` aw88166 boot-time firmware load. The Flip codec in the DTS is `simple-audio-amplifier`.
- Anbernic RG DS Plus DTS (`675c364c6d6c`). Another board.
- H700 Panfrost, H700 suspend, and EmulationStation sleep commits in the same September window. Different SoC or userspace.
- `084b71874a9a` `libmali: force linear to allow direct scanout`. Userspace GPU packaging, not this kernel inventory.

Current ROCKNIX `next` has no `rk3568_dmc` hit under `projects/` or `packages/linux` in this checkout, and its RK3566 patch list has no DFI PM patch. That is evidence of what ROCKNIX currently carries. It is not a reason to delete Zlyme's DMC or DFI patches.

## Later-phase findings

### Phase 3

- `rocknix-joypad` pin `d02ed13` versus Zlyme `3bc3ef644`.
- Patches `0002` (input-polldev), `0004` (adc-keys keycode 316), and the RGxx3 UART1 DMA patch `1008`. The first two are still part of the running 7.0.2 baseline. Phase 2 may keep them so the current driver builds. Phase 3 owns the replacement driver.
- InputPlumber was not inspected and is not started.

### Phase 6

- Zlyme `1010` rockchip-dfi suspend/resume. Keep it in the tree through Phase 2. Do not enable deep suspend. The Flip DTS suspend include stays commented out.
- ROCKNIX rk817 gauge-across-sleep patch `005`.
- ROCKNIX RK3566 `modules.keep` / `sleep.sh` wifi change.
- `9901` disables async suspend globally. 2B has to decide whether that is baseline policy for the suspend that already works, or only deep-suspend scaffolding. 2A does not remove it.

### Phase 7

- Zlyme `1012a` and `1012b`, the rk3568-dmc binding and driver. The Flip DTS and `CONFIG_ARM_RK3568_DMC_DEVFREQ=y` use them. Current ROCKNIX `next` not carrying the driver does not move extraction into Phase 2.

## Potential Phase 2 decisions

These are candidates for 2B/2C. They are not decisions.

### KEEP until 2B says otherwise

Patches that modify the Flip's included SoC dtsi or a driver the Flip is known to use, and that are absent from Linux 7.0.2:

- `0005` RTL8733BU
- `0007` SYS_CAN_SD
- `0008` Mali properties on `&gpu`
- `0021` dma-names
- `0022` and `0023` OTP, pending a check that the shared dtsi node is actually wanted
- `0666` CMA
- `1001` idle-states
- `0001` 1992 MHz OPP, because removing it would change Flip CPU frequencies
- `1013` VOP2 BCSH, because the Flip display uses VOP2
- `1012a` / `1012b` held for Phase 7
- `1010` held for Phase 6
- `0002`, `0003`, and `0004` held so the current joypad still builds; rewrite is Phase 3

### REPLACE only after a semantic diff

- `0007` against ROCKNIX/Chris Morgan `007` plus binding `006`
- Mali DT `0008` is not replaced by the new pmdomain patch; that patch is an additional candidate

### REMOVE candidates, still not classified

Inherited files that do not touch the Flip DTS or the Flip panel compatible, if 2B confirms they do not alter a shared path the Flip uses:

- Anbernic/Powkiddy DTS and panel patches: `0003`, `0004`, `0005`, `0006`, `0009`, `0010`, `0012`, `0014`, `0015`, `0016`, `0018`, `0019`, `0024`, `0025`, `1002`, `1004`, `1006`, `1008`, `1009`
- `1011` Goodix firmware-load comment, if no Goodix device is on the Flip
- `0026` aw87391, if nothing in the Flip DTS or config selects it
- `0010` MSM DPU, Qualcomm display
- `9998` initramfs log downgrade, if it is only hiding a message

`0013` (Bluetooth SSP key size) and `0006` (DualSense Edge) need a hunk-level look before either keep or remove. `0030` is a Zlyme diagnostic on the RK817 MFD the board uses; treat it as debug-or-keep, not as a foreign-board drop.

## Unknowns

- No patch in this inventory was test-applied to a clean 7.0.2 tree during 2A. Symbol checks cover the rows in the upstream table only.
- Marcel Holtmann `0013` and the MSM series were not matched to an upstream commit id.
- `0023` adds an OTP node to `rk356x-base.dtsi`. Whether that node is harmless on RK3566 was not proven from the dtsi structure.
- Whether `0001`'s 1992 MHz OPP is inside the operating-point table the Flip actually selects was not dumped from a built DTB.
- Chris Morgan's `SYS_CAN_SD` patch and Zlyme's `0007` were shown to differ as files, not yet compared hunk by hunk.
- The new fuel-gauge patches were not compared with the Flip's `simple-battery` binding or with a captured SoC trace.
- The GPU clock-ownership patch's interaction with Panfrost, as opposed to `mali_kbase`, was not code-reviewed beyond the commit message.
- Wiki `b08e335` was pinned and its tip subject recorded. Individual wiki pages were not re-read for every candidate.
- `6ec91044aad1` and `1ebff24f36` were not used as a diff range.

## Out-of-scope findings

Recorded so they are not implemented here.

| Finding | Where it belongs |
| --- | --- |
| ROCKNIX `next` tip `3993c6bb` is a wifictl network-switch fix | ignore for the kernel audit |
| EmulationStation H700 sleep and armsx2 RK3566 enablement in the September history | future/backlog, not Phase 2 |
| `libmali` linear scanout force (`084b71874a9a`) | future/backlog; userspace GPU packaging |
| H700 Panfrost copy-image quirk | ignore |
| InputPlumber | Phase 4, not started |
