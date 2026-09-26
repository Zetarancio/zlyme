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

The driver loads early and starts from the protocol fallback `0/128/255`. Its bounded boot runtime recenter then runs asynchronously. It may update only `runtime_zero`. It never learns min/max and never writes persistence. If that recenter accepts, the fresh center becomes the runtime zero. If it rejects or times out, the current runtime source stays. After the existing frontend first-frame wait, userspace restores saved min, saved zero, and max. A restore may install the saved zero as the runtime zero only while the source is still `default` or `persisted`. A source of `boot` keeps the accepted fresh runtime zero. The kernel never opens the persistent files. Full min/zero/max calibration is manual only. No infinite wait, no delayed probe, and no calibration loop inside `probe`. Buttons stay available if UART never produces a frame.

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

```text
Phase 3C2b COMPLETE — 2026-09-25
Phase 3C3 COMPLETE — 2026-09-25
Phase 3D COMPLETE — 2026-09-25
Phase 3 COMPLETE — 2026-09-25
Phase 4A COMPLETE
Phase 4B COMPLETE — 2026-09-26
Phase 4C NOT STARTED
Phase 4D NOT STARTED
```

Earlier gates: Phase 3A complete 2026-09-23, Phase 3B complete 2026-09-23, Phase 3C1 complete 2026-09-24, Phase 3C2a complete 2026-09-24.

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
* persistent per-axis min, saved zero, and max through userspace;
* bounded non-blocking boot runtime recentering that rejects a moving or out-of-range stick;
* manual full-range calibration of both sticks, including asymmetric travel;
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

Calibration mechanism and calibration policy are deliberately separate:

```text
kernel:
    UART decode
    runtime transform
    deadzone/noise handling
    bounded boot runtime recenter
    calibration sysfs mechanism
    standard ABS_* output

userspace:
    manual calibration procedure
    persistent files under /storage
    calibration UI
    persistent restore/apply policy
```

The kernel never opens persistent calibration files.

A **manual calibration** is an explicit user action that measures and saves per-axis min, zero, and max.

A **boot runtime recenter** is not a full calibration. It may refine only the running center for the current boot. It never learns min/max and never rewrites persistence.

The normal model is:

```text
persistent:
    min
    saved zero
    max

per boot:
    runtime zero
```

The driver may asynchronously accept a fresh stable center for the current boot. If accepted, that center becomes the runtime zero only. If the samples are moving, unstable, or outside the active calibrated range, they are rejected. Boot, buttons, and NextUI must never wait for this measurement.

Full min/zero/max calibration is manual through the user-facing calibration PAK only.

Phase 3C owns the input power and wakeup audit before the physical driver is called feature-complete. Measure UART/DMA interrupt rate, idle GPIO interrupt rate, CPU idle residency, idle CPU use, the evdev event rate, and battery current where that reading is reliable. The ~66.8 Hz figure is the UART frame rate. Do not decimate real stick motion or change the UART baud without protocol evidence. The old 6 ms GPIO poll and the UART cadence are different mechanisms.

#### 3C1 result — power and wakeup audit

Measured on zlyme41.

Idle UART was 66.91 frames/s, 6 bytes/frame, with 0 bad frames. The UART IRQ matched that rate. Gamepad GPIO IRQs were 0.

Idle evdev delivered:

```text
0 EV_ABS
0 SYN_REPORT
0 EV_KEY
```

Linux 7.0.2 already drops unchanged absolute values and does not deliver an empty synchronization packet. CPU0 idle residency was about 83.7% and CPU1 about 84.9%; both continued to enter `cpu-sleep`.

Recommendation: **no driver-side duplicate-report filter**.

RK817 current reporting was not trustworthy enough for a battery result.

#### 3C2a result — production calibration mechanism

Complete and hardware-validated through zlyme43.

The production uncalibrated fallback is the UART byte domain:

```text
min          0
saved_zero   128
runtime_zero 128
max          255
```

These are protocol-domain fallbacks, not measured physical travel.

Each axis tracks:

```text
min
saved_zero
runtime_zero
max
```

Runtime-zero provenance is explicit:

```text
default
persisted
boot
apply
```

Calibration attributes are:

```text
calibration_left
calibration_right
```

Writes are:

```text
restore x_min x_zero x_max y_min y_zero y_max
apply   x_min x_zero x_max y_min y_zero y_max
```

The kernel validates that the active center is strictly inside min/max and that both usable spans are longer than the raw deadband.

`restore` updates persistent min, saved zero, and max. A runtime center originating from `boot` or `apply` remains authoritative if it still fits the proposed range.

`apply` is a deliberate live calibration operation. It installs min, saved zero, runtime zero, and max and becomes source `apply`.

A successful boot runtime recenter installs only a fresh `runtime_zero` and source `boot`.

A stable boot center outside the active calibrated range is not installed. The existing center/source remain active and the diagnostic state becomes terminal `range-rejected`.

Invalid writes are atomic.

Persistent userspace files are:

```text
/storage/.config/zlyme/miyoo-flip-gamepad/joypad.config
/storage/.config/zlyme/miyoo-flip-gamepad/joypad_right.config
```

with:

```text
x_min
x_max
y_min
y_max
x_zero
y_zero
```

The kernel never opens these files.

Hardware validation covered fallback behavior, persistent restore, early and late restore/apply ordering, stale calibration rejection, asymmetric full-range scaling, return to center, UART continuity, deep suspend/resume, and post-resume input.

Measured original-stick calibration remains diagnostic hardware evidence, not compiled defaults:

```text
YL 25 / 139 / 239
XL 2  / 103 / 223
YR 49 / 138 / 226
XR 17 / 112 / 203
```

#### 3C2b — Integrated joystick calibration and live deadzone tuning

Phase 3C2a established the production calibration mechanism:

```text
raw UART
    ->
per-axis min / saved zero / runtime zero / max
    ->
normalized ABS_X / ABS_Y / ABS_RX / ABS_RY
```

3C2b completes the user-facing calibration and tuning lifecycle.

Do not introduce InputPlumber in this phase.

The user-facing implementation belongs inside the existing NextUI Settings application rather than as a permanent standalone Tool PAK.

The target UI is:

```text
Settings
    -> System
        -> Joysticks
```

This follows the same architectural direction as Zlyme Update: device/system configuration that is part of the OS belongs in Settings rather than requiring a separate Tool PAK.

Checkpoint `3ef5bca` built a standalone `Joystick Calibration.pak` as an integration experiment. That PAK was never released. It is not the product UI, and it is not an OTA migration target. Fresh images omit it. A copy left on a developer test card is removed by hand.

##### Upstream input model

Use established Linux controller practice as guidance, but preserve Zlyme's actual hardware requirements.

Reference review:

```text
Linux:
    torvalds/linux
    master reviewed at ee9c669f9bf5fd2c24206746ded9382fe810df89

Relevant drivers:
    drivers/hid/hid-nintendo.c
    drivers/hid/hid-steam.c

Linux input semantics:
    include/uapi/linux/input.h
    drivers/input/input.c

InputPlumber:
    ShadowBlip/InputPlumber
    v0.81.0
    ea60d873cca17edd1cb655ede26f557108135252
```

`hid-nintendo` provides a useful calibration model:

* independent calibration for each stick axis;
* explicit min, center, and max;
* validation that `min < center < max`;
* asymmetric scaling on either side of center;
* safe defaults when calibration cannot be read;
* standard normalized Linux axis output.

It does not implement a user-adjustable analog-stick deadzone in the axis mapping function.

`hid-nintendo` instead advertises nonzero Linux `fuzz` and `flat` values.

`hid-steam` exposes its joystick axes with zero `fuzz` and zero `flat`, while configurable controller behavior is normally handled by the higher userspace Steam Input layer.

Those two models establish an important distinction:

```text
hardware calibration / normalization
        !=
user-selected gameplay deadzone
```

Linux `fuzz` is an input-core noise filter. It can suppress or smooth small changes anywhere on an absolute axis.

Linux `flat` is axis metadata used by consumers such as the legacy joydev interface to define a central flat region. It is not guaranteed to transform the evdev values seen by every application.

SDL may return Linux joystick values without applying `flat`.

Therefore Zlyme must not depend on `flat` alone for a deadzone that is intended to affect all consumers of the built-in physical controller.

##### Zlyme ownership

Preserve mechanism/policy separation:

```text
kernel driver:
    UART decode
    raw hardware sample
    min / center / max transform
    fixed minimal hardware-noise floor
    configurable deadzone mechanism
    standard ABS_* output

userspace:
    calibration procedure
    deadzone choice
    live tuning UI
    persistence
    boot restore policy
```

The driver's deadzone parameter is a mechanism.

Settings chooses the value and persists it.

The kernel must not open persistent files.

InputPlumber remains Phase 4 policy for one composite per player controller, player order, hotplug, grabs, and broad application compatibility. It must not become necessary for built-in-stick calibration or deadzone tuning in 3C2b.

##### Hardware noise floor versus user deadzone

Keep these as separate concepts.

The existing:

```text
MF_RAW_DEADBAND = 2
```

is a small hardware/noise floor around the active runtime center.

It remains an internal driver correctness mechanism unless hardware measurements justify changing it.

It is not the user-visible deadzone setting.

The driver applies a separate user-adjustable deadzone after per-axis calibration/normalization.

Conceptually:

```text
UART raw values
    ->
fixed minimal raw noise floor
    ->
asymmetric min / runtime-zero / max normalization
    ->
per-stick configurable deadzone
    ->
ABS_X / ABS_Y / ABS_RX / ABS_RY
```

The default user deadzone is:

```text
0%
```

so upgrading preserves the currently validated stick behavior apart from the existing fixed raw noise floor.

The first UI range is:

```text
0% .. 30%
```

in 1% steps.

Do not add response curves, outer deadzones, anti-deadzones, acceleration, sensitivity, or per-axis user tuning in 3C2b.

Those are separate policy features and require separate evidence.

##### Deadzone shape

The user setting is per physical stick:

```text
left deadzone
right deadzone
```

not four independent X/Y settings.

Use a scaled radial inner deadzone after the X/Y axes have been independently calibrated and normalized.

Required behavior:

```text
inside radius:
    X = 0
    Y = 0

outside radius:
    preserve stick direction
    transition continuously away from zero
    rescale remaining travel so full cardinal travel can still reach full scale
```

There must not be a discontinuous jump from zero to the deadzone percentage at the boundary.

The integer implementation uses no kernel floating point. Independent axis normalization can produce a vector whose radius is greater than `M` (32767), up to about `sqrt(2) * M`. Scaling that region with the circular formula makes the factor greater than 1 and can clamp a component before that axis has reached its own end.

The shipped transform is:

```text
r <= D:     output = 0
D < r < M:  scaled radial remap
r >= M:     input vector unchanged
```

It does not amplify `r >= M`. A circular stick near 45 degrees, about `0.707 M` on each axis, still uses the scaled remap. This outer-radius identity is a host math invariant, not a separate physical diagonal test.

##### Linux ABS metadata

Do not use Linux `flat` as the implementation of the configurable deadzone.

Because the driver itself will emit zero inside the selected deadzone, advertising the same region again as nonzero `flat` can cause consumers that honor `flat` to apply a second deadzone.

Keep:

```text
flat = 0
```

for the built-in stick axes unless later measurements and consumer testing justify another value.

Likewise do not add nonzero `fuzz` merely because `hid-nintendo` uses it. Linux input core actively filters absolute-axis changes using `fuzz`, including away from center.

Keep:

```text
fuzz = 0
```

unless measured Miyoo Flip noise demonstrates that whole-axis input-core filtering improves behavior without harming latency or precision.

The existing fixed center noise floor remains the current noise mechanism.

##### Runtime deadzone ABI

Expose a narrow runtime interface on the same gamepad device as the calibration attributes.

Use one value per stick, for example:

```text
deadzone_left
deadzone_right
```

The stable value is an integer percentage:

```text
0 .. 30
```

Writes outside the supported range fail without changing the active value.

A successful write changes the running transform immediately.

Changing deadzone must not alter:

```text
min
saved_zero
runtime_zero
max
boot-center state
```

and must not restart or reprobe the input device.

Updating a deadzone must immediately re-report the latest stick position through the new transform so the Settings UI can preview the result without waiting for physical movement.

Do not overload `calibration_left` or `calibration_right` with deadzone syntax. Preserve the already validated calibration ABI.

##### Persistence

Keep physical calibration files unchanged:

```text
/storage/.config/zlyme/miyoo-flip-gamepad/joypad.config
/storage/.config/zlyme/miyoo-flip-gamepad/joypad_right.config
```

Do not append deadzone fields to those files.

That preserves the existing calibration format and improves rollback compatibility.

Persist user deadzones separately:

```text
/storage/.config/zlyme/miyoo-flip-gamepad/deadzone.config
```

with a small explicit format such as:

```text
left=0
right=0
```

Each value is validated independently.

A missing file means the default user deadzone of `0%`.

A missing or invalid left value must not prevent a valid right value from being restored, and the reverse.

Persistent replacement uses the same minimum durability contract as calibration:

```text
temporary file
    -> fsync file
    -> close
    -> rename
```

Do not write the persistent file on every D-pad adjustment.

Live preview changes runtime state only.

Persistence happens only when the user explicitly saves.

##### Boot lifecycle

Keep the existing 3C2b boot architecture.

Do not move calibration or deadzone persistence into the kernel.

Do not add another Class-A operation before the NextUI first frame.

The intended boot sequence remains:

```text
module loading
    -> Miyoo Flip Gamepad available
    -> asynchronous boot runtime recenter
    -> fixed raw noise floor active
    -> default user deadzone active

NextUI
    -> first frame/list

rc.late
    -> restore saved min / saved zero / max
    -> restore saved left/right deadzone
    -> Class-B background work
```

`S26joypadcal` is removed. Module loading stays with `modules-load.d`, and `rc.late` is the only boot restore owner. On the 2026-09-25 validation boot, `nextui-first-flip` was 10.93 s, restore started at 10.95 s, and restore ended at 11.07 s, about 0.12 s. Restore stayed after the first-frame gate.

`rc.late` calls `zlyme-gamepad-cal restore` once, immediately after the existing `wait_boot_list` gate returns and before Class-B `start_bg`. `wait_boot_list` returns on `nextui-first-flip` or after its existing ~20-second timeout. Do not add another calibration or deadzone wait. Restore is outside the first-frame path. If the frontend never flips, the existing timeout still lets late work proceed. Do not delay NextUI because boot runtime recenter has not finished, and do not assume the usual recenter duration.

`zlyme-gamepad-cal restore` restores both calibration and deadzone. A missing file is a successful no-op for that state. If boot runtime recenter has already accepted a center, later calibration restore keeps that runtime center while installing saved extrema and saved zero. Restoring deadzone must not replace a boot-selected runtime center.

Do not perform full min/zero/max calibration automatically at boot.

##### Settings integration

The product UI is Settings, not a Tool PAK. The submenu is:

```text
Settings
    -> System
        -> Joysticks
            Test Sticks
            Calibrate Left
            Calibrate Right
            Tune Left Deadzone
            Tune Right Deadzone
            Values
```

Use the existing Settings rendering/input lifecycle rather than embedding a second UI framework into `settings.elf`.

Keep gamepad-specific code isolated in a dedicated Zlyme joystick/settings module rather than scattering sysfs discovery and calibration parsing through generic Settings code.

Do not add a daemon.

Raw polling is allowed only while a live joystick/calibration screen is visible, because the calibration ABI is a snapshot sysfs interface rather than an event stream. Keep that polling bounded and stop it immediately when the screen closes.

##### Test Sticks

`Test Sticks` shows both sticks simultaneously using the actual post-driver Linux input values that applications receive.

It is a final-output test, not a calibration source.

Each stick should have a clear center marker and live position marker.

This screen verifies:

```text
center
deadzone
direction
full travel
return to center
```

without changing configuration.

##### Manual calibration UI

Calibration itself uses `raw_axes`, not already transformed SDL axes.

For the selected stick show:

```text
raw physical position
captured range
current min/max
capture progress
```

with a realtime stick visualization.

Range capture begins immediately when the calibration screen opens.

The instruction is conceptually:

```text
Rotate the stick fully around the edge.
Press A when finished.
```

The user does not hold A while moving the stick.

When A ends the range phase:

```text
stop updating captured extrema
    ->
ask the user to release the stick
    ->
automatically collect center samples
```

Do not make the button press itself create the center measurement.

The center phase continuously measures the released stick until the existing stability requirement is satisfied.

Only after a stable center is available should the UI enable/offer:

```text
A  Save
```

A successful save performs:

```text
validate candidate
    ->
live kernel apply
    ->
atomic persistent replacement
```

and must distinguish:

```text
apply failed
apply succeeded but persistence failed
full success
```

`B` cancels without modifying persistence.

Provide a restart/reset action for the current capture where useful.

##### Travel-quality validation

The kernel's raw deadband invariant is not sufficient evidence of a good manual full-range calibration.

Do not use:

```text
captured span > MF_RAW_DEADBAND
```

as the only full-travel quality test.

The kernel should continue accepting any structurally safe calibration that satisfies its invariant.

Travel-quality policy belongs in the calibration UI.

The implemented userspace travel-quality threshold is `CAL_MIN_SPAN = 40` raw counts on both axes. It is not a kernel invariant. Measured original-stick spans are about 177..221 counts, so 40 only rejects an obviously incomplete sweep. Asymmetric axes remain valid.

##### Live deadzone tuning UI

`Tune Left Deadzone` and `Tune Right Deadzone` are realtime screens.

Show:

```text
outer calibrated stick area
current deadzone as an inner circle
physical/raw-position marker
effective post-deadzone output marker
deadzone percentage
```

The raw marker allows the user to see physical center drift.

The output marker shows what applications actually receive.

When the physical marker is inside the deadzone, the effective output marker remains centered.

Controls:

```text
D-pad Left   decrease deadzone
D-pad Right  increase deadzone
A            save
B            cancel
```

Adjustments apply to the driver immediately for preview.

They do not write persistent storage on each step.

On `A`:

```text
apply final runtime value
    ->
atomically persist
```

On `B`:

```text
restore the runtime deadzone that was active when the screen opened
    ->
leave persistence unchanged
```

A crash during preview may leave a temporary runtime value for the current boot, but it must never corrupt persistent calibration or persistent deadzone state. Reboot restore returns to the saved value.

##### Values screen

Replace the current large text-message dump with a compact diagnostic screen.

Show left and right sticks side by side where practical.

Include at least:

```text
min
saved center
runtime center
max
center source
deadzone %
current raw X/Y
current final/output X/Y
persistent calibration present/valid
persistent deadzone present/valid
```

This screen is read-only.

It should make the important distinction between saved center and boot/runtime center visible without requiring SSH.

##### Backup behavior

Remove the calibration-specific `.bak` mechanism and the separate:

```text
Restore Left Backup
Restore Right Backup
```

UI.

The calibration save transaction already keeps the old persistent file when replacement fails.

Zlyme Settings also already provides the broader `/storage/.config` backup facility.

Do not maintain a second calibration-only backup lifecycle without a demonstrated need.

##### Released Autocal migration

Fresh images contain neither `Autocal.pak` nor the unreleased checkpoint `Joystick Calibration.pak`.

`Joystick Calibration.pak` from `3ef5bca` was never shipped. Do not add an OTA deletion for it. `post-update.sh` removes only the released obsolete tool:

```text
/storage_root/Tools/my355/Autocal.pak
```

That hook runs from initramfs after the new squashfs has been committed. Do not put the deletion in `pre-update.sh`. Do not add an every-boot Autocal deletion to `nextui-session`.

Stop building the standalone `calibrate.elf` once Settings owns the UI. Keep calibration logic and tests that exercise the production backend. Do not remove Apostrophe merely because the checkpoint PAK used it.

Legacy calibration evidence under:

```text
/storage/.config/miyoo-serial-joypad/
```

still survives until the later old-driver cleanup.

##### Attribution

Moving the UI into Settings must not lose upstream attribution.

The workflow reference remains:

```text
Helaas/nextui-Joe-s-Calibrage-pak
205f662c9ab7334229787e024e3556ee00272aad
v0.2.0
MIT
Copyright (c) 2026 Kevin Vranken
```

Retain the applicable MIT license, copyright, upstream commit, and attribution in the repository and installed license/credits material even after the standalone PAK directory disappears.

Do not copy Joe's old my355 hardware backend.

In particular, do not reintroduce:

```text
/dev/ttyS1
userspace termios ownership
/userdata calibration files
/tmp/miyoo_inputd
/tmp/joypad_calibrating
/sys/class/miyooio_chr_dev/joy_type
```

UART1 remains owned by the kernel serdev driver.

##### InputPlumber boundary

InputPlumber remains Phase 4.

Current InputPlumber v0.81.0 has a `deadzone` property used for threshold-style mappings such as axis-to-button translation, but the reviewed analog axis-to-axis path does not provide the system-wide adjustable analog deadzone required here.

Do not introduce InputPlumber into 3C2b solely for deadzone tuning.

When Phase 4 later routes the built-in controller through a virtual device, preserve the deadzone already applied by the physical Miyoo Flip driver.

Do not silently apply a second default deadzone in InputPlumber.

If InputPlumber later gains a suitable analog deadzone transform and Zlyme considers moving policy there, that is a separate measured migration. It must compare direct-input behavior, latency, boot ordering, external-controller policy, and double-deadzone risk before ownership changes.

##### 3C2b gate

Before 3C2b is complete, prove on the Miyoo Flip:

```text
Settings -> System -> Joysticks opens and exits cleanly
fresh images contain no Joystick Calibration.pak
Test Sticks shows both final output sticks in realtime

left-stick manual calibration works
right-stick manual calibration works
calibration visualization is driven by raw_axes
range capture begins automatically
A ends range capture but does not itself measure center
center capture occurs after release and rejects unstable center
incomplete travel is rejected by documented UI quality policy
asymmetric calibration remains supported

live apply uses the production calibration sysfs ABI
persistent calibration remains atomic
failed live apply is not reported as saved
failed persistent replacement is not reported as full success

left deadzone adjusts live
right deadzone adjusts live
deadzone 0% preserves the current validated behavior
inside the configured deadzone final X/Y are exactly zero
movement immediately outside the deadzone is continuous
full cardinal travel can still reach full scale
diagonal movement does not show unacceptable clipping or early saturation
deadzone tuning does not alter calibration min/zero/max
deadzone tuning does not alter boot-center ownership

D-pad adjustment performs no persistent write
A saves the selected deadzone
B restores the pre-preview runtime value
left and right deadzone persistence restore independently
missing deadzone persistence defaults safely
existing six-field calibration files remain valid without migration
deadzone survives reboot

Linux flat remains zero unless later evidence changes the design
Linux fuzz remains zero unless later measurement justifies filtering
SDL/direct evdev consumers observe the effective driver deadzone without requiring a special SDL deadzone hint

post-first-frame calibration/deadzone restore works
restore does not delay NextUI first frame
boot runtime recenter remains independent
no automatic full calibration occurs at boot

Autocal.pak is absent from a fresh image
OTA removes a released card copy of Autocal.pak after the squashfs commit
the unreleased Joystick Calibration.pak has no OTA cleanup
legacy /storage/.config/miyoo-serial-joypad/ survives

general System backup includes the new persistent deadzone file
no calibration-specific .bak lifecycle remains
Joe-derived attribution/license remains correct
no InputPlumber dependency is introduced
```

Hardware timing evidence must continue to include:

```text
driver/module available
first valid UART frames
boot runtime-recenter result
nextui-first-flip
persistent calibration/deadzone restore start
persistent calibration/deadzone restore end
```

Restore begins after the existing first-frame gate and must not move `nextui-first-flip` later.

##### 3C2b closure — 2026-09-25

The gate above is complete. Closure uses the device checks, the user's end-to-end acceptance of the UI OTA at `25b34fd7ac8660e642eed7e470a5d28325f10e1d`, code review, host tests, and the image build. The diagonal-saturation correction is `8e288dc790bbbb02b8e3efba666f7e756774bb30` and is host-validated only.

On that boot, `miyoo_flip_gamepad` was the only gamepad module, the UART port was open, `bad=0`, valid frames were increasing, and boot recenter had accepted all four axes. Saved six-field calibration survived the OTA. Resting output was `X=0 Y=0 RX=0 RY=0`. A runtime-only 30% deadzone on each stick kept the other stick at zero, moved the tested axis in the correct direction, and returned to zero on release. The saved `deadzone.config` checksum did not change during those sysfs writes. Settings save and cancel for both sticks matched the file. Restore ran from 10.95 s to 11.07 s, after `nextui-first-flip` at 10.93 s.

`Autocal.pak` was absent from the card and the image. The unreleased Joystick Calibration PAK was absent from both. `/storage/.config/miyoo-serial-joypad/` was not on the validation card. Source audit shows neither restore nor `post-update.sh` deletes that directory. Settings backup runs `tar -acf /storage/zlyme-backup.tar.gz -C /storage .config`, so the gamepad files under `/storage/.config` are inside the general backup. There is no calibration `.bak` writer in the current UI.

Do not remove the old ROCKNIX driver in 3C2b. Phase 3D and Phase 4 have not started. Phase 3C3 is complete.

#### 3C3 — FF_RUMBLE and final physical-driver feature gate

Complete 2026-09-25. The accepted evidence is the physical motor, gain, save, and reboot tests plus the SSH capability and UART checks. Suspend while an effect was playing, and forced module removal while rumbling, were not run. They are not closure blockers: teardown is not a normal product lifecycle, and rumble suspend safety is the driver's cancel-work and PWM-off path plus the earlier physical suspend/resume of this same gamepad.

```text
FF_RUMBLE
    ->
ff-memless / standard FF_GAIN
    ->
single PWM5 motor
Settings:
    persisted global gain
InputPlumber:
    later routing only
```

The kernel driver owns the physical mechanism on the existing `Miyoo Flip Gamepad` device. PWM5 comes from the Flip DTS (`pwms = <&pwm5 0 10000000 0>`, consumer `enable`, period 10 ms, normal polarity). `input_ff_create_memless()` advertises `FF_GAIN`, defaults it to `0xffff`, and applies that gain before the play callback. The callback does not sleep: it caches strong-if-nonzero else weak, then schedules work. The worker maps `0x0000..0xffff` to PWM duty with `pwm_set_relative_duty_cycle()` and does not change the period. Level 0 disables PWM. Close, remove, and probe failure leave the motor off. Suspend cancels the worker and disables PWM but keeps the cached level; resume restarts that level, matching `pwm-vibra`. A permanent PWM claim failure leaves buttons and sticks up and does not advertise `FF_RUMBLE`. `-EPROBE_DEFER` still defers probe. There is no custom `rumble_strength` sysfs and no rumble daemon.

Userspace stores the displayed percentage as `gain=N` (`N` 0..100) in `/storage/.config/zlyme/miyoo-flip-gamepad/rumble.config`. A missing file means displayed 30% and is not created by restore. `zlyme-gamepad-ff restore` still applies that 30%. An invalid file is reported, applied as displayed 30%, and is not rewritten. A saved file stays authoritative. Conversion to `FF_GAIN` is the only Flip motor compensation: displayed 0 stays 0, displayed 10 becomes 15, displayed 30 becomes 34, and displayed 100 stays 100. Fresh Haptic feedback is enabled. An existing `haptics=` value is left alone. A haptic before `rc.late` can still see the kernel's 100% `FF_GAIN`. That stays behind the first-frame gate. Settings → System → Joysticks has Rumble Strength (10% steps, live apply, A saves, B restores the value from screen open) and Test Rumble (about 250 ms, full effect magnitude, so `FF_GAIN` still scales it). `rc.late` runs `zlyme-gamepad-ff restore` after calibration restore and after `nextui-first-flip`. `PLAT_setRumble()` prefers the exact name `Miyoo Flip Gamepad`, then a name containing `retrogame`, then any other `FF_RUMBLE` device. Settings → System → Haptic feedback only enables or disables NextUI's own pulses. Those pulses still go through `PLAT_setRumble()` and are scaled by Rumble Strength. `VIB_doublePulse` / `VIB_triplePulse` scale twice if called, but nothing calls them.

On `zlyme-my355-20260925-4d1c1d44d2a2.tar` (`root@192.168.0.108`, kernel 7.0.2 #5), `event4` was `Miyoo Flip Gamepad` and advertised `FF_RUMBLE` and `FF_GAIN`. Only `miyoo_flip_gamepad` was loaded. Saved `gain=10` (checksum `3682488949 8`) survived runtime-only 0/10/50/100 tests and `restore`. The user confirmed 0% silent, 10% weak but perceptible, and 50% then 100% progressively stronger. Earlier on the previous OTA, Settings save, Test Rumble, and reboot restore of Rumble Strength passed. UART stayed open with `bad=0` and valid frames increasing. Resting axes stayed at zero. Calibration and deadzone files were unchanged. `/sys/kernel/debug/pwm` was not mounted, so PWM-off was not read back. `nextui.elf` held `event4` read-write, but `haptics=0`, so that descriptor was not a confirmed `rumble_open()` result. Suspend while an effect was playing and forced driver removal were not exercised. Source review covers cancel-work and PWM off. Those cases are recorded and are not 3C3 blockers. Phase 3D owns physical-driver cutover and old ROCKNIX removal, not emulator mappings.

Remaining sequence:

```text
3C2b  Settings joystick calibration and live deadzone, post-first-frame restore, Autocal migration
3C3   FF_RUMBLE and physical gain, complete
3D    physical-driver cutover and legacy ROCKNIX cleanup
4     InputPlumber virtual P1 for emulators and standalone applications
```

### 3D — Physical-input cutover and legacy cleanup

Complete 2026-09-25. The old ROCKNIX package is not in the tree. The image must not contain `rocknix-singleadc-joypad.ko`. OTA deletes Autocal, the old serial-joypad config directory, and a hot-copied copy of that module. Current settings stay in `/storage/.config/zlyme/miyoo-flip-gamepad/`.

`CONFIG_KEYBOARD_GPIO_POLLED=y` still needs the `input-polldev` patch, so that patch stays. The adc-keys keycode redirect is unused on the Flip, which has no `adc-keys` node, and remains for Phase 5 rather than a kernel re-extract in this cutover. Non-Flip dts-overrides that still mention the old compatible are not the product image.

After 3C, the physical driver, calibration, deadzone, and rumble are already accepted. Do not repeat those hardware tests here.

3D owns:

```text
NextUI and direct platform code that still need the name Miyoo Flip Gamepad
removal of retrogame and old-driver fallbacks once that path is safe
current NextUI device lookup still tied to the old identity
a check that the physical device is not itself emitting duplicate events
removal of rocknix-singleadc-joypad from the normal product
old-driver-only package and build dependencies
input-polldev, adc-keys, and joypad_input_g only where they exist solely for the old driver
clean build and image inspection
```

3D does not own per-emulator mappings, standalone controller configuration, RetroArch ABI validation, independent virtual controllers, player order, hotplug, connect and disconnect during games, or making every emulator bind to `Miyoo Flip Gamepad`. Those are Phase 4.

Switch 1 non-Hall replacement sticks stay a designed compatibility target on the same UART frame. Community validation is not a Phase 3 blocker, and they are not called physically validated.

Git history remains the fallback for the old driver. Broader kernel-patch reduction remains Phase 5. Module loading of the new gamepad stays on the existing early boot path.

Some NextUI controls may act twice. The kernel reported one press and one release on one device. 3D only has to show the physical device is not the source. Do not change the button ABI to hide an application bug. If Phase 4 later exposes both the physical device and a virtual device, exclusive grab owns that separate problem.

### Phase 3 gate

Before Phase 4:

* current gamepad hardware ownership is documented;
* the new driver uses no ROCKNIX-branded public identity;
* no unrelated controller identity is spoofed;
* all built-in gamepad buttons work;
* both analog sticks work across their usable ranges;
* persistent per-axis min, zero, and max calibration works;
* boot runtime recenter changes only runtime zero and never persistence;
* boot runtime recenter is bounded and non-blocking, and rejects an unstable or out-of-range center;
* full min/zero/max calibration occurs only through an explicit userspace action;
* persistent saved calibration restore is outside the frontend first-frame critical path;
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
* standard suspend/resume of the physical gamepad works;
* the old driver is no longer required for the normal build after 3D;
* the known-good old implementation remains recoverable through Git history rather than parallel runtime ownership;
* documentation reflects the implemented architecture.

Game launch, external controllers, hotplug, and per-emulator mappings are Phase 4. They are not prerequisites for finishing the physical gamepad.

The physical hardware gate is the evidence from Phase 3B through Phase 3C3. Switch replacement sticks are not required to finish Phase 3.

## 4 — Introduce InputPlumber as the application controller

Phase 4 owns the controllers that emulators and standalone applications see. Each physical player controller stays independent:

```text
one physical player controller
        ->
one InputPlumber composite
        ->
one virtual controller
        |
        +-> RetroArch
        +-> standalone emulators
        +-> native and PAK applications that need a controller
```

Several physical player controllers stay several composites:

```text
multiple physical player controllers
        ->
multiple independent InputPlumber composites
        ->
multiple ordered application-facing virtual controllers
```

Applications should not bind to the board-specific name `Miyoo Flip Gamepad`. InputPlumber owns each physical player controller as its own composite and exposes one virtual controller for that composite. After the handoff, NextUI, RetroArch, standalones, and PAK applications that need a controller use those virtual devices. Settings → System → Joysticks stays on the physical built-in pad and its sysfs for calibration, deadzone, and rumble. Entering that screen should unmanage only the internal source. Leaving it restores InputPlumber. Do not stop every controller to calibrate one stick if a per-device control exists.

P1 is the first position among those independent virtual controllers. With no external controller, the built-in pad is P1. If any external controller is connected, external controllers come first, in connection order unless InputPlumber has a stronger stable order, and the built-in pad is last. Do not use `/dev/input/eventN` as priority. HDMI does not change this. An HDMI cable with no external controller leaves the built-in pad as P1.

Do not require a Switch Pro, DualShock, DualSense, or hotplug test on this unit. Match external devices through InputPlumber's own interfaces and say they are not physically validated here. The device test is the built-in pad: InputPlumber sees it, the virtual target appears, normal consumers do not also see the physical source, buttons and sticks match, rumble returns to the motor if the target supports it, and a supported unmanage/manage of the internal source drops and restores virtual input. Do not unload `miyoo-flip-gamepad` to simulate that.

InputPlumber starts after the current first frame. NextUI keeps the physical path until the virtual controller is ready, then closes that handle and uses the virtual device. One owner at a time. Measure startup, time to a usable virtual pad, RSS, and wakeups before making InputPlumber block the first frame.

This is an intentional Zlyme design choice relative to historical implementations. Do not infer the current official ROCKNIX state without fresh research.

The previous Zlyme research correctly concluded that InputPlumber was unnecessary merely to fix Nintendo controller support. That remains true: vendor HID drivers such as `hid-nintendo` solve vendor report-mode problems.

Adopt InputPlumber for the application-policy goal:

- one virtual controller per physical player controller;
- player order, with the built-in pad first when it is alone and external controllers first when any external is connected;
- exclusive grabs when useful;
- consistent mapping;
- hotplug policy;
- game launch and in-game controller behavior;
- decoupling emulators and standalones from the physical Flip identity.

### 4A — Package InputPlumber

Complete. At the 4A checkpoint, Buildroot `cargo-package` built pinned v0.81.0 (`ea60d873cca17edd1cb655ede26f557108135252`). The image contained `/usr/bin/inputplumber`, the D-Bus policy, upstream `default.yaml`, and `20-zlyme_miyoo_flip.yaml`. That file is a CompositeDevice named Miyoo Flip Gamepad, matched by evdev name, `maximum_sources: 1`, `auto_manage: false`, `persist: false`, target `xb360`. At that checkpoint nothing started it, and there was no device test. Phase 4B added the init script, the capability map, post-first-frame startup, and live validation.

### 4B — Built-in controller integration and latency

Complete — 2026-09-26. The service starts after the first frame and owns zero controllers until management is enabled. Live checks covered exclusive grab, one `xb360` target, face buttons, sticks, MENU/Guide, L3/R3, D-pad as `ABS_HAT0X`/`ABS_HAT0Y`, virtual `FF_RUMBLE`, manage/unmanage recovery, and UART health. Physical L2 and R2 are digital GPIO buttons, `BTN_TL2` and `BTN_TR2`. The capability map sends them as trigger values, so the virtual pad writes binary `ABS_Z` and `ABS_RZ`: 255 pressed and 0 released, matching the axis maximum from `EVIOCGABS`. A typical routing estimate is about 1.8 ms: about 1.25 ms expected poll wait plus about 0.56 ms measured average internal work. The 1.8 ms figure is partly inferred. Managed idle cost was about 13.0 MiB RSS and about 1.5% of one core. The Phase 3 driver, the 10 ms debounce, and the UART path stay as they are. Event-driven InputPlumber evdev is a later candidate. Details are in `docs/research/inputplumber.md`.

### 4C — NextUI handoff and player policy

NextUI switches from the physical device to the virtual controller after InputPlumber is ready. Settings → Joysticks temporarily unmanages only the built-in source. Player order is external controllers first, built-in last, independent of HDMI and of `/dev/input/eventN`.

### 4D — Application cutover

Retarget RetroArch, standalones, and other controller applications to the virtual device. Remove leftover physical-name lookups that Phase 4 no longer needs. External controller models are not a completion test on this unit.

### Start optional

The old "package it experimentally" step is Phase 4A. It is not optional, and it is not a first-frame service.

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
