# PortMaster capability, Phase 14 start

This is the opening inventory for Phase 14. It is not an acceptance matrix. Status words in the table below are from this tree on 2026-10-16, pin `2026.06.23-0015` in `package/system/portmaster/portmaster.mk`.

## Runtime completion status

The PortMaster seed stays `2026.06.23-0015`. No alpha or beta seed was
taken. Phase 14 remains open. As of the 2026-10-23 evening pass, the
installed image is source `da7eb2128294`, squashfs
`f08c3fa8795565e4195f307ca194b7c16fb8429a1c3b0bde0b960236dc1b1fd1`,
GPU `libmali`. The format=4 validator archive is uninstalled and is
not an acceptance tool. The architecture review is
[phase14-portmaster-architecture-proposal.md](phase14-portmaster-architecture-proposal.md).
It is not approved and it is not current architecture. Sentences
below that still say the final candidate is uninstalled describe the
state before that install. They are left in place.

Box comparison was made at these exact revisions:

- ptitSeb Box86
  `bb716a2a6576cc06da811bf55e31e2f6f03b7596`, which is the reviewed
  upstream head, is the Zlyme ARMHF pin;
- ptitSeb Box64 head
  `39aae76ddf3c515393bab5b2dd58ce676386501f` was reviewed, but Zlyme
  preserves its working v0.4.4 pin
  `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` and `BOX32=OFF`;
- Batocera master
  `cac5b73176de87ec6670f9a7f0d7306a75a969fb` configures its RK3568
  target as AArch64. `batocera-system` selects Box64 for every AArch64
  target, and its current Box64 recipe enables `BOX32` and
  `BOX32_BINFMT`. That tree has no Box86 package. This is Box64/BOX32
  selection on RK3568, not evidence for a native ARMHF Box86 there;
- KNULLI `knulli-main`
  `57afa662009641d181f57241bcc480119b131530`, Batocera submodule
  `487014d91147610ebdd62f870009d4563ac61763`, and Buildroot submodule
  `c2d7985b7528db04c783851db36a5c83ad848c0e` were reviewed. Its RK3566
  image is AArch64 and selects proprietary Mali EGL/GLES/GBM. Neither
  Box package is selected by that target. One legacy Shovel Knight
  launcher carries a game-local Box86 directory; that is not system
  Box86 support;
- ROCKNIX `next`
  `8b70f693b87464efb2ad0febe570db8eb67b6563` builds RK3566 as AArch64
  plus an ARM hard-float side. Its AArch64 emulator set selects Box64.
  The ARM virtual package evaluates the RK3566 emulator set with
  `ENABLE_32BIT=true`, which selects Box86, and the device supplies
  32-bit libmali. Zlyme adopts neither ROCKNIX's copied binary layout,
  binfmt registration, nor global profile configuration.

Zlyme instead builds Box86 natively in its own ARMHF Buildroot target,
checks a separate artifact manifest, and exposes an explicit
`zlyme-box86-run`. It installs no binfmt handler, service, or global
x86 library path. A source-controlled dynamically linked i386 probe
executed under ARMHF Box86 and qemu-arm with output
`box86-x86 4 475f677f`; invalid ELF and missing-library cases returned
diagnostics. That is CPU/runtime proof only. It is not rendered
PortMaster proof.

The 32-bit graphics requirement is separate. An AArch64 GL4ES cannot be
loaded by native ARMHF Box86. Zlyme's licensed ARMHF provider is
Mesa/Panfrost: EGL, GLES, GBM, the Panfrost DRI driver, and ARMHF GL4ES
remain under `/usr/lib/zlyme-armhf`. The existing proprietary libmali
payload is AArch64-only, so graphical Box86 requires a Panfrost boot.
No unsupported ARMHF blob is imported. AArch64 GL4ES is isolated under
`/usr/lib/portmaster/gl4es/aarch64`; ARMHF GL4ES is isolated under
`/usr/lib/zlyme-armhf/gl4es`. Ports select either explicitly, after
their own library directories. System GL, EGL, and GLES symlinks are
unchanged.

SDL3 now has a source-controlled KMSDRM render and InputPlumber-pad
probe. GL4ES has a desktop-OpenGL triangle probe. Disposable marked
Tools entries run both through the normal NextUI ownership lifecycle.
They have built on the target toolchain but have not been physically
observed on the uninstalled candidate. SDL 1.2 compatibility remains
per-port: the installed Abombniball tree carries its own AArch64
SDL-1.2-related library, and no shared SDL1.2 SONAME requirement was
demonstrated. No blind SONAME link or global compatibility package was
added.

Hotkey comparison used LoveRetro NextUI
`5291344b3aceae5fa197437a70824afb41e2d338`, ROCKNIX
`8b70f693b87464efb2ad0febe570db8eb67b6563`, rocknix-hotkey
`cc3a863199a71a350db05e9d0d0e646a8411332c`, PortMaster-GUI
`ccea6b746827d0ae3a1cad744f6e8ccc5a032041`, and the pinned Zlyme
NextUI. ROCKNIX and PortMaster gptokeyb use application-name
termination and a later force kill. LoveRetro NextUI has
application-specific launch scripts rather than an equivalent generic
session waiter. Zlyme keeps its PID/start-time/session ownership model.
The hotkey retains a pidfd for the published spawn waiter and signals
only that waiter; the waiter performs bounded, identity-checked session
cleanup. It never uses `killall`, never signals the frontend group, and
refuses to restart DRM after unresolved cleanup.

The installed-image and named-port evidence is in
[portmaster-matrix-20261023.md](portmaster-matrix-20261023.md). Build
success, executable runtime, rendered display, physical input, audio,
exit, cleanup, and frontend return are separate statuses there.

## Earlier status on 2026-10-23

This section preserves the status before runtime completion was reopened.
The runtime-completion section above is current where the two differ.
The pin was `2026.06.23-0015`. An October 18 upstream labeled alpha was
not taken, and neither was `2026.10.03-1041`.

The product mixer on the installed image is PipeWire with `pipewire-pulse`. `libpulse` and `libpulse-simple` are on that image. BlueALSA is not the A2DP owner. The PulseAudio daemon row and the BlueALSA sentences later in this file are the earlier candidate.

14O's looked-at rows are accepted on installed `4652076`. Abombniball MENU+START failed on that image. The pak-session waiter is in source and was not in that image. ARMHF userspace was proven earlier by `xdelta3.armhf`; that binary is not installed on `4652076`, so it was not run again. SDL3 is installed and has no Flip display test. Box86 and Box64 `BOX32` stay deferred. No GL4ES library was found in the prepared PortMaster tree or three levels under the installed Ports directory. System GLES is Mesa. The launch matrix is [portmaster-matrix-20261023.md](portmaster-matrix-20261023.md).

GitHub marks `2026.10.03-1041` as not a prerelease. The release text is `Release: 2026.10.03-1041 (alpha)`. That is not a reason to move the pin. `2026.07.28-1212` and `2026.10.01-0433` are beta. The latest release whose own text says stable, through 2026-10-16, is `2026.06.23-0015`. Review a newer stable release when one is published. A fix taken from a beta or alpha tag needs a named benefit and a named regression risk, and that fix does not move the pin by itself.

| Area | Status | Evidence |
| --- | --- | --- |
| PortMaster seed and persistent install | Implemented | The image ships the zip. A user update on the selected library is kept. |
| `CFW_NAME=Zlyme` | Implemented | `zlyme-portmaster-prepare` requires that export. |
| Platform class | Host-verified | Prepare inserts `class PlatformZlyme(PlatformBase)` and maps `'zlyme'` to it. The patched `platform.py` from this pin imports. `first_run`, `portmaster_install`, and `portmaster_post_install` create no files. `ES_NAME` stays unset. In this pin's `harbourmaster` tree, `ES_NAME` is only assigned, never read. An older `'zlyme': PlatformROCKNIX` line is rewritten. |
| Selected library and artwork | Implemented | `zlyme-portmaster-root` and `zlyme-portmaster-art`. JPEG is copied, not converted. |
| Mount teardown | Implemented | `zlyme-portmaster-cleanup` unmounts a recorded mount only while its id is the visible one. MTP still refuses a nested mount. |
| AArch64 ports | Partial | The userspace is AArch64. Which ports run was not remeasured here. |
| ARMHF userspace | Proven on a Flip for one program | `xdelta3.armhf -V` printed `Xdelta version 3.1.1` through `/lib/ld-linux-armhf.so.3`, with `libc.so.6` from `/usr/lib/zlyme-armhf`. `control.txt` exports `DEVICE_HAS_ARMHF=Y`. `DEVICE_ARCH` stays `aarch64`. Every ARMHF port working is not proven. |
| Box64 and Wine | Implemented | `BR2_PACKAGE_BOX64` is selected for Wine. `BOX32=OFF`. |
| Box86 | Deferred | No Box86 recipe. The pinned Box64 marks BOX32 experimental. |
| SDL2 | Implemented | NextUI and the product image link SDL2. |
| SDL3 | Built, not run on a Flip | Buildroot `package/sdl3` 3.4.12 is selected with KMSDRM, OpenGL ES, and Wayland. X11 and desktop OpenGL are off. The SONAME stub is gone. `libSDL3.so.0` exports versioned `SDL_Init`. Display and controller use was not run on a Flip. |
| GL4ES | Missing | No GL4ES package in this tree. |
| Theora 1.1 for LÖVE | Implemented | `libtheoradec.so.1` under `/usr/lib/compat`. |
| gptokeyb | In the PortMaster seed | AArch64 `gptokeyb` and `gptokeyb2`, plus ARMHF copies. `control.txt` uses the AArch64 names. InputPlumber remains the virtual pad. |
| ALSA / PulseAudio | Implemented in source, not yet on a Flip | One PulseAudio 17 server. The default ALSA PCM is the Pulse plugin. BlueALSA still owns A2DP and is a Pulse sink. |
| Fake `systemctl` | Rejected | Still rejected. |

At this checkpoint the named ports were not a test list. The later
runtime-completion decision explicitly reopened them.

## Launch environment

`nextui-session` exports `LD_LIBRARY_PATH=/storage/.config/zlyme/lib:/usr/lib`. `portmaster-launch` starts the GUI and prepends `/usr/share/nextui/lib:/usr/lib`. `PORTS.pak/launch.sh` starts a port and leaves the session value in place. A port that sources `control.txt` and calls `get_controls` prepends `/usr/lib/compat` when that directory is not already listed. `zlyme-portmaster-exec` does not change `LD_LIBRARY_PATH`. The AArch64 Weston wrapper it can install prepends that runtime's `lib_aarch64`.

The ARMHF loader's built-in directory is `/usr/lib/zlyme-armhf/`. It is not prepended to native processes. Under qemu-user 10.0.13, with `LD_LIBRARY_PATH` unset, the probe's loader opens `/usr/lib/zlyme-armhf/libc.so.6` and prints `armhf 32 0.3`. With `LD_LIBRARY_PATH=/usr/lib` and an ELF64 file at `/usr/lib/libc.so.6`, the trace tries that file, does not call its init, and then inits the private `libc.so.6`. The same probe output follows. That is qemu-user on the host. It is not a Flip execution.

`device_info.txt` in the seed sets `DEVICE_HAS_ARMHF=Y` when `/lib/ld-linux-armhf.so.3` exists, then sets `DEVICE_ARCH=aarch64` when the AArch64 loader exists. `control.txt` exports `DEVICE_HAS_ARMHF=Y` after that file, so a port that sources `device_info.txt` again still sees Y. The two files do not export opposite values. The bit is the ABI that `xdelta3.armhf` ran. It is not a promise that every ARMHF port runs.

## Box86 and BOX32

Pinned Box64 `2f130fab` (v0.4.4) says `BOX32` is experimental and not to be used. The same README says 32-bit binaries need Box86 or Box32, and that a WOW64 Wine build can run 32-bit Windows programs on Box64 alone. Zlyme's Wine package is that WOW64 build, launched by this Box64 with `BOX32=OFF`. Buildroot 2026.08 has no Box86 recipe. Native Box86 would be an ARMHF executable using the private glibc. It is not added here. `BOX32` stays off so the Wine binary is not rebuilt on an experimental flag.

## GPTK and shared runtimes

The seed's unsuffixed `gptokeyb` and `gptokeyb2` are AArch64 PIE binaries. `gptokeyb.armhf` and `gptokeyb2.armhf` are ARM EABI hard-float. `control.txt` exports `GPTOKEYB` and `GPTOKEYB2` as the unsuffixed names, through `zlyme-portmaster-exec`. InputPlumber remains the virtual Xbox pad (`0x045e/0x028e`). No second grabber was added.

`runtimes/` in the seed contains LÖVE 11.5 with `libs.aarch64` and `libs.x86_64`. There is no ARMHF LÖVE runtime in that zip. `libs/` is empty. `libgl_default.txt` prepends `gl4es.$DEVICE_ARCH` or `gl4es` from the port directory. GL4ES is not a Zlyme package. OpenAL is not in the seed. Engine squashfs files stay PortMaster downloads. The earlier device passes heard ALSA and BlueALSA. The current source uses one PulseAudio server in front of that hardware. That server has not been heard on a Flip.

## HDMI

Compared on 2026-10-17:

- `apommel/baseos-my355` `898590462020`. The simultaneous panel and HDMI path is a mainline U-Boot VOP2 plane assignment, introduced in `72081df41c31` and still described in `docs/decisions.md` and `docs/uboot.md` at that HEAD. `tools/rkbootimg.py` names the masks. The panel gets a real window and HDMI gets another, because the RK3566 mirror windows scan out nothing. Stock disables the panel to use HDMI. That tree does not select 720p for emulators. Zlyme's U-Boot and panel already scan out, so those masks are not copied.
- `apommel/NextUI` `35d5450ce687` (`fix(my355): align HDMI with h700`), still contained in branch `my355-latest-rebase` at `4eaa1721d0bb`. `GFX_init` sets `hdmi_active` from `card0-HDMI-A-1/status`, and `FIXED_WIDTH`/`FIXED_HEIGHT` become 1280×720. The UI is then drawn at that size. LoveRetro pull 761 is that branch: open, head `4eaa1721d0bb`, merge commit recorded by GitHub as `9e0d96546a85cddf2786548d1b1ed7a24deb61ed`. No newer commit on that branch adds a RetroArch or standalone mode policy. Zlyme does not adopt the 1280×720 UI. Art Book and the menus stay 640×480.

Compared for the SDL adapter, not copied:

- ROCKNIX `distribution` `next` `075a7c303b92c4984aa72e6ce85d5d951c3490c6`, `projects/ROCKNIX/packages/graphics/SDL2/patches/0006-drm-resolution.patch`. It modesets `connector->modes[index]` from `/var/run/drmMode` while adding a display, then hides every other SDL mode.
- Batocera `batocera.linux` `master` `38fe6e8bcce84c9b815692ec4da5b6b310cc4e6d`, `board/batocera/patches/sdl2/001-drm-resolution.patch` and `002-drm-conn.patch`. The same index file, plus `/var/run/drmConn` to keep one connector enumeration slot.
- KNULLI `knulli-linux` `knulli-main` `57afa662009641d181f57241bcc480119b131530` carries those two SDL patches at `board/patches/sdl2/` (blobs `a77d6764ff6a` and `09ea189c7e24`) and a RetroArch DRM patch at `package/retroarch/retroarch/008-drm-resolution.patch` (`369b26729e0d`).

The index preserves the EDID clock. The enumeration slot does not preserve connector identity, the file has no gate, and hiding the other SDL modes means an application cannot request a different size. Zlyme keeps one policy command and a small SDL adapter. The adapter uses the connector id and the mode index. It does not set the window's fullscreen flag. A fullscreen request for a different size is left alone. Vulkan windows are skipped. That is the decision. The Batocera stack is not imported. Unmodified SDL cannot see a mode index, so it is not sufficient for 59.94 Hz.

A general review of `apommel/baseos-my355` beyond this display question is still open. It is not a Phase 14 gate. The installer pin stays `e09d37bb0f03c34e564d61bd02164f332d8515a8`.

The Phase 14 HDMI case is a cable connected after boot, then a new process. On the installed candidate, ending the 720p client restored HDMI to `1024x768` at 78750 kHz, so the next client does not inherit that mode. Disabling the DSI panel would not remove that choice. The SDL patch selects the recorded EDID index. The RetroArch patch only runs when `encoder_id` is 0 and refuses a CRTC it cannot prove free. In-process cable changes are not a gate.

`panfrost` selects Panfrost GLES. `panvk` is the only saved GPU value that exports `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER`. RetroArch's stock driver is `gl`. PPSSPP's seed is `GraphicsBackend = 0`. Flycast's seed is `pvr.rend = 0`. PortMaster `2026.06.23-0015` `device_info.txt` has architecture bits and no Vulkan bit. An ICD on disk is not advertised as a capability.

RetroArch 1.22.2 `drm_get_encoder` only accepts `connector->encoder_id`. A connector plugged in after boot can have that field at 0, and context creation then stops with "Couldn't find DRM encoder." The Zlyme patch, used only in that case, takes the first encoder the connector lists whose `possible_crtcs` mask contains a CRTC that is not already scanning. It does not take the panel CRTC. Plugging or unplugging the cable while RetroArch is already running is a different path and is not patched.

`zlyme-hdmi` is the physical choice. NextUI `ac84bec60689e12ecf4e6c86e3edc1bbf4399e6a` letterboxes from it. After the first present it reads the sysfs connector `mode` file, which is width and height only. Status words below are source and host tests. None of the scanout lines have been read on a Flip.

| Backend | Launch | Video | Status |
| --- | --- | --- | --- |
| NextUI and Settings | `nextui.elf`, `settings.elf` | SDL2 KMSDRM | The letterbox is 960×720 at x=160 on 1280×720. On `a58a5ab6`, a wrapper that exported the policy produced HDMI-A-1 CRTC `1280x720` at 74250 kHz and the viewport log. The stock session on that image did not export the variables. The sysfs `mode` file stayed empty. |
| Libretro cores | `ra-run` | RetroArch 1.22.2 KMS/EGL | IMPLEMENTED. Session `video_fullscreen_x/y`, `video_refresh_rate`, and `video_monitor_index`. User `retroarch.cfg` is not written. Aspect settings are not written. Scanout is HARDWARE-PENDING. |
| PPSSPP OpenGL | `PPSSPPSDL --fullscreen` | SDL2 KMSDRM | IMPLEMENTED through the SDL patch. The game scaler stays PPSSPP's. Scanout is HARDWARE-PENDING. |
| PPSSPP Vulkan | same binary, `GraphicsBackend = 3` | `VK_KHR_display`, first Vulkan display | HARDWARE-PENDING. The SDL patch does not choose that plane. |
| Flycast, ScummVM, OpenBOR, DraStic, GZDoom, Amiberry, Hypseus, Moonlight | their launch scripts | SDL2 KMSDRM, dynamic `libSDL2` | IMPLEMENTED through the SDL patch. Scanout is HARDWARE-PENDING. One of these stands in for the SDL2 row on the hardware pass. |
| Dolphin | `start_dolphin` | EGLDRM, first connected connector | HARDWARE-PENDING. `/var/run/drmMode` indexes that connector. Nothing writes the file. |
| AetherSX2 | `start_aethersx2` | Qt EGLFS | IMPLEMENTED as a temporary KMS config. Scanout is HARDWARE-PENDING. |
| PICO-8 and Splore | user `pico8_64` | its own SDL, not shipped | EXTERNAL. The process inherits the SDL variables. A static SDL build will not see the patch. |
| PortMaster GUI and native ports | `portmaster`, `PORTS.pak` | whatever the port links | The managed environment exports the policy. A port with its own DRM or static SDL is EXTERNAL. |
| WestonPack and Wine | `zlyme-weston-run` | Weston DRM, one client | IMPLEMENTED as a temporary `[output]` mode. The compositor is still per launch. Scanout is HARDWARE-PENDING. |
| SDL3 | no probe | KMSDRM in the library | Not covered. The patch is SDL2. |

The mode is the display controller's. Rendering is separate. `zlyme-gpu-env.sh` exports one Vulkan ICD and sets `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER` only when the saved GPU choice is exactly `panvk`. The HDMI variables do not choose an ICD. libmali GLES and Panfrost GLES are the two OpenGL ES stacks the image can boot; neither has an HDMI scanout observation. libmali Vulkan and PanVK are separate. PanVK stays experimental. PPSSPP's `VK_KHR_display` path is not evidence for either Vulkan stack.

`S16display` still sets the panel refresh and still replays `display_mode`. That replay is not the client modeset. Weston `mode=` and the AetherSX2 EGLFS string use an integer refresh. They do not carry the mode index.

## Hardware pass on d438e74, 2026-10-18

Installed squashfs `/boot/zlyme` is `356d7f5c86063de249847adf61b9faf5712c18d4b241d5766738479e689c3527`. `/boot` was read-only. Recently Played `.media/bg.png` matched the firmware Changa One PNG `90ba5400b94b81c0a0bf0ab2b43522ccdfbe6c5ac1d3c5470ffc338a058a9cda`. There was no `/storage/bg.png`. The seed marker was the earlier empty file, so this was the known-hash replacement.

Logs from the launches are on the second card under `/mnt/sd2/zlyme-hw/`. None of these is a played-through game. HDMI scanout below is the CRTC mode while that process was still up. It is not a 720p pass. Audio status files were empty. No button was pressed.

Gambatte, `GBC.pak`, `ZLYME_HDMI_720P=1`, ROM `SOLASTRA.gb`: FAIL before modeset. Log: connector 56 unbound, `No free CRTC for unbound connector 56`, `Couldn't find a suitable DRM device`. `Using fullscreen size` was not logged. With NextUI stopped, HDMI video port 0 was disabled and the panel CRTC stayed active. The HDMI encoder's `possible_crtcs` is `0x1` (video port 0 only). `ACTIVE` is not in the CRTC property list until `DRM_CLIENT_CAP_ATOMIC`. RetroArch 1.22.2 never sets that cap, and the occupancy check treats an unread property as occupied.

The first port batch left `frt_3.3.4` running, so later "kmsdrm not available" lines in that batch are not engine bugs. The table uses the later batch, after that process was gone. Uptime did not reset during these two batches.

| Launcher | Result | What was observed |
| --- | --- | --- |
| `2048.sh` | FAIL | Exited inside the window. HDMI port disabled. No RetroArch process left. Stdout empty. Same class of failure as gambatte, without a retained RetroArch log. |
| `Abombniball.sh` | FAIL | `libpulse-simple.so.0` missing. GPTK started. No `libpulse` under the port tree, `/usr/lib`, or the PortMaster directory. |
| `A Key(s) Path.sh` | LAUNCHED | `frt_3.3.4` and GPTK stayed up. HDMI `1920x1080i60`, panel `640x480p60`. |
| `Ascent DX.sh` | LAUNCHED | `love.aarch64` stayed up. HDMI `1024x768p75`. Log: `Could not restore CRTC`. Not the earlier EGL exit. |
| `Gravity Defied.sh` | LAUNCHED | Launcher and GPTK still up at 12 s. HDMI `1920x1080i60`. The clean log did not repeat `EGL not initialized`. |
| `Shards of God.sh` | LAUNCHED | `ags` stayed up and was scanning saves. HDMI `1920x1080i60`. SDL 2.32.10 had initialized on the earlier contaminated run; this run got past that. |
| `Alien Squatter.sh` | LAUNCHED | `ohrrpgce-game asquatter.rpg -f` stayed up. HDMI `1920x1080i60`. |
| `Dead Cells.sh` | LAUNCHED | The window caught PortMaster's `utils/patcher` under LÖVE, not `gamedata/deadcells`. No game frame. |
| `Deltarune.sh` | FAIL | `gmloadernext.aarch64` missing `libavcodec.so.58`. |
| `Evoland Legendary Edition.sh` | LAUNCHED | Launcher and GPTK still up. HDMI `1920x1080i60`. |
| `Impostor Factory.sh` | LAUNCHED | `mkxp-freebird.aarch64` stayed up and loaded scripts. HDMI `1920x1080i60`. |
| `If On A Winter's Night, Four Travelers.sh` | LAUNCHED | Launcher still up. Save bind succeeded. Engine process was not in the sample. HDMI `1920x1080i60`. |
| `Bowling Cross` | BLOCKED | Directory `bowlingcross` has `gmloader`, `gamedata`, and an apk. There is no `.sh` launcher. None was invented. |

`LISA The Painful.sh`, `Mina the Hollower.sh`, `My Big Sister.sh`, `Nightmare Frames.sh`, `Painted Heart.sh`, `REPOSE.sh`, `Rakuen.sh`, `Skautfold - Shrouded in Sanity.sh`, `SteelAssault.sh`, `Towards the Pantheon - Escaping Eternity.sh`, and `Undertale.sh` were started in a third batch. The route to the Flip dropped while that batch was still restoring NextUI. Their matrix lines are on the card and were not read back. They are not classified here.

Common failures. Missing `libpulse-simple.so.0` is Abombniball's own NEEDED entry, and `LISA The Painful`'s `falcon_mkxp.bin` failed the same way on the saved sample. A resident PulseAudio daemon is not the fix by itself: `libpulse-simple.so.0` speaks the PulseAudio protocol and does nothing useful without a server. A missing `libavcodec.so.58` is Deltarune's loader, not the system FFmpeg SONAME. Ports that did start picked a mode themselves, often interlaced 1920×1080, because `PORTS.pak` does not apply `ZLYME_HDMI_720P`. That is not the RetroArch 720p result. An earlier run rejected `abombniball.armhf` because `libSDL_image-1.2.so.0` from `libs.aarch64` is ELFCLASS64. On the card checked with `00e6c343`, that library is still ELF64 machine 183, and there is no `libs.armhf` directory. The launcher runs `abombniball.${DEVICE_ARCH}`, so the advertised ARMHF bit does not select that binary.

The third batch wrote an END line for LISA and a START line for Mina the Hollower, then the matrix file contains NUL padding. Mina's sample is empty. SSH then had no route. The next successful connection was a new boot, id `46be5cec-fa17-4d49-af76-97d1501264f6`, uptime under 15 minutes, pstore empty, and no panic or OOM line in that boot's dmesg. Wi-Fi was associated to `TP-Link_E44F` at `192.168.0.108`. NextUI was running. No `frt` or Weston process and no extra squashfs mount were left. That is a reboot or power loss. It is not a captured kernel panic. The TV turning off was reported by the maintainer and is not in these logs.

## Audio server

Buildroot 2026.08 PulseAudio is 17.0. Enabling it selects the BlueZ audio plugin because BlueALSA already selects that plugin. Pulse is built with its BlueZ module available and the Zlyme script does not load it, so BlueALSA remains the only A2DP endpoint owner. PipeWire was not chosen: it would add a second graph beside BlueALSA for the same protocol.

`libpulse.so.0` and `libpulse-simple.so.0` come from that package. They are AArch64. They do not make an ARMHF program able to open them. The server listens on `/run/zlyme/pulse/native` only. `autospawn` is off. Installed size, RSS, and playback latency were not measured before the image build. The codec fragment is 1024 bytes, four fragments, 48 kHz S16 stereo: 5.3 ms and 21.3 ms nominal, not a measured latency. On 2026-10-19 the codec sink reported 21017 µs for that setting and 63726 µs for 12 fragments. Codec and HDMI in source now request those 12 fragments. Bluetooth stays at 4. Listening is not done.

Abombniball and LISA need `libpulse-simple.so.0`. A launch that gets past the dynamic linker is not an audio pass until a stream is heard. `libavcodec.so.58` for Deltarune is still a port/runtime SONAME, not the system FFmpeg.
