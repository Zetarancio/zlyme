# Product polish — Phase 9

Research only. Nothing here was implemented. Dispositions say what Phase 9 should do after Phase 8 owns the NextUI source.

Date: 2026-09-30. Tree: `baadc22b4be1e96c67e75ab94482a5f51f13d4c5`.

Evidence labels match `docs/research/frontend-source-phase8.md`.

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
| Save format / save-state format | RESEARCH FIRST, then KEEP or hide | Settings still persist `SAVE_FORMAT` and `STATE_FORMAT` (`settings.cpp`, `config.h`). `zlyme-game-cleanup` reads them. `ra-run.sh` sets `savefile_directory` and `savestate_directory` and does not map the format enums onto RetroArch save names. Do not delete the rows as a MinArch leftover until that audit finishes. Either wire them or hide them with a migration note. |
| Wi-Fi regulatory domain | RESEARCH FIRST | No country UI decision until cfg80211/regdb behavior and whether the domain persists are known. |
| Persistent PAK logs | KEEP | `pak-log.sh` appends with `>>` when `zlyme-ctl want logs`. Bound the files. Do not add logrotate unless a bound file is not enough. |
| Timezone vs NTP | RESEARCH FIRST | `platform.c` stores localtime under `/storage/.config/nextui/shared/localtime` and reads `/usr/share/zoneinfo`. The clock widget uses `localtime()`. First-frame work deliberately skipped `TIME_init()`. Separate "clock is UTC" from "no NTP". |
| Bluetooth headset icon after radio off | RESEARCH FIRST | `generic_bt.c` classifies headsets from bluetoothctl Class/Icon. The stale icon is an invalidation question when the radio stops, not a new audio path. |
| Doom input | RESEARCH FIRST | `DOOM.pak/launch.sh` execs `gzdoom` with `+set use_joystick true` and sources `pak-input.sh`. Map that path before changing buttons. It is not a libretro core. |
| Orphan cleanup UI freeze | RESEARCH FIRST | `zlymemenu.cpp` already has a dry-run invocation of `zlyme-game-cleanup`. Run that and capture the exit before any destructive pass. |
| VTree font / log | RESEARCH FIRST | Still open. Not re-diagnosed in this pass. |
| Leftover `FSCK*.REC` | KEEP if Phase 8 did not fix it | See `frontend-source-phase8.md`. |

## Group 2 — Settings and UI

| Work | Disposition | Notes |
| --- | --- | --- |
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

Fetched 2026-09-30:

| Candidate | What it is | License signal | Activity |
| --- | --- | --- | --- |
| `ruffle-rs/ruffle` | Official player. HEAD seen `7140bb4e9b8b` (2026-09-30), web dependency bump. | GitHub license API returned no single SPDX id. Confirm MIT OR Apache-2.0 from the repo before packaging. | Active the day of this note. |
| `aweigit/ruffle-miyooflip` | Fork with `sdl2test-flip` (SDL2/GLES), plus Brick and desktop frontends. Pushed 2026-07-19. | GitHub license API: no SPDX id. Read `LICENSE.md` before any import. | Stale relative to upstream. |
| `SilverPsychoo/Ruffle-Handheld` | Multi-CFW launcher: discovery, profiles, NextUI menu. Pushed 2026-09-30. | MIT. | Active. NextUI display/cursor path is still described as experimental by the maintainer; re-read the README at implementation time. |

Preferred direction: pin official Ruffle, and put a thin SDL/GLES frontend in front of it, using `sdl2test-flip` as the handheld renderer starting point. Use SilverPsychoo as the reference for SWF discovery, multi-file games, profiles, handheld controls, and the NextUI menu. Pinning the whole `aweigit` fork is the alternative if the official core cannot be built against that frontend without a large private patch set.

Record before inclusion: Rust/Buildroot/cargo, dependency size, GLES fit with the Zlyme stack, controller ABI, virtual mouse, quit/hotkey, and the license of every crate that would ship. Do not import a prebuilt player.

### Music Player

`nborodikhin/nextui-music-player`. MIT. `pak.json` platforms include `my355`. Changelog `v1.15.0` says Miyoo Flip support; `v1.17.0` (current `pak.json` version) mentions a Miyoo JPEG. Pushed 2026-09-30.

`launch.sh` on `main` reads and writes `cpu0/cpufreq` itself (`conservative`, min, max) and restores them on exit. Do not ship that. Session policy goes through `zlyme-governor`, the PAK input environment, `pak-log.sh`, and `zlyme-audio`.

INTEGRATION CANDIDATE. Built-in Tool PAK versus Pak Store is not decided here.

### Cheat Downloader

`nborodikhin/nextui-cheat-downloader-alt`. MIT. `pak.json` version `v1.6.0` lists `tg5040`, `tg5050`, and `my355`. Changelog `v1.3.0` added my355 and switched to official minui-list / minui-presenter. The README install example still shows only `tg5040`. Written in Nim (`cheat_manager.nim`). Pushed 2026-08-16.

The Libretro cheat database stays downloaded user content. It does not go in the base image. Prefer the minui-list and minui-presenter already in the image over bundling second copies.

INTEGRATION CANDIDATE. Same Pak Store question as Music Player.

### Pak Store

DEFER the delivery decision until both candidates have a source-build plan. Weigh offline availability, reproducible builds, and what happens when upstream `launch.sh` or `pak.json` changes. Convenience of not vendoring is not the reason to choose the store.

## Group 5 — release

| Work | Disposition | Notes |
| --- | --- | --- |
| Weston test PAK | KEEP | `paks/Tools/Weston.pak` is still installed. Drop it from the production image if it is only a developer probe. Keep the developer tool. |
| CI log volume | KEEP | Short log on the Actions console, full log as an artifact, so the job is not truncated. |
| README | INVARIANT | Per shipped feature, not a final dump. |
| Community / Contributing | KEEP | Invite other RK3566 ports and point at Discord. |
| Dead file audit | KEEP, last | After features stop moving. Grep-clean is not proof. |

End of Phase 9, in order: version bump, one full clean Buildroot build, reproducibility check, one release/OTA candidate, one hardware pass for the behavior that needs the device. No OTA per text or default tweak.
