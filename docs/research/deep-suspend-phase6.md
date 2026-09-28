# Deep suspend — Phase 6A

Research only. No driver, DTS node, Kconfig symbol, or regulator policy was activated. No OTA was built. `vdd_logic` stays `regulator-on-in-suspend`. RK817 `005` was not applied.

Date: 2026-09-28. Branch `phase-6-deep-suspend` at the start of this note: `d2094007a8661b722611b12d3de767700f0cd873`. Accepted runtime baseline remains `8119387e0fdb729f1f013bed9dbc48c76e37a1df`.

Ordinary Linux suspend already works, including a resume from `/sys/power/mem_sleep` set to `deep`. That is not the same thing as programming the RK3568 BL31 low-power mode. The SIP configuration driver is not in the running image.

Evidence labels:

```text
PROVEN FROM SOURCE
PROVEN FROM DTB
SUPPORTED BY SYMBOL/BINARY EVIDENCE
BSP INFERENCE ONLY
UNKNOWN
```

## Source revisions

| Source | Revision | What it is |
| --- | --- | --- |
| Zlyme | `d2094007a8661b722611b12d3de767700f0cd873` | Current tree. Linux 7.0.2. |
| Linux 7.0.2 | `dl/linux/linux-7.0.2.tar.xz` | Pristine selected kernel. Not `output/build`. |
| Rockchip BSP 5.10 | `rockchip-linux/kernel` `develop-5.10` `95a3ad83f7f90e0e672b9c99b0858b4964318667` | Vendor PM-config driver. |
| Rockchip BSP 6.1 | same repo, `develop-6.1` `77168c8d5ab82399f65a80e9f807b50ba37cf483` | Later vendor driver. |
| ROCKNIX | `ROCKNIX/distribution` `fe127fad01f6006bea1734ebde87d1c02cc6d256` | PX30S trim, not an RK3566 port. |
| Hardware wiki | `b08e335d31fca41383e01176390914c3d4550ec5` | Local checkout. |
| Stock firmware DTB | `miyoo355_fw_20250527/unpack/miyoo355_20250527_0.dts` | Decompiled shipped tree. |
| Stock System.map | `Extra/System.map-5.10` | A 5.10 kernel image map. Not proven to be the same build as that DTB. |
| Local 5.10 tree | `Extra/linux-5.10.y-3b916183b455b56c966bc7c19c3f772d258dc583` | Makefile says 5.10.160. It is not the Rockchip BSP tree. |

## Old Zlyme `1013a/b`

The files were not recovered.

Searched: tracked files, ignored and untracked names, `git log --all -S'RK3568_SUSPEND_MODE'`, `git log --all -S'rockchip,rk3568-suspend'`, and local filenames under the repository and a shallow home search. The only hits are the current comment in `linux.config` and the commented node in `rk3566-miyoo-flip.dts`. Those comments are already present in the first board commit `d843dbecf314122605c1374e4fe5d98e1c09c06b`. The patch files were never committed here.

```text
NOT RECOVERED
```

What survives, and what it is allowed to prove:

| Artifact | Text | Strength |
| --- | --- | --- |
| `board/my355/linux/linux.config` | `# 1013a/b rk3568-suspend patches are .testing-disabled` and `# CONFIG_RK3568_SUSPEND_MODE is not set` | The symbol name and the two-file split are recorded. The C source is not. |
| Commented DTS node | compatible `rockchip,rk3568-suspend`, the flag list below, `sleep-debug-en = <0>` | This is a hypothesis left in a comment. It is not a driver. |
| Comment above that node | "Sends sleep-mode-config and wakeup-config to BL31 via SIP_SUSPEND_MODE SMC at probe and before each suspend." | Untrusted. It names a lifecycle, but there is no source to check the SMC register order, return handling, or whether `LINUX_PM_STATE` was included. |

There is no SHA-256, subject line, Kconfig text, Makefile line, or new C file to inventory. This note does not reconstruct one.

The commented node, for comparison only:

```dts
rk3568-suspend {
	compatible = "rockchip,rk3568-suspend";
	status = "okay";
	rockchip,sleep-debug-en = <0>;
	rockchip,sleep-mode-config = <
		(0
		| RKPM_SLP_CENTER_OFF
		| RKPM_SLP_ARMOFF_LOGOFF
		| RKPM_SLP_PMIC_LP
		| RKPM_SLP_HW_PLLS_OFF
		| RKPM_SLP_PMUALIVE_32K
		| RKPM_SLP_OSC_DIS
		| RKPM_SLP_32K_PVTM)
	>;
	rockchip,wakeup-config = <(0 | RKPM_GPIO_WKUP_EN)>;
};
```

The block is inside a block comment, so it is not in the built DTB.

## BSP 5.10 and 6.1

Both branches use this node, in `rk3568.dtsi` (5.10) and `rk356x.dtsi` (6.1):

```dts
rockchip_suspend: rockchip-suspend {
	compatible = "rockchip,pm-rk3568";
	status = "disabled";
	rockchip,sleep-debug-en = <1>;
	/* ARMOFF_LOGOFF | CENTER_OFF | HW_PLLS_OFF | PMUALIVE_32K
	   | OSC_DIS | PMIC_LP | 32K_PVTM */
};
rockchip,wakeup-config = <(0 | RKPM_GPIO_WKUP_EN)>;
```

`rockchip,rk3568-suspend` does not appear in either DTS. The driver match table in both `rockchip_pm_config.c` files includes `rockchip,pm-rk3568`. It does not include `rockchip,rk3568-suspend`.

Header `include/dt-bindings/suspend/rockchip-rk3568.h` is the same on both branches for the bits Zlyme's comment names. The OR of those seven sleep bits is `0x5ec`:

| Bit | Name | Value |
| --- | --- | --- |
| 3 | `RKPM_SLP_ARMOFF_LOGOFF` | `0x008` |
| 2 | `RKPM_SLP_CENTER_OFF` | `0x004` |
| 6 | `RKPM_SLP_HW_PLLS_OFF` | `0x040` |
| 7 | `RKPM_SLP_PMUALIVE_32K` | `0x080` |
| 8 | `RKPM_SLP_OSC_DIS` | `0x100` |
| 5 | `RKPM_SLP_PMIC_LP` | `0x020` |
| 10 | `RKPM_SLP_32K_PVTM` | `0x400` |

`RKPM_GPIO_WKUP_EN` is bit 4 of the wake mask, `0x10`. `RKPM_SLP_32K_EXT` is not in the default mask. The 32 kHz choice in this default is the PMU alive clock plus PVTM, not an external oscillator. That is a BSP default, not a Flip crystal measurement.

SMC service, both headers: `SIP_SUSPEND_MODE` `0x82000003`. Subcommands used by the driver:

| Value | Name |
| --- | --- |
| `0x01` | `SUSPEND_MODE_CONFIG` |
| `0x02` | `WKUP_SOURCE_CONFIG` |
| `0x05` | `SUSPEND_DEBUG_ENABLE` |
| `0x09` | `LINUX_PM_STATE` |

`sip_smc_set_suspend_mode()` returns `res.a0` from the SMC. The 5.10 `.prepare` path ignores that return.

### Lifecycle, BSP 5.10

`PROVEN FROM SOURCE` at `95a3ad83`.

Probe parses the node named `rockchip-suspend` and, when the properties exist, sends:

- `SUSPEND_MODE_CONFIG`
- `WKUP_SOURCE_CONFIG`
- `SUSPEND_DEBUG_ENABLE`
- plus optional PWM, GPIO power, APIOS, IO retention, and sleep-pin calls

`.prepare` is compiled only when the driver is not a module (`#ifndef MODULE`). On every suspend it sends:

- `LINUX_PM_STATE` with `mem_sleep_current`
- `SUSPEND_MODE_CONFIG` again, using the state-specific mask or the `mem` default
- `WKUP_SOURCE_CONFIG` again, the same way

There is no `.suspend_late` or `.resume_early` in 5.10. A module build registers the driver and still runs probe, but it does not register `.prepare`, so it never sends `LINUX_PM_STATE` and never resends the masks.

### What 6.1 changed

`PROVEN FROM SOURCE` at `77168c8d`. The RK3568 compatible, default mask, and wake bit are the same. Material differences:

- `.prepare` reads `get_mem_sleep_current()` instead of the `mem_sleep_current` symbol.
- `.complete`, `.suspend_late`, and `.resume_early` exist. The late/early pair enables and disables regulators named for the pre-mem window. The Flip DTS does not have those lists.
- If the driver is built as a module, probe returns before the per-state sleep-config parse. The PM callbacks are still in the driver object; the 5.10 file omitted them entirely under `#ifndef MODULE`.
- The SIP header adds explicit negative return codes (`SIP_RET_NOT_SUPPORTED` and others). The 5.10 header used for this comparison does not list those names next to the suspend calls.
- The match table adds `rockchip,pm-rk3538`. Irrelevant to the Flip.

## Local Miyoo stock

### Source tree

`Extra/linux-5.10.y-3b916183...` is Linux 5.10.160. `drivers/soc/rockchip/` contains `grf.c`, `io-domain.c`, and `pm_domains.c`. It does not contain `rockchip_pm_config.c`, `drivers/firmware/rockchip_sip.c`, or `include/dt-bindings/suspend/rockchip-rk3568.h`.

```text
Does this checkout's source configure BL31 suspend mode?
NOT PROVABLE FROM LOCAL STOCK SOURCE
```

`include/soc/rockchip/rockchip_sip.h` in that tree has no `SUSPEND_MODE` symbol. That header is not the BSP SIP header.

The board DTS checked in under `Extra/miyoo355_sdk_release/dts/rk3566-miyoo-355-v10-linux.dts` and `Extra/rockchip/rk3566-miyoo-355-v10-linux.dts` does not contain `rockchip-suspend` or `pm-rk3568`. The shipped tree can still inherit the node from a dtsi that is not that file.

### Firmware DTB

`PROVEN FROM DTB`, `miyoo355_20250527_0.dts`:

```dts
rockchip-suspend {
	compatible = "rockchip,pm-rk3568";
	status = "okay";
	rockchip,sleep-debug-en = <0x01>;
	rockchip,sleep-mode-config = <0x5ec>;
	rockchip,wakeup-config = <0x10>;
};
```

`0x5ec` is the BSP seven-bit mask above. `0x10` is `RKPM_GPIO_WKUP_EN`. `serial@fe660000` (UART2) is `status = "disabled"` in the same tree. `vdd_logic` (`DCDC_REG1`) is `regulator-off-in-suspend`. `vdd_gpu` is off. `vcc_ddr` (`DCDC_REG3`) is `regulator-on-in-suspend`. `vcc_3v3` is off, with a suspend microvolt.

Which driver consumed that node, and at which callback, is not in the decompiled DTB.

### System.map-5.10

`SUPPORTED BY SYMBOL/BINARY EVIDENCE`. This map is not proven to be the kernel that booted the DTB above.

Present: `pm_config_probe`, `pm_config_prepare`, `sip_smc_set_suspend_mode` (exported), `rockchip_pm_drv_register`, and an initcall whose name includes `rockchip_pm_config`.

Absent from a direct search: `pm_config_suspend_late`, `pm_config_resume_early`, `pm_config_complete`.

That shape matches BSP 5.10 (probe plus prepare, no late regulator callbacks) better than BSP 6.1. It does not prove the SMC argument order inside `pm_config_prepare`.

## Linux 7.0.2

`PROVEN FROM SOURCE` in the pristine tarball.

`include/soc/rockchip/rockchip_sip.h` defines:

```c
#define ROCKCHIP_SIP_SUSPEND_MODE  0x82000003
#define ROCKCHIP_SLEEP_PD_CONFIG   0xff
```

It does not define `SUSPEND_MODE_CONFIG`, `WKUP_SOURCE_CONFIG`, `SUSPEND_DEBUG_ENABLE`, or `LINUX_PM_STATE`.

`drivers/pmdomain/rockchip/pm-domains.c` calls `arm_smccc_smc(ROCKCHIP_SIP_SUSPEND_MODE, ROCKCHIP_SLEEP_PD_CONFIG, ...)` only when `arm_smccc_1_1_get_conduit()` is not `SMCCC_CONDUIT_NONE`. That is the existing mainline use of this SMC: power-domain idle configuration, subcommand `0xff`, not the BSP suspend-mode subcommands.

`drivers/soc/rockchip/Kconfig` has no `ROCKCHIP_PM_CONFIG`. There is no `rockchip_pm_config.c`.

`drivers/mfd/rk8xx-core.c` already owns the RK817 sleep pin:

- `rk8xx_suspend()` writes `SLPPIN_SLP_FUN`
- `rk8xx_resume()` writes `SLPPIN_NULL_FUN`
- `rk8xx_shutdown()` writes `SLPPIN_DN_FUN`

The DTS comment that vanilla rk8xx handles SLPPIN is accurate for 7.0.2. A deep-suspend driver should not also write that register.

## ROCKNIX PX30S trim

`projects/ROCKNIX/devices/RK3326/patches/linux/031-px30s-suspend-wakeup-config.patch` at `fe127fad`. This is PX30S (`rockchip,pm-px30`), not RK3566. Do not copy the SoC or the mask.

The architectural point in its own comment: an earlier version that sent mode and wake only at probe was incomplete. The vendor driver also sends `LINUX_PM_STATE`. The trimmed driver:

- is `bool`, not a module, because it reads `mem_sleep_current`
- lives in `drivers/soc/rockchip/rockchip-pm-config.c`
- at probe sends mode, wake, and debug
- at `.prepare` sends `LINUX_PM_STATE`, then resends mode and wake
- keeps only those four subcommands

That is the right size for a first Flip driver. Importing all of `rockchip_pm_config.c` would also pull virtual poweroff, MCU sleep, sleep IO tables, IO retention, GPIO power lists, PWM regulator config, and the 6.1 regulator on/off lists. The Flip DTS and the stock DTB do not describe those.

## BL31

Zlyme selects it in `configs/zlyme_my355_defconfig`:

```text
BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME="bin/rk35/rk3568_bl31_v1.44.elf"
```

The comment there says a normal card boot uses the NAND preloader for DDR, and this BL31 still runs. The paired TPL blob is `rk3566_ddr_1056MHz_v1.23.bin`.

The local file `bl31_v1.44_stock_disasm/rk3568_bl31_v1.44.elf` contains the strings `suspend_mode_config`, `(	mode: RKPM_SLP_ARMOFF_LOGOFF`, and `Exceeded the supported suspend GPIO number.`

```text
SUPPORTED BY BINARY EVIDENCE
```

Those strings show this ELF knows an ARMOFF_LOGOFF mode and a suspend-mode configuration path. They do not prove that subcommand `0x01` or `0x09` is accepted, or what `res.a0` is on failure. A later 6C test can log `res.a0` for `SUSPEND_MODE_CONFIG`, `WKUP_SOURCE_CONFIG`, `SUSPEND_DEBUG_ENABLE`, and `LINUX_PM_STATE` without turning `vdd_logic` off. This research task did not issue SMC calls.

Unknown until that log exists: whether v1.44 accepts `LINUX_PM_STATE`, whether a bad subcommand returns the 6.1 `SIP_RET_NOT_SUPPORTED` value, and whether `PMIC_LP` in the mask matches the RK817 sleep pin the kernel already programs.

## Verdict on the surviving Zlyme comment

The C file is missing, so rows that need it are `UNKNOWN`.

| Claim in the comment or node | BSP 5.10 | BSP 6.1 | Stock | Linux 7.0.2 | Verdict |
| --- | --- | --- | --- | --- | --- |
| Compatible `rockchip,rk3568-suspend` | Not a match string | Not a match string | DTB uses `rockchip,pm-rk3568` | No driver | AI-INVENTED / NO EVIDENCE |
| Node name `rk3568-suspend` | `rockchip-suspend` | `rockchip-suspend` | `rockchip-suspend` | none | WRONG |
| The seven sleep bits | Same set, `0x5ec` | Same set | DTB value `0x5ec` | no binding | CORRECT as a mask, not as a proven Flip requirement by itself |
| Wake `RKPM_GPIO_WKUP_EN` | Default | Default | DTB `0x10` | none | CORRECT as the stock/BSP default |
| `sleep-debug-en = <0>` | BSP dtsi uses `<1>` but `status = "disabled"` | Same | DTB `<1>` and `status = "okay"` | none | Differs from stock. Debug-off is a reasonable production default. Not proven required. |
| SMC `0x82000003` | `SIP_SUSPEND_MODE` | Same | `sip_smc_set_suspend_mode` exists in System.map | `ROCKCHIP_SIP_SUSPEND_MODE` already `0x82000003` | CORRECT BUT SHOULD USE MAINLINE API |
| Sent at probe and again before suspend | Probe plus `.prepare` | Probe plus `.prepare` | `pm_config_prepare` exists in System.map | no driver | The comment matches BSP. The missing C file cannot confirm the old patch did this. |
| `LINUX_PM_STATE` each suspend | Yes, in `.prepare` | Yes | Not separable from the symbol `pm_config_prepare` | constant absent | UNKNOWN for the old patch. REQUIRED for a replacement, because BSP and the PX30S postmortem both treat a probe-only config as incomplete. |
| Parallel `drivers/firmware/rockchip_sip.c` | BSP has one | BSP has one | exported `sip_smc_set_suspend_mode` implies some SIP wrapper in that image | mainline already has `arm_smccc_smc()` and the SIP header | CORRECT BUT SHOULD USE MAINLINE API. Do not add a second SIP framework. |
| `CONFIG_RK3568_SUSPEND_MODE` | BSP does not use this symbol name | Same | unknown Kconfig text | symbol absent | UNKNOWN. A new option should not revive an unreviewed name just to match the comment. |
| Module versus built-in | Prepare omitted if `MODULE` | Module probe skips the per-state parse | initcall is from `rockchip_pm_config` | n/a | UNKNOWN for the old patch. Replacement should be built-in. |
| SMC return ignored | `.prepare` ignores `res.a0` | Same pattern | unknown | PM-domain path checks the conduit first | INCOMPLETE if copied. A Zlyme driver should check the conduit and `res.a0`. |
| SLPPIN written by this driver | Not in the suspend-mode path | Same | unknown | rk8xx already does it | BSP FEATURE NOT NEEDED BY ZLYME as a second writer |

## Binding, placement, and build

Use the stock and BSP compatible: `rockchip,pm-rk3568`, node name `rockchip-suspend`. A new Zlyme-only string would not match the DTB this board already shipped and would not match the vendor driver. The properties are a firmware ABI, not a description of a pin. Putting the same raw mask in DT is what BSP and the stock DTB already do. A YAML binding should say that, if the patch is written to a mainline standard. Do not add mem-lite, mem-ultra, virtual poweroff, or IO-retention properties until a Flip boot describes them.

Place a small built-in driver at `drivers/soc/rockchip/rockchip-pm-config.c`. That is where BSP and the PX30S trim put it. Add the four subcommand numbers next to `ROCKCHIP_SIP_SUSPEND_MODE` in `include/soc/rockchip/rockchip_sip.h`. Call `arm_smccc_smc()` only after `arm_smccc_1_1_get_conduit()` is not `SMCCC_CONDUIT_NONE`. If the conduit is absent, fail probe with an error. Do not treat a firmware rejection as success.

`bool`, not `tristate`. BSP 5.10 drops the per-suspend callback when built as a module. The PX30S trim is built-in for the same reason: it has to read the kernel sleep state before the suspend happens. A late-loaded module cannot fix a suspend that already started, and unloading it would leave BL31 holding the last mask with no owner.

Required DT properties for the first driver:

- `rockchip,sleep-mode-config`
- `rockchip,wakeup-config`
- `rockchip,sleep-debug-en` (0 in the first production-shaped experiment; 1 only while a debug image is asking BL31 to keep a console path)

Required SMC subcommands:

- `SUSPEND_MODE_CONFIG` (`0x01`)
- `WKUP_SOURCE_CONFIG` (`0x02`)
- `SUSPEND_DEBUG_ENABLE` (`0x05`)
- `LINUX_PM_STATE` (`0x09`)

Send debug at probe. Send `LINUX_PM_STATE`, then the mode mask, then the wake mask, from `.prepare` on every suspend. Nothing in BSP `.prepare` runs on resume except the 6.1 regulator list, which Zlyme should omit. rk8xx resume already clears the sleep pin.

Intentionally omitted: PWM regulator config, GPIO power lists, sleep IO and sleep-pin tables, IO retention, virtual poweroff, MCU sleep, mem-lite and mem-ultra, regulator name lists, power-domain device links, and `.suspend_late` regulator toggling.

## Regulators

Current Zlyme `rk3566-miyoo-flip.dts`:

| Rail | Suspend state | Note |
| --- | --- | --- |
| `vdd_logic` | on | Comment says BL31 defaults cannot restore the logic domain without the 1013 driver. The comment is not a measurement. Stock DTB turns this rail off. |
| `vdd_gpu` | off | |
| `vcc_ddr` | on | Stock DTB also keeps it on. |
| `vcc_3v3` | off | Comment says this was confirmed and TF-A restores it. That test predates this audit and was not repeated here. |
| `vcca1v8_pmu` | on | |
| `vdda_0v9` | off | |
| `vdda0v9_pmu` | on | |
| `vccio_acodec` | off | |
| `vccio_sd` | on | |
| `vcc3v3_pmu` | on | |
| `vcc_1v8`, `vcc1v8_dvp`, `vcc2v8_dvp` | off | |
| `boost`, `otg_switch` | off | |
| `vcc5v0_host`, `vcc3v3_lcd0_n` | off | |
| `vdd_cpu` | off | RK8600, not an RK817 DCDC. |
| `vcc_sd`, `vcc_sd2` | no `regulator-state-mem` | Comment says cutting SD power breaks resume. Left as written. |
| `vcc_wifi`, `vcc3v8_sys` | no `regulator-state-mem` | |

Do not change `vdd_logic` to `regulator-off-in-suspend` in the same image that first programs BL31. Prerequisites, in order:

1. The driver probes and the conduit is SMC.
2. Firmware `res.a0` for the four subcommands is a success code, logged, not assumed.
3. Suspend to `mem` with `deep` still resumes while `vdd_logic` stays on, including power-key wake.
4. Storage mounts cleanly after that resume.
5. Only then, a separate image turns `vdd_logic` off, with `ARMOFF_LOGOFF` in the mask that the previous image already showed was accepted.

`PMIC_LP` stays in the mask because it is in the stock value `0x5ec`. The kernel SLPPIN write stays in rk8xx. Those are different owners. Do not add a third.

## Wake and UART2

Stock and BSP enable only `RKPM_GPIO_WKUP_EN` in the BL31 mask. That arms GPIO wakeup at firmware. It does not mark every GPIO as a Linux wake source.

Already `wakeup-source` in the Zlyme DTS: volume up, volume down, the lid switch (wake on open only), and the RK817 node. The power key is the RK817 pwrkey child. USB, SD, PCIe, and timer bits exist in the header and are clear in the stock mask. Do not set them for the first test.

UART2 is `disabled` in the stock firmware DTB while `sleep-debug-en` is 1 and the suspend node is okay. So "UART2 must stay enabled or deep sleep cannot resume" is not what that DTB does. Zlyme enables UART2 because it is the debug console. `no_console_suspend` plus `sleep-debug-en = <1>` is how to watch the console across suspend. It is not a production requirement. Do not add `no_console_suspend` to the default command line.

## DFI, DMC, GPU, RK817 `005`

`1010` saves and restores DDRMON around system suspend. Its own text says the center domain drop is why the registers are lost. That drop happens if BL31 actually gates the center. Today the mode is not programmed, so `1010` is not a prerequisite for the first "send the mask, leave `vdd_logic` on" image. Keep the patch. Revisit it when `CENTER_OFF` is known to be accepted and DDR frequency scaling dies across resume. Do not edit it in 6B.

`1012b` already forces DDR back to the boot rate on suspend and turns on DDR auto self-refresh. That is the existing ATF assumption. Phase 6 can test deep suspend without moving the driver out of the kernel patch. Phase 7 still owns that extraction.

`0008` stays the Mali DT addition from Phase 5. The ROCKNIX GPU power-domain clock-ownership change is not required to find out whether BL31 accepts the suspend SMC. It is a later resume test if Panfrost or `mali_kbase` fails to come back after `vdd_logic` is allowed to drop. Do not apply it in the first image.

RK817 `005` (`fe127fad`, Jacob Cook) restamps the gauge across system sleep because the coulomb counter was wrong on an RG353M during charge. Those numbers are not Flip measurements. Ordinary `mem` on the Flip has not been shown to need it, and a deeper BL31 mode might change the error. It stays `EVALUATE IN PHASE 6`, after the firmware path resumes, and it stays out of the BL31 bring-up image.

## Recommended shape

One new patch, not a revival of unrecovered `1013a/b`.

```text
drivers/soc/rockchip/rockchip-pm-config.c
include/soc/rockchip/rockchip_sip.h   (four subcommand numbers only)
drivers/soc/rockchip/Kconfig          bool, depends on OF && HAVE_ARM_SMCCC
drivers/soc/rockchip/Makefile
rk3566-miyoo-flip.dts                 uncomment as rockchip-suspend / rockchip,pm-rk3568
                                      keep vdd_logic on
```

Probe: read the three properties, refuse a missing SMC conduit, send `SUSPEND_DEBUG_ENABLE`, optionally send mode and wake once so a failed call is visible before the first suspend.

`.prepare`: read the current mem sleep state, send `LINUX_PM_STATE`, resend mode, resend wake. Log control, arguments, and `res.a0`. If `res.a0` is a failure, `dev_err` and return that failure on the diagnostic image so the suspend does not continue into an unconfigured firmware state.

No resume callback. No second SIP C file. No module.

The first image changes only that driver and the DTS node. It does not change `1010`, `1012b`, `0008`, `005`, `9901`, or `vdd_logic`.

## Stages

| Stage | Content |
| --- | --- |
| 6A | This note. |
| 6B | Built-in driver and the BSP-compatible node. `vdd_logic` stays on. Debug logs of the four SMC results. |
| 6C | On device: conduit present, `res.a0` success, `mem` and `deep` both resume, power key wakes, storage is intact, input and the panel return. Repeat a handful of cycles, not dozens yet. |
| 6D | Separate image. Same mask, `vdd_logic` off. Resume must still work. If it does not, revert the regulator and keep the driver. |
| 6E | Only failures from 6D: DFI counters, GPU, RK817 gauge, Wi-Fi/BT, USB. One subsystem per experiment. |
| 6F | The roadmap gate: dozens of cycles, USB attached and not, radios on and off, audio, input, DMC scaling, NextUI first frame, standby current, filesystem intact. |

6B logs belong to that image: SMC id, subcommand, two arguments, `res.a0`, the Linux sleep state, and the mode and wake masks. One line per call. Drop them to `dev_dbg` or a Kconfig debug option before a release image. Do not leave `dev_info` on the success path forever.

## Open items

- The old `1013a/b` C source is gone. Any claim about its SMC order or return checks would be an invention.
- `System.map-5.10` and the 2025-05-27 DTB are not proven to be one image.
- BL31 v1.44 return codes for `0x01`, `0x02`, `0x05`, and `0x09` are unknown until 6C logs them.
- Whether `PMIC_LP` and rk8xx `SLPPIN_SLP_FUN` double-program the RK817, or whether both are required, is unknown. Stock shipped both the mask bit and a kernel that has the usual RK817 sleep-pin code, but this checkout does not contain that PMIC sleep function to compare.
- The "vcc_3v3 off is confirmed" DTS comment was not re-measured here.
- UART2's role in Zlyme resume, as opposed to debug output, is not established. Stock leaves it disabled.
