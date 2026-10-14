# Phase 3C integration log

Moved unchanged from `docs/ROADMAP.md` on 2026-10-14. The active roadmap keeps the same heading and a short acceptance note. The text below is the log as it stood. It is not a new conclusion.

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

