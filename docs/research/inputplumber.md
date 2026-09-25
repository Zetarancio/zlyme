# InputPlumber

Date of the original study: 2026-09-14 / 2026-09-15. Updated 2026-09-25.

## Current decision

InputPlumber is adopted as the Zlyme application-facing controller layer. This is a project architecture decision, not a conditional experiment. Phase 4A packages it. Phase 4B integrates and measures the built-in controller. Later phases retarget applications.

The 2026-09-15 finding still stands: InputPlumber was unnecessary merely to fix Switch Pro report-mode handling. `hid-nintendo` was the correct fix for that problem.

Current Batocera and KNULLI trees inspected on 2026-09-25 do not package InputPlumber. They instead maintain a mature controller/config-generation architecture:

```text
physical controller mappings
    ->
central controller representation
    ->
per-emulator config generators
```

That proves InputPlumber is not technically required, but also demonstrates the amount of controller/application policy infrastructure needed by the direct approach. Zlyme chooses InputPlumber to centralize physical-controller normalization, exclusive ownership, virtual controller identity, hotplug, and player-order policy. Emulator-specific console semantics may still require application configuration.

## Latency

```text
Miyoo Flip analog source:
    ~66.8 UART frames/s
    ~15 ms physical sample period
Phase-3 stick driver path:
    serdev receive callback
    -> parse complete frame
    -> calibration/deadzone transform
    -> input_report_abs
    -> input_sync
No extra worker/timer exists in the normal stick input path.
Phase-3 GPIO buttons:
    interrupt
    -> 10 ms delayed debounce
    -> input_report_key
InputPlumber v0.81.0 generic evdev source:
    nonblocking evdev
    2.5 ms / 400 Hz polling
    TODO upstream: replace polling with epoll/event-driven wakeup
```

The first likely InputPlumber-added source delay is 0..2.5 ms, roughly 1.25 ms average, plus translation, scheduling, and uinput overhead. Do not claim total latency until it is measured on the Flip. InputPlumber supports `ENABLE_METRICS=1` for internal event-path timing.

Potential latency work, in order:

```text
1. measure
2. optimize InputPlumber polling/event wakeup if needed
3. reconsider the 10 ms GPIO debounce only with bounce evidence
4. do not restructure the UART driver unless measurements show it is responsible
```

The physical driver already exposes standard evdev and force feedback. Do not change it merely to suit InputPlumber. Rumble Strength stays a physical-device setting, not an InputPlumber policy.

## Historical recommendation — 2026-09-15

Do not package InputPlumber merely for the Switch Pro. hid-nintendo is the driver for that pad. The notes below are that study. They are not the current Phase 4 decision.

## Live Switch Pro (2026-09-15)

Paired `98:B6:D4:58:CD:79`, `js1` / `event5`, `DRIVER=hid-generic`
(`HID_ID=0005:057E:2009`). `ID_INPUT_JOYSTICK=1` but **zero evdev
bytes in 2s**. KEY bitmap is keyboard-ish (`ffff000000000000`), not
`BTN_SOUTH`. `CONFIG_HID_NINTENDO` was off; DualShock already has
`HID_PLAYSTATION`. Nintendo pads stay in vendor report mode until
hid-nintendo sends 0x30. RetroArch udev therefore has nothing to map.
That is why RA “does not work” after a successful BlueZ pair.

**Next rebuild:** `CONFIG_HID_NINTENDO=m` + `NINTENDO_FF` in
`my355.fragment`, plus libretro `Nintendo Switch Pro Controller.cfg`.
Pro will still enumerate as **player 2** (`js0` is Flip). MENU+Start
exit stays `zlyme-pak-hotkey` on js0.

## Historical recommendation — superseded

The 2026-09-15 text below said not to package InputPlumber for the Switch Pro. That pad-specific conclusion remains true. The project later adopted InputPlumber as the application controller layer. See the current decision at the top of this file.

## Recommendation

Do **not** package InputPlumber for this pad. hid-nintendo is the
driver. IP is the later *composite* (one Xbox-like P1 from Flip+BT,
exclusive grab). Stay SDL + eudev until we want that grab. No Rust
daemon in front of NextUI.

## What ROCKNIX #2685 actually is

sydarn [ROCKNIX/distribution#2685](https://github.com/ROCKNIX/distribution/pull/2685)
is Anbernic gpio-keys / ADC plus YAML keyed on the DT **model**. That is
not the Flip. The Flip pad is UART `retrogame_joypad` (ROCKNIX serial
`.ko`, Zlyme patch 0002). Sticks are userspace `miyoo_inputd` on ttyS1
in stock; we use the kernel driver instead. See
`RESEARCH-JOYPAD-DRIVER.md`.

## What an obscure USB/BT pad does on Zlyme today

- eudev creates `/dev/input/event*` / `jsN`.
- NextUI opens every `SDL_JOYDEVICEADDED` (buttons mix, no grab).
- RetroArch is udev + gamecontrollerdb; unknown pads stay unmapped.
- `zlyme-pak-hotkey` is **js0** (built-in). A second pad must not steal that.
- A BT headset is A2DP, not a pad. HID UUID `00001124` is hidp, not A2DP.

## When IP would pay

One composite device, grab, known maps, cleaner BT vs built-in. Cost:
Rust daemon before NextUI first frame, a Flip YAML, RA/hotkey retarget
off `js0`. That is the opposite of Class A boot.

Stay SDL/udev. Revisit if we need exclusive grab or a pile of obscure
pads that gamecontrollerdb will not cover.
