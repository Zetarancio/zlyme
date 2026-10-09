# Zlyme roadmap and sequencing

This roadmap is ordered to minimize overlapping variables during hardware bring-up.

The Miyoo Flip (`my355`) remains the only supported device.

`ROADMAP.md` is sequencing guidance, not the current architecture specification. Current architecture and invariants live in `AGENTS.md` and the canonical documents under `docs/`.

## Current phase

Phase 11 is closed. It is `zlyme44.2`: related user-facing fixes, separate commits, and a small number of OTA candidates. Phase 10 is closed. Source and documentation closure and `zlyme44.1` device validation are complete. The accepted runtime/source SHA is `6a398b311310246ef6a5515ed72805c6f58d787d`. The accepted local root SHA-256 is `9e4f8a772b04e937a87b92ed4ffd5e950b756bcbcf0beda55c1b7b0744058b65` (`zlyme44.1 (2026-10-05)`). `zlyme44.1` is still unpublished. GitHub Actions run `37375071442` is the outstanding clean-build and release gate for that release. Finishing that run is release administration, not unfinished Phase 10 implementation. The statement that no `zlyme44.2` work had started was the state at Phase 10 closure. Phase 11 is the work that follows it. `zlyme44.1-maintenance` stays frozen at the accepted runtime SHA. The hardware wiki stays on published `zlyme44` until `zlyme44.1` is published. Phase 11A, Phase 11B, and Phase 11C are hardware-accepted. Phase 11D, closure and release handoff, is complete. It does not wait for a later `zlyme44.1` or `zlyme44.2` build, and it has no field-aging gate. `zlyme44.2` is not a published release. The remote candidate build after the merge is the release pipeline. It does not keep this phase open. Standalone stock-side preloader helpers were packaged after that closure. On 2026-10-08 one Flip hardware-accepted the restore helper, the MASKROM helper from the repaired preloader, the MASKROM helper from the original stock preloader, the following right-slot Zlyme boot, and `disarm-recovery`. That acceptance is this unit's image pair. It is not new Phase 11 evidence, and it does not accept every vendor SPL revision.

2026-10-09: PortMaster's live installation moves to the selected library. The system image keeps `PortMaster.zip` as the seed. Legacy state is merged before the Zlyme integration pass. Reset PortMaster is on the Game page. A verified Recovery write offers shut down or a normal restart and does not write again in that Settings session. MASKROM entry stays a cold boot with the right-hand card removed. This is not hardware-accepted. `zlyme44.2` is not a published release.

Phase 9 implementation is closed. The accepted runtime SHA is `337ccbce2587393463a4b49c551f94e33e318e44`. The maintainer hardware-accepted that image (`zlyme44 (2026-10-03)`, installed root `9462f77f78bb750680b36f1ab720ef22e6954be6d76f7caab5127b7010288213`). `main` was fast-forwarded to that SHA. GitHub Actions Build run `37164297221` built it from a clean tree and succeeded on 2026-10-04. It published the first stable release, `zlyme44 (2026-10-04)`, tag `zlyme-37164297221`, which points at that SHA. That closed the Phase 9 release gate. A documentation commit does not replace the runtime SHA. "Complete and hardware-validated through zlyme43" below is the Phase 3 calibration result, not the current product.

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
Phase 4C COMPLETE — 2026-09-26
Phase 4D COMPLETE — 2026-09-28
Phase 4 COMPLETE — 2026-09-28
Phase 5 COMPLETE — 2026-09-28
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

Userspace stores the displayed percentage as `gain=N` (`N` 0..100) in `/storage/.config/zlyme/miyoo-flip-gamepad/rumble.config`. This 2026-09-25 pass used a missing-file default of displayed 30%. Phase 9 later changed that missing and invalid default to 40%. A missing file is still not created by restore. An invalid file is reported, applied as the current default, and is not rewritten. A saved file stays authoritative. Conversion to `FF_GAIN` is the only Flip motor compensation: displayed 0 stays 0, displayed 10 becomes 15, displayed 30 becomes 34, and displayed 100 stays 100. Fresh Haptic feedback is enabled. An existing `haptics=` value is left alone. A haptic before `rc.late` can still see the kernel's 100% `FF_GAIN`. That stays behind the first-frame gate. Settings → System → Joysticks has Rumble Strength (10% steps, live apply, A saves, B restores the value from screen open) and Test Rumble (about 250 ms, full effect magnitude, so `FF_GAIN` still scales it). `rc.late` runs `zlyme-gamepad-ff restore` after calibration restore and after `nextui-first-flip`. `PLAT_setRumble()` prefers the exact name `Miyoo Flip Gamepad`, then a name containing `retrogame`, then any other `FF_RUMBLE` device. Settings → System → Haptic feedback only enables or disables NextUI's own pulses. Those pulses still go through `PLAT_setRumble()` and are scaled by Rumble Strength. `VIB_doublePulse` / `VIB_triplePulse` scale twice if called, but nothing calls them.

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

Complete — 2026-09-26. The persistent OTA `e911db674811` was installed and accepted on the Miyoo Flip. InputPlumber starts after the first frame. There is one composite and one `xb360` target per player controller. External controllers stay ahead of the built-in pad, in their relative order, with the built-in pad last. `release` and `reclaim` return only when the built-in target state is ready, and the same `zlyme-input` process restores management after an InputPlumber restart. Settings → Joysticks is the physical-maintenance exception and releases only the built-in composite. Printed A/B/X/Y match Xbox A/B/X/Y, and digital L2/R2 are binary trigger axes. MENU remains Guide; NextUI takes `BTN_MENU` timing from the raw guide button because SDL holds Guide for 250 ms. Virtual `FF_RUMBLE` reaches the motor. Volume, power, and the lid switch stay outside InputPlumber. External-controller ordering is source policy; specific external models were not part of this acceptance.

### 4D — Application cutover

Complete — 2026-09-28. The accepted image is `zlyme-my355-20260927-0b139e9099ee.tar` from `0b139e9099eec699e31d1cb5313998f57f387e12`, SHA-256 `9bedb4874f8a834c362fc9cccbd61aaece882595ac221865128ae6a3a4f3437e`. Application exit and in-pak brightness read each InputPlumber `xb360` target. MENU+START on one virtual controller exits the pak. Volume, power, and the lid stay on their own devices. Shipped controller consumers use that virtual xb360 pad. On that installed image, PPSSPP showed a picture with working audio and controls, MENU+Volume changed brightness in a pak, and RetroArch, PICO-8 Splore, and PortMaster launched, took the controller, and returned to NextUI on MENU+START. PPSSPP 1.19.3 presents through the SDL KMSDRM window (`USING_EGL` off). Details are in `docs/research/inputplumber.md`.

Phase 4 is complete. 4A through 4D are accepted. Phase 5 research is recorded in `docs/research/kernel-patch-audit-phase5.md`. No Phase 5 patch has been added or removed.

### Start optional

The old "package it experimentally" step is Phase 4A. It is not optional, and it is not a first-frame service.

## 5 — Second kernel patch reduction pass

Complete — 2026-09-28. The accepted runtime is `7eaecf794830a15c53f6b417a1b408dd31ceee53`. The accepted image is `zlyme-my355-20260928-7eaecf794830.tar`, SHA-256 `71a7fbc507d7e725641d1d6ed8d8b3856e40e438adaf6ee832323ddd31fd1947`. On the Miyoo Flip that image booted to NextUI. Built-in d-pad, ABXY, both sticks, and MENU worked. One emulator took those controls and MENU+START returned to NextUI. Bluetooth could be enabled and scanning worked. Volume, one suspend/resume cycle, and a clean shutdown passed. Controller pairing was not part of the gate.

Phase 5 started from eighteen Linux patches on Linux 7.0.2. Phase 5A removed the `input-polldev` restoration, the adc-keys joypad export, and the RK817 ON/OFF diagnostic log. Phase 5D removed the shared UART1 `dma-names` patch and the historical Bluetooth SSP patch. Thirteen patches remain, in application order: `0005`, `0001`, `0002`, `0007`, `0008`, `0666`, `1001`, `1010`, `1012a`, `1012b`, `1013`, `9901`, `0006`. Retained filenames were not renumbered.

`0007` still clears `SYS_CAN_SD`. With that bit set the off current is about 8 mA. With it clear, about 0.05 mA. An overnight unplugged power-off left `OFF_CNT` at 50, `BAT_CON` clear, and `SYS_CAN_SD` clear. `PWRON_VOL` was 3.947810 V. The Flip OCV table returned 82%. `Q_INIT` was about 2.460 Ah. The visible gauge was about 81% after the measured runtime load. That `OFF_CNT >= 3` reseed was reproduced and matched the table. Phase 5 did not adopt RK817 `001`, `002`, or `008`. Patch `001` corrects a saved-SoC ceiling. On the reachable 7.0.2 boot paths that were observed, that corrected value is overwritten before display, so an `001`-only image was not justified. `005` stays with Phase 6.

`1010`, `9901`, and the GPU suspend/power-domain question stay with Phase 6. `1012a` and `1012b` stay with Phase 7. Phase 6 has not started. The evidence note is `docs/research/kernel-patch-audit-phase5.md`.

After that hardware closure the maintainer corrected the retained kernel-delta policy. The image above remains the tested Phase 5 result and is no longer the intended final patch stack. The correction applies sixteen Linux patches: those thirteen, plus `0021`, `0030`, and local `0003`. `0021` keeps `dma-names` beside the RK356x UART1 DMA descriptors. The Flip DTS enables UART1, selects the CTS pinmux, and owns the gamepad child; it does not repeat `dma-names`. The effective Flip UART1 node is unchanged. `0030` is a DEBUG probe log of the ON and OFF source registers. It only reads those registers. `0003` is ROCKNIX patch `001` and changes the NVRAM SoC ceiling from `10000` to `100000`. That bounds check was objectively wrong. On the observed Linux 7.0.2 boot paths the saved value is still replaced by the coulomb counter or the `PWRON_VOL` OCV result before it is displayed, so `0003` does not fix the overnight reseed. ROCKNIX `002` and `008` stay disabled. `005` remains a Phase 6 evaluation. `0007` stays as it was. The Bluetooth SSP patch, `input-polldev`, and the adc-keys joypad export stay removed.

That corrected stack is accepted on the Miyoo Flip. The runtime is `8119387e0fdb729f1f013bed9dbc48c76e37a1df`. The image is `zlyme-my355-20260928-8119387e0fdb.tar`, SHA-256 `4b831245e8f25ba8f1f1960021917ad631f6df734cb83bc589aa73981da292ae`. Boot to NextUI, built-in controls, one game with MENU+START, volume, Bluetooth enable and scan, one suspend/resume, a plausible battery percentage, and shutdown passed. At 1.118675 seconds the probe logged `ON_SOURCE=0x02 OFF_SOURCE=0x08`, so the DEBUG facility is working. `7eaecf794830` stays the original Phase 5 closure image. `8119387e` is the intended baseline entering Phase 6. Phase 6 has not started.

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

**Phase 6 — COMPLETE.** The accepted runtime is `b709719aac5c5540394d0369e5e06981b8aa00bc`, image `zlyme-my355-20260928-b709719aac5c.tar`, SHA-256 `02cd1d769d146bb71d11631dcc649d0cdc5b041c0b202c93053ab324497332ba`, kernel `Linux 7.0.2 #2 SMP PREEMPT Mon Sep 28 14:31:17 UTC 2026`. Later commits on `phase-6-deep-suspend` are documentation and research only. No replacement Phase 6 OTA was built to close the phase. Evidence is `docs/research/deep-suspend-phase6.md`.

The shipped ABI is `compatible = "rockchip,pm-rk3568"`, `sleep-mode-config = 0x5ec`, `wakeup-config = 0x10`, `sleep-debug-en = 0`, BL31 `rk3568_bl31_v1.44.elf`. Linux mem sleep is `s2idle [deep]`. Firmware returned `res.a0=0` for `LINUX_PM_STATE` `cfg1=0x3`, mode `cfg1=0x5ec`, and wake `cfg1=0x10`. Phase 6D turns `vdd_logic` / RK817 `DCDC_REG1` off in mem suspend and keeps `regulator-always-on` and `regulator-boot-on`. The mask still includes `RKPM_SLP_ARMOFF_LOGOFF`. Repeated maintainer power-button cycles passed. The exact total is not in the ring buffer.

Phase 6C covered the normal NextUI path and the in-game path. Display, audio, the built-in pad, and the virtual Xbox 360 pad returned. `/storage` stayed usable. Wi-Fi and SSH returned. DMC devfreq stayed present. `mali_kbase` stayed loaded. No filesystem corruption and no Oops, panic, or hung task attributable to deep suspend was observed. An SSH suspend that slept twice was a userspace artifact: it bypassed `PWR_sleepNow()`, so `pwr.resume_tick` was never armed. It was not a BL31 failure, a kernel retry, or a firmware wake failure. The `xHC error in resume, USBSTS 0x401, Reinit` line recovered with the USB radio. Lid policy was not given a separate deep-suspend test and is unchanged.

`CONFIG_ROCKCHIP_PM_CONFIG=y` stays built-in. The per-suspend `.prepare` path is part of the firmware configuration, and that built-in driver is what the hardware test ran. The module question is closed: keep built-in. Successful `dev_info` lines at probe and suspend stay. They are low-frequency ABI diagnostics. Changing their level would be a new kernel runtime, so it is not part of this closure.

DFI `1010` stays applied. Deep suspend did not show a fatal DFI or DMC resume failure. Dynamic DMC scaling is Phase 7, so `1010` is kept through Phase 6 and re-evaluated with the DMC module lifecycle in Phase 7. The deferred ROCKNIX GPU power-domain change was not imported. No GPU resume failure required it.

RK817 `001` stays applied as local `0003`. `002` stays disabled. `005` stays unapplied: Test A showed no discharge jump, charging ratio 1.22 did not repeat at 0.98, and the published fallback only credits an under-count. `008` stays disabled. `0007` is unchanged. Phase 7 does not reopen those gauge decisions.

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

Closed: **keep built-in**. `CONFIG_ROCKCHIP_PM_CONFIG=y`. The hardware-proven driver registers with `builtin_platform_driver` and reprograms BL31 from `.prepare` on every suspend. Turning that into a loadable module is not part of Phase 6.

### Gate

Phase 6 is complete when:

- the stock/BSP-compatible RK3568 suspend configuration is implemented;
- BL31 accepts the required SMC calls;
- Linux deep mem suspend enters and resumes;
- `vdd_logic` off-in-suspend works with `ARMOFF_LOGOFF`;
- repeated physical power-button suspend/resume works;
- normal NextUI suspend/resume works;
- in-game suspend/resume works;
- display, audio, and input recover;
- persistent storage remains healthy;
- normal networking can recover;
- no serious kernel or filesystem failure attributable to deep suspend remains;
- RK817 sleep-gauge behavior has been evaluated and given an explicit disposition.

These are useful extended checks and are not closure blockers: dozens of cycles, every USB-host attached and unattached combination, a full Wi-Fi/BT on/off matrix, a quantitative standby-current measurement, and DMC dynamic-scaling validation. DMC scaling and the DMC module lifecycle are Phase 7. Standby current characterizes power. It does not prove that the suspend architecture resumes. USB and Bluetooth combinatorial stress is extended regression coverage, not a prerequisite for accepting the proven BL31 and `vdd_logic` design. Those extended checks were not claimed as done. Lid behavior keeps the existing userspace policy and was not a separate deep-suspend closure test.

`vdd_logic` off-in-suspend was enabled together with BL31 `ARMOFF_LOGOFF` (`0x5ec`) and resumed.

## 7 — DMC driver modularization / patch extraction

**Phase 7A — HARDWARE ACCEPTED.** Image `zlyme-my355-20260929-81c7fc87331d.tar`, SHA-256 `ebec9766147adf6ef69d64240834f4510eca474a6586a39376aa73ee828669c3`, runtime `81c7fc87331d5f4c8ab3d39d6da7e6b28dc06ffb`, kernel `Linux zlyme 7.0.2 #1 SMP PREEMPT Tue Sep 29 23:34:11 CEST 2026`. The only change from the Phase 6 kernel was `CONFIG_ARM_RK3568_DMC_DEVFREQ=m`. `rk3568_dmc` autoloaded from the `rockchip,rk3568-dmc` modalias. Before any SSH governor command the live state was `powersave` at 324/324/324 MHz. Observed rates were 324, 528, 780, and 1056 MHz. One physical deep suspend left the same module loaded and Smart at 324 MHz. The BL31 `.prepare` calls returned `res.a0=0`. A `_regulator_disable` warning from `mali_kbase` `pm_callback_runtime_off` is not a DMC failure.

**Phase 7B — HARDWARE ACCEPTED.** Image `zlyme-my355-20260929-b3bb23748aa6.tar`, SHA-256 `53931e4f039ab01eecd9e1e838288969558b11ef144ad735e4ee6d1a0aed8527`, runtime `b3bb23748aa64742416ac477dea620e7c72ee8e2`. The module is `/lib/modules/7.0.2/updates/rk3568_dmc.ko`, SHA-256 `2a713b1bc0ce8f5ecf669319fa2000c7c486dcd5c8f4796bd182d82e9afc3e4c`. It autoloaded, held Smart at 324 MHz, changed rate under Play, and survived one physical deep suspend with the same post-resume Smart state.

**Phase 7 — COMPLETE.** The DMC driver is the external package `package/drivers/rk3568-dmc`. It installs at `/lib/modules/7.0.2/updates/rk3568_dmc.ko` and autoloads from `rockchip,rk3568-dmc`. The Device Tree contract is `package/drivers/rk3568-dmc/README.md`. `1012a` and `1012b` are removed. `1010-devfreq-event-rockchip-dfi-add-pm-suspend-resume.patch` stays, because DFI is still the in-tree load provider and the accepted suspend tests ran with that PM restore. Sixteen Linux patches remain.

The physical hardware acceptance point is runtime `21de8081d6e6a419d708e8f3c792e4f1357eaafc`, image `zlyme-my355-20260929-21de8081d6e6.tar`, SHA-256 `ecd2d58a3b6060c8aed320ca411c742138649d8f0c13c00eba81c292c7b87f5a`. That installed module SHA-256 is `f0b8739266ad67d9ba94ebecb5a874603e7d6773ecbbfda42cb085035633715d`. It autoloaded, stayed at `powersave` 324/324/324 MHz before any governor command, changed rate under Play, and survived one physical deep suspend. `.prepare` returned `res.a0=0` for `LINUX_PM_STATE` `0x3`, mode `0x5ec`, and wake `0x10`. Storage, both pads, Wi-Fi, and `mali_kbase` recovered. The `_regulator_disable` warning is `mali_kbase` `pm_callback_runtime_off`, not a DMC failure. After wake, Play moved DDR off 324 MHz and Smart restored 324/324/324.

Commit `70acb1d27443447df84903e2043a2af05dbd9ee3` is the later source correction. After `DRAM_SET_RATE` has been issued, a failed upscale keeps the raised center voltage instead of rolling it back. It was accepted by source review, `git diff --check`, and a clean `rk3568-dmc-dirclean` plus `rk3568-dmc` rebuild. That module SHA-256 is `0a6ace5494d1b2cae787a58a556170bd3c6d8dbcc224a2ad710ea85fd8440016`. It was not given its own hardware test: it changes only that failure path, those failures were not induced, and the successful target and suspend sequences are unchanged. All four Flip DMC OPPs are 900000 µV, so the accepted image did not move the rail between those rates.

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

## 8 — Frontend source ownership, platformization, and performance

Detailed findings: `docs/research/frontend-source-phase8.md`.

Do this in order. Do not combine the fork with a LoveRetro version bump. Do not comment out large regions of upstream code. Prefer a build exclusion, a platform or feature conditional, or deletion of code that exists only in the Zlyme tree and is demonstrably dead. Leave harmless upstream code in place when removing it would only add merge conflicts.

1. **Storage preflight.** Done. ZLYMEBOOT stays read-only and the squashfs loop is read-only (`loop0/ro=1`); a shutdown-time remount of `/boot` is not the mechanism. Primary `/storage` is unmounted with a normal `umount` before `reboot -f` / `poweroff -f`. Both were hardware-accepted. Do not add boot-time fsck or repair the inherited exFAT dirty bit in this phase.
2. **Baseline.** Keep a measured known-good frontend (first frame and a normal menu path) before moving source.
3. **Fork from the vendored pin.** Reconstruct Zlyme's NextUI as commits on LoveRetro `ae652648548edf6ab24cbb816cf4e4194e609fb3`, not on current upstream HEAD. Preserve PolyForm Noncommercial 1.0.0 and the LoveRetro / MinUI attribution.
4. **Fetch the fork.** Switch `nextui.mk` from `SITE_METHOD=local` to that exact commit after the tree matches current behavior.
5. **Platform boundary.** Device code stays in `workspace/<platform>` (`workspace/my355` today). `BR2_PACKAGE_NEXTUI_PLATFORM` remains the selector. Joystick-calibration UI visibility is part of this boundary.
6. **MinUI helpers.** Vendor `minui-list` 0.15.2 and `minui-presenter` 0.13.2 in-tree, with upstream repo, tag, and commit recorded. There is no source delta today; vendoring is so later platform edits stay local and reproducible. Build the vendored trees. Derive the platform from `BR2_PACKAGE_NEXTUI_PLATFORM`. Do not create GitHub forks just to vendor them. Do not bump to `0.15.4` / `0.13.4` in the same step; evaluate those tags only after the vendored build matches current behavior.
7. **Equivalence.** Current user-visible behavior stays, or the change is written down. Targeted frontend builds. One incremental device image is allowed to prove the migration. Source or build comparison is not hardware acceptance.
8. **Upstream, after that.** Current LoveRetro HEAD at research time was `a0628cdc0cee8e173a9bb94144f5c8baa22ab8e7`, two commits past the pin. Rebase only once the fork matches today's image. Re-fetch HEAD at that time.
9. **Profile, then optimize.** First frame, menu frame time, extra filesystem I/O, image and font loads, redraws, allocations, logging, controller enumeration, Settings startup. `-O3` is not a substitute for a measurement.
10. **Dead code.** Drop or exclude only what the image cannot reach. A full clean Buildroot build is not required at the end of this phase.

### Gate

- Storage preflight is already hardware-accepted: `/boot` read-only, `loop0/ro=1`, and a normal `umount /storage` before forced reboot.
- Frontend behavior matches the pre-migration baseline, or differences are documented.
- Buildroot fetches a pinned Zlyme NextUI commit.
- `minui-list` / `minui-presenter` are vendored at the current tags, platform-neutral, and behavior-equivalent. Newer tags are not mixed into that step.
- A profile exists for the paths that were optimized.

Status, 2026-09-30: Phase 8 is complete. The hardware-equivalent runtime is `7a0fc397cb5b3e0f7c4b19f4f3abe8626eaccaf8`, image `zlyme-my355-20260930-7a0fc397cb5b.tar`, SHA-256 `eff4cd7643b32f53ed7bb284bbc6b3c60732f54da85527150de19c358f1a9bac`. The later commit `b7c5a19` excludes build-only `res/branding/` from the target. That exclusion was checked in the build tree and was not given a second hardware OTA. It does not change the accepted runtime. Other-platform NextUI source stays in the fork. Upstream pins were not moved. The profile did not justify a frontend optimization.

## 9 — Product polish, integrations, and release preparation

Detailed dispositions: `docs/research/product-phase9.md`.

Group related work so one implementation and test cycle covers a subsystem. README updates ride along with each user-facing change, and the release gate below still reconciles the README against the last non-prerelease. No OTA per text or default tweak. Items already implemented or intentionally designed (trash globs, the three PortMaster directories, `/tmp/poweroff` through `zlyme-halt`, RTL8723FU Bluetooth firmware) are not reopen tasks. Do not start this work until the Phase 8 closure is on `main`.

Detailed governor and gpSP notes: `docs/research/product-phase9.md`.

1. **Emulator speed and governor policy.** This comes before cosmetic Settings work. GBA is the known regression. Two decisions are already made. Update libretro-gpsp from `4caf7a167d159866479ea94d6b2d13c26ceb3e72` to exactly `8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f`, the gpSP revision in ROCKNIX `next` at `a55d58a1209b35e287dd55a3aad67a5543b467ce`. KNULLI `knulli-main` at `6a23957a19a1df18989ac6aa5e9fff003ae611ed` carries the older gpSP `d6decfa351b575e2936afebba26d41ec20e4ddcd`. Take the newer of those two carried revisions. Do not move to current libretro/gpSP HEAD, and do not pick a commit past the ROCKNIX pin. The February 2024 Zlyme pin is history, not a candidate. Inspect the delta and the Zlyme recipe for build compatibility. Do not add a `gpSP.opt` override just to restate the upstream default sound rate of 32768. Adopt SpruceOS `2b7bc4a79359de14ea4d4f00da9801a937e2846d` per-system `scaling_min_freq` values as the CPU minimum floors. Do not invent replacement floors, and do not collapse a Spruce system back to a generic play/heavy minimum. Do not copy Spruce's ondemand governor, two-core Smart layout, or DMC policy. Zlyme keeps schedutil, the existing online-core counts, and the existing in-game DMC and GPU behavior. Resolve each Spruce floor to the lowest mainline OPP that is greater than or equal to it: 240000 and 312000 become 408000, 648000 becomes 816000, 1008000 becomes 1104000, and an exact OPP stays unchanged. Never round down. `zlyme-governor emu <tag>` owns that table. Launchers pass the tag. `ZLYME_GOVERNOR` from MENU+Y still wins, and that explicit choice is not replaced by the Spruce floor. A system Spruce does not cover keeps the existing Zlyme profile and is written down. Audit every shipped tag in static checks. Gameplay is not a Phase 9A gate; the maintainer may report it later. Zlyme already sets RetroArch `video_threaded = true`.
2. **Correctness.** Save format, save-state format, and extracted-file-name rows are hidden on my355. Shared NextUI still stores them and still shows them on other platforms. Zlyme's RetroArch launcher does not consume them. Wi-Fi country is the global `country=` line in `wpa_supplicant.conf`; no line means World/default. Diagnostic logs keep five system boots and three PAK launches. Timezone presentation is `/etc/localtime` pointing at the storage zone file. `S15` seeds that file before returning. `S49ntp` sets the system clock from the HTTP `Date` header as UTC and writes the RTC with `hwclock -u -w`. A timezone change does not write the RTC. The Bluetooth status pill drops when the radio flag is off. GZDoom already reads the virtual pad through SDL joysticks. Orphan cleanup is an indexed same-card scan with a dry-run before DELETE. Standalone reset deletes settings files only. VTree settings persist, with hidden files on for a new config. `FSCK*.REC` is a historical FAT recovery name, not a current writer.
3. **Settings.** Done: Quick Menu, keyboard L1 DELETE, no CLTMP hint on my355, VTree hidden files, rumble default 40%, Time zone, Advanced (GPU, undervolt, ZRAM, OTG, HDMI, second SD, logs, Reset Settings, Factory Reset), one reboot prompt for `gpu` / `undervolt` / `otg` / `hdmi` / `sd2`, and pill rows for the per-game governor and emulator. The selectable A/B swap was dropped in Phase 9K; the built-in map is fixed. PortMaster keeps upstream `default_theme`. A `Zlyme` color scheme derived from Darkest Mode is the fresh default, with selected text `#FC9C14`. The separate cloned `themes/Zlyme` theme is removed. A stored selection of that obsolete standalone theme converts once to `default_theme` with the `Zlyme` scheme. A later user theme or scheme choice is kept. CPU undervolt stays off until the L1 voltage delta and failure evidence are written down; L1 remains selectable. The exact reset file list is in `docs/research/product-phase9.md`.
4. **Library and launch.** Done: PortMaster location through the existing `HM_*` variables, guarded formatting of removable media, one overlay assignment per content directory, separate native PICO-8 and Fake-8, per-ROM delete, and splash only when the kernel command line has a `quiet` token. Phase 9K supersedes "BIOS and saves follow only the ROM library": BIOS is a runtime union of every mounted library, with the game card winning duplicate paths, and saves pick one writable library (existing data across cards, game card wins, new saves on the game card). Each winning card keeps its own tmpfs BIOS view, so switching cards does not rebuild the other view. The synthetic Splore row is created by `zlyme-storage` in the Pico-8 folder of the library that holds the native runtime, with a `000)` sort prefix so it is the first row. Downloaded carts stay under `Pico-8-native/bbs/carts` and open through `PICO.pak`. The graphical splash is the product boot, including update progress. A non-quiet LCD text console was tried and dropped. The command line is `quiet` plus `console=ttyS2`. Native PICO-8 can find `Bios/PICO/pico8_64` and `pico8.dat` on any active library. Splore downloads land in `Pico-8-native/bbs/carts`. CPU undervolt stays off.
5. **Optional PAKs.** Ruffle and Music Player stay. Artwork Scraper and Cheat Downloader are removed. ZcrapeGoat, the Zlyme integration of ScrapeGoat, is the sole built-in ScreenScraper artwork, metadata, and manual tool, and the sole Libretro cheat installer. `BR2_PACKAGE_ZCRAPEGOAT` compiles `package/system/zcrapegoat/src/`: a pristine upstream v2.3.0 import at `c52f749eae21a4c02c767e485fef2abbb773f2d7`, then normal Zlyme commits, with no ScrapeGoat patch stack. The PAK is `Tools/ZcrapeGoat.pak` and the binary is `/usr/lib/zlyme/zcrapegoat/zcrapegoat`. Private state is `/storage/.config/ZcrapeGoat`. Nothing migrates `/storage/.config/ScrapeGoat` or `.userdata/shared/ScrapeGoat`. Libraries are the lines in `/run/zlyme/libraries`. Artwork is written beside the actual ROM, under `.media`. Installed cheats stay at `/storage/Cheats` and do not follow the ROM card. ScreenScraper developer credentials are private build inputs, from the ignored file `package/system/zcrapegoat/credentials.local` or the GitHub Actions secrets `SCREENSCRAPER_DEV_ID` and `SCREENSCRAPER_DEV_PASSWORD`. The credential-bearing compile disables ccache. Pak Store stays deferred past the first stable release. Flash is the pinned `SilverPsychoo/Ruffle-Handheld` v4.2 appliance: small Zlyme launch/environment glue only. Do not maintain a Zlyme Ruffle frontend, do not swap in current official Ruffle, and do not take on renderer or runtime patches. Music Player is a direct pinned integration, not a Pak Store delivery. Do not keep Music Player's own cpufreq writes. Do not put the Libretro cheat database in the image.
6. **Release cleanup.** The Weston test PAK is off the production image. Weston and `zlyme-weston-run` stay. After a successful OTA, the OS card loses only the exact stale stock paths `Tools/my355/Weston.pak`, `Tools/my355/Artwork Scraper.pak`, `Tools/my355/Cheat Downloader.pak`, and `Tools/my355/ScrapeGoat.pak`. The dead-file audit runs after the Phase 9 surface stops moving. The Actions build writes the full log to an artifact and prints the tail on the job console. Community text for other RK3566 ports can wait until after the first stable release and is not a Phase 9 release blocker.
7. **Incremental OTA transport.** A maintenance release may publish zstd `--patch-from` deltas beside the full OTA. The device reconstructs a complete squashfs on `/storage`, checks its SHA-256, and only then writes `/storage/.update/pending/zlyme`. The existing boot-apply and initramfs copy are unchanged. Never patch `/boot/zlyme` in place. A baseline version (`zlyme44`) publishes a full OTA only. A point version (`zlyme44.1`) may add direct deltas from the same-major baseline and the last three same-major point releases. The installed root hash, not the version string, decides whether a delta applies. Local `build.sh` does not generate deltas or query GitHub. Details are in `docs/research/product-phase9.md`.

### Gate

The earlier plan started the remote clean build in parallel with the local smoke OTA and held `main` until that clean artifact was hardware-accepted. That is superseded. The process below is the one this closure follows.

After the product work, in order:

1. Finish the Phase 9 product changes on `phase-9-product`: remove Artwork Scraper and Cheat Downloader, make ZcrapeGoat the sole scraper and cheat integration, replace the cloned PortMaster theme with the `Zlyme` scheme, and add the stale-PAK post-update cleanup.
2. Reconcile the README with the last non-prerelease GitHub release, `zlyme40 (2026-09-23)`, tag `zlyme-35854070921`. Ignore `zlyme43 (2026-09-28)` because that release is a prerelease. The README must describe the user-facing behavior the final image actually ships: emulators, Tools/PAKs, Settings, and install/update steps. Do not describe deferred or experimental work as supported. Ride-along README edits during the phase do not replace this pass. Keep joystick text to calibration, deadzone, the stick test, rumble, and that built-in controls work in games. GPIO, UART, force-feedback, and InputPlumber topology stay in the technical docs. Remove or rewrite the claim that core pinning and per-emulator performance settings are the SpruceOS policy; Zlyme's current policy is not that per-system Smart table. Run the dead-file audit in the same reconciliation, limited to files Phase 9 made obsolete.
3. The closure candidate is `zlyme44`, a new baseline. Do not attach a build date to `ZLYME_VERSION`. Artifact filenames and the displayed build date are generated when the image is built. `zlyme44` publishes a full OTA and a manifest with zero deltas. Later `zlyme44.1` and `zlyme44.2` may publish same-major deltas. `zlyme45` is the next full baseline. A delta applies only when `from_sha256` equals the SHA-256 of the installed squashfs.
4. Local validation does not wipe the Buildroot output tree. Clean and rebuild the Phase 9 packages that remain shipped, and the packages this pass changes, then build one incremental image with `./build.sh --config zlyme_my355_defconfig`. Do not dispatch GitHub Actions for that proof.
5. The maintainer installs that one local OTA. Phase 9 is not closed, and `phase-9-product` does not move, until that image is hardware-accepted.
6. After that acceptance, `phase-9-product` may fast-forward into `main`.
7. Immediately after that merge, the maintainer may dispatch the GitHub Actions `Build` workflow from that exact Phase 9 SHA. The runner starts from an empty Buildroot `output/`. Restoring compiler ccache is allowed. That is the full clean-build proof. It is not started during the local closure pass.
8. Phase 9 implementation closure does not wait for the remote build to finish.
9. The remote clean build remains the reproducibility and release-artifact gate. A failed remote clean build still requires a correction before a stable release can be considered valid. The local incremental OTA does not prove a different clean image.
10. Pak Store stays post-first-stable. The CPU undervolt default stays off. Community text for other RK3566 ports is not a Phase 9 release blocker.

```text
product work and README reconciliation
        |
        v
targeted package rebuilds, one local incremental OTA
(product version is zlyme44, a full baseline)
        |
        v
maintainer hardware acceptance of that local image
        |
        v
fast-forward phase-9-product into main
        |
        v
dispatch the GitHub clean build from that SHA
        |
        +------------------------------+
        |                              |
        v                              v
Phase 9 implementation closure   remote clean build
(does not wait for the runner)   (release artifact;
                                 failure blocks a
                                 stable release)
```

`ZLYME_VERSION` is `zlyme44`. Dates belong on the artifact that was built that day, not on the version name. Earlier `zlyme43` images stay historical. The published `zlyme43` GitHub release is a prerelease and is left as it is.

Status, 2026-10-02: the maintainer installed `zlyme-my355-20261001-f0143dd5b067.tar` and accepted GZDoom controls and saves, Cheat Downloader navigation, Music song download and radio, Ruffle launch and `Saves/FLASH` persistence, ROM-driven system visibility, and Create game folders under Settings → System → Storage. That acceptance does not keep Artwork Scraper or Cheat Downloader. The maintainer then installed `zlyme-my355-20261002-1f5dab487ee4.tar`. No other accepted surface regressed, and the stale Artwork Scraper, Cheat Downloader, and Weston test PAK cleanup was not reported as regressed. ScrapeGoat did not open: the launcher built a log path from the binary path and died before the program started. PortMaster's Zlyme selected text was too close to white.

The maintainer then installed `zlyme-my355-20261002-daebc6f5dbab.tar` (`daebc6f5dbabf1a2470cba416067b38176034c20`). That image passed the personal ScreenScraper credential flow, `/storage` and SD2 artwork, Libretro cheats under `/storage/Cheats`, `/storage/.config/ZcrapeGoat` with no old ScrapeGoat or `.userdata` state created, MENU+START, removal of `ScrapeGoat.pak`, and the PortMaster Zlyme scheme, orange selection, persistence, and PAK handoff. Still open on that artifact: the logical system list omitted systems whose first library folder was empty, Settings → Manual download directory aborted, About ran past `MIT License.`, and a same-name ROM on two cards was not confirmed on the device. The list and picker failures are the representative-library emptiness check and the Apostrophe POSIX `realpath` fixed-buffer abort. PortMaster stays accepted.

The maintainer then installed `zlyme-my355-20261002-93a6714f658f.tar` (`93a6714f658f659f3cdebf31c2cff155f9b99846`). On that artifact, ScreenScraper artwork works and manual downloading works. Cheats fail before the database clone because ZcrapeGoat looks for Git at `/usr/lib/zlyme/zcrapegoat/resources/bin/git`. No other focused check on that image was reported.

The maintainer then installed `zlyme-my355-20261003-4d4b110b32ea.tar` (`4d4b110b32ead08908504c687df4aaa9da3d4d5d`, root SHA-256 `8d9bcf918053f20702cb78164823aeb85d47672f3e5389028dbd77287fc3747a`). The cheat log selected the PAK Git. A live `ls-remote` failed with `Could not resolve host: github.com` while the link was unstable, and the same clone options succeeded after name resolution worked. Git's fatal text was not in the PAK log. At that moment Phase 9 was not complete and the remote clean build had not been dispatched.

Closure, 2026-10-04: implementation is closed at `337ccbce2587393463a4b49c551f94e33e318e44`. The maintainer hardware-accepted `zlyme44 (2026-10-03)`, root `9462f77f78bb750680b36f1ab720ef22e6954be6d76f7caab5127b7010288213`, including a fresh ZcrapeGoat cheat under `/storage/Cheats/GB` and a root-sized delta reconstruction through the installed updater after `--mmap-dict`. `main` was fast-forwarded to that SHA. Build run `37164297221` built it cleanly and succeeded, and published the stable release `zlyme-37164297221`, `zlyme44 (2026-10-04)`. The release shows 2026-10-04 because that is its image date. The source is the same SHA as the 2026-10-03 image the maintainer accepted.

## 10 — Documentation, maintainability, and cross-repository knowledge

This is not a product-feature phase. Closure, 2026-10-06: Phase 10 is closed. Source and documentation closure and `zlyme44.1` device validation are complete. The accepted runtime/source SHA is `6a398b311310246ef6a5515ed72805c6f58d787d`. The accepted local root SHA-256 is `9e4f8a772b04e937a87b92ed4ffd5e950b756bcbcf0beda55c1b7b0744058b65`. `zlyme44.1` is still unpublished. GitHub Actions run `37375071442` was dispatched from that SHA with `publish_release=false` and remains the clean-build and release gate. Finishing that run is release administration, not unfinished Phase 10 implementation. At this closure, no `zlyme44.2` implementation had started. Phase 11 is the `zlyme44.2` work that follows it. `zlyme44.1-maintenance` remains the frozen release-source branch at the accepted SHA. The canonical procedure is `docs/MAINTENANCE.md`. The research outline in `docs/research/maintenance-phase10.md` stays historical planning material. The hardware wiki stays on published `zlyme44` until `zlyme44.1` is published. Build run `37164297221` succeeded and published `zlyme-37164297221`. That closed the Phase 9 release gate.

### 10A. Zlyme documentation and comments

Review Zlyme-owned code in this repository. Comments explain hardware quirks, safety order, ownership, lifecycle constraints, compatibility, upstream workarounds, and why a magic value or a simpler design is wrong. Do not narrate syntax. Do not comment vendored minui-list, minui-presenter, or parson for style. Do not change the NextUI pin for a comment pass. A comment commit is not a refactor. A functional bug found during the pass is a separate commit.

### 10B. Maintenance playbook

`AGENTS.md` already points at `docs/UPSTREAMS.md`, `docs/DEVELOPMENT.md`, `docs/OPERATIONS.md`, and `docs/ENGINEERING_PRINCIPLES.md`. Phase 10 adds one index, `docs/MAINTENANCE.md`, and points agents at it. It links those documents. It does not replace them. The index covers kernel and ROCKNIX-derived patch review, emulator updates, vendored helper updates, NextUI fork maintenance, and README/release notes. The last non-prerelease remains the user-visible README baseline. Release notes describe accepted behavior. The Phase 9 local incremental OTA is the hardware-acceptance image. The remote clean build dispatched from the merged Phase 9 SHA is the release artifact. Implementation closure does not wait for that runner. A failed remote build still blocks treating a stable release as valid.

### 10C. Wiki synchronization

`Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` already has `AGENTS.md`, `docs/DOCUMENTATION_MODEL.md`, a hardware-versus-implementation hierarchy, and a test for what belongs in the wiki. Keep that model. The published wiki snapshot is `zlyme44`. Do not update that page for an unpublished `zlyme44.1` candidate. After `zlyme44.1` is published, one sync moves the Zlyme snapshot to that release, records the retained U-Boot 2026.01 / BL31 v1.44 / no-OP-TEE serial proof and the accepted shared-card SD2 behavior, and keeps this ownership boundary. Do not paste the Zlyme architecture manual into the wiki.

Ownership stays split. Hardware, electrical, protocol, and firmware facts stay in the wiki. Zlyme packaging, init, policy, frontend, and build architecture stay in this repository. A short statement of how Zlyme implements a hardware mechanism goes in `docs/implementations/zlyme.md` with `Last synchronized against Zlyme <release / exact SHA>`. Joypad protocol stays in the wiki; the driver, InputPlumber topology, and calibration plumbing stay here. BL31/SIP and `vdd_logic` constraints stay in the wiki; the DTS and runtime stay here. The RK3566/RK3568 V2 DMC protocol stays in the wiki; the external module and its policy stay here. Do not mirror Markdown both ways. Historical ROCKNIX evidence stays historical.

### Gate

- Zlyme and the wiki name the same ownership boundaries.
- The wiki Zlyme page uses the Phase 9 implementation SHA for runtime evidence and the Phase 10 documentation SHA for wording. Wiki synchronization with published `zlyme44.1` waits until that release exists. It is not open Phase 10 work.
- Hardware facts found during the roadmap are on the wiki page that owns them.
- Historical ROCKNIX evidence is still marked historical.
- Non-obvious Zlyme-owned code has short comments, and obvious code does not.
- Update procedures are reachable from `AGENTS.md`.
- Documentation cleanup did not change a technical conclusion or a runtime feature.
- Links and paths were checked.

## 11 — zlyme44.2 user-facing reliability and compatibility

Related user-visible fixes ship as a few OTA candidates. Each subphase still uses separate commits. Miyoo Flip (`my355`) stays the only device. `/boot` stays read-only at runtime. The squashfs root stays read-only. Persistent state stays under `/storage` with the owners already documented. Host tests stay in the repository and are not installed into the image.

`ZLYME_VERSION` for this phase is `zlyme44.2`. The date stays on the image, not on that name.

### 11A — Settings, network, updater, and build UX

One candidate covers Settings order, an application proxy, updater reinstall wording, scrollable release notes, and live build progress.

Settings stays `Settings.pak`. The visible label stays `Settings`. NextUI's existing `map.txt` alias `000) Settings` sorts it before the other Tools entries. Those stay alphabetical. No separate C sort. The stored entry keeps the `000)` prefix; display strips it.

Proxy lives at Settings → Network → Proxy: Off/On, HTTP or SOCKS5, host, port, and Test proxy. No username or password. SOCKS uses `socks5h://` so name lookup can go through the proxy. `localhost`, `127.0.0.1`, and `::1` stay direct. One file, `/storage/.config/zlyme/proxy.conf`, is the canonical config. `zlyme-proxy` parses it, writes it by atomic replace, and fails closed on a malformed file. The file is not evaluated as shell. The updater reads it when it makes a request. `nextui-session` applies the validated environment once, at pak launch. Changing the setting does not rewrite the environment of the already-running NextUI process. This is an application HTTP/HTTPS/SOCKS proxy for clients that honor it. It is not a VPN, and it does not cover Wi-Fi association, DHCP, or arbitrary UDP.

The updater may download and reinstall the running release. The same `zlymeNN.M` warns and still allows it. An available root SHA-256 that equals the installed `/boot/zlyme` says the exact firmware is already installed and still allows a deliberate redownload. Delta selection stays the existing `from_sha256` match. Filename and date heuristics are not the decision when the release metadata is present.

Release notes show the release body in a scrolling view, with NextUI's normal button hints. B goes back, Up and Down scroll a line, and L1 and R1 scroll a page. Empty notes and notes the metadata fallback could not retrieve are different sentences.

GitHub Actions keeps the full build log artifact. The job console streams Buildroot `>>>` lifecycle lines and useful error lines while the build is running. The filter does not replace the build's exit status. The staged ccache, timeout, and retry behavior stay as they are.

The README carries a short proxy and update note. The user guide carries the proxy steps.

Gate: host tests, the affected NextUI and Zlyme components compile, no tests in the rootfs, and one local `zlyme44.2` OTA. The maintainer's device check covers Settings order, proxy, same-version update, and scrolling notes. That check is not done by the image build.

Hardware-accepted on 2026-10-06. Zlyme source `64d87e4a20809680b3a02b81246463d34113dd03`. NextUI `bbaafd5aa894d90f75517e7f56c4b35791b19ae8`. Root SHA-256 `6b715f9a7319c65b09385fdfa4bd3b935827ed016eb7efa5e9968e5782aae97e`. OTA `zlyme-my355-20261006-64d87e4a2080.tar`.

On that image, Settings is first in Tools and displays normally. The HTTP and SOCKS5 proxy UI persists. An HTTP proxy and a SOCKS5H proxy both worked on the Flip, and public GitHub release metadata worked through both. Turning the proxy off restored direct access, with no stale proxy left in the helper. Same-version and exact-root warnings remain host-tested; a real release case waits for 11D. Release notes scroll. The native hints are U/D SCROLL, L1/R1 PAGE, and B BACK. A general NextUI and PAK smoke passed. Logs showed no 11A crash. This does not accept the `zlyme44.2` product.

### 11B — Compatibility and runtime

OpenBOR, MKXP-Z, and Wine share one emulator/runtime OTA so they can be tested together. There is no migration. Nobody is relying on OpenBOR, MKXP-Z, or Wine state from earlier Zlyme releases, so 44.2 does not scan legacy paths, copy saves forward, convert a prefix, or keep a second layout. Old OpenBOR and MKXP-Z files may sit unused. The cleanup does not delete `Roms/`, `Saves/`, or `Bios/`. The one discarded object is the exact file `/storage/.config/nextui/my355/wine-prefix.ext4`, a Zlyme-created ext4 image of about 1 GiB. Post-update removes that file and does not read it.

OpenBOR's upstream defaults create `Paks`, `Saves`, `Logs`, and `ScreenShots` relative to the working directory. A package-local patch honors `OPENBOR_PAKS_DIR`, `OPENBOR_SAVES_DIR`, `OPENBOR_LOGS_DIR`, and `OPENBOR_SCREENSHOTS_DIR` when they are set, and keeps those relative defaults when they are absent. The launcher passes the ROM as an argument and does not use the ROM directory as the working directory. Saves use the library `Saves/OPENBOR` tag. Engine paks and screenshots stay under the OpenBOR user directory. Engine log files follow the existing log switch: `/tmp` when system logs are off, and `/storage/.logs/paks/OPENBOR` when they are on. The PAK stdout log stays the primary log. Orphan cleanup no longer treats a `.sav` beside the ROM as an OpenBOR save.

MKXP-Z stays at white-axe `650cb0888a07d0b5044e131160ddfa53feaf595b`. The hardware log already showed Mali GLES 3.1 and ALSA. The launch failure is the content root: an archive whose project sits in one top directory is mounted so `Game.ini` is not at `/Game`. A direct project path, and an archive whose project is at the archive root, stay as they are. One unambiguous wrapper directory is unwrapped inside the core VFS. Anything else fails as it does today. Fonts and FluidSynth wait. The README lists the extensions `retro_get_system_info` actually advertises.

Wine's first 44.2 runtime is Kron4ek 11.6 `amd64-wow64` (vanilla), SHA-256 `045549657b513c2fb191734b0434c81000b36ba4d482d1688bf99f80a8ee07a5`, with Box64 still at `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` (v0.4.4) and Box32 off. The path stays NextUI, release DRM, application-scoped Weston, Wine, Weston exits, NextUI recovers DRM. Persistent prefix files live on exFAT at `/storage/.config/nextui/<platform>/wine-prefix/`. A 1 MiB tmpfs covers only `dosdevices`, where `c:` points at `../drive_c` and `z:` points at `/`. `prepare` creates `drive_c` before that link and copies missing PE builtins plus the x86 WinSxS common-controls DLL, because exFAT cannot store wineboot's symlinks. There is no loop device, no ext4 prefix image, and no fsck. GL4ES, a MIDI bridge, a SoundFont, and gamepad-to-mouse are not in this candidate. They wait for a hardware result that shows they are required. "Wine newer than 11.6 OOMs" stays one observation, not a rule. Linux 7.0.2 already builds `CONFIG_NTSYNC=y`; this candidate does not make NTSYNC a requirement and does not change the kernel for it.

Gate: one OTA. Check that OpenBOR no longer writes into the ROM directory, that MKXP-Z opens a root archive and a one-directory archive, and that Wine runs one 32-bit and one 64-bit program, keeps the prefix across a restart, and returns to NextUI. GL4ES and MIDI are not part of this check.

Hardware-accepted on 2026-10-06. Zlyme source `cdf7f6f4fff73687c173f532e7cb05bdd9d23e67`. Root SHA-256 `80436cfe3e22637efe240d809fbcdd33c84fe3a735c869ea6f6cb25c6a9097e6`. Image version `zlyme44.2 (2026-10-06)`.

OpenBOR launches, does not use the ROM directory as its working directory, and does not leave runtime files there. Return to NextUI still works.

MKXP-Z visibly ran Knight Blade, a one-wrapper archive, and Legionwood Tale of the Two Swords, an archive-root project. That is the layout gate. It is not a claim that every RPG Maker game works. Knight Blade later asks for Standard RTP MIDI, and the WASI FluidSynth `stat` stub blocks that lookup. Witch's House ships an MP3 that libsndfile rejects. Some titles call Win32API functions the libretro sandbox does not provide. Missing-font warnings are not layout failures.

Wine 11.6 `amd64-wow64` under Box64 `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` showed a visible window for `zlyme-notepad64.exe`, `zlyme-notepad32.exe`, and PuTTY x64. 64-bit and 32-bit `cmd.exe /c ver` both exited 0. The exFAT prefix stayed. The `dosdevices` tmpfs was mounted for the launch and gone afterward. NextUI returned with no leftover Weston, wineserver, or Box64. PuTTY x86 can hit an intermittent `c0000409` fast-fail. The 7-Zip 26.04 x86 installer can stay running without a window the maintainer can use. Neither of those is the base WoW64 GUI path. GL4ES, MIDI, DXVK, gamepad-to-mouse, and Box32 stay out of this phase. This does not accept the `zlyme44.2` product.

### 11C — Installation, preloader recovery, and the hardware wiki

Stock-assisted preparation replaces the old user-facing apommel multiboot steps. `miyoo355_fw.img` is not a foreign preloader. Stock runs the installer. The installer reads that unit's preloader, patches the relevant `/pinctrl` data, backs up the original, verifies it, and writes the repaired image. Attribution to `apommel/baseos-my355` stays. Ship `miyoo355_fw.img` on `ZLYMEBOOT`. Generate it from pinned upstream source when that fits the build. Otherwise pin the exact artifact, version, hash, and provenance. Leaving the file on the boot FAT after a successful run is acceptable when stock ignores an already-patched unit. The README and the install guide retire multiboot as the recommended install.

Recovery adds the Buildroot MTD tools the safe path needs: `flash_erase`, `nandwrite`, and `mtdinfo`. There is no general NAND flashing UI. Two operations, both fail closed: restore the stock preloader from a valid per-device backup, and erase the preloader on purpose. The original plan treated that erase as MASKROM entry. The 2026-10-07 report below rejects that claim. Checks, as they apply: my355 identity, the exact MTD partition name, expected size and geometry, battery and charger, a readable backup of the expected size, backup and readback hashes, bad blocks, an explicit destructive confirmation, and no fallback to a device that only roughly matches. Fixture and dry-run tests cover validation and the command line. Automated testing does not erase or restore a live preloader. The maintainer runs those two operations and reports the result. The automated gate is build, static, and fixture proof. Destructive acceptance is `MANUAL — MAINTAINER REPORT REQUIRED`.

The hardware wiki `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` follows its own `AGENTS.md`. Retire multiboot as the recommended Zlyme install, keep the attribution and the history, document the stock-assisted `miyoo355_fw.img` method, and update eraser and restore guidance. Document the Linux-host xrock workaround the maintainer supplied (smaller bulk chunks, a longer timeout, chunked large receives) only after checking the current xrock source. If Zlyme keeps a patch, ship the patch file. Describe it as a Flip-tested workaround for Linux bulk-transfer failures, not as an upstream xrock requirement. Do not update `docs/implementations/zlyme.md` to call a `zlyme44.2` runtime hardware-accepted before the maintainer accepts it.

This candidate generates `miyoo355_fw.img` from `apommel/baseos-my355` `e09d37bb0f03c34e564d61bd02164f332d8515a8` and puts it on a fresh `ZLYMEBOOT`. The ordinary OTA does not. `zlyme-preloader` stays the NAND backend. The product UI is Settings → System → Advanced → Recovery, not a Tools pak. Restore checks the current preloader and its DDR payload before erase, retries a failed write three times, then rolls back to the saved current image. A failed erase does the same and is not reported as MASKROM. Erase removes the SPI preloader. It does not promise USB MASKROM while another loader, including a Zlyme card idbloader, can still boot. MASKROM recovery is the recovery preloader: the vendor SPL boot order is only the right-slot SD. A bootable Zlyme card there still boots Zlyme. No bootable card there resets to the boot ROM. The earlier one-shot boot-file request was removed. A fresh stock-assisted `zlyme.img` install did succeed on 2026-10-07: stock ran the card's `miyoo355_fw.img`, the installer rebooted, and Zlyme booted with root `14b2cd609ba37d66a6414627026af2da30001064429674d16aaa0def5bf97a03`. That accepts the fresh-install path only. It does not accept Phase 11C. The direct Linux MASKROM request on that root logged the restart command and then produced no loader text and no USB `2207:350a`. A physical reset was required. That Linux path was removed. Phase 11C is not hardware-accepted.

Maintainer report, 2026-10-07, not acceptance. `zlyme-preloader restore` performed a real restore: battery 27% with the charger online, the current preloader saved under `/storage/.config/zlyme/preloader-backups/`, `/dev/mtd0` erased, `nandwrite` of the complete 2 MiB image, the backend line `restored original preloader`, and a later `status` that recognized the original backup. That is positive evidence for the restore backend. The same session ran the erase command then named `erase-maskrom`. `flash_erase` completed. The product claim “erase the preloader, and the next power-on enters USB MASKROM” is not an invariant: with a bootable Zlyme card installed, the RK3566 boot ROM can load that card's idbloader. Do not describe a finished erase as MASKROM entry. `Preloader Recovery.pak` did not work for the maintainer and is not the recovery UI. The stock `rbrom` path that did enumerate `2207:350a` is recorded in `docs/research/maskrom-entry.md`. A userspace flag write followed by ordinary `reboot -f`, and the same flag followed by a CRU first reset on an unreliable USB path, did not prove MASKROM. Later the same day the maintainer installed that candidate from a fresh `zlyme.img`, not an OTA. Stock detected `miyoo355_fw.img`, the installer patched the preloader, and Zlyme booted. The Recovery page was present. Both restore confirmations and both MASKROM confirmations kept Cancel as the default, and the final labels were correct. The preloader status text was superimposed and hard to read. The final `REBOOT TO MASKROM` action turned the screen black. The host never saw `2207:350a`. A physical reset booted Zlyme again, and the preloader was still present. One serial diagnostic then ran `sync` and `/usr/sbin/zlyme-maskrom` once. The kernel line was `Restarting system with command 'maskrom'`, and the UART stayed silent afterward. `PMUGRF_OS_REG0` was `0x5242C300` before the request. The platform driver `miyoo-flip-maskrom` was bound to `maskrom-restart`. The USB gadget state was `not attached`. No second MASKROM request was made. PMU OS registers 1 and 4 through 11 are not a proven one-shot handoff: registers 2 and 3 hold DRAM geometry, register 0 is the boot-mode word, and the others are not shown to survive the DDR blob. The direct Linux path is a product failure and was removed. The replacement at that time was the boot-FAT request consumed by U-Boot `rbrom`. Later the same day the maintainer wrote the image from `0e09c31933bd5c429e5f24238307838717231c28`. The fixed preloader status page was readable. Reboot to MASKROM left `/boot/zlyme-maskrom.request` in place and returned to Zlyme. That consumer opened U-Boot `mmc 0:2` (`sdhci`) instead of `mmc 1:2` (`sdmmc0`, Linux `/dev/mmcblk0`). `rbrom` was not reached and is not classified as failed. That request path was later removed. Restore still prefers one per-device `mtd5-original-<sha256>.img`. A missing backup may use the wiki stock image only when the installed preloader is that image's exact patched counterpart. Other revisions are refused. The wiki does not grant redistribution of that vendor preloader, so a public release is not cleared to ship it. Phase 11C is not hardware-accepted.

Closure item recorded 2026-10-08, not done. The development card still runs the diagnostic U-Boot with `CONFIG_BOOTDELAY=5`. That timeout only affects a successful boot into Zlyme U-Boot. It is not part of an SPL MASKROM decision. Before Phase 11C or the zlyme44.2 release is closed, the installed U-Boot returns to production `CONFIG_BOOTDELAY=-2`. `board/my355/board.mk` still writes `-2` when U-Boot is configured. The card image is the exception, and this note does not change it.

NAND cycle recorded 2026-10-08, not acceptance. On the live `fd57d042a890` root, `arm-recovery` installed the derived right-slot image and a full readback matched `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367`. `disarm-recovery` restored `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`, and the full readback matched the saved source. Linux was not rebooted.

Hardware paths recorded 2026-10-08, not closure. With the recovery image installed, a known-good Zlyme card in the right slot booted Zlyme after `Trying to boot from MMC2`. With that card removed, the Nov 02 SPL tried only MMC2, failed voltage select (`mmc_init: -95`), printed `SPL: failed to boot from all boot devices`, and reset to the boot ROM. The host saw `2207:350a`. An `xrock` RAM usbplug used afterward identified the NAND and did not write it. The two hashes are that unit's pair. Phase 11C is not hardware-accepted. The development card still has diagnostic `CONFIG_BOOTDELAY=5` until the production U-Boot from the closure candidate is installed. That install is not part of the source closure.

Production U-Boot recorded 2026-10-08, not acceptance. `zlyme-update uboot` wrote idbloader `2312107bacc63dacb00f333cec93852d46620ddf015ca054bb767e3adf163719` and FIT `38dd59c86c8f4f7745a38cd555a73c2dfe3378ff275ff13ad3565d1bef29b6ee`. Raw readback of those files at 32 KiB and 8 MiB matched. That build has `CONFIG_BOOTDELAY=-2`. Linux booted afterward. The missing UART transcript is not a remaining failure. On the installed root `fdb123fb053f1be82fb2af72ed5dcf43739ffb2aab7df8878afef46439b01606`, `zlyme-preloader status-machine` exited 2 with no output and Preloader status left Settings.

Status page recorded 2026-10-08. The maintainer installed root `9af9a425473639c96695b6415299cfa4944cab9d9fe4547dffbc9738fc8a7ae6`. `/dev/mtd0ro` stayed `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. `status-machine` exited 0 with `mode=normal`, `recovery=ready`, `source_backup=available`, `stock_restore=unavailable`, `backup=unavailable`, and `fallback=incompatible`. Preloader status opened and the rows were readable. That accepts the status collector and the Settings page. This unit has no `mtd5-original-*` backup, so that result is the no-bundle reading. The next candidate restores the known bundled stock image for live image `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. Phase 11C stays open until that candidate reports `stock_restore=available`, `backup=unavailable`, and `fallback=compatible`, and Stock restore on the status page reads Available. Do not arm, disarm, rewrite U-Boot, or collect UART for that check.

Closure, 2026-10-08. Phase 11C is hardware-accepted. Local candidate `4783f6989f12da25bb6b8a1f6423a9f6aab02d18`, root `b61cb24b4712c375cd7b56d0c6e5932e2b55b46fd47d3b81cc87ca8e0e7be7a0`, reported `stock_restore=available`, `backup=unavailable`, and `fallback=compatible` with NAND `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. The recovery image `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367` was armed for the serial evidence. With the right card removed, the UART log reached BootROM and the host saw `2207:350a`. With that card in the right slot, the same preloader booted to `zlyme login:` on production U-Boot, with no diagnostic countdown. Disarm then restored the saved source byte for byte. Restore stock was available and was not run. Sentences above that say Phase 11C is not hardware-accepted are the record from before this closure.

### 11D — closure and release handoff

The earlier plan waited on a published `zlyme44.1`, a partial OTA from that exact root, and field feedback before Phase 11 could close. That plan is superseded. No Phase 11 completion criterion waits for a later 44.1 or 44.2 build. There is no time-based field-aging gate. Accepted Phase 11C hardware evidence stays authoritative. The remote build after the merge is a candidate pipeline step. It is not a reason to leave this engineering phase open for weeks, and this task does not publish a release.

Closure means:

- reconcile the documentation and the hardware-wiki evidence
- capture the canonical serial logs
- finish the local tests and the local candidate build
- merge the accepted development branch
- start the remote candidate build

Closed 2026-10-08 with the candidate and the NAND result named in the 11C closure note. The UART logs are in the hardware wiki.

### Gate

- 11A, 11B, and 11C each have their own candidate and the checks named above. 11C is hardware-accepted on the 2026-10-08 closure note.
- Erase is not USB MASKROM. The boot-file MASKROM request was removed. Production U-Boot is `CONFIG_BOOTDELAY=-2`. The card readback matched that build, and the right-slot UART log has no diagnostic countdown.
- 11D is the closure and release handoff above. It is complete. It does not publish `zlyme44.2`.
- `zlyme44.1-maintenance` stays at `6a398b311310246ef6a5515ed72805c6f58d787d` until 44.1 publication work, which is separate from this phase.

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
bootfat-remount
nextui-fork
nextui-fetch
nextui-profile
product-polish
release-image
```

Names are illustrative; the important part is one reason per checkpoint.

The Phase-2 research checkpoint should not contain kernel implementation changes. The Phase 8 research checkpoint should not contain the NextUI fork.
