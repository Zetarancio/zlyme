# Zlyme roadmap and sequencing

This roadmap is ordered to minimize overlapping variables during hardware bring-up.

The Miyoo Flip (`my355`) remains the only supported device.

`ROADMAP.md` is sequencing guidance, not the current architecture specification. Current architecture and invariants live in `AGENTS.md` and the canonical documents under `docs/`.

## Rule for every phase

Before starting a phase:

1. begin from a known-good commit;
2. record the relevant baseline;
3. read the canonical docs required by `AGENTS.md`;
4. separate research from production changes;
5. make one architectural change at a time;
6. run the narrowest useful build/check first;
7. run the phase-specific Miyoo Flip smoke test when runtime behavior changes;
8. commit the known-good state before starting the next phase.

Do not ask an agent to execute this entire roadmap in one pass.

Do not turn discovery in one phase into implementation of a later phase.

## External evidence and upstream intake

Zlyme is not a downstream synchronization project.

Use external projects to reduce uncertainty, not to replace Zlyme's own architecture decisions.

Source-of-truth order for roadmap work:

1. **Zlyme repository** — authoritative for current Zlyme implementation and policy.
2. **Miyoo Flip hardware wiki** (`Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`) — primary device/hardware evidence.
3. **Selected Linux kernel and upstream Linux history** — authoritative for whether kernel behavior is already upstream, backported, changed, or obsolete for the selected kernel.
4. **Current official ROCKNIX `next` and other distributions** — current comparison and implementation evidence, not authority for Zlyme behavior.
5. **Archived Zetarancio ROCKNIX fork and historical notes** — historical evidence only.

For external kernel code or patches:

- pin the exact source commit or patch revision used for comparison;
- preserve authorship, provenance, copyright, and license notices;
- prefer an upstream/mainline implementation when it is applicable and semantically equivalent;
- do not assume a newer downstream patch is better merely because it is newer;
- understand the failure mode and mechanism before adopting a workaround;
- compare external behavior against the Miyoo Flip hardware evidence and Zlyme's selected kernel;
- keep only the smallest Zlyme delta that remains necessary;
- do not merge or synchronize another distribution wholesale;
- do not import unrelated userspace/package changes during a kernel phase.

When research finds useful work outside the active phase, record it for the appropriate later phase or backlog instead of implementing it immediately.

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

### Status

Complete, 2026-09-22. Both my355 defconfigs configure, and the product image was built from a clean `output/` through `./build.sh --config zlyme_my355_defconfig`. The etched card booted to NextUI. Smoke notes are in `docs/LOGBOOK.md` (2026-09-22).

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

### Status

Complete, 2026-09-23. Native application-scoped Weston recovered NextUI repeatedly on both Panfrost/Mesa and libmali. PortMaster Alex the Allegator 2 ran through WestonPack and Xwayland, was visible, and answered controls. Normal exit and MENU+START returned to NextUI on both GPU stacks, with no permanent Weston, `seatd`, or Xwayland left behind. On Panfrost, WestonPack used `card0` for KMS and `renderD128` for Mesa. Wine 11 under Box64 showed PuTTY through native `winewayland.drv` and Zlyme's temporary Weston, not WestonPack, on both stacks, including normal exit, relaunch, and MENU+START. Notes are in `docs/LOGBOOK.md`.

## 2 — Refresh upstream evidence and audit the kernel patch inventory

Goal:

Create a small, current, explainable kernel delta for the Miyoo Flip before rewriting input or power-facing components.

Phase 2 is not "update from ROCKNIX". It is an evidence-driven audit of Zlyme's current kernel baseline using the current selected Linux kernel, current upstream history, the hardware wiki, and current external implementations.

Baseline for Phase 2:

```text
main after Phase 1:
56cc4c38c5189b96e724c9227d69e6b92203339d
```

If `main` changes before Phase 2 begins, record the actual starting SHA instead of silently using this historical value.

### 2A — Refresh upstream evidence

This substage is research-only.

Do not modify kernel patches, DTS, kernel configuration, U-Boot, BL31, drivers, or runtime behavior during 2A.

Create or update a focused research document, preferably:

```text
docs/research/kernel-patch-audit.md
```

Record exact revisions for:

- current Zlyme `main`;
- Zlyme's selected Linux version/tree;
- current official `ROCKNIX/distribution` `next`;
- the Miyoo Flip hardware wiki revision used;
- the archived Zetarancio ROCKNIX fork only where historical comparison is useful.

Review external changes since the last recorded comparison, but filter them to plausible Miyoo Flip relevance. Do not manually review unrelated distribution churn merely because it is newer.

At minimum search for changes involving:

```text
my355 / Miyoo Flip
RK3566 / RK3568
RK817
power-off / shutdown / battery / fuel gauge
suspend / resume / wake
regulators / power domains / clocks
GPU / Panfrost / Mali / runtime PM
DMC / devfreq / DFI / SIP
joypad / input / UART / GPIO
USB host / PHY / Type-C where relevant
SD / MMC / shared vqmmc
Wi-Fi / Bluetooth power and suspend interactions
DTS / bindings used by the Flip
kernel-version changes that make Zlyme patches upstream or obsolete
```

For every relevant external candidate, record:

| Field | Required evidence |
| --- | --- |
| Candidate | concise description |
| Source | repository + exact commit/patch revision |
| Subsystem | kernel area affected |
| my355 relevance | yes / no / uncertain, with reason |
| Zlyme overlap | exact Zlyme patch/file or `none` |
| Selected-kernel status | upstream / backport / downstream-only / obsolete / uncertain |
| Hardware evidence | what is known specifically on Miyoo Flip |
| Architectural owner | Phase 2 / 3 / 6 / 7 / future / ignore |
| Recommendation | compare / adopt / replace / keep current / defer / ignore |
| Validation needed | build/config/device evidence required |

The recommendation is not permission to implement a later-phase feature.

Examples of deferral:

- joypad architecture changes belong to Phase 3;
- InputPlumber policy belongs to Phase 4;
- deep-suspend enablement belongs to Phase 6;
- DMC modularization/extraction belongs to Phase 7.

A Phase-2 candidate may be implemented later in Phase 2 only if it is a kernel-baseline correctness fix or a direct replacement/removal of an existing Zlyme patch and does not start one of those later architectural changes.

#### 2A checkpoint

Stop after producing the evidence matrix.

Review the findings before changing the kernel patch stack.

The 2A checkpoint must answer:

- which Zlyme patches may already be upstream;
- which current patches overlap newer external work;
- which external fixes are relevant to current my355 correctness;
- which findings belong to later roadmap phases;
- which external changes are irrelevant to Zlyme.

### 2B — Classify every current Zlyme kernel patch

After 2A is reviewed, inventory every currently applied Linux patch in order.

Classify each patch:

```text
A: required specifically for Miyoo Flip
B: reusable RK3566/RK3568 platform fix still required by the selected kernel
C: upstream/backport still required by the selected kernel
D: irrelevant inherited device patch
E: historical/debug-only
F: candidate for external module or later architectural extraction
```

For each patch record:

```text
path/order
purpose
original reason
affected subsystem
my355 dependency
external/upstream equivalent, if any
classification
KEEP / REPLACE / REMOVE / DEFER decision
validation needed
```

Do not classify a patch from filename alone.

Read the patch and inspect the selected kernel source it modifies.

The current `20-rk3566` directory contains inherited device-specific material; determine applicability from code and hardware evidence rather than assuming that every RK3566 patch belongs on my355.

### 2C — Apply only the kernel-baseline decisions that belong to Phase 2

After the inventory is reviewed:

- remove category D/E patches in small logical families;
- remove category C patches only when the selected kernel already contains the required behavior;
- replace a current patch with a better upstream/current implementation only after comparing semantics;
- adopt a newly discovered baseline correctness fix only when it is clearly relevant to current my355 behavior and does not start a later roadmap phase;
- preserve provenance when importing external code;
- do not rewrite the joypad driver here;
- do not enable deep suspend here;
- do not modularize/extract DMC here;
- do not introduce InputPlumber here.

One conceptual reason per commit.

After each logical patch family:

1. regenerate/verify kernel configuration if relevant;
2. build the kernel or affected image;
3. boot on Miyoo Flip when runtime behavior changed;
4. run a smoke test appropriate to the subsystem;
5. inspect logs for new warnings/regressions;
6. commit the known-good state before the next family.

### Phase 2 gate

Phase 2 is complete only when:

- the current external/upstream evidence snapshot is pinned and documented;
- every active Zlyme kernel patch has an explicit classification and disposition;
- irrelevant/historical patches selected for removal are gone;
- any Phase-2 replacements are documented with provenance;
- later-phase findings are deferred rather than partially implemented;
- both my355 defconfigs still configure;
- the full product image builds from the resulting baseline;
- the image boots on Miyoo Flip;
- NextUI reaches first frame;
- normal display/input/audio/storage still work;
- standard suspend/resume still works;
- Panfrost/libmali selection still behaves as expected if touched;
- no new kernel warnings attributable to the audit remain unexplained;
- `docs/LOGBOOK.md`, `docs/research/kernel-patch-audit.md`, and any canonical docs affected by actual decisions are updated.

The result should be a cleaner kernel baseline, not the smallest possible patch count at any cost.

### Status

Complete, 2026-09-23. 2A evidence is `8984f6106c99f89bde214a3beeec3ee4bc175ba7`. 2B classification is in `docs/research/kernel-patch-audit.md`. 2C removed the foreign-board, unused-driver, perf-Rust, inert-initramfs, and unused RK3568 OTP patches. The OTP-removal image booted on the Flip: NextUI, display, controls, audio, Wi-Fi, and standard suspend/resume passed, with no OTP provider left. Eighteen Linux patches remain. Joypad architecture stays in Phase 3. DFI `1010` stays in Phase 6. DMC `1012a`/`1012b` stays in Phase 7.

## 3 — Rebuild the Miyoo Flip gamepad stack around the actual hardware

Do this **before making InputPlumber the default**.

Phase 2 deliberately preserved the current joypad implementation and its supporting kernel patches so Phase 3 can redesign the input mechanism against a known-good kernel baseline.

The goal is not to rename or incrementally clean up the existing `rocknix-joypad` integration.

The goal is to establish the Miyoo Flip's actual gamepad hardware boundary, then implement the smallest clear Zlyme driver around that hardware.

The new implementation should not carry distribution branding in its driver, device-tree compatible, input-device name, or public ABI.

If implementation code is reused from ROCKNIX, stock Miyoo sources, Linux, or another external project, preserve the applicable authorship, provenance, copyright, and license information. A new architecture does not erase provenance for copied code.

### Current evidence

The built-in gamepad currently combines several mechanisms:

* face buttons, d-pad, shoulders, triggers, MENU, and stick-click buttons are GPIO-backed;
* analog-stick values reach the RK3566 over UART1;
* stock Miyoo software configures that UART as 9600 8N1;
* the observed stock analog frame is six bytes:

```text
FF YL XL YR XR FE
```

* stock software separately reads buttons through `/dev/miyooio`;
* stock calibration stores per-stick minimum, maximum, and center values;
* Zlyme currently combines GPIO buttons, UART axes, calibration, and PWM rumble into one Linux input device through the inherited joypad driver.

The current implementation also carries architecture that is not naturally specific to the Flip, including generic ADC support, input polling, direct `/dev/ttyS1` access from kernel space, delayed initialization, a serial kthread, custom calibration sysfs, and coupling to a patched `adc-keys` global input pointer.

Phase 3 should not assume those mechanisms are the correct final design.

### Replacement-stick evidence

Multiple users have fitted standard Nintendo Switch 1 non-Hall-effect potentiometer stick modules to the Miyoo Flip and reported that they work under the stock Miyoo OS.

Treat this as evidence that the Flip's physical analog-stick modules are likely mechanically and electrically compatible with the standard Switch 1 potentiometer-stick family, possibly using the same component family or a compatible clone.

Do **not** infer Nintendo HID protocol compatibility from physical stick compatibility.

Phase 3A did not identify the part between the potentiometers and UART1. The RK3566 is the receiver. The sender is not a Joy-Con HID device. `hid-nintendo`, Switchroot Joy-Con parsing, and `adc-joystick` do not apply to this frame. One driver and one protocol cover original modules and Switch 1 non-Hall replacements. Only the observed minimum, center, maximum, and noise change.

Designed compatibility is not hardware-validated compatibility. Phase 3B does not wait for replacement modules. Phase 3D does not call them validated until the community protocol passes.

### Linux input ABI

The physical device should expose standard Linux gamepad semantics.

Expected capabilities include, as applicable:

```text
BTN_SOUTH
BTN_EAST
BTN_NORTH
BTN_WEST
BTN_DPAD_UP
BTN_DPAD_DOWN
BTN_DPAD_LEFT
BTN_DPAD_RIGHT
BTN_TL
BTN_TR
BTN_TL2
BTN_TR2
BTN_THUMBL
BTN_THUMBR
BTN_SELECT
BTN_START
BTN_MODE

ABS_X
ABS_Y
ABS_RX
ABS_RY

FF_RUMBLE
```

Use positional Linux button semantics rather than encoding printed A/B/X/Y labels into the kernel ABI.

The physical driver must represent the actual Miyoo Flip hardware.

Do not identify it as an Xbox, Xbox 360, Nintendo Switch, or other unrelated commercial controller solely for application compatibility.

If a later userspace policy layer benefits from exposing a virtual Xbox-compatible controller, that belongs to Phase 4 and InputPlumber, not to the physical kernel driver.

Volume, lid, and PMIC power-key devices remain separate from the gamepad.

### Architectural preference

Research should evaluate rather than assume the final structure, but the preferred target is currently:

```text
Miyoo Flip gamepad
  |
  +-- UART1 / serdev
  |     `-- analog frame parser
  |
  +-- gamepad GPIO inputs
  |     `-- interrupt/event driven where hardware permits
  |
  +-- calibration transform
  |
  +-- PWM5
  |     `-- FF_RUMBLE
  |
  +-- suspend/resume
  |
  `-- one standard Linux input_dev
```

One Linux input device for the physically integrated handheld gamepad is not inherently problematic merely because it reports many buttons.

The architectural question is whether one driver can own those resources with clear boundaries and lower complexity than exposing several physical input devices and relying on userspace aggregation before Phase 4.

Phase 3A selected that shape. Linux 7.0.2 models the analog path as a `serdev` child of UART1 at 9600 8N1. Phase 3B proved interrupt-driven GPIO on all seventeen gamepad lines, including press and release. The observed ~66.8 Hz rate is the analog sender delivering UART frames. It is not a button poll. The old driver polled GPIOs every 6 ms. Those are different mechanisms.

The 3B tracer keeps the current UART1 pinmux, including `uart1m0_ctsn`, and the current DMA setup. Stock userspace disables hardware flow control, and the stock DTB still muxes CTS and describes DMA. Those are not the same fact. Dropping either is a later experiment, not part of the driver replacement.

SARADC stays enabled through the initial Phase 3 work. The stick axes are UART. Unused-ADC cleanup is Phase 5 unless the new node actually conflicts with it.

### Calibration boundary

Calibration is normal. The potentiometer modules vary from unit to unit, and Switch 1 non-Hall replacements are a designed target for the same UART protocol. Do not treat stock raw defaults as universal, and do not assume four axes share one range.

```text
persistent, independently per axis:  min, zero, and max
boot:                                 a fresh center when the sticks are still
```

Userspace owns the full-range procedure, the files under `/storage`, the UI, and restore/apply policy. The kernel owns UART decoding, the runtime transform, deadzone/noise handling, and standard `ABS_*` output. The kernel must not open persistent files. A small sysfs attribute is enough. Do not add a character device for calibration.

Boot-center collection starts only after the input device exists. It uses an outlier-resistant estimate and accepts a center only from a stable cluster. An accepted center is used for that boot and must not rewrite the persistent file. If the samples are moving, keep the persisted zero. If no valid persisted calibration exists, keep a conservative compiled default zero. No infinite wait, no delayed probe, and no calibration loop inside `probe`. Buttons stay available if UART never produces a frame.

The full calibration application still captures `x_min`, `x_zero`, `x_max`, `y_min`, `y_zero`, and `y_max` independently for each stick, including asymmetric travel. A narrow diagnostic report of raw bytes, observed extrema, center, active calibration, normalized axes, and frame errors is part of 3C/3D. It is not a permanent broad debug ABI.

Missing, corrupt, or unexpected UART data must not block probe, button registration, NextUI, boot, or suspend/resume. Axes may degrade on their own. Parsing resumes when valid frames return.

### 3A — Hardware, protocol, and ABI research

This substage is research-only.

Do not modify the production driver, DTS, kernel patches, or userspace input policy.

Establish:

* complete current Zlyme gamepad dependency graph;
* stock Miyoo button and analog architecture;
* UART1 protocol and line configuration;
* hardware between the physical sticks and UART1 as far as evidence permits;
* GPIO ownership and IRQ feasibility;
* UART DMA/CTS requirements;
* rumble hardware;
* suspend/resume requirements;
* calibration behavior;
* current synthetic or inherited input identity values;
* applicability of `serdev`;
* applicability of `hid-nintendo`, Switchroot Joy-Con support, `adc-joystick`, and other upstream Linux drivers;
* implications of successful Nintendo Switch stick replacements;
* likely causes and limitations of the historical modified-stick/ROCKNIX black-screen report;
* one-driver versus split-device architecture.

Use the Zlyme repository as authority for current implementation, the Miyoo Flip hardware wiki and stock artifacts as primary hardware evidence, and upstream Linux as the authority for Linux interfaces and driver patterns.

Do not expose additional stock NAND partitions merely for exploratory research while equivalent evidence exists in saved stock images, binaries, source fragments, logs, or an intact stock OS.

#### 3A checkpoint

The evidence report is `docs/research/joypad-driver.md`.

It records the hardware boundary, UART/`serdev` transport, GPIO model, one-`input_dev` topology, truthful Miyoo identity, calibration split, PWM rumble, the DTS contract, the cutover list, and the measurements that still need a tracer or a scope.

### Status

Phase 3A complete, 2026-09-23. Phase 3B complete, 2026-09-23, on `phase-3-gamepad`. Phase 3C has not started.

### 3B — Minimal new-driver tracer

After 3A is reviewed, create the new Zlyme gamepad implementation as an out-of-tree kernel module.

Use a Miyoo/Zlyme hardware name rather than distribution branding, for example:

```text
miyoo-flip-gamepad
miyoo,flip-gamepad
Miyoo Flip Gamepad
```

Exact names should follow the conclusion of 3A.

Start with the narrowest useful tracer.

At minimum prove:

```text
module loads
hardware resources bind
UART frames are received and parsed
GPIO buttons report
one Linux input device appears
axes report stable values
module unload/cleanup is correct if unload is supported
buttons still report when UART is silent
```

Treat every gamepad GPIO IRQ as unproven until that tracer shows request, polarity, debounce, and press/release. Do not wait for Switch replacement sticks before this tracer. Do not change UART CTS pinmux or DMA in the same step.

Do not implement every calibration or compatibility feature before proving the resource model.

Keep the existing driver available as a **mutually exclusive build-time fallback**.

Never bind the old and new drivers to the same UART, GPIO, or PWM resources simultaneously.

#### 3B result

Hardware-validated on the zlyme41 tracer image. The module is `miyoo_flip_gamepad`, compatible `miyoo,flip-gamepad`, input name `Miyoo Flip Gamepad`, `BUS_HOST`, vendor/product/version 0. The old `rocknix-singleadc-joypad` module stayed on disk and was not loaded or bound.

UART was 9600 8N1, frame `FF YL XL YR XR FE`, about 66.8 valid frames per second, and 0 bad frames in the final test. An untouched boot accepted centers YL 139, XL 103, YR 138, XR 112, each after the 1.5 s settle and two confirming windows. Resting normalized axes stayed at 0.

Directed original-stick extrema, diagnostics only:

```text
YL 25 / 139 / 239
XL 2 / 103 / 223
YR 49 / 138 / 226
XR 17 / 112 / 203
```

Fallback 85/200 does not describe those ranges. Signs match the Linux gamepad convention: negative is left/up, positive is right/down. All seventeen `BTN_*` lines, including `BTN_DPAD_*`, passed press and release. No keyboard arrows and no autorepeat. The 10 ms debounce kept extra GPIO edges out of evdev. Suspend/resume left the same driver bound, probe count 1, the port open, frames running, and both a stick and a button working. NextUI opened the new event device directly.

Not done in 3B: persistent calibration, `FF_RUMBLE`, Switch-stick hardware validation, userspace name cutover, and emulator compatibility.

### 3C — Complete physical gamepad integration

Once the tracer is proven, complete the physical-device behavior:

* all built-in gamepad buttons;
* both analog sticks;
* correct axis orientation;
* full usable axis ranges;
* deadzone/noise handling;
* calibration mechanism;
* persistent per-axis min, zero, and max through userspace;
* non-blocking boot-time center calibration that rejects a moving stick;
* full-range calibration of both sticks, including asymmetric travel;
* a narrow raw/normalized diagnostic report;
* L3/R3;
* MENU;
* standard `FF_RUMBLE`;
* suspend/resume;
* robust handling of missing or malformed UART data;
* correct cleanup and recovery;
* correct DTS ownership.

Do not make InputPlumber part of this phase.

Do not emulate Xbox or Nintendo controller protocols in the physical driver.

Application-specific mapping remains userspace policy.

Phase 3C owns the input power and wakeup audit before the physical driver is called feature-complete. Measure UART/DMA interrupt rate, idle GPIO interrupt rate, CPU idle residency, idle CPU use, the evdev event rate, and battery current where that reading is reliable. The ~66.8 Hz figure is the UART frame rate. If `input_sync()` runs for every frame while no published axis value changed, synchronize only when a published value changes. Do not decimate real stick motion. Do not change the UART baud unless the sender protocol is shown to support it. The old 6 ms GPIO poll and this UART cadence are not the same loop.

Phase 3C also replaces `Autocal.pak` and `zlyme-joypad-cal`. Those talk to the old ROCKNIX sysfs ABI. The selected UI/workflow reference is `Helaas/nextui-Joe-s-Calibrage-pak` at `205f662c9ab7334229787e024e3556ee00272aad` (v0.2.0), MIT, Copyright (c) 2026 Kevin Vranken. Its my355 backend is not usable as-is: it opens `/dev/ttyS1`, writes `/userdata` calibration files, and uses `miyooio` `joy_type`. UART1 stays owned by the serdev driver. The new app uses the driver's calibration and raw-diagnostic interface. Do not add a character device, and do not open files from the kernel. Copied or adapted code keeps the MIT text, Kevin Vranken's copyright, attribution to Joe's Calibrage, and that commit. Audit vendored dependencies separately from the repository MIT license.

Suggested attribution:

```text
Calibration UI/workflow based in part on Joe's Calibrage
by Kevin Vranken (Helaas), used under the MIT License.
```

The runtime model must keep persistent min / saved zero / max distinct from a fresh accepted boot center. A later restore must not overwrite that fresh runtime center with the persisted zero. Exact sysfs names are chosen when 3C starts. The interface stays small.

### 3D — Cutover and hardware validation

After the replacement has feature parity, switch Zlyme to the new driver.

Update direct dependencies such as:

```text
DTS binding
module loading
calibration tooling
NextUI device lookup where necessary
RetroArch/SDL mappings where necessary
post-build module checks
```

Original Flip sticks are the hardware-validation target for this cutover.

Switch 1 non-Hall replacement sticks stay a designed compatibility target. They use the same driver and the same frame. Phase 3D may include the community protocol in `docs/research/joypad-driver.md` when a tester has those modules. Do not call that support validated until those tests pass. Do not block the original-stick cutover on them.

Phase 3D owns removal of `rocknix-joypad` from the normal product build, after 3C calibration and rumble have passed. Git history is the fallback. At that cutover, check whether `input-polldev` and the `adc-keys` / `joypad_input_g` patches exist only for the old driver. If they do, remove them as part of this migration, with a clean Linux re-extract and repatch. That is not the Phase 5 kernel cleanup.

Phase 3D owns direct Zlyme consumers required for the physical-driver cutover: NextUI lookup where it is required, `zlyme-keylidmon`, `zlyme-pak-hotkey`, rumble lookup, module loading, post-build checks, calibration boot restore, and the minimum mapping needed for the game-launch gate. Do not edit every emulator config here. Broad emulator compatibility is the Phase 4 virtual controller.

Some NextUI controls may perform the same action twice. The kernel reported one press and one release on one device, with the old driver unbound. Treat that as an application, SDL, or input-routing issue until evidence says otherwise. Instrument that path at the start of 3D. Do not change the physical button ABI in 3C to hide it. If Phase 4 later exposes both the physical device and an InputPlumber virtual device, exclusive grab owns that separate duplicate-device problem. Do not use Phase 4 to hide an existing NextUI bug.

Broader kernel-patch reduction remains Phase 5.

### Phase 3 gate

Before Phase 4:

* current gamepad hardware ownership is documented;
* the new driver uses no ROCKNIX-branded public identity;
* no unrelated controller identity is spoofed;
* all built-in gamepad buttons work;
* both analog sticks work across their usable ranges;
* persistent per-axis min, zero, and max calibration works;
* a boot-time center does not rewrite the persistent calibration file;
* boot-time center calibration is non-blocking, rejects a moving stick, and does not delay buttons or NextUI;
* original sticks are hardware-validated;
* Switch 1 non-Hall replacement sticks are a designed compatibility target on the same UART protocol;
* replacement-stick support is not called validated until the community hardware tests pass;
* L3/R3 work;
* MENU works;
* rumble works through standard force feedback;
* input capabilities and device identity are stable;
* GPIO handling does not retain unnecessary polling where interrupts are suitable;
* UART ownership and recovery are deterministic;
* malformed/missing UART data cannot block boot or frontend startup;
* standard suspend/resume works repeatedly;
* game launch/exit works;
* external controller coexistence works;
* the old driver is no longer required for the normal build;
* the known-good old implementation remains recoverable through Git history rather than parallel runtime ownership;
* documentation reflects the implemented architecture.

Only after this gate should Phase 4 introduce InputPlumber as the stable virtual controller for broad emulator and application compatibility. That virtual device may present an Xbox-compatible userspace ABI for selected software. Phase 4 does not replace the Phase 3D NextUI duplicate-action investigation.

## 4 — Introduce InputPlumber as the input-policy layer

This is an intentional Zlyme design choice relative to historical implementations. Do not infer the current official ROCKNIX state without fresh research.

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

## 5 — Second kernel patch reduction pass

After the input transition, remove patches made obsolete by:
- the new joypad module;
- newer upstream kernel code discovered since Phase 2;
- no-longer-supported devices.

For every affected patch, record one of:

```text
KEEP — required and why
UPSTREAMED — remove, with upstream commit/version
MODULE — functionality moved to external module
DROP — irrelevant to my355
DEBUG — keep only in debug profile, or delete
```

Re-check upstream status rather than relying blindly on the Phase-2 snapshot if significant time has passed.

This should leave a small explainable my355 kernel delta.

## 6 — Deep suspend bring-up

The device wiki establishes:

- standard suspend already works;
- deep suspend is a separate BL31/SIP configuration feature;
- `vdd_logic` off-in-suspend is unsafe without `ARMOFF_LOGOFF`;
- historical Miyoo Flip implementations deferred deep suspend for userspace/lifecycle reasons.

That historical userspace decision does **not automatically apply** to Zlyme. Zlyme uses NextUI and must validate its own lifecycle.

Phase 2 may discover newer suspend fixes or implementations. Preserve that evidence for this phase instead of enabling deep suspend early.

### Do not combine two experiments initially

First bring up deep suspend using the best-supported implementation shape established by current hardware and upstream research.

Do not simultaneously:
- rewrite the joypad driver;
- change BL31 for unrelated reasons;
- change DMC architecture;
- change input policy.

Prove deep suspend first.

### Module question

If the selected suspend implementation is built-in or relies on early/late kernel init integration, converting it into an external loadable module is a separate refactor.

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

Phase 2 must first establish the current upstream/external state of the RK3568 DMC/DFI patches. This phase owns the architectural migration.

Important: the current Zlyme `rk3568_dmc` patch defines:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ
```

as `tristate`, and the driver uses `module_platform_driver()`.

Therefore separate two goals.

### 7A — build it as a module

Change:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ=y
```

to:

```text
CONFIG_ARM_RK3568_DMC_DEVFREQ=m
```

while keeping the source-injection patch initially.

Validate module load timing, devfreq availability, suspend/resume, and gaming profiles.

This is the smaller experiment.

### 7B — stop injecting the driver through a kernel patch

Only after 7A is proven, move the driver source into a Buildroot out-of-tree kernel-module package, for example:

```text
package/drivers/rk3568-dmc/
```

The external module must be self-contained with respect to the V2 SIP constants it needs.

This can potentially remove the patch that adds the driver/Kconfig/Makefile entries to the kernel tree.

It does **not** automatically remove an in-tree DFI PM patch if that patch still modifies the selected kernel's `rockchip-dfi` behavior.

Review DTS/binding changes separately; runtime functionality does not justify retaining documentation/binding patches that are no longer required by code or validation.

### Gate

Test:
- module autoload/probe;
- available DMC frequencies;
- dynamic scaling;
- governor switching;
- performance profile forcing;
- suspend/resume;
- deep suspend if Phase 6 is enabled;
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
phase-2-roadmap
phase-2-upstream-evidence
phase-2-patch-inventory
kernel-patch-prune-<family>
kernel-patch-replace-<family>
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

The Phase-2 research checkpoint should not contain kernel implementation changes.
