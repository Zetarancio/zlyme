# rk3568-dmc

`rk3568_dmc.ko` is the RK3566/RK3568 DDR devfreq driver. It changes DDR
frequency through the Rockchip ATF shared-memory SIP protocol. Zlyme uses
it on the Miyoo Flip. The module loads from the Device Tree modalias.
There is no `modules-load.d` entry and no init script that runs
`modprobe rk3568_dmc`.

## Device Tree node

The driver binds only to:

```dts
compatible = "rockchip,rk3568-dmc";
```

The node must provide:

| Property | Role |
| --- | --- |
| `compatible` | `rockchip,rk3568-dmc` |
| `devfreq-events` | Rockchip DFI devfreq-event provider used for DDR load |
| `clocks` | The DMC clock |
| `clock-names` | Must be `dmc_clk` |
| `operating-points-v2` | OPP table for rate, center voltage, and ATF filtering |
| `center-supply` | Regulator for the center / logic rail |
| `interrupts` | Completion interrupt for the ATF/DCF MCU frequency change |
| `interrupt-names` | Must be `complete` |

### `devfreq-events`

Must reference a Rockchip DFI devfreq-event provider. The driver reads
that provider with `devfreq-events` phandle 0 and uses the counters as
the `simple_ondemand` load. On Zlyme:

```dts
devfreq-events = <&dfi>;
```

### `clocks` and `clock-names`

One clock. The driver calls `devm_clk_get(dev, "dmc_clk")`, so
`clock-names` must be `dmc_clk`. On the Flip the clock is SCMI index 3:

```dts
clocks = <&scmi_clk 3>;
clock-names = "dmc_clk";
```

### `operating-points-v2`

Must point at the DMC OPP table. The module uses it to choose the
frequency, choose the center voltage, drop OPPs the ATF frequency info
does not support, and restore the boot frequency across suspend. On the
Flip:

```dts
operating-points-v2 = <&dmc_opp_table>;
```

### `center-supply`

Must be the regulator that supplies the center / logic voltage. The
driver calls `devm_regulator_get(dev, "center")`, which is the
`center-supply` property, and raises or lowers that voltage around a
DDR frequency change so the rail is never below the OPP for the rate
being entered. On the Flip:

```dts
center-supply = <&vdd_logic>;
```

### `interrupts` and `interrupt-names`

One level-triggered completion interrupt. The driver calls
`platform_get_irq_byname(..., "complete")`, so `interrupt-names` must
be `complete`. It maps that IRQ to its hardware number and writes the
number into the ATF shared page. On the Flip:

```dts
interrupts = <GIC_SPI 10 IRQ_TYPE_LEVEL_HIGH>;
interrupt-names = "complete";
```

## Miyoo Flip integration

This is the current Flip node, not a requirement that every RK3568
board use these phandles or these rates:

```dts
dmc: dmc {
    compatible = "rockchip,rk3568-dmc";
    interrupts = <GIC_SPI 10 IRQ_TYPE_LEVEL_HIGH>;
    interrupt-names = "complete";
    devfreq-events = <&dfi>;
    center-supply = <&vdd_logic>;
    clocks = <&scmi_clk 3>;
    clock-names = "dmc_clk";
    operating-points-v2 = <&dmc_opp_table>;
    status = "okay";
};
```

The Flip OPP table is 324, 528, 780, and 1056 MHz, each at 900000 µV.
Those four rates and that voltage are the Flip integration. Another
RK3568 board can use a different OPP set if its ATF accepts it.

## ATF

Device Tree is not enough. The module refuses to probe unless the DDR
SIP API reports version `0x101` or newer. It uses:

- `ROCKCHIP_SIP_DRAM_FREQ` for the DRAM service
- `SIP_SHARE_MEM` to obtain the shared page
- shared DDR page 2
- `DRAM_INIT`
- `DRAM_SET_RATE`
- `DRAM_GET_VERSION`
- `DRAM_GET_FREQ_INFO`
- `MCU_START`
- `POST_SET_RATE`

The six RK3568 V2 values that stock Linux 7.0.2 does not put in
`rockchip_sip.h` are defined in this module. The DRAM service ID and
the ordinary `DRAM_INIT` / `DRAM_SET_RATE` subcommands come from that
header.

## DFI

Load accounting needs the in-tree Rockchip DFI devfreq-event driver.
Zlyme keeps `CONFIG_PM_DEVFREQ_EVENT=y`,
`CONFIG_DEVFREQ_EVENT_ROCKCHIP_DFI=y`, and
`1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch`. Phase 7B
does not remove that dependency.

## Binding patch

Zlyme still carries
`1012a-dt-bindings-memory-controllers-rockchip-rk3568-dmc.patch`. That
patch is the kernel-tree schema for `rockchip,rk3568-dmc`. This README
is the integration note for the external module. It does not replace
schema validation.

## Suspend

System suspend is part of the driver contract. Before suspend the
module returns DDR to the boot rate and sets the ATF self-refresh flag
the resume firmware expects. After resume it rereads the DMC clock and
primes the DFI counters so `simple_ondemand` can scale back down
instead of treating an empty counter as load.
