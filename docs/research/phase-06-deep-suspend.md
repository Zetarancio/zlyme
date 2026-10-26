# Deep suspend — Phase 6A

> Status: historical Phase 6 record, 2026-09-28 to 2026-09-29. The opening and the sections before "Phase 6B implementation" are Phase 6A research, written before anything was enabled. Later sections record 6B to 6D and the closure.
> Phase 6 then shipped `1011a`/`1011b` (`rockchip,pm-rk3568`, `CONFIG_ROCKCHIP_PM_CONFIG=y`) with `vdd_logic` off in mem suspend, and closed on runtime `b709719a` ("Phase 6 closure" below).
> Phase 7 replaced the `1012a`/`1012b` DMC patches this note describes with the external module `package/drivers/rk3568-dmc`.
> For the shipped behavior, read [docs/ARCHITECTURE.md](../ARCHITECTURE.md) "Hardware source of truth" and `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`.

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

They are not in the Zlyme git history. A later search of the local archived ROCKNIX checkout found them, renamed so the build does not apply them:

```text
/run/media/ale/SPCC/Cursor/MIYOO-FLIP/ROCKNIX/distribution
  revision d249b09bd95120c65555b0c56bc381f72ce073bc
  projects/ROCKNIX/devices/RK3566/patches/linux/
    1013a-dt-bindings-soc-rockchip-rk3568-suspend.patch.testing-disabled
      SHA-256 0d66a61107c4878508e9b416ff682a967c3a0da5a322ec9609a37436a8e4d13c
      Subject: dt-bindings: soc: rockchip: add rk3568 suspend configuration
      From: Zetarancio, dated 2025-02-25 in the patch header
      Adds Documentation/devicetree/bindings/soc/rockchip/rockchip,rk3568-suspend.yaml
    1013b-soc-rockchip-add-rk3568-suspend-configuration.patch.testing-disabled
      SHA-256 b96ec108a11db4ed0ccc68350de1356de60fc79fbd14ff689151b13f499b76f2
      Subject: soc: rockchip: add rk3568 suspend mode configuration driver
      Adds drivers/soc/rockchip/rk3568_suspend_config.c
      Adds include/dt-bindings/suspend/rockchip-rk3568.h
      Adds four subcommand macros to include/soc/rockchip/rockchip_sip.h
      Kconfig: config RK3568_SUSPEND_MODE, bool, depends on HAVE_ARM_SMCCC && SUSPEND && ARCH_ROCKCHIP
      Makefile: obj-$(CONFIG_RK3568_SUSPEND_MODE) += rk3568_suspend_config.o
```

The Zlyme tree still only has the config comment and the commented DTS node. Those comments were already in board commit `d843dbecf314122605c1374e4fe5d98e1c09c06b`. The `.testing-disabled` suffix is why they are not in an active patch directory.

What the recovered driver actually does:

- Compatible `rockchip,rk3568-suspend`. The binding text says this is intentionally smaller than the vendor `rockchip-pm-config` node. The string itself is not the BSP or stock compatible.
- `arm_smccc_smc(ROCKCHIP_SIP_SUSPEND_MODE, ctrl, cfg1, cfg2, 0, 0, 0, 0, &res)`. Argument order matches BSP `sip_smc_set_suspend_mode(ctrl, config1, config2)`.
- Subcommands `0x01`, `0x02`, `0x05`, and `0x09`, under local names. Values match the BSP header.
- Probe calls the apply helper: mode, wake, and debug if `rockchip,sleep-debug-en` is present.
- `.prepare` sends `LINUX_PM_STATE` with `mem_sleep_current`, then calls the same apply helper again.
- A non-zero `res.a0` is logged with `dev_warn` and turned into `-EIO`. Probe still returns 0 after that warning. `.prepare` ignores the apply result and returns 0, so a firmware rejection does not stop suspend.
- There is no `arm_smccc_1_1_get_conduit()` check.
- Kconfig is `bool`. The C file uses `module_platform_driver()`, `MODULE_LICENSE`, and `MODULE_DEVICE_TABLE`. It cannot be built as a module, but it is written like one. Registration is `device_initcall` via `module_init`, not the BSP `late_initcall_sync`.
- The YAML binding names Heiko Stuebner as maintainer. That is not evidence of an upstream submission.
- The new dt-bindings header copies the Rockchip sleep and wake bits as `(1 << n)` instead of `BIT()`. The values used by the Flip comment match the BSP header. The LDO-on bits from the BSP header are omitted.

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

## Verdict on the recovered `1013a/b`

| Old implementation | BSP 5.10 | BSP 6.1 | Stock | Linux 7.0.2 | Verdict |
| --- | --- | --- | --- | --- | --- |
| Compatible `rockchip,rk3568-suspend` | Not a match string | Not a match string | DTB uses `rockchip,pm-rk3568` | No driver | AI-INVENTED / NO EVIDENCE. The binding comment knows the vendor node and still invents this string. |
| Node name `rk3568-suspend` in the example and the Flip comment | `rockchip-suspend` | `rockchip-suspend` | `rockchip-suspend` | none | WRONG |
| Seven sleep bits in the header and the Flip comment | Same set, `0x5ec` | Same set | DTB `0x5ec` | no binding | CORRECT as values. Not, by itself, a measured Flip requirement. |
| Wake `RKPM_GPIO_WKUP_EN` | Default | Default | DTB `0x10` | none | CORRECT as the stock/BSP default |
| `sleep-debug-en` default 0 in the YAML | BSP dtsi uses `<1>` and `status = "disabled"` | Same | DTB `<1>` and `status = "okay"` | none | Differs from stock. Debug-off is a reasonable production default. |
| SMC `0x82000003`, subcommands `0x01` `0x02` `0x05` `0x09`, `a0` = function, `a1` = subcommand, `a2` = value | Same | Same | `sip_smc_set_suspend_mode` is in System.map | `ROCKCHIP_SIP_SUSPEND_MODE` exists; the four subcommands do not | CORRECT BUT SHOULD USE MAINLINE API |
| Probe sends mode, wake, and debug | Probe does this, plus extra optional calls | Probe does this | `pm_config_probe` exists | no driver | CORRECT for those three. The extra BSP calls are absent, which is appropriate. |
| `.prepare` sends `LINUX_PM_STATE` then resends mode, wake, and debug | `.prepare` sends state, then mode and wake. Debug is probe-only. | Same as 5.10 | `pm_config_prepare` exists; late callbacks do not | no driver | CORRECT for state, mode, and wake. Resending debug every time is extra, not wrong. |
| No second `rockchip_sip.c` | BSP has one | BSP has one | that image exports `sip_smc_set_suspend_mode` | `arm_smccc_smc()` already exists | CORRECT BUT SHOULD USE MAINLINE API |
| `bool` Kconfig, `module_platform_driver()` in the C file | `.prepare` omitted if `MODULE` | Module probe skips the per-state parse | initcall comes from `rockchip_pm_config` | n/a | INCOMPLETE. The intent is built-in, and the file is written as a module. `device_initcall` is earlier than BSP `late_initcall_sync`. |
| `res.a0` logged; probe returns 0 anyway; `.prepare` always returns 0 | `.prepare` ignores the return | Same pattern | unknown | PM-domain path checks the conduit first | INCOMPLETE. A rejection is visible and does not stop suspend. No conduit check. |
| No SLPPIN writes | Not in this path | Same | unknown | rk8xx already does it | CORRECT. Do not add a second writer. |
| YAML names an upstream maintainer and a placeholder example index `111111111111` | BSP binding is a `.txt` file | Same | DTB uses the vendor compatible | no YAML | AI-INVENTED / NO EVIDENCE as an upstream binding |

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

RK817 `005` (`fe127fad`, Jacob Cook) restamps the gauge across system sleep because the coulomb counter was wrong on an RG353M during charge. Those numbers are not Flip measurements. The Flip baseline is in the sleep-gauge section below. One charging interval counted about 22% more than a simple elapsed-current estimate, and the repeat did not. `005` stays unapplied.

## Recommended shape

One new patch. Do not re-enable `1013a/b` as they stand. The recovered driver already has the right SMC values, the right argument order, a probe send, and a `.prepare` resend that includes `LINUX_PM_STATE`. What it should not keep is the invented compatible, the module-shaped registration, the missing conduit check, and a `.prepare` that returns success after firmware rejects the call.

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
| 6F | Closure. The original dozens-of-cycles, USB, radio, standby-current, and DMC-scaling list is not the gate. See the closure section. |

6B logs belong to that image: SMC id, subcommand, two arguments, `res.a0`, the Linux sleep state, and the mode and wake masks. One line per call. Closure keeps those successful `dev_info` lines. They are the ABI trace the hardware test ran. Demoting them would be a different kernel. A later logging-only change can do that.

## Phase 6B implementation

Built, not hardware-accepted. The active node is `rockchip-suspend` / `rockchip,pm-rk3568` with `rockchip,sleep-mode-config` `0x5ec`, `rockchip,wakeup-config` `0x10`, and `rockchip,sleep-debug-en` 0. `vdd_logic` remains `regulator-on-in-suspend`.

The driver is `drivers/soc/rockchip/rockchip-pm-config.c`, `CONFIG_ROCKCHIP_PM_CONFIG=y`, registered with `builtin_platform_driver`. It reuses `ROCKCHIP_SIP_SUSPEND_MODE` and adds:

```text
ROCKCHIP_SIP_SUSPEND_MODE_CONFIG      0x01
ROCKCHIP_SIP_SUSPEND_WKUP_SOURCE      0x02
ROCKCHIP_SIP_SUSPEND_DEBUG_ENABLE     0x05
ROCKCHIP_SIP_SUSPEND_LINUX_PM_STATE   0x09
```

Probe checks `arm_smccc_1_1_get_conduit()` and fails before any call when the conduit is none. It then sends mode, wake, and debug. A rejected required call stays bound. `.prepare` retries `LINUX_PM_STATE`, mode, and wake, and returns `-EIO` if any raw `res.a0` is non-zero. Debug is not resent from `.prepare` and does not fail suspend. There is no resume callback and no RK817 SLPPIN write.

## Phase 6B hardware result and Phase 6C

Hardware-accepted on the installed image `zlyme-my355-20260928-ff92191bb51c.tar`, runtime `ff92191bb51c09174b42b7660e94f0f652bf6241`, kernel `Linux 7.0.2 #1 SMP PREEMPT Mon Sep 28 13:11:00 UTC 2026`. `/sys/power/mem_sleep` stayed `s2idle [deep]`.

The SSH-started suspend at 13:51:10 UTC resumed at 13:52:32 UTC. `.prepare` was:

```text
LINUX_PM_STATE ctrl=0x9 cfg1=0x3 sleep_state=3 res.a0=0
MODE           ctrl=0x1 cfg1=0x5ec            res.a0=0
WAKE           ctrl=0x2 cfg1=0x10             res.a0=0
```

A second `.prepare` about four seconds later returned the same three zeros. That suspend was `/usr/share/nextui/bin/suspend` from SSH. It did not run `PWR_sleepNow()`, so `pwr.resume_tick` stayed unset. NextUI treats a power press within 1000 ms of that timestamp as the wake press and ignores it. Without the timestamp, the wake press was a new power press and NextUI slept again. `zlyme-keylidmon` uses `POWER_RESUME_GUARD_MS` 1000 for the in-game path only. This duplicate is a test-method and userspace event-handling artifact. It is not a BL31 rejection, a kernel PM retry, or a firmware wake failure. Neither program was changed.

The later power-button session left eight `.prepare` triplets in the kernel log, at 442.61, 484.94, 504.56, 535.89, 552.28, 578.65, 602.24, and 616.25 seconds. Every one is `LINUX_PM_STATE` `cfg1=0x3` `res.a0=0`, mode `0x5ec` `res.a0=0`, and wake `0x10` `res.a0=0`. The shortest gap is 14.0 seconds. NextUI's log has six `Entering mem sleep` lines. Each says the platform suspend executable exited 0, then reinitializes audio. It does not contain `ignoring spurious power button press`. The log order is two menu sleeps, Doom, four menu sleeps, then Game Boy Color. The two kernel suspends that are not in that log sit in the Doom gap, which is the in-game path. There is no four-second pair like the SSH duplicate.

`/storage` (`mmcblk0p3`, exFAT) took a temporary file, read it back, and the file was removed. `/sys/class/devfreq/dmc` stayed `powersave` at 324 MHz before and after. `mali_kbase` stayed loaded and NextUI still reported `opengles2`. Wi-Fi reassociated to `TP-Link_E44F` and SSH returned. Each resume reinitialized the Realtek USB device after `xHC error in resume, USBSTS 0x401, Reinit`, and the MMC hosts retuned. Those lines are resume traffic, not a stuck fault. No `Oops`, `Call Trace`, hung task, or filesystem I/O error remained in the buffer. The Flip gamepad and the virtual `Microsoft X-Box 360 pad` were both present. Battery while charging moved from capacity 9 / `charge_now` 284832 to capacity 13 / `charge_now` 377024. That is the charger, not an RK817 `005` result.

`vdd_logic` was not switched to off-in-suspend in that test.

## Phase 6D hardware result

Hardware-accepted. Image `zlyme-my355-20260928-b709719aac5c.tar`, runtime `b709719aac5c5540394d0369e5e06981b8aa00bc`, SHA-256 `02cd1d769d146bb71d11631dcc649d0cdc5b041c0b202c93053ab324497332ba`. Kernel `Linux zlyme 7.0.2 #2 SMP PREEMPT Mon Sep 28 14:31:17 UTC 2026`. The only functional difference from Phase 6C is `vdd_logic` / RK817 `DCDC_REG1` `regulator-off-in-suspend`. `regulator-always-on` and `regulator-boot-on` remain. No suspend microvolt was added. Stock `miyoo355_20250527_0.dts` matches that DCDC1 suspend policy. Its suspend node is `rockchip,pm-rk3568`, sleep `0x5ec`, wake `0x10`, and `sleep-debug-en` 1. Zlyme keeps debug at 0.

The first unplugged power-button cycle on that kernel had one `.prepare` at 174.07 seconds and no second `.prepare`:

```text
LINUX_PM_STATE ctrl=0x9 cfg1=0x3 sleep_state=3 res.a0=0
MODE           ctrl=0x1 cfg1=0x5ec            res.a0=0
WAKE           ctrl=0x2 cfg1=0x10             res.a0=0
```

The maintainer repeated physical power-button suspend/resume after that and reports that those cycles worked. A later awake boot of the same kernel, uptime about 249 seconds, still showed the probe trio at `res.a0=0` and zero `.prepare` lines. The ring buffer therefore does not hold a total cycle count. On that boot `/storage` was mounted, `/sys/class/devfreq/dmc` was `powersave` at 324 MHz, `mali_kbase` was loaded, Wi-Fi was associated to `TP-Link_E44F`, and both `Miyoo Flip Gamepad` and `Microsoft X-Box 360 pad` were present. Battery was discharging at 68%. No standby current was measured. No `Oops`, `BUG`, panic, or filesystem I/O error was in that buffer. The `xHC error in resume, USBSTS 0x401, Reinit` line from Phase 6C is a recovering USB reinit, not by itself a 6D regression.

`dmc` still has `center-supply = <&vdd_logic>`. DCDC1 powers the center domain while the system is running. BL31 `ARMOFF_LOGOFF` restored it across these mem suspends. The DMC driver was not changed. Phase 6 later closed on this runtime. The closure section records the revised gate.

## Open items

- `System.map-5.10` and the 2025-05-27 DTB are not proven to be one image.
- Whether `PMIC_LP` and rk8xx `SLPPIN_SLP_FUN` double-program the RK817, or whether both are required, is unknown.
- The "vcc_3v3 off is confirmed" DTS comment was not re-measured here.
- UART2's role in Zlyme resume, as opposed to debug output, is not established. Stock leaves it disabled.
- Subcommand `0x05` (`SUSPEND_DEBUG_ENABLE`) returned `res.a0=0` at probe with value 0. A non-zero debug enable has not been tested.
- Standby current with `vdd_logic` off has not been measured.

BL31 v1.44 on this Flip accepts subcommands `0x01`, `0x02`, and `0x09`. Success on those calls was raw `res.a0=0`. `vdd_logic` off in mem suspend resumed.

## RK817 sleep gauge — `005` not applied

Source: `ROCKNIX/distribution` `fe127fad01f6006bea1734ebde87d1c02cc6d256`, `projects/ROCKNIX/packages/linux/patches/mainline-rockchip/005-power-supply-rk817-charger-correct-gauge-across-sleep.patch`, Jacob Cook, 2026-09-03. Disposition: no actionable Flip problem demonstrated. Not applied. `002` and `008` stay disabled. `001` stays applied as Zlyme `0003`.

The patch does not apply to Zlyme's tree. Its context edits `rk817_bat_relax_voltage_uv()`, which vanilla Linux 7.0.2 does not have. That function, `rk817_bat_ocv_recalibrate()`, `rk817_bat_voltage_uv()`, the `charger->bat_info` and `charger->relax_voltage_uv` fields, and `RK817_GAS_GAUGE_RELAX_VOL1_H` (`0x5a`) / `RELAX_VOL2_H` (`0x5c`) are added by ROCKNIX `002` at the same revision. `001` only changes the NVRAM ceiling from `10000` to `100000`.

| `005` name | Linux 7.0.2 | ROCKNIX `001` | ROCKNIX `002` |
| --- | --- | --- | --- |
| `charger->bat_info` | absent | no | adds the field |
| `rk817_bat_relax_voltage_uv()` | absent | no | adds it, one argument |
| `rk817_bat_ocv_recalibrate()` | absent | no | adds it |
| `charger->relax_voltage_uv` | absent | no | adds it |
| `rk817_bat_voltage_uv()` | absent | no | adds it |
| relax voltage register macros | absent | no | `0x5a` and `0x5c` |
| `slp_boottime`, `slp_charge_uah`, `slp_cur_ua`, `slp_charging` | absent | no | absent; `005` adds them |
| `rk817_bat_sleep_adjust()` | absent | no | absent; `005` adds it |
| `ADC_TO_CHARGE_UAH`, `CHARGE_TO_ADC`, `rk817_record_battery_nvram_values` | present | no | uses them |

Adopting `005` as published would require importing those `002` helpers. That is not "only `005`". `002`'s boot policy, 5% relax loop, and `VOLTAGE_BOOT` / `VOLTAGE_OCV` properties stay out unless a later task reviews them on their own.

What `005` is trying to do, from its own RG353M notes, not from a Flip trace: the coulomb counter was erratic across sleep while charging at about 1.4 A. One 15-minute sleep counted about 69% of a simple elapsed-current estimate, another about 139%, and a charge that finished during sleep could still show the pre-sleep percentage. At suspend it stores boottime, `charge_now_uah`, the absolute average current, and whether the charger was in CC/CV or trickle, and it clears `RK817_RELAX_VOL_UPD`. At resume it reads `Q_PRES`, derives SoC, and if a relax pair is latched it OCV-recalibrates and returns. Otherwise, if it slept while charging and is still plugged in, it treats `elapsed * pre-sleep current` as the expected charge, credits any shortfall, caps at full, writes `Q_INIT`, and saves NVRAM.

Risks if that idea is retargeted at the Flip:

- One pre-sleep current is not the current for the whole sleep. CV taper makes a constant-current estimate high. The patch says so and caps at full.
- A counter that over-counts is left alone (`expected_uah - moved_uah > 0` is the only elapsed-current credit). Only a shortfall is corrected, and only while charging. That fallback would not correct a charging-sleep over-count.
- Relax-pair correction depends on `002`'s voltage read and OCV helper. Zlyme does not have those.
- Writing `Q_INIT` and NVRAM on resume is a gauge state change. The following `rk817_read_props()` reads `Q_PRES`, not `Q_INIT`. If the gauge has not copied `Q_INIT` into `Q_PRES` before that read, the in-memory SoC written by `005` is replaced by the uncorrected counter.
- `001` clamps a saved SoC above 100000 on the next NVRAM read. It does not stop `005` from writing NVRAM.
- With `002` disabled, a later cold boot still follows vanilla `OFF_CNT >= 3`: SoC is replaced from `PWRON_VOL` and the OCV table. A resume NVRAM write does not change that boot path.
- The published ratios are RG353M charging sleeps. They are not Flip measurements, and they are not a discharging-sleep result.

Current Zlyme behavior is vanilla 7.0.2 plus `0002`, `0003`, and `0007`. None of those patches edit `rk817_suspend()` or `rk817_resume()`. Suspend cancels `rk817_charging_monitor`. It does not write `GG_STS`, `Q_INIT`, or NVRAM, and it does not clear relax flags. Resume queues that monitor immediately. The monitor reads `Q_PRES` into `charge_now_uah`, sets `soc` from that charge and `fcc_mah`, and updates voltage and current. It does not recompute an OCV SoC. The next monitor is 8 seconds later. The driver does not say whether the silicon coulomb counter keeps integrating while the system is suspended.

Baseline, run read-only on the installed Phase 6D image. Kernel `Linux zlyme 7.0.2 #2 SMP PREEMPT Mon Sep 28 14:31:17 UTC 2026`. No patch, no register write, no SSH suspend. The maintainer slept and woke with the power button. Times are monotonic `/proc/uptime`, because the RTC was wrong. Coulomb values use the driver's integer `ADC_TO_CHARGE_UAH` with `res_div = 1`: `adc / 3600 * 172`. `GG_STS` `RELAX_STS` is bit 1. `RK817_RELAX_VOL_UPD` is both bits of the field at `0x3 << 2`. Plug-in is `SYS_STS` bit 6.

Test A, unplugged. Uptime 709.80 s to 1712.77 s, **1002.97 s** between snapshots. That includes the awake moments around the button presses.

| Field | Before | After |
| --- | --- | --- |
| capacity | 65 | 64 |
| status | Discharging | Discharging |
| charge_now | 1946180 µAh | 1913672 µAh |
| voltage_avg | 3717090 µV | 3722760 µV |
| current_avg | −826116 µA | −851056 µA |
| GG_STS `0x57` | `01` | `0b` |
| RELAX_VOL1 / VOL2 | `00 00` / `00 00` | `d6 13` / `00 00` |
| Q_INIT `0x70–0x73` | `02 a1 db d0` | unchanged, 2109924 µAh |
| Q_PRES `0x74–0x77` | `02 6d 34 8d` | `02 63 1c 35` |
| SYS_STS `0xf0` | `82` | `82` |

`Q_PRES` went from 1944976 µAh to 1913328 µAh, **−31648 µAh**. `charge_now` fell 32508 µAh. Capacity fell one point. `Q_INIT` did not change. The plug-in bit stayed clear. `RELAX_STS` became set and the update field became 2, so only bit 3 is set. `RELAX_VOL2` stayed zero. That is not the full pair `RK817_RELAX_VOL_UPD` requires. Awake current was not used as expected sleep drain. The same 1003 seconds at the pre-sleep awake current would have been about 230 mAh. The counter moved about 32 mAh, in the discharge direction, with the visible percentage. That is not an implausible jump.

Test B, after A, charger connected and current settled near 1.02 A while capacity was 64% and terminal voltage was 4.004 V. Uptime 2002.04 s to 3016.29 s, **1014.25 s**.

| Field | Before | After |
| --- | --- | --- |
| capacity | 64 | 75 |
| status | Charging | Charging |
| charge_now | 1906620 µAh | 2259048 µAh |
| voltage_avg | 4003690 µV | 4171970 µV |
| current_avg | +1022024 µA | +1007920 µA |
| GG_STS `0x57` | `0b` | `09` |
| RELAX_VOL1 / VOL2 | `d6 13` / `00 00` | unchanged |
| Q_INIT | `02 a1 db d0` | unchanged |
| Q_PRES | `02 61 47 a3` | `02 d1 c2 67` |
| SYS_STS | `c0` | `c0` |

`Q_PRES` went from 1907652 µAh to 2259908 µAh, **+352256 µAh**. `charge_now` rose 352428 µAh. The plug-in bit stayed set. Status stayed `Charging`. Post-wake current was still about 1.01 A, so charging did not finish and did not fall into a deep taper. `RELAX_STS` cleared. The update field stayed 2, and no new relax pair appeared.

The constant-current comparison is diagnostic, not ground truth:

```text
expected = 1022024 µA * 1014.25 s / 3600 = 287941 µAh
ratio    = 352256 / 287941 = 1.22
```

The counter counted about 64 mAh more than that estimate, and the visible capacity rose 11 points against about 9.6 points on the same estimate. A taper would make this estimate high and the ratio low. This ratio is high while the current did not fall, so taper does not explain B1. Published `005` would not have changed this sample: its elapsed-current fallback credits only `expected_uah - moved_uah > 0`, and here the counter moved more than the estimate.

Test B2 is the repeat, on a later boot of the same kernel. Pre-sleep uptime was 128.99 s. Current had settled near 1.07 A at 71% and 4.172 V, still well above 0.8 A. Uptime 128.99 s to 1092.89 s, **963.90 s**.

| Field | Before | After |
| --- | --- | --- |
| capacity | 71 | 80 |
| status | Charging | Charging |
| charge_now | 2129876 µAh | 2412644 µAh |
| voltage_avg | 4172090 µV | 4227230 µV |
| current_avg | +1079988 µA | +979540 µA |
| GG_STS `0x57` | `01` | `01` |
| RELAX_VOL1 / VOL2 | `00 00` / `00 00` | unchanged |
| Q_INIT `0x70–0x73` | `02 a8 40 88` | unchanged, 2129876 µAh |
| Q_PRES `0x74–0x77` | `02 a8 b6 f5` | `03 02 eb 31` |
| SYS_STS `0xf0` | `c0` | `c0` |

`Q_PRES` went from 2131424 µAh to 2413848 µAh, **+282424 µAh**. `charge_now` rose 282768 µAh. Capacity rose 9 points. `Q_INIT` did not change. The plug-in bit stayed set. Status stayed `Charging`. Post-wake current was 0.98 A, so charging did not finish. `GG_STS` stayed `01`. No relax voltage and no full relax pair appeared.

```text
expected = 1079988 µA * 963.90 s / 3600 = 289167 µAh
ratio    = 282424 / 289167 = 0.98
```

| | B1 | B2 |
| --- | --- | --- |
| elapsed | 1014.25 s | 963.90 s |
| pre current | +1022024 µA | +1079988 µA |
| post current | +1007920 µA | +979540 µA |
| Q_PRES movement | +352256 µAh | +282424 µAh |
| simple estimate | +287941 µAh | +289167 µAh |
| ratio | 1.22 | 0.98 |
| capacity delta | +11 | +9 |
| charging after wake | yes | yes |
| full relax pair | no | no |

The estimate is `pre-sleep current_avg * elapsed` over the whole snapshot interval. That interval includes awake time before the power press and after wake. It uses the gauge's own averaged current, not an external coulomb meter. Charger current can move, and a taper makes the estimate high. B2's terminal voltage rose from 4.172 V to 4.227 V and current fell about 9%, from 1.08 A to 0.98 A, so this interval had started toward the charge voltage. Current was still near 1 A and the charge did not complete. B2's ratio of 0.98 sits inside that current change. B1's ratio of 1.22 did not repeat, and B2 did not substantially under-count.

Classification: **A. No actionable Flip problem demonstrated.** `005` stays unapplied. No Zlyme gauge change is justified. The published fallback still would not correct an over-count, and the patch still depends on helpers from disabled `002`.

## Phase 6 closure

**Phase 6 — COMPLETE.** Accepted runtime `b709719aac5c5540394d0369e5e06981b8aa00bc`. Image `zlyme-my355-20260928-b709719aac5c.tar`, SHA-256 `02cd1d769d146bb71d11631dcc649d0cdc5b041c0b202c93053ab324497332ba`. Kernel `Linux 7.0.2 #2 SMP PREEMPT Mon Sep 28 14:31:17 UTC 2026`. Commits after that runtime are documentation. No closing OTA was built.

The gate that closed the phase is: BSP-compatible `rockchip,pm-rk3568` configuration, BL31 acceptance of the SMC calls, Linux deep mem suspend and resume, `vdd_logic` off with `ARMOFF_LOGOFF`, repeated physical power-button cycles, NextUI and in-game suspend/resume, display, audio, and input recovery, healthy storage, networking able to recover, no serious kernel or filesystem failure attributable to deep suspend, and an explicit RK817 gauge disposition. Dozens of cycles, a USB attached/unattached matrix, a Wi-Fi/BT matrix, standby current, and DMC dynamic scaling are not blockers. DMC scaling is Phase 7. Standby current is power characterization. USB and Bluetooth matrices are extended regression coverage. None of those extended checks is claimed as done. Lid policy was not given its own deep-suspend test and is unchanged.

`CONFIG_ROCKCHIP_PM_CONFIG=y` stays. The module question is closed as keep built-in. Successful probe and `.prepare` `dev_info` lines stay, because that is the runtime the hardware accepted. DFI `1010` stays applied and is re-evaluated with the DMC module work in Phase 7. The ROCKNIX GPU power-domain change stays out. RK817 `0003` stays applied. `002` and `008` stay disabled. `005` stays unapplied. `0007` is unchanged. Phase 7 does not reopen the gauge.
