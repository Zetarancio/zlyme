# InputPlumber

Date of the original study: 2026-09-14 / 2026-09-15. Updated 2026-09-26.

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

The first likely InputPlumber-added source delay is 0..2.5 ms, roughly 1.25 ms average, plus translation, scheduling, and uinput overhead. InputPlumber supports `ENABLE_METRICS=1` for internal event-path timing. Phase 4B measured that internal path. The about 1.8 ms typical routing estimate below adds the inferred poll wait to the measured average. It is not a direct end-to-end sample.

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

## D-pad map and latency — 2026-09-26

v0.81.0 `evdev.rs` maps face buttons, bumpers, `BTN_TL2`/`BTN_TR2`, start, select, mode, and stick clicks. It does not map `BTN_DPAD_*`. Upstream AYN and Retroid maps send those keys to `DPadUp`/`DPadDown`/`DPadLeft`/`DPadRight`, and the Xbox target writes them as `ABS_HAT0Y`/`ABS_HAT0X`. Events absent from a capability map still use the generic translator (`gamepad.rs`).

A temporary bind mount of `/usr/share/inputplumber` added only those four mappings, id `zlyme_miyoo_flip`, with `auto_manage: false`, `persist: false`, and target `xb360`. The virtual capture then showed `ABS_HAT0X` -1 then 0 and +1 then 0, and `ABS_HAT0Y` -1 then 0 and +1 then 0. That is left/right and up/down. `BTN_EAST` (A) still appeared. Those four entries remain in the packaged map.

The Flip L2 and R2 controls are digital GPIO buttons. The Phase 3 device reports them as `BTN_TL2` and `BTN_TR2`. They are not analog axes. In the first managed capture they did not appear as `ABS_Z` or `ABS_RZ`. Metrics recorded two `Gamepad(Button(LeftTrigger))` events and two `Gamepad(Button(RightTrigger))` events, so the generic translator saw those keys. The Xbox target turns that button capability into `KEY` `BTN_TL2`/`BTN_TR2`, and the virtual `xb360` device does not include those keys, so the writes are not visible. The same target does expose `ABS_Z` and `ABS_RZ`, range 0..255, for `GamepadTrigger::LeftTrigger` and `GamepadTrigger::RightTrigger`.

Metrics were collected only after `Properties.Set` of `org.shadowblip.Input.Metrics.Enabled` to true on `/org/shadowblip/InputPlumber/devices/target/gamepad0`, with `ENABLE_METRICS=1`. `EventMetrics` count was 2322. Root span, microseconds: min 202, median 488, average 560, p95 877, max 7014. Subspans, same units, min/median/average/p95/max: `source_poll` 25/58/63/103/205, `source_send` 44/198/248/392/6416, `target_send` 13/107/121/242/2494, `target_write` 7/27/37/86/2445. The root span starts inside a source poll, after `fetch_events()`. It does not include time a kernel event waited for the next 2.5 ms loop. That wait is 0 to 2.5 ms, about 1.25 ms on average if arrivals are uniform, and it is an inference. Do not add it into the measured root number.

Managed idle cost from the earlier window remains about 1.5% of one CPU and 13320 kB RSS. Shortening the poll to 1 ms would buy latency with more wakeups. An event-driven source is the first candidate if routing delay or that idle cost needs to come down. It is not required before Phase 4C, and it is not implemented here. The stick path and the 10 ms debounce stay unchanged.

The temporary mount was removed after that D-pad run. `S31inputplumber` was left running with metrics unset and zero composites.

## Digital L2/R2 to xb360 axes — 2026-09-26

The adaptation is only at the virtual ABI. A temporary capability map kept the four D-pad entries and added `BTN_TL2` and `BTN_TR2` with `value_type: trigger`, targeting `GamepadTrigger` `LeftTrigger` and `RightTrigger`. For a key, InputPlumber sees 0 or 1. That trigger value is a float, and the Xbox axis scales it to its declared maximum. `EVIOCGABS` on the live virtual pad reported 0..255 for both `ABS_Z` and `ABS_RZ`.

The map was bind-mounted over `/usr/share/inputplumber` on the still-unflashed card, with metrics unset, `maximum_sources: 1`, `auto_manage: false`, `persist: false`, and target `xb360`. One composite and one `Microsoft X-Box 360 pad` appeared. The virtual node was discovered by name. Three L2 press/release pairs wrote `ABS_Z` 255 then 0 every time. Three R2 press/release pairs wrote `ABS_RZ` 255 then 0 every time. A still arrived as key 305, press and release. The four D-pad entries were unchanged, so the earlier hat validation still stands. The mount was removed. The service was restarted through `S31inputplumber` with metrics unset and zero composites. The physical pad remained `Miyoo Flip Gamepad`.

A reasonable typical routing estimate is about 1.8 ms: about 1.25 ms expected poll wait plus about 0.56 ms measured average internal work. That 1.8 ms is partly inferred. It is not a direct end-to-end measurement. The measured internal cost is small enough that functional integration is more useful than a driver or poll change. Do not change the Phase 3 driver. Do not reduce the 10 ms button debounce. Do not alter the about 66.8 Hz UART path. Do not fork InputPlumber for `epoll` before Phase 4C, and do not shorten the polling interval. Event-driven evdev, readiness instead of 400 Hz polling, stays a later candidate because it could cut both the poll-phase wait and idle wakeups without changing the physical device ABI.

Phase 4B is complete. The closure evidence is post-first-frame startup, a normal zero-composite state, exclusive grab of the physical pad, one `xb360` target, face buttons, sticks, MENU/Guide, L3/R3, D-pad as `ABS_HAT0X`/`ABS_HAT0Y`, digital L2/R2 as binary `ABS_Z`/`ABS_RZ`, virtual `FF_RUMBLE` reaching the physical motor, manage/unmanage recovery, UART health, the internal latency above, and the managed-idle cost. Nothing in that evidence requires a Phase 3 driver change.

## Native libraries — 2026-09-26

InputPlumber depends on crate `hidapi` 2.6.4 and does not select a feature, so the crate default applies. On Linux that default is `linux-static-hidraw`. The crate build script compiles `etc/hidapi/linux/hid.c` into a static archive and uses pkg-config to find `libudev`. The shared backends, which probe `hidapi-hidraw` or `hidapi-libusb`, are not enabled. The previous build script output recorded `cargo:rustc-link-lib=static=hidapi` and `cargo:rustc-link-lib=udev`. The installed binary's dynamic section needs `libudev.so.1` and `libiio.so.0`, plus `libgcc_s`, `libm`, and `libc`. It does not need `libhidapi`. Buildroot's hidapi package stays in the image because Dolphin selects it. It is not an InputPlumber build dependency. A package directory clean and rebuild, with Buildroot's `hidapi-hidraw.pc` and `hidapi-libusb.pc` moved aside, reproduced that same linkage. The fresh build script again compiled `linux/hid.c`, linked static `hidapi` plus `udev`, and did not probe the shared hidapi packages.

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
