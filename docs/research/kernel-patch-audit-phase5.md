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

The Phase 5 starting tree had eighteen patches. Phase 5A dropped three. Fifteen remain. The Phase 2 inventory had 45. This table is that starting list with the Phase 5A disposition.

| Path | Subject | Provenance | Files | Flip use | 7.0.2 | Upstream `7.3-rc5` | Proposed disposition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `10-mainline/linux/0002-input-add-input-polldev-driver.patch` | restore `input-polldev` | brooksytech | `input-polldev.c`, Kconfig | No remaining caller. `gpio_keys_polled.c` in 7.0.2 does not include `input-polldev.h`. Flip volume and hall nodes are `gpio-keys`. `miyoo-flip-gamepad` does not use the helper. `KEYBOARD_GPIO_POLLED` does not depend on `INPUT_POLLDEV`. | Symbol existed only because of this patch. | Same. | DROP. Removed in Phase 5A. `CONFIG_INPUT_POLLDEV=y` was removed from `linux.config`. |
| `10-mainline/linux/0004-input-adc-keys-redirect-keycode-316-to-rocknix-joypa.patch` | export `joypad_input_g` from adc-keys | spycat88 | `adc-keys.c` | No Flip `adc-keys` node. No C consumer of `joypad_input_g`. The Phase 3 driver does not reference it. | adc-keys exists; the export does not. | Not an upstream symbol. | DROP. Removed in Phase 5A. Nothing replaced the symbol; the Flip gamepad is `miyoo,flip-gamepad`. |
| `10-mainline/linux/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | RTL8733BU firmware table | spycat88, `656d871541b3` | `btrtl.c`, `btusb.c` | Flip DTS has `rockchip,rtl8733bu-power`. | `8733` is absent from pristine `btrtl.c`. | Still absent from `7.3-rc5` `btrtl.c`. | KEEP. Not upstream. |
| `20-rk3566/linux/0001-arm64-dts-rockchip-rk356x-add-1992mhz-cpu-opp-with-t.patch` | 1992 MHz OPP at 1.15 V, `turbo-mode` | sydarn | `rk3566.dtsi` | Flip includes that dtsi and does not delete the OPP. `zlyme-governor` `profile_overclock` sets `408000..1992000` when boost is on. Undervolt overlays `rk3566-undervolt-cpu-l1/l2/l3.dts` each contain `opp-1992000000`. | Not in the stock dtsi; this patch adds it. | Not treated as upstream. | KEEP. Optional boost, not the 1.8 GHz path. Removing it changes a live policy and the undervolt overlays. |
| `20-rk3566/linux/0002-power-supply-rk817-update-battery-and-charger-name-s.patch` | `rk817-battery` to `battery`, charger name to `charger` | ab0tj | `rk817_charger.c` | Live. Apostrophe reads `/sys/class/power_supply/battery/capacity`. `PLAT_getBatteryStatusFine` also reads that path and comments that the charger class may still be `rk817-charger`. | Stock names are the `rk817-*` strings. | Not re-checked; the rename is a Zlyme userspace ABI. | KEEP. A rename back would be a separate userspace migration, not a patch deletion. |
| `20-rk3566/linux/0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | clear `SYS_CAN_SD` | Zetarancio, 2026-04-05 | `rk817_charger.c`, `rk808.h` | Flip hardware. Wiki and `docs/OPERATIONS.md` / `ARCHITECTURE.md` require it. True POR leaves register `0xe6` at `0xc5` (bit set): about 8 mA off, about 0.05 mA with the bit clear. | `RK817_SYS_CAN_SD` is absent. | Still absent from `7.3-rc5`. | KEEP. See the comparison below. Do not stack ROCKNIX `007` on top. |
| `20-rk3566/linux/0008-arm64-dts-rockchip-add-support-for-mali-bifrost-driv.patch` | Mali resets and power model on `&gpu` | Danil Zagoskin | `rk356x-base.dtsi` | Flip enables `&gpu`. | Phase 2: not in 7.0.2. Not re-diffed this pass. | Unknown this pass. | KEEP until a hunk diff shows the dtsi already has it. Not the ROCKNIX pmdomain clock patch. |
| `20-rk3566/linux/0013-Bluetooth-Check-key-sizes-only-when-Secure-Simple-Pa.patch` | key-size check only when SSP is on | Marcel Holtmann, 2019, `cce32250027f` | `hci_conn.c` | Generic Bluetooth. Helps legacy devices. Not Flip-specific. | `hci_conn_check_link_mode` still uses `if (hci_conn_ssp_enabled(conn) && !encrypt) return 0`. | `7.3-rc5` still has that combined test, not the early `!ssp` return. | KEEP. Downstream relative to 7.0.2 and 7.3-rc5. |
| `20-rk3566/linux/0021-arm64-dts-rockchip-fix-missing-dma-names.patch` | `dma-names` on a shared SoC node | spycat88 | `rk356x-base.dtsi` | Flip includes that dtsi. | Phase 2: carried because the hunk was not already pristine. Not re-diffed this pass. | Unknown this pass. | KEEP until a pristine diff says the names exist. |
| `20-rk3566/linux/0030-mfd-rk8xx-log-on-off-source-for-RK817-RK809.patch` | `dev_info` of ON/OFF source | Zetarancio | `rk8xx-core.c` | No current procedure in `docs/OPERATIONS.md`, `board/`, `package/`, or `scripts/` reads `ON_SOURCE` / `OFF_SOURCE`. Historical notes are not a runtime contract. The off-state drain fix remains patch `0007`. | The log was not in pristine 7.0.2. | Not re-checked after removal. | DROP. Removed in Phase 5A. |
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

## Phase 5A result

Phase 5A removed three patches and did not change battery-gauge behavior. `0007` is untouched. ROCKNIX `001`/`002`/`005`/`008` were not applied.

Removed:

- `0002` input-polldev. Safe because no selected driver calls `input_*_polled_device`, 7.0.2 `gpio_keys_polled.c` does not include that header, and `KEYBOARD_GPIO_POLLED` does not select `INPUT_POLLDEV`. `CONFIG_INPUT_POLLDEV=y` was deleted from `linux.config`. It cannot be re-selected: the symbol is not in pristine 7.0.2 Kconfig.
- `0004` adc-keys `joypad_input_g` export. Safe because the Flip DTS has no `adc-keys` node, volume and lid are `gpio-keys`, and `miyoo-flip-gamepad` does not reference the symbol. The old ROCKNIX joypad module is not built.
- `0030` RK817 ON/OFF `dev_info`. Safe because nothing in the current operational docs or userspace parses that line. The physical off-state fix stays `0007`.

Fifteen Linux patches remain, in application order: `0005`, `0001`, `0002` (supply names), `0007`, `0008`, `0013`, `0021`, `0666`, `1001`, `1010`, `1012a`, `1012b`, `1013`, `9901`, `0006`. Number gaps are the removed files. Retained names were not renumbered. Later retained patches do not touch `input-polldev.c`, `adc-keys.c`, or the `0030` hunk in `rk8xx-core.c`.

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

## Phase 5A hardware acceptance — 2026-09-28

The image `zlyme-my355-20260928-b0594dc35ee5.tar` (SHA-256 `64d3c391f2f9edb0141b1878ca135139855769b3e40c4bec80a2567c13eea6a4`) was installed with Etcher and accepted on the Miyoo Flip: boot to NextUI, built-in d-pad / ABXY / sticks / MENU, one emulator with controls and MENU+START, volume buttons, lid or power suspend and resume, and a clean shutdown. Phase 5A is accepted. Phase 5 is not complete.

## Phase 5B — BSP fuel gauge versus Linux 7.0.2

No kernel patch was added or removed. No RK817 register was written. `0007` was not edited.

### Local evidence

| Tree | What it is |
| --- | --- |
| `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP` | Hardware wiki. Git `main` `b08e335d31fca41383e01176390914c3d4550ec5`, remote `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`, clean relative to `origin/main`. |
| `Extra/linux-5.10.y-3b916183b455b56c966bc7c19c3f772d258dc583` | Linux 5.10 tree sitting inside that wiki checkout. It is not its own git repository. `drivers/power/supply` has no `rk817_battery.c` or `rk817_charger.c`. `drivers/mfd/rk808.c` is present. `include/linux/mfd/rk808.h` in that tree has no `RK817_GAS_GAUGE_*` block. |
| `Extra/kernel_config` | `CONFIG_BATTERY_RK817=y` and `CONFIG_CHARGER_RK817=y`. |
| `Extra/System.map-5.10` | The built 5.10 image contained `rk817_bat_init_coulomb_cap`, `rk817_bat_save_dsoc`, `rk817_bat_save_data`, `rk817_bat_get_pwron_voltage`, `rk817_bat_get_ocv_voltage`, `rk817_bat_get_relax_voltage`, `is_rk817_bat_relax_mode`, `rk817_bat_pm_suspend`, `rk817_bat_pm_resume`. It does not contain `rk817_bat_not_first_pwron`, `is_rk817_bat_last_halt`, `rk817_bat_rsoc_init`, or `max_soc_offset`. |

The C implementation of those symbols is not in the supplied tree, so the BSP halt test and the relax threshold were not reconstructed from source. The wiki quotes only the `SYS_CAN_SD` helper from `rk3568_linux-rosa1337`: clear the bit unless `gate_function_disable` is set. That is the behavior Zlyme `0007` already implements unconditionally. The wiki also separates the two bugs: physical off current is `SYS_CAN_SD` (~8 mA with the bit set, ~0.05 mA cleared, true POR reads `0xe6 = 0xc5`); an earlier large percentage drop was fuel-gauge OCV reseed when `OFF_CNT >= 3`, with terminal voltage matching to 140 µV over 5.7 h and the percentage unchanged after ~20 h off.

No Miyoo Flip battery DTS was found in that 5.10 tree. Zlyme's current node remains the comparison target: 3 Ah, 4.25 V, 1.5 A, 150 mA termination, OCV 3.2–4.25 V at 20 °C from the 2025 firmware, sense resistor 10000 µΩ, sleep-enter 150 mA, sleep-filter 100 mA, `factory-internal-resistance-micro-ohms = <100000>`. Mainline `rk817_charger.c` does not read that resistance property. Relax OCV does not need it. A loaded terminal-voltage bound (`008`) does: 0.1 Ω at 1 A is 100 mV, which moves the Flip OCV curve by several percent. `008` stays deferred.

### Linux 7.0.2 boot path

Pristine `rk817_charger.c` from `linux-7.0.2`. Registers, from `rk808.h`:

| Field | Address | Encoding |
| --- | --- | --- |
| `GG_STS` | `0x57` | `BAT_CON` is bit 4. Set means uninitialized. The driver clears it after first setup. `RELAX_STS` is bit 1. |
| `OFF_CNT` | `0x6f` | One byte. Mainline comment: decaminutes, saturates at 255. |
| `Q_INIT` | `0x70`–`0x73` | Big-endian 32-bit coulomb ADC. |
| `Q_PRES` | `0x74`–`0x77` | Big-endian 32-bit live coulomb ADC. |
| `PWRON_VOL` | `0x6b`–`0x6c` | Big-endian 16-bit. |
| `OCV_VOL` | `0x63`–`0x64` | Big-endian 16-bit. |
| Saved SoC (BSP DSOC area) | `0x9a`–`0x9c` | Little-endian 24-bit. `0` = 0%, `100000` = 100%. |
| Saved remaining mAh | `0x9d`–`0x9f` | Little-endian 24-bit mAh. |
| Saved FCC mAh | `0xa0`–`0xa2` | Little-endian 24-bit mAh. |

`rk817_read_battery_nvram_values()` loads FCC, replaces an impossible FCC with the design capacity, then loads SoC and clamps `soc > 10000` to `10000`.

`rk817_read_or_set_full_charge_on_boot()` then:

- If `BAT_CON` is set (first init): SoC comes from `PWRON_VOL` through the OCV table at 20 °C, FCC is the design capacity, `BAT_CON` is cleared, and NVRAM is saved. The clamped NVRAM SoC is not read.
- Otherwise it reads NVRAM (including the clamp) and then **replaces** `charger->soc` before the coulomb counter is rewritten:
  - `OFF_CNT >= 3`: SoC from `PWRON_VOL` and the OCV table.
  - else: SoC from `Q_PRES` converted to mAh, times `100000 / fcc_mah`.

The value used to program `Q_INIT` is that replaced SoC, not the clamped NVRAM value. Later updates in `rk817_read_props()` set SoC from the live counter (`charge_now_uah * 100 / fcc_mah`) and `rk817_bat_calib_cap()` writes that live SoC back to NVRAM. Displayed capacity is `(soc + 500) / 1000`.

So patch `001` corrects a real ceiling bug, but on the current 7.0.2 normal-boot path the clamped value is overwritten before it becomes the visible percentage or the counter seed. `001` alone is **correct and currently latent**. It becomes reachable if a later change keeps the saved SoC when the counter is rejected. That is what ROCKNIX `002` does for a non-positive counter. `001` is a prerequisite for that fallback, not a user-visible fix by itself.

`002` items against this driver and the missing BSP C file:

| `002` item | Match |
| --- | --- |
| `PWRON_VOL` only on first init | Already what 7.0.2 does when `BAT_CON` is set. BSP function `rk817_bat_get_pwron_voltage` exists in System.map; the condition was not readable. |
| Normal boot uses the coulomb counter | Already what 7.0.2 does when `OFF_CNT < 3`. |
| Non-positive counter keeps saved SoC | Not in 7.0.2. 7.0.2 clamps a negative ADC to 0 and then derives SoC from that. This is the part of `002` that would make `001` matter. BSP source for the rule was not in the tree. |
| Keep the battery-info OCV table | Both already use it. |
| Expose `voltage_boot` and `voltage_ocv` | Not in 7.0.2. Observability, not a gauge algorithm. |
| Periodic relax pair, re-init counter if it differs by more than 5% | Not in 7.0.2. No `max_soc_offset` in the local wiki or in `System.map-5.10`. The 5% figure is ROCKNIX policy from other handhelds, not a proven Flip threshold. |

`005` remains Phase 6. `008` stays deferred: it treats loaded terminal voltage as an OCV bound, and the unused 0.1 Ω resistance property is exactly why that is less safe than a rested relax voltage.

### Live device, read only

Kernel `Linux version 7.0.2 ... #1 SMP PREEMPT Mon Sep 28 00:23:23 UTC 2026`. That is the Phase 5A rebuild. `/usr/share/zlyme/version` is still the NextUI pin `zlyme43 (2026-09-27)`, not the git SHA. `/storage/.update` was empty because the image was written with Etcher, not the OTA applicator. No reboot, power-off, or register write was done. debugfs was mounted and `regmap/0-0020/registers` was read.

`battery` (discharging, not charging):

| Property | Value |
| --- | --- |
| capacity | 88 |
| voltage_now | ABSENT |
| voltage_avg | 3649470 µV |
| current_now | ABSENT |
| current_avg | -1085148 µA |
| charge_now | 2626784 µAh |
| charge_full | 3000000 µAh |
| charge_full_design | 3000000 µAh |

`charger` (`type=USB`, `online=0`). `0xe6 = 0x40`: bit 7, `SYS_CAN_SD`, is clear.

Decoded NVRAM and counters (`res_div = 1` for the 10000 µΩ sense resistor):

| Field | Raw | Decoded |
| --- | --- | --- |
| Saved SoC `0x9a`–`0x9c` LE | `1c 55 01` | 87324 = 87.324%. Greater than 10000. |
| Saved remaining `0x9d`–`0x9f` LE | `3b 0a 00` | 2619 mAh. Equals `87324 * 3000 / 100000`. |
| Saved FCC `0xa0`–`0xa2` LE | `b8 0b 00` | 3000 mAh. |
| `Q_PRES` BE | `03 44 42 03` | ADC 54808579. `ADC_TO_CHARGE_UAH` ≈ 2619 mAh at the moment of the register read. Sysfs `charge_now` a moment earlier was 2627 mAh. |
| `OFF_CNT` | `0x00` | 0. Below the mainline reseed threshold of 3. |
| `GG_STS` | `0x49` | `BAT_CON` (bit 4) is clear. Not a first-init boot. `RELAX_STS` (bit 1) is clear. |

On the next boot, `rk817_read_battery_nvram_values()` would clamp 87324 to 10000 and then `rk817_read_or_set_full_charge_on_boot()` would discard that clamp and take the coulomb counter, because `OFF_CNT` is 0. The displayed 88% is the live counter, not the clamped NVRAM value.

The local BSP halt rule was not available to apply. The common `abs(live - saved) > FCC/10` test, which this tree does **not** confirm, would be about 8 mAh versus 300 mAh and would not call this a halt. That is an illustration, not a BSP result.

## Phase 5C — long power-off, 2026-09-28

Result: **INSUFFICIENT LONG-OFF INTERVAL**.

The Phase 5A image was shut down cleanly, left off about 40–45 minutes with the charger unplugged and the battery connected, then booted still unplugged. Capture was at `2026-09-28T01:15:43Z`. `/proc/uptime` was `2337.78` seconds (38.96 minutes after boot). Kernel is still `7.0.2 #1 SMP PREEMPT Mon Sep 28 00:23:23 UTC 2026`. Charger `online=0`. No register was written and the machine was not rebooted for this capture.

`OFF_CNT` (`0x6f`) read `0x00`. `GG_STS` is `0x49`, so `BAT_CON` (bit 4) is clear. `0xe6` is `0x40`, so `SYS_CAN_SD` is still clear. Linux 7.0.2 only reads `OFF_CNT`; it does not write it. Nothing under `board/my355` writes that register. The live value is therefore the hardware value, and it is below 3. The `PWRON_VOL` reseed branch was not taken. This run does not test that branch.

Post-boot `battery`, for the record, not as a reseed result: capacity 80, `voltage_avg` 3606280 µV, `voltage_now` ABSENT, `current_avg` -1034064 µA, `current_now` ABSENT, `charge_now` 2396304 µAh, `charge_full` 3000000 µAh. Saved SoC `04 38 01` = 79876 (79.876%). Saved remaining `5c 09 00` = 2396 mAh. FCC still 3000 mAh. `Q_PRES` `02 fd 41 71` converts to about 2394 mAh. Those numbers sit on the coulomb path, about 8 percentage points below the Phase 5B 88% / 87.324% snapshot, after the off interval plus 39 minutes powered on. That is not evidence of an OCV reseed, and it is not evidence of physical milliamp drain. The ~8 mA / ~0.05 mA `SYS_CAN_SD` result is unchanged.

`001` is still latent on both boot branches in the source: the `>= 3` branch replaces SoC from `PWRON_VOL` after the clamp, and this run did not enter that branch. No `001` image. The 5% relax loop in `002` is still unproven. The pre-reinit coulomb counter is not observable here because `OFF_CNT` never showed that the reseed ran. No temporary boot log is required until a later off interval actually leaves `OFF_CNT >= 3`.

Next step: **A. No implementation yet.** Repeat the unplugged power-off only if a future read shows `OFF_CNT >= 3` without writing the register. Do not apply `001`, `002`, `005`, or `008` from this run.

### Recommendation

Phase 5B said **D**: no gauge change until a long power-off is captured. Phase 5C did that capture and the counter stayed at 0, so the outcome is now **A**: no implementation yet.

`001` alone does not change today's displayed percentage. `002` mixes a saved-SoC fallback that would make `001` reachable with a 5% relax reseed that the Flip BSP source, which is missing from this checkout, does not justify. Do not reset `BAT_CON` or clear NVRAM to manufacture a test. `0007` stays as it is.

## Overnight power-off — 2026-09-28

The Phase 5A image was shut down in software, left off at least 6 hours with the charger unplugged and the battery connected, then started from the power button still unplugged. Capture was `2026-09-28T09:04:46Z`, `/proc/uptime` `127.08` seconds. Kernel is still `7.0.2 #1 SMP PREEMPT Mon Sep 28 00:23:23 UTC 2026`. Charger `online=0`. No register was written.

`OFF_CNT` is `0x32` = 50. The 7.0.2 comment treats that register as decaminutes, so 50 counts are 500 minutes (8.3 hours), which matches an overnight off. `GG_STS` is `0x41`: `BAT_CON` (bit 4) is clear, `RELAX_STS` (bit 1) is clear. `0xe6` is `0x40`: `SYS_CAN_SD` is clear. Linux 7.0.2 only reads `OFF_CNT`. Zlyme's board tree does not write it. The stock U-Boot `fg_rk817.c` does clear `OFF_CNT` after reading it; this boot did not, because the register is still 50. The earlier 40–45 minute off that read 0 was a real zero at that time, not a Linux clear. A uniform 10-minute tick would have made 45 minutes about 4 counts, so that short off did not run the same counter. This overnight did.

Voltage calibration from `VCALIB0` `0x8007` and `VCALIB1` `0xdfd3`, using the driver's integer formulas:

```text
voltage_k = (4025 - 2300) * 1000 / (57299 - 32775) = 70
voltage_b = 4025 - (70 * 57299) / 1000 = 15
PWRON_VOL raw = 0xdb77 = 56183
PWRON uV = 70 * 56183 + 1000 * 15 = 3947810
```

`power_supply_ocv2cap_simple()` on the Flip 20 °C table interpolates 3947810 µV between 3967000 µV / 85% and 3930000 µV / 80%:

```text
80 + (5 * 17810) / 37000 = 82
internal SoC = 82000
boot_charge_mah = 82000 * 3000 / 100 / 1000 = 2460
```

`Q_INIT` `03 11 a5 00` converts to 2459944 µAh, and `charge_now_uah * 100 / fcc_mah` is 81998. That is the 82% seed, not the pre-off 2396 mAh. Visible capacity is 81. `Q_PRES` `03 07 ee c0` is 2429500 µAh. Saved SoC `6e 3c 01` is 81006 (81.006%). Saved remaining `7e 09 00` is 2430 mAh. FCC is still 3000 mAh. At the measured −850884 µA, 127 seconds is about 30 mAh, 1.0% of 3000 mAh. 82% at probe minus that load is 81%. The post-boot gauge matches the `PWRON_VOL` reseed plus the consumption since boot.

Against the pre-off reference (79.876%, 2396 mAh, loaded `voltage_avg` 3606280 µV at about −1.03 A): the boot seed is +2.1 percentage points and +64 mAh. Displayed change after the SSH delay is 81 − 80 = +1 percentage point. Prediction error versus the visible 81% is 1 point, accounted for by the measured current. This is **REPRODUCED**. It is not a wild percentage collapse, and it is not physical drain. Six hours at the cleared-`SYS_CAN_SD` current is a fraction of a milliamp-hour. The pre-off 3.606 V reading was under about 1 A of load; `PWRON_VOL` at 3.948 V is the unloaded boot sample the table maps to 82%.

`001` stays latent on this branch too: the `>= 3` path replaces SoC from `PWRON_VOL` after the 10000 clamp. The saved 81006 is the post-boot writeback. No `001`-only image.

Of `002`, this run supports only the observation that 7.0.2 discards the previous coulomb boot state when `OFF_CNT >= 3` and writes `Q_INIT` from OCV. Keeping that counter would have stayed near 80% instead of 82%. That 2-point difference is the existing policy working, not a conversion bug. The saved-SoC fallback, `voltage_boot`, `voltage_ocv`, and the 5% relax loop are not justified by this capture. The pre-reinit hardware counter was overwritten by probe; the pre-off userspace value 2396 mAh is the comparison, not a register read from before `Q_INIT` was rewritten.

Next direction: do not implement a boot-gauge change. The overnight branch fired and landed on the OCV table. Do not apply `001`, `002`, `005`, or `008` from this result. `0007` stays.
