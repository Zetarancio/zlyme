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
