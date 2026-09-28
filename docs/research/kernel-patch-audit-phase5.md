# Kernel patch audit — Phase 5 research

Research only. This note does not add, delete, or replace a kernel patch. The Phase 2 record stays in `docs/research/kernel-patch-audit.md`. Current architecture stays in `docs/ARCHITECTURE.md`.

Date: 2026-09-28.

## Baselines

| Source | Revision |
| --- | --- |
| Zlyme `main` after the Phase 4 fast-forward | `04442328d42191a6d77eb0dcbabeb163f2244297` |
| Phase 5 branch created from that `main` | `phase-5-kernel-reduction` at the same SHA, before this note |
| Selected Linux | `7.0.2` (`BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` in `configs/zlyme_my355_defconfig`). Pristine checks used `dl/linux/linux-7.0.2.tar.xz` and `gregkh/linux` tag `v7.0.2`, not `output/build/linux-7.0.2`. |
| Official ROCKNIX `next` | `46eeb493a7532bec24b86dcd33bda3d87d463672` (2026-09-27, `Merge pull request #3390`, initramfs race). RK3566 in `projects/ROCKNIX/packages/linux/package.mk` is still `PKG_VERSION="7.0.2"`. |
| Archived fork | `Zetarancio/distribution` `flip` `d249b09bd95120c65555b0c56bc381f72ce073bc` (2026-09-02, merge of `1ebff24f36`) |
| Last official commit in that archived fork | `1ebff24f36501fb6493beb2bf83bf2604536d9aa` (2026-09-01) |
| Phase 2 ROCKNIX pin | `3993c6bb666022c3f10b7adbc27862103dfa959f` (2026-09-22) |
| Hardware wiki | `b08e335d31fca41383e01176390914c3d4550ec5` (2026-09-21) |
| Upstream Linux | `torvalds/linux` `72d3fcf802c45d00b300f25b848a93c3a2bd7c7e` (2026-09-27, `Linux 7.3-rc5`) |

GitHub compare:

| Range | Result |
| --- | --- |
| `1ebff24f36..46eeb493a753` | 241 commits, archived fork is not behind in the other direction |
| `3993c6bb66..46eeb493a753` | 19 commits |

The 19 commits after the Phase 2 pin are mostly other SoCs and frontends (H700, SM4450, SM6115, SM8750, RPCS3, rocknix-abl). The RK3566-relevant ones are `82dd3a665684` (STI8070A, other board) and `e74d9da67da4` / `46eeb493a753` (ROCKNIX initramfs/sysroot build race). Neither is a Zlyme kernel patch.

## Current Zlyme Linux patches

Eighteen patches, applied from `board/my355/linux/patches/` in directory order. The Phase 2 inventory had 45. The extras were other-board DTS and drivers removed in later cutovers. This list is the Phase 5 starting tree.

| Path | Subject | Provenance | Files | Flip use | 7.0.2 | Upstream `7.3-rc5` | Proposed disposition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `10-mainline/linux/0002-input-add-input-polldev-driver.patch` | restore `input-polldev` | brooksytech | `input-polldev.c`, Kconfig | No remaining caller. `gpio_keys_polled.c` in 7.0.2 does not include `input-polldev.h`. Flip volume and hall nodes are `gpio-keys`, not `gpio-keys-polled`. | Symbol absent until this patch. `linux.config` sets `CONFIG_INPUT_POLLDEV=y` and `CONFIG_KEYBOARD_GPIO_POLLED=y`. | Same absence of the old helper. | DROP candidate, together with `CONFIG_INPUT_POLLDEV` if nothing else selects it. Do not drop in the same commit as a gauge change. |
| `10-mainline/linux/0004-input-adc-keys-redirect-keycode-316-to-rocknix-joypa.patch` | export `joypad_input_g` from adc-keys | spycat88 | `adc-keys.c` | No `adc-keys` node on the Flip (`rk3566-miyoo-flip.dts` says saradc ch0 belongs to the joypad). No C consumer of `joypad_input_g` outside the patch. The old ROCKNIX joypad module is gone. | adc-keys exists; the export does not. | Not re-checked line by line; the symbol is a ROCKNIX joypad hook. | Strong DROP candidate. |
| `10-mainline/linux/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | RTL8733BU firmware table | spycat88, `656d871541b3` | `btrtl.c`, `btusb.c` | Flip DTS has `rockchip,rtl8733bu-power`. | `8733` is absent from pristine `btrtl.c`. | Still absent from `7.3-rc5` `btrtl.c`. | KEEP. Not upstream. |
| `20-rk3566/linux/0001-arm64-dts-rockchip-rk356x-add-1992mhz-cpu-opp-with-t.patch` | 1992 MHz OPP at 1.15 V, `turbo-mode` | sydarn | `rk3566.dtsi` | Flip includes that dtsi and does not delete the OPP. `zlyme-governor` `profile_overclock` sets `408000..1992000` when boost is on. Undervolt overlays `rk3566-undervolt-cpu-l1/l2/l3.dts` each contain `opp-1992000000`. | Not in the stock dtsi; this patch adds it. | Not treated as upstream. | KEEP. Optional boost, not the 1.8 GHz path. Removing it changes a live policy and the undervolt overlays. |
| `20-rk3566/linux/0002-power-supply-rk817-update-battery-and-charger-name-s.patch` | `rk817-battery` to `battery`, charger name to `charger` | ab0tj | `rk817_charger.c` | Live. Apostrophe reads `/sys/class/power_supply/battery/capacity`. `PLAT_getBatteryStatusFine` also reads that path and comments that the charger class may still be `rk817-charger`. | Stock names are the `rk817-*` strings. | Not re-checked; the rename is a Zlyme userspace ABI. | KEEP. A rename back would be a separate userspace migration, not a patch deletion. |
| `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | clear `SYS_CAN_SD` | Zetarancio, 2026-04-05 | `rk817_charger.c`, `rk808.h` | Flip hardware. Wiki and `docs/OPERATIONS.md` / `ARCHITECTURE.md` require it. True POR leaves register `0xe6` at `0xc5` (bit set): about 8 mA off, about 0.05 mA with the bit clear. | `RK817_SYS_CAN_SD` is absent. | Still absent from `7.3-rc5`. | KEEP. See the comparison below. Do not stack ROCKNIX `007` on top. |
| `20-rk3566/linux/0008-arm64-dts-rockchip-add-support-for-mali-bifrost-driv.patch` | Mali resets and power model on `&gpu` | Danil Zagoskin | `rk356x-base.dtsi` | Flip enables `&gpu`. | Phase 2: not in 7.0.2. Not re-diffed this pass. | Unknown this pass. | KEEP until a hunk diff shows the dtsi already has it. Not the ROCKNIX pmdomain clock patch. |
| `20-rk3566/linux/0013-Bluetooth-Check-key-sizes-only-when-Secure-Simple-Pa.patch` | key-size check only when SSP is on | Marcel Holtmann, 2019, `cce32250027f` | `hci_conn.c` | Generic Bluetooth. Helps legacy devices. Not Flip-specific. | `hci_conn_check_link_mode` still uses `if (hci_conn_ssp_enabled(conn) && !encrypt) return 0`. | `7.3-rc5` still has that combined test, not the early `!ssp` return. | KEEP. Downstream relative to 7.0.2 and 7.3-rc5. |
| `20-rk3566/linux/0021-arm64-dts-rockchip-fix-missing-dma-names.patch` | `dma-names` on a shared SoC node | spycat88 | `rk356x-base.dtsi` | Flip includes that dtsi. | Phase 2: carried because the hunk was not already pristine. Not re-diffed this pass. | Unknown this pass. | KEEP until a pristine diff says the names exist. |
| `20-rk3566/linux/0030-mfd-rk8xx-log-on-off-source-for-RK817-RK809.patch` | `dev_info` of ON/OFF source | Zetarancio | `rk8xx-core.c` | No `docs/OPERATIONS.md` procedure reads this log. No userspace parser. | Phase 2: string absent from pristine `rk8xx-core.c`. | Not re-checked. | DROP candidate, or DEBUG if a power-cycle log is still wanted. Not a product behavior dependency. |
| `20-rk3566/linux/0666-cma-region.patch` | CMA region | historical | CMA | Flip display/GPU allocations. Phase 2 KEEP. | Not re-diffed. | Unknown. | KEEP. Do not resize memory in this phase. |
| `20-rk3566/linux/1001-arm64-dts-rockchip-Add-idle-states-for-rk356x.patch` | CPU idle states | historical | `rk356x` dts | Flip CPUs. Phase 2 KEEP. | Not re-diffed. | Unknown. | KEEP. Idle behavior is not a deletion target without a measurement. |
| `20-rk3566/linux/1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch` | DFI suspend/resume | historical | DFI driver | Used with the DMC node. | Not re-diffed. | Unknown. | Leave for Phase 6. Do not delete as "unused" from a Phase 5 cleanup. |
| `20-rk3566/linux/1012a-dt-bindings-memory-controllers-rockchip-rk3568-dmc.patch` | RK3568 DMC binding | historical | binding | Flip DTS has `rockchip,rk3568-dmc`. `CONFIG_ARM_RK3568_DMC_DEVFREQ=y`. | Not upstream in the Phase 2 check. | Not re-checked. | Leave for Phase 7. |
| `20-rk3566/linux/1012b-devfreq-rockchip-add-rk3568-dmc-devfreq-driver.patch` | RK3568 DMC driver | historical | devfreq driver | Same DMC node. | Same. | Same. | Leave for Phase 7. |
| `20-rk3566/linux/1013-drm-rockchip-vop2-bcsh-tv-properties.patch` | VOP2 BCSH | historical | vop2 | `zlyme-bcsh` and the panel path. Phase 2 KEEP. | Not re-diffed. | Unknown. | KEEP. Display color is not a drive-by deletion. |
| `30-default/linux/9901-pm-disable-async-suspend-resume-by-default.patch` | async suspend off by default | historical | PM core | Board suspend policy. Phase 6 owns suspend validation. | Not re-diffed. | Unknown. | KEEP through Phase 5. Phase 6 can revisit it. |
| `40-kernel-7.0/linux/0006-hid-playstation-expose-DualSense-Edge-Fn-and-back-paddles.patch` | Edge Fn and back paddles | Anze, 2026-07-07 | `hid-playstation.c` | External controller only. Product `0x0df2`. | `BTN_TRIGGER_HAPPY` / `0x0df2` paddle decode is absent. | Present in `7.3-rc5` (`BTN_TRIGGER_HAPPY1`–`4`, Edge comment). | KEEP on 7.0.2. Not `UPSTREAMED` for the selected kernel. A later kernel bump can drop it after a hunk match. |

`dts-overrides/rockchip/rk3568-anbernic-rg-ds.dts` still has an `adc-keys` node. That file is not the Flip DTS and is not a reason to keep `0004` on `my355`.

## SYS_CAN_SD

Zlyme `0007` always clears bit 7 of `RK817_PMIC_CHRG_TERM` (`0xe6`) from `rk817_battery_init` with `regmap_write_bits(..., RK817_SYS_CAN_SD, 0)`.

ROCKNIX `39b77d22afafa808f8489366deb55f006940ec2b` imports Chris Morgan's pair:

- `006` binding, patch id `985642a0046d`, property `rockchip,gate-function-disable`
- `007` driver, patch id `5c74541b46510f2e5ca58a0a86a3678691f0c291`, `Reported-by: Zetarancio`

`007` calls `regmap_clear_bits` on the same bit unless that property is set. The Flip charger node does not set `rockchip,gate-function-disable`, so the default result on this board matches Zlyme: the bit is cleared. `git apply --check` / `patch --dry-run -p1` of `007` against pristine 7.0.2 `rk817_charger.c` and `rk808.h` succeeded. It must not be applied on top of Zlyme `0007`; both add `RK817_SYS_CAN_SD` and both write the bit.

`7.0.2` and `7.3-rc5` have no `RK817_SYS_CAN_SD` in `rk817_charger.c`. The pair is posted-shaped downstream code, not merged upstream. Replacing one proven patch with a binding plus a driver patch does not shrink the Flip patch set. Recommendation: **KEEP Zlyme `0007`**. A REPLACE is only justified later if the pair is actually merged and a kernel bump picks it up.

## RK817 fuel gauge, absent from the archived fork

These landed in official ROCKNIX after `1ebff24f36`. They are separate patches.

### 001 — NVRAM SoC bound

ROCKNIX commit `f03ec1352010cda78e0541429b3ef275b0f65977`. Patch `001-power-supply-rk817-charger-Fix-NVRAM-SoC-Value.patch`. Upstream-style id `d6bc8b45fe18b1c8fdd7e4b8d5fa6f10d0eda4cd`, Chris Morgan, 2026-08-24.

`rk817_read_battery_nvram_values()` documents SoC as 0..100000 (0%..100%) but rejects values above `10000` (10%) and clamps them to `10000`. The patch changes that ceiling to `100000`. `7.0.2` line 741 and `7.3-rc5` line 741 are still `if (charger->soc > 10000)`. Dry-run of the patch on pristine 7.0.2 succeeded.

The Flip uses this driver and a 3 Ah `simple-battery` (`charge-full-design-microamp-hours = <3000000>`, OCV 3.2–4.25 V, 20 °C table from the 2025 firmware). A saved NVRAM SoC above 10% is therefore forced to 10% on every boot that takes that path, until a later full-charge or empty correction. That is a real correctness bug on this hardware, independent of the ~8 mA drain. It does not change the OCV table or the 3 Ah capacity.

Proposed disposition: **ADOPT CANDIDATE**, alone, with the validation plan below. Not implemented in this commit. Upstream status: posted downstream, not in 7.0.2 or 7.3-rc5.

### 002 — boot SoC from the coulomb counter

Same ROCKNIX import. Patch `002-power-supply-rk817-battery-resolve-boot-soc-from-counter.patch`, Chris Morgan, 2026-09-03.

It stops using `OFF_CNT >= 3` to reseed from `PWRON_VOL` after the first boot. It takes the coulomb counter when that counter is positive, keeps the saved SoC when the counter is zero or negative, and exposes `POWER_SUPPLY_PROP_VOLTAGE_BOOT` and `POWER_SUPPLY_PROP_VOLTAGE_OCV`. While resting, if the relax-voltage pair disagrees with the tracked SoC by more than 5%, it re-inits the counter from that pair.

This matches the wiki's separate bug: a large powered-off percentage drop that was gauge OCV reseeding, not the ~8 mA `SYS_CAN_SD` drain. The Flip assumptions that matter are the ones already in the DTS: 3 Ah design capacity, OCV table at 20 °C, `rockchip,sleep-enter-current-microamp = <150000>`, `rockchip,sleep-filter-current-microamp = <100000>`, sense resistor 10000 µΩ. The 5% relax threshold and the "counter keeps counting while off" claim come from RG353M / RG DS observations, not from a Flip trace.

Dry-run of `002` on pristine 7.0.2 succeeded, so it does not strictly need `001` to apply. Semantically it should still follow `001`, because a counter-derived SoC above 10% would otherwise be clamped by the old NVRAM bound on the next save/read. `VOLTAGE_BOOT` / `VOLTAGE_OCV` are absent from 7.0.2 and 7.3-rc5.

Proposed disposition: **ADOPT CANDIDATE only after 001**, and only as its own change with the validation plan. Do not import it because another handheld saw the bug. Upstream status: downstream only.

### 008 — bound boot SoC with the OCV table

ROCKNIX `f79ac0182f367049802815680014f16fe8d322a8`. Patch `008`, Jacob Cook. It edits the boot-counter path from `002`: under load the OCV table is a floor (keep saved SoC if the counter is more than 10 percentage points below the table); on charge the table is a ceiling. The ±10% figures are `10000` in the 0..100000 SoC scale.

Dry-run on pristine 7.0.2 failed both hunks. It depends on `002`'s boot log and counter assignment. The Flip OCV table is a firmware curve, not a measured rested pack on this unit, so it is not yet evidence that a 10% bound is right for a degraded or replacement cell.

Proposed disposition: **DEFER** until `001` and `002` have Flip measurements. Not an automatic third patch. Upstream status: downstream only.

### 005 — gauge across sleep

Patch `005`, Jacob Cook, in the same ROCKNIX series. Suspend stamps boot time, charge, current, and charging state. Resume rebuilds SoC from the counter, uses a relax pair latched during sleep, and otherwise credits `elapsed * current` if the counter fell short while charging.

Phase 2 left suspend gauge behavior to Phase 6. Dry-run on pristine 7.0.2 failed 2 of 6 hunks. It belongs after the boot-SoC series, and the roadmap owner is still Phase 6.

Proposed disposition: **DEFER TO PHASE 6**. Do not start deep-suspend work from this research.

### Fuel-gauge reset helper

ROCKNIX `8931cfab92801f58079faf23f0e3daf74f4398bf` is userspace. It sets `BAT_CON` and clears gauge NVRAM so the next power-on reinitializes the gauge, and it is wired into factory reset.

That is a destructive recovery tool, not a kernel patch. Ordinary factory reset should not wipe a working gauge. A narrow developer command could be useful while testing `001`/`002`, and it is not required if those patches migrate cleanly. YAGNI: **DO NOT ADOPT** into Zlyme factory reset.

## Other post-fork RK3566 items

| Candidate | Commit | Relevance | Disposition |
| --- | --- | --- | --- |
| GPU clock ownership | `7153ebf9a43b` kernel `1012-pmdomain-rockchip-let-mali_kbase-own-the-rk3568-GPU-clocks.patch` plus mali `003-fix-unbalanced-regulator.patch` | Drops `GENPD_FLAG_PM_CLK` on the GPU power domain so `mali_kbase` is the only clock owner across suspend. Zlyme also runs Panfrost on that domain. The hunk is conditional, but it still changes the domain Panfrost uses. No Zlyme suspend trace shows the bug. | **DEFER** to Phase 6. Do not apply for Panfrost in Phase 5. |
| AW88166 firmware without stalling boot | ROCKNIX `0027` | Flip audio is `simple-audio-amplifier`, not AW88166. | **DO NOT ADOPT** |
| STI8070A vdd_cpu | `82dd3a665684` | Flip CPU supply is `rockchip,rk8600` at `0x40` (`vdd_cpu_rk860`). | **DO NOT ADOPT** |
| Initramfs parallel-build race | `e74d9da67da4`, merge `46eeb493a753` | ROCKNIX package dependencies. Zlyme builds the kernel and initramfs with Buildroot. No matching Zlyme failure. | **DO NOT ADOPT** |

## Dependency graph

Checked with `patch --dry-run -p1` against files extracted from pristine `linux-7.0.2.tar.xz`:

| Patch | On pristine 7.0.2 |
| --- | --- |
| ROCKNIX `001` | applies |
| ROCKNIX `007` | applies (alternative to Zlyme `0007`, not a stack) |
| ROCKNIX `002` | applies |
| ROCKNIX `008` | fails; needs the `002` boot path |
| ROCKNIX `005` | fails; needs the later series |

Intended later order, if implementation is approved:

```text
Linux 7.0.2
    -> retained Zlyme patches, including 0007 and not ROCKNIX 007
    -> RK817 001
    -> RK817 002
    -> RK817 008 only after Flip evidence
005 stays on the Phase 6 side of that line
```

## Proposed implementation sequence

Do not combine a gauge experiment with unrelated deletions in one commit or one OTA.

1. **5.1** Remove `0004` and, once `CONFIG_INPUT_POLLDEV` has no other selector, `0002` plus that config symbol. Confirm the built Flip DTB still has no `adc-keys` node and that `miyoo-flip-gamepad` still probes.
2. **5.2** Remove `0030` if a boot log from a normal power cycle is no longer needed. One commit.
3. **5.3** Re-diff `0008`, `0021`, `0006`, and `0013` against 7.0.2 before calling any of them upstream. `0006` is in 7.3-rc5 but not in 7.0.2, so it stays until a kernel bump. Do not bump Linux in Phase 5.
4. **5.4** Isolate RK817 `001`. Measure. Only then consider `002`, then `008`. Leave `0007` in place.
5. **5.5** Do not touch `1010`, `1012a`, `1012b`, `9901`, or the ROCKNIX GPU pmdomain patch. Those stay with Phase 6 and Phase 7.

## Battery validation plan

Percentage is not off-state current. The `SYS_CAN_SD` evidence stays the direct current measurement already recorded (about 8 mA with the bit set, about 0.05 mA cleared, register `0xe6` `0xc5` after a true POR).

For a later `001` / `002` / `008` experiment, log before and after, and do not change `0007` in that image:

- cold boot after a true power-off (battery disconnect or an equivalent POR, not only `poweroff` if the PMIC did not reset)
- warm reboot
- several hours powered off, then boot
- boot on the charger and boot off the charger
- charge to the driver's full condition
- partial discharge
- rested pack (no load long enough for the relax pair)
- suspend/resume, and suspend while charging, only when the build also includes `005` or when the test is only checking that `001`/`002` did not break resume

Capture, when the sysfs or debug files exist:

- `capacity`, `voltage_now`, `voltage_avg`, `current_now`, `current_avg`, `charge_now`, `charge_full`
- `voltage_boot` and `voltage_ocv` only if `002` added those properties
- the boot line the patch prints (counter µAh, saved SoC, full-charge mAh, battery µV, `off_cnt`)
- `RK817_GAS_GAUGE_OFF_CNT` and the NVRAM SoC before the clamp, if a temporary debug print is used for the test build

Pass condition for `001` alone: a saved SoC above 10% is no longer forced to 10% across reboot, and a value above 100% is still rejected. Pass condition for `002` is a separate image: a powered-off period that previously reseeds from `PWRON_VOL` no longer jumps the displayed percentage without a matching voltage change, and a charger-plug boot does not report a voltage above `voltage-max-design`.
