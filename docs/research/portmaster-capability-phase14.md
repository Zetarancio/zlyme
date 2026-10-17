# PortMaster capability, Phase 14 start

This is the opening inventory for Phase 14. It is not an acceptance matrix. Status words are from this tree on 2026-10-16, pin `2026.06.23-0015` in `package/system/portmaster/portmaster.mk`.

GitHub marks `2026.10.03-1041` as not a prerelease. The release text is `Release: 2026.10.03-1041 (alpha)`. That is not a reason to move the pin. `2026.07.28-1212` and `2026.10.01-0433` are beta. The latest release whose own text says stable, through 2026-10-16, is `2026.06.23-0015`. Review a newer stable release when one is published. A fix taken from a beta or alpha tag needs a named benefit and a named regression risk, and that fix does not move the pin by itself.

| Area | Status | Evidence |
| --- | --- | --- |
| PortMaster seed and persistent install | Implemented | The image ships the zip. A user update on the selected library is kept. |
| `CFW_NAME=Zlyme` | Implemented | `zlyme-portmaster-prepare` requires that export. |
| Platform class | Host-verified | Prepare inserts `class PlatformZlyme(PlatformBase)` and maps `'zlyme'` to it. The patched `platform.py` from this pin imports. `first_run`, `portmaster_install`, and `portmaster_post_install` create no files. `ES_NAME` stays unset. In this pin's `harbourmaster` tree, `ES_NAME` is only assigned, never read. An older `'zlyme': PlatformROCKNIX` line is rewritten. |
| Selected library and artwork | Implemented | `zlyme-portmaster-root` and `zlyme-portmaster-art`. JPEG is copied, not converted. |
| Mount teardown | Implemented | `zlyme-portmaster-cleanup` unmounts a recorded mount only while its id is the visible one. MTP still refuses a nested mount. |
| AArch64 ports | Partial | The userspace is AArch64. Which ports run was not remeasured here. |
| ARMHF userspace | Host-tested with qemu-user; staged into the product tree | `output-armhf` comes from `scripts/build-armhf-sysroot.sh`. `zlyme-armhf-runtime` installs the loader and `/usr/lib/zlyme-armhf/`. qemu-user 10.0.13 in a disposable Debian container ran the probe. `DEVICE_HAS_ARMHF` stays `N`. Not run on a Flip. |
| Box64 and Wine | Implemented | `BR2_PACKAGE_BOX64` is selected for Wine. `BOX32=OFF`. |
| Box86 | Deferred | No Box86 recipe. The pinned Box64 marks BOX32 experimental. |
| SDL2 | Implemented | NextUI and the product image link SDL2. |
| SDL3 | Built, not run on a Flip | Buildroot `package/sdl3` 3.4.12 is selected with KMSDRM, OpenGL ES, and Wayland. X11 and desktop OpenGL are off. The SONAME stub is gone. `libSDL3.so.0` exports versioned `SDL_Init`. Display and controller use was not run on a Flip. |
| GL4ES | Missing | No GL4ES package in this tree. |
| Theora 1.1 for LÖVE | Implemented | `libtheoradec.so.1` under `/usr/lib/compat`. |
| gptokeyb | In the PortMaster seed | AArch64 `gptokeyb` and `gptokeyb2`, plus ARMHF copies. `control.txt` uses the AArch64 names. InputPlumber remains the virtual pad. |
| ALSA / BlueALSA | Implemented | No resident PulseAudio. |
| Fake `systemctl` | Rejected | Still rejected. |

Named ports in the roadmap are not a test list for this phase.

## Launch environment

`nextui-session` exports `LD_LIBRARY_PATH=/storage/.config/zlyme/lib:/usr/lib`. `portmaster-launch` starts the GUI and prepends `/usr/share/nextui/lib:/usr/lib`. `PORTS.pak/launch.sh` starts a port and leaves the session value in place. A port that sources `control.txt` and calls `get_controls` prepends `/usr/lib/compat` when that directory is not already listed. `zlyme-portmaster-exec` does not change `LD_LIBRARY_PATH`. The AArch64 Weston wrapper it can install prepends that runtime's `lib_aarch64`.

The ARMHF loader's built-in directory is `/usr/lib/zlyme-armhf/`. It is not prepended to native processes. Under qemu-user 10.0.13, with `LD_LIBRARY_PATH` unset, the probe's loader opens `/usr/lib/zlyme-armhf/libc.so.6` and prints `armhf 32 0.3`. With `LD_LIBRARY_PATH=/usr/lib` and an ELF64 file at `/usr/lib/libc.so.6`, the trace tries that file, does not call its init, and then inits the private `libc.so.6`. The same probe output follows. That is qemu-user on the host. It is not a Flip execution.

`device_info.txt` in the seed sets `DEVICE_HAS_ARMHF=Y` when `/lib/ld-linux-armhf.so.3` exists, then sets `DEVICE_ARCH=aarch64` when the AArch64 loader exists. `control.txt` assigns `DEVICE_HAS_ARMHF=N` after sourcing that file. The loader can be in the image before a Flip has run an ARMHF program.

## Box86 and BOX32

Pinned Box64 `2f130fab` (v0.4.4) says `BOX32` is experimental and not to be used. The same README says 32-bit binaries need Box86 or Box32, and that a WOW64 Wine build can run 32-bit Windows programs on Box64 alone. Zlyme's Wine package is that WOW64 build, launched by this Box64 with `BOX32=OFF`. Buildroot 2026.08 has no Box86 recipe. Native Box86 would be an ARMHF executable using the private glibc. It is not added here. `BOX32` stays off so the Wine binary is not rebuilt on an experimental flag.

## GPTK and shared runtimes

The seed's unsuffixed `gptokeyb` and `gptokeyb2` are AArch64 PIE binaries. `gptokeyb.armhf` and `gptokeyb2.armhf` are ARM EABI hard-float. `control.txt` exports `GPTOKEYB` and `GPTOKEYB2` as the unsuffixed names, through `zlyme-portmaster-exec`. InputPlumber remains the virtual Xbox pad (`0x045e/0x028e`). No second grabber was added.

`runtimes/` in the seed contains LÖVE 11.5 with `libs.aarch64` and `libs.x86_64`. There is no ARMHF LÖVE runtime in that zip. `libs/` is empty. `libgl_default.txt` prepends `gl4es.$DEVICE_ARCH` or `gl4es` from the port directory. GL4ES is not a Zlyme package. OpenAL is not in the seed. Engine squashfs files stay PortMaster downloads. Audio stays ALSA and BlueALSA.

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

`zlyme-hdmi` is the physical choice. NextUI `ac84bec60689e12ecf4e6c86e3edc1bbf4399e6a` letterboxes from it. After the first present it reads the sysfs connector `mode` file, which is width and height only. Status words below are source and host tests. None of the scanout lines have been read on a Flip.

| Backend | Launch | Video | Status |
| --- | --- | --- | --- |
| NextUI and Settings | `nextui.elf`, `settings.elf` | SDL2 KMSDRM | IMPLEMENTED. Letterbox is 960×720 at x=160 on 1280×720. Scanout is HARDWARE-PENDING. |
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

The mode is the display controller's. Rendering is separate. `zlyme-gpu-env.sh` exports one Vulkan ICD and sets `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER` only when the saved GPU choice is exactly `panfrost`. The HDMI variables do not choose an ICD. libmali GLES and Panfrost GLES are the two OpenGL ES stacks the image can boot; neither has an HDMI scanout observation. libmali Vulkan and PanVK are separate. PanVK stays experimental. PPSSPP's `VK_KHR_display` path is not evidence for either Vulkan stack.

`S16display` still sets the panel refresh and still replays `display_mode`. That replay is not the client modeset. Weston `mode=` and the AetherSX2 EGLFS string use an integer refresh. They do not carry the mode index.
