# PortMaster validation, 2026-10-23

## Runtime-completion update

Phase 14 is still open. The maintainer installed
`zlyme-my355-20261023-c67692fe7ba7.tar` from
`c67692fe7ba7d65b0a1762ee7d26a6ee5ddc4456` and physically accepted
Abombniball returning from the Ports list after MENU+START. SSH on that
installation observed Zlyme `zlyme44.3 (2026-10-23)`, Linux `7.2.10`,
U-Boot `2026.01`, read-only `/boot`, and `/boot/zlyme` SHA-256
`134130f227792e21cfbfc82493d8ed0ba79ad3da24873b6665b41688519cce13`.
The running `nextui.elf` SHA-256 is
`49cefda55510db18c74197c75eaa4e963d663a596aab58063ea1c1a49b5f738c`;
the host binary built from pinned NextUI
`b0960dcde4d69d32871d6605c354b1b901621eb5` has the same hash. The
rootfs does not embed the Zlyme Git revision, so the source association
comes from the named archive and build record rather than a runtime
revision file.

The source after that installed image now has:

- native ARMHF Box86 at upstream
  `bb716a2a6576cc06da811bf55e31e2f6f03b7596`, imported through its own
  checked manifest; Box64 stays at `2f130fab` with `BOX32=OFF`, and the
  Wine WOW64 path is unchanged;
- ARMHF Mesa/Panfrost EGL, GLES, and GBM for graphical Box86 work.
  The installed proprietary libmali is AArch64-only. ARMHF graphics
  therefore requires a Panfrost boot and remains unavailable on a
  libmali boot;
- pinned GL4ES `2037865590d410bcd7b8d1f22b841472ed6d39ac` in isolated,
  explicit AArch64 and ARMHF directories. It does not replace system
  GL, EGL, or GLES and does not override a port-bundled GL4ES;
- normal-NextUI disposable SDL3 KMSDRM/input and AArch64 GL4ES render
  probes, plus a passive bounded process/DRM/mount observer;
- fail-closed PAK session cleanup. Incomplete `/proc` inspection,
  identity changes, allocation failure, or a surviving owned process
  returns status 125. PortMaster cleanup still runs, but
  `nextui-session` does not start another DRM client;
- the exact upstream `systemctl restart oga_events` request translated
  by `zlyme-portmaster-exec` to the existing idempotent
  `zlyme-input ensure` contract. Other `systemctl` commands are not
  emulated.

Current host results separate package presence from execution:

- A clean ARMHF target build, package and manifest checks, invalid-ELF
  and missing-library checks, and the dynamic i386 probe pass. The
  legal probe prints `box86-x86 4 475f677f` under ARMHF Box86 and
  qemu-arm. The product target contains the byte-identical ELF32 ARM
  hard-float Box86 and private libc. That proves CPU/runtime execution,
  not graphical output. Target LLVM, Clang, and build-only SPIR-V
  utility libraries are excluded from the imported runtime after its
  remaining ELF dependency closure is checked.
- SDL3 and GL4ES package/probe builds, explicit selector ordering,
  absence of build-tree RPATH, ARMHF manifest closure, PAK lifecycle,
  mount ownership, PlatformZlyme, library selection, orphan preference,
  and synthetic Delete Game checks are host tests only.
- The candidate graphics probes must be launched from NextUI. Running
  them from SSH beside the frontend would be a second DRM client and is
  not an acceptance test. Physical display and pad observations remain
  NOT RUN until the candidate is installed.

The current installed card still selects `/mnt/sd2`. No compatibility
mount was active during the read-only preflight, and NextUI was the
frontend. Both cards and user files were left unchanged. The named-port
static audit found:

The earlier `DEVICE_HAS_ARMHF=N` is in the selected card's unprepared
copy. Normal launches source `/opt/system/Tools/PortMaster/control.txt`,
whose prepared Zlyme override exports `DEVICE_HAS_ARMHF=Y` after
`device_info.txt`; the captured Abombniball launch also reported Y.
The N file is stale/inactive for that lifecycle, not an effective
capability contradiction, so the user's tree is not rewritten.

- Shards of God: AArch64 AGS engine and game data present. Existing
  diagnostics reached `Starting game`, OpenAL, and an SDL GLES2
  renderer. That historical launch is not a new physical acceptance.
- LISA The Painful: AArch64 `falcon_mkxp.bin` and configuration present.
  The old log failed to open an OpenAL device through Pulse. Current
  Zlyme supplies PipeWire-compatible `libpulse` and
  `libpulse-simple`; the game was not rerun.
- Rakuen: the same AArch64 mkxp engine class is present. Its old log
  names missing `libpulse-simple.so.0`; that SONAME is present on the
  installed image, but the game was not rerun.
- Steel Assault: user game data is present. Its requested Mono squashfs
  was not found in the bounded selected-tree check, and the old launch
  ended at `mono: command not found`. Status is BLOCKED on the shared
  PortMaster runtime, not PASS.
- Skautfold: AArch64 `gmloadernext`, `data.win`, and the input map are
  present. Execution is NOT RUN on the current completion candidate.
- If On A Winter's Night, Four Travelers: AArch64 AGS engine, data, and
  input map are present. An old log reached the engine and later
  reported CRTC restore failure. Execution is NOT RUN on the candidate.
- Mina the Hollower: the AArch64 Machismo loader, extracted application,
  and prepared shader corpus are present. An old log reached the
  Vulkan window path but also recorded unresolved symbols and missing
  initial user files. Rendering, input, audio, clean exit, and NextUI
  return are NOT RUN on the candidate.

The `systemctl: not found` report is now attributable: LISA, Rakuen,
Steel Assault, and Winter Travelers explicitly request
`$ESUDO systemctl restart oga_events` after their engine returns.
Upstream `pm_finish` does the same. Zlyme does not run `oga_events` and
does not add a fake `systemctl`; InputPlumber remains the one input
owner.

The uninstalled candidate is
`zlyme-my355-20261023-8c5841c04fbc.tar`, source
`8c5841c04fbc23ac1ca0c9ad4a21e21c3c910da2`. Its OTA SHA-256 is
`519dc0d40c5d0d6fa2a2ae7eaa2a0d08cd664de00c034dbc40e0bb068ad1e829`,
and its squashfs SHA-256 is
`d5f9f77ee4bb1f7ea1ee7a15881c6a0c1bafd1d591e2d4d41dcf5639be5d90fc`.
The embedded NextUI pin is
`b0960dcde4d69d32871d6605c354b1b901621eb5`. Boot payload comparison
against the installed `c67692f` archive found the kernel, DTB,
idbloader, and U-Boot unchanged. These are build results, not hardware
acceptance.

Required candidate hardware work remains: install the final uninstalled
OTA, rerun Abombniball because the waiter changed after its accepted
image, run the SDL3 and GL4ES probes from the normal menu with a
physical pad, run the ARMHF and Box86 console probes, exercise each
runnable named port and selected LÖVE/Mono/WestonPack/Wine runtime that
is actually installed, verify audio, exit, NextUI return, and mount
cleanup separately, and capture RetroArch's own 1280×720 CRTC. The
alternate Panfrost graphics boot is unobserved. Missing commercial data
or an absent downloaded runtime is not converted into PASS.

## Earlier installed-image matrix

Phase 14 stays open. This is the host and live-device matrix for installed `zlyme-my355-20261023-465207696ff8.tar`. Source `465207696ff8493f239a1bcab0e232459f4be75c`. Squashfs `512454168f4cbb671de9020e12f24f8380fc8ea8c4d410e2d2590fcdd6722906`. NextUI `b0960dcde4d69d32871d6605c354b1b901621eb5`. Kernel `7.2.10`. `/boot/zlyme` matches that squashfs. The version string is `zlyme44.3`. Nothing here was installed over the user's PortMaster tree.

A status of NOT RUN is not a pass.

## Recovery

Abombniball was open from the Ports list and did not return on MENU+START. SSH showed one `abombniball.aarch64`, reparented to init, alone in a session whose leader was already dead, and the only holder of the display device. `SIGTERM` to that pid left it running. `SIGKILL` of that same pid stopped it. The frontend session was not signaled. `nextui.elf` then held the display device. The picture on the panel was not watched.

The game binary does not import `fork` or `setsid`. The script runs it in the foreground. The session log names `PORTS.pak/launch.sh` for that launch. The one-shot trace in the same boot has no chord, no signal, and no port-cleanup line, and the waited pid was still in the frontend session when it was recorded. Settings had already run, so those five lines are not proven to be this launch. What is proven is that the session had returned and the hotkey was gone while the game still held the display.

## What is installed

Both the OS card and the second card have a `.portmaster` tree at `2026.06.23-0015`, with `mod_Zlyme.txt` and `ESUDO` pointed at `zlyme-portmaster-exec`. The copy under `Ports/PortMaster` is the stock tree: empty `ESUDO`, no `mod_Zlyme.txt`. The launch used `/opt/system/Tools/PortMaster`, which is the prepared tree. `DEVICE_ARCH` is `aarch64`. The Abombniball log printed `DEVICE_HAS_ARMHF="Y"`. The second-card `.portmaster` `control.txt` also contains `DEVICE_HAS_ARMHF=N`. That file was not rewritten.

The second card has the port scripts and data directories. The OS-card Ports directory had no game scripts. LÖVE 11.5 is present as `love.aarch64` and `love.x86_64`. No GL4ES file was found in the prepared tree or three directory levels under Ports. No PortMaster, Weston, or `/roms` mount was recorded, and the mount registry directory was absent. No Wine prefix was present. `box64` and the Wine 11.6 wrapper are installed. `box86` is not.

Ports with a top-level script and a data directory: A Key(s) Path, Abombniball, Alien Squatter, Ascent DX, Bowling Cross, Dead Cells, Deltarune, Evoland Legendary Edition, Gravity Defied, If On A Winter's Night, Four Travelers, Impostor Factory, LISA The Painful, Mina the Hollower, My Big Sister, Nightmare Frames, Painted Heart, REPOSE, Rakuen, Shards of God, Skautfold, Steel Assault, Towards the Pantheon, Undertale. `papersplease` has a data directory and no top-level script in that listing. File counts say a directory exists. They do not say the commercial data is complete. A Key(s) Path references Godot. Ascent DX references LÖVE. No script in that pass referenced Weston, Wine, Box86, or Box64. Saves and settings were not opened.

## Tier 1, host

| Check | Status |
| --- | --- |
| PortMaster prepare, root, artwork, log, theme, Theora, PlatformZlyme | PASS |
| Mount ownership and teardown | PASS |
| ARMHF capability (host) | PASS |
| SDL3 package | PASS |
| List width | PASS |
| `libpulse` selected, HDMI launch wiring | PASS |
| Pak launch lifecycle, including Wine cleanup classification | PASS |
| Pak session: clean exit, long-running leader, wrapper child that ignores SIGTERM, frontend sleeper left alone, port cleanup | PASS |
| MENU+START chord recognition, and refusal to signal the frontend session | PASS |

An ELF dependency check is not a game launch. No port was started on the host.

## Tier 2, live device

| Check | Status |
| --- | --- |
| Image, kernel, NextUI pin, squashfs | PASS |
| Active tree `2026.06.23-0015`, prepared `ESUDO`, `DEVICE_ARCH=aarch64` | PASS |
| `DEVICE_HAS_ARMHF=Y` on the launch that ran | PASS |
| Second-card `control.txt` still contains `DEVICE_HAS_ARMHF=N` | recorded, not changed |
| ARMHF loader and private `libc.so.6` present | PASS |
| `xdelta3.armhf` on this image | NOT RUN. The binary is not installed. The earlier `00e6c343` result stays that image's result. |
| Abombniball AArch64 ELF64 machine 183, ARMHF ELF32 machine 40, gptokeyb ELF64 | PASS as file identity, not a launch |
| SDL2 2.32.10, SDL3 3.4.12, system GLES/EGL, `libpulse` and `libpulse-simple` | PASS as files present |
| Box64 and Wine wrapper present; Box86 and BOX32 | DEFERRED |
| LÖVE 11.5 files present | PASS as files. Not launched. |
| GL4ES | not found in the searched trees. Not a system package. |
| PortMaster mounts | none present after recovery |
| Per-port launch | NOT RUN, except the Abombniball start already in progress |

## Tier 3, device launches

NextUI held the display after recovery. No second KMS client was started, and no game was launched from SSH.

| Case | Status |
| --- | --- |
| A. Native AArch64. Abombniball started from the Ports list on this image | FAIL. It did not return on MENU+START. Other native ports were not started. |
| B. ARMHF userspace | NOT RUN on this image. Loader present. Probe binary absent. |
| C. LÖVE, WestonPack, or another compatibility runtime | NOT RUN. LÖVE files are present. No Weston mount. No Wine prefix. |
| D. PortMaster GUI open and exit | NOT RUN |
| E. Abombniball MENU+START after the session waiter | NOT RUN. The waiter is not in the installed image. |

## Phase 14 A–O

| Item | Class |
| --- | --- |
| 14A seed and inventory | IMPLEMENTED. Pin stays `2026.06.23-0015`. Alpha upstream is not taken. |
| 14B ARMHF | IMPLEMENTED. Proven earlier by `xdelta3.armhf`. Not re-run on this image. |
| 14C Box86 and BOX32 | DEFERRED BY DESIGN. Not a release blocker. |
| 14D GLES, SDL3, GL4ES | PARTIAL. System GLES, SDL2, and SDL3 are installed. No SDL3 window test. No GL4ES package, and none in the searched port trees. |
| 14E GPTK and MENU+START | FAILED on this image for Abombniball. The session waiter is in source and is hardware-unproven. |
| 14F runtimes, mounts, audio compatibility | PARTIAL. Host mount and `libpulse` checks passed. PipeWire is the installed mixer. No runtime was launched. |
| 14G named ports | DEFERRED BY DESIGN as per-game work. Several of those directories are on the card. Running each one is not a closure requirement. |
| 14H acceptance | PARTIAL. HDMI audio, Bluetooth, volume, Wi-Fi, NextUI 720p, and panel return stay accepted. The port matrix does not. |
| 14I PlatformZlyme | IMPLEMENTED, HARDWARE UNPROVEN as a GUI. Host checks passed. The prepared trees are on the card. |
| 14J orphan preferences | IMPLEMENTED, HARDWARE UNPROVEN. |
| 14K Wi-Fi services | IMPLEMENTED AND ACCEPTED on `0b35a90`. |
| 14L Art Book | The system and tool pictures looked at with 14O passed. The rest of the art package was not rechecked. |
| 14M HDMI 720p | IMPLEMENTED AND ACCEPTED for NextUI. RetroArch's CRTC was not observed. |
| 14N delete game | IMPLEMENTED, HARDWARE UNPROVEN. |
| 14O list width | IMPLEMENTED AND ACCEPTED for the rows that were looked at. User background was not a separate check. |

Release-critical and still open: MENU+START must return from a game on the image that contains the session waiter, and one native port plus one compatibility runtime must return to NextUI without a leaked mount. SDL3's missing display test, Box86, BOX32, and a global GL4ES package are not release blockers on the ports that are installed. A port that needs GL4ES and does not bring its own is still unproven, not a reason to add the package before that port is chosen.
