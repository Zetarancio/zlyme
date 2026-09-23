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

The lists above are the Phase 2A preliminary reading. The Phase 2B classification later in this file is the disposition plan. No patch was removed in 2B.

## Unknowns

These bullets are the Phase 2A record. Phase 2B, below, answers the SYS_CAN_SD comparison, the 1992 MHz policy, the OTP consumer question from source, the GPU power-domain patch, and the sleep-ownership split. The remaining open items are collected under "Still uncertain" in that section.

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

## Phase 2B classification

2B assigns a class and a disposition. It does not edit patches. `REPLACE` was not used. Later phases stay deferred.

Class letters:

- A: required specifically for the Miyoo Flip
- B: reusable RK3566/RK3568 or RK817 platform fix still required on Linux 7.0.2
- C: upstream-style backport still required on Linux 7.0.2
- D: irrelevant inherited device or subsystem patch
- E: historical, diagnostic, or build-policy patch
- F: later architectural extraction

An optional Zlyme policy is labeled in the reason. The letter does not mean the feature is mandatory for ordinary 1.8 GHz operation.

### SYS_CAN_SD

Zlyme `0007` clears `RK817_SYS_CAN_SD` on every probe with `regmap_write_bits(..., RK817_SYS_CAN_SD, 0)` inside `rk817_battery_init`, next to the existing charge-termination update.

Chris Morgan `5c74541b46510f2e5ca58a0a86a3678691f0c291`, carried by ROCKNIX as `mainline-rockchip/007-power-supply-rk817-clear-sys-can-sd-register-by-default.patch` from commit `39b77d22afafa808f8489366deb55f006940ec2b`, clears the same bit with `regmap_clear_bits` only when `rockchip,gate-function-disable` is absent. The companion binding is `985642a0046d45d8d7bb49b3970c1a60f9bf9d98`. `Reported-by` on both external patches is Zetarancio. Zlyme's own writeup is dated 2026-04-05 and includes the Flip measurement: register `0xe6` reads `0xc5` after a real power-on reset, and clearing bit 7 drops off-state drain from about 8 mA to about 0.05 mA.

`rk3566-miyoo-flip.dts` does not set `rockchip,gate-function-disable`. On this board the default result of both patches is the same clear. The external patch is the more upstream-shaped form (binding, `Fixes:` trailer, opt-out). Zlyme's patch is the smaller one, it matches the BSP unconditional clear, and nothing in Zlyme uses the opt-out.

Disposition: **A + KEEP**. Do not replace it in 2C. The drain fix stays.

### 1992 MHz OPP

`0001` adds `opp-1992000000` at 1.15 V with `turbo-mode` on `&cpu0_opp_table` in `rk3566.dtsi`. The Flip DTS includes that file and only adds `clock-latency-ns` on `opp-408000000`. It does not delete the 1992 MHz point.

Linux treats `turbo-mode` as a boost OPP. It is not a normal scaling frequency while cpufreq boost is off. `governor.sh` uses that contract:

- `profile_smart`, `profile_play`, and `profile_idle` call `set_boost 0` and cap the CPU at 1.8 GHz or lower
- `profile_overclock` calls `set_boost 1` and `set_cpu_minmax 408000 1992000`

The undervolt overlays `rk3566-undervolt-cpu-l1.dts`, `l2`, and `l3` each contain `opp-1992000000`, so those overlays expect the node to exist. `docs/research/performance.md` already treats 1992 MHz as an optional overclock above the 1.8 GHz baseline.

This is an intentional optional Zlyme performance policy. It is not required for ordinary 1.8 GHz operation. Class **B + KEEP** because the OPP has to stay on the selected kernel for the boost profile and the overlays. 2C does not remove it and does not turn boost on.

The Flip did not answer SSH (`root@192.168.0.108`, connection timed out), so `scaling_boost_frequencies` was not read from a running card. The source contract is enough. No overclock run was started.

### RK3568 OTP

`0022` adds `rockchip,rk3568-otp` read support. `0023` adds the node at `fe38c000` on `rk356x-base.dtsi`, which the Flip includes, with cells `cpu_code`, `otp_cpu_version`, `otp_id`, `cpu_leakage`, `log_leakage`, `npu_leakage`, and `gpu_leakage`. `CONFIG_NVMEM=y`, `CONFIG_NVMEM_SYSFS=y`, and `CONFIG_NVMEM_ROCKCHIP_OTP=y`.

No Zlyme DTS, overlay, or package references those labels or an `nvmem-cells` phandle. The Flip CPU OPP table, including the 1992 MHz point, uses fixed microvolts. Nothing in-tree selects an OPP, a regulator, or a thermal zone from these cells. If the provider probes, sysfs can expose the cells because `CONFIG_NVMEM_SYSFS=y`. That is diagnostic exposure, not binning.

Linux 7.0.2 `drivers/nvmem/rockchip-otp.c` has no `rk3568` support. Current mainline `rk356x-base.dtsi` has the same cell map, but the binding shape differs: mainline uses `nvmem-layout`, clock names `otp`, `apb_pclk`, `phy`, `sbpi`, and four resets. Zlyme's patch uses clock names `usr`, `sbpi`, `apb`, `phy` and one reset, `otp_phy`. Current mainline `rk3566.dtsi` also has no consumer of the leakage cells. The 7.0.2 patches are not a drop-in of that newer node.

The Flip did not answer SSH, so `/sys/bus/nvmem/devices/` and the probe line were not observed. From the tree, the provider is unconsumed. It is not "unused" as a guess from a filename. It is unconsumed because no node or subsystem takes a cell from it.

Disposition: **B + DEFER**. Do not remove it in 2C. A boot log can later show whether probe succeeds. Phase owner remains Phase 2, not Phase 7.

### GPU power management

ROCKNIX `7153ebf9a43b630c9c169b24936eb6956f890446` contains two different changes.

The pmdomain patch drops `GENPD_FLAG_PM_CLK` on `RK3568_PD_GPU` when the power controller is `rockchip,rk3568-power-controller`. That is the Flip's power controller. The flag is a property of the domain, so every device on that domain is affected, including Panfrost. The commit text motivates the change with `mali_kbase` also preparing `SCMI_CLK_GPU` and `CLK_GPU`. Importing it is not a Mali-only fix.

The companion `patches/mali-bifrost/003-fix-unbalanced-regulator.patch` enables regulators at probe and disables them on teardown. That file is Mali-only. Zlyme's `mali-kbase` package pins `39da994bb6fc8819e5e8c1873907dd21d17e53c1` and applies only `002-lowercase-interrupts-first.patch`. That pin contains the "Regulators probed" site and does not contain the "Enable regulators during probe" balance. `enable_gpu_power_control` is not in that file.

`docs/LOGBOOK.md` has no `Enabling unprepared clk_gpu` or `failed to set domain 'gpu'` record. Importing the domain-flag change would alter clock tracking on the already-working standard suspend path for both GPU stacks.

Disposition for both external changes: **DEFER**. Do not import them in 2C. Zlyme's existing Mali DT patch `0008` stays **B + KEEP**. It is not a substitute for this pmdomain change, and this pmdomain change is not a substitute for it.

### Sleep findings, re-owned

RK817 gauge correction across sleep, ROCKNIX patch `005` by Jacob Cook, hooks system suspend and resume in `rk817_charger.c`. That is ordinary system sleep, not BL31 deep suspend. Zlyme builds that driver. The measurements in the patch are from an RG353M, not from the Flip. Adopting it does not start deep-suspend work. Owner: **Phase 2**, disposition **DEFER**. It is not one of the 45 patches, and 2C does not add it.

`platforms/RK3566/modules.keep` in the wifi-sleep merge contains `rtw88_8821cs`. The Flip radio is RTL8733BU. That line is ROCKNIX userspace policy for a different module. Zlyme has no matching sleep script. Owner: **ignore**. It is not Phase 6.

`1010` still belongs to Phase 6 as a disposition. Its callbacks are system PM ops and the current standard-suspend image already includes them, so 2C does not delete them either. The failure described is DDRMON state lost when the center domain gates in deep suspend, which Phase 6 owns. Class **B + DEFER**, owner Phase 6.

### All 45 patches

Paths are under `board/my355/linux/patches/`. Validation is what 2C must do if it follows the disposition. KEEP and DEFER rows are not 2C edits.

| # | Patch | Class | Disposition | Owner | Reason | Validation if 2C touches it |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `10-mainline/linux/0002-input-add-input-polldev-driver.patch` | A | KEEP | Phase 3 | File is absent from Linux 7.0.2. Current `rocknix-joypad` `3bc3ef644` and newer `d02ed13` both include `input-polldev.h`. The newer pin only adds `MODULE_IMPORT_NS("IIO_CONSUMER")`. | Do not remove in 2C. Phase 3 rebuilds the module. |
| 2 | `10-mainline/linux/0003-pwm-add-pwm_set_period.patch` | D | REMOVE | Phase 2 | Inline is unused on my355. Neither joypad pin calls it. The only ROCKNIX caller found is an RK3326 input patch. | Rebuild the kernel and `rocknix-joypad`. |
| 3 | `10-mainline/linux/0004-input-adc-keys-redirect-keycode-316-to-rocknix-joypa.patch` | A | KEEP | Phase 3 | Flip DTS has no `adc-keys` node, but the patch defines `joypad_input_g`, and `rocknix-singleadc-joypad.c` references it. Removing it breaks the current module link. | Do not remove in 2C. |
| 4 | `10-mainline/linux/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | A | KEEP | Phase 2 | `8733BU` is absent from Linux 7.0.2. Flip DTS uses `rockchip,rtl8733bu-power`. `CONFIG_BT_RTL=m`. | Not a 2C removal. |
| 5 | `20-rk3566/linux/0001-arm64-dts-rockchip-rk356x-add-1992mhz-cpu-opp-with-t.patch` | B | KEEP | Phase 2 | Optional boost OPP. See the 1992 section. Not required for the 1.8 GHz profiles. | Not a 2C removal. |
| 6 | `20-rk3566/linux/0002-power-supply-rk817-update-battery-and-charger-name-s.patch` | A | KEEP | Phase 2 | Renames the supplies to `battery` and `charger`. NextUI reads `/sys/class/power_supply/battery/capacity`. | Not a 2C removal. |
| 7 | `20-rk3566/linux/0003-drm-panel-st7703-Fix-Panel-Initialization-for-Anbern.patch` | D | REMOVE | Phase 2 | st7703 init for RG353V-V2. Flip panel is `rocknix,generic-dsi`, copied by `board.mk`, not this driver. | Kernel build. Display smoke after the panel-driver group. |
| 8 | `20-rk3566/linux/0004-arm64-dts-rockchip-fix-wifi-sdio-errors.patch` | D | REMOVE | Phase 2 | Only `rk3566-anbernic-rgxx3.dtsi` and `rk3566-powkiddy-x55.dts`. | Kernel dtbs build. Flip DTB unchanged. |
| 9 | `20-rk3566/linux/0005-arm64-dts-rockchip-fixup-anbernic-controls.patch` | D | REMOVE | Phase 2 | Anbernic DTS only. | Same as the foreign-DTS group. |
| 10 | `20-rk3566/linux/0006-drm-panel-nv3051d-fix-panel-timings-and-display-mode.patch` | D | REMOVE | Phase 2 | RK2023 panel timings. Flip does not bind `nv3051d`. The driver is built (`CONFIG_DRM_PANEL_NEWVISION_NV3051D=y`) and still has no Flip node. | Kernel build. Display smoke with the panel-driver group. |
| 11 | `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | A | KEEP | Phase 2 | Unconditional off-state drain fix. Equivalent on the Flip to the newer opt-out patch, which Zlyme does not need. | Not a 2C edit. |
| 12 | `20-rk3566/linux/0008-arm64-dts-rockchip-add-support-for-mali-bifrost-driv.patch` | B | KEEP | Phase 2 | Adds reset and Mali power-model properties on `&gpu` in `rk356x-base.dtsi`. The Flip enables that node for Panfrost or `mali_kbase`. Unknown properties are ignored by Panfrost; the reset is already in the running DT. | Not a 2C edit. |
| 13 | `20-rk3566/linux/0009-arm64-dts-rockchip-fix-shoulders-triggers-on-powkidd.patch` | D | REMOVE | Phase 2 | Powkiddy RGB10 Max 3 DTS only. | Foreign-DTS group. |
| 14 | `20-rk3566/linux/0010-drm-panel-st7703-request-higher-pixelclock-for-RGB30.patch` | D | REMOVE | Phase 2 | RGB30 pixel clock in st7703. Flip does not bind that panel. | Panel-driver group. |
| 15 | `20-rk3566/linux/0012-arm64-dts-rockchip-update-powkiddy-x55-dts-to-suppor.patch` | D | REMOVE | Phase 2 | Powkiddy X55 DTS only. | Foreign-DTS group. |
| 16 | `20-rk3566/linux/0013-Bluetooth-Check-key-sizes-only-when-Secure-Simple-Pa.patch` | C | KEEP | Phase 2 | Marcel Holtmann, patch id `cce32250027ffa6e2fed8e99734f90cd04f6b86a` (2019). It still changes `hci_conn_check_link_mode` so legacy BR/EDR without SSP skips the encryption check. The 2A search for the uppercase string `SSP` did not describe this hunk. `CONFIG_BT` is built. Not required for the Flip's own pad. | Not a 2C removal. |
| 17 | `20-rk3566/linux/0014-drm-panel-st7701-fixup-Anbernic-RG-Arc-panel-timings.patch` | D | REMOVE | Phase 2 | RG-Arc timings. `CONFIG_DRM_PANEL_SITRONIX_ST7701=y`, no Flip node. | Panel-driver group. |
| 18 | `20-rk3566/linux/0015-arm64-dts-rockchip-use-linear-backlight-levels-to-im.patch` | D | REMOVE | Phase 2 | Backlight levels on RG-Arc, RG353, and X55 DTS. Flip backlight is its own `pwm-backlight` node. | Foreign-DTS group. |
| 19 | `20-rk3566/linux/0016-arm64-dts-rockchip-add-device-tree-for-powkiddy-x35s.patch` | D | REMOVE | Phase 2 | Adds a Powkiddy DTS. | Foreign-DTS group. |
| 20 | `20-rk3566/linux/0018-arm64-dts-rockchip-add-device-tree-for-powkiddy-rgb2.patch` | D | REMOVE | Phase 2 | Adds a Powkiddy DTS. | Foreign-DTS group. |
| 21 | `20-rk3566/linux/0019-arm64-dts-rockchip-add-system-power-controller-attri.patch` | D | REMOVE | Phase 2 | `system-power-controller` on RGxx3 only. | Foreign-DTS group. |
| 22 | `20-rk3566/linux/0021-arm64-dts-rockchip-fix-missing-dma-names.patch` | B | KEEP | Phase 2 | Adds `dma-names = "tx", "rx"` on `uart1` in `rk356x-base.dtsi`. The Flip uses UART1 for the joypad. This is not the RGxx3-only UART patch. | Not a 2C removal. Phase 3 must keep a working UART. |
| 23 | `20-rk3566/linux/0022-nvmem-rockchip-otp-Add-support-for-rk3568-otp.patch` | B | DEFER | Phase 2 | Driver half of the unconsumed OTP provider. See the OTP section. | Do not remove in 2C. |
| 24 | `20-rk3566/linux/0023-arm64-dts-rockchip-rk3568-Add-otp-device-node.patch` | B | DEFER | Phase 2 | Shared-dtsi node. Same conclusion as `0022`. Mainline's later node is not the same binding. | Do not remove in 2C. |
| 25 | `20-rk3566/linux/0024-sdmmc1-card-detect-delay.patch` | D | REMOVE | Phase 2 | Card-detect delay on RGxx3 only. Flip sdmmc1 power is in the Flip DTS. | Foreign-DTS group. |
| 26 | `20-rk3566/linux/0025-arc-swap-touch-axes.patch` | D | REMOVE | Phase 2 | RG-Arc-D touch axes only. | Foreign-DTS group. |
| 27 | `20-rk3566/linux/0026-ASoC-codecs-Add-aw87391-amplifier-driver.patch` | D | REMOVE | Phase 2 | New codec. Flip audio is `simple-audio-amplifier`. `CONFIG_SND_SOC_AW87391=y` exists because this patch adds the option. 2C drops that config line with the patch. | Kernel build plus headphone/speaker smoke. |
| 28 | `20-rk3566/linux/0030-mfd-rk8xx-log-on-off-source-for-RK817-RK809.patch` | E | KEEP | Phase 2 | `dev_info` of ON/OFF source at RK817 probe. No control change. Useful for power-cycle diagnosis. | Not a 2C removal. |
| 29 | `20-rk3566/linux/0666-cma-region.patch` | B | KEEP | Phase 2 | 256 MiB default CMA on `rk356x-base.dtsi`, so it is the Flip's CMA policy. Removing it changes allocation. | Not a 2C removal. |
| 30 | `20-rk3566/linux/1001-arm64-dts-rockchip-Add-idle-states-for-rk356x.patch` | B | KEEP | Phase 2 | `cpu-idle-states` on the four CPUs in the shared dtsi. `CONFIG_ARM_PSCI_CPUIDLE=y`. The 0.2 W note in the patch was measured on an RG353P, and the nodes are still on the Flip. | Not a 2C removal. |
| 31 | `20-rk3566/linux/1002-arm64-dts-rockchip-Add-spk_amp-regulator-for-Anberni.patch` | D | REMOVE | Phase 2 | Anbernic speaker regulator DTS only. | Foreign-DTS group. |
| 32 | `20-rk3566/linux/1004-arm64-dts-rockchip-Add-avdd_0v9-and-avdd_1v8-for-RGx.patch` | D | REMOVE | Phase 2 | RGxx3 HDMI regulators. Flip HDMI supplies are in the Flip DTS. | Foreign-DTS group. |
| 33 | `20-rk3566/linux/1006-arm64-dts-rockchip-Correct-boot-enabled-regulators-f.patch` | D | REMOVE | Phase 2 | RGxx3 boot regulators only. | Foreign-DTS group. |
| 34 | `20-rk3566/linux/1008-arm64-dts-rockchip-Enable-DMA-for-uart1-on-RGxx3.patch` | D | REMOVE | Phase 2 | UART1 DMA on RGxx3 only. The Flip's UART1 `dma-names` come from `0021`, which stays. | Foreign-DTS group. Joypad smoke still belongs to that group's device check. |
| 35 | `20-rk3566/linux/1009-arm64-dts-rockchip-Map-wifi-host-wake-interrupt-for-.patch` | D | REMOVE | Phase 2 | RGxx3 wifi host-wake only. | Foreign-DTS group. |
| 36 | `20-rk3566/linux/1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch` | B | DEFER | Phase 6 | In-tree DFI system-sleep callbacks. The stated hardware loss is deep suspend. Current standard suspend already includes the patch, so 2C leaves it in place. | Phase 6. Not a 2C edit. |
| 37 | `20-rk3566/linux/1011-input-touchscreen-goodix-usability-fixes.patch` | D | REMOVE | Phase 2 | Skips Goodix firmware load from disk. `CONFIG_TOUCHSCREEN_GOODIX=y`, and the Flip DTS has no Goodix node, so the probe path does not run. | Kernel build. No touch device on the Flip. |
| 38 | `20-rk3566/linux/1012a-dt-bindings-memory-controllers-rockchip-rk3568-dmc.patch` | F | DEFER | Phase 7 | Binding for the Flip `rockchip,rk3568-dmc` node. Extraction is Phase 7. | Not a 2C edit. |
| 39 | `20-rk3566/linux/1012b-devfreq-rockchip-add-rk3568-dmc-devfreq-driver.patch` | F | DEFER | Phase 7 | Driver behind `CONFIG_ARM_RK3568_DMC_DEVFREQ=y`. `governor.sh` writes the DMC devfreq. | Not a 2C edit. |
| 40 | `20-rk3566/linux/1013-drm-rockchip-vop2-bcsh-tv-properties.patch` | A | KEEP | Phase 2 | NextUI `msettings.c` sets DRM TV properties `brightness`, `contrast`, `saturation`, and `hue` on the Flip's VOP2 path. | Not a 2C edit. |
| 41 | `30-default/linux/9901-pm-disable-async-suspend-resume-by-default.patch` | B | KEEP | Phase 2 | Sets `pm_async_enabled` to 0. The validated standard suspend path includes this. It is global PM policy from 2014, and it is not a deep-suspend feature. | Not a 2C removal. |
| 42 | `40-kernel-7.0/linux/0006-hid-playstation-expose-DualSense-Edge-Fn-and-back-paddles.patch` | C | KEEP | Phase 2 | `CONFIG_HID_PLAYSTATION=y`. Extra buttons are gated on Edge pid `0x0df2`. A plain DualSense is unchanged. Optional external controller, not the built-in pad. | Not a 2C removal. |
| 43 | `40-kernel-7.0/linux/0010-msm-resource-cleanup.patch` | D | REMOVE | Phase 2 | Seven MSM DPU hunks. `CONFIG_ARCH_QCOM` is not set, so this display controller is not built. The patch still has to apply to the 7.0.2 sources today. | Kernel build. No Qualcomm device on the Flip. |
| 44 | `40-kernel-7.0/linux/9998-silence-initramfs-unpack-warn.patch` | E | DEFER | Phase 2 | Downgrades an initramfs unpack failure from `KERN_EMERG` to `KERN_DEBUG`. `CONFIG_BLK_DEV_INITRD=y`. No boot log was captured this round, so it is not yet shown to be a harmless expected message. | Do not change in 2C until one boot log is read. |
| 45 | `40-kernel-7.0/linux/9999-fix-rust-build-error.patch` | E | REMOVE | Phase 2 | Rewrites perf's Rust target triples to `*-rocknix-linux-gnu`. Zlyme does not select `BR2_PACKAGE_LINUX_TOOLS_PERF`. The triple is the wrong one if perf Rust is ever built here. | Kernel build. No runtime change. |

Counts: A 6, B 9, C 2, D 23, E 3, F 2. KEEP 15, REPLACE 0, REMOVE 24, DEFER 6.

### Still uncertain

- OTP probe success and the sysfs directory were not read. SSH to the Flip timed out. The unconsumed conclusion is from the tree, not from a live device.
- `scaling_boost_frequencies` was not read on a running card. Boost behavior is taken from `turbo-mode` plus `governor.sh`.
- `9998` may be hiding a real initramfs error or an expected empty-archive message. Left DEFER.
- `0013` was not matched to a later mainline commit that might have replaced the 2019 hunk with different key-size policy. It stays because the carried hunk is still a delta.
- The GPU domain warning was not searched in a live `dmesg`. The logbook has no record of it.

### Proposed Phase 2C sequence

2C is not started here. Each group is one conceptual commit. Do not combine a foreign-file deletion with an RK817, GPU, OPP, OTP, DFI, or DMC change.

#### Group 1 — foreign board DTS only

Patches: `0004`, `0005`, `0009`, `0012`, `0015`, `0016`, `0018`, `0019`, `0024`, `0025`, `1002`, `1004`, `1006`, `1008`, `1009` under `20-rk3566/linux/`.

Reason: each file edits only Anbernic or Powkiddy DTS. None edits `rk356x-base.dtsi`, `rk3566.dtsi`, or `rk3566-miyoo-flip.dts`.

Expected runtime impact: none on the Flip.

Build validation: kernel build, Flip DTB still produced.

Device validation: boot to NextUI, display, built-in pad, audio, internal storage. `1008` is the RGxx3 UART file; the Flip UART DMA names stay via `0021`, so the pad check is the rollback signal.

Rollback boundary: this commit alone.

#### Group 2 — uninstantiated foreign drivers and the wrong-SoC display patch

Patches: st7703 `0003` and `0010`, nv3051d `0006`, st7701 `0014`, aw87391 `0026`, Goodix `1011`, `pwm_set_period` `0003`, MSM DPU `0010`.

Reason: the panel, codec, and touch drivers are enabled in `linux.config` and are not bound by the Flip DTS. `pwm_set_period` has no my355 caller. MSM DPU is not compiled because `CONFIG_ARCH_QCOM` is not set.

Expected runtime impact: none if the Flip panel remains `rocknix,generic-dsi` and audio remains `simple-audio-amplifier`.

Build validation: remove the patch and, in the same commit, drop the config symbols that exist only because the patch added them (`CONFIG_SND_SOC_AW87391`, and the panel/Goodix symbols if they stop existing). Rebuild the kernel and `rocknix-joypad`.

Device validation: NextUI frame, DSI panel, backlight, speaker and headphones, built-in pad.

Rollback boundary: this commit alone, separate from Group 1.

#### Group 3 — inherited perf Rust triple

Patch: `40-kernel-7.0/linux/9999-fix-rust-build-error.patch`.

Reason: ROCKNIX perf triple, not used by the Zlyme kernel build.

Expected runtime impact: none.

Build validation: kernel build.

Device validation: not required for this file. A boot smoke is enough if it is stacked on a Group 2 image.

Rollback boundary: this commit alone.

`9998` is not in this group.

#### Group 4 — accepted baseline, no patch edit

Leave in place: `0001` (optional 1992 boost), `0002` battery names, `0005` RTL8733BU, `0007` SYS_CAN_SD, `0008` Mali DT, `0013` Bluetooth key-size, `0021` UART1 dma-names, `0030` ON/OFF log, `0666` CMA, `1001` idle-states, `1013` VOP2 BCSH, `9901` async suspend off, DualSense Edge `0006`, and the Phase 3 inputs `0002` input-polldev and `0004` adc-keys export.

No runtime change, because there is no edit. No device test is required for this group itself.

#### Group 5 — replacements

None. Do not replace `0007`. Do not import the RK817 fuel-gauge series, the GPU pmdomain flag change, or the Mali regulator balance.

#### Held out of 2C

- OTP `0022` and `0023`: DEFER until a probe log exists.
- `9998`: DEFER until a boot log shows the initramfs line.
- `1010`: Phase 6.
- `1012a` and `1012b`: Phase 7.
- Joypad pin `d02ed13`: Phase 3. The current support patches stay.

### Appendix: not in the 45

`linux.config` says the `1013a/b` rk3568-suspend patches are `.testing-disabled`. Those files are not in `board/my355/linux/patches/`. The Flip DTS deep-suspend node is commented out. Status: disabled, not applied, owner Phase 6. Do not reactivate them in Phase 2.

## Phase 2C Group 1 execution

Group 1 passed the Miyoo Flip smoke. Group 2 has not started. The 45-row classification above stays the Phase 2B input. This section records what was removed from that inventory.

Fifteen foreign-board DTS patches were removed. Each diff touched only Anbernic or Powkiddy `.dts`/`.dtsi` files. None modified `rk356x-base.dtsi`, `rk3566.dtsi`, `rk3566-miyoo-flip.dts`, C source, Kconfig, or a Makefile. Remaining patch files were not renumbered or edited. `board/my355/linux/dts-overrides/` was left as it was.

Active Linux patches: 45 before, 30 after, counted from `10-mainline`, `20-rk3566`, `30-default`, and `40-kernel-7.0`.

The applied tree `output/build/linux-7.0.2` was removed with `./build.sh --config zlyme_my355_defconfig linux-dirclean`. The product build extracted pristine Linux 7.0.2 again (`linux-7.0.2.tar.xz` sha256 `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662`) and applied 30 patches. The deleted filenames were not in that patch phase.

`zlyme_my355_defconfig` built successfully and produced `Image.gz`, `rk3566-miyoo-flip.dtb`, and `output/images/zlyme-my355-20260923-68f6ca0dea6d-dirty.tar` (sha256 `629b3fe6962c6535e2b4fa3d367f5bad0f13c1d533cd7f91369656b2eedfb54c`). The `-dirty` suffix is because that tar was packed before this commit. `zlyme_my355_minimal_defconfig` configured successfully afterward, and the output tree was returned to `zlyme_my355_defconfig`.

Flip DTB before, saved at `/tmp/rk3566-miyoo-flip.dtb.group1-before` from both `output/images` and the previous kernel build tree: `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`. The rebuilt `output/images/rk3566-miyoo-flip.dtb` and the new kernel-tree DTB have the same hash. `cmp` reports them byte-identical.

This kernel build warned twice, both in the still-present adc-keys patch: missing prototypes for `rk_send_key_f_key_up` and `rk_send_key_f_key_down`. Those warnings were not introduced by deleting the foreign DTS files. They stay with the current joypad and input patches. They were not fixed here.

The validated card booted Linux 7.0.2 built 2026-09-23 01:18:48 UTC. `dmesg` had no err, crit, alert, or emerg lines. NextUI reached the first frame, the built-in controls worked, audio worked, `/storage` was mounted, and standard suspend/resume returned. A mali regulator warning and RTL8733BU C2H messages were also in that log. They are outside this DTS deletion and were not changed.

## Phase 2C Group 2A execution

Removed two patches that are not on the my355 runtime path. Group 2B has not started. The Phase 2B classification table is unchanged.

`10-mainline/linux/0003-pwm-add-pwm_set_period.patch` only added `pwm_set_period()` to `include/linux/pwm.h`. The Zlyme tree, the patched Linux 7.0.2 sources, and `rocknix-joypad` `3bc3ef644` (`rocknix-joypad.c`, `rocknix-joypad.h`, `rocknix-singleadc-joypad.c`) have no caller. After the clean rebuild the symbol is absent from `include/linux/pwm.h`.

`40-kernel-7.0/linux/0010-msm-resource-cleanup.patch` has nine hunks, all under `drivers/gpu/drm/msm/disp/dpu1/`. The generated kernel config still has `# CONFIG_ARCH_QCOM is not set` and `CONFIG_ARCH_ROCKCHIP=y`. No `dpu_*.o` objects were built. Qualcomm was not enabled to test this.

Active Linux patches: 30 before, 28 after. `linux-dirclean` removed the applied tree. The product build extracted pristine 7.0.2 and applied 28 patches. Neither deleted filename was in that patch phase. `zlyme_my355_defconfig` built successfully. `zlyme_my355_minimal_defconfig` configured, and the output tree was returned to the product defconfig.

The product build did not rebuild `rocknix-joypad`, because that package was already installed and does not call the removed helper. An explicit `rocknix-joypad-rebuild` afterward compiled `rocknix-singleadc-joypad.ko` against this kernel with no warning. That module rebuild is not inside the tar below.

Flip DTB stayed `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`, byte-identical to the Group 1 DTB. OTA: `output/images/zlyme-my355-20260923-c66fb88b954f-dirty.tar`, sha256 `ffdb36a316a231e313a5003613e345f3327340131da60ea78e465c6161617199`. The `-dirty` suffix is this deletion, packed before the commit.

The kernel build again warned about missing prototypes for `rk_send_key_f_key_up` and `rk_send_key_f_key_down` in the remaining adc-keys patch. Those warnings are unchanged and were not fixed. No my355 runtime path changed, so this subgroup did not get a separate Flip test.
