# PortMaster validation, 2026-10-23

## X-Moto and JVGS, 2026-10-25

Same squashfs. Boot `a0cf811e-e52e-453b-a7c5-a4d256b83fd4`. GPU `libmali`. Both screens stayed blank. The failing boundary is the dynamic linker, before SDL initialization and before GL context creation.

X-Moto `xmoto` is AArch64, needs `libxml2.so.2`, `libGL.so.1`, `libGLU.so.1`, and libSDL2. The system has `libxml2.so.16` only. `libs.aarch64` has no libxml2. `PORTS.log` 2026-10-25T10:29:40Z: `error while loading shared libraries: libxml2.so.2`. The script sources `libgl_default.txt` (`LIBGL_ES=2`, `LIBGL_GL=21`, `LIBGL_FB=4` when `card0` exists) and sets `SDL_VIDEO_GL_DRIVER` and `SDL_VIDEO_EGL_DRIVER` to `gl4es.aarch64`. `share/xmoto` is present. Those settings never reached a running game.

JVGS `bin/jvgs` is AArch64, needs `libGL.so.1` and `libSDL-1.2.so.0`, and calls `SDL_GL_SwapBuffers`. `PORTS.log.1` 2026-10-25T10:29:16Z: `error while loading shared libraries: libmodplug.so.1`. That SONAME is not in `/usr/lib` or `jvgs/libs.aarch64`. The script uses the same `libgl_default.txt` and port `libGL.so.1`. The three ports' bundled `libGL.so.1` files share SHA-256 `b2b24ebe56b894e44b2ed8ce335ad8b1c90e8856b3b3f864561122c8ec32f970`. Aerofoil loaded its copy. X-Moto and JVGS did not.

`pm_finish` then killed gptokeyb and gptokeyb2. No GL4ES init line, no GBM line, and no KMSDRM line appears in either port log. Zlyme's fallback was not involved.

## Aerofoil, 2026-10-25

Same squashfs and boot `190b7a7d-150f-4bc3-bbf2-badc3dcea785`. GPU `libmali`. The maintainer launched Aerofoil from Ports and exited from the game menu. Picture, motion, pad, and audio were fine. NextUI returned. No Pak failed dialog, leftover process, save bind, or kernel Oops. The port log shows `libgl_default.txt` selecting `LIBGL_FB=4` and the port's `gl4es.aarch64` library, built Nov 12 2024, logging `using GBM` on `/dev/dri/card0`. `libGL.so.1` SHA-256 `b2b24ebe56b894e44b2ed8ce335ad8b1c90e8856b3b3f864561122c8ec32f970`. Zlyme's fallback library was not loaded. JVGS and X-Moto were not run. Panfrost was not tested.

## Isolated GL4ES diagnostic, 2026-10-25

Same installed squashfs
`cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`.
Boot `190b7a7d-150f-4bc3-bbf2-badc3dcea785`. GPU `libmali`. A private
GL4ES library from pin `2037865590`, built with `NOX11`, `NOEGL`,
and `NO_INIT_CONSTRUCTOR`, was loaded from the disposable Tools pak.
The probe called `initialize_gl4es()` after the SDL context existed,
`glFlush()` before each swap, and `close_gl4es()` before SDL teardown.
The maintainer saw a moving triangle. `GL4ES_DONE frames=709 error=0x0`.
NextUI returned with no Pak failed dialog and no leftover probe or
mount. The original launcher was restored and the installed
`/usr/lib/portmaster/gl4es` library was not replaced. This is not an
ordinary PortMaster binary and not a Panfrost result. The dark-screen
row below remains the record of the installed library.

## Installed `72916de` Gate 1

Source `72916de97b2ce8a027bad14ace275ef25426a695`. Squashfs
`cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`.
Boot `5fdca665-7a90-4aaf-8d89-4fc32e4456cc`. Steel Assault at
23:22:28Z reached Mali-G52, loaded shaders, and wrote a save. The
maintainer exited to NextUI. Shards of God reached `Starting game`
and the maintainer exited. After those launches, `owned-mounts` was
empty and mountinfo had no Mono directory, no Shards AGS bind, no
`/roms`, and no `/tmp/weston`. `/storage` and `/mnt/sd2` stayed
mounted. Winter Travelers' loaded `gamedata/acsetup.cfg` requested `D3D9`
and failed at 23:24:11Z. The maintainer later set that same file to
`driver=software` and reports picture, pad, audio, and return to
NextUI. Shards already used `driver=software`. Both still log the
KMSDRM cursor line. The package template `config/acsetup.cfg` was
already `software` and is not recopied while
`.initial_config_done` exists. Reinstalling the port is not
guaranteed to keep the corrected file. The 2026-10-25 isolated GL4ES diagnostic is a later entry and does not change this Winter result.
Audio for Steel was not a separate check.

## Installed `da7eb21` pass

Supersedes the "candidate not installed" sentences in the section
below for current status only. Those sentences stay as the record of
the earlier day.

Installed source `da7eb2128294d2ef3d48a6691dd857da75ae8e89`. Squashfs
`f08c3fa8795565e4195f307ca194b7c16fb8429a1c3b0bde0b960236dc1b1fd1`.
GPU `libmali`. Seed `2026.06.23-0015`. Evidence archive
`Portmaster and gpu report.zip`, SHA-256
`4c101d6e5e8b9ddff202795a247ca36bd87fd58648e3cce04e3b0751e954abb8`.
The on-image validator is format=3. Do not use it for acceptance.
The format=4 archive from `074949c` is uninstalled.

| Case | Status | Bound |
| --- | --- | --- |
| Shards of God | Start and pad input observed | `PORTS.log.2` at 20:55:20Z. AGS reached `Starting game`. gptokeyb used `./shardsofgod.gptk`. Maintainer reports usable input. Conflict original kept. Not every AGS port. |
| Winter Travelers | FAIL | `PORTS.log.1` at 20:55:54Z. Same cursor line as Shards, then another graphics path: `Failed to load GL`, `Cursor not initialized properly`, segmentation fault. The cursor line is not the established cause. |
| Steel Assault | FAIL | `PORTS.log` at 20:56:30Z. `taskset not found`, `mount: bad address 'opt'`, mount source begins `//opt/system/Tools/PortMaster/libs/` (double leading slash), `mono: command not found`. Bytes are on SD2. `taskset`, mount, runtime root, and `PATH` are separate. |
| GL4ES probe | Context observed, picture FAIL | `system-0/session.txt`. `LIBGL_FB=3`, `GL4ES_READY` Mali-G52, no `GL4ES_DONE`. Black screen. MENU+START. |
| SDL3 probe | Events PASS, picture reaction NOT DEMONSTRATED | Same session. OpenGL ES2, Xbox 360 pad, `SDL3_DONE frames=512 input=1`. Probe does not draw button state. Not an InputPlumber failure. |
| Box86 console | PASS | Same image, SSH, `box86-x86 4 475f677f`, exit 0. Not in the zip. Graphical Box86 not run. |
| DRM clients | UNKNOWN | Debugfs unavailable. Idle `/dev/dri/card0` fd on `nextui.elf` is not a master PASS. |
| Panfrost GL4ES, Ascent Panfrost, Mina, RetroArch HDMI CRTC | Open | Not in this archive. |

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
- AArch64 GL4ES pin `81547d986798e876de8b434193920b606a72363f`, the
  ROCKNIX `ODROID`, `NOX11`, and `NOEGL` profile, isolated under
  `/usr/lib/portmaster/gl4es/aarch64`. ARMHF stays at
  `2037865590d410bcd7b8d1f22b841472ed6d39ac` under
  `/usr/lib/zlyme-armhf/gl4es`. Neither replaces system GL, EGL, or
  GLES or a port-bundled GL4ES. The AArch64 change is a host recipe;
  it is not the library on the installed image;
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

The uninstalled `8c5841c` build was superseded before use after
waiter-identity review. The replacement candidate is
`zlyme-my355-20261023-3da3f2bafe05.tar`, source
`3da3f2bafe051821a4aaf484441c71f573e0346e`. Its OTA SHA-256 is
`59ba6c76bd6120fd39fb0aee40be266234ae5f8ebb673e52778e37e53c9f6c8b`,
and its squashfs SHA-256 is
`ad9c430a9efde75156146d2d2f1b26a2cc2e4bba1fc1f29f3cc7f4931bcfb320`.
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
