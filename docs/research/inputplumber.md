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

## Phase 4C mechanism — 2026-09-26

Pinned v0.81.0 behavior, read from the extracted tree:

`devices manage-all --enable` sets `ManageAllDevices` and runs `discover_all_devices`. Setting it false stops composites that are not `auto_manage`. That would drop external controllers, so Settings does not use it.

`CompositeDevice.Stop` stops that one composite. Source gamepads call `device.grab()` when they start; stopping the composite drops the source. `SystemSleep` only calls `suspend` on target devices, so suspend is not a physical release.

`CreateCompositeDevice` sends `ManagerCommand::CreateCompositeDevice`, and `create_composite_device` ignores the config and returns `Ok(())`. It is not a recreate path.

`GamepadOrder` is the native player list. `set_gamepad_order` suspends and resumes targets in the requested order. It does not rename event nodes.

`RescanDevices` is a Zlyme patch. It calls `discover_all_devices` only while `ManageAllDevices` is already true. `on_source_device_added` skips ids already in `source_devices_used`. Virtual input nodes whose syspath contains `/devices/virtual` are not considered sources, so the `xb360` target is not grabbed again.

Device configs load in filename order. `20-zlyme_miyoo_flip.yaml` matches the built-in name before `80-zlyme_external_gamepad.yaml` matches `ID_INPUT_JOYSTICK=1` on `event*`. The external file targets `xb360` only.

`zlyme-input` is the caller boundary. `run` watches `NameOwnerChanged` for `org.shadowblip.InputPlumber`. When a new owner appears and the Manager interface answers, it sets `ManageAllDevices` and reconciles order. If the owner disappears, the daemon stays up and activates again on the next owner. On `InterfacesAdded`, `InterfacesRemoved`, and manager `PropertiesChanged` it stable-partitions the current order: externals keep their relative order, and the composite named Miyoo Flip Gamepad moves last. It does not write `GamepadOrder` when that sequence is already in place. `release` returns only after that composite and its gamepad target are gone. `reclaim` returns only after the composite's `TargetDevices` includes a gamepad target. `ensure` is the session command: it reclaims when InputPlumber is up and returns success when it is not, so the first frame does not wait.

The first image was built before the card was reachable. The GUIDs below were computed from SDL 2.32.10 and then confirmed on the device. See the live check.

## Phase 4C live check — 2026-09-26

The installed OTA matches the `602aa5275e80` target tree. `/usr/bin/inputplumber`, `/usr/sbin/zlyme-input`, the capability map, and `/usr/lib/gamecontrollerdb.txt` have the same SHA-256 as that build. `/boot/VERSION` was not left on the FAT partition. Boot timing on that image: `nextui-first-flip` at 54.74 s, `inputplumber-start` at 57.21 s. After boot, `ManageAllDevices` was true, one composite named Miyoo Flip Gamepad, `GamepadOrder` was that composite, source `/dev/input/event4`, target `gamepad0`, virtual node name `Microsoft X-Box 360 pad`, ids `0003/045e/028e/0001`. InputPlumber held the physical node.

SDL 2.32.10 on the device, with `/usr/lib/gamecontrollerdb.txt`:

```text
physical Miyoo Flip Gamepad
  guid 19007c5b4d69796f6f20466c69702000
  gamecontroller=1
  crc:5b7c
  a:b1,b:b0,x:b2,y:b3
virtual pad
  SDL joystick name Xbox 360 Controller
  evdev name Microsoft X-Box 360 pad
  guid 030081b85e0400008e02000001000000
  gamecontroller=1
  crc:b881
  a:b0,b:b1,x:b2,y:b3,dpup:h0.1,lefttrigger:a2,righttrigger:a5
```

The computed GUIDs matched. SDL renames the virtual joystick to `Xbox 360 Controller`, so NextUI treats both that string and the evdev name as the xb360 target. A maintenance flag, not the shared name, decides when the physical Flip may be open beside another virtual pad.

On the installed map, printed A was virtual button 0 and printed B was button 1. Printed X was button 3 and printed Y was button 2. `GamepadButton::North` writes `BTN_NORTH` (SDL `x:b2`) and `West` writes `BTN_WEST` (SDL `y:b3`), so the first map's North→West and West→North swap was backwards. The corrected map sends `BTN_NORTH` to `North` and `BTN_WEST` to `West`. A second press of X then Y produced button 2 then button 3.

The same capture: d-pad hats up/down/left/right, up-left and down-right diagonals, Start button 7, Select button 6, Guide button 8, L1 button 4, R1 button 5, L2 axis 2 and R2 axis 5 from the released value to full scale and back, L3 button 9, R3 button 10, left stick on axes 0 and 1, right stick on axes 3 and 4, with negative Y for up.

On the installed `602aa52` binary, `release` returned in about 45–57 ms while the composite disappeared at about 244–282 ms and the virtual node about 10 ms later. `reclaim` returned about 120 ms before the target was ready. After `S31inputplumber restart`, `zlyme-input` stayed alive and left `ManageAllDevices` false until S32 was restarted.

The hardened binary was bind-mounted, not written into the squashfs. Twenty release/reclaim cycles then returned only after the promised state. Release was 184–326 ms, median 232 ms. Reclaim was 366–547 ms, median 404 ms. Each cycle ended with `ManageAllDevices` true, one built-in composite, and one virtual pad. Two InputPlumber restarts were recovered by the same `zlyme-input` process. A daemon started while InputPlumber was stopped reported `unavailable`, then became `manage=1 builtin=virtual` after InputPlumber started. `FF_RUMBLE` on the virtual node played, and the motor buzzed once. Killing `nextui.elf` with the built-in composite released made `nextui-session` run `ensure`, which reclaimed the target, and the new frontend opened the virtual pad. Settings screen-by-screen cancellation and a lid suspend were not run on this temporary pair. The persistent card is still the `602aa52` OTA until a newer image is installed. Calibration files `joypad.config` and `joypad_right.config` were not rewritten. No `deadzone.config` or `rumble.config` was present.

## Phase 4C MENU timing — 2026-09-26

The installed `748668829772` image matches the target tree for `/usr/sbin/zlyme-input` (`f4afc9f21180531b822992655d861454721ef363c544607312a799115e943628`), `/usr/bin/inputplumber` (`011eaea8530a2cae855bba493de6767af695b39b3bd41bba45812ffa93abc44f`), the capability map (`72dd7b6450de0299d9a67666376228bfabadc97595bd53e82361127ff1064aef`), and `/usr/bin/nextui.elf` (`a360020c29542c40bdaa197b2a229714448afc83c09f0e3d9dc677b2fd07e817`). No bind mounts. `zlyme-input status` was `manage=1 builtin=virtual devices=Miyoo Flip Gamepad`. InputPlumber held the physical pad. NextUI held the physical node once (the rumble handle) and the virtual pad. `zlyme-keylidmon` held volume, hall, and power only.

SDL 2.32.10 `SDL_MINIMUM_GUIDE_BUTTON_DELAY_MS` is 250. A Guide release earlier than that is postponed until the 250 ms mark. NextUI's menu tap and brightness-modifier windows are also 250 ms. On the virtual pad, one quick MENU tap was raw button 8 down/up in 142 ms and `SDL_CONTROLLER_BUTTON_GUIDE` down/up in 263 ms. That stretched hold opened the brightness overlay. A 345 ms press and holds of about 1.1–1.8 s released Guide with the raw button, and MENU+Volume still changed brightness. The Guide mapping stays. NextUI accepts the raw guide button for `BTN_MENU` and ignores the delayed controller Guide event. A bind-mounted build of that binary opened the Quick Menu on a quick tap and a normal press, showed the brightness overlay on a hold, changed brightness with MENU+Volume, and changed volume with Volume alone. That binary is not in the installed squashfs yet.

That last sentence belongs to this `748668829772` checkpoint. The installed image at closure is `e911db674811`, recorded below.

## Phase 4C closure — 2026-09-26

The persistent card is the OTA `zlyme-my355-20260926-e911db674811.tar`, SHA-256 `a9a298c1f6d59c13d1e750c8b9aa9043328a360016776dd96e137d62043eb015`. No bind mounts covered InputPlumber, `zlyme-input`, NextUI, or `/usr/share/inputplumber`. Installed SHA-256 values match the `e911db674811` target tree:

```text
/usr/bin/inputplumber
  011eaea8530a2cae855bba493de6767af695b39b3bd41bba45812ffa93abc44f
/usr/sbin/zlyme-input
  f4afc9f21180531b822992655d861454721ef363c544607312a799115e943628
/usr/bin/nextui.elf
  3b010571adc1bc1731c4d34e546f1b6a526d68729dfdf9f60b7df58ee9184719
capability map zlyme_miyoo_flip.yaml
  72dd7b6450de0299d9a67666376228bfabadc97595bd53e82361127ff1064aef
/usr/lib/gamecontrollerdb.txt
  50aaf9334f09803cfcb2dc10b2b962817200cacf2675025b4e1a3e0e03b42eaf
```

`/boot/VERSION` was not on the FAT partition. `/usr/share/zlyme/version` remains the NextUI pin line `zlyme43 (2026-09-26)`, not the Zlyme git SHA. The capability map still sends `BTN_NORTH` to North and `BTN_WEST` to West.

On that boot, S31 and S32 were running. `zlyme-input status` was `manage=1 builtin=virtual devices=Miyoo Flip Gamepad`. One composite, `GamepadOrder` that composite alone, source `Miyoo Flip Gamepad`, target node `Microsoft X-Box 360 pad`. InputPlumber held the physical pad. Volume was `gpio-keys-volume`, power was `rk805 pwrkey`, and the lid was `gpio-keys-hall`. `zlyme-keylidmon` held those three and not the gamepad. NextUI's log for this image showed the physical controller removed and `Microsoft X-Box 360 pad` added before a game launch. At the lifecycle check, NextUI was not the foreground process because RetroArch was running a Game Boy pak. RetroArch still had the physical node and the virtual node open. Application retargeting is Phase 4D. InputPlumber held the physical grab.

`zlyme-input release` printed `built-in composite released` and returned 0 only after the composite list was empty and the virtual node was gone. `ManageAllDevices` stayed true. `zlyme-input reclaim` printed `built-in target ready` and returned 0 only after one Miyoo Flip Gamepad composite and the `Microsoft X-Box 360 pad` node were back. `GamepadOrder` was that composite. Uptime moved from 605 to 606 across reclaim. Restarting S31 changed the InputPlumber pid from 744 to 9025 and left `zlyme-input` pid 759 running. The first status poll was `unavailable`. The next poll was `manage=1 builtin=virtual devices=Miyoo Flip Gamepad`, with the composite, the virtual node, and the physical grab restored. S32 was not restarted.

SDL 2.32.10 still delays `SDL_CONTROLLER_BUTTON_GUIDE` until at least `SDL_MINIMUM_GUIDE_BUTTON_DELAY_MS` (250). NextUI's tap and brightness windows are the same 250 ms, so my355 takes `BTN_MENU` from the raw joystick button bound to Guide and ignores the delayed controller Guide event. The InputPlumber mapping remains MENU to Guide. The live test of this installed image accepted a short or normal MENU press as the Quick Menu, a hold as the brightness modifier, MENU+Volume as brightness, and Volume alone as volume. The same test accepted A, B, X, Y, D-pad and diagonals, Start, Select, L1/R1, L2/R2, L3/R3, both sticks, and virtual `FF_RUMBLE`. Settings → Joysticks remains the physical-maintenance path: release, then the physical pad, then reclaim of only the built-in composite. Calibration files were not rewritten for this closure. External controllers stay one composite and one `xb360` target each, ordered ahead of the built-in pad, with relative order preserved. No external model was physically tested.

## Phase 4D application cutover — 2026-09-26

MENU+START stopped exiting paks because `zlyme-pak-hotkey` still opened `/dev/input/js0` (buttons 9 and 10) and the evdev node named Miyoo Flip Gamepad (`BTN_MODE` + `BTN_START`). InputPlumber grabs that physical pad, so those fds receive nothing. On the virtual target `Microsoft X-Box 360 pad` (`0003/045e/028e/0001`, sysfs under `/devices/virtual/`), a live capture showed MENU as evdev 316 (`BTN_MODE`) and START as 315 (`BTN_START`). The helper now watches each such virtual target, exits only when both are down on the same one, and rescans `/dev/input` with inotify. `zlyme-keylidmon` takes MENU from that same Guide button and still reads volume, power, and the lid from their own devices.

A bind-mounted pair was tried in a RetroArch Game Boy pak. Volume alone changed volume. MENU+Volume changed brightness. MENU alone and START alone did not exit. MENU+START returned to NextUI. The user did not count the exits, so this is not recorded as three repetitions. An InputPlumber restart while a pak is running has not been repeated for the new helper.

RetroArch's first log put Miyoo Flip Gamepad on port 1 and `Microsoft X-Box 360 pad` (1118/654) on port 2, both "not configured". After the Xbox autoconfig and `input_player1_joypad_index` for the virtual pad, a live Game Boy session accepted the d-pad, A/B/X/Y, Start, Select, L1/R1, MENU as the RetroArch menu, and MENU+START back to NextUI. The remaining startup banner is `notification_show_autoconfig_fails`: the saved config leaves that on, and the physical pad is still "not configured". `SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0x045e/0x028e` was checked on the device: SDL then reports one joystick, index 0, name `Xbox 360 Controller`. Paks export that hint, RetroArch player 1 is index 0, and the fail banner is forced off. NextUI does not get the hint.

Paks export `SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0x045e/0x028e` from `pak-input.sh`, which `nextui-session` sources only inside `run_pak_cmd`, before the pak process starts. `nextui.elf` does not get that hint, so the frontend and Settings → Joysticks still see the physical pad. Every InputPlumber player target, built-in and external, is an xb360 pad with ids `045e:028e`, so the filter keeps those targets and drops the physical Flip pad. On the device, SDL then reported one joystick, index 0, name `Xbox 360 Controller`.

Splore used to be started under `pico8-splore-pad`, which called `EVIOCGRAB` on that virtual node. While Splore was open, that process, `zlyme-pak-hotkey`, and `zlyme-keylidmon` all had the node open, and the log said the mapping was grabbed. MENU opened Splore's own menu, MENU+START did not leave Splore, and MENU+Volume changed volume. The grab hid Guide and Start from the session helpers. ROCKNIX launches Pico-8 directly (`pico8_64 -joystick 0`). Zlyme now does the same. The virtual pad's d-pad is a hat, so Splore reads it without a translator. A live pass then accepted d-pad, A/B, stick pointer, MENU as Splore's menu, START not exiting, MENU+START back to NextUI, volume, and MENU+Volume brightness. `pico8-splore-pad.c` was not changed.

OpenBOR v7533 (`BUILD_LINUX=1`, SDL2) opens every SDL joystick with `SDL_JoystickOpen` and polls buttons, axes, and hats into `joysticks[].Data` on the non-Android path. `savedata.usejoy` defaults to 1. Player 1's default bindings in `engine/sdl/control.h` were keyboard scancodes (`SDL_SCANCODE_UP`, `SDL_SCANCODE_A`, and so on), so the opened joystick never drove a character until someone remapped in the menu. That is the pre-InputPlumber defect. The Phase 4 part is which device is index 0: the hint makes that the virtual xb360 pad. The Linux SDL2 defaults now use joystick slots for that pad's measured shape, 15 buttons and 6 axes plus hat 0. Button 0 is A. Hat up is `JOY_LIST_FIRST + 1 + 15 + 12` (628). A binary settings file already stored under `Saves/` next to a pak still overrides these defaults. The card was not readable for an existing file during this pass. OpenBOR was not physically tested.

| Application | Launch | API | Old assumption | 4D change | Test |
| --- | --- | --- | --- | --- | --- |
| NextUI | nextui-session | SDL GameController | virtual pad after handoff | unchanged from 4C | live in 4C |
| zlyme-pak-hotkey | session, per pak | evdev | js0 and physical name | virtual Guide+Start, same pad | live, exit count not recorded |
| zlyme-keylidmon | S26 | evdev | physical BTN_MODE | virtual Guide; volume/power/lid unchanged | live volume and brightness |
| RetroArch / libretro | ra-run | SDL2 joypad | retrogame profile, physical often port 1 | player 1 is SDL index 0 after the physical pad is hidden; Xbox autoconfig; fail banner off | live: buttons, menu, MENU+START |
| PPSSPP | PSP.pak | SDL, seed ini has no device index | first SDL device | pak hint hides non-xb360 game controllers | static |
| Flycast | DC.pak | SDL | no device index in the launcher | same hint | static |
| ScummVM | SCUMMVM.pak | SDL2 `--joystick 0` | first device was the physical pad | hint makes index 0 the virtual pad | static |
| Hypseus Singe | DAPHNE.pak `-gamepad` | SDL2 | first joystick | same hint | static |
| Amiberry | AMIGA.pak | SDL2 GameController (`libSDL2-2.0.so.0`) | first controller | same hint; binary has no `/dev/input` strings | static |
| OpenBOR | OPENBOR.pak | SDL2 joystick poll | keyboard scancode defaults; index 0 was physical | hint plus xb360 default slots in `control.h` | source review; not played |
| Moonlight | Moonlight.pak | SDL2 (`platform = sdl`); libevdev is linked for other platforms | all evdev if not on the sdl platform | config selects sdl, so the hint applies | static |
| GZDoom | DOOM.pak | SDL2 (`NO_SDL_JOYSTICK` off) | first joystick | same hint | static |
| PICO-8 / Splore | `pico8` direct, like ROCKNIX | SDL2 `-joystick 0` | translator grabbed the virtual pad | no translator; hat d-pad on joystick 0 | live |
| DraStic | start_drastic.sh | SDL2 `SDL_JoystickOpen` | first joystick | hint applies to joystick enumeration, not only GameController | static |
| AetherSX2 | start_aethersx2.sh | SDL2 GameController | first controller | same hint | static |
| Dolphin | start_dolphin.sh | SDL2 | first device | same hint | static |
| PortMaster | portmaster | per-port SDL | ports pick their own device | hint is in the pak environment | not played yet |
| Wine / Box64 | WINE.pak | guest via box64; `wine` is a shell wrapper | not host SDL | the hint is exported but Wine XInput/DInput does not use it; no guest mapping was added | static |

Libretro cores ride RetroArch. The human test list for later passes is NextUI/PAK lifecycle (the hotkey and brightness path above), RetroArch, PortMaster, PICO-8 Splore, and PPSSPP. Other shipped consumers stay static until someone runs them. No external controller was required.

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
