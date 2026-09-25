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

## Phase 4B runtime

`S31inputplumber` starts in `rc.late` after system D-Bus and after `nextui-first-flip`. It is not a first-frame service. Normal environment is `INSECURE_DISABLE_POLKIT=1` and `HIDE_DEVICES_FROM_ROOT=0`, with metrics unset. The Flip profile still has `auto_manage: false`, so boot does not grab the pad. Zlyme does not ship polkit. The installed D-Bus policy allows only root to own or call `org.shadowblip.InputPlumber`. NextUI, Settings, and SSH run as root. `devices manage-all --enable` sets manage-all; the same command without `--enable` stops composites that are not auto-managed, which releases the physical pad without unloading the driver.

## Device check — 2026-09-26

SSH `root@192.168.0.108`, image `zlyme-my355-20260925-99e05660f792`. InputPlumber 0.81.0. `/tmp/boot-timing`: `nextui-first-flip` at 11.00 s, `inputplumber-start` at 13.21 s. One daemon. Environment was `INSECURE_DISABLE_POLKIT=1` and `HIDE_DEVICES_FROM_ROOT=0`, with `ENABLE_METRICS` unset. The log was empty. `devices list` reported 0 composites. NextUI had `/dev/input/event4` (`Miyoo Flip Gamepad`) open. This card had no `/storage/.config/zlyme/miyoo-flip-gamepad/` directory. Deadzone sysfs was 0 and 0. UART `bad=0`, port open.

Stopping the service removed the D-Bus name (`InputPlumber daemon is not currently running`). The next `S31inputplumber start` was ready at the first 20 ms poll. Uptime went from 184.80 s to 184.98 s, so the start call plus D-Bus readiness was about 0.18 s. Composites stayed at 0.

With zero composites, over about 10 s: VmRSS 11676 kB, utime+stime unchanged (0 jiffies), voluntary context switches 54 and nonvoluntary 434, both unchanged. `CONFIG_HZ=250`.

`devices manage-all --enable` created one composite, id 0, name Miyoo Flip Gamepad, source `/dev/input/event4`, profile Default, target `xb360` / `Microsoft X-Box 360 pad` on `event5`. Bus/vendor/product/version `0003/045e/028e/0001`. The virtual node advertised face buttons, bumpers, select, start, guide, both stick clicks, sticks, hat axes, `FF_RUMBLE`, and `FF_GAIN`. It did not advertise `BTN_TL2`/`BTN_TR2`. InputPlumber held `event4` and `/dev/uinput`. NextUI still held `event4` and also opened `event5`. An independent read of `event4` during the grab counted 0 keys, 0 absolute events, and 0 syncs.

The virtual capture in that window: 10 key reports, 717 absolute reports, 727 syncs. Presses: `BTN_SOUTH` 304, `BTN_EAST` 305, `BTN_MODE` 316, `BTN_THUMBL` 317, `BTN_THUMBR` 318, one press each. Nonzero absolute activity on `ABS_X`, `ABS_Y`, `ABS_RX`, and `ABS_RY`. No hat and no D-pad codes were in that file. A later physical read, after release, did see D-pad up, down, and right.

Managed and idle, over about 10 s, still with metrics off: VmRSS 13320 kB, utime 122 to 131 and stime 252 to 280 (37 jiffies, about 0.15 s at 250 Hz), voluntary context switches 97 and nonvoluntary 73, both unchanged.

`ENABLE_METRICS=1` was used for a later restart. `dbus-monitor` on `org.shadowblip.Input.Metrics` recorded no `EventMetrics` signals. v0.81.0 only emits those after a client sets the metrics interface `Enabled` property; the environment variable creates the interface and the spans, and the performance screen is what sets the property. Internal min/average/max were therefore not measured. The 2.5 ms source poll remains source review, not a measurement. Do not treat a missing root span as a latency result. The unmeasured poll wait is still 0 to 2.5 ms, about 1.25 ms if the phase is uniform, and it is not included in any root span.

A temporary helper uploaded `FF_RUMBLE` on `event5` at full strong and weak magnitude, 250 ms, played, stopped, and erased it. Every ioctl and write succeeded. Both `FF_RUMBLE` and `FF_GAIN` were present on that node. `rumble.config` was absent before and after. PWM debugfs was not used.

`devices manage-all` with no `--enable` removed the composite and `event5`. The service was then restarted through `S31inputplumber` with metrics unset. A following physical read of `event4` saw `BTN_DPAD_UP` 544, `BTN_DPAD_DOWN` 545, `BTN_DPAD_RIGHT` 547, and `BTN_EAST` 305. NextUI was still running and still held `event4`. Final state: daemon up, metrics off, zero composites.

UART `valid` moved from 9822 to 34993 during the routed exercise and to 40920 after release. `bad` stayed 0. The gamepad config directory was absent at the start and at the end.

No driver, debounce, or poll-rate change follows from this run. The first software candidate, if a later review wants less routing delay, is InputPlumber's 2.5 ms evdev poll. The 10 ms button debounce and the about 15 ms stick sample period stay as they are until there is separate evidence.

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
