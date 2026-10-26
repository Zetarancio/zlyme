# Phase 15C1 — RetroArch input and panel-audio investigation

Date: 2026-10-26. Read-only. No RetroArch, input, audio, or display code was changed.

The installed image is squashfs `e3772c9f0760c494120098cddb5575e195aaa5e57212aaf14def79f68758d10b`, source `d358bf533e79d058bb63bfc32487bd544d8eb5de`. Phase 15 after that commit changes the PPSSPP save-bind lifecycle and documentation. `ra-run.sh`, the RetroArch recipe, the stock configuration, InputPlumber, the panel DTS, and the PipeWire graph are the same code as that image.

## Confirmed source behavior

`ra-run.sh` appends a session config that forces `input_driver` and `input_joypad_driver` to `sdl2` and `input_player1_joypad_index` to `0`. It does not write the user's `retroarch.cfg`. `pak-input.sh` exports `SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT` for `045e:028e`, so SDL index 0 is an InputPlumber virtual pad. The udev driver does not use that SDL filter.

The stock file uses ALSA device `default`, 64 ms latency, audio/video sync, threaded video, and no `video_refresh_rate`. RetroArch 1.22.2 is built with SDL2, udev, ALSA, KMS, and EGL. The installed binary also reports a PipeWire audio driver. The stock file does not select it. `default` is the PipeWire ALSA plugin. There is no PulseAudio daemon.

The panel mode in `rk3566-miyoo-flip.dts` requests 32000 kHz on a 1030×518 timing. `&cru` assigns VPLL 1.2 GHz and `&vop` parents `DCLK_VOP1` to VPLL. Upstream Linux removed `CLK_SET_RATE_PARENT` from RK3568 `dclk_vop*` so a modeset divides the PLL instead of retuning it. 1.2 GHz / 38 is 31,578,947 Hz. That is the same clock tree as `zlyme44.3`.

InputPlumber's `zlyme_miyoo_flip` map sends the physical face buttons and digital triggers to the `xb360` target. The virtual device is what RetroArch sees. The shipped autoconfig is SDL2-only and uses SDL gamecontroller button numbers. Those numbers are not evdev indexes.

## Previously reported hardware evidence

Issue #3, on `zlyme44.3`, measured about 45.5 FPS with the SDL2 joypad backend and about 124.6 FPS with the udev joypad backend in a fixed 600-frame uncapped run. The report says the blocking call was not identified. Normal play after the udev workaround was about 59 FPS. Index 1 was that boot's ordering, not a general rule.

Issue #2, on the `zlyme44.3` ALSA graph, read `dclk_vop1` at 31,578,948 Hz during gameplay and traced ALSA `-EPIPE` underruns. A temporary `video_refresh_rate` of 59.187592308 removed those underruns in that test. The maintainer asked for a PipeWire retest. That retest has not been done.

## New read-only device observations

On the installed image, with NextUI in the foreground and no game running:

- `/boot/zlyme` matches the squashfs above. The GPU value is `libmali`.
- `nextui.elf`, InputPlumber, PipeWire, and `pipewire-pulse` are running. PipeWire's status is `ready`.
- Both `Miyoo Flip Gamepad` and `Microsoft X-Box 360 pad` (`045e:028e`) are present.
- DSI-1 is connected and enabled. HDMI-A-1 is disconnected.
- RetroArch on the device reports SDL2, UDEV, ALSA, and PipeWire.
- Debugfs clock and CRTC state were not readable. This idle check does not say what the pixel clock is while RetroArch owns the display.

## Hypotheses that still need a test

The FPS table shows the SDL2 joypad backend is the slow path and the udev joypad backend is not. RetroArch 1.22.2's SDL2 joypad poll pumps the SDL queue and flushes axis and button events on every poll. An analog virtual pad can make that flush expensive. That is a code-path hypothesis, not a profile from this device. It is not evidence that the virtual device, enumeration order, or the general SDL2 input driver is the cause. The issue's own matrix already kept general SDL2 input fast when the joypad backend was udev.

The clock arithmetic still predicts about 59.1876 Hz whenever the 32 MHz panel mode is active and VPLL stays at 1.2 GHz. PipeWire does not change that divider. It can change where an underrun is counted. A clean PipeWire session would not prove the divider changed, and an idle clock reading would not prove the gameplay clock.

## Candidate fixes and risks

Issue #3, not implemented: a session-only udev joypad selection that never hardcodes index 1. It must skip `Miyoo Flip Gamepad`, match `Microsoft X-Box 360 pad` devices to InputPlumber's player order, and use an evdev autoconfig checked against the virtual pad's capability bitmap. The SDL gamecontroller file cannot be reused as that bitmap. If the player order cannot be proved, keep the current SDL2 session. Do not force threaded video. Risks are a wrong player assignment, a menu button that follows SDL number 5 instead of the evdev Guide index, and hotplug reordering after launch. MENU+START is `zlyme-pak-hotkey` on the virtual pad and does not depend on RetroArch's joypad driver, but it still has to be rechecked.

Issue #2, not implemented: no DTS edit and no global 59.187592308 setting. The smallest later change, only if a gameplay retest still shows broken audio, is a session refresh computed from the live internal-panel CRTC clock. It must not apply to HDMI. Raising latency or the resampler limit would hide the symptom without identifying the clock.

The missing evidence is one gpSP session on this image: the debugfs CRTC clock and totals while the game is running, whether the sound breaks, RetroArch's reported audio rate, and PipeWire xruns. An idle frontend reading is not that test.
