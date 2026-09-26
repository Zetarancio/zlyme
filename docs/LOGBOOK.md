Defconfig names in entries below are the names used that day. They are now `configs/zlyme_my355_defconfig` and `configs/zlyme_my355_minimal_defconfig`.

# Logbook

OS is **Zlyme**, board is **my355**. Image is `zlyme.img`. Storage label `ZLYME`.
Older entries used a previous product name; treat those as the same tree.

This file is the chronological engineering log.
Durable current facts belong in the appropriate canonical documentation:

- `docs/ARCHITECTURE.md` for system architecture and invariants;
- `docs/OPERATIONS.md` for live-device behavior and recovery;
- `docs/DEVELOPMENT.md` for build/development policy;
- `docs/UPSTREAMS.md` for source/repository authority;
- the Miyoo Flip hardware wiki for hardware, firmware, electrical, protocol, and reverse-engineering facts.

Historical material from the former `NOTES/` tree is preserved under `docs/archive/`.
Device serial dumps and temporary developer notes remain local/gitignored where documented.

---

## 2026-09-26 — Phase 4C complete

The persistent OTA `zlyme-my355-20260926-e911db674811.tar` (SHA-256 `a9a298c1f6d59c13d1e750c8b9aa9043328a360016776dd96e137d62043eb015`) is the installed card. `inputplumber`, `zlyme-input`, `nextui.elf`, the capability map, and `gamecontrollerdb.txt` match that tree, with no bind mounts. `ManageAllDevices` stayed true through one release, one reclaim, and an InputPlumber restart that the same `zlyme-input` process recovered. The live test of this image accepted the built-in virtual path: A/B/X/Y, D-pad and diagonals, Start, Select, MENU, L1/R1, L2/R2, L3/R3, both sticks, and virtual rumble. A short or normal MENU press opens the Quick Menu, a hold shows the brightness modifier, MENU+Volume changes brightness, and Volume alone changes volume. Settings → Joysticks uses the physical-maintenance release/reclaim path. Volume, power, and the lid stay independent. Phase 4C is complete. Phase 4D has not started.

## 2026-09-26 — Phase 4C MENU tap on the 7486688 image

The persistent card matches `748668829772`: `zlyme-input`, InputPlumber, the capability map, and `nextui.elf` share that tree's SHA-256, with no bind mounts. `ManageAllDevices` was true, one Miyoo Flip Gamepad composite, and NextUI held the virtual pad. `zlyme-keylidmon` did not have the gamepad open. A 142 ms physical MENU tap produced a raw guide release at 142 ms and an SDL Guide release at 263 ms. SDL's 250 ms minimum Guide hold is the same window NextUI uses for a brightness hold, so quick and normal taps opened the brightness overlay. Longer holds and MENU+Volume still changed brightness. NextUI now takes MENU from the raw guide button and ignores the delayed Guide event. A bind-mounted build of that binary opened the Quick Menu on a quick tap and a normal press, showed the brightness overlay on a hold, changed brightness with MENU+Volume, and changed volume with Volume alone. Phase 4C stays in progress until that binary is on an installed image. Phase 4D has not started.

## 2026-09-26 — Phase 4C live checkpoint

The installed OTA matches `602aa5275e80`. On that binary, `release` returned before the composite was gone, and `zlyme-input` did not re-enable management after an InputPlumber restart. SDL GUIDs matched the computed database. Printed A/B were correct; printed X/Y were swapped until `BTN_NORTH` mapped to `North` and `BTN_WEST` to `West`. A bind-mounted rebuild then finished release and reclaim only when the target state was ready, recovered two InputPlumber restarts, reclaimed after `nextui.elf` was killed, and played `FF_RUMBLE` on the virtual pad. The motor buzzed once. Settings cancellation and lid suspend were not run. Phase 4C stays in progress until a newer image is installed. Phase 4D has not started.

## 2026-09-26 — Phase 4C implementation checkpoint

`zlyme-input` enables InputPlumber after the first frame, orders external composites ahead of the built-in pad, and releases only that composite for Settings. InputPlumber gained `RescanDevices` so reclaim does not toggle `ManageAllDevices`. NextUI follows SDL GameController on the virtual `xb360` target and closes the physical handle. The card at `192.168.0.108` was not reachable, so this image is not hardware-validated. Phase 4C is not complete. Phase 4D has not started.

## 2026-09-26 — Phase 4B final audit

The capability-map schema hint is pinned to InputPlumber `ea60d873cca17edd1cb655ede26f557108135252`. Buildroot hidapi is not an InputPlumber dependency: crate `hidapi` 2.6.4 uses `linux-static-hidraw`, compiles its own hidraw archive, and the binary needs `libudev` and `libiio`. Package help and the defconfig comment now say the daemon starts after the first frame and manages nothing. The Phase 4 diagram is one composite and one virtual controller per physical player controller. Phase 4C has not started.

## 2026-09-26 — Phase 4B complete

Physical L2 and R2 are digital GPIO buttons, `BTN_TL2` and `BTN_TR2`. The generic InputPlumber path turns them into button capabilities, and the `xb360` target does not emit those keys, which is why an earlier virtual capture showed nothing for them. A capability map with `value_type: trigger` sends them to `LeftTrigger` and `RightTrigger`. On the live virtual pad, three L2 presses wrote `ABS_Z` 255 and released to 0, three R2 presses wrote `ABS_RZ` 255 and released to 0, and A still arrived. The four D-pad entries were not changed. The test mount was removed. The daemon is running with metrics off and nothing managed.

Measured internal `root` processing over 2322 samples was 202 µs minimum, 488 µs median, 560 µs average, 877 µs p95, and 7014 µs maximum. Adding the inferred 0..2.5 ms poll wait, about 1.25 ms if arrival phase is uniform, gives about 1.8 ms typical software routing. That 1.8 ms is not a direct end-to-end measurement. Managed idle cost stays about 13.0 MiB RSS and about 1.5% of one core. The Phase 3 driver, the 10 ms debounce, and the UART path are unchanged. Event-driven evdev remains a later candidate. Phase 4B is complete. Phase 4C has not started.

## 2026-09-26 — Phase 4B D-pad map and latency

A temporary capability map for the four `BTN_DPAD_*` keys was bind-mounted over `/usr/share/inputplumber`. The virtual Xbox pad then reported hat X and hat Y for all four directions, returning to 0, and A still arrived. L2 and R2 were seen internally as trigger buttons and did not appear as `ABS_Z` or `ABS_RZ`. Metrics, after the Enabled property was set, were 2322 events. Root processing was about 202 µs minimum, 560 µs average, 877 µs p95, and 7014 µs maximum. That span does not include the 0 to 2.5 ms wait for the next source poll. The test mount was removed. The daemon is running with nothing managed. Phase 4B is not complete.

## 2026-09-26 — Phase 4B device check

On `root@192.168.0.108`, `nextui-first-flip` was 11.00 s and `inputplumber-start` was 13.21 s. InputPlumber 0.81.0 was one process, metrics off, and `devices list` was empty. NextUI held the physical `event4`. After `manage-all --enable` there was one Miyoo Flip Gamepad composite and an `xb360` node, `event5`. An independent read of the physical node during the grab saw no events. The virtual node saw both sticks, A, B, MENU, L3, and R3. D-pad was not in that virtual capture. A full-magnitude `FF_RUMBLE` upload on `event5` succeeded. `event5` also advertises `FF_GAIN`. Disabling manage-all removed the virtual node. A later physical read saw A and D-pad. UART `bad` stayed 0. No `rumble.config` existed before or after, because this was a freshly written card. `EventMetrics` did not fire: the D-Bus metrics property stays off unless a client enables it. The 2.5 ms poll was not measured. Phase 4B is not closed. No driver change.

## 2026-09-25 — Phase 4B InputPlumber service

`S31inputplumber` starts after D-Bus in the `rc.late` block that already waits for `nextui-first-flip`. It is not in the Class A list. The daemon is backgrounded, logs to `/tmp/inputplumber.log`, and does not set `ENABLE_METRICS`. `auto_manage` is still false, so it owns no controller at boot. NextUI still opens the physical pad. Polkit is not installed. Root is the only D-Bus client allowed to manage the service. Device routing and latency measurement have not been run.

## 2026-09-25 — Phase 4A InputPlumber package

InputPlumber v0.81.0, commit `ea60d873cca17edd1cb655ede26f557108135252`, is built with Buildroot `cargo-package` and Rust 1.88. The binary links libudev and libiio. host-clang supplies libclang for the uhidrs-sys bindgen step. The IIO daemon is not enabled. Installed files are the binary, `org.shadowblip.InputPlumber.conf`, upstream `profiles/default.yaml`, and `devices/20-zlyme_miyoo_flip.yaml`. That composite device matches the evdev name Miyoo Flip Gamepad, does not auto-manage, does not persist, and targets `xb360`. Init, udev autostart, NextUI, and the gamepad driver were not changed. Phase 4B has not started.

## 2026-09-25 — Phase 4 InputPlumber architecture

InputPlumber is the application-facing controller layer. That is a project decision, not a trial against a no-InputPlumber design. `hid-nintendo` remains the Switch Pro report-mode fix. Batocera and KNULLI, as inspected on this date, do not package InputPlumber; they generate per-emulator controller config instead. Zlyme uses InputPlumber for normalization, exclusive ownership, virtual identity, hotplug, and player order.

Phase 4A packages it and does not start it. Phase 4B is the first built-in-controller test and the latency measurement. The v0.81.0 evdev source polls every 2.5 ms. The Flip stick path has no extra worker. Do not change the physical driver until a measurement says to.

## 2026-09-25 — Phase 3D and Phase 3 closure

Phase 3 is complete. The built-in gamepad is `miyoo-flip-gamepad` / `Miyoo Flip Gamepad`. The ROCKNIX package is gone from the tree and is not a product module. OTA removes Autocal.pak, `/storage/.config/miyoo-serial-joypad/`, and a hot-copied `rocknix-singleadc-joypad.ko`. It does not touch `/storage/.config/zlyme/miyoo-flip-gamepad/`. `zlyme-gamepad-ff gain` accepts only an integer 0..100. Direct lid and pak-hotkey lookups use the Flip name. Rumble prefers that name and keeps a generic `FF_RUMBLE` fallback that is not the retired driver.

`input-polldev` stays because `CONFIG_KEYBOARD_GPIO_POLLED` is still enabled. The adc-keys redirect toward the old joypad stays in the tree as dead code on this board: the Flip has no `adc-keys` node. Both are Phase 5 kernel cleanup, not a reason to keep the old module. RetroArch and PICO files that still mention `retrogame_joypad` are application mappings for Phase 4, not the kernel driver.

No new Flip test was run for this cutover. The physical gate is the evidence from Phase 3B through 3C3. Phase 4 has not started.

## 2026-09-25 — Phase 3C3 rumble closure

Phase 3C3 is complete. The physical Flip tests accepted `FF_RUMBLE` and `FF_GAIN` on `Miyoo Flip Gamepad`, Settings Rumble Strength, Test Rumble, save, reboot persistence, 0% silent, compensated 10% weak but perceptible, and 50% then 100% stronger. UART `bad` stayed 0, sticks stayed centered, and calibration and deadzone files were unchanged. Standard gamepad suspend/resume had already passed earlier in Phase 3. Suspend while an effect was playing, and forced module removal while rumbling, were not repeated. Source review shows suspend and remove cancel the rumble worker and turn PWM off. Those cases are not closure blockers.

Shipping defaults, not yet retested on a fresh card: displayed Rumble Strength 30%, and Haptic feedback on. A missing `rumble.config` is not created by restore, but restore applies displayed 30%. An existing `rumble.config` or `haptics=` value is left alone. The 30% default is userspace only. The kernel `FF_GAIN` default remains 100% until `rc.late` runs after the first frame.

Phase 3D is only the physical-driver cutover and old ROCKNIX cleanup. Emulator mappings, external controllers, and the virtual P1 belong to Phase 4 InputPlumber. Neither phase has started.

## 2026-09-24 — initramfs grep applet

The tiny embedded initramfs `/init` calls `grep -q` to see whether `/boot_root` and `/storage_root` are already mounted. Its own BusyBox config had `# CONFIG_GREP is not set` while `CONFIG_EGREP` and `CONFIG_FGREP` were enabled, so those checks could not execute `grep`. The fix enables the normal `grep` applet. The script was not rewritten around `fgrep`.

Host `dash -n` accepted `package/boot/zlyme-initramfs/init` as a syntax check only. `./build.sh --minimal zlyme-initramfs-dirclean`, `zlyme-initramfs`, `linux-rebuild`, and a complete `./build.sh --minimal` succeeded. The generated initramfs `.config` has `CONFIG_GREP=y`, `CONFIG_EGREP=y`, and `CONFIG_FGREP=y`. `output/images/initramfs/bin/grep` links to that static BusyBox, the packed cpio contains `bin/grep` and `init`, and `CONFIG_INITRAMFS_SOURCE` is `/zlyme/output/images/initramfs`. No Miyoo Flip boot was tested.

## 2026-09-24 — Phase 3C2a calibration range invariant

Hardened on `zlyme43 (2026-09-23)`. The runtime zero must stay strictly inside the active min/max, with both sides longer than the deadband of 2. A `restore` that would leave a `boot` or `apply` center outside the new range returns `-ERANGE` and changes neither axis. A stable boot median that does not fit the active range is not installed. That axis stays on its current center and source, and the tracer shows `range-rejected`. The state is terminal. Persistent files are not rewritten.

Checked on the live image: `restore 120 130 200 140 160 220` against boot centers 104/137 failed with the stick unchanged. After `apply 4 110 220 30 150 230`, `restore 140 160 220 170 190 240` failed and the source stayed `apply`. A stale right X range of 140/170/230 restored, the sampler found resting XR 114, and that center was rejected. XR stayed at 170 with source `persisted`. YR and the left stick accepted normally. The measured files were restored and a fresh boot accepted 104/137/114/138, source `boot`, axes 0, port open, bad frames 0. The file hashes are still `f28facba…` and `74ece9a2…`.

Phase 3C2a is complete. Phase 3C2b and Phase 3C3 have not started.

## 2026-09-24 — Phase 3C2a gamepad calibration

Persistent calibration passed on `zlyme42 (2026-09-23)`. Phase 3C2b has not started. Rumble has not started. The old ROCKNIX joypad package is still installed and was not bound.

The uncalibrated range is 0/128/255, the UART byte, not measured travel. Source is `default`, `persisted`, `boot`, or `apply`. Writes must stay in 0..255 with the center strictly inside and both sides longer than the deadband of 2. `restore` updates the saved range and adopts that center only when the source is `default` or `persisted`. Boot center and `apply` keep their runtime zero. Apply also cancels an unfinished boot center. That race was checked while the tracer was still settling: eight seconds later the applied zeros were unchanged and the boot state was `cancelled`.

`S26joypadcal` modprobes the new module and runs `zlyme-gamepad-cal restore` immediately. Files are `/storage/.config/zlyme/miyoo-flip-gamepad/joypad.config` and `joypad_right.config`. The kernel does not open them. The measured originals stayed in place: left XL 2/103/223 and YL 25/139/239, right XR 17/112/203 and YR 49/138/226, SHA256 `f28facba…` and `74ece9a2…`.

Left reached ABS_X ±32767 at raw 2 and 223. ABS_Y reached −32767 at raw 25 and +32130 at raw 237, two counts short of stored max 239. Right reached ABS_RX −32418 at raw 18 and +32767 at raw 203, and ABS_RY ±32767 at raw 49 and 226. Held up moved ABS_RX only about 0..−697. After release, all four axes were 0 for about 20 seconds. A later 3-count offset produced about ±318. Deadband was not changed.

A lid close did not enter kernel suspend. The later deep suspend kept the driver bound, probe count 1, the port open, frames running, bad frames at 0, and source `boot`. Stick input and `BTN_WEST` worked after resume. No gamepad, UART, or GPIO error. The Mali regulator warning is unrelated.

Next is the calibration UI in 3C2b, then rumble in 3C3. Joe's Calibrage was not copied.

## 2026-09-23 — Phase 3C1 gamepad input power audit

Measurement only, on the zlyme41 tracer image. No driver change.

Over 60.95 s with the sticks untouched, UART delivered 4078 valid frames (66.91/s), exactly 6 bytes each, and 0 bad frames. The `ttyS1` interrupt rose by the same 4078. All seventeen gamepad GPIO interrupts stayed at 0. A separate 20 s read of the gamepad evdev device counted 0 `EV_ABS`, 0 `SYN_REPORT`, and 0 `EV_KEY`.

Linux 7.0.2 `input_handle_abs_event()` drops an absolute report whose value did not change. An empty `SYN_REPORT` flush does not call `input_pass_values()`. The driver still calls `input_report_abs()` and `input_sync()` once per frame. Those calls do not become userspace wakeups while the published axes stay the same.

CPU0 idle residency was about 83.7% and CPU1 about 84.9%. Both online CPUs still entered `cpu-sleep`. RK817 current readings were not trustworthy, so this is not a battery-power result. The old 6 ms GPIO poll and this UART frame cadence are different mechanisms.

Phase 3C1 recommendation: no driver change.

## 2026-09-23 — Phase 3B gamepad tracer

The Miyoo Flip gamepad tracer passed its hardware gate on the zlyme41 image. Phase 3C has not started.

The live device is `miyoo_flip_gamepad` / `miyoo,flip-gamepad` / `Miyoo Flip Gamepad`, `BUS_HOST`, ids 0. `rocknix-singleadc-joypad.ko` stayed on disk and was not bound. UART frames ran at about 66.8 Hz with no bad frames in the final test. That rate is the analog sender, not a button poll. An untouched boot accepted YL 139, XL 103, YR 138, and XR 112. Directed original-stick extrema were YL 25/139/239, XL 2/103/223, YR 49/138/226, and XR 17/112/203. Fallback 85/200 does not fit them. Signs are negative for left/up and positive for right/down. All seventeen `BTN_*` lines passed press and release. Ten millisecond debounce kept extra edges out of evdev. Suspend/resume kept the same binding, one probe, an open port, and working stick and button input. NextUI opened the new event device directly.

Not done: persistent calibration, rumble, Switch-stick validation, and userspace cutover. Apparent double actions in NextUI are a Phase 3D frontend question. The power/wakeup audit and a MIT-preserving adaptation of Joe's Calibrage (`205f662c`, Kevin Vranken) are Phase 3C. Removing the old ROCKNIX joypad package is Phase 3D. Broad emulator compatibility through InputPlumber is Phase 4.

## 2026-09-23 — Phase 3A gamepad research

Research only. No driver, DTS, kernel patch, or userspace consumer changed. Notes are in `docs/research/joypad-driver.md`.

The stick protocol is 9600 8N1, frame `FF YL XL YR XR FE`, on UART1. A 1.5 Mbaud 8250 figure is the divisor base, not the line rate. Stock `/dev/miyooio` is the vendor button path: a `gpio-keys-polled` node plus a 128-byte char device. Its GPIOs match Zlyme's seventeen gamepad lines. `joy_type` is stored and printed (`-1` none, `0` miyoo, `1` xbox) and is not read by the button path in the May 2025 stock image. No public `miyooio.c` was found. The new driver does not need that char device.

Switch 1 non-Hall stick modules are a designed compatibility target for the same UART front-end, not a Nintendo HID device. `hid-nintendo` is the wrong transport. They are not hardware-validated on Zlyme until the Phase 3D community protocol passes.

The physical device is one `input_dev` named `Miyoo Flip Gamepad` on `BUS_HOST`, with vendor, product, and version left at 0. Axes use `serdev`. Buttons use GPIO interrupts after tracer proof. Rumble stays `FF_RUMBLE` to PWM5. Persistent calibration is per-axis min, zero, and max. A trustworthy boot center replaces the running zero only and does not rewrite the saved file. If the boot samples are moving, the persisted zero stays. If nothing was saved, a compiled default zero is used. Boot measurement must not block probe, buttons, NextUI, or suspend. UART CTS pinmux and DMA stay as they are for the tracer. SARADC is not removed in Phase 3.

Implementation has not started. Phase 3B has not started.

## 2026-09-23 — Phase 2C OTP candidate

The earlier image's RK3568 OTP provider probed and read 128 nonzero bytes, and nothing consumed those cells. Removed `0022` and `0023`. Active Linux patches went from 20 to 18. The new Flip DTB is `056f5f7a554a363b55ec95dd3c1d280075a9e9fd6601e5ee79ee285656bf35ce`; the only decompiled change from `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4` is deletion of `otp@fe38c000` and its cells. OTA: `output/images/zlyme-my355-20260923-000c8b1ae9d1-dirty.tar`, sha256 `7bd23b856bf5d910f45f8476c1ed9e19ecb53ff17ca0c5392f74fc22b5345486`.

That image booted as `Linux 7.0.2 #1 SMP PREEMPT Wed Sep 23 12:49:33 UTC 2026` with no OTP provider and no `otp@fe38c000` node. CPU, GPU, DMC, and thermal policy were still present. NextUI, the joypad, RK817 audio, Wi-Fi, and `/storage` were healthy. Physical boot, display, controls, audio, Wi-Fi, and standard suspend/resume passed. Phase 2 kernel-patch work ends here. Joypad architecture stays in Phase 3. DFI stays in Phase 6. DMC stays in Phase 7.

## 2026-09-23 — Phase 2C inert initramfs warning patch

Removed `40-kernel-7.0/linux/9998-silence-initramfs-unpack-warn.patch`. It only downgrades an initramfs unpack `printk` in the `#else` of `CONFIG_BLK_DEV_RAM`. The my355 kernel has `CONFIG_BLK_DEV_RAM=y`, so that line is not compiled. Zlyme's embedded initramfs is unchanged: `CONFIG_INITRAMFS_SOURCE="/zlyme/output/images/initramfs"`, and the linked cpio contains `/init`. Active Linux patches went from 21 to 20. The Flip DTB stayed `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`. OTA: `output/images/zlyme-my355-20260923-34a6114552cf-dirty.tar`, sha256 `446e7c7b7e3e5eb93d1fcc5d74743160d577d096fd5b4f70a35ec274d16652a7`. No Flip test. OTP remains open.

## 2026-09-23 — Phase 2C Group 3 perf Rust target patch

Removed `40-kernel-7.0/linux/9999-fix-rust-build-error.patch`. It only changed Rust triples in Linux `tools/perf/Makefile.config`. Zlyme does not build that tool. `CONFIG_PERF_EVENTS=y` stayed on, and `CONFIG_RUST` stayed off. Active Linux patches went from 22 to 21. The clean rebuild applied 21 patches, produced no `tools/perf` objects, and left the Flip DTB at `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`. OTA: `output/images/zlyme-my355-20260923-19aebc095a6f-dirty.tar`, sha256 `7f967dfea75966ff0290f90aa63c3ee92e32160ca7c4de9a88b2c0b6c9a87d7e`. No Flip test: nothing on the runtime path changed. OTP and `9998` were not touched.

## 2026-09-23 — Phase 2C Group 2B foreign driver patches

Removed six inherited driver patches: two ST7703 edits, NV3051D timings, ST7701 timings, the AW87391 codec, and the Goodix probe tweak. Active Linux patches went from 28 to 22. `CONFIG_SND_SOC_AW87391=y` was removed. The upstream ST7701, ST7703, NV3051D, and Goodix options stayed on. Linux and the four out-of-tree modules were rebuilt before the image was packed. The Flip DTB stayed `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`. Kernel build time is `Wed Sep 23 02:17:38 UTC 2026`. OTA: `output/images/zlyme-my355-20260923-c528362a7a6e-dirty.tar`, sha256 `35a58f850a8a90d611406b057ebf1c3a3f9d8c2b40531a4d8f26da141d2571df`.

SSH and physical checks on that image passed. The live panel is `rocknix,generic-dsi` at 640x480. No Goodix or AW87391 device appeared. RK817 audio, the joypad, Wi-Fi, libmali, and `/storage` were healthy. The loaded out-of-tree modules matched vermagic `7.0.2 SMP preempt mod_unload aarch64`.

An in-game power-key suspend loop showed up during this test. It comes from `zlyme-keylidmon` treating the wake press as a new suspend, and it predates these patch deletions. The fix is on `main` at `11aecdc2aa3b429e3321c43fb00c86e0c0425d23`, not in this checkpoint. Group 3 was not started.

## 2026-09-23 — Phase 2C Group 2A unused non-my355 patches

Removed the unused `pwm_set_period` helper and the Qualcomm MSM DPU series. Active Linux patches went from 30 to 28. No config, Flip DTS, or runtime file changed. Linux was rebuilt from a clean 7.0.2 extract. `CONFIG_ARCH_QCOM` stayed unset and no DPU objects were built. `rocknix-joypad` `3bc3ef644` compiled afterward. The Flip DTB stayed `3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`. OTA: `output/images/zlyme-my355-20260923-c66fb88b954f-dirty.tar`, sha256 `ffdb36a316a231e313a5003613e345f3327340131da60ea78e465c6161617199`. No separate Flip test: nothing on the my355 runtime path changed. The adc-keys prototype warnings remain and were not fixed. Group 2B was not started.

## 2026-09-23 — Phase 2C Group 1 foreign DTS patches

Removed 15 Anbernic/Powkiddy DTS patches. Active Linux patches went from 45 to 30. No shared RK3566 source, Flip DTS, kernel config, or runtime file changed. Linux was rebuilt from a clean 7.0.2 extract. The Flip DTB stayed byte-identical (`3197ed1b9f39d368689359e8a852e3169bc09253b8c379e72344fcc3a4bf10d4`). Full build passed. Product OTA: `output/images/zlyme-my355-20260923-68f6ca0dea6d-dirty.tar`, sha256 `629b3fe6962c6535e2b4fa3d367f5bad0f13c1d533cd7f91369656b2eedfb54c`.

Miyoo Flip smoke passed: NextUI first frame, built-in controls, audio, `/storage`, and standard suspend/resume. Post-boot `dmesg` had no err, crit, alert, or emerg lines. The kernel build's missing prototypes for `rk_send_key_f_key_up` and `rk_send_key_f_key_down` come from the remaining adc-keys patch. They were not introduced here and stay with the joypad work. Group 2 was not started.

## 2026-09-23 — Phase 2B kernel patch classification

Classification only. No kernel, DTS, config, or runtime change.

All 45 active Linux patches now have an A–F class and a KEEP, REPLACE, REMOVE, or DEFER disposition in `docs/research/kernel-patch-audit.md`. `SYS_CAN_SD` stays the current unconditional clear. The 1992 MHz OPP is optional boost policy, not the 1.8 GHz path. The RK3568 OTP provider has no in-tree consumer; its live probe was not observed because the Flip did not answer SSH. The ROCKNIX GPU clock patch is not imported. Deep suspend, DMC extraction, and the joypad rewrite stay later.

## 2026-09-23 — Phase 2A kernel evidence

Research only. No kernel, DTS, config, or runtime change.

Phase 2 branch `phase-2-kernel-audit` is based on `56cc4c38c5189b96e724c9227d69e6b92203339d`. The selected kernel is Linux 7.0.2. Official ROCKNIX `next` was read at `3993c6bb666022c3f10b7adbc27862103dfa959f`; its handheld RK3566 kernel is also 7.0.2. The hardware wiki pin is `b08e335d31fca41383e01176390914c3d4550ec5`. Notes are in `docs/research/kernel-patch-audit.md`. Forty-five Linux patches are inventoried. None of the symbols checked in the pristine 7.0.2 tarball are already upstream. RK817 fuel-gauge work, GPU clock ownership, and a newer `rocknix-joypad` pin are recorded for later comparison. Joypad rewrite, deep suspend, and DMC extraction stay in Phases 3, 6, and 7.

## 2026-09-23 — Phase 1 Weston compatibility

Normal graphics stay NextUI to direct DRM/KMS. There is no permanent compositor.

Zlyme's own Weston is application-scoped. The native tracer rendered a client and returned to NextUI repeatedly, on both Panfrost/Mesa and libmali.

On Panfrost, `card0` is the Rockchip display and `renderD128` is the Panfrost render node. Forcing `MESA_LOADER_DRIVER_OVERRIDE=panfrost` breaks that split, so it stays unset.

PortMaster Alex the Allegator 2 was the X11 tracer. It uses WestonPack and Xwayland. The stock Crusty path works on libmali. On Panfrost, only `drm gl kiosk system` was changed: no Crusty, system Wayland and GLESv2 for the compositor, and the pack's `mesa_x11_stub` kept private to Xwayland. Other WestonPack modes were not claimed. Alex was visible, controls worked, and both a normal exit and MENU+START returned to NextUI on both GPU stacks. The session, not the pak, removes `/tmp/weston` because MENU+START kills the pak group. No Weston, `seatd`, or Xwayland process is left behind.

Wine is Kron4ek 11 amd64 under Box64, using `winewayland.drv` and Zlyme's temporary Weston. `libxkbregistry.so.0` is enabled. Wine does not use Xwayland or WestonPack. `/storage` is exFAT and cannot hold Wine's prefix symlinks, which is why a prefix there failed to load `kernel32.dll`. A tmpfs prefix was too small. The prefix is a 1 GiB ext4 image at `/storage/.config/nextui/<platform>/wine-prefix.ext4`, loop-mounted at `/run/zlyme-wine/prefix` only while Wine runs. exFAT allocates the whole file. A finished prefix used about 612 MiB. Session cleanup stops that prefix's wineserver, unmounts, and detaches only the owned loop. PuTTY was visible on Panfrost and libmali. Normal exit, a second launch, and MENU+START all returned to NextUI on both stacks.

Wine is an advanced compatibility runtime, not a promise that an arbitrary Windows executable is drop-and-run. Phase 1 does not install Mono or Gecko, does not run Winetricks, and does not keep per-game bottles. A global `WINEDLLOVERRIDES=mscoree,mshtml=` was tried on a card copy of `WINE.pak` and rejected because it changes every Windows program. `wine wineboot -u` under Weston exited 137 with the wineserver still running, so that was not adopted as an automatic bootstrap.

The hardware runs used that card-side launcher. The final source removes the override. The user did not ask for another PuTTY run after that deletion. Source build of this tree is `output/images/zlyme-my355-20260922-f5fe1c022eba-dirty.tar` (sha256 `5a627c316d9e530f29296832d668d65f1b599cac9c8d0517ab59c123d988ebc1`). Its rootfs contains this launcher with no Mono/Gecko override. That image was not run on the Flip.

## 2026-09-22 — Wine graphical smoke on native Weston

`/storage` stays exFAT. Wine's prefix is a 1 GiB ext4 image,
`/storage/.config/nextui/<platform>/wine-prefix.ext4`, loop-mounted
at `/run/zlyme-wine/prefix` only while a Windows pak runs. exFAT
stores the whole file. A finished prefix used about 612 MiB. Symlinks
in that ext4 image are what let `kernel32.dll` load. `c0000135` was
the missing symlink, not a bad loader path.

`WINE.pak` mounts that image, unsets `DISPLAY`, and runs
`zlyme-weston-run wine "$ROM"`. Kron4ek Wine 11.0 then uses
`winewayland.drv`. `libxkbregistry.so.0` comes from libxkbcommon built
with `-Denable-xkbregistry=true` and `-Denable-x11=false`. There is no
Xwayland and no WestonPack. `nextui-session` unmounts the prefix after
the pak returns, including MENU+START. The wineserver is outside the
pak group, so cleanup sends `wineserver -k` for that prefix only.

Installed image
`output/images/zlyme-my355-20260922-f5fe1c022eba-dirty.tar` does not
contain a later card-only edit that exported
`WINEDLLOVERRIDES=mscoree,mshtml=` for every launch. That export was
removed. It would have disabled Mono and Gecko for every Windows
program, not only for first-time setup.

A fresh ext4 prefix, under `zlyme-weston-run` with that override set
only for the boot command, ran `wine wineboot -u`. No Mono or Gecko
installer text appeared. `kernel32.dll` and `system.reg` were written,
and the Wayland driver initialized. The command still exited 137
(`Killed`). `wineserver`, `services.exe`, and `explorer.exe` were
still running afterward. A following `wine cmd /c exit` without the
override also exited 137. That is not a completed bootstrap, so no
marker was added and no new image was built. The saved prefix's
`DllOverrides` section is empty. Final exact-image validation is not
done. Phase 1 is not marked complete.

## 2026-09-22 — PortMaster ESUDO prefix for the Panfrost Weston path

`pm_platform_helper()` is not the WestonPack lifecycle. In
PortMaster-New `28383a4` (2026-09-21), 72 launchers mount
`weston_pkg_0.2` with `$ESUDO mount` onto `/tmp/weston` and unmount
with `$ESUDO umount`. 55 of those launchers never call
`pm_platform_helper()`. Orbo and X-YZE are in that set. Minecraft's
launcher only renames a squashfs and does not mount Weston.

`control.txt` now sets `ESUDO=/usr/sbin/zlyme-portmaster-exec`.
`ESUDOKILL` and `ESUDOKILL2` are unchanged. The prefix execs every
command as given, except a mount or umount whose target is exactly
`/tmp/weston`. libmali, mali, and mali_kbase leave that mount alone.
Any other GPU selection, the same rule as `gpudriver`, may bind a
rewritten `westonwrap.sh` from `/run/zlyme-portmaster/` over the
mounted runtime. The mounted script stays the source of truth. The
tested file is Westonwrap 0.2.7.1, sha256
`b1f879c4099c8aa8513ed04e2cd26ef53f457745a17310304ae414733626a2bc`.
The runtime ships no license, so the script is not copied into the
tree. An unknown hash is not rewritten; the new mount is unmounted
and the command fails.

The rewrite changes only `drm gl kiosk system` on Zlyme Panfrost:
system `libwayland-client.so.0` and `libGLESv2.so.2` resolved with
`readlink -f`, no Crusty preload, no `crusty_gbm` on the compositor
library path, `LIBSEAT_BACKEND=builtin`, and no bundled `seatd`.
Xwayland keeps the pack's `mesa_x11_stub` path. Other wrapper modes
keep the stock Crusty and seatd commands. `mod_Zlyme.txt` does not
grow a Weston hook. `zlyme-portmaster-cleanup` is still the
abnormal-exit path.

Dirty test image
`output/images/zlyme-my355-20260922-eafc97caf537-dirty.tar` was
installed. The helpers match that rootfs and are not bind-mounted.
`ESUDO` is the prefix. After both runs, `/tmp/weston` was gone and
NextUI was running.

On Panfrost the log shows `prepared Panfrost westonwrap`, compositor
preload of the resolved system `libwayland-client` and `libGLESv2`,
no `crusty_gbm` on the compositor library path, builtin libseat,
`card0`, `renderD128`, Mesa, Mali-G52 (Panfrost), and Xwayland on
`mesa_x11_stub`. On libmali the same log shows the stock Crusty
preload and ARM EGL, with no Panfrost wrapper preparation. Alex
exited 0 on both. The panel check was visible, controllable, a
normal return, and MENU+START, on both stacks. Phase 1 is not
complete.

## 2026-09-22 — Phase 1 Weston tracer built, not yet run on the Flip

Chose Buildroot Weston 14.0.2 (MIT) with the DRM backend and kiosk shell.
No Xwayland, no desktop shell, no boot service. PortMaster's
`weston_pkg_0.2.squashfs` stays a runtime a port downloads; it is not in
the image. Reasoning is in `docs/research/weston.md`.

`zlyme-weston-run` drops DRM master, starts Weston with libseat's
builtin backend, runs one client, then stops Weston. It does not start
a `seatd` daemon. Tools → Weston calls `zlyme-weston-test`, which
shows `weston-simple-egl` for three seconds and returns 0 so NextUI
restarts. RetroArch and other KMSDRM launches are unchanged.

`./build.sh --config zlyme_my355_defconfig` then `nextui-rebuild` and
another image build. Rootfs went from about 621M to 623M
(652926976 bytes). Update tar
`output/images/zlyme-my355-20260922-9cdca4cbd556.tar`. The squashfs
contains `weston`, `weston-simple-egl`, `zlyme-weston-run`, and
`Tools/Weston.pak`. No Weston init script.

The Flip at `192.168.0.108` did not answer after that image was packed,
so the NextUI → client → NextUI cycle, the second GPU stack, a
Weston PortMaster title, and Wine were not run. Phase 1 is not complete
until that cycle is repeated on the device. Phase 6 deep-power config
was not touched.

Stock pak copy was still keyed off `version.txt` (`ae652648…-zlyme40`),
so an existing card kept `/storage/.config/zlyme/paks-version` and never
copied `Tools/Weston.pak`. `version.txt` stays the frontend pin.
`paks-version.txt` is a content hash of `paks/Emus` and `paks/Tools`.
`nextui-session` compares that hash to the card stamp. A match still
skips the per-pak walk. A mismatch recopies stock names and leaves
extra card paks in place.

## 2026-09-22 — Weston tracer corrections after the first Flip run

Forcing `MESA_LOADER_DRIVER_OVERRIDE=panfrost` broke GBM initialization.
`card0` is rockchip-drm and `card1` is Panfrost. With the override unset,
Mesa reported EGL 1.5 and renderer Mali-G52 r1 MC1 (Panfrost). The
Panfrost branch of `zlyme-gpu-env.sh` now unsets that variable and
`VK_ICD_FILENAMES`. libmali is unchanged.

The first Weston image reused Mesa configured at 03:17 with
`-Dplatforms=` empty, so the device EGL client extensions had GBM and
no Wayland platform. After `./build.sh --config zlyme_my355_defconfig
mesa3d-dirclean` and `./build.sh --config zlyme_my355_defconfig`, meson
was `-Dplatforms=wayland` (configured 14:00, installed 14:01). The new
`libEGL.so.1.0.0` includes `EGL_EXT_platform_wayland` and
`EGL_KHR_platform_wayland`. Downloads and ccache were kept.

`zlyme-weston-test` used to kill `weston-simple-egl` after three seconds
and exit 0. The device log had `weston status=0` together with
`Assertion ret && n >= 1 failed`. An exit before those three seconds is
now a failure; a client that is still running is killed and counts as
success. Output remains `/tmp/zlyme-weston-client.log`.

Phase 1 is not complete. PortMaster, Xwayland, and Wine were not started.

## 2026-09-22 — PortMaster WestonPack cleanup is owned by the session

`PORTS.pak` execs the port, and MENU+START kills that process group, so
the port cannot unmount `/tmp/weston`. `nextui-session` now calls
`zlyme-portmaster-cleanup` before and after a `PORTS.pak` launch. The
helper only signals processes whose cwd, exe, maps, or fd is under
`/tmp/weston`, waits up to 6s after SIGTERM, then SIGKILL, then
`umount`. No lazy unmount.

On libmali, Alex reached `wp_weston`, Xwayland, and `alex2.aarch64`
with `/tmp/weston` mounted. After the game process exited, and again
after MENU+START, the mount and those holders were gone and NextUI was
running. On Panfrost the launch still fails inside Crusty, and
MENU+START after `Could not create SDL Window` left no `/tmp/weston`
and NextUI running. Phase 1 is not complete.

## 2026-09-22 — PortMaster runtime store for unmodified ports

Alex the Allegator 2 failed on both GPU stacks before Weston started.
The port looks for `weston_pkg_0.2.squashfs` under
`/opt/system/Tools/PortMaster/libs`, which is the read-only image.
The file the GUI installed is
`/storage/Roms/.portmaster/PortMaster/libs/weston_pkg_0.2.squashfs`.
Mounting that squashfs by hand works, including an executable
`westonwrap.sh`. HarbourMaster, with no `HM_*` set, then tried to
create `/roms/tools` on the read-only root. Sourcing `funcs.txt` also
tried to unpack fonts and delete `do_init` inside the image, and
`gptokeyb` was not executable.

`control.txt` and `portmaster-launch` now export
`HM_TOOLS_DIR=/storage/Roms/.portmaster` and the Ports directory
(`/storage/Roms/Ports (PORTS)`, or `/storage/Roms/ports` when that is
the one that exists) unless those variables are already set.
`PortMaster/libs` in the image is a symlink to
`/storage/Roms/.portmaster/PortMaster/libs`. The packaged `libs`
directory only contained `.gitkeep`. `runtime_check` writes into that
same directory, so a fresh card and an existing runtime are the same
path a port reads. The build extracts Noto Sans, copies the `.ttf`
files into `resources`, and removes `NotoSans.tar.xz` and
`resources/do_init`. `gptokeyb`, `gptokeyb2`, `harbourmaster`,
`oga_controls`, and `tasksetter` are executable.

Hardware revalidation is still required:
NextUI → Ports → Alex the Allegator 2 → WestonPack/Xwayland → game →
cleanup → NextUI, on libmali and then Panfrost. Phase 1 is not complete.

## 2026-09-22 — NextUI GLES context on Panfrost

Panfrost's kernel driver, Mesa EGL/GBM, and the Mesa Wayland platform
passed on the Flip. `kmscube` rendered at about 59.19 fps. The Weston
native tracer passed. NextUI did not: `PLAT_initVideo` kept logging
`waiting for display (EGL not initialized)`.

Panfrost/Mesa on this device is OpenGL ES 3.1 (Mesa 26.0.1, Mali-G52 r1
MC1). `plat_video_try_open()` asked for ES 3.2. The frontend does not
need that. Its shader loader rewrites shaders to `#version 300 es`.
The GL calls are vertex arrays, program binaries, framebuffers, and
ordinary texture draws. There is no compute shader, `glDispatchCompute`,
shader storage buffer, image load/store, `glBindImageTexture`, memory
barrier, geometry or tessellation shader, or `#version 310 es` /
`#version 320 es`. The device request is now ES 3.0, set before the
window is created, on every non-desktop target. A failed
`SDL_GL_CreateContext()` still leaves `SDL_GetError()` for the existing
retry line.

`nextui-dirclean` then `./build.sh --config zlyme_my355_defconfig`
rebuilt `nextui.elf` (14:27, 298984 bytes, in the squashfs). Mesa stayed
at the 14:00 `-Dplatforms=wayland` configure. Phase 1 is not complete.

## 2026-09-22 — Phase 0 smoke on the etched card

Etched `output/images/zlyme.img` from the clean product build (kernel
7.0.2 `#1` Tue Sep 22 02:00:08 UTC 2026, NextUI `ae652648…-zlyme40`).
SSH `root@192.168.0.108` after the host key changed. This boot had
already applied `zlyme-my355-20260922-837fff5aad39-dirty.tar`
(`zlyme-update` boot-apply, then initramfs copied the squashfs).
U-Boot blobs were staged under `/storage/.update/bootloader` and not
written.

That boot's `/tmp/boot-timing` was `rcS-start` 48.96 s and
`nextui-first-flip` 56.66 s. `Run /init` was already at 1.36 s, so the
gap was the initramfs squashfs swap, not the list.

A later reboot, with resize skipped and no tar queued, is the normal
framing. Same kernel. `Run /init` 1.36 s, `rcS-start` 3.79 s,
`nextui-first-flip` **10.90 s** (7.1 s after rcS). `nextui.elf` was up.

Checked over SSH: `nextui-session` up, `retrogame_joypad` plus volume,
hall, power, and the headphone switch, `zlyme-audio` sink `codec`
available at volume 40 (cards HDMI and rk817ext), `/storage` exFAT on
`mmcblk0p3` and `/boot` vfat on `mmcblk0p2`, `zlyme-update status`
`queued=no`. `device.conf` is the my355 file.

Suspend: `/sys/power/mem_sleep` was `s2idle [deep]`. Set s2idle, armed
the RTC, `zlyme-radios pre`, then `echo mem`. dmesg shows
`PM: suspend entry (s2idle)` at 535.25 s and `PM: suspend exit` at
537.30 s. A Linux `mem_sleep=deep` suspend-to-RAM cycle at 538.77–540.82 s also returned successfully.
This validates the normal Linux deep suspend state exposed through `/sys/power/mem_sleep`; it does **not** mean Roadmap Phase 6's RK3568 BL31/SIP deep-power configuration (`ARMOFF_LOGOFF`, `vdd_logic` power-off policy, etc.) has been enabled or validated. NextUI's own
log says the platform suspend executable exited 0 and audio was
reinitialized. Codec sink still available after. Wi-Fi dropped during
`zlyme-radios pre` and SSH came back after exit.

A card that has never queued a tar does not get `/storage/.update`.
S18 will not start `zlyme-update` until a tar is already there, and
the first-boot mkfs wipes the exFAT seed. S15 now creates that
directory with the other storage seeds. This etched image does not
have that yet; the directory on this card exists because the OTA
apply created it.

## 2026-09-20 — image rebuild, BASEOS first-flip cuts

`./build.sh --config zlyme_defconfig nextui-dirclean all` wrote
`output/images/zlyme.img` at 01:32 and
`zlyme-my355-20260919-6d6061396fe8-dirty.tar`. First pass died in
`target-finalize`: overlay still had `/roms/ports` as a symlink,
`mkdir -p` could not replace it. Post-build now `rm`s that leftover
then creates a real directory.

BASEOS (`apommel/baseos-my355` `85b67b4`) is a BusyBox hand-off OS
(no UI). Safe copies: skip no-op S12/S13, skip `zlyme-update` when
no tar is queued, builtin `boot_mark`, initramfs `performance`,
do not walk paks when `paks-version` matches. Unsafe copy, reverted
in the tree: udev and S11modules after the list. That never loaded
`rocknix-singleadc-joypad`, so `/dev/input` had no `retrogame_joypad`
and NextUI hybrid-slept with no wake button. S10udevd + S11modules
are Class A again. S26 still modprobes the pad as backup.

## 2026-09-20 — per-card libraries, live Flip

Dropped mergerfs and `/storage/.roms_base`. `zlyme-storage` only
mounts and unmounts, then writes `/run/zlyme/libraries` and
SIGUSR1s NextUI. Games lists one folder per TAG and concatenates
matching dirs. Saves and BIOS stay on the volume the ROM is on.
MENU+Y writes `zlyme-prefs.txt`. Settings → Game has ConfirmAB
cleanup. `BR2_PACKAGE_MERGERFS` is off.

Etchered the 2026-09-19 image. Opening an SD2 console crashed
because `/mnt/sd2/Roms/...` is not a child of `/storage` and
`pathToStack` came back empty. SIGUSR1 at idle had the same
dangling `top` after `Menu_quit`. DraStic exported
`LD_PRELOAD=libdrastouch.so` for BusyBox mkdir. `/roms/ports` was
a symlink, so the Ports bind overlaid OS Roms and every `.sh`
showed twice.

Those four are in the tree. The Flip is running copies from
`/storage/.config/zlyme/bin` until the next image. README slime
gif is half width on GitHub. Settings → Update shows
`zlymeNN (date)` when GitHub names the release that way.

## 2026-09-19 — RA A/B and zlyme RGUI in the RetroArch package

Physical A on the Flip is east. The sdl2 `retrogame_joypad` autoconfig
had that backwards versus NextUI, so RGUI A/B were swapped. Both sdl2
and udev maps now ship from `package/emulators/retroarch/zlyme/`
(`input_a_btn=1`, `input_b_btn=0`) and `ra-run` prefers
`/usr/share/retroarch/autoconfig`. `input_menu_swap_ok_cancel_buttons`
stays false.

RGUI oranges were easy to lose to a stale user cfg. The preset is now
`/usr/share/retroarch/assets/rgui/zlyme.cfg` in the RetroArch package,
and `ra-run` appends `/usr/share/retroarch/rgui-theme.cfg` last. Needs
a rebuild to show up on the Flip.

## 2026-09-19 — NOTES in git, serial dumps dropped

`NOTES/` starts going to GitHub so the hardware diary can travel with
the tree. `TODO.md` and `DEVLOGS/` stay gitignored. Serial dumps from
the September boot/OTA/resize week were deleted; they were already
folded into NOTES/LOGBOOK. No passwords or tokens in the tracked
files — only the empty root SSH login and the `GH_PAT` secret *name*.

## 2026-09-19 — README: Update is Settings, not a Tools pak

Public README now lists **Settings → Update**, drops the Tools Update
pak, and the systems table is the one you edited.

---

## 2026-09-18 — paks, logs, PS2/GC/Wii, live Flip

Etchered zlyme40. About → System logs (off by default) writes
`/storage/.logs` (`dmesg`, session `next.txt`, one `TAG.log` per pak).
Each `launch.sh` sources `pak-log.sh` and calls `zlyme-governor`
play or heavy. Pico carts that sat in `Bios/` moved to
`Roms/Pico-8 (PICO)/`; `pico8_64` stays in `Bios/PICO`.

Knulli recipes for AetherSX2 (ROCKNIX Qt6 EGLFS) and Dolphin nogui.
BIOS is `Bios/PS2` and `Bios/GC/{USA,EUR,JAP}/IPL.bin`, never the ROM
folder. Legal smokes: wLaunchELF, cubeboot.dol, Nintendont loader.dol.

Live: RA 1.22 `appendconfig` is `|` not comma; `input_driver` is
`sdl2` (plain `sdl` is SDL3). Moonlight can leak `/dev/dri/card0`;
session/ra-run/Dolphin call `zlyme-drm-release` (SET/DROP_MASTER).
Fluidsynth 2.4 DT_NEEDED `libSDL3.so.0` — versioned stub, do not
patchelf VERNEED. Aether needs pcre2-16, libaio, patchelf off X11.
PS2 pak started. Dolphin still cannot init a video backend. Wine
11.0 under box64; wineboot still misses PE kernel32. Test ROMs
deleted from `.roms_base` after the run (Splore kept).

---

## 2026-09-18 — splash on FAT, OTA anims, WiFi rows, PortMaster Zlyme

Branding loops are the real GIFs (slime 135f, galaxy 90f, charge still).
Stills stay in initramfs; `.anim` on ZLYMEBOOT and `/usr/share/zlyme`.
`S12splash` restarts after `switch_root` so resize can USR1 galaxy
before S16. OTA already copied Image/dtb; the old on-device updater
skipped the anims. This updater copies them, picks the newest
`zlyme-my355-*.tar`, and flips galaxy while extracting.

WiFi/BT Custom rows no longer draw the name twice. `performLayout`
keeps scroll. One pill of description space so five rows fit. BT
uses the same skip-rebuild and off-path guard as WiFi.

PortMaster: `NAME="Zlyme"`, ROCKNIX first_run alias, seeded
`control.txt` (exFAT HOME split). Version is the Settings short
string (`zlyme39` plus build date), not git describe and not
unquoted Buildroot `VERSION=2026.02.3`.

README hero is `zlyme_slime_loop.gif`. Dropped the Start+Vol wiki
line that is not this device. Deleted Reference GIFs, the glass
checker, `.host-tools/{bc,dc}`, and `__pycache__`.

Live card: slime moves, PortMaster shows Zlyme 0.0.0 (old
os-release). Local tar `zlyme-my355-20260918-abee3d8c5354-dirty.tar`
still has the git string; rebuild before expecting `zlyme39` in
PortMaster. OTA of that tar is untested. Do not Etcher. Do not
start GHA.

---

## 2026-09-18 — close the live-boot pile

Pushed `e0ee31d..18c7b53` on `main` (thirteen commits, first one
`updated gifs, again`). Built
`zlyme-my355-20260917-e0ee31d0ae3f-dirty.tar` locally (sha256
`40552781…`). Did not OTA; the card is still `-zlyme39`. GitHub
warned that `zlyme_galaxy_loop-Reference.gif` is 60 MB.

The boot gif was projected twice: `zlyme-splash` on fb0, then NextUI
killed it for KMSDRM and replayed the same still+anim in SDL. That
looked like static → move → static → list. Init now leaves the PID
across `switch_root`; S16/session reuse it; NextUI only kills it when
it takes the panel. No SDL splash.

Settings: HDMI mode → Display resolution (under Screen timeout);
About NextUIzlyme → version; SSH → SSH user/pss.

Pico-8 stays off the list until `pico8_64` and `pico8.dat` are in
`Bios/PICO` or the ROM folder. Splore is not a bios.

PortMaster said CFW/Device unknown because harbourmaster never reads
`CFW_NAME`. os-release is now quoted `NAME="ROCKNIX"`
`HW_DEVICE="miyoo-flip"`, plus a hardware.py pattern for DTB
`Miyoo Flip`. Same RK3566 640×480 two-stick profile PortMaster
already had.

Also in this tree (split commits): no `.system`; minui-list/presenter
built from Jose’s sources against NextUI objects; NextUI stays
PolyForm NC; PCE/VB/MAME `EMU_EXE` match Knulli `.so` names;
parallel_n64 and melondsds dropped; DAPHNE/OPENBOR/SCUMMVM/WINE paks;
stock paks glob-copied onto the card; OTA pre/post-update hooks.

---

## 2026-09-17 — animated boot splash

`zlyme-splash` was a single blit so the slime glass sat still. It now
loops `splash.anim` (glass overlay) until init SIGTERMs it before
`switch_root`. Rasterize writes that from the README GIF.

---

## 2026-09-17 — slime loop splash and README

New lockup is `zlyme_slime_loop.gif`. Boot/charging/`background.png` are
a mid-loop frame fitted and centered on 640×480 `#050608` (not the
old 0.72 / Y 160 wordmark). README plays the same loop (640×320
paletted GIF, ~230K, `loop 0`) and centers the tagline. `nextui.mk`
drops branding GIFs from the squashfs. Splash still needs initramfs
dirclean + `linux-rebuild` to land in the kernel Image. Cancelled
Actions run `35175983309` and dispatched `35178424594` on `e0ee31d`.

---

## 2026-09-17 — live OTA, then S18 yanked the list

Dropped `zlyme-my355-20260917-630c096b4a33-dirty.tar` on
`/storage/.update`. It applied (apply.log extracted, kernel on
`/boot`, reboot). Live is **2026-09-17** / `-zlyme39` at
`root@192.168.0.108` (host key changed; `.156` is dead).
`zlyme-keylidmon` 257, `zlyme-jackd` 245, NextUI up, Playback Mux
SPK. No `keymon.elf` / `flip-jackd` / `minarch.elf` /
`gametimectl.elf`.

During that apply, `rcS` **forked** S18 at 44.47 s and started
NextUI at 44.78. The list came up; when the tar finished it
`reboot -f` while in use. Tree now **waits** for S18 (S17 still
forked). `/etc` is squashfs so the live unit still forks until the
next tar. Do not Etcher. Do not start GHA.

Daemons: `zlyme-keylidmon` is the msettings shm host (`S26keylidmon`,
pidfile + `killall`, comm may truncate). `zlyme-jackd` is Playback
Mux. No minarch stub; In-Game cheevos are RetroArch via `ra-run`.
Settings main list Network / In-Game / Appearance / System / About;
quick Wifi → BT → Settings.

---

## 2026-09-16 — emu paks for compiled cores

NextUI paks for cores that were in the image with no TAG.pak:
COLECO (gearcoleco), MSX (bluemsx), A5200, P8 (fake08), SG1000
from LoveRetro extras; ST (hatari), A800, INTV, VEC, O2, SGX
for the rest. Each pak has the same PolyForm NC LICENSE as the other
emu paks. README systems table lists them. N64/NDS stay mupen/DraStic;
parallel_n64 and melondsds stay alternate .so files. U-Boot delay=2 is
proven (OTA does not rewrite `u-boot.itb`), not remaining work.

---

## 2026-09-16 — zlyme39 first flip 7.6 s

OTA of the hang-fix plus the udev/lock work. Live reboot: first flip
**7.69 s**, no udev kill, SD2 mergerfs, smart governors (schedutil,
cpu2/3 off, DMC 324 powersave). rc.late 7.95 after the list. Class B
(sshd, wpa, BlueZ, keymon) still starts.

mmcblk1 (games) mounted clean. `ZLYME`/`ZLYMEBOOT` still “not
properly unmounted” — `zlyme-halt` skips those two, then `reboot -f`.
Not new. ON 0x02 / OFF 0x08 is this software reboot.

Landed as three commits on `main` (`3500111` rewritten):
`c912b72` (S18 OTA lock), `e696b07` (mergerfs/udev flock),
`c46fafb` (list before Class B).

---

## 2026-09-16 — zlyme38 first-frame (now in c46fafb)

Pushed `14f2bb1` (plaque/Z) and `9b2c85d` (list without waiting on
mergerfs/splash). Then, now in `c46fafb`: do not mkdir 35 empty
Pretty dirs (and rmdir leftovers), `/usr/lib` first on
`LD_LIBRARY_PATH`, nextui.elf logs on tmpfs, skip `sync()` when
applying msettings, no DRM TV props before SDL, show the list before
`loadLast`/thumbs, mount SD2 by blkid TYPE only.

---

## 2026-09-16 — OTA hung on "applying settings after OS swap"

S18 is Class A and waited. After the squashfs swap it ran
`zlyme-update reapply` → `zlyme-ctl apply-settings` → `zlyme-storage
merge` while forked S17 already held `/tmp/zlyme-storage.lock`. The
splash kept that log line; `/storage/.update/reapply` was not deleted,
so the next boot would hang the same way.

Unstick: delete `ZLYME/.update/reapply`, boot. Reapply is rc.late now,
and it drops the flag before doing gov/led/zram (no merge, no DRM).

---

## 2026-09-16 — zlyme38 first-frame (uncommitted)

Pushed `14f2bb1` (plaque/Z) and `9b2c85d` (list without waiting on
mergerfs/splash). On top of that, not committed: do not mkdir 35 empty
Pretty dirs (and rmdir leftovers), `/usr/lib` first on
`LD_LIBRARY_PATH`, nextui.elf logs on tmpfs, skip `sync()` when
applying msettings, no DRM TV props before SDL, show the list before
`loadLast`/thumbs, mount SD2 by blkid TYPE only.

---

## 2026-09-16 — zlyme37 live, first flip 14.0 s

Etcher of zlyme37. SSH `root@192.168.0.108`. `/tmp/boot-timing`:
rcS 2.27, S28 4.08, nextui.elf 6.80, enter 9.88, gfx 11.03, menu 13.28,
**first-flip 14.04**. Mergerfs `/.roms_base:/mnt/sd2/roms`, GBA 27.
S17 probed mmcblk1p1 as exfat/vfat then ext4 (background). Second
nextui at 176 s was Settings.

Uncommitted on `7b39f4a` before this landing: branding plaque/Z,
U-Boot `BOOTDELAY=0` hook, first-frame NextUI (no hwclock, no
gametimectl), splash wait before switch_root, S17 forked not waited,
session bind not mergerfs, no `kill -9` until first-flip.

---

## 2026-09-16 — zlyme36 Etcher: splash forever

Proven list on hardware was **zlyme35**: dirty tree on `7b39f4a`
(`ae652648…-zlyme35`, tar `zlyme-my355-20260916-7b39f4a21ed7-dirty.tar`)
OTA onto a zlyme32 card. That OTA does not rewrite U-Boot or the
initramfs inside `/Image`. First frame 15.1 s. Session still
bind-mounted `.roms_base` (SD2 merge failed; list still appeared).

zlyme36 was a full Etcher of `zlyme.img`. After resize+reboot the
logo stuck; power sleep/resume still worked (keymon). Storage had
no NextUI logs. Hotspot scan (TP-Link_E44F / 192.168.0.0/24): only
the router and this PC, no SSH.

Tree vs that proven boot (zlyme37): wait the initramfs splash
before `switch_root` (do not leave a process on fb0); do not wait
S17 before S28; session bind not mergerfs; do not `kill -9
nextui.elf` until `nextui-first-flip`; DRM retries 80 again.

---

## 2026-09-16 — mergerfs dest was the .roms_base bind

Live zlyme35: session bind-mounted `.roms_base` onto `/storage/Roms`,
then S17 `mergerfs` failed (`branches can not include the mountpoint`).
Five stacked binds; SD2 GBA (27) never joined the list. Merged live.
Fix: Class A `S17sd2`, unmount-all, xattr-add if already FUSE, session
does not bind over an existing merge. Reboot without that squashfs
shows the empty seed dirs again.

---

## 2026-09-16 — First-frame cuts (zlyme35, building)

Live card still zlyme32. Extra first-frame work on top of dbus/mergerfs:

- NextUI `GFX_init` no longer parses zone.tab or runs `hwclock` (Settings
  still does on the timezone row).
- `main` no longer `system("gametimectl.elf stop_all")` (stub fork).
- `hasRoms` matches a ROM name before stat (exFAT `DT_UNKNOWN`).
- Session: stamp skip of 35 rom-dirs; one bind for `paks/Emus`.
- `S15bootpart` no `seedrng reload` (crng wait). `S20alsa` aplay in bg.
- Initramfs `wait_mount` waits for `mmcblk*p*` before LABEL= hammering.
- Marks: `nextui-enter/gfx/menu/first-flip`.

One local `./build.sh --config zlyme_defconfig`. Do not Etcher. SSH
stays up for post-OTA `/tmp/boot-timing`.

---

## 2026-09-16 — First-frame boot + GHA dispatch-only

Live zlyme32 `/tmp/boot-timing` (DEVLOGS `boot-zlyme32-timing-20260916.txt`):
`rcS-start` 3.52, dbus 3.53–**12.54** (`crng init done` 12.45),
`S28minui` 15.40, `nextui.elf` **26.4 s**. Mergerfs of SD2 in
`nextui-session` was the second 11 s. Do not systemd.

Tree: Class A whitelist, dbus+`/etc/machine-id` in `rc.late`, session
bind `.roms_base` only, initramfs spins on `mmcblk*p*`. GHA Build is
`workflow_dispatch` only (no push, no `0 4 * * *`). Artifact
`retention-days: 1`. Push must not start a run. Make the repo public
then click Run. `NOTES/` not committed.

---

## 2026-09-15 — Splore wget, N64 hyphen, RA sdl2 (zlyme33)

Live card is **zlyme32** (`0094329`) plus SSH binds. Tree is **zlyme33**
(`6a82351`). Do not Etcher. Next squashfs OTA ships the four commits
below. `NOTES/` not committed.

User on the panel (zlyme32): lid vs power **works**; Splore UI download
**works**; volume **works**. Still untested by the user: Smash from
the NextUI list, Switch Pro in a game after Settings shows Connected,
A2DP vs HDMI by ear.

SSH QA on throwaway `/tmp/zlyme-qa-roms` (tmpfs; do not pollute
`/storage/Roms`): Smash stayed up once `EMU_EXE=mupen64plus-next`
(GLideN64, dynarec, sdl2). First ra-run fallback used `tr _ -` and
produced `mupen64plus-next-libretro.so` (wrong). Freedoom needed
`gzdoom -iwad` plus NextUI `.config/nextui/shared/configs/gzdoom`.
EasyRPG zip/dir still exit 1 (empty stdout). Do not bind-mount wget
over the BusyBox symlink (Too many levels of symbolic links). Pico-8
is `wget URL -q -O file`; `--fail` made curl 22 on a 404 body.

Commits (PLAN: one or two sentences on why):

- `088efe4` URL-first wget + Wget UA so Splore HTTPS writes a cart
- `d2cef56` N64 pak + Knulli hyphen core so Smash finds the .so
- `ad4227c` RA sdl2 + sdl2 autoconfig + skip already-connected HID
- `6a82351` gzdoom `-iwad` so a WAD is an IWAD

Push `main` for a new three-stage GHA Build (`cancel-in-progress`
false). HTTPS credential helper is a missing `/tmp/ghbin`; push was
`git@github.com:Zetarancio/zlyme.git` `7c59518..6a82351`. Device was
asleep (`192.168.0.108` no route) so no live `/tmp/boot-timing`; used
`NOTES/DEVLOGS/boot-zlyme30.log`.

**Boot (why it feels slow).** Do not switch to systemd. Class A is
already “NextUI before radios”; the holes are:

- Initramfs `wait_mount` is `sleep 1` × 20 after `mmc0` tuning -5
  and `LABEL=ZLYMEBOOT: Can't lookup blockdev` (~1.7 s). First empty
  card then sat in resize until reboot at 17.8 s.
- `S30dbus-daemon` runs *before* seedrng. `dbus-uuidgen --ensure` is
  the ~8 s in `/tmp/boot-timing`.
- Class A blacklist still runs `S40network` / avahi / crond / syslog
  before the list. `ifup -a` is only `lo`, but it is the wrong class.
- `nextui-session` mkdir + mergerfs + bind every `.pak` after S28
  and before `nextui.elf`.
- Live U-Boot still `Hit any key … 2` (OTA does not write the ITB).

Keep BusyBox. Whitelist Class A. Poll MMC at 100 ms. Move dbus to
`rc.late`. Meter is `/tmp/boot-timing`.

---

## 2026-09-15 — keymon, lid, governors (zlyme31)

Tree `179cfd9`. GHA `cancel-in-progress: false` so a push does not kill a
ccache pack. Settings lost NTP / CPU boost 1992 / merge; USB OTG (top),
LED Auto, two-line power hints. Clock is `S49ntp` after Wi-Fi only.

`keymon.elf` is the msettings shm host (S26, before NextUI). Volume and
MENU+vol brightness only while nextui/settings are not running, with
`EVIOCGRAB` on `gpio-keys-volume`. Lid always: in the list,
`pwr.requested_sleep` on close; in a pak, radios-then-mem like ROCKNIX.

Governors: smart 2c 408–1800 DMC 324; play 4c 408–1800; heavy 4c
1104–1800 schedutil (PSP/NDS/DC/N64/Saturn). Ports and Moonlight are
play. `HID_NINTENDO=m` + Pro autoconfig. PSP.pak has no `--memstick`.

Local `./build.sh --config zlyme_defconfig` is this flash. Do not start
a second one on the same `output/`. Etcher `zlyme.img` on the empty QA
card (not a games card). Panel tests (ears, lid, Splore download, N64
rumble, Pro in a game) cannot be faked over SSH.

---

## 2026-09-15 — Device QA: audio matrix, BT pads, faster boot

Assembled unit, no UART. SSH `root@192.168.0.108`. HDMI-A-1 connected
to an Optoma 1080P (ELD `sad_count=1` LPCM 2ch — this projector **has**
HDMI audio). Sink was still `codec`. ROCKNIX needed a reboot for HDMI
A/V; we poll ELD. Jack is `rk817_ext Headphones`. `wlan0` + wpa up.
`bluetoothd` up, `zlyme-btsink` not running. Switch Pro
`98:B6:D4:58:CD:79` Trusted, Paired=false. `mkdir` of a BlueZ MAC dir
on exFAT → Invalid argument. No `timeout` applet. `hidp` not loaded
until a manual modprobe. USB: Realtek 8733bu + Verbatim STORE N GO
(`/dev/sda`). FF on `retrogame_joypad`. `fw_printenv bootdelay` empty.

Tree work this pass (not `NOTES/`):

- Wi-Fi enable/disable is a live rfkill toggle; DHCP is background.
- Splore matches minui-pico-8-pak (`-root_path` romdir, XDG under home).
- `zlyme-btsink` is A2DP → HDMI-if-ELD → codec. S46 always runs.
- `/run/bluetooth` is tmpfs; `zlyme-bluetooth save|restore` tars to
  `/storage/.config/bluetooth.tar`. `dbus-send` Powered/Pairable.
  Persistent `bluetoothctl --agent=NoInputNoOutput`. `modprobe hidp`.
- NextUI userdata is `/storage/.config/nextui/{shared,my355}`. No
  S15 migrate. OTA keeps `apply-settings`, drops palette sed.
- MergerFS pools `.roms_base` + SD2 + USB. USB host overlay hits
  upper EHCI+OHCI. `PLAT_setRumble` is FF on the joypad. README 70%
  banner. `CONFIG_BOOTDELAY=0`. rcS Class A then NextUI; Class B
  `rc.late` via inittab `::once:`.
- Research only: `NOTES/RESEARCH-INPUTPLUMBER.md`,
  `NOTES/RESEARCH-JOYPAD-DRIVER.md`. Do not package InputPlumber.

Live card still has `.userdata`; after OTA, one SSH `mv` into
`.config/nextui/`.

**Verify on new card (2026-09-15, AOC 24G1WG4, UART + Saponetta AP).**
Empty card, Etcher of the dirty zlyme30 image. First boot resized OK,
second boot NextUI. Class A `rcS-nextui-ready` ~14.7 s; **dbus is ~8 s**
of that. U-Boot still counts **Hit any key … 2**. Host ping to
`192.168.0.108` often fails (AP isolation); serial is the console.
Later the UART went 0 bytes and SSH timed out — do not assume it is up.

- Wi-Fi live off/on: wpa gone + rfkill, then COMPLETED and DHCP again
  (`wlan0` `192.168.0.108`).
- HDMI: ELD `sad_count<TAB>1` on the AOC. Stock parser wants `=`.
  Live bind → `ZLYME_SINK=hdmi`.
- MergerFS: Verbatim STORE N GO wiped to exFAT `ZLYMEROM`, top EHCI.
  `/mnt/media` needs tmpfs. Merge cat `a.iso` / `b.iso` / `c.iso`.
- BT: adapter `14:5D:34:35:F5:2D`. Pairable after dbus retry. Agent
  stayed alive once stdin was held. Switch Pro `98:B6:D4:58:CD:79`
  Paired/Bonded/Trusted/Connected, `js1`, tar at
  `/storage/.config/bluetooth.tar`. RA still ignores it (`hid-generic`,
  0 evdev bytes).
- Clock was 2017; after `date -s` lexaloffle HTTPS 200. Splore UI not
  walked (needs NTP on the card). Pico-8 binary is on the card.
- Headset A2DP connected (`ZLYME_SINK=bt`) but crackles on GB under
  Smart (cpu2/3 offline, DMC 324). Volume in-game does nothing (no
  keymon / volmon). PSP `--memstick` not launched after the fix.
- FF bits on `retrogame_joypad`; no in-game rumble pulse.

**Image (2026-09-15 01:23).** Pin **zlyme30**. Tar
`output/images/zlyme-my355-20260914-94d740a2802c-dirty.tar` (616M,
`551e1e3e…`). MergerFS 2.40.2 needed
`0001-skip-make-unique-on-cxx14.patch` (gcc 14 already has
`std::make_unique`). First squashfs used a stale NextUI extract
(zlyme29 `.stamp_built`); bumped the pin and rebuilt so Settings
shows **USB host (top port)** / **Merge extra storage**, rumble,
and `.config/nextui` paths.

---

## 2026-09-14 — Split commits + GHA 6h stages

Push runs after `dac38cb` did start Docker, then GitHub **cancelled**
them at the hosted 360-minute cap: `34801512689` (~6h1m) and
scheduled `34828905859` (~6h3m), both during Build image. Pack ccache
ran `if: always()` but `tar` hit “file changed as we read it” because
the container was still writing; the uploaded `ccache-my355.tar` was
tiny. `output/` is 51G (build 40G) so it cannot be an artifact (10G)
or a Release file (2G).

Fix: reusable `build-stage.yml`, caller runs stage-a → b → c, each
`timeout -k 3m 310m ./build.sh`, exit 0 on 124/137/143 without an
image, skip later stages if `zlyme-my355-*.tar` exists, then a
release job. Stop docker before packing; prune 1.5G; zstd to
`zlyme-cache`. Also `actions/cache` per run/stage.

Product tree committed in eight slices; `NOTES/` not committed;
leftover `res/branding/{Beaker,Logo,Z}.png` left untracked.

---

## 2026-09-14 — Device UI test (no serial), zlyme29 live, GHA Docker

Device reassembled, no UART. UI pass against the zlyme28 dirty tar.

**GitHub.** Run `34800359003` died `docker: command not found` after
`maximize-github-runner-space` removed docker-engine. Committed only
`.github/workflows/build.yml` (`dac38cb`): skip that component, reinstall
Docker if missing, publish `zlyme-<run_id>` as latest. Pushed and left
push run `34801512689` (cancelled the duplicate workflow_dispatch).
Product fixes stay uncommitted; live rebuild only.

Live image:
`output/images/zlyme-my355-20260914-dac38cbcd3bc-dirty.tar`
(and `zlyme.img`). Drop the tar on `ZLYME` as
`/storage/.update/zlyme-my355-update.tar` and reboot. Do not Etcher
over a games card. Splash is in the kernel Image this time
(initramfs dirclean + linux-rebuild).

**PSP folder.** `Roms/Sony PlayStation Portable (PSP)/PSP/` is the
PPSSPP memstick (`SYSTEM`, `SAVEDATA`, …), native, not a ROCKNIX
rename leftover. Hide it (`skipCompanionFolder`). Launch with
`--memstick` under userdata so new saves do not land next to ISOs.

**Volume.** Overlay showed on the first PLUS/MINUS; hold did nothing;
volume itself never changed. No `keymon.elf`, `BTN_MOD_VOLUME=BTN_NONE`
so the overlay hid after 500ms. `PWR_update` now `SetVolume` /
`SetBrightness` on `justRepeated` and keeps the pill while PLUS/MINUS
is down.

**Pico-8 BBS.** List could update, cart download said cannot connect
to BBS. Wrapper now sets `SSL_CERT_FILE`, `-home` on shared userdata,
and `-root_path` to the rom folder when that dir is writable.

**Contrast/saturation.** DRM TV props blacked the panel; stored values
survived reboot. Sliders removed on my355 (`hasContrastSaturation`
false). `apply_bcsh` stays at identity 50 for contrast/sat. Did not
revert the whole BCSH commit (brightness/hue still used).

**Wi-Fi keyboard.** `KeyboardPrompt` is Custom with zero items.
`MenuList::draw` returned before `drawCustom`. Palette was a red herring.

**Boot logo.** Previous pass was 40% smaller in the upper third and not
in the Image (initramfs is baked into the kernel). SCALE_MUL 0.72,
center Y 160. Needs `zlyme-initramfs-dirclean` + `linux-rebuild`.

**About.** Label NextUIzlyme; version `zlyme29` plus build date; kernel;
SSH `root` / empty password; wlan0 IP.

**Status LED Battery.** Auto mode: green on battery, red charging, flash
red when low. Wanted. Green/Red/Off lock the colour.

**Other UI.** Restore backup desc shortened. RGUI theme appended last.
vtree ActiveTheme forced from Files.pak userdata copy. Moon icon calls
`PWR_sleepNow` (mem via `BIN_PATH/suspend`). Battery percent default on
plus one-shot migrate. README lists `build.sh` flags. Update.pak can
send `Authorization` from `/storage/.config/github-token`.

---

## 2026-09-14 — GitHub remotes

Pushed `main` to private https://github.com/Zetarancio/zlyme (`823d22a`).
Public https://github.com/Zetarancio/zlyme-cache has a stub README so
releases can exist. Secret `GH_PAT` is on `zlyme`. README banner points
at `zlyme-horizontal-exact.svg` (`39cc361`); Update.pak repo file is
`Zetarancio/zlyme` (`68489a4`). Root `.gitignore` never ignored
`README.md`. First Actions `Build` started on the push.

---

## 2026-09-14 — zlyme27 tree on main (udev MENU, RPG, Settings)

Four commits after leftovers were dropped (`linuxraw`/`sdl2` autoconfig
gone, `zlyme-storage` not remapping the library card):

- `b80e48d` mali_kbase lowercase IRQs first
- `cc9c9a7` EasyRPG + mkxp-z cores/paks
- `ef199ff` RetroArch RGUI from MENU on **udev**, Enable Hotkey nul, js 10
- `d411b53` Settings Network hub, MENU+Start `zlyme-pak-hotkey`, NextUI
  `.m3u` pass-through and skip companion `Game/` when `Game.m3u` exists

Library card uses NextUI `Pretty (TAG)` names, `.media/{rom}.png`, and
`Game.m3u` next to `Game/`. Lunar playlist loaded disc 1/3 live.

RA MENU is **not** SDL Guide 5. That index is R1 on this pad.

---

## 2026-09-14 — branding v4, fb0 blank, README m3u

Three commits on `main` after leftover autoconfig was already gone:

- `f0efd94` faithful pack v4: lockup 40% smaller in the upper third of
  640×480, palette `#FA7C08` / `#EC2A01`, matching vtree / PortMaster /
  RGUI (ozone is not built)
- `1bcd537` `PLAT_initVideo` fills `/dev/fb0` with `#050608` so dropping
  KMSDRM does not flash the initramfs splash (first Settings/pak return
  after reboot). Untested on device (SSH dropped)
- `013ce94` README: second card uses `Pretty (TAG)`, art is `.media/`
  only, `Game.m3u` next to `Game/`

Incremental `./build.sh --config zlyme_defconfig` succeeded
(`zlyme-my355-20260914-d411b537adbd-dirty.tar`, built with branding+fb0
before the three hashes). NextUI **zlyme28**.

SSH to `192.168.1.62` came back. ES `images/` for GB/GBC/GBA/MD/PSP/
EasyRPG/PS was already in `.media/` (NextUI `{stem}.png`, not a
frontend change). Copied PortMaster `cover.png` / `screenshot` for all
22 `.sh` launchers into `Ports (PORTS)/.media/`. Four JPEGs needed a
host convert (device ffmpeg has no `scale`). Spring Eternal / Touhou
Mother have no title PNG. No GitHub push: no `gh`, no token.

---

## 2026-09-13 — First-boot resize reboot works without partprobe

Fresh image, no `partprobe` on the live vfat, `reboot -f` after mkfs.
Resize printed `OK`. The automatic reboot and a later manual reboot both
loaded `/Image` (three u-boot passes, zero `Invalid FAT entry`). GPT still
`uboot` / `boot` / `storage`, p3 **57 GiB**, labels `ZLYMEBOOT` / `ZLYME`,
`#autoresize=true`. Landed on `main` as `239d475`.

---

## 2026-09-13 — First-boot serial: not a partition name

Fresh `zlyme.img`. Resize printed `OK`. After that, GPT names were still
`uboot` / `boot` / `storage`, labels `ZLYMEBOOT` / `ZLYME`, p3 grown to
57 GiB. `reboot` then: u-boot scanned `mmc@fe2b0000` part 2, loaded
`/extlinux/extlinux.conf`, `Retrieving file: /Image` → `Invalid FAT
entry`. So u-boot still finds the boot partition; FAT1 is what died
(`partprobe` + `sed` on the live vfat; remount `/boot` was busy).
`S13resize` on `main` (`239d475`) skips `partprobe`, leaves `autoresize`
for the next boot, and `reboot -f` like ROCKNIX. That card needed a reflash.

---

## 2026-09-13 — Serial field test: BT audio, DMC, contrast, RTC mem

`echo freeze` is not how this board sleeps. UART is not a wake IRQ;
the power button woke s2idle, then `zlyme-btsink` saw A2DP drop and
`kill -9` RetroArch, so the ROM relaunched from the start. That is the
watcher, not kernel resume.

Real path (same as 2026-09-10 and ROCKNIX `logs/suspend-*.sh`):

```
echo 0 > /sys/class/rtc/rtc0/wakealarm
echo +N > /sys/class/rtc/rtc0/wakealarm
sync
echo mem > /sys/power/state
```

`rk808-rtc` wakeup is enabled. Serial showed `abcdeghijsramwfi…` and
`PM: suspend entry (deep)` / `exit`. RetroArch pid **23013** survived
three in-game cycles (with ROCKNIX-style radio stop, without it, and
the first RTC proof). NextUI pid **27686** survived a menu cycle with
Wi-Fi already off. `zlyme-radios resume` brought `wlan0` back to
`192.168.1.62` and `hci0`. `S40`/`S45` start FAIL on a second resume is
already-running.

ROCKNIX `sleep.sh` stops Bluetooth and disables Wi-Fi **before** mem
so `rtl8733bu_power_suspend_late` can cut the combo GPIO without
`hci_dev_close` hanging freeze. `zlyme-radios pre|resume` is that
sequence; `PWR_enterSleep`/`PWR_exitSleep` call it (needs next
nextui.elf). Live tests inlined the same stops over serial.

Audio: buds were connected, RA still had `pcmC1D0p` because
`audio.conf` was never `bt`. `ZLYME_SINK=bt` + relaunch → no kernel PCM,
`pcm-io` thread, codec subdevice 1/1 free. Disconnect/reconnect with a
patched `nextui-session` reload loop relaunched GB onto codec then BT.
Watcher must debounce; `/tmp/zlyme-keep-emu` holds it across mem.
CMF Buds showed `Paired: no` after a bluetoothctl disconnect; later
`connect` said not available.

DMC: `zlyme-governor performance` + DDR hammer **324M → 1056M**
(`simple_ondemand`). Smart locks 324M. After mem, `cur_freq` can read
1056M while min=max=324 until the governor is written again; bounce
fixes it. Contrast: DRM TV props at identity 50; with DRM master,
set 80 reads back 80, `zlyme-bcsh` with msettings contrast=5 → 75.

Live bind-mounts: `/storage/.zlyme-live/{nextui-session,ra-run,zlyme-btsink,zlyme-radios}`.
Squashfs still zlyme25 until the next OTA.

---

## 2026-09-13 — zlyme26 image (BT sink, radios pre/resume, DMC poke)

Built `ae652648…-zlyme26`. Watcher now applies on first poll, debounces
codec fallback 12s / BT 2s, and `zlyme-radios resume` keeps
`/tmp/zlyme-keep-emu` for 25s so mem cannot look like a ROM restart.
OTA tar `output/images/zlyme-my355-20260913-599ac2c10583-dirty.tar`
sha256 `f38b7817a4be6d4260b29fc99c2d9ce48146a7aeffac2d1e7174dbbb8671028d`.
Drop it as `/storage/.update/zlyme-my355-update.tar` and reboot. Do not
Etcher `zlyme.img` onto a games card.

---

## 2026-09-13 — S13resize FAT1 smash (again), Knulli method

Stage 8 first boot still hit the 2026-09-12 brick: `OK, rebooting` then
u-boot `Invalid FAT entry` on `/Image`. FAT1 was zeros; FAT2 still had
the chain. The previous "fix" (lazy-umount `/boot` before `sgdisk` /
`partprobe`, leave `autoresize=true`, `reboot -f`) is what did it.
`/boot/zlyme` is the squashfs loop, so umount is lazy; `partprobe` then
rereads a busy VFAT.

Live: copied FAT2 → FAT1 from the u-boot prompt (`mmc read`/`mmc write`;
no gadget/`ums` in this u-boot). `fatls` saw `Image`. Commented
`autoresize` and `reset`. Kernel loaded. `ZLYME` was already grown
(~57G). Games card is SD2 (`mmcblk1p1` bound into `/storage/Roms`).

Tree: `S13resize` now matches Knulli `board/fsoverlay/S02resize` +
ROCKNIX `fs-resize` — **keep `/boot` mounted**, umount storage only,
`sgdisk -e`, `parted resizepart`, `partprobe`, `mkfs.exfat` on the
≤600MB seed, `sed` comment `autoresize`, remount ro/rw to flush. No
`reboot -f`. Size >600MB only drops the trigger (do not copy Knulli's
always-`format_internal`). Live squashfs still has the old script;
autoresize is commented so it will not run again on this card. Next
image/OTA picks up the overlay.

---

## 2026-09-13 — Stage 8 Flip polish (zlyme23)

VOP2 BCSH via DRM TV properties (identity 50) so contrast/saturation
are live for NextUI and emus. Spruce-like `zlyme-governor`: Smart
(schedutil, cores 01, DMC 324M), Performance (1800, 0123, DMC 1056M),
idle conservative when the screen is off, optional 1992 boost.
Dropped CPU/GPU governor pickers. zram 384 MiB lz4 default on.
IRQ affinity is supposed to pin RTL8733BU EHCI `fd880000` + MMC →
CPU0; the first tar matched `dw-mmc`/`mmc0` and never hit live names
(`dw-mci`, `ehci_hcd:usb4` under `fd880000.usb`). Tree matcher fixed
after the serial probe. `ZLYME_SINK` is in `nextui.elf` (`codec`).
MENU stays raw button 10 (dropped SDL `guide:b10`). PortMaster path
is `Roms/Ports (PORTS)/`. Kernel rebuild for BCSH + conservative.
Flashed kernel still has `CONFIG_USB_NET_CDCETHER=y` (NCM/MBIM select
it); fragment/`linux.config` now also turn those off for the next
rebuild. Keep `CONFIG_DEBUG_KERNEL`. Bluetooth scan `FAIL-BUSY` is
still open. Live sysfs (after FAT repair): Smart schedutil cores 01
DMC 324M GPU simple_ondemand; `zlyme-governor emu psp` → performance
0123 DMC 1056M; idle conservative 1104M; zram 384M lz4 swappiness 45.

---

## 2026-09-13 — Plan closed (zlyme22)

Stages 1–7 plus the remaining UI/OTA polish are on the device.
Image pin **zlyme22**. SSH is OpenSSH (SFTP). Named Zlyme palette
(hint orange, not gray). vtree `theme/Zlyme.ini` + `ActiveTheme=`.
PortMaster theme is `PortMaster/themes/Zlyme`. Pico-8 binary is
**MinUI `Bios/PICO/`**; leftover `Bios/pico8_64` was moved there.
Splore mapper is the pak process so it ungrabs the Flip pad on
exit (a background grab had left NextUI with no buttons). RetroArch
needs `liblzma.so.5` (CHD); curl/Overlays/ScrapeGoat need
`libzstd.so.1` — both now in the defconfig (live card has copies
under `.system/my355/lib`). Launch check with ROMs present: GB,
GBA, GBC, MD, PS, PSP, Splore. Other system folders were empty.
Tools paks started; Update.pak still wants a real GitHub repo in
`/usr/share/zlyme/github-repo`. Settings list font stayed stock
(large glyphs artifacts).

---

## 2026-09-12 night — Casad, DHCP, Overlays

After OTA, `zlyme-wifi connect` reached `COMPLETED` but left
`169.254` (udhcpc had run while SCANNING). Kill + `udhcpc` after
associate got `192.168.1.62`. Overlays then fetched GitHub (`minui-list`
“Pick a system (res: 480p)”). Artwork Scraper list UI OK. `zlyme-wifi`
now starts DHCP after associate. `boot-apply` with an empty queue no
longer writes `FAILED`.

---

## 2026-09-12 night — OTA tar proven

Drop-tar-and-reboot worked: `boot-apply` extracted on `ZLYME`, copied
Image/dtb, initramfs `copying new zlyme` then `zlyme committed`, loop
mount, login. Live `/boot/zlyme` 585764864 bytes; `/usr/bin/curl`
8.20.0 present. `FAILED` after that was a probe calling `boot-apply`
with an empty queue (tar already consumed). Overlays now finds curl;
GitHub fetch failed (`Could not resolve host`) with `wpa_state=DISCONNECTED`.

---

## 2026-09-12 night — Tools paks on serial

Seven of eight Tools paks started via `/tmp/next` (needed `kill -9`
on `nextui.elf`; SIGTERM left it running). Settings, Files, Autocal,
PortMaster (`pugwash`), Moonlight, ScrapeGoat, Artwork Scraper: OK.
Overlays **FAIL**: `curl: not found` (image has `libcurl` + busybox
`wget`, not the CLI). Toast said “Check Wi-Fi”; helpers were present.
`BR2_PACKAGE_LIBCURL_CURL=y` added to `zlyme_defconfig`. First `all`
left libcurl stamped without the CLI; `libcurl-rebuild all` put
`/usr/bin/curl` in the squashfs. Update tar:
`output/images/zlyme-my355-20260912-4bf848d295a1-dirty.tar` (symlink
`zlyme-my355-update.tar`). Settings still logs BT `FAIL-BUSY` but stays up; `/tmp/last.txt`
is `/storage`. Layout: `#autoresize`, p2 ~1300M FAT, p3 ~57G exFAT,
no queued OTA. Kernel noted ZLYMEBOOT dirty FAT after resize; first
FAT sector was not zeros.

---

## 2026-09-12 night — licenses, Splore, 3-partition boot

PLAN: every package/pak ships a `LICENSE` (`f3620e7`). Pico-8 is a
NextUI system (`PICO.pak`, `Pico-8 (PICO)`, Splore dummy cart from
josegonzalez/minui-pico-8-pak). User still supplies `pico8_64`.

`libudev-zero` deleted — the image is eudev.

GPT: dropped the `rootfs` partition instead of renaming it to
`ZLYMEROOT`. Three partitions: `uboot`, **1300M** FAT32 `ZLYMEBOOT` (Image
with embedded initramfs + live `zlyme` file), 32MB exFAT `ZLYME` seed.
OTA pending squashfs is on `ZLYME`; initramfs copies it onto FAT.
Existing cards need a reflash (empty card). U-boot still only wants GPT
name `uboot`. eMMC DTS `label = "rootfs"` is NAND, untouched.

## 2026-09-12 late — 1300M ZLYMEBOOT, OTA on ZLYME

`ZLYMEBOOT` is a fixed **1300M** (one live `zlyme` + kernel, not two
squashfs copies). OTA extracts to `/storage/.update/pending/` on the
exFAT games partition. Userspace copies Image/dtb/overlays/extlinux
onto `/boot`, then reboots. Initramfs copies `pending/zlyme` over the
live FAT file in place. Interrupted copy can brick; that is the size
trade. Factory `zlyme` stays on FAT (the 32MB seed is wiped on first
boot). Busybox initramfs has `VOLUMEID_EXFAT` so `LABEL=ZLYME` mounts.
`CONFIG_MKPASSWD` is off (static glibc has no `libcrypt.a`). Install dest
is `INITRAMFS_DIR`, not `ZLYME_INITRAMFS_DIR` (Buildroot reserved).
Image built 2026-09-12 19:05: `zlyme.img` 1.4G, GPT `uboot` 4M +
`boot` **1300MiB** FAT `ZLYMEBOOT` + `storage` 32M. Squashfs 559M on
FAT. Initramfs is packed in `Image` (gzip). Update tar
`zlyme-my355-20260912-dce2d76f091b-dirty.tar`. Live card was reflashed
to this GPT. First-boot resize after the umount fix reached login.

## 2026-09-12 — S13resize wiped FAT1

First boot loaded `Image`, loop-mounted `zlyme`, then `reboot -f` at
~15.7s (`S13resize`). Second boot: u-boot `Invalid FAT entry` on
`/Image`. FAT1 start was zeros; FAT2 still had the chain. `S13resize`
now umounts `/boot` before `sgdisk`/`partprobe` and umounts after
clearing `autoresize`. Reflash with that fix: first boot `OK, rebooting`,
second boot reached `zlyme login:` (no `Invalid FAT entry`).

---

## 2026-09-12 evening — libmali default, RA MENU, BT abort, OTA almost

HEAD after this drop: `dce2d76` (five commits on `aa08679`). NextUI pin
**zlyme17**. Live Flip had been on an `aa08679bbbfe-dirty` squashfs
(kernel 7.0.2) with Casad Wi-Fi, DHCP **192.168.1.62**, serial
`/dev/ttyUSB0` 1500000. Credentials are not in this file.

### GPU

Default is **libmali**. Mesa stays `/usr/lib`; blob bind-mounts onto
`readlink -f` of `libEGL.so.1` and friends (binding `libEGL.so` never
unmounted). `S15gpudriver` after `S15bootpart`. Mali Vulkan ICD
(`mali_icd.json`); no PanVK in Buildroot 2026.02. Pick Vulkan inside
the emulator. `mali_kbase` IRQ JOB -6 is normal. Overnight NOTES said
"do not ship Vulkan"; that was reversed once the question was "ICD +
in-emu", not PanVK-as-OS-default.

### RetroArch

MENU (10) = hotkey + menu_toggle; MENU+Start (9) = quit. `/etc`
appendconfig no longer forces `video_driver`, so a user Vulkan line
can stick. In-Game help text updated. Tested earlier on gpSP.

### Settings Bluetooth

Abort was `menu.hpp` `getValue` asserting on empty values (Bluetooth
row was Generic + DeferToSubmenu). Now a Button; empty index returns
`{}` / `""`; scan list rebuild deletes stale items under lock.
`FAIL-BUSY` on scan is still the radio.

### OTA — the failure that defined the updater

`make-update-tar.sh` already packed KERNEL+dtb+squashfs. The 16:09
`zlyme-update apply` **dd'd PARTLABEL=rootfs while it was `/`**.
`606+1` records, 635592704 bytes filled p3 exactly, then:

```
SQUASHFS error: … data probably corrupt
reboot: Input/output error
```

SysRq `echo b > /proc/sysrq-trigger` came back. New image booted.
That is not an updater. Batocera/Knulli unpack a squashfs **file**
onto FAT `/boot`. Ours **is** the GPT partition.

Revised contract: drop tar on `/storage/.update/zlyme-my355-update.tar`,
reboot. `S18zlymeupdate` (before NextUI) runs `boot-apply`: extract on
exFAT, snapshot `.config`/`.userdata`, copy busybox+updater to tmpfs,
`pivot_root`, unmount squashfs, refuse dd if `/` is still squashfs,
install `/boot`, `apply-overlays`, dd, SysRq reset.

`FDTOVERLAYS` is not rewritten every boot (U-Boot reads extlinux
before Linux). Settings apply on change; OTA writes them after stock
extlinux lands.

### Size check, then shrink

17:01 tar squashfs **635596800** vs live p3 **635592704** (exactly
4096 over). Updater printed `ERROR: squashfs … larger than
/dev/mmcblk0p3` and did **not** dd. Old OS intact. `pending/` was
deleted so an old S18 could not `install_boot` then fail dd.

Rebuild: `BR2_TARGET_ROOTFS_SQUASHFS_EXTREME_COMP` (zstd **-22**,
was not on by default) + 1MiB blocks. post-image GPT rootfs =
squashfs rounded + **32MiB slack** (new flashes only).

17:16 artefact squashfs **585674752** (~50MB under live p3). Tar still
named `zlyme-my355-20260912-aa08679bbbfe-dirty.tar` (uncommitted
describe). User was going to copy it onto the card. **pivot/dd/reboot
of this smaller tar was not finished.** Do not use the morning tar
`zlyme-my355-20260912-f3620e7ca3c4-dirty.tar` (ABI-stale modules).

Live `/usr/sbin/zlyme-update` is still the old dd-live copy until this
squashfs lands. Bootstrap: `/storage/.system/my355/bin/zlyme-update`.
BusyBox wget of the tar over weak Wi-Fi stalled; copy onto the SD.
`scp` needs `-O`.

Serial captures: `DEVLOGS/2026-09-12-gpu-ra-bt-ota.txt`,
`ota-ramfs.txt`, `ota-apply-serial.txt`, `ota-reboot-serial.txt`.

dropbear FAIL on boot was seen before and after the first OTA — not
treated as a new regression.

### Tested on the live Flip after zlyme14

Done on hardware (serial and/or SSH `root@192.168.1.62`):

- Casad Wi-Fi COMPLETED, DHCP, ping host + 1.1.1.1, SSH (`scp` needs `-O`)
- Settings backup `tar -acf` create / list / extract
- CPU `schedutil`, GPU `fde60000.gpu` = `simple_ondemand`
- GBA launch through emu pak; MENU opens RGUI, MENU+Start quits (gpSP)
- First OTA live-`dd` (16:09): squashfs corrupt, SysRq `b` recovered,
  new image actually booted
- Second apply (17:01): size check refused 4096-over tar, old OS intact
- `pending/` deleted so old S18 could not half-apply

Not finished / not retested on the new squashfs:

- tmpfs `pivot_root` + `dd` + reboot of the 17:16 zstd-22 tar
- Settings Bluetooth UI after the Button fix (crash was on the old
  binary; scan `FAIL-BUSY` is separate)
- libmali as default on a card that already had `gpu=panfrost`
- OTG/HDMI/SD2 overlay UI, Artwork Scraper JSON lists, PortMaster on
  Casad, PPSSPP GLES, Samba/Syncthing toggles
- Sleep left at 0 on the debug unit (defaults 120/600 are in the image)

Do not Etcher `zlyme.img` over the games partition. Do not use
`/usr/sbin/zlyme-update` on the current live image.

---

## 2026-09-12 — overnight unattended (zlyme15-shaped), then ABI and seeds

Unattended pass against the live Flip (sleep left at 0 for debug).
Casad associated; SSH worked. Product choices from that night that
**landed in the tree**:

- Backup used BusyBox `tar czf` (no `-z`). Now `tar -acf` / `-axf`.
  Live create/list/extract of `.config` + `.userdata` succeeded.
  Restore button does not reboot.
- DHCP raced association → 169.254. `S30wifi` waits for COMPLETED.
- Artwork Scraper `minui-list` JSON lists + longer DRM wait (still
  needs a UI retest).
- PortMaster: stub `pgrep`/`pkill`, JPEG, `--no-check`, wipe
  `.pugwash-reboot`.
- `apply_undervolt` wiped other overlays. `FDTOVERLAYS` is composed
  (undervolt + optional disable-otg/hdmi/sd2). Defaults on.
- NextUI-Overlays pak (GPL-3.0), my355 → 480p.
- Bluetooth under Network.
- Sleep defaults 120s / 600s (migrate factory 60/30 once; never
  clobber 0 after that).
- CPU/GPU governors in Settings (`schedutil` / `simple_ondemand`).
- `S13resize` reboots after a successful grow.
- Kernel fragment: drop unused WLAN/BT vendors; `DEBUG_SPINLOCK` off
  (ROCKNIX aarch64.conf still has it on). **That changes
  `this_module` size** — OOT joypad/8733bu/mali_kbase must be rebuilt.
  Card-local `joypad.ko` is the live workaround (`3329b5c`).
- Keep Wi-Fi credentials when seeding wpa (`aa08679`); do not open
  the Flip pad twice.
- Spruce Flip performance keys + MinUI-to-RA mapping (`a17accc`).
  MD pak → picodrive. `ra-run` writes cheevos/OSD from
  `minuisettings.txt`.
- OTA **tar packing** existed; **apply** was not wired (and the first
  wiring was the live-dd disaster above).
- Vulkan overnight conclusion ("do not ship") was a question, not a
  lock. See evening entry.

Image pin around this drop was **zlyme15** / NextUI `ae652648`. LOGBOOK
had stopped at **zlyme14** (eudev, LEDs, joypad cal) until now.

---

## 2026-09-12 — zlyme12 on device: Settings abort, LEDs off, RA cannot quit

Serial (`/dev/ttyUSB0` 1500000, `stty` + `os.open`; `serialcon.py` still
unusable). Pin `…-zlyme12`.

**NextUI → emulator.** `nextui.elf` writes `'$emu_pak/launch.sh' '$rom'` to
`/tmp/next` and exits. `nextui-session` `eval`s that; when the emulator
exits, it starts `nextui.elf` again. GBA launched. Quit is RetroArch
hotkey, not NextUI MENU: overlay had Select(8)+Start(9), and
`/storage/.config/retroarch/retroarch.cfg` was **0 bytes** so those
hotkeys never applied. zlyme13: `ra-run --appendconfig /etc/retroarch.cfg`,
MENU (10) = hotkey and exit, Select toggles RGUI, `system_directory =
/storage/Bios`.

**ROM list.** `addEntries` treated every non-hidden file as a ROM. GB showed
`Halo Combat Devolved.srm` (pak exit 1). GBA folder: 13 srm / 11 gba / 8
jpg. PS CHD failed: BIOS is `/storage/Bios/PSXONPSP660.bin`, not under
`Bios/PS`, and RA was looking in `~/.config/retroarch/system`. Filters
from Knulli `es_systems.yml` go in `rom-exts.txt`.

**Settings pak 134.** `free(): double free detected in tcache 2` on every
clean exit. `~AbstractMenuItem` deletes `submenu`; `settings.cpp` then
deleted `appearanceMenu` / `systemMenu` again.

**LEDs.** Sysfs write of 1 works (charging → red). `zlyme-led apply` then
wrote **0** because ash functions share globals: `led_off` → `led_state`
set `val=0`, then `brightness red 1` wrote 0. `local` in `led_state`.
Live workaround: `/tmp/zlyme-led-live.sh` until the next image.

**PortMaster pak 1.** Python 3.14 `sysconfig.get_path` → `ValueError: bad
marshal data` on `_sysconfigdata_*.pyc` (pyc-only). No `_ssl` / `sqlite3`.
zlyme13: `BR2_PACKAGE_PYTHON3_PY_PYC` + SSL/SQLite/expat/zlib; run
pugwash without `exec` so the traceback is logged.

**Artwork Scraper.** `minui-list` segfault 139 (not only wrong buttons).
**Files.** vtree `KeyConfirm=a` is SDL south = physical B. Nintendo
`gamecontrollerdb` (`a:b1,b:b0`) for Flip `retrogame_joypad`. **Moonlight.**
Harvested `richieszemeredi/nextui-moonlight-pak` v0.1.0 `moonlight-pak`
(credits in the pak). **ScrapeGoat.** Same SDL map; no Wi-Fi is a real
network check. **Reboot** works. Shutdown via serial `zlyme-halt poweroff`: library card
unmounted (`EXT4-fs mmcblk1p1: unmounting`), panel already off, UART went
dead with no squashfs errors. That is a real power-off, not a hang.

Host UART scripts live in
`/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP/test-scripts`
(also `NOTES.md` §1).

---

## 2026-09-12 — Flashed zlyme9: keyboard lie, boot still slow, scraper hang

The X=ENTER hint was still drawn while X was backspace; user followed the
icon. X now submits (8+ still enforced), L1 is backspace, hint is B BACK /
X ENTER.

Boot: S28 starts nextui-session, but zlyme9 still **copied** every pak
(including Artwork Scraper) onto exFAT before nextui.elf. eudev S10 still
ran trigger+settle(0). Next image **bind-mounts** squashfs paks (no copy),
S10 only starts udevd, S29 coldplugs after the panel.

Artwork Scraper listed every file in every Roms folder (library card =
tens of thousands) under a forever "Populating emus list" presenter, so
NextUI never came back. Now it stops at the first ROM per folder.

---

## 2026-09-11 — Fast boot, sleep, eudev, dual card

NextUI starts at **S28** (after storage, panel, ALSA). **S90minui** only
stops the UI so busybox still kills it first on shutdown. WiFi/BT waits
(S30/S35, up to ~5s each) no longer block the game list.

Sleep was userspace, not DTS. `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`
**is** the ROCKNIX Flip DTS (`rocknix-singleadc-joypad`, RK817 `pwrkey`,
hall `SW_LID` wakeup, SD `keep-power-in-suspend`). Volume keys now also
have `wakeup-source`. NextUI had `CODE_POWER` unset so `HAS_POWER_BUTTON`
was false and the menu called `PWR_disableSleep()`. `BTN_SLEEP` was
`BTN_NONE`. `PLAT_initLid` forced `has_lid=0`. Session wrote
`screentimeout=0` every start. Pin **zlyme9**: power scancode 102, lid
evdev, `PLAT_shouldWake` on lid open or any key, one-shot restore of
timeout 0 leftovers, `PLAT_supportsDeepSleep` already 1 → `mem`.

We were off udev only so moonlight could link (`libudev-zero`) on
devtmpfs. That cannot hotplug OTG HID, disks, or BlueZ adapters. Both
defconfigs now use **eudev** (`DEVICE_CREATION_DYNAMIC_EUDEV`).
`/etc/default/udevd` sets `SETTLE_TIMEOUT=0` so coldplug does not stall
boot (stock S10 waits up to 30s). SDL2 and BlueZ enable udev when
`HAS_UDEV`. RetroArch `--enable-udev`. Moonlight links against eudev,
not libudev-zero. `rtl8733bu_power` stays in modules-load.d (platform
driver). `btusb` stays blacklisted until S35.

Dual card: `/usr/sbin/zlyme-storage` (S17, eudev `99-zlyme-storage.rules`,
Settings Mount/Eject). Library layout (`roms/` or `Roms/`) → `/mnt/sd2`
plus bind into `/storage/Roms` and `/storage/Bios` (`_orphans/bios`,
`Bios`, …). Same-name folders: SD2 hides the OS card. Other volumes →
`/mnt/media/<label>`. Skips `mmcblk0` / `ZLYME` / `ZLYMEBOOT`. Inserted
while the list is open: udev mounts; NextUI rescans after Settings
returns (session restarts `nextui.elf`).

---

## 2026-09-11 — Reflash worked; WiFi UI and SSH still broken on device

First-boot resize **did** grow `/storage` to **57.6G**. Flags survived (`wifi`/`bluetooth`/`ssh` on). Serial joined **Hotspot Ale** (`wpa_state=COMPLETED`, DHCP **10.32.20.251/24**, ping OK). Do not put the PSK in this file.

SSH port 22 was **connection refused** even with `zlyme-ctl want ssh`. Dropbear `-r` pointed at the exFAT host key (no Unix mode bits); dropbear exits, which looks like refused. Next image copies the key to `/var/run/dropbear` mode 600 and restarts dropbear after udhcpc.

The Settings keyboard was not ES: **B was backspace**, cancel left `KeyboardPrompt` with a stale `CancelButton`, so the next password attempt exited immediately; X confirmed an empty PSK. Next image: **B/Y/Menu = Back**, **L1/X = backspace**, highlight Enter to confirm, `onShow()` resets cancel, `zlyme-wifi` (same verbs as ROCKNIX `wifictl` / Knulli `knulli-wifi`) refuses a PSK shorter than 8.

Samba4's `S91smb` still started nmbd (`disable netbios = yes` → NMB FAIL). Overlay is a no-op; `S70samba` is the real share.

Do **not** start a second log GUI. Serial on host **`/dev/ttyUSB0`** at **1500000** is enough. After this rebuild, `ssh root@10.32.20.251` (empty password) should also work for `/storage/.userdata/my355/logs/`.

Pin is **`ae652648…-zlyme8`**. `version.txt` is that pin (it used to be the UPSTREAM hash, so paks never refreshed). `S90minui` no longer bind-mounts card copies of `settings.elf` over squashfs.

Sleep still cannot wake from keys. `nextui-session` forces `screentimeout=0` / `suspendTimeout=0` **every** time `nextui.elf` starts, including after leaving Settings.

---

## 2026-09-11 — ROCKNIX library card → NextUI names (second slot)

The card at `/run/media/ale/eb9c6e3f-…` is a **ROCKNIX** library (`roms/` short names, `App/` at the card root). It is not Batocera.

Rename of `roms/` used ROCKNIX short names → `Pretty Name (TAG)` from `rom-dirs.txt`. **33207 files kept** (the report file made the count 33208). `App/` untouched. Unmapped systems (ports, pico-8, bios, 3ds, …) went to `roms/_orphans/<name>/`. `bios` is not card-root `Bios` — NextUI BIOS is `/storage/Bios` on the OS card; copy from `_orphans/bios` if a core needs it.

Three root-owned dirs still sit in `roms/` (`backup`, `backups`, `Zeta`) — `mv` needs root. They have no emu pak so NextUI will not list them.

NextUI only scans `/storage/Roms`. `S17sd2` mounts the other SD (not the OS disk) at `/mnt/sd2`; `nextui-session` bind-mounts each named folder over `/storage/Roms/…`. Insert the library card in **slot 1** (right slot is boot). Empty seed dirs on the OS card stay empty if SD2 is absent.

`_orphans/ports` (~13k files) and `_orphans/pico-8` (278) are not NextUI systems yet. PortMaster.pak still launches the GUI from the image.

---

## 2026-09-11 — Storage was 64MB full (WiFi, settings, sleep)

First curated image booted. WiFi scan and on-screen keyboard worked once.
Then scan died, most settings did not persist, and the panel slept. Serial
showed `/storage` at **62MB / 62MB** on a ~58GB card: the image seed was
64MB and never grew. Empty `wifi` flag, empty `wpa_supplicant.conf`, empty
`minuisettings.txt` (`ENOSPC`). NextUI copied paks every boot; PortMaster
copied its GUI onto the card.

Fix (rebuild + reflash, not live): 512MB exFAT seed like Knulli miyoo-flip,
`S13resize` from their `S02resize` (`sgdisk`/`parted`/`mkfs.exfat`), empty
flag files count as default, seed a missing wpa conf, `CFG_sync` fsync,
pak copy only when `version.txt` changes.

---

## 2026-09-11 — Drop libretro-mame2015

mame2010 and mame2015 are frozen snapshots (MAME 0.139 / 0.160), not two
maintained trees. Arcade default stays **mame2003-plus** (actively
maintained 0.78+ set) plus FBNeo. Keep **mame2010** to match Knulli
(0.139 extra set). Drop mame2015: Knulli does not ship it; NextUI only
wires `mame2003_plus`.

---

## 2026-09-11 — Drop b2/daphne/fbalpha2012; add ROCKNIX standalones

Dropped libretro-b2, libretro-daphne, and the extra fbalpha2012 recipe.
BBC Micro is gone (Knulli uses MAME; we do not). Laserdisc is hypseus-singe.
Arcade stays FBNeo + the existing `libretro-fbalpha` pin.

Added ROCKNIX RK3566 standalones the user named: wine (Kron4ek amd64 +
box64, not Buildroot's `BR2_PACKAGE_WINE`), pico-8 launcher only,
moonlight-embedded, gzdoom GLES2, openbor, amiberry, hypseus-singe,
duckstation AppImage, drastic blob, AetherSX2 prebuilt. Qt/KMS: eglfs,
no Wayland. `/flip/output` bind-mount stays — host gcc prefix is still
`/flip/output/host`.

Amiberry needed `libportmidi` (Knulli has it; Buildroot does not). GZDoom
host tools failed until Knulli’s patches sat next to `gzdoom.mk` (and
were refreshed for `patch -F0`). 0001 maps Knulli `/userdata` onto
`/mnt/SDCARD/.userdata/shared`. Leftover b2/daphne/fbalpha2012 dirs
removed.

---

## 2026-09-11 — Rebrand (Zlyme / my355)

The product name is **Zlyme**. The board/platform stays **my355** (Miyoo /
NextUI / myoo). Kernel dtb stays `rk3566-miyoo-flip.dtb`.

| What | Value |
| --- | --- |
| OS | Zlyme |
| Image | `zlyme.img` |
| Hostname / issue | `zlyme` / `Zlyme` |
| Storage / boot labels | `ZLYME` / `ZLYMEBOOT` |
| Board tree | `board/my355` |
| Defconfigs | `zlyme_defconfig`, `zlyme_minimal_defconfig` |
| BR2_EXTERNAL | `BR2_EXTERNAL_ZLYME_PATH` |
| Config dir | `/storage/.config/zlyme` |
| Tools | `zlyme-ctl`, `zlyme-audio`, `/etc/zlyme.conf` |
| Docker | `zlyme-build`, workdir `/zlyme` |
| NextUI | `PLATFORM=my355`, pin `ae652648` |
| Settings | `zlymemenu.cpp` |

Left as hardware/compat names: `flip-jackd`, `rocknix-joypad`,
`rk3566-miyoo-flip`, `FlipVolume`, `pcm.flipsink_*`.

`main` is six orphan commits (old tip `5d5e055` is reflog only). PLAN.md was
restored after a bad overwrite, then renamed in place (stages not collapsed).

---

## 2026-09-11 — Remaining RK3566 emus, refresh, undervolt

**Qt6 / SDL3.** ROCKNIX compiles Dolphin/Azahar/melonDS-sa/Vita3K with Qt6 on
Wayland. We have no compositor. Azahar has an SDL2 frontend; Dolphin plays
through nogui. melonDS-sa and Vita3K still need a Qt UI. Choice: add **SDL3
3.4.10** (KMSDRM+GLES) and **Qt6 eglfs** (no X11/Wayland). Skip Drastic and
AetherSX2 (blobs).

**DTS.** Decompiled the ROCKNIX card dtb (`/run/media/ale/ROCKNIX`) against
ours. `opp-table-0` voltages match. Panel already has the 60/50/40 mode
strings. Source dts differs only in comments. Card currently boots with
`FDTOVERLAYS /overlays/rk3566-undervolt-cpu-l3.dtbo`. Our u-boot already has
`OF_LIBFDT_OVERLAY`. Overlays compile and `fdtoverlay` onto our dtb.

**Settings.** Display: panel refresh 60/50/40 (sysfs `640x480@Hz` after naming
modes in `panel-generic-dsi`). Zlyme: CPU undervolt Off/L1/L2/L3 writes
`FDTOVERLAYS` in `/boot/extlinux/extlinux.conf` (next reboot). `S12bootfs`
mounts `ZLYMEBOOT`.

**Cores / standalones.** Added the ROCKNIX RK3566 cores we were missing
(Knulli recipes where they existed, ROCKNIX pins otherwise) plus Dolphin
(SDL3 + nogui, evdev off — no udev), Azahar (Qt UI; 2125 dropped the
SDL2 frontend, so Concurrent+DBus), Vita3K, melonDS-sa, Mednafen,
ScummVM. Full `zlyme_defconfig` build started after this entry.

The host gcc is still configured with `--prefix=/flip/output/host`. `build.sh`
bind-mounts the same tree at `/flip/output` so those rpaths keep working.
Do not byte-replace `/flip/` → `/zlyme/` in the output tree (it shifts ELF
and `.a` members by one byte and breaks the toolchain).

---

## 2026-09-11 — Zlyme / my355

Board tree is `board/my355`. NextUI `PLATFORM` is still `my355`. Kernel dtb
stays `rk3566-miyoo-flip.dtb`. Commits should stay short and human.

`main` was rewritten as six commits (old tip `5d5e055` is in reflog only):
build driver, my355 board, radios, system services, RetroArch, NextUI.

---

---

## 2026-09-10 — Stage 1 done, booted on hardware

`zlyme_minimal_defconfig` → 85 MB `zlyme.img`, written with Balena Etcher, boots to a root
shell on `ttyS2` in 3.4 s. Log kept at `output/boot-1.log`.

Verified on the artefact before flashing: GPT has `uboot` at LBA 16384 (the sector the NAND
preloader probes), `boot` at 12 MB with attributes `0x0004` — bit 2, legacy-bootable — and
`rootfs` at 76 MB. `RKNS` magic at 32 KB, `d00dfeed` at 8 MB. Decompiled dtb says
`model = "Miyoo Flip"` and carries the `rocknix,generic-dsi` node.

Verified on the device: read-only squashfs root, tmpfs `/var` repopulated by `S00vardirs`
(`cache lib lock log run spool tmp`, `lock` and `run` as symlinks), root login with no
password, 50 MB of 976 in use.

### Two build failures, both fixed

**Patch fuzz.** Buildroot uses `patch -F0`, LibreELEC plain `patch -p1` (fuzz 2). 9 of 44
patches, 13 hunks, only applied thanks to the slack; nothing failed even with fuzz. Wrote
`scripts/refresh-kernel-patches.sh` to rewrite just the context — every `+`/`-` line and
every header preserved, insertion/deletion counts verified identical, idempotent on a second
run. Promoted to `NOTES.md`.

Checked the riskiest by hand: `1001-add-idle-states` had all four hunks at fuzz 2, and
`cpu-idle-states = <&CPU_SLEEP>` lands at the same anchor in all four CPU nodes. The drift
was upstream churn — `<&scmi_clk 0>` → `<&scmi_clk SCMI_CLK_CPU>`, `i-cache-line-size`
appearing.

**Foreign device trees.** `make dtbs` builds every Rockchip board, and patch 0009 references
a `&joypad` label defined only in ROCKNIX's replacement `rk2023.dtsi`. Harvested both files
ROCKNIX overwrites into `board/my355/linux/dts-overrides/`, deliberately *not* `dts/`, since
Buildroot `find`s the latter to decide what to install. Promoted to `NOTES.md`.

### Costs, for planning

| Step | Time | Notes |
| --- | --- | --- |
| `docker build` | 11 min | apt; cached after |
| `make source` | 59 min | almost all of it glibc's git clone; cached after |
| full build | 11 min | 16 cores, cold ccache |

### Still open from Stage 1

- **rkbin TPL blob, rk3566 vs rk3568 v1.23.** Cannot be settled by a card boot — the NAND
  preloader supplies its own DDR init. Only reachable from sector 64 with the preloader out
  of the way. BL31 v1.44 is confirmed good.
- **No getty on `tty1`.** The panel shows the kernel log but has no login prompt, because
  Buildroot spawns exactly one getty and ours is on `ttyS2`. Deliberate for now. Adding one
  is a two-line change; remember it will fight a DRM frontend later.
- **`cfg80211: failed to load regulatory.db`** — needs `wireless-regdb`. Stage 2.
- **Backup GPT is at the image's last LBA, not the card's.** Expected until a first-boot
  resize exists. Partitioning tools will offer to "repair" it; don't let them.

---

## 2026-09-10 — Stage 2 starting

Goal per `PLAN.md`: RTL8733BU, WiFi, Bluetooth, SSH. Deliberately before anything graphical,
because it turns the loop from "rebuild an image" into "scp a file".

Encouraging start: the adapter already enumerates on the Stage 1 kernel as
`usb 5-1: idVendor=0bda, idProduct=b733`, `Product: 802.11n WLAN Adapter`,
`Manufacturer: Realtek`, `SerialNumber: 145D3435F52C`. No driver claims it yet.

### Built, not yet booted

`zlyme.img` is 91 MB, squashfs 5.66 → 11.16 MB. Not flashed; the device is off.

Everything the dArkOS work produced was reusable as-is: the six rtl8733bu patches,
`rtl8733bu_power.c`, and the two `rtl_bt` blobs, all under
`DARKOS/dArkOS/drivers-mainline/`. Three new packages under `package/drivers/`, all
building. The driver pin in `NOTES.md` is still correct, though the repository was
renamed — `Awesome-Embedded-Learning-Studio` now 301s to `Charliechen114514`, and
commit `c46aa25e2` resolves there.

Two things were already right without being touched: our DTS carries the
`rockchip,rtl8733bu-power` node with the enable GPIO, and the kernel already has
`{ USB_DEVICE(0x0bda, 0xb733), .driver_info = BTUSB_REALTEK }` in `btusb.c` from
harvested patch 0005. Only `8733bu` claims that id in `modules.alias`.

### Three deviations from what NOTES/the dArkOS work assumed

**Buildroot's kernel-module infrastructure, not MIMIKI's symlink-into-the-tree.**
`NOTES.md` prefers the latter to avoid depmod and wrong-module-name bugs, but those
were dArkOS's hand-rolled build; Buildroot runs `modules_install` and `depmod`
itself. Verified: both modules land in `updates/`, and `modules.softdep` carries
`softdep rtl8733bu_power post: 8733bu`, so one `modprobe rtl8733bu_power` brings up
the whole chip.

**Real kmod instead of busybox modprobe.** Busybox here is built without
`FEATURE_MODPROBE_BLACKLIST` and has never implemented `softdep` at all, so both
directives in `modprobe.d` — and the driver's own `MODULE_SOFTDEP`, which modprobe
processes rather than the kernel — would have been read and silently ignored. On a
combo chip where load order resets the hardware that is not cosmetic.
`/sbin/modprobe` now resolves to kmod, and the post-build script asserts it.

**No rfkill utility.** The power driver registers both rfkills *unblocked*, so the
chip is live from probe and nothing is needed to bring WiFi up. `rfkill` lives in
util-linux, which is a larger dependency than it is worth right now; the state is
readable from `/sys/class/rfkill/*/`. Needed when there is a WiFi on/off control.

### Credentials and host keys had nowhere to live

The root filesystem is read-only and the repository is public, so neither WiFi
credentials nor an SSH host key can ship in the image. The boot vfat is the only
writable filesystem on the card, so for now it is both:

- `S15bootpart` mounts it at `/boot`, found by filesystem label `FLIPBOOT` via
  busybox `blkid`. Not from fstab: busybox mount here has no
  `FEATURE_MOUNT_LABEL`, so neither `LABEL=` nor `PARTLABEL=` resolves, and there
  is no udev to provide `/dev/disk/by-label`.
- `wpa_supplicant.conf.example` ships on the partition for the user to rename and
  fill in from any card reader.
- `/etc/default/dropbear` points dropbear's host key at `/boot`, so ssh stops
  treating every reboot as a man-in-the-middle attack.

Both are stopgaps and both are noted as such in the files. FAT has no journal and
no permission bits, so the host key is readable by anyone holding the card — the
same trust level as the passwordless root account, and the same thing to fix. Move
both to the user partition when it exists.

Buildroot had already solved the other two read-only-root traps by itself:
`/etc/resolv.conf` is a symlink to `../run/resolv.conf` and its udhcpc script
writes through it deliberately, and `S50dropbear` detects a read-only `/etc`.

### Two silent successes, both fixed

Neither of these failed. Both exited 0 and produced an image.

**`build.sh` ignored the defconfig.** It only applied the defconfig when there was
no `.config`, so an edit adding a whole stage's packages did nothing — a 10-second
build that finalized the target and rebuilt the image. Now reapplies when the
defconfig is newer, which does discard uncommitted menuconfig work, deliberately;
`savedefconfig` is the way to keep that.

**The rtl8733bu patches were never applied.** They were in a `patches/`
subdirectory. `pkg-patches-dirs` looks in `$(PKGDIR)` and
`$(BR2_GLOBAL_PATCH_DIR)/<rawname>`, and nowhere else, so the step printed
`Patching` and applied nothing — which would have shipped a module registering
`wlan0` and `wlan1`, panicking on an ordinary disconnect, and never running its
shutdown hook. Moved up a level, plus a `POST_PATCH` hook asserting
`-DCONFIG_CONCURRENT_MODE` is gone from the Makefile, since the failure mode is all
six patches at once and never one.

Both argued for `board/my355/post-build.sh`, which now asserts the modules, the
softdep line, the two firmware files, `regulatory.db`, and that modprobe is kmod.

### Storage layout: decided in part, one thing open

Reference facts from the ROCKNIX card and Knulli's sources are in `NOTES.md` §4. What
was decided here:

**All persistent configuration lives under one directory.** `/etc/zlyme.conf` defines
`ZLYME_STORAGE` and `ZLYME_CONFIG` once, and `S15bootpart`, `S30wifi` and
`/etc/default/dropbear` all source it. Following ROCKNIX's `/storage/.config`, so a
backup is a directory copy and not a list of paths that goes stale. `ZLYME_STORAGE` is
the only line that changes when the writable partition arrives — it is `/boot` today.

**kmod stays.** Verified two ways that busybox cannot do `softdep`: zero matches for the
string in the whole 1.37.0 tree, and Spectrum OS banned busybox modprobe over exactly
this. `blacklist` is one config option away, `softdep` is not a feature at all.

**Settled: exFAT, one partition, last on the disk.** Now built and in the image:

| Part | Name | Size | Notes |
| --- | --- | --- | --- |
| 1 | `uboot` | 4 MB | LBA 16384, where the NAND preloader looks |
| 2 | `boot` | 64 MB | vfat `FLIPBOOT`, attrs `0x0004` |
| 3 | `rootfs` | 15 MB | squashfs |
| 4 | `storage` | 64 MB | exFAT `ZLYME`, grows on first boot |

Label `ZLYME` and not ROCKNIX's `STORAGE`, because a user of this device having a
ROCKNIX card in the other slot is completely ordinary and two identical labels would be
ambiguous.

Three things this ran into:

- **genimage has no exfat image type** — only vfat, ext2/3/4, cpio, hdimage. So
  `post-image.sh` runs `mkfs.exfat` itself and genimage takes the result as a partition
  image. The tool comes from Buildroot's `host-exfatprogs`, which exists but has no
  Config.in option, so `external.mk` hangs it off `target-post-image` as a prerequisite.
- **An exFAT image's contents cannot be authored at build time.** exfatprogs has no mcopy
  equivalent and mounting needs privileges the build must not have. So the partition ships
  empty and `S15bootpart` seeds `.config` from `/usr/share/zlyme/` on first boot — which
  is what ROCKNIX does too. Consequence: the very first boot has no WiFi credentials, so
  configure over serial or power off and edit the now-formatted card.
- **genimage's parser reads `#` inside a `files = { }` list as a token** and dies with
  `unexpected token`. Comments have to go outside the braces. Cost one build.

**Superseded: the earlier question of partition count.** A separate exFAT partition is
what ArkOS does (`boot` vfat + `root` ext4 + `EASYROMS` exFAT "for cross-platform
compatibility"), and exFAT is needed because FAT32 caps files at 4 GB and Wii and PS2
ISOs exceed that. Fewer partitions is only possible by storing root as a loop-mounted
file the way ROCKNIX and Batocera do. u-boot 2026.01 does have exFAT read/write, checked,
so exFAT is not disqualified from being the boot partition either.

GammaOS was considered and is not a model: it is Android, with Rockchip's Android
partition scheme, and it does not even enable exFAT by default.

Worth stealing when the resize is written: ArkOS needs a **two-reboot** dance (`sfdisk`,
marker file, reboot so the kernel rereads the partition table, then repartition and
format) purely because the filesystems are mounted. Doing it in the initramfs `NOTES.md`
already wants avoids that entirely.

### Bluetooth, completing stage 2

`bluez5_utils` with `bluetoothctl`, `btmon`, and the HID and HOG plugins, which is what
game controllers need. Brings dbus, the one thing in this system that requires it —
`bluetoothd` is a dbus service and pairing cannot be done without it. The audio plugin is
deliberately absent: A2DP needs ALSA and belongs with the rest of audio in stage 3.

Boot order now matters and is deliberate:

| Script | Does |
| --- | --- |
| `S11modules` | kmod loads `rtl8733bu_power` from `/etc/modules-load.d/`; softdep pulls in `8733bu` |
| `S15bootpart` | mounts `/storage` by label, seeds `.config` |
| `S30dbus-daemon` | dbus, before anything that needs it |
| `S30wifi` | waits for `wlan0`, then wpa_supplicant and udhcpc |
| `S35btusb` | persists pairings, loads `btusb` *after* the WiFi driver, waits for `hci0` |
| `S40bluetoothd` | the daemon |
| `S50dropbear` | sshd |

The module load moved out of `S30wifi` into `/etc/modules-load.d/rtl8733bu.conf`, so there
is one place that decides what loads at boot, and it happens early enough that the chip
has finished enumerating over USB by the time `S30wifi` looks for `wlan0`.

`btusb` stays out of `modules-load.d` on purpose: it has to come after the WiFi driver is
done with the chip, and that is a sequencing problem rather than a list of modules.

Pairing keys are symlinked from `/var/lib/bluetooth` — a tmpfs, so otherwise forgotten
every reboot — into the configuration directory, which also means they get backed up with
everything else. They are on a filesystem with no permission bits, so unlike a normal
system they are not 0700. Noted in the script.

### Open for the next boot

- **Not booted yet.** Everything above is build-time verification only. `zlyme.img` is
  now 162 MB.
- **`wireless-regdb` is installed but untested** — the `cfg80211` complaint should be gone;
  confirm on the next boot.
- **First boot will have no WiFi**, by construction: the exFAT partition ships empty, so
  `.config/wpa_supplicant.conf.example` only appears after `S15bootpart` has seeded it.
- **The storage partition is 64 MB until the resize exists.** Fine for testing, useless for
  ROMs. See `NOTES.md` §10 for the two constraints that shape it.
- **Kernel module trimming deferred** to the performance pass, recorded in `NOTES.md` §10.
- **Revisit the passwordless root now that SSH is in the image.** Flagged in the
  defconfig since Stage 1: fine on a serial console, different once the device is
  on a network. Dropbear will accept an empty-password root login.

## 2026-09-10 — Stage 2 booted on hardware, and it works

Second boot of the day, captured to `output/boot-2.log`. WiFi, Bluetooth, suspend and
resume all confirmed on the device. The general findings are in `NOTES.md` §10; what
follows is what happened and the reasoning that is not worth keeping there.

### What worked first time

`S11modules` loaded `rtl8733bu_power`, the softdep pulled in `8733bu`, the chip enumerated
as `0bda:b733`, and `wlan0` appeared. `/storage` mounted exFAT from `/dev/mmcblk0p4` by
label and `S15bootpart` seeded `.config` with `bluetooth/`, `dropbear/` and
`wpa_supplicant.conf.example`. `btusb` loaded, `hci0` came up on our own
`rtl8723fu_{fw,config}.bin`, `bluetoothd` started. Serial login prompt on time. The exFAT
`Volume was not properly unmounted` line is just the earlier hard power-off.

WPA2 associated, DHCP leased `192.168.0.108`, and Bluetooth discovered five devices
including the laptop and a pair of earbuds. Suspend went to real `deep` and the RTC alarm
brought it back.

### Capturing serial: the mistake worth not repeating

A backgrounded `cat /dev/ttyUSB0` inside a command substitution is reaped when its parent
shell exits, so the first boot was captured to an empty file and the boot was lost. The
capture has to be a long-running foreground command that the harness keeps alive. An idle
system sends nothing, so "no output" does not distinguish a dead link from a booted system
sitting at a login prompt — the way to tell is to power-cycle with the capture already open.
`pyserial` is not installed here; `stty -F /dev/ttyUSB0 1500000 raw -echo clocal -crtscts`
plus `cat` needs no dependencies and is what the test-scripts do anyway.

### Chasing the wrong cause, twice

**Power save.** With ROCKNIX's options in place, ICMP failed 12 times out of 12 while DNS
resolved reliably and DHCP had just succeeded. That pattern — traffic arriving immediately
after a transmission works, traffic arriving later does not — is what a broken power-save
implementation looks like, so I reloaded the driver with `rtw_power_mgnt=0 rtw_lps_level=0`
and ping went to 4 of 4. That looked conclusive and was not: the loss came straight back at
70%, and the improvement was the re-association, not the parameter. ROCKNIX ships the
identical options line and its comment shows the matrix was chosen deliberately. Left alone.
The real cause is distance, which the user said at the outset.

**Dropbear.** `No persistent location to store SSH host keys` is printed by `S50dropbear`
whenever `/etc/dropbear` is an unremovable symlink, without consulting `DROPBEAR_ARGS`.
`ps` shows dropbear running with our `-r` and listening on `0.0.0.0:22`, so the warning is
cosmetic. The empty key directory is `-R`, which defers generation to the first connection.
Both facts had to be checked on the device rather than reasoned about.

Also of note: `netstat -lntp` prints nothing under busybox and `ip -br` and `ip -s` are not
supported — three tool-difference dead ends that each looked like a system fault.

### Five fixes, committed, not yet built

1. **Dropped the `/var` tmpfs and `S00vardirs`.** This was the real bug behind
   `Could not create /var/lib/dbus/machine-id`. Reasoning in `NOTES.md` §7. Bluetooth link
   keys now go through `/run/bluetooth`, baked in by `post-build.sh`, so `S35btusb` still
   gets to decide at runtime whether that points at the card — an unmounted card costs
   pairings instead of leaving `bluetoothd` on a dangling symlink.
2. **RNG seed onto the writable partition**, with `S15bootpart` reloading `seedrng` once it
   is mounted. Under the tmpfs the seed was never credited and the log said so every boot.
3. **`CONFIG_CFG80211=m`** so `regulatory.db` is requested after root is mounted. Built in
   it asked at 3.005 s and root arrived at 3.029 s, which is why `iw reg get` still said
   `country 00`. `mac80211` follows; nothing built in needs either.
4. **`options btusb reset=1`**, which ROCKNIX ships and we did not.
5. **A comment recording that the dropbear warning is misleading**, so the next person does
   not spend the same half hour.

`post-build.sh` now asserts the `/var` symlinks are still symlinks and that `/etc/fstab`
does not mount over them, because every failure in this area is a daemon that carries on.

### Open

- **Nothing above is rebuilt.** Deliberate — Stage 3 is next and one build should carry
  both.
- **SSH never actually connected**, so persistence of the host key is inferred from the
  command line and the listening socket, not observed. Confirm when the link allows it.
- **Resume loses the IP address.** The fix is a suspend entry point and it belongs to
  Stage 5; recorded under Deferred in `NOTES.md` §10.
- Carried forward: storage still 64 MB, module trimming, passwordless root.

## 2026-09-10 — Stage 3 started, and a correction

### The device has HDMI. NOTES said it did not.

Owner-confirmed. The claim traces to the dArkOS session, where it appears three times, and
to nothing in the wiki or the ROCKNIX tree — so no source was wrong, an earlier note was.
It survived because it was attached to a finding that *is* correct and useful (the codec is
card 1, address cards by name), and because the contradicting evidence was in the same
paragraph and went unread: dArkOS shipped a `.asoundrchdmi` using `CARD=rockchiphdmi`.

Worth generalising: the risky sentences in these notes are the unsourced asides sitting
next to well-evidenced findings, because they inherit the finding's credibility. Anything
about what the hardware *has* should cite how it was established.

### Stage 3 so far

The kernel needed nothing for either half — ROCKNIX's config already had
`CONFIG_DRM_PANFROST=m` and `SND_SOC_RK817=y`, so `panfrost.ko` had been shipping since
stage 1 with nothing to load it, and both ALSA cards registered on the stage 2 boot.

Committed: Mesa with Panfrost plus kmscube, `/etc/modules-load.d/panfrost.conf`, ALSA
userspace with mixer state on the writable partition, and a new assertion in `build.sh`.

### Buildroot forces target LLVM and clang for panfrost

Its panfrost option has a hard `depends on BR2_PACKAGE_MESA3D_LLVM` and selects a hidden
`NEEDS_PRECOMP_COMPILER` which selects target OpenCL, hence clang and libclc. Verified by
resolving a scratch config, not by reading Kconfig. Upstream master still does this and has
since added libclc and has-libopencl to the same select, so there is no version that avoids
building them.

ROCKNIX shows the target side is unnecessary: Mesa 26.2.0, panfrost, `llvm:host` only,
target depends on `toolchain expat libdrm`, with `-Dgallium-rusticl=false` and
`-Ddraw-use-llvm=false`. Since size is not a constraint here (the criterion is overhead and
performance, not bytes on a large card), the chosen route is to let Buildroot build them and
keep `libLLVM` out of the *driver* with `-Ddraw-use-llvm=false` from `external.mk` — no
Buildroot patch to rebase. **Verify after the build with `ldd` on the panfrost DRI driver:
`libLLVM` must not appear.** If CI time later hurts, tightening the Kconfig is mechanical.

Appending to `MESA3D_CONF_OPTS` from `external.mk` works because meson recipes expand
`$($(PKG)_CONF_OPTS)` when the recipe runs and `BR2_EXTERNAL_MKS` is included after
`package/*/*.mk` — the same lever as `target-post-image: host-exfatprogs`.

### A defconfig option can be silently dropped

`BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_PANFROST=y` alone does nothing: its `depends on` is
unmet, kconfig discards the line, and the build succeeds with no GPU driver and no message.
Now asserted in `build.sh` before every full build, scoped to full builds so
`build.sh menuconfig` still runs. Tested both ways — it catches an invented option and does
not false-positive on the real defconfig.

### Open

- **Nothing built yet.** Stage 2 fixes and all of stage 3 are unverified on hardware.
- `asound.conf` as committed hardwires `hw:rk817ext,0` and cannot reach HDMI or Bluetooth.
  It needs the `@func getenv` indirection described in `NOTES.md` section 5.
- Jack watcher not written. `bluez-alsa` not added.

### The first stage 3 build was a false success

`build.sh` defaulted to `ZLYME_DEFCONFIG=zlyme_defconfig`, and the only file in `configs/` is
`zlyme_minimal_defconfig`. Nothing complained. The reconfigure branch tests `-f` on the
defconfig and skipped; `assert_defconfig_survived` — added *this session* precisely to catch
silent config loss — returned early on the same `-f`; the build then ran against the
`.config` left by the previous run, rebuilt the kernel because the fragment had genuinely
changed, re-ran the overlay and genimage, and printed `==> images in …`.

The image it produced had all of stage 3's *scripts* (the overlay is copied regardless) and
none of stage 3's *packages*. `asound.conf`, `S20alsa`, `S25jackd`, `S45bluealsa` and
`zlyme-audio` shipped with no alsa-utils, no bluealsad and no `flip-jackd` binary behind
them. Only the defensive "is it there?" check at the top of each script would have kept the
boot quiet, which would have made it look like a working stage 3.

Two lessons, the second more useful than the first:

1. A guard written as `[ -f "$X" ] && ...` treats "missing" as "nothing to do". For an input
   the build is *defined by*, missing must be fatal. Fixed: a missing defconfig now dies and
   lists what exists, and the default points at a file that is actually there.
2. **An assertion that shares a precondition with the thing it guards does not guard it.**
   `assert_defconfig_survived` and the reconfigure step both keyed off `-f "${CONFIG_SRC}"`,
   so the one case where reconfiguring was skipped was exactly the case the assertion
   declined to check. Worth applying to the other asserts in `build.sh`.

Caught only because a full Mesa-and-LLVM build finished in 20 seconds. Without that
implausibility there was no other signal.

### On harvesting, prompted by the right question

Asked whether the jack watcher and sink switcher could be harvested instead of written, and
whether udev was the usual mechanism. Investigating changed two conclusions and is written
up in NOTES section 5. Briefly: udev cannot see a jack event (it is `EV_SW` on a device that
already exists, and we have no udev at all — devtmpfs only); Batocera does not detect the
jack on this class of device, its `auto` and `speakers` cases being byte-identical; and a
sound server *could* see the jack (the card has `Headphones Jack`, confirmed later on
hardware) but would still not write `Playback Mux`, which is the actual route.

The genuinely useful correction was about *why* the neighbours ship PipeWire. It is not for
emulator audio: Buildroot's `sdl2` hardcodes `--disable-pulseaudio`, so those emulators are
ALSA clients by construction, and Batocera ships a config that switches WirePlumber's ALSA
device reservation *off* so its server stops fighting them for the card. The server is there
for sinks, volume, A2DP and Kodi. That makes ALSA-only a reasonable position here rather
than a stubborn one — with PortMaster the one unverified risk, to be settled in stage 4/6.

### Three build failures, all worth keeping

**libclc cannot build against Buildroot's clang wrapper.** `host-clang` installs
`$(HOST_DIR)/bin/clang` as a symlink to `toolchain-wrapper-clang`, whose purpose is to make
clang compile *for the target*, so it appends the target's flags to every invocation —
here `-mcpu=cortex-a55+crc+crypto+fp+simd+rcpc`. libclc compiles OpenCL C with
`clang -target spir64--`, and clang rejects `-mcpu` for that target. The generated compile
command is clean; the flags are added underneath, which is why the only way to see it was to
notice `bin/clang` is a symlink.

Both variants are affected. Buildroot set the *target* variant's `CMAKE_C_FLAGS` to
`HOST_CFLAGS` to avoid exactly this, which cannot work — the flags come from the binary, not
from CMake. The target build fails differently only because it also compiles for AMD GPUs,
where the same `-mcpu` is misread as a GPU target ID.

Fixed from `external.mk` with no Buildroot patch, by pre-seeding libclc's `find_program`
cache variable to `clang.br_real`, the real binary beside the wrapper. Only `clang` is
wrapped — `opt`, `llvm-as`, `llvm-link` and `llvm-spirv` are installed unwrapped, which is
why they never complained. The wrapper honours only `BR2_DEBUG_WRAPPER` and
`BR2_USE_CCACHE`, so there is no way to ask it to stand down.

Also restricted `LIBCLC_TARGETS_TO_BUILD` to `spirv64-mesa3d-` for the target build.
Buildroot sets it for the host variant only, so the target took libclc's default of "all" and
was compiling the amdgcn and tahiti kernel libraries for hardware this device does not have.
Reported-quality upstream bug on both counts.

**Deleting a file from the overlay does not delete it from the target.** Buildroot rsyncs the
overlay over `output/target` without `--delete` and never prunes, so a retired file ships in
every incremental image until a clean build, silently. `S00vardirs` proved it: retired when
`/var` stopped being a tmpfs, still in the image two builds later, still scheduled first —
and not harmless there, because its `ln -sf /run /var/run` would follow the symlink Buildroot
now puts at `/var/run` and create a self-referential `/run/run` plus `/run/lock/lock`.
`post-build.sh` now prunes a list of retired paths. Add to it when retiring a file.

**`note()` fails the build.** It sets `fail=1` and `post-build.sh` ends with
`exit "${fail}"`, so using it for the pruning message failed the build on the very run that
fixed the problem. There is now an `info()` beside it and a comment on the distinction:
note() means "this is wrong", info() means "this happened".

### Stage 3 built and verified in the image

- **`libgallium-26.0.1.so` does not link `libLLVM`** — NEEDED is libdrm, libexpat, libz,
  libSPIRV-Tools, libstdc++, libm, libgcc_s, libc, ld. This is the `-Ddraw-use-llvm=false`
  claim in `external.mk`, now checked rather than asserted. `libLLVM.so.21.1` is on the
  target at 65 MB because the Kconfig chain forces it, but nothing in the GL path maps it.
- Mesa 26 ships **one megadriver**, `libgallium-<version>.so`, with no `/usr/lib/dri` and no
  `panfrost_dri.so`. Do not go looking for the old filenames — confirm panfrost is present
  by its symbols inside libgallium.
- Boot order came out right: `S20alsa` then `S25jackd` (restore state, then let the live jack
  reading win), `S40bluetoothd` then `S45bluealsa`.
- **The daemon is `bluealsa`, not `bluealsad`**, in bluez-alsa 4.3.1 as Buildroot packages it.
  The comment claiming upstream's 4.0 rename applied here was wrong; the script tried both
  names, which is the only reason it would have started.

### Stage 3 confirmed on hardware, 2026-09-10

Booted the image that carried Stage 2's leftover fixes and all of Stage 3. Login on
`ttyS2`. Panfrost bound the G52 (`id 0x7402`, DRM 1.6.0 on minor 1). `kmscube` reached
EGL 1.5 / OpenGL ES 2 and dumped the Mesa extension list, then was killed after a few
seconds — `timeout(1)` is not on the image, so it was `kmscube & sleep 3; kill`.

Jack: mux `HP` with the plug in, `SPK` after unplug, `flip-jackd` still running. The
`@func getenv` path in `asound.conf` parsed (`zlyme-audio status` / `list` both worked).
`FlipVolume` existed. `Headphones Jack` *is* a CARD kcontrol — section 5's "none exists"
claim was wrong and is corrected. HDMI and A2DP playback were not exercised.

WiFi stayed down because this card only had the example `wpa_supplicant.conf`. Not chased.

Stage 3 is closed. libmali / `mali_kbase` / `gpudriver` stay deferred. Next is Stage 4.

## 2026-09-10 — Stage 4 started, Stage 5 researched

### Stage 4 first harvest is building as zlyme_defconfig

Not dumped into flip_minimal: that stays the bring-up image. zlyme_defconfig is a copy
plus SDL2 (KMSDRM+GLES, no X11/Wayland), RetroArch 1.22.2 from Knulli's recipe cut down
to KMS+EGL+GLES+SDL2+ALSA+RGUI, four cores (gambatte, fceumm, snes9x, genesis-plus-gx),
and rocknix-joypad.

rocknix-joypad at NOTES' pin `3bc3ef644` downloaded on the first try. The DTS has
been describing that node since stage 1.

Their Makefile's first branch is `ifeq ($(DEVICE),$(filter $(DEVICE), S922X RK3588))`.
An empty `DEVICE` makes both sides empty, so Buildroot built `rocknix-joypad.ko`
and the Flip node (`compatible = "rocknix-singleadc-joypad"`) never bound. Forced
`obj-m=rocknix-singleadc-joypad.o`. Live `insmod` after a serial transfer: probe
success, `input: retrogame_joypad` (vendor `0x484B` product `0x1101`), 17 GPIO
keys, rumble, then 10 s later "Miyoo serial logic started successfully".

Input cannot use udev — we are still devtmpfs-only — so RetroArch is configured
`--disable-udev` and the seeded cfg uses `input_driver = sdl2`.

### Stage 4 confirmed on hardware

`retroarch --version` is 1.22.2 / GCC 14.3. Features include KMS, EGL, GLES, SDL2,
ALSA. A 7 s `--menu` run: DRM connector 1 at 640×480, `GL context: kms`,
`Vendor: Mesa, Renderer: Mali-G52 r1 MC1 (Panfrost)`, `OpenGL ES 3.1 Mesa 26.0.1`,
ALSA `default` FLOAT_LE. Cores present: gambatte, fceumm, snes9x, genesis_plus_gx.
snes9x needed a `z_crc_t` patch for GCC 14 (do not cast to `unsigned long *` on
aarch64).

### Stage 5: do not invent a platform

shauninman/MinUI already lists Miyoo Flip and ships `workspace/my355`: 640×480,
HDMI 1280×720, SDL2, joystick 0. Examined at `dbf89435`. The work is adapting it:

- lid: stock `hall-mh248/hallvalue`; ours is `gpio-keys-hall` + `SW_LID`
- storage: `/mnt/SDCARD` vs `/storage`
- volume: their raw mixer vs FlipVolume / zlyme-audio
- needs SDL2_image, SDL2_ttf, and their libmsettings
- their makefile assumes CROSS_COMPILE and `/root/workspace`

MinUI is not in this build. Next rebuild after RetroArch is proven.

## 2026-09-10 — Stage 5 packaged from my355

Did not write a platform from RGB30. `BR2_PACKAGE_MINUI` fetches `shauninman/MinUI`
`dbf89435` and builds `workspace/my355`: minui.elf, minarch.elf, libmsettings.so.

Adaptations, all userspace:

- `SDCARD_PATH` `/storage`
- lid: `gpio-keys-hall` / `SW_LID` (stock is `hall-mh248/hallvalue`)
- volume: `FlipVolume` via amixer; flip-jackd still owns `Playback Mux`
- battery/charger sysfs names confirmed live (`battery`, `charger`)
- joypad: `retrogame_joypad` SDL button numbers (Nintendo A=EAST=1)
- `api.c` blend: `__ARM_ARCH >= 5` picked ARMv5 asm on aarch64; C path instead

S90minui starts `/usr/sbin/minui-session`. Touch `/storage/.minui-disable` to skip.
Cores stay `/usr/lib/libretro`. Res seeded from the MinUI 20251127-1 release.

## 2026-09-10 — Stages 4–7 packaged (unattended)

Proceeded without waiting. Choices, all written down so they can be revisited:

- **Cores:** Knulli `.mk` pins, filter = ROCKNIX RK3566 `LIBRETRO_CORES`. 81
  recipes. Dropped Qt6 / 1 GiB-hopeless: Dolphin, PCSX2, Play, full MAME,
  libretro-PPSSPP, EasyRPG, ScummVM-lr. `package/emulators/libretro recipes`
  is how they were copied.
- **Settings:** no MinUI settings screen. `zlyme-ctl` +
  `/storage/.config/zlyme/{wifi,bluetooth,ssh,samba,syncthing,gpu}` and Tools
  paks under `/storage/Tools/my355`. Defaults: radios and SSH on (Stage 2
  already starts them); Samba/Syncthing off.
- **Refresh:** DSI is one 640×480@60 mode in the ROCKNIX DTS. Display.pak
  cycles HDMI sysfs modes only.
- **mali_kbase:** OOT module, ROCKNIX pin `39da994`, `platform=devicetree`.
  libmali JeffyCN `4233031` g29p1 under `/usr/lib/mali`. `gpudriver` switches
  at boot. Default remains Panfrost so a 7.0.2 compile miss does not brick GLES.
- **Standalones:** PPSSPP v1.19.3 and Flycast v2.5 from Knulli, GLES, no Qt.
  Drastic / Dolphin-sa / Vita3K / Azahar left out (blob or Qt6).
- **Stage 7:** Buildroot samba4; Syncthing 2.0.13; PortMaster-GUI
  2026.05.04-1202; box64 `2f130fab`. PortMaster deps (hotkeys, gst) were not
  copied from ROCKNIX — Python3 + box64 + the zip is the first cut.

Image build of `zlyme_defconfig` is the next proof. MinUI empty-library
behaviour was confirmed on the live serial boot: A/dpad do nothing with no
ROMs; the pad itself is fine (SDL sees 17 buttons).

## 2026-09-10 — zlyme_defconfig build in progress

`./build.sh --config zlyme_defconfig` after a defconfig touch so the new
`select`s survive `assert_defconfig_survived`. Kconfig wrote `.config`
despite two recursive-dependency warnings; both are now fixed in tree
(will apply on the next reconfigure, not this run):

- `portmaster` both depended on and selected `PYTHON3`. Dropped the
  `depends on`; `select` is enough.
- `retroarch` both depended on and selected `SDL2`. That closed a cycle
  through swanstation → ffmpeg → ffplay → SDL2. Dropped the `depends on`;
  GLES+EGL stay as real depends.

`gpudriver` is a local package now (`SITE_METHOD=local`), same pattern as
`flip-jackd`. Empty `SITE`/`SOURCE` was going to explode at extract.

Legal-info selects added earlier this run: libpcap, libzip, libpng, zlib,
fmt, boost, ffmpeg, janet, sdl2, libcurl, libdrm. `libcapsimage` stripped
from hatari (not in Buildroot). `host-nasm` stripped from
mupen64plus-next (x86 assembler).

Build is still in the samba/python/boost neighbourhood. Do not start a
second `build.sh` on this `output/`.

## 2026-09-10 — Frontend source is NextUI, not archived MinUI

User pointed out MinUI is archived and NextUI already has Settings
(wifi scan/connect, BT pair) plus community paks. PLAN's old veto
(PolyForm + TrimUI-only) is stale: Zlyme is non-commercial, and
`apommel/NextUI` `my355-latest` (`6db3c783`) is a real Flip port
(HDMI 720p, joypad input, BT headphones).

Choice: harvest NextUI's *binaries* onto Zlyme userspace. Do not
adopt their CFW skeleton (stock `runmiyoo.sh`, `/mnt/SDCARD`,
`miyoo_inputd`, RTL8189, `hciattach ttyS1`).

`BR2_PACKAGE_MINUI` now fetches that pin and builds `nextui.elf` +
`settings.elf` + Zlyme `libmsettings` (FlipVolume). `minarch` from
NextUI is deferred (rcheevos/libchdr/nested clones); emu paks exec
RetroArch. `wifi_init.sh`/`bt_init.sh` call S30wifi / S35btusb.
S30wifi seeds an empty `wpa_supplicant.conf` so Settings can scan
before anyone edits the card.

The running `zlyme_defconfig` build still has the old MinUI recipe in
`.config` until make reaches that package or we reconfigure. The new
`.mk` is what it will compile if it has not started minui yet.

## 2026-09-10 — samba4 died: host-python3 has no `_ssl`

Configure: `Waf: The wscript ... is unreadable` → `import ssl` →
`ModuleNotFoundError: No module named '_ssl'`.

`BR2_PACKAGE_HOST_PYTHON3_SSL` is now y (samba selects it) but
host-python3 was built earlier without SSL and was not rebuilt.
`host-python3-dirclean` then a resume. Kconfig cycles are already
fixed, so this reconfigure should be clean.

## 2026-09-10 — samba4 built; libretro-81 died on evmapy keys

Samba configured and installed after host-python3 grew `_ssl`.
Harvested 81/cap32/wasm4 still copied Batocera `*.keys` from
`$(BR2_EXTERNAL_BATOCERA_PATH)/...` which does not exist. Stripped
those install lines (we have no evmapy). Resume from libretro-81.

## 2026-09-10 — beetle-pcfx died on host x86 SSE

`platform="unix arm64"` does not match this Makefile's exact `unix`
branch (or if it did, that branch sets `ARCH_X86` from *host* `uname -p`).
OwlResampler then compiles SSE inline asm for aarch64.

Knulli maps RK3568 → `SM1` (`-mcpu=cortex-a55`). Flip is RK3566, same
CPU. Set `LIBRETRO_BEETLE_PCFX_PLATFORM = SM1`. Resume.

## 2026-09-10 — beetle-saturn linked `-lGL`

Compile succeeded; link wants desktop GL. Zlyme is GLES only.
`platform=unix arm64` does not contain `gles`, so the Makefile picks
`-lGL`. Pass `unix arm64 gles` → `-lGLESv2`. Knulli can get away with
`-lGL` because Batocera ships Mesa GL.

## 2026-09-10 — ecwolf git submodules 401 on Bitbucket

`GIT_SUBMODULES=YES` clones SDL/mixer/net from `bitbucket.org/ecwolf/*`.
Those URLs prompt for a username in the container and fail; Buildroot
mirror 404s. ROCKNIX already moved to `porschemad911/ecwolf`
`5ddc1d00` (`sdl-submodule-url`) which points the same submodules at
GitHub. Same pin. Wipe `dl/libretro-ecwolf` (corrupt cache) and resume.

## 2026-09-10 — fake08 GCC13 patch already upstream

Knulli's `001-fix-gcc13.patch` adds `#include <cstdint>`. This pin
already has it (just after `string.h`), so hunk 1 fails. Dropped the
patch.

## 2026-09-10 — fbalpha2012 vs GCC 14 zlib pointers

`unzOpenCurrentFile3` assigns `get_crc_table()` (`z_crc_t *`) to
`unsigned long *`. GCC 14 errors. ROCKNIX adds
`-Wno-error=incompatible-pointer-types`. Same flag. FBNeo stays the
default arcade core.

## 2026-09-10 — hatari patches assume Batocera + libcapsimage

`001-pathconfig` misses the VITA/PS3 ifdef (upstream already
`.hatari`). `003`/`004` and `IPFSUPPORT=1` need libcapsimage, which
is not in Buildroot. Dropped every harvested hatari patch (CRLF vs
the makefile patches too). Stock `Makefile.libretro` `platform=unix`
is what we build. ST STX/MSA still work.

## 2026-09-10 — drop harvested board makefile patches

mame2003-plus `000-add-s812` missed its insert point. The same class of
Knulli RPi/S812/RK3588/SM8250/Odin makefile hunks will keep failing
on newer pins, and we never set those platforms. Deleted them all.

## 2026-09-10 — mame2003-plus GCC 14 pointers

Same class as fbalpha: `signed char *` into `INT16 *`. Same
`-Wno-error=incompatible-pointer-types`.

## 2026-09-10 — melonDS DS embed race

`embed_binaries` writes `melondsds_vertex_shader.c` while `-j17` already
compiles it. `MAKE = $(MAKE) -j1` for this package.

Real cause: CMake 4 sets `CMAKE_PARENT_LIST_FILE` in `-P` mode, so
embed-binaries' script-mode guard never fires and it writes nothing.
Sed the guard to `if(CMAKE_SCRIPT_MODE_FILE)` in a pre-build hook.

## 2026-09-10 — old melonDS unix = host x86_64

`platform=unix` sets `ARCH=$(uname -m)` → desktop GL and x64 JIT.
Knulli RK3568 uses `odroidc4`. Same here.

## 2026-09-10 — mupen64plus-next gcc-fix already upstream

`001-gcc-fix.patch` adds `<cstdint>`. This pin already has
`<stdint.h>`. Dropped.

## 2026-09-10 — opera no-cd patch drifted

`001-makefile-no-cd` no longer applies. Intent was no host-Linux
physical CD. Pass `HAVE_CDROM=0` on the make line instead.

## 2026-09-10 — parallel-n64 host x86 SSE

`platform=unix arm64` leaves `ARCH=$(uname -m)` → x86_64 dynarec →
`-msse -msse2`. Fallback is now Knulli's `h5` + `WITH_DYNAREC=aarch64`.

## 2026-09-10 — pc88 GCC 14 wchar pointers

`disks.c` `snprintf`s into a `wchar_t *` message buffer. GCC 14
errors. Same `-Wno-error=incompatible-pointer-types` via environment
CFLAGS so the Makefile keeps its `-I` paths.

## 2026-09-10 — pc98 GCC 14 IO callback pointers

NP2kai `iocore_attachout` wants `UINT` callbacks; boards pass
`UINT8`. Same CFLAGS demote.

## 2026-09-10 — picodrive leftover patch list

An interrupted apply left `.applied_patches_list` without
`.stamp_patched`. Retry then hit Buildroot's duplicate-filename
check. The harvested `000-makefile.patch` is rpi/riscv only;
upstream already has `platform=aarch64`. Dropped the patch and
wiped the extract.

## 2026-09-10 — picodrive GCC 14 vram pointers

`libretro.c` assigns `PicoMem.vram` (`short *`) to `uint8_t *`.
Same CFLAGS demote.

## 2026-09-10 — prboom c99 hides POSIX

Makefile uses `-std=c99`, so glibc hides `ftruncate`/`fileno`.
Pass `-D_DEFAULT_SOURCE` via environment CFLAGS.

## 2026-09-10 — puae isoc99 hunk drifted

`002-isoc99math.patch` still wants `#undef __USE_ISOC99` before
`math.h`. This pin added `machdep/maccess.h` in between. Updated
the gfxutil hunk. Wipe extract (partial apply).

## 2026-09-10 — puae isoc99 patch hides C99

The undef hides `sinf`/`snprintf` on glibc 2.41 + `-std=gnu99`.
Knulli needed it on an older toolchain. Dropped from puae and
puae2021. IPF path patch stays.

## 2026-09-10 — puae GCC 14 softfloat pointers

`floatx80_mod` wants `uint64_t *`; callers pass `uae_u64 *`
(`unsigned long long` on this ABI). Same CFLAGS demote on puae
and puae2021.

## 2026-09-10 — px68k c99 hides POSIX

Makefile uses `-std=c99`, so glibc hides `strcasecmp`/`strncasecmp`.
Same `-D_DEFAULT_SOURCE` as prboom.

## 2026-09-10 — stella2014 unix arm64 = Windows

Makefile matches `platform=unix` exactly. `unix arm64` falls
through to the winmm `.dll` link. Set platform `unix`.

## 2026-09-10 — wasm4 minifb wants X11

Default cmake builds the desktop window backend. Zlyme has no X11.
`-DLIBRETRO=ON` skips minifb/cubeb and only builds the core.

## 2026-09-10 — yabasanshiro unix = desktop GL

`platform=unix` matches first and sets `HAVE_LIBGL` / `_OGL3_`.
Knulli RK3568 uses `odroid-c4` (A55, GLES, aarch64 DRC). Same here.

## 2026-09-10 — yabasanshiro missing SH2DynShowSttaics proto

`yabause.c` calls a C++ dynarec stats function with no C
prototype. GCC 14 errors. Demote implicit-function-declaration.

## 2026-09-10 — PPSSPP SDL2_ttf cmake target missing

Staging `sdl2_ttf-config.cmake` sets `FOUND=TRUE` but looks for
`/usr/lib/libSDL2_ttf.so` and never creates `SDL2_ttf::SDL2_ttf`.
Disable that find_package so PPSSPP uses pkg-config.

## 2026-09-10 — minui.hash still named the old MinUI tarball

The .hash file listed `minui-dbf89435…`. NextUI pin `6db3c783`
then failed the hash check. Updated the sha256.

## 2026-09-11 — NextUI GLES2 headers vs GLES3 video

`generic_video.c` uses program binaries and VAOs. We had swapped
`SDL_opengl.h` for GLES2 only. Include `GLES3/gl3.h` too.
Link `-lGLESv2 -lEGL` (SDL2 does not pull them in).

## 2026-09-11 — build.sh writes output/build.log

Full image builds (and non-menuconfig make targets) tee into
`output/build.log`, overwritten at the start of the run.
`less +F output/build.log` is the watch path.

## 2026-09-11 — syncthing doubled Go import path

`golang-package` prepends `GOMOD` to `BUILD_TARGETS`. We had the
full module path already, so `go build` looked for
`…/syncthing/github.com/syncthing/syncthing/cmd/syncthing`.
Target is now `cmd/syncthing`.

## 2026-09-11 — zlyme_defconfig image built

`output/images/zlyme.img` assembled (idbloader, u-boot, boot
vfat, squashfs root, exFAT storage). NextUI, cores, PPSSPP,
PortMaster, Syncthing, box64 are in this tree.

## 2026-09-11 — NextUI flashing was a NULL-font segfault

Serial: kernel and init are fine (`Starting NextUI: OK`).
`nextui.elf` reached GLES (`opengles2`), opened
`retrogame_joypad`, then `Segmentation fault`. `minui-session`
restarts it immediately — that is the flashing panel.
`nextui.txt` grew to ~5000 lines in two minutes.

Cause: NextUI's default UI font is `font1.ttf` (OG = `font2.ttf`)
under `/storage/.system/res`. We only seeded MinUI's
`BPreplayBold-unhinted.otf`. `TTF_OpenFont` failed, first list
draw called `TTF_RenderUTF8_Blended(NULL)` and died.

Live fix: copied BPreplay to `font1.ttf` / `font2.ttf` on the
card and restarted `S90minui`. `nextui.elf` stayed up.

Package fix: `minui.mk` installs those aliases into the seed;
`minui-session` copies them if a card already has BPreplay but
not `font1.ttf`.

Still noisy, not fatal: no `zone.tab` (timezone 320 / Berlin),
no `gametimectl.elf`. Add tzdata and a stub later.

## 2026-09-11 — Tools paks are toggles, not submenus

The flashing "-" is NextUI's launch hint: it writes
`/tmp/next` and exits, `minui-session` runs the pak, then
NextUI comes back. Serial `next.txt` showed the actions
actually ran (Wi-Fi off, SSH off, Syncthing on, Autocal
message, PortMaster missing files).

Only **Settings.pak** is a real UI (`settings.elf`). The rest
are one-shot Zlyme actions that were supposed to toast via
`show.elf "msg" 2`. We never shipped `show.elf`, so the panel
never showed the result.

Added `package/system/nextui/zlyme/show.c` (MinUI toast API),
built into minui, and live-installed to
`/storage/.system/my355/bin/show.elf`. On-card launch.sh now
points at it.

Sleep/wake works: hybrid sleep → suspend to RAM → resume,
audio re-inited on `rk817_ext`.

## 2026-09-11 — NextUI "closes" after Settings: missing zone.tab

Not missing PNGs. `assets@2x.png`, fonts, and scanline grids
are on the card. The bounce was `settings.elf` aborting:

`menu.hpp:253 Assertion 'valueIdx >= 0' failed`

CFG default timezone is index 320 (Europe/Berlin). There is
no `/usr/share/zoneinfo/zone.tab`, so the tz list is empty
and Settings dies. `minui-session` then restarts NextUI.
`/tmp/last.txt` still pointed at `Settings.pak`, so the next
start restored into that folder and once segfaulted.

Live: overlayfs on `/usr/share`, installed `zone.tab`, reset
last.txt to `/storage`. Settings.pak now writes last.txt back
to `/storage` before exec.

Package: seed `zone.tab`, session overlay fallback, timezone
NULL-safe in apply-userspace, skip empty tz list.

## 2026-09-11 — NextUI font change broke the UI

`font=0` (OG) is `font2.ttf`. We had aliased both faces to
MinUI's 169 KB BPreplay. Official NextUI `font1.ttf` (Next)
is 3.6 MB; `font2.ttf` is BPreplay. Switching fonts with the
wrong atlas/icons and a dummy Next face made Settings look
broken.

Harvested `.system/res` from
`NextUI-6.14.0-rc.2+my355-base.zip` / `MinUI.zip` into
`package/system/minui/res` (real fonts, updated atlas,
Games/Tools/Recents/Collections icons, palettes). Session
now always refreshes stock res from the seed. Do not
overwrite those fonts with BPreplay aliases.

## 2026-09-11 — NextUI maintenance belongs in PLAN.md §8

Rewrote section 8 in plain language so Stage 5 is followable:
Zlyme is the OS, NextUI is the menu. Tools paks that duplicate
Settings (Wi-Fi, Bluetooth) go away. SSH/GPU stay Tools until
we add Settings pages. Pak Store waits. No NextUI fork.
The save/"-" bounce is the next bug, not a new architecture.

## 2026-09-11 — Settings "save" was last.txt + a newline

Serial back. nextui.elf was dying ~once a second (2243
segfaults in nextui.txt). Settings *did* write
`minuisettings.txt`. After Settings (or any Tool) we wrote
`/storage\n` to `/tmp/last.txt`. NextUI's `getFile` keeps that
newline; `loadLast` then walks the path until `strrchr` is
NULL. That is the "-" loop.

Fixed: write `/storage` with no newline (`minui-session`,
Settings.pak). Live on the device: last.txt rewritten, scripts
patched, session bind-mounted, nextui PID stable.

Still noisy: no tzdata files (`Europe/Budapest`), no
`gametimectl.elf`. Timezone in Settings cannot actually apply
until we ship zoneinfo.

## 2026-09-12 — zlyme13 on the Flip, then the tool paks

Flashed **zlyme13**. NextUI stays up. Autocal ran. Files.pak A/B was
the SDL south-face vs Nintendo layout; shipped a Nintendo
`gamecontrollerdb.txt` for `retrogame_joypad`. RetroArch MENU
quit is `ra-run --appendconfig` plus overlay cfg (hotkey = button
10). Settings double-free and LED `local` vars were real. Halt
now unmounts bind-mounted paks before squashfs goes busy.

Grabbed the four tool failures into `DEVLOGS/` (do not reset
to “fix” a freeze until the dump is on disk):

- **Artwork Scraper** — bundled `minui-list` SIGSEGV then hang
  holding DRM. Upstream Flip build is keyboard scancodes.
- **Moonlight.pak** — Apostrophe inits, then `hrtimer_nanosleep`.
  Same keyboard assumption; no pair/config.
- **ScrapeGoat** — “No internet / Continue A” and A does nothing.
  Wifi was actually `DISCONNECTED` (169.254); Continue was input.
- **PortMaster** — pugwash → loguru → `sysconfig.get_path` →
  `ValueError: bad marshal data` on the host-written 3.14
  `_sysconfigdata_*.pyc`. No `_ssl` / `sqlite3` on the image
  either (python3 was configured before those kconfig flags).

## 2026-09-12 — Apostrophe, not a keyboard shim

Stock Apostrophe documents Flip buttons as HID scancodes.
Zlyme’s rocknix joypad only emits joystick `BTN_*`. Do not add
a uinput translator; patch the paks.

Vendored https://github.com/Helaas/Apostrophe (MIT, Kevin
Vranken) at `package/system/nextui/apostrophe/` with LICENSE and
CREDITS. `apostrophe.h` maps my355 to NextUI `JOY_*` (A=1 B=0,
D-pad 13–16) and keeps `SDL_JOYBUTTON*` on Flip.

Rebuilt into the Tools paks (credits/licenses in each pak):

- ScrapeGoat v2.3.0 — same ScreenScraper developer tokens as
  the upstream 2.3.0 binary, dynamically linked to image curl.
- Moonlight.pak UI — Apostrophe v1.2.0; streamer stays
  `/usr/bin/moonlight`.
- Artwork Scraper `minui-list` / `minui-presenter` — not
  Apostrophe; rebuilt against this tree’s my355 `api.c` +
  `InitSettings` fallback.

## 2026-09-12 — PortMaster is python, not minui-portmaster

https://github.com/ben16w/minui-portmaster is TrimUI-only
(`tg5040`, `/usr/trimui/lib`). Flip keeps PortMaster-GUI
pugwash (MIT, Jacob / PortsMaster).

The image python3 must actually be *rebuilt* with
`PYTHON3_SSL`, `PYTHON3_SQLITE`, `PY_PYC`, plus
`ca-certificates`. Finalize hook copies the sysconfig `.py` and
deletes the bad `.pyc`. post-build fails the image if `_ssl`,
`_sqlite3`, or the CA bundle is missing. `python3-dirclean` is
required on the next image; `.config` already had the flags
while `config.log` still had `--disable-sqlite3` and
`py_cv_module__ssl=n/a`.

## 2026-09-12 — eudev, storage, LEDs, joypad cal

Switched `/dev` to eudev (drop libudev-zero next to it). Storage
scripts bind sd2/OTG, halt unmounts. `zlyme-led` matches ROCKNIX
`ledcontrol` verbs; `ledcontrol` is a symlink. Joypad patches
0002/0003: DTS deadzone plus sysfs `miyoo_cal_*` restored by
S26 / Autocal.

Image pin for this drop is **zlyme14**.

## 2026-09-12 — no 1.2s after Tools; retry DRM in NextUI

B on Overlays / Artwork Scraper left NextUI on the launching
"-". `nextui.elf` was respawning while kmsdrm master was still
held; `SDL_CreateRenderer` came back with a pointer that could
not make textures (`Parameter 'renderer' is invalid`).

Do not sleep 1.2s in `nextui-session` to paper over that.
`PLAT_initVideo` now retries window/renderer/GL/layer textures
until they actually work (25ms only while contended). Session
still treats minui-list B/menu as 0/2/3, not a pak fail.
Overlays and Artwork Scraper keep writing `/storage` to
`/tmp/last.txt` so the next menu is not the `.pak` folder.

## 2026-09-13 — zlyme24/25 field test: OTA, resize, Ports

Unattended rebuild to **zlyme24**, then **zlyme25** (bash + `/roms`
symlinks + S13 unlabeled fallback). No second `build.sh` on the same
tree; no `linux-reconfigure` on the 25 pass.

**OTA.** `scp` of
`zlyme-my355-20260913-599ac2c10583-dirty.tar` (579M,
`42df3846…`) onto `/storage/.update/zlyme-my355-update.tar`. Python
`http.server` has no Range; `curl --max-time 300` died at 40M. scp ran
~130 KB/s for about an hour. Reboot: `S18` extract, initramfs
`zlyme committed`, u-boot still `Retrieving file: /Image`. Live
`ae652648…-zlyme25`. Storage and Wi-Fi survived (no GPT rewrite).
Host SSH `root@192.168.1.62`; after a `mkfs` of `ZLYME` drop
known_hosts (`accept-new`).

**Resize.** Two shrink-to-32MB cycles with `/boot` kept mounted.
`Resizing storage: OK`, `#autoresize=true`, p3 57G. FAT-proof reboot
after each grow still loads `/Image` (no `Invalid FAT entry`). Live
`mkfs.exfat` while the old superblock is busy fails; a reboot with
no `/storage` mount formats cleanly. `dd` of the first sector of p3
strips `LABEL=ZLYME` and S13 used to no-op — now falls back to
`mmcblk0p3`.

**Ports.** Library card folder is `Roms/Ports (PORTS)/`. Squashfs
`/roms/ports` and `/opt/system/Tools/PortMaster` point there.
`Gravity Defied.sh` via PORTS.pak + image `bash`: `gravity_defied` +
`gptokeyb`, Performance 0123, DMC `simple_ondemand` 1056M. No `/opt`
tmpfs hack.

**ROMs / Stage 8.** GB (gambatte) with session env. PSP `.chd` had
already booted on 23. zram 384MiB lz4. `zlyme-bcsh` 0. IRQ `dw-mci`
and `ehci_hcd:usbN` on fd880000 → CPU0. 8733bu LPS 0/0. `bluetoothctl
scan on` starts; a nearby device appeared. Overlays `curl` is on the
image.

**Samba.** Stock `S70` `mkdir` on squashfs `/var/lib/samba` then
`msg.sock` `chmod 0700` fails on exFAT. Fix: `/tmp/samba-lib` + bind
(and post-build symlink). Live `smbd: OK`, share `storage` listed,
stop clears the pid. Syncthing start/stop needs `killall` (forks).
Those overlay fixes are in the tree; next squashfs OTA ships them.
Defaults stay off.

GitHub Releases still `OWNER/REPO`. Do not commit `TODO.md` or `DEVLOGS/`.

## 2026-09-19 — Settings → Update

Tools `Update.pak` is gone. One Settings row above About talks to
GitHub (`github-release.py`), shows a short build date, downloads
with a progress bar, and only queues `/storage/.update/zlyme-my355-update.tar`
after sha256 matches. Incomplete files stay `*.tar.part`. Failed apply
still goes to `.update/failed/`; the next download deletes that leftover.
`PWR_powerOff(1)` from Settings is a fake reboot (panel off, NextUI
respawns). A after queue calls `zlyme-halt reboot` instead. Session
honors `/tmp/reboot` after a pak, and never recopies `Update.pak` from
an old squashfs.


