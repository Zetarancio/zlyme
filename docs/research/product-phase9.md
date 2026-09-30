# Product polish — Phase 9

Research only. Nothing here was implemented. Dispositions say what Phase 9 should do after Phase 8 owns the NextUI source.

Date: 2026-09-30. The original notes were taken at `baadc22b4be1e96c67e75ab94482a5f51f13d4c5`. The governor and README-gate sections were added after Phase 8 closed, before any Phase 9 code.

Evidence labels match `docs/research/frontend-source-phase8.md`.

## Emulator speed and governor policy

This is the first Phase 9 work. Two choices are fixed. The February 2024 gpSP pin is not a candidate, and Spruce's per-system CPU floors are the floors to apply.

### gpSP pin

Zlyme currently builds `4caf7a167d159866479ea94d6b2d13c26ceb3e72`. The carried external pins are:

| Distro | Revision | gpSP |
| --- | --- | --- |
| ROCKNIX `next` | `a55d58a1209b35e287dd55a3aad67a5543b467ce` | `8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f` |
| KNULLI `knulli-main` | `6a23957a19a1df18989ac6aa5e9fff003ae611ed` | `d6decfa351b575e2936afebba26d41ec20e4ddcd` |

ROCKNIX carries the newer of the two. Phase 9 updates Zlyme to exactly `8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f`. Do not take current libretro/gpSP HEAD, and do not take a commit after that ROCKNIX pin. Inspect the delta and the existing `libretro-gpsp.mk` for build flags, ARM64 dynarec, dependencies, and license. Do not import unrelated ROCKNIX packaging. That pin changes the default sound output rate from 65536 to 32768. `gpSP.opt` does not override the rate. Do not add an override only to restate the new default.

RetroArch on Zlyme already has `video_threaded = true`, `video_vsync = true`, `video_hard_sync = false`, `video_frame_delay = 0`, `video_max_swapchain_images = 3`, `audio_latency = 64`, and `run_ahead_enabled = false`. `gpSP.opt` enables the dynarec and disables frameskip.

### CPU floors

SpruceOS `2b7bc4a79359de14ea4d4f00da9801a937e2846d` is the source of `scaling_min_freq` per system. Those values are the policy. Do not research a different set, and do not replace a Spruce system floor with a generic play or heavy minimum. Do not copy Spruce's ondemand governor, its two-core Smart layout, or its DMC implementation.

Zlyme keeps schedutil, the existing core counts, and the existing in-game DMC and GPU behavior. The Spruce number is the requested minimum. The runtime floor is the lowest frequency in `scaling_available_frequencies` that is greater than or equal to that request. Exact matches stay. 240000 and 312000 become 408000. 648000 becomes 816000. 1008000 becomes 1104000. Never round down. If the sysfs list is missing, use that same mapping on the known my355 OPPs: 408000, 600000, 816000, 1104000, 1416000, 1608000, 1800000, 1992000.

`zlyme-governor emu <tag>` owns the table. A launcher passes the tag. It does not call `play` or `heavy` for an emulator. `ZLYME_GOVERNOR`, set from MENU+Y, still selects smart, performance, overclock, or the other explicit modes and is not replaced by the Spruce floor.

Applied from SpruceOS `2b7bc4a` `Emu/*/config.json`. Effective floors use the my355 OPP list.

| Zlyme tag | Spruce system | Spruce floor | Zlyme floor |
| --- | --- | ---: | ---: |
| GB | GB | 240000 | 408000 |
| GBC, FC, A5200 | GBC, FC, FIFTYTWOHUNDRED | 312000 | 408000 |
| MS, GG, PCE, NGP, A26, SG1000, VEC, PKM, MSX | MS, GG, PCE, NGP, ATARI, SEGASGONE, VECTREX, POKE, MSX | 408000 | 408000 |
| COLECO, INTV, LYNX, O2, ST, A78, A800, DOOM, EASYRPG, P8 | COLECO, INTELLIVISION, LYNX, ODYSSEY, ATARIST, SEVENTYEIGHTHUNDRED, EIGHTHUNDRED, DOOM, EASYRPG, FAKE08 | 480000 | 600000 |
| MD, WS, MKXPZ, PORTS | MD, WS, MKXP-Z, PORTS | 648000 | 816000 |
| GBA, SFC, VB, DOS, PICO, NDS, SCUMMVM, FBNEO, MAME, AMIGA, 32X, SGX, TIC | GBA, SFC, VB, DOS, PICO8, NDS, SCUMMVM, FBNEO, ARCADE, AMIGA, THIRTYTWOX, SGFX, TIC | 816000 | 816000 |
| PS, PSP, N64, DC, SATURN, OPENBOR, NEOCD | same names | 1008000 | 1104000 |
| PS2, GC, WII | none |  | heavy, minimum 1104000 |
| WINE, 3DO, DAPHNE | none |  | play, minimum 408000 |

### What "tested" means

Phase 9A does not require gameplay. The maintainer may play emulators later; that is outside this gate. Acceptance is: gpSP is exactly the ROCKNIX revision and the package builds; every shipped tag has an explicit governor disposition; the Spruce floor table and the OPP resolution tests pass; launchers call `zlyme-governor emu <tag>`; `ZLYME_GOVERNOR` still wins; return to NextUI still selects smart. Do not describe emulator speed as physically proven.

```text
PHASE 9A GPSP UPDATE = BUILD VERIFIED
PHASE 9A SPRUCE CPU FLOORS = STATIC/BUILD VERIFIED
RUNTIME EMULATOR PERFORMANCE = MAINTAINER VALIDATION OUTSIDE PHASE GATE
```

## README release gate

Ride-along README edits stay. They do not replace a final pass against the last non-prerelease GitHub release: `zlyme40 (2026-09-23)`, tag `zlyme-35854070921`. `zlyme43 (2026-09-28)` is a prerelease and is not that baseline. The pass checks emulators, Tools/PAKs, Settings, and install/update instructions against the final image and source. Deferred work stays undescribed. The joystick section should keep calibration, deadzone, the stick test, rumble, and that built-in controls work in games. Driver, UART, and InputPlumber detail stays out of the README. After the floor change, the README may say that per-system CPU frequency floors are adapted from SpruceOS's Miyoo Flip tuning onto Zlyme's mainline frequency table. It must not say that Zlyme uses Spruce's governor, DMC policy, or core-count policy. The full README pass against `zlyme40` is still the release gate.

## Incremental OTA

This is transport only. A full OTA and a delta OTA both end at `/storage/.update/pending/zlyme`. Initramfs still copies that file over `/boot/zlyme`. Nothing patches the live squashfs in place.

`zlyme43` is a baseline. `zlyme43.1` is a maintenance release. `zlyme43.0` is not a version. A baseline publishes a full OTA, `zlyme.img`, and a manifest with `deltas` empty. It does not diff against the previous major. A point release still publishes the full OTA, and may add direct deltas from the same-major baseline and the last three earlier point releases of that major. The device applies a delta only when `from_sha256` equals the SHA-256 of the installed `/boot/zlyme`. Otherwise it uses the full OTA.

The patch is `zstd --patch-from` from CLI 1.5.7, which the image already ships. Do not add xdelta3. A delta package is a tar of the normal boot files with `zlyme` replaced by `zlyme.patch.zst` and a `DELTA-MANIFEST`. Reconstruction writes `zlyme.new` under `/storage/.update/reconstruct`, hashes it, and renames it into `pending/zlyme` only on a match. A `.new` file is not a pending update. A delta tar at least 70% of the full OTA size is not published.

`scripts/make-release-deltas.py` runs in the GitHub Actions release job only. `build.sh` and `make-update-tar.sh` stay full-OTA tools. Releases without `release-manifest.json` stay on the old single-tar path. A corrupt manifest that names a full OTA which fails its hash fails the release job. A release with no manifest is skipped as a delta base.

Reproducibility of the squashfs is still a final Phase 9 release check. This transport does not require two clean builds. Safety is exact base hash to exact target hash. mksquashfs timestamps and `SOURCE_DATE_EPOCH` are not rewritten here.

The final release gate should also run one realistic zstd-delta benchmark on Zlyme-sized squashfs inputs. Record the old root size, the new root size, the patch size, the patch/full ratio, encode time, decode time, peak decoder RSS if practical, and the round-trip target SHA. That measurement is release validation. It does not block the current product work.

```text
PHASE 9A GPSP UPDATE = BUILD VERIFIED
PHASE 9A SPRUCE CPU FLOORS = STATIC/BUILD VERIFIED
RUNTIME EMULATOR PERFORMANCE = MAINTAINER VALIDATION OUTSIDE PHASE GATE
```

## Dropped from the roadmap

These were checked in source and are not open Phase 9 tasks.

| Item | Disposition | Why |
| --- | --- | --- |
| `.Trash-1000` cleanup | ALREADY IMPLEMENTED | `zlyme-game-cleanup.sh` matches `.Trash` and `.Trash-*`. |
| Merge `portmaster-home` and `PortMaster` | ALREADY DESIGNED | `portmaster-launch` sets `HOME` to `.config/portmaster-home` because exFAT folds case. `.config/PortMaster` holds `control.txt` / `mapper.txt`. The install tree is `HM_TOOLS_DIR/PortMaster`. Three roles, not one duplicated directory. |
| NextUI shutdown routing | ALREADY IMPLEMENTED | `PLAT_powerOff` touches `/tmp/poweroff` or `/tmp/reboot`. `nextui-session` execs `zlyme-halt`. Reopen only if a long-press path is shown to skip those files. |
| Remove `rtl8723fu-firmware` | REJECT | The recipe comment states it is the RTL8733BU Bluetooth firmware (`rtl_bt/rtl8723fu_{fw,config}.bin`). Not in linux-firmware. |
| Joystick calibration as its own Phase 9 feature | MOVE TO PHASE 8 | Keep it as a platform-visibility boundary while frontend code is split into `workspace/my355`. No new calibration behavior. |
| README as a standalone gate | INVARIANT | Every user-facing system, PAK, or setting updates the README in the same change. |

## Group 1 — correctness

| Work | Disposition | Notes |
| --- | --- | --- |
| Save format / save-state format / extracted file name | COMPLETE | Hidden on my355. Shared NextUI enums, getters, setters, defaults, and `minuisettings.txt` keys stay. See the Game-format conclusion below. |
| Wi-Fi regulatory domain | RESEARCH FIRST | No country UI decision until cfg80211/regdb behavior and whether the domain persists are known. |
| Persistent PAK logs | KEEP | `pak-log.sh` appends with `>>` when `zlyme-ctl want logs`. Bound the files. Do not add logrotate unless a bound file is not enough. |
| Timezone vs NTP | RESEARCH FIRST | `platform.c` stores localtime under `/storage/.config/nextui/shared/localtime` and reads `/usr/share/zoneinfo`. The clock widget uses `localtime()`. First-frame work deliberately skipped `TIME_init()`. Separate "clock is UTC" from "no NTP". |
| Bluetooth headset icon after radio off | RESEARCH FIRST | `generic_bt.c` classifies headsets from bluetoothctl Class/Icon. The stale icon is an invalidation question when the radio stops, not a new audio path. |
| Doom input | RESEARCH FIRST | `DOOM.pak/launch.sh` execs `gzdoom` with `+set use_joystick true` and sources `pak-input.sh`. Map that path before changing buttons. It is not a libretro core. |
| Orphan cleanup UI freeze | RESEARCH FIRST | The dry-run path remains `zlyme-game-cleanup <action> --dry-run`. Responsiveness of that synchronous scan is a later item. Do not add threads, cancellation, or a progress UI as part of the format-row change. |
| VTree font / log | RESEARCH FIRST | Still open. Not re-diagnosed in this pass. |
| Leftover `FSCK*.REC` | KEEP if Phase 8 did not fix it | See `frontend-source-phase8.md`. |

### Game-format conclusion

RetroArch 1.22.2 names battery saves `*.srm` and savestates `*.state`, with numbered slots as `*.stateN` (slot 0 stays `*.state`). Compression is `save_file_compression` (default false) and `savestate_file_compression` (default true). Those options are not the MinUI filename enums. `ra-run.sh` sets `savefile_directory` and `savestate_directory` only. It does not read `SAVE_FORMAT`, `STATE_FORMAT`, or `useExtractedFileName`.

```text
Save format:
shared NextUI setting, not consumed by Zlyme's RetroArch launcher.
Hidden on my355; retained in shared NextUI for other/future platforms.
Save-state format:
same disposition.
Use extracted file name:
not consumed by the current Zlyme RetroArch path.
Hidden on my355; shared setting retained.
Cleanup:
never depended on these values; stale environment plumbing removed.
```

MinArch still reads the shared settings. The my355 image deletes `minarch.elf`, and no emulator pak launches it. The enums, getters, setters, defaults, and `minuisettings.txt` keys stay. Old values remain stored and unused on my355. No settings file is rewritten.

```text
PHASE 9C GAME FORMAT SETTINGS = COMPLETE
MY355 INERT FORMAT ROWS = HIDDEN
SHARED NEXTUI FORMAT SUPPORT = RETAINED
CLEANUP FORMAT DEPENDENCY = REMOVED
```

## Group 2 — Settings and UI

| Work | Disposition | Notes |
| --- | --- | --- |
| Quick Menu order | KEEP, after Phase 8 | Current `getQuickToggles()` order is Wi-Fi, Bluetooth, Settings, then Pak Store, Sleep, Reboot, Poweroff. The intended order is Settings, Wi-Fi, Bluetooth, then the same remaining entries. Phase 8 preserves today's order. Pak Store stays deferred; this only reserves its place if the entry exists. |
| Keyboard L1 DELETE pill | KEEP | `keyboardprompt.cpp` already deletes on `BTN_L1`. The shared button hint does not say so. Add the pill once, in `KeyboardPrompt`, so every caller gets it. |
| Shorter destructive Game-settings text | KEEP | Copy change only, after the save-format audit so the text matches real behavior. |
| One pending-reboot prompt | KEEP | Aggregate reboot-required settings. Prompt once on leaving Settings. Reboot through `zlyme-halt reboot`. |
| PortMaster and VTree dark themes | KEEP | `portmaster-launch` already seeds a Zlyme theme into PortMaster. Rethink it from a dark baseline. VTree is separate. |
| Emulator and governor selectors as pills | KEEP | Use the existing NextUI/MinUI pill widgets. |
| Stop advertising CLTMP on my355 | KEEP | `GFX_blitHardwareHints` still offers `CLTMP` / `COLOR TEMP`. Display color temperature is not a my355 control. Hide that hint on this platform. |
| Global A/B swap | KEEP | Implement at the InputPlumber virtual controller, not per emulator. |
| Advanced System submenu | KEEP | GPU, CPU undervolt, ZRAM, USB OTG, HDMI, secondary SD, System Logs. |
| Factory Reset placement | KEEP | Document what it deletes, then move it. `Zlyme_appendFactoryResetItem` is on the system list today. |
| Reset Settings vs Factory Reset | KEEP | Do not remove submenu reset actions until the two operations are distinct in the UI and in the files they touch. |
| VTree `Settings_ShowHidden=yes` | RESEARCH FIRST | Confirm the key's meaning in the VTree source before changing the default. |
| Rumble default 30% to 40% | KEEP | `FF_DEFAULT_GAIN_PERCENT` is 30 in `ff_gain.h`, with tests that lock that number. This is a my355 product default, not an upstream MinUI change. |
| CPU undervolt default to L1 | DEFER | Default in `zlyme-ctl` and `S15bootpart` is `undervolt=off`. L1/L2/L3 stay selectable and map to `rk3566-undervolt-cpu-*.dtbo`. L1 sets 800 mV on 408–1104 MHz, then 850/900/950/1000 mV at 1416/1608/1800/1992 MHz. The 1992 MHz base point added by the kernel patch is 1150 mV. Stock voltages for the lower OPPs live in upstream `rk3566.dtsi` and were not copied into this repository. Silicon-dependent. Do not change the default without that side-by-side, failure reports, and an explicit decision. |

## Group 3 — storage, library, launch

| Work | Disposition | Notes |
| --- | --- | --- |
| PortMaster install disk | RESEARCH FIRST | `portmaster-launch` already exports `HM_PORTS_DIR`, `HM_TOOLS_DIR`, and `HM_SCRIPTS_DIR`. Use that model if PortMaster already has a supported install-location switch. Do not move its files from outside. |
| Format secondary media | KEEP, with hard limits | Secondary SD and removable OTG only. The system card and internal partitions must be impossible to select. Explicit filesystem choice and a destructive confirm. Inspect who owns the mount before adding the UI. |
| Overlays PAK content-directory overrides | KEEP | Deterministic RetroArch content-directory overrides. The PAK already exists. |
| PICO-8 / Splore | RESEARCH FIRST | `nextui.c` treats `pico8_64` and `pico8.dat` as runtime assets, separate from `.p8` cartridges. Find Splore's real download directory before listing those carts. Fake-8 is a different emulator. BIOS discovery across libraries is its own question. |
| Per-ROM delete | KEEP | Reuse `zlyme-game-cleanup` matching. Exact ROM and save paths, plus a confirm. |
| Splash vs `quiet` | KEEP | `S12splash` starts the animation without reading `/proc/cmdline`. If `quiet` is absent, leave the console visible. |

## Group 4 — optional systems

No binaries were downloaded. No forks were created.

### Flash / Ruffle

Fetched 2026-09-30. The first research note preferred official Ruffle plus a Zlyme-maintained SDL/GLES frontend, with `aweigit/ruffle-miyooflip` as the fallback fork. That direction is superseded. Zlyme will not own a Ruffle frontend. An older working player with a small packaging glue layer is preferred to a newer Ruffle that Zlyme would have to keep building.

Preferred candidate: `SilverPsychoo/Ruffle-Handheld`, used as an upstream-owned appliance.

```text
Zlyme integration glue
        |
        v
Ruffle-Handheld
        |
        v
its frozen bundled Ruffle runtime
```

Inspected `main` at `d6e6e4527e97e6d25ba034de29754086a3eb5a9b` (2026-09-30). `VERSION` is `0.8.34`. Project license is MIT.

PROVEN FROM UPSTREAM SOURCE:

- `port.json` describes the bundle as an offline ARM64 launcher with frozen v0.7.7 binaries, profile-controlled buttons, and an offline profile maker.
- `runtime/core/launch.sh` is labeled "Ruffle Handheld v0.7.7" and logs `Engine: frozen-v0.7.7`. It reads SDL controller config (`SDL_GAMECONTROLLERCONFIG` or `SDL_GAMECONTROLLERCONFIG_FILE`) and can feed gptokeyb2.
- `runtime/native-adapter.sh` selects a video driver. The NextUI/TrimUI branch clears `DISPLAY` and `SDL_VIDEODRIVER`. Another branch sets `SDL_VIDEODRIVER=kmsdrm`. NextUI preloads `runtime/libruffle_nextui_display.aarch64.so` when `RUFFLE_NEXTUI_DISPLAY=1`.
- The tree ships ARM64 `ruffle-native.aarch64` and `ruffle-native-multifile.aarch64`. Zlyme does not build that runtime.
- `setup.sh` detects NextUI when `SDCARD_PATH` has `Roms`, `PLATFORM` is set, and `Emus/$PLATFORM/PORTS.pak` exists. It can also detect `PORTS.pak` from the script path.
- Profiles, single-file and multi-file launchers, and `profile-maker.html` are in the tree. `THIRD_PARTY.txt` attributes the emulator to Ruffle / ruffle4consoles (MIT OR Apache-2.0) and says no SWFs are distributed.
- `tools/ruffle_nextui_display.c` says the display adapter is experimental, keeps the frozen executable unchanged, and does not intercept GL calls.

README limits, still current, so this is not a Zlyme/my355 success:

- NextUI / TrimUI Brick: installer and game player have run. Cursor movement is still under investigation. Some games render in only a quarter of the screen.
- ROCKNIX on Miyoo Flip: reported to reach the player. Controls and individual games still need testing.

`ruffle-rs/ruffle` (`7140bb4e9b8b`, 2026-09-30) and `aweigit/ruffle-miyooflip` (pushed 2026-07-19, `sdl2test-flip`) stay in this note as comparison only. They are not the implementation path.

Phase 9 policy:

1. Integrate a pinned Ruffle-Handheld revision substantially as supplied. Record the revision and checksums.
2. Allow only small packaging and environment glue, as with other third-party ports.
3. Do not fork or patch the bundled Ruffle runtime or frontend to make Flash work.
4. Do not replace frozen v0.7.7 with current official Ruffle in the first integration.
5. Keep the bundled third-party license and attribution.
6. Test the existing NextUI path on Zlyme/my355.

If it runs with that glue, include it. If it needs a Zlyme renderer, a Zlyme SDL/GLES frontend, invasive runtime patches, or ongoing merges from official Ruffle, defer Flash. No binaries were imported for this note.

### Music Player

`nborodikhin/nextui-music-player`. MIT. `pak.json` platforms include `my355`. Changelog `v1.15.0` says Miyoo Flip support; `v1.17.0` (current `pak.json` version) mentions a Miyoo JPEG. Pushed 2026-09-30.

`launch.sh` on `main` reads and writes `cpu0/cpufreq` itself (`conservative`, min, max) and restores them on exit. Do not ship that. Session policy goes through `zlyme-governor`, the PAK input environment, `pak-log.sh`, and `zlyme-audio`.

INTEGRATION CANDIDATE as a direct pinned Zlyme package. Pak Store is not part of this decision.

### Cheat Downloader

`nborodikhin/nextui-cheat-downloader-alt`. MIT. `pak.json` version `v1.6.0` lists `tg5040`, `tg5050`, and `my355`. Changelog `v1.3.0` added my355 and switched to official minui-list / minui-presenter. The README install example still shows only `tg5040`. Written in Nim (`cheat_manager.nim`). Pushed 2026-08-16.

The Libretro cheat database stays downloaded user content. It does not go in the base image. Prefer the minui-list and minui-presenter already in the image over bundling second copies.

INTEGRATION CANDIDATE as a direct pinned Zlyme package. Pak Store is not part of this decision.

### Pak Store

Not a Phase 8 or Phase 9 gate. The earlier note treated Pak Store as an open delivery choice for Music Player and Cheat Downloader. That choice is closed for this phase: both are evaluated as pinned Zlyme integrations only. Do not design a generic Pak Store architecture here.

Future: evaluate Pak Store after the core Zlyme product and first stable release are complete. At that time reconsider whether optional/community applications should move from curated built-in integrations to Pak Store. The later look can weigh easier community updates, a smaller base image, upstream independence, reproducibility, offline availability, security and provenance, and breakage when an upstream package changes.

## Group 5 — release

| Work | Disposition | Notes |
| --- | --- | --- |
| Weston test PAK | KEEP | `paks/Tools/Weston.pak` is still installed. Drop it from the production image if it is only a developer probe. Keep the developer tool. |
| CI log volume | KEEP | Short log on the Actions console, full log as an artifact, so the job is not truncated. |
| README | INVARIANT, plus a final gate | Per shipped feature, and one reconciliation against non-prerelease `zlyme40 (2026-09-23)` before the version bump. See the README release gate above. |
| Community / Contributing | KEEP | Invite other RK3566 ports and point at Discord. |
| Dead file audit | KEEP, last | After features stop moving. Grep-clean is not proof. |

End of Phase 9: version bump, then one committed SHA. From that SHA, a local incremental OTA is only a smoke test. The GitHub Actions `Build` workflow, from an empty Buildroot output tree, is the clean release candidate. Reproducibility checks and the release image use the remote artifact. An incremental OTA does not prove that clean image. No OTA per text or default tweak.
