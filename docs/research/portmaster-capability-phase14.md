# PortMaster capability, Phase 14 start

This is the opening inventory for Phase 14. It is not an acceptance matrix. Status words are from this tree on 2026-10-16, pin `2026.06.23-0015` in `package/system/portmaster/portmaster.mk`. Upstream `2026.10.03-1041` was not fetched in this pass, so it is not compared file by file.

| Area | Status | Evidence |
| --- | --- | --- |
| PortMaster seed and persistent install | Implemented | The image ships the zip. A user update on the selected library is kept. |
| `CFW_NAME=Zlyme` | Implemented | `zlyme-portmaster-prepare` requires that export. |
| Platform class | Partial | The same prepare step requires `'zlyme': PlatformROCKNIX`. That inherits ROCKNIX behavior. A `PlatformZlyme` class is not in the tree. |
| Selected library and artwork | Implemented | `zlyme-portmaster-root` and `zlyme-portmaster-art`. JPEG is copied, not converted. |
| Mount teardown | Implemented | `zlyme-portmaster-cleanup` unmounts a recorded mount only while its id is the visible one. MTP still refuses a nested mount. |
| AArch64 ports | Partial | The userspace is AArch64. Which ports run was not remeasured here. |
| ARMHF userspace | Missing | No `ld-linux-armhf` package and no second ARMHF root in this tree. |
| Box64 and Wine | Implemented | `BR2_PACKAGE_BOX64` is selected for Wine. |
| Box86 | Missing | No Box86 recipe in `package/`. |
| SDL2 | Implemented | NextUI and the product image link SDL2. |
| SDL3 | Missing as a runtime | `board/my355/post-build.sh` installs a SONAME stub because FluidSynth needed `libSDL3.so.0`. Buildroot 2026.08 has `package/sdl3`. It is not selected. |
| GL4ES | Missing | No GL4ES package in this tree. |
| Theora 1.1 for LÖVE | Implemented | `libtheoradec.so.1` under `/usr/lib/compat`. |
| gptokeyb | Missing as a Zlyme package | Not in `package/`. InputPlumber remains the virtual pad. |
| ALSA / BlueALSA | Implemented | No resident PulseAudio. |
| Fake `systemctl` | Rejected | Still rejected. |

Named ports in the roadmap are not a test list for this phase.
