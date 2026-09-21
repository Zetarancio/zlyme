# Zlyme roadmap and sequencing

This roadmap is ordered to minimize overlapping variables during hardware bring-up.

The Miyoo Flip (`my355`) remains the only supported device.

## Rule for every phase

Before starting a phase:

1. begin from a known-good commit;
2. record the relevant baseline;
3. make one architectural change at a time;
4. build;
5. run the phase-specific Miyoo Flip smoke test;
6. commit the known-good state before starting the next phase.

Do not ask an agent to execute this entire roadmap in one pass.

## 0 — Repository/context refactor and baseline

Goals:

- add `AGENTS.md` and canonical docs;
- split `NOTES/` by responsibility;
- make `my355` target identity explicit;
- move board-only Linux/U-Boot hooks into `board/my355/board.mk`;
- introduce immutable device metadata;
- preserve runtime behavior.

This should be primarily structural.

### Gate

Before phase 1:

- both my355 defconfigs configure;
- full image builds;
- image boots;
- NextUI reaches first frame;
- normal controls/audio/storage work;
- standard suspend/resume works;
- update status/verification still works.

Record a baseline first-frame boot time and a short device smoke log.

## 1 — Application-scoped Weston/WestonPack support

Goal:

Support software that needs Wayland/X11 without changing Zlyme's normal compositor-free architecture.

Architecture:

```text
normal:
NextUI -> SDL/KMSDRM -> DRM/KMS

compat app:
NextUI releases DRM
  -> temporary Weston
  -> native Wayland and/or Xwayland client
  -> app exits
  -> Weston exits
  -> NextUI reacquires DRM
```

Start with the smallest tracer bullet:

```text
launch Weston -> render one test client -> exit -> recover NextUI
```

Then test:
- a PortMaster title that requires Weston/X11;
- Wine graphical smoke test;
- Xwayland fallback if needed.

Do not make Weston a boot service.

### Gate

Repeatedly pass:

```text
NextUI -> Weston app -> NextUI -> Weston app -> NextUI
```

with correct input/audio/DRM cleanup.

## 2 — Audit kernel patch inventory

Before rewriting kernel-facing components, classify every current patch:

```text
A: required for Miyoo Flip
B: RK3566/RK3568 reusable
C: upstream/backport still required by selected kernel
D: irrelevant inherited device patch
E: historical/debug-only
F: candidate for external module
```

Do not delete everything in one commit.

The current `20-rk3566` directory visibly contains inherited Anbernic/Powkiddy/touchscreen patches that deserve classification because Zlyme supports only my355.

Remove category D/E patches in small groups with a build and device smoke test after each logical family.

This phase creates a cleaner kernel baseline for the new input driver and power work.

## 3 — Rewrite the Miyoo Flip joypad driver as an out-of-tree module

Do this **before making InputPlumber the default**.

Reason:

InputPlumber consumes the Linux input ABI produced by the low-level drivers. If the joypad rewrite changes:
- device names;
- event split;
- axes;
- calibration;
- rumble;
- capabilities;
- suspend behavior,

an InputPlumber profile written first would need to be rewritten.

### Design target

Kernel driver owns mechanism:
- Miyoo UART1 protocol;
- GPIO button input if intentionally combined there;
- analog axes;
- force feedback / rumble;
- hardware calibration mechanism;
- suspend/resume.

Userspace owns input policy.

Prefer standard kernel interfaces such as serdev where they genuinely simplify UART ownership, but do not force a framework if it makes the driver less clear.

### Migration strategy

Keep the old `rocknix-joypad` package available as a temporary build-time fallback until the replacement is proven.

Do not run two drivers against the same UART/GPIO resources simultaneously.

### Gate

Test:
- every button;
- both analog sticks and full ranges;
- calibration persistence;
- L3/R3;
- rumble;
- device naming/capabilities;
- repeated module load/unload if supported;
- standard suspend/resume;
- game launch/exit;
- external controller coexistence.

Only then remove the old driver.

## 4 — Introduce InputPlumber as the input-policy layer

This is an intentional Zlyme design choice relative to the archived Miyoo Flip ROCKNIX implementation, which did not use InputPlumber for the Flip. Do not infer the current official ROCKNIX state without fresh research.

The previous Zlyme research correctly concluded that InputPlumber was unnecessary merely to fix Nintendo controller support. That remains true: vendor HID drivers such as `hid-nintendo` solve vendor report-mode problems.

Adopt InputPlumber only for the larger policy goal:

- stable virtual P1;
- built-in + external controller composition;
- exclusive grabs when useful;
- consistent mapping;
- hotplug policy;
- decoupling frontend/emulators from physical event ordering.

### Start optional

First package it and run it experimentally.

Do not immediately make it a hard first-frame dependency.

Measure:
- process RSS;
- startup time;
- CPU wakeups;
- controller hotplug latency.

If NextUI eventually consumes only the virtual InputPlumber controller, InputPlumber becomes Class A and must have a strict startup budget.

### Gate

Test:
- built-in controller;
- Switch Pro with `hid-nintendo`;
- DualShock/DualSense if available;
- controller connect/disconnect during frontend;
- controller connect/disconnect during game;
- suspend/resume;
- hotkey ownership;
- no duplicate inputs;
- deterministic P1 assignment.

## 5 — Kernel patch reduction pass

After the input transition, remove patches made obsolete by:
- the new joypad module;
- newer upstream kernel code;
- no-longer-supported devices.

For every patch, record one of:

```text
KEEP — required and why
UPSTREAMED — remove, with upstream commit/version
MODULE — functionality moved to external module
DROP — irrelevant to my355
DEBUG — keep only in debug profile, or delete
```

This should leave a small explainable my355 kernel delta.

## 6 — Deep suspend bring-up

The device wiki establishes:

- standard suspend already works;
- deep suspend is a separate BL31/SIP configuration feature;
- `vdd_logic` off-in-suspend is unsafe without `ARMOFF_LOGOFF`;
- the archived Miyoo Flip ROCKNIX implementation deferred deep suspend because of an EmulationStation UX blocker.

That was an implementation-level blocker, not a hardware limitation. Zlyme uses NextUI rather than EmulationStation, so the historical ROCKNIX blocker does **not automatically apply**. Zlyme still needs its own lifecycle validation.

### Do not combine two experiments initially

First bring up deep suspend using the known working implementation shape from the hardware research.

Do not simultaneously:
- rewrite the driver as a module;
- change BL31;
- change DMC implementation;
- change input policy.

Prove deep suspend first.

### Module question

The documented rk3568-suspend implementation uses a `bool` Kconfig and early/late kernel init integration. Converting it into an external loadable module is a separate refactor.

After built-in deep suspend is proven on Zlyme, evaluate whether module semantics are safe and worthwhile.

### Gate

Test:
- power-button/lid policy;
- at least dozens of suspend/resume cycles;
- USB host attached/unattached;
- Wi-Fi/BT on/off;
- audio after resume;
- input after resume;
- DMC scaling after resume;
- NextUI first frame after resume;
- standby current;
- no filesystem corruption.

Only enable `vdd_logic` off-in-suspend together with the correct BL31 `ARMOFF_LOGOFF` configuration.

## 7 — DMC driver modularization / patch extraction

Important: the current Zlyme `rk3568_dmc` patch already defines:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ
```

as `tristate`, and the driver already uses `module_platform_driver()`.

Therefore separate two goals:

### 7A — build it as a module

Change:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ=y
```

to:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ=m
```

while keeping the source-injection patch.

Validate module load timing, devfreq availability, suspend/resume, and gaming profiles.

This is the smaller experiment.

### 7B — stop injecting the driver through a kernel patch

Only after 7A is proven, move the driver source into a Buildroot out-of-tree kernel-module package, for example:

```text
package/drivers/rk3568-dmc/
```

The external module must be self-contained with respect to the V2 SIP constants it needs.

This can potentially remove the patch that adds the driver/Kconfig/Makefile entries to the kernel tree.

It does **not** automatically remove the DFI PM patch (`1010`), because that patch modifies the existing in-tree `rockchip-dfi` driver.

The DTS/binding situation should be reviewed separately; runtime functionality does not require every documentation binding patch to remain if no in-tree code consumes it.

### Gate

Test:
- module autoload/probe;
- available DMC frequencies;
- dynamic scaling;
- governor switching;
- performance profile forcing;
- suspend/resume;
- deep suspend if phase 6 is enabled;
- module unload only if explicitly supported and safe.

## 8 — NextUI optimization

Do this after graphics compatibility and input architecture have stabilized so you do not optimize code that will immediately be rewritten.

Profile before modifying.

Areas to measure:
- time from `exec` to first flip;
- ROM/library scanning;
- image/font loading;
- filesystem reads;
- redraw frequency;
- SDL event handling;
- settings startup;
- allocations;
- logging;
- controller enumeration;
- suspend/resume lifecycle.

Do not treat `-O3`/`-Ofast` as a substitute for profiling.

Prioritize architectural/runtime wins over compiler flag churn.

### Gate

Compare before/after:
- first flip;
- menu frame time;
- input latency;
- RSS;
- CPU usage while idle;
- battery/power impact.

## 9 — Delete unused files

Correctly last.

After the migrations are stable:

- search all references;
- include build-time/generated references;
- inspect package install commands;
- inspect scripts/CI/docs;
- remove dead assets/tools/packages;
- build from a clean output tree.

"Not referenced by grep" alone is not proof of unused Buildroot content.

## Suggested commit/checkpoint rhythm

Use separate known-good checkpoints such as:

```text
docs/refactor
device-boundary
weston-runtime
kernel-patch-prune-1
joypad-driver
inputplumber-optional
inputplumber-default
kernel-patch-prune-2
deep-suspend
dmc-as-module
dmc-external-module
nextui-profile
nextui-optimize
dead-file-cleanup
```

Names are illustrative; the important part is one reason per checkpoint.
