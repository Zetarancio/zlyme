# Product polish — Phase 9

This file records the Phase 9 decisions and what was actually verified. Earlier sections are the research and the passes that led here, including intermediate failures. Those failures stay as history.

Phase 9 implementation is closed. The accepted runtime SHA is `337ccbce2587393463a4b49c551f94e33e318e44`. The maintainer installed that image and hardware-accepted it. The displayed product is `zlyme44 (2026-10-03)`. The installed root SHA-256 is `9462f77f78bb750680b36f1ab720ef22e6954be6d76f7caab5127b7010288213`. `main` was fast-forwarded to that exact SHA. GitHub Actions Build run [37164297221](https://github.com/Zetarancio/zlyme/actions/runs/37164297221) built that SHA from a clean tree and succeeded on 2026-10-04. It published the first stable, non-prerelease release, [`zlyme-37164297221`](https://github.com/Zetarancio/zlyme/releases/tag/zlyme-37164297221), named `zlyme44 (2026-10-04)`, with its tag at `337ccbce2587393463a4b49c551f94e33e318e44`. Assets: `zlyme.img`, `zlyme-my355-20261004-337ccbce2587.tar` and its `.sha256`, and `release-manifest.json`, with zero deltas because `zlyme44` is a baseline. The date differs from the accepted local image because the clean build ran on 2026-10-04. The source SHA is the same. That closed the reproducibility and release gate.

Date of the original notes: 2026-09-30, at `baadc22b4be1e96c67e75ab94482a5f51f13d4c5`. The governor and README-gate sections were added after Phase 8 closed.

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

`zlyme44` is the Phase 9 baseline. It publishes a full OTA, `zlyme.img`, and a manifest with `deltas` empty. It does not diff against `zlyme43`. A later `zlyme44.1` or `zlyme44.2` still publishes the full OTA and may add direct deltas from the `zlyme44` baseline and the last three earlier point releases of that major. `zlyme45` is the next full baseline and again publishes no deltas. `zlyme44.0` is not a version. The device applies a delta only when `from_sha256` equals the SHA-256 of the installed `/boot/zlyme`. The displayed version is not enough. Otherwise it uses the full OTA. Earlier `zlyme43` images remain historical development artifacts. The published `zlyme43` GitHub release is a prerelease and is not mutated or deleted.

The patch is `zstd --patch-from` from CLI 1.5.7, which the image already ships. Reconstruction is `zstd -d --memory=2048MB --mmap-dict --patch-from`. The memory cap accepts a root-sized window. That cap is larger than the base squashfs, so zstd would otherwise malloc a second copy of it. On the 1 GiB Flip that copy is OOM-killed. `--mmap-dict` keeps the installed `/boot/zlyme` file-backed. Do not add xdelta3. A delta package is a tar of the normal boot files with `zlyme` replaced by `zlyme.patch.zst` and a `DELTA-MANIFEST`. Reconstruction writes `zlyme.new` under `/storage/.update/reconstruct`, hashes it, and renames it into `pending/zlyme` only on a match. A `.new` file is not a pending update. A delta tar at least 70% of the full OTA size is not published.

`scripts/make-release-deltas.py` runs in the GitHub Actions release job only. `build.sh` and `make-update-tar.sh` stay full-OTA tools. Releases without `release-manifest.json` stay on the old single-tar path. A corrupt manifest that names a full OTA which fails its hash fails the release job. A release with no manifest is skipped as a delta base.

Reproducibility of the squashfs is still a final Phase 9 release check. This transport does not require two clean builds. Safety is exact base hash to exact target hash. mksquashfs timestamps and `SOURCE_DATE_EPOCH` are not rewritten here.

The final release gate should also run one realistic zstd-delta benchmark on Zlyme-sized squashfs inputs. Record the old root size, the new root size, the patch size, the patch/full ratio, encode time, decode time, peak decoder RSS if practical, and the round-trip target SHA. That measurement is release validation. It does not block the current product work.

Hardware record of the root-sized delta path:

1. On the installed `7796b98` image, `test-stage` of a real root-sized delta was OOM-killed inside `zstd`. That updater allowed a large window and did not pass `--mmap-dict`, so zstd copied the squashfs into RAM. `/boot/zlyme` was unchanged.
2. The same patch, decoded with `--mmap-dict` so the installed root stayed file-backed, reconstructed the target on `/storage` with no new OOM.
3. `337ccbce` added `--mmap-dict` to the updater.
4. After that image was installed (root `9462f77f78bb750680b36f1ab720ef22e6954be6d76f7caab5127b7010288213`), `ZLYME_UPDATE_TEST=1 zlyme-update test-stage` of a new delta whose target was the `7796b98` root exited 0. `pending/zlyme` matched `9ddb8c88a9e94d876e7fa7bc367f54b6b45462fd1d94d8eb492f972a674e670c` and was 653897728 bytes. No new OOM occurred. The boot payload hashes were unchanged. Cleanup removed the test pending tree, the splash flag, and the test tar. `zlyme-update status` returned to `queued=no`. The same image had already shown a fresh ZcrapeGoat cheat download and `/storage/Cheats/GB/Mole Mania.cht`.

`test-stage` is not a user command. It calls the normal stage path, so it creates `/boot/zlyme-splash.progress` for the run. That flag is not a root or kernel write. A test `pending` tree must be removed before reboot. Do not put a test tar under `/storage/.update`. `/tmp` may be tmpfs and must not hold the test delta while memory is measured.

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
| Wi-Fi regulatory domain | COMPLETE | `wireless-regdb` is already shipped. `cfg80211` and `mac80211` stay modules so `regulatory.db` is present when they load. The persistent country is the global `country=` line in `/storage/.config/wpa_supplicant.conf`. No line means World/default `00`. The user chooses an explicit alpha-2; timezone, locale, and location are not used. The pinned RTL8733BU build does not set `CONFIG_REGD_SRC_FROM_OS`. Its cfg80211 notifier passes `NL80211_REGDOM_SET_BY_USER` into `rtw_set_country()`, so `iw reg set` is the existing hint. No driver patch. |
| Persistent PAK logs | COMPLETE | System logs keep 5 logged-boot generations under `/storage/.logs/system-N`. PAK logs keep 3 launch generations per tag under `/storage/.logs/paks/`. Logs off: the session wrapper and routine session lines use `/tmp`, and normal use does not append a diagnostic file on `/storage`. No logrotate or daemon. New images no longer write `/storage/.config/zlyme/nextui-session.log`. An old copy on a card is left in place. |
| Timezone vs NTP | COMPLETE | Wall-clock sync stays `S49ntp`: HTTP `Date` sets UTC system time and writes the RTC in UTC. No NTP daemon. Timezone is presentation. `/etc/localtime` is a squashfs symlink to `/storage/.config/nextui/shared/localtime`. After `/storage` is mounted, `S15` runs `zlyme-timezone ensure` before the background seed returns, so the first `localtime()` is not racing an empty target. A missing or corrupt file becomes UTC. A valid file is kept. Settings → System → Time zone calls `zlyme-timezone apply`, which stores the zone bytes and `localtime.zone`. A missing name on a UTC file shows UTC. Zoneinfo comes from `BR2_TARGET_TZ_INFO` with an empty `BR2_TARGET_LOCALTIME`. The clock does not depend on Wi-Fi, and zoneinfo parsing is not on the first-frame path. |
| Bluetooth headset icon after radio off | COMPLETE | `PLAT_bluetoothEnable(false)` clears the saved radio flag before the shutdown thread finishes. `PLAT_getNetworkStatus()` already forced the cache false when `BT_enabled()` was false, but only on the next poll. `PLAT_btIsConnected()` now returns `BT_enabled() && bluetoothConnected`, so the status pill cannot keep a cached true in that gap. Pairing, reconnect, and BlueALSA are unchanged. |
| Doom input | ALREADY CORRECT | GZDoom g4.14.2 Linux input is `src/common/platform/posix/sdl/i_joystick.cpp`. It calls `SDL_JoystickOpen` and polls axes and hats. `+set use_joystick true` enables that path. Default axes are side, forward, none, yaw, pitch, which matches an Xbox pad whose third axis is the left trigger. InputPlumber grabs the physical pad; the remaining node is the virtual `045e:028e` pad. No Zlyme remap was added. |
| Orphan cleanup UI freeze | COMPLETE | The scan loads each card's ROM stems once and matches saves in one `awk` pass. A 5,000-ROM / 5,500-save host fixture took 18753 ms with a per-file `grep` and 48 ms with the indexed scan, with the same 500 orphans. No UI thread was added. Dry-run remains `zlyme-game-cleanup <action> --dry-run` and still runs before DELETE. |
| VTree font / log | COMPLETE | Files.pak used to copy `config.ini` on every launch, so `FontFile` and `ShowHidden` never survived. It now seeds once. A selected font stays. Logging is the bounded Files PAK log from Phase 9E. No second VTree log. |
| Leftover `FSCK*.REC` | CLOSED AS HISTORICAL | `FSCK*.REC` is a dosfstools recovered-cluster name, not a Zlyme writer. Phase 8 left `/boot` read-only and found none of those files after a normal reboot. No current production path creates them. Do not fsck or delete boot-FAT files from this phase. |

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

### Standalone settings reset

`zlyme-game-cleanup standalones` deletes an explicit settings list. It does not delete a tree and then try to spare user data. Dry-run prints that same list. A failed `rm` makes the script exit nonzero. The Settings row shows "Scan failed" or "Cleanup failed" instead of "Done".

| Emulator | Settings reset path | Preserved user-data path | Evidence |
| --- | --- | --- | --- |
| PPSSPP | `/storage/.config/ppsspp/PSP/SYSTEM` | `/storage/.config/ppsspp/PSP/SAVEDATA`, `/storage/.config/ppsspp/PSP/PPSSPP_STATE`, and `Saves/PSP` | `PSP.pak/launch.sh` bind-mounts the Saves directories onto those two config paths. A failed bind must not turn them into delete targets. |
| Flycast | `/storage/.config/flycast` and `/storage/.config/nextui/<platform>/.config/flycast` | `Saves/DC` and `/storage/.config/nextui/<platform>/.local/share/flycast` | `DC.pak/launch.sh` seeds `emu.cfg` from `XDG_CONFIG_HOME` or `$HOME/.config`. It bind-mounts `Saves/DC` onto `XDG_DATA_HOME/flycast`. |
| Dolphin | `/storage/.config/dolphin-emu` | `Saves/GC`, `Saves/WII`, and `/storage/.config/nextui/<platform>/.local/share/dolphin-emu` | `start_dolphin.sh` writes `Dolphin.ini` and `GCPadNew.ini` under `XDG_CONFIG_HOME` and bind-mounts the Saves trees onto the data directory. |
| DraStic | `/storage/.config/drastic/drastic.cfg` | `Saves/NDS/backup`, `Saves/NDS/savestates` | `start_drastic.sh` keeps the cfg on the OS card and bind-mounts the slot directories. |
| AetherSX2 | `/storage/.config/aethersx2/inis` | `Saves/PS2`, `/storage/Bios/PS2`, `/storage/.config/aethersx2/cache` | `start_aethersx2.sh` points MemoryCards and Savestates at `Saves/PS2` and BIOS at `Bios/PS2`. Cache is not a settings file and is left in place. |
| GZDoom | `/storage/.config/nextui/shared/configs/gzdoom/gzdoom.ini` | `soundfonts/`, `fm_banks/`, `autoexec.cfg`, `Saves/DOOM`, `shared/saves/gzdoom` | `0001-Fix-file-paths.patch` and `DOOM.pak/launch.sh`. User soundfonts and FM banks are search paths, not generated settings. |
| Pico-8 | `Pico-8-native/config`, `Pico-8-native/sdl_controllers.txt` | `carts/`, `cdata/`, `bbs/`, `data/`, `splore-installed` | `start_pico8.sh` uses `-home` on `Pico-8-native`, sets `XDG_CONFIG_HOME` to `config/`, and copies the controller db to `sdl_controllers.txt`. |
| Wine | none | `wine-prefix.ext4`, `/storage/.config/nextui/<platform>/wine` | `zlyme-wine-prefix` stores installed Windows software in the 1 GiB ext4 image. Nothing in the current launcher owns the `wine/` directory, so it is left untouched. The reset does not call `zlyme-wine-prefix cleanup`. |

```text
PHASE 9D GAME CLEANUP SAFETY = COMPLETE
STANDALONE USER DATA = PRESERVED
DRY-RUN BEFORE DELETE = PASS
ORPHAN MATCHING = INDEXED
```

## Group 2 — Settings and UI

| Work | Disposition | Notes |
| --- | --- | --- |
| Quick Menu order | COMPLETE | `getQuickToggles()` is Settings, Wi-Fi, Bluetooth, Pak Store if present, Sleep, Reboot, Poweroff. Missing capabilities are still omitted. Pak Store was not added. |
| Keyboard L1 DELETE pill | COMPLETE | `KeyboardPrompt` still deletes on L1. The hint row is `L1 DELETE` on the left and `B BACK` / `X ENTER` on the right. |
| Shorter destructive Game-settings text | COMPLETE | Game cleanup rows name the real action. "Reset standalone settings" says games and saves are kept because the reset list is settings files only. |
| One pending-reboot prompt | COMPLETE | `zlyme-bootcfg` snapshots `gpu`, `undervolt`, `otg`, `hdmi`, and `sd2` when Settings opens. On a clean exit it compares the normalized values. HDMI off then on does not prompt. Restart writes `/tmp/reboot` and exits. `nextui-session` calls `zlyme-halt reboot`. Later leaves the saved values in place. ZRAM, logs, timezone, Wi-Fi country, LED, network services, and rumble are not in the snapshot. `ab_swap` was removed from this snapshot in Phase 9K. |
| PortMaster and VTree dark themes | COMPLETE | PortMaster theme is already the dark Zlyme baseline (`#050608` / `#F2F3F5` / `#FA7C08` / `#EC2A01`). `portmaster-launch` sets that theme once and does not replace a later user theme. VTree seeds the Zlyme theme on first run and then keeps the user's choice. |
| Emulator and governor selectors as pills | COMPLETE | The per-game screen still uses left/right to change Governor and Emulator, up/down to move, A save, B back, and X inherit. Rows are now selector pills. The stored preference format and launch path are unchanged. |
| Stop advertising CLTMP on my355 | COMPLETE | `PLAT_supportsColorTemperature()` is false on my355 and true on the shared fallback. The hint and the color-temp overlay are skipped here. `GetColortemp` stays for other platforms. |
| Global A/B swap | DROPPED in Phase 9K | The selectable setting, `zlyme-ab-map`, and the alternate capability map are gone. One built-in map remains: printed A (east, `BTN_EAST`) is virtual South and printed B (south, `BTN_SOUTH`) is virtual East. my355 raw `JOY_A` is 0 and `JOY_B` is 1 so NextUI agrees with that map. The generic Xbox line `a:b0,b:b1` is unchanged. |
| Advanced System submenu | COMPLETE | System keeps ordinary preferences, Time zone, Joysticks, Storage, and Backup. Advanced holds GPU, CPU undervolt, ZRAM, USB OTG, HDMI, Second SD, System logs, Reset Settings, and Factory Reset. Per-menu Reset to defaults stays on the ordinary menus. |
| Factory Reset placement | COMPLETE | Both resets are buttons under Advanced. Neither runs on highlight. Each asks A RESET / B BACK. |
| Reset Settings vs Factory Reset | COMPLETE | See the reset ownership section below. `rm -rf /storage/.config/nextui` is gone. Settings does not call `reboot -f`. |
| VTree hidden files | COMPLETE | The stored key is `[General] ShowHidden`. `Settings_ShowHidden` is only a settings-screen label. A new config and the one-time migration use `ShowHidden=true`. A later user choice is kept. |
| Rumble default 30% to 40% | COMPLETE | `FF_DEFAULT_GAIN_PERCENT` is 40. Missing and invalid gain files use it. A saved 0–100 value is left alone. |
| CPU undervolt default to L1 | DEFER | Default in `zlyme-ctl` and `S15bootpart` is `undervolt=off`. L1/L2/L3 stay selectable and map to `rk3566-undervolt-cpu-*.dtbo`. L1 sets 800 mV on 408–1104 MHz, then 850/900/950/1000 mV at 1416/1608/1800/1992 MHz. The 1992 MHz base point added by the kernel patch is 1150 mV. Stock voltages for the lower OPPs live in upstream `rk3566.dtsi` and were not copied into this repository. Silicon-dependent. Do not change the default without that side-by-side, failure reports, and an explicit decision. |

### Reset ownership

Reset Settings deletes only these files when they are regular files:

```text
/storage/.config/zlyme/wifi
/storage/.config/zlyme/bluetooth
/storage/.config/zlyme/ssh
/storage/.config/zlyme/samba
/storage/.config/zlyme/syncthing
/storage/.config/zlyme/gpu
/storage/.config/zlyme/display_mode
/storage/.config/zlyme/refresh
/storage/.config/zlyme/undervolt
/storage/.config/zlyme/led
/storage/.config/zlyme/otg
/storage/.config/zlyme/hdmi
/storage/.config/zlyme/sd2
/storage/.config/zlyme/boost
/storage/.config/zlyme/zram
/storage/.config/zlyme/merge
/storage/.config/zlyme/logs
/storage/.config/zlyme/update_channel
/storage/.config/zlyme/cpu_gov
/storage/.config/zlyme/gpu_gov
/storage/.config/nextui/shared/minuisettings.txt
/storage/.config/nextui/shared/localtime
/storage/.config/nextui/shared/localtime.zone
/storage/.config/nextui/shared/vtree/config.ini
/storage/.config/nextui/shared/vtree/.zlyme-vtree-v1
```

It then seeds a UTC zone file when `zlyme-timezone` is available and recreates `minuisettings.txt` through `zlyme-card-defaults`, the same helper `nextui-session` uses. Immediate defaults are applied by the existing owners: Wi-Fi, Bluetooth, SSH, Samba, and Syncthing init scripts, plus `zlyme-ctl` for LED, ZRAM, refresh, HDMI mode, logs, merge, and the governor profile. GPU, undervolt, OTG, HDMI, and second SD stay reboot-required; the overlay line is rewritten and the pending-reboot prompt covers them. `boost`, `cpu_gov`, `gpu_gov`, and `update_channel` are persistence only. A missing flag falls back to the existing `zlyme-ctl` default. CPU undervolt's default remains off.

Reset Settings preserves ROMs, BIOS, saves, cheats, Wi-Fi credentials (`wpa_supplicant.conf`), Bluetooth pairings (`bluetooth.tar`), SSH host keys under `/storage/.config/ssh`, joystick calibration and rumble, standalone emulator configs and saves, Pico-8 carts and cdata, PortMaster ports and config, the Wine prefix, user-installed PAKs, stock PAKs, and logs.

Factory Reset does that same settings reset, then creates `/storage/.config/zlyme/factory-reset`. The next session start overwrites stock Tools and Emus names from the image and leaves extra PAKs. It does not delete personal content. Settings asks for a restart through `/tmp/reboot` after that flag is written. The reset command itself does not reboot.

## Group 3 — storage, library, launch

| Work | Disposition | Notes |
| --- | --- | --- |
| PortMaster install disk | COMPLETE | Pinned PortMaster `2026.05.04-1202` reads `HM_TOOLS_DIR`, `HM_PORTS_DIR`, and `HM_SCRIPTS_DIR` when they are already set. Zlyme persists the library root and exports those three. Default is `/storage`. Changing it does not move files. A missing explicit disk refuses to start PortMaster. Runtime `libs` is `/run/portmaster/libs`, pointed at the selected root at launch. |
| Format secondary media | COMPLETE | `zlyme-storage-format` accepts only the removable names `zlyme-storage` already scans. It rejects `mmcblk0`, the disks behind `/`, `/boot`, and `/storage`, and labels `ZLYME` and `ZLYMEBOOT`. Filesystems are exFAT and ext4. A failed normal unmount aborts before mkfs. No lazy unmount and no repartitioning. The label default is `ZLYME-LIB`. |
| Overlays PAK content-directory overrides | COMPLETE | The PAK no longer writes both `/Overlays/<TAG>` and `/Overlays/<res>/<TAG>`. It stores the asset on the chosen library and records the absolute content directory in `content-overlays.tsv`. `ra-run` appends that cfg. The same folder name on another card is a different key. `write-cfg` replaces only `input_overlay` and `input_overlay_enable`. |
| PICO-8 / Splore | SUPERSEDED for BIOS scope by Phase 9K | Runtime discovery is unchanged and now shared: both `pico8_64` and `pico8.dat`, ROM-library BIOS first, then every active library. The synthetic Splore row exists only while that pair is present, in that library's Pico-8 folder. Downloaded carts were proven on the live Flip at `/storage/.config/nextui/shared/Pico-8-native/bbs/carts/` (`marepike-0.p8.png` is Last Bullet). NextUI lists that directory. It does not copy the carts. |
| Per-ROM delete | UPDATED in Phase 9K | MENU+Y on a ROM has a Delete game row. Confirmation runs `zlyme-game-cleanup rom` as argv, then `rom-apply` on that exact plan. Saves are taken only from the library the save resolver would select. `.cue` / `.m3u` / `.gdi` do not pull in referenced files. A Splore dummy delete also clears its marker so the helper can recreate it. |
| Splash vs `quiet` | DROPPED as a mode switch | Product boot is always the graphical splash, including update progress. The command line is `quiet console=ttyS2`. The `tty1` text console was removed after it left stray characters on the panel. |

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

## Phase 9L — launch and format stabilization

The Phase 9K BIOS view rebuilt every BIOS symlink in the shell on every launch, and `ra-run` did it again. On a card with thousands of BIOS files that never reached the emulator. One resolution is cached per winning library. A second launch for the same card does not walk Bios again, and switching to another card reuses that card's view. Saves are matched by filename, not a full tree walk.

On the installed 9L image, 4272 BIOS files took 1.519s to build and 0.059s from the same-card cache. Switching cards rebuilt (1.756s and 1.441s). That rebuild is what the per-card cache removes. GBC/Gambatte started, ran 11 seconds, saved, and returned. PPSSPP booted an ISO; the first exit aborted inside PPSSPP while creating a Vulkan window, and the second exit returned. MENU+Y, the format confirmation, and the quick Settings smoke were not done on that image. No card was formatted.

The MENU+Y screen shows the governor policy from `zlyme-governor --policy` (Auto, or Heavy/Play when that is the real fallback) and the emulator id from `emu-defaults.txt`. X clears the stored override and leaves the effective values on screen.

Format removable storage passed `--confirm-text` without `--confirm-show`, so A did nothing on the last step. The confirm button is shown. A tmpfs status file records the stage. No card was formatted from this session.

## Phase 9K — live corrections and multi-library BIOS/saves

The previous rule "BIOS and saves follow the ROM library, with a main-card BIOS fallback" is superseded.

BIOS: each launch builds one runtime view of every mounted library's `Bios` tree. The ROM library is applied last, so a duplicate relative path comes from the game card. Card files are not copied. If the library registry is missing, only `/storage` is used.

Saves: one writable library per launch. Exact save files for that ROM win over unrelated files in the same system folder. The ROM library wins when it is one of the matches. An empty `Saves/<tag>` does not count. If nothing exists, the new directory is on the ROM library. Nothing is copied between cards.

| Launcher write under BIOS_PATH | Class | Where it lives now |
| --- | --- | --- |
| PAK `mkdir` of `BIOS_PATH/<tag>` | mkdir only | runtime view |
| `ra-run` fbneo, neocd, tos, colecovision links | temporary alias | runtime view, rebuilt each launch |
| ST `tos.img`, Coleco `colecovision.rom`, MSX Machines/Databases | temporary alias | runtime view |
| Flycast BIOS links | temporary alias into the save dir | selected `Saves/DC` |
| RetroArch save RAM / states | persistent | selected `Saves/<tag>` via `savefile_directory` |
| PPSSPP, DraStic, Flycast, Dolphin, AetherSX2, GZDoom, OpenBOR, ScummVM | persistent saves | selected `SAVES_PATH` (system directory, not a ROM-name match) |
| Native PICO-8 | no BIOS write | runtime pair stays on its card |
| Wine, PortMaster | not conventional saves | application prefix / port tree, not the save resolver |

A/B swap user setting: dropped. Wi-Fi Country row: kept across scan rebuilds. Clock default: on, once, via `zlyme-card-defaults` marker `.zlyme-clock-on-default`. Volume overlay: no Y EDIT. MENU+Y: releasing MENU does not close Edit Preferences. Splore dummy: only while `Bios/PICO/pico8_64` and `pico8.dat` exist. Splore download location, proven on the live Flip: `/storage/.config/nextui/shared/Pico-8-native/bbs/carts/marepike-0.p8.png` (title Last Bullet, from `temp-marepike.nfo`).

## Live acceptance

Confirmed on `zlyme-my355-20261001-b9f8947780ec.tar`: PPSSPP OpenGL and Vulkan, a real format of a disposable card, the offline clock after a network sync, Splore and downloaded BBS carts, Splore sorting first, the PortMaster GUI, the quiet graphical boot, game/Settings/PAK handoff, and MENU+Y without the old list layer.

Ruffle, the Music Player, and Cheat Downloader were deferred here. The maintainer later made those three pre-release gates. Pak Store stays deferred. See the pre-release source pass below.

## Phase 9 architecture audit

| Subsystem | Owner | Classification | Why |
| --- | --- | --- | --- |
| gpSP pin and Spruce floors | `zlyme-governor` | KEEP | One policy command. NextUI asks `--policy` instead of copying the table. |
| Incremental OTA | update scripts | KEEP | Hash and base checks are the safety, not leftover complexity. |
| Game cleanup | `zlyme-game-cleanup` | KEEP | Dry-run, then one plan. Per-ROM delete uses the save resolver. |
| Bounded logs | `pak-log.sh` / `zlyme-logs` | KEEP | Fixed generations. Format status is one tmpfs line, copied into the Settings log only when logging is already on. |
| Wi-Fi country | `zlyme-wifi` plus the settings row | KEEP | The row is static across scans. |
| Time zone | `zlyme-timezone` | KEEP | `/etc/localtime` is the one path. RTC stays UTC. |
| Reset / Advanced | `zlyme-reset`, `zlyme-bootcfg` | KEEP | Explicit file list. `ab_swap` has no consumer. |
| A/B swap setting | removed | REMOVE | One built-in map. `JOY_A`/`JOY_B` live in the my355 platform header that NextUI, minui-list, and minui-presenter all compile. |
| Multi-library BIOS | `zlyme-library.sh` + `bios-union.py` | KEEP | Callers see one `BIOS_PATH`. Precedence and the per-card cache stay behind that. The shell `find` loop was the wrong implementation and is gone. |
| Multi-library saves | `zlyme_save_root` | KEEP | One writable root. Exact name, then any file in `Saves/<tag>`, ROM card wins, no copy. |
| Synthetic Splore | `zlyme-storage` calls `zlyme-pico-splore` | KEEP, BUT CHANGE OWNERSHIP | A dummy ROM is still the smallest catalog entry NextUI already lists. A virtual menu action would be a second catalog. The file is `000) Splore.p8` on the library that holds `pico8_64` + `pico8.dat`, so NextUI's existing sort prefix puts it first and the label is still Splore. Downloaded carts stay in `bbs/carts` and open `PICO.pak`; they are not copied into Roms. Live evidence: the pair was only on `/mnt/sd2` and the `/storage` dummy was absent, so the row the user browses never contained it. PICO `.p8.png` carts are allowed by that console's extension list; the generic junk suffix does not override the whitelist. |
| PortMaster | `control.txt`, `mod_Zlyme.txt`, `PORTS.pak` | KEEP, identity forced after `device_info.txt` | Upstream `device_info.txt` was leaving `CFW_NAME=Unknown`, so `mod_Zlyme.txt` never loaded. DRM is released before the port, same as RetroArch. No per-game script patches. |
| Weston | `zlyme-weston-run` | KEEP | Temporary, one client. The test PAK is gone. It owns `SDL_VIDEODRIVER=wayland` for clients that actually need a Wayland socket. PPSSPP does not use it. |
| PPSSPP Vulkan | `PPSSPPSDL` on KMSDRM | KEEP, LIVE PASS | `VK_KHR_display` from an SDL KMSDRM window. No Wayland and no Weston. OpenGL is the same direct exec. The maintainer launched a game with Vulkan on `e70ddec`. |
| Formatting | backend `zlyme-storage-format`; UI is Settings | KEEP, LIVE PASS | The nested minui UI was removed. Settings calls the backend with `execl`. The maintainer formatted a disposable card. The OS disk checks are unchanged. |
| quiet / console | extlinux, initramfs, `S12splash` | DROPPED | `console=tty1` and the `rcS` copy onto the LCD left stray text during splash and app handoff. The splash owns the panel again. Serial remains `ttyS2`. |
| MENU+Y editor | NextUI `SCREEN_EDITPREFS` | KEEP | Opaque `THEME_COLOR7`, then the same dark theme pill and `THEME_COLOR5_255` as a selected game row. Delete has no inline A. Bottom hints are B/X/A on a setting row and B/A on Delete. MENU release is not Back. |
| RTC | `S49ntp`, `PLAT_setDateTime` | KEEP, LIVE PASS | Both writers use `hwclock -u -w`. After one network sync the maintainer rebooted with Wi-Fi off and the local clock stayed correct. |

## Live acceptance of 8e8116f

Confirmed on `zlyme-my355-20261001-8e8116f00969.tar`, product file still `zlyme43`:

- MENU+Y title position
- System order: Display, then Joysticks, Storage, Advanced
- Time zone immediately under Show 24h time format
- Default view under Appearance
- About → Version shows `zlyme43`

Those rows were not reworked in the pre-release source pass.

## Pre-release source pass

This is not the version-bump gate. Hardware smoke of the new OTA is still outstanding. Do not treat the items below as live-accepted.

### Splore names and art

`zlyme-pico-bbs` owns the catalog. It runs from `zlyme-pico-splore` and after `PICO.pak` returns. It does not run while NextUI draws.

PICO-8's sidecar is real. The live capture of `marepike-0.p8.png` stored `title:Last Bullet` in `temp-marepike.nfo`. The old list matcher required `lid:` to equal the whole filename stem (`marepike-0`), so the title was ignored and the row stayed a slug. The indexer matches `lid:` or the `.nfo` name (`temp-` stripped) to the stem or the stem with a trailing `-<digits>` removed.

If no `.nfo` title matches, `pico8-data-extractor` 0.1.0 (MIT, static AArch64, Buildroot `host-go`) reads the first Lua comment. A cart that yields neither keeps its stem. `temp-*` files are not rows. Layout is `bbs/carts/` plus one numeric directory under `bbs` (`bbs/1/…`), which is the shard pico-8 and minui-pico-8-pak 0.8.5 both describe. Nothing deeper is scanned.

Rows go to each Pico-8 folder's existing `map.txt` (`filename<TAB>title`). `.zlyme-bbs-map` records the keys this tool owns so a removed or renamed cart drops its generated alias and other rows stay. Carts are not copied into `Roms`, `.media`, or `.res`.

Artwork stays the NextUI thumbnail path. `.media` next to the cart wins. Otherwise a finished `.p8.png` under `Pico-8-native/bbs/` is the image. `Show game art` off still skips the thumbnail. A PNG outside that BBS tree is not treated as a cart label.

ROCKNIX's current `next` tree was not found to contain a BBS filename parser. The title source here is the `.nfo` plus the cart's own comment, then `map.txt`.

The Flip was not reachable for a fresh `.nfo` read this pass. The mapping above uses the earlier live capture.

### Apostrophe, Update, and Joysticks

`nextui-session` still sources `pak-input.sh` for every pak except Settings. That exposes only the InputPlumber Xbox 360 target. Apostrophe's my355 path now opens that pad with SDL GameController. The standard A/B/X/Y/dpad/L1/R1/Start/Select/Guide map is the one that runs. The raw fallback is Xbox order (A=0, B=1), not the old physical Flip indices. TrimUI maps are unchanged. Settings still does not source `pak-input.sh`, so joystick calibration still sees the physical pad.

`ap_set_cpu_speed()` returns immediately on my355. The rebuilt Moonlight and ScrapeGoat binaries are compiled with `AP_CPU_SPEED_DEFAULT` and `-DPLATFORM_MY355`, and the `scaling_setspeed` string is not in those binaries. ScreenScraper developer credentials in the ScrapeGoat rebuild are the same strings that were already in the previous binary.

The old `Update.pak` is still deleted by `nextui-session` and is not in the image seed. Update remains a Settings row. The standalone joystick/calibration pak is not shipped. Calibration stays inside Settings. Neither was resurrected.

Other shipped Tools: Files, Artwork Scraper, Overlays, and PortMaster do not link Apostrophe. Music Player and Cheat Downloader are not Apostrophe apps. They inherit `pak-input.sh` from the session. Ruffle selects its existing NextUI display path (`RUFFLE_CFW_NAME=nextui`) and the same controller database. No Moonlight-only or ScrapeGoat-only button swap was added.

### New packages

| App | Pin | License | Integration |
| --- | --- | --- | --- |
| Ruffle Handheld | release v4.2, commit `d6e6e4527e97e6d25ba034de29754086a3eb5a9b` | MIT, bundled Ruffle MIT OR Apache-2.0 | Appliance under `/usr/share/zlyme/rufflehandheld`. `FLASH.pak` launches it. `RUFFLE_PERFORMANCE=0` so it does not write CPU, GPU, or DMC governors. `setup.sh` and `core-install.sh` are not installed. No SWF is shipped. Per-game data is `$library/Saves/FLASH/flash_data`. Logs are `/storage/.config/ruffle`. Direct NextUI path, not Weston. |
| Music Player | release v1.17.0, commit `a77cdf69cd19e3313dc2b906e19b5be34715375a` | MIT, plus Fraunhofer FDK AAC | Binary on the squashfs. Launch script does not write cpufreq and forces `auto_update=0`. The restart flag is ignored. Application state is `/storage/.config/music-player`. Music is `/storage/Music`. Podcasts are `/storage/Podcasts`. Optional YouTube helpers, if the user installs them, are `/storage/.config/music-player/helpers`. No audio files are shipped. |
| Cheat Downloader | release v1.6.0, commit `4e673432cb3e92c8a34907cf5740aafacbbc3f47` | MIT | Experimental. AArch64 `cheat_manager` from the my355 zip (`bin/arm` is still AArch64). `minui-list` and `minui-presenter` come from `/usr/bin`. ROM folders on every library are symlinked in `/tmp` for the run; files are not copied. A duplicate filename follows the later library. Cheats install to `CHEATS_PATH` (`/storage/Cheats`). The Libretro database is only downloaded when the pak runs, into `/storage/.config/cheat-downloader`. Presenter timeouts are the upstream values. MENU+START leaves the tool. |

`pico8-data-extractor` 0.1.0 is a Buildroot package (`host-go`, `CGO_ENABLED=0`, `GOARCH=arm64`).

Stock Tools and Emus are still the image glob. No new boot service and no first-frame work were added for these apps.

### Live acceptance of e93a85f

Confirmed on the installed `e93a85f` image:

- downloaded Splore titles and artwork, with no visible `temp-*` rows, and a downloaded cart launch
- Moonlight and ScrapeGoat: printed A confirms, printed B goes back
- RetroArch, PPSSPP Vulkan, Settings open/return, and quiet transitions

Ruffle was not visible. The card directory is `Flash (FLASH)` and the SWF is there. The image shipped `RUFFLE.pak`, `RUFFLE: swf`, and `Flash (RUFFLE)`. NextUI hides a ROM folder when `hasEmu()` cannot find `TAG.pak`. `.swf` is not on the junk list, so the missing pak is what hid the folder. The tag and the extension line were also the wrong name.

Music Player exited 127. The log is `libmali.so.1: cannot open shared object file`. The v1.17.0 my355 binary was linked in a toolchain whose GLES dependency is vendor libmali. That library is at `/usr/lib/mali/libmali.so.1` and is not on the default loader path. The GPU file is `libmali`. A Panfrost boot would fail the same `DT_NEEDED` even if the path were added.

Cheat Downloader stayed up until MENU+START. Its pak log is only the launch header. `textui debug offline` on the device walks `FIND_LOCAL_DB` → `CHECK_UPDATE` → `INIT_DB` and exits with "No cheat database". GitHub's release redirect answers in a few seconds when curl has a timeout. The graphical path starts `minui-presenter` with `--timeout -1` or `0`, which waits until a button, and the binary does not log unless `debug` is passed. Its curl invocations have no connect or total timeout.

`mmcblk0p3` is `/storage` (exFAT, rw). The exFAT "not properly unmounted" line is from this boot, at about 3 seconds. `zlyme-halt` already `sync`s and unmounts `/storage` without a lazy unmount before poweroff. No repair was run.

Create game folders is a Phase 9 settings action. It only adds missing directories on a library listed in `/run/zlyme/libraries`.

## Still not hardware-accepted

Ruffle still needs a runtime launch on the Flip and a visual confirmation. Music Player and Cheat Downloader still need a launch on the corrected image. Create game folders still needs a settings pass. The exFAT warning still needs a maintainer filesystem check when the card can be unmounted. PPSSPP Vulkan, formatting, the clock, PortMaster, quiet boot, and the 8e8116f Settings rows stay closed.

## Group 5 — release

| Work | Disposition | Notes |
| --- | --- | --- |
| Weston test PAK | REMOVED from the image in Phase 9L | `Tools/Weston.pak` only launched `zlyme-weston-test`. That Tools entry and the helper are gone. Weston itself stays for PortMaster and Wine. |
| CI log volume | KEEP | Short log on the Actions console, full log as an artifact, so the job is not truncated. |
| README | INVARIANT, plus a final gate | Per shipped feature, and one reconciliation against non-prerelease `zlyme40 (2026-09-23)` before the version bump. See the README release gate above. |
| Community / Contributing | KEEP | Invite other RK3566 ports and point at Discord. |
| Dead file audit | KEEP, last | After features stop moving. Grep-clean is not proof. |

End of the pre-release source notes. The section below supersedes "Still not hardware-accepted" for the items the maintainer has since passed.

## Live acceptance of f6f1b2d

The maintainer installed `zlyme-my355-20261001-f6f1b2d7944c.tar` and accepted:

- Splore downloaded-cart names, artwork, and cart launch, with no `temp-*` rows
- Moonlight and ScrapeGoat printed A/B
- Ruffle: `Flash (FLASH)` is listed, `/storage/Roms/Flash (FLASH)/Mario ATV.swf` launches and renders, MENU+START returns to NextUI
- Music Player opens, plays online radio, and returns to NextUI
- Settings → Game → Create game folders on SD card 1, with existing ROMs kept
- RetroArch, PPSSPP Vulkan, Settings open/return, and quiet transitions

The exFAT dirty-unmount line is closed for Phase 9. `/storage` is exFAT. `zlyme-halt` already syncs and unmounts it with a normal `umount` before `reboot -f` or `poweroff -f`. `fsck` is an offline maintenance operation. Shutdown code was not changed for it.

## Corrective persistence pass

Canonical state, also in `docs/ARCHITECTURE.md` and `docs/OPERATIONS.md`:

- OS and application configuration: `/storage/.config` (`zlyme`, `syncthing`, `<application>`)
- ROMs, saves, BIOS: the library's `Roms`, `Saves`, and `Bios`
- user media: `/storage/Music`, `/storage/Podcasts`, and the Cheats content path
- transient data: `/run` or `/tmp`
- optional logs: `/storage/.logs`
- Samba enable state: `/storage/.config/zlyme`. Samba's private database stays `/tmp/samba-lib` because exFAT cannot store the mode bits.

Ruffle's emulator is unchanged. `RUFFLE_ROM_ROOT` stays the library, and the launch passes that same directory as `--rom-root`, which is the path accepted on `f6f1b2d`. `RUFFLE_FLASH_DIR` is the directory that already contains the SWF (`dirname` of the ROM). Companion data is `RUFFLE_DATA_DIR=$library/Saves/FLASH/flash_data`. A legacy `$library/flash_data` directory and the old `$library/.config/zlyme/ruffle/data` tree are migrated once. The old `$library/.config/zlyme/ruffle/flash` directory is left in place: it is not ROM content and it is not the save tree. Application logs are `/storage/.config/ruffle`. `RUFFLE_PERFORMANCE=0` stays.

Music Player state is `/storage/.config/music-player`. The player is patched so it does not use NextUI's shared userdata macro. Legacy `.userdata/shared/music-player` and `.config/nextui/shared/music-player` are migrated once. The launch script does not create `.userdata`.

The YouTube helper's `Failed to check GitHub` was reproduced on the installed pak. The player runs `curl --cacert ./res/cacert.pem` from the pak directory. That file is not installed. The same request with `/etc/ssl/certs/ca-certificates.crt` returned HTTP 200. The patch uses that system bundle. User-installed `yt-dlp`, `qjs`, and `ffmpeg` go under `/storage/.config/music-player/helpers/`. Application self-update stays off. The in-player check has not been repeated on the Flip; that waits for the image that contains the patched binary.

Cheat Downloader stays experimental. On the installed image, `minui-presenter` under `SDL_VIDEODRIVER=dummy` opens both gamepads and exits on its timeout, so the presenter binary itself starts. The graphical failure was not reproduced while NextUI held the panel. The launcher no longer treats the optional pak log as a presenter handshake. The presenter wrapper touches `/tmp/zlyme-cheat-presenter.<pid>` immediately before exec, and the launcher removes that file on exit. Upstream `--timeout -1` and `--timeout 0` are passed through. Curl still bounds the update check and the database transfer separately. Cache and database metadata are `/storage/.config/cheat-downloader`. Installed `.cht` files stay on the Cheats content path. The database is not in the image. MENU+START remains the escape.

GZDoom config follows upstream `$HOME/.config/gzdoom` with `HOME=/storage`. The path patch no longer hardcodes `/mnt/SDCARD` or `.userdata`. It keeps `/usr/share/gzdoom` for the immutable resources and points the node cache at `$HOME/.config/gzdoom/cache`. Game saves stay `$SAVES_PATH/DOOM` via `-savedir`. Legacy config trees are migrated once.

`/tmp/zlyme-session-handoff` was only a launch test. NextUI `c82b4a63` removes the poll. Nothing else reads that file.

Ruffle, Music Player, and Cheat Downloader do not write cpufreq, do not start a daemon, and do not run at boot. Music Player application update stays disabled. Ruffle's installer is not shipped. Cheat Downloader downloads only the user database.

A blank card in the second SD slot is SD card 2. `zlyme-storage` classifies that slot by the `sdmmc1` controller (`mmc@fe2c0000` in the Flip DTB; alias `mmc1`; regulator `vcc_sd2`). The boot slot is `mmc@fe2b0000`. USB mass storage stays `/mnt/media/<label>`. Whether the volume already contains `Roms` is not the slot identity. Settings already labels `/mnt/sd2` as SD card 2 and `/mnt/media/<label>` as `USB: <label>`.

## Live acceptance of 1cd9c94

The maintainer installed `zlyme-my355-20261001-1cd9c9411b03.tar` and accepted:

- Ruffle launches `Mario ATV.swf`, renders, and MENU+START returns. The save is `$library/Saves/FLASH/flash_data/.../MarioATVGE.sol`
- Music Player radio, YouTube helper installation, `/storage/.config/music-player`, and podcast download
- Physical SD2 identification, formatting, and Create game folders on SD2
- GZDoom launches and uses `/storage/.config/gzdoom`

Still open on that image: `/storage/flash_data` was recreated beside the real save, song download failed, Cheat Downloader stayed black until MENU+START, GZDoom buttons did not operate the menus, and an empty-looking Flash system could appear. Create game folders moves to Settings → System → Storage after this pass. Pre-release path migrations are removed.

```text
RUFFLE LAUNCH = MAINTAINER ACCEPTED on 1cd9c94
RUFFLE flash_data CREATOR = runtime/save-storage.sh via RUFFLE_ROM_ROOT; PATCHED TO RUFFLE_DATA_DIR
MUSIC RADIO AND HELPERS = MAINTAINER ACCEPTED on 1cd9c94
MUSIC SONG DOWNLOAD = M4A PREFERRED, FFMPEG FALLBACK
CHEAT DOWNLOADER = EXPERIMENTAL; SHALLOW ROM VIEW; NIM FOLLOWS DIRECTORY SYMLINKS
GZDOOM MENU = UPSTREAM KEY_JOY1/KEY_JOY2 RESTORED; menu_confirm CVAR REMOVED
SD2 = MAINTAINER ACCEPTED on 1cd9c94
CREATE GAME FOLDERS = Settings → System → Storage
GZDOOM = LAUNCH ACCEPTED ON 1cd9c94; BUTTON EVENTS NOT YET DISTINGUISHED FROM POLLING
PHASE 9 RELEASE = NOT COMPLETE
```

## Live acceptance of f0143dd

The maintainer installed `zlyme-my355-20261001-f0143dd5b067.tar` (`f0143dd5b067b04fa808b706973a6632c04ebd1b`) and accepted:

- GZDoom: A confirms, B goes back, both sticks, L1/R1, L2/R2, Start, save creation, three launch/exit cycles with no reproduced NextUI crash, and MENU+START
- Cheat Downloader: the UI appears promptly, navigation and systems/cards work, and MENU+START works
- Music Player: an online song download works, the downloaded song plays, and radio works
- Ruffle: an SWF launches, the companion save follows the ROM library under `Saves/FLASH`, `/storage/flash_data` is not recreated, and MENU+START works
- ROM-driven system visibility: an empty Flash folder stays hidden, and Flash appears when another library has a valid SWF
- Settings: Create game folders is under System → Storage and the action works

That Cheat Downloader pass is evidence for `f0143dd` only. Product policy then changed. Cheat Downloader does not stay on the next image.

## Closure decisions, 2026-10-02

This section is the current product. It supersedes earlier notes that still list Artwork Scraper, Cheat Downloader, or a patched ScrapeGoat package as what the image ships. Those earlier sections stay as the record of intermediate images. Dated hardware results below stay history.

- Artwork Scraper is removed. ZcrapeGoat owns ScreenScraper artwork, metadata, and manuals.
- Cheat Downloader is removed. ZcrapeGoat owns Libretro cheat discovery and install.
- `BR2_PACKAGE_ZCRAPEGOAT` builds `package/system/zcrapegoat/src/`. That tree is a pristine `Helaas/nextui-scrapegoat-pak` v2.3.0 import at `c52f749eae21a4c02c767e485fef2abbb773f2d7`, followed by normal Zlyme commits. There is no ScrapeGoat patch stack.
- The tool is `Tools/ZcrapeGoat.pak`. The binary is `/usr/lib/zlyme/zcrapegoat/zcrapegoat`.
- Private state is `/storage/.config/ZcrapeGoat`. Nothing migrates `/storage/.config/ScrapeGoat` or `.userdata/shared/ScrapeGoat`, and the app does not create those old trees.
- Libraries are the lines in `/run/zlyme/libraries`. Artwork is written beside the actual ROM, under `.media`. Installed cheats stay at `/storage/Cheats` and do not follow the ROM card.
- ScreenScraper developer credentials are private build inputs. Local builds read the ignored file `package/system/zcrapegoat/credentials.local`. The GitHub Actions build reads the secrets `SCREENSCRAPER_DEV_ID` and `SCREENSCRAPER_DEV_PASSWORD`. The credential-bearing compile sets `CCACHE_DISABLE=1`.
- PortMaster keeps upstream `default_theme` and the `Zlyme` scheme derived from Darkest Mode. Selected text is `#FC9C14`, unselectable text is `#FA7C08`, and the selection fill is `#8A3E06`. The earlier `#FFD7B0` selected color is not the current scheme. A stored standalone `Zlyme` theme converts once. A later user choice is kept. `themes/Zlyme` is not installed.
- After a successful OTA, exact stale stock paths removed from the OS card are `Tools/my355/Weston.pak`, `Tools/my355/Artwork Scraper.pak`, `Tools/my355/Cheat Downloader.pak`, and `Tools/my355/ScrapeGoat.pak`. Weston and `zlyme-weston-run` stay. User artwork, cheats, and existing config directories are not deleted.
- The dead-file audit runs after those product changes, and only for files Phase 9 made obsolete.
- The product version is `zlyme44`, a new baseline. Do not attach a date to `ZLYME_VERSION`. Artifact filenames and the displayed build date are generated when the image is built. This baseline publishes a full OTA and a manifest with zero deltas. It does not download or generate deltas. Later `zlyme44.1` and `zlyme44.2` may publish same-major deltas. `zlyme45` is the next full baseline. A delta applies only when `from_sha256` matches the installed squashfs. Local validation does not wipe the Buildroot output tree. Refresh the packages whose inputs changed, then build one incremental image. GitHub Actions is not dispatched in this pass.
- After the maintainer accepts that local image, `phase-9-product` may fast-forward into `main`. The maintainer may then dispatch the GitHub clean build from that exact SHA. Phase 9 implementation closure does not wait for the runner. The remote build remains the reproducibility and release-artifact gate. A failure there still requires a correction before a stable release is valid.
- Phase 10 is documentation and maintainability only. It may start on `main` after the merge and the remote dispatch. Zlyme documentation in this repository comes first. The hardware-wiki agent runs afterward, using the Phase 9 implementation SHA as runtime evidence and the Phase 10 documentation SHA as wording guidance.
- Pak Store stays post-first-stable. The CPU undervolt default stays off. Community text for other RK3566 ports is not a Phase 9 release blocker.

Phase 9 is not complete. The next local image is not hardware-accepted until the maintainer installs it.

## Live result of 1f5dab

The maintainer installed `zlyme-my355-20261002-1f5dab487ee4.tar`. No other already accepted Phase 9 surface regressed. Stale Artwork Scraper, Cheat Downloader, and Weston test PAK cleanup was not reported as regressed. ScrapeGoat did not open. The launcher set `LOG_FILE` from the full binary path, which produced a `//` path whose parent directories did not exist, so the log redirect ended the script before the program started. PortMaster worked, and its Zlyme selected text `#FFD7B0` was too close to white. The next candidate corrects those two items. Previously accepted functions do not need the full matrix repeated. `1f5dab` is not the final accepted image.

## Live result of daebc6f

The maintainer installed `output/images/zlyme-my355-20261002-daebc6f5dbab.tar` (`daebc6f5dbabf1a2470cba416067b38176034c20`, SHA-256 `26aa0e1a643f0a6f0bcab9fb34b07c0495bbc4bd6ecac7342fbc81a124bd0a6c`).

Passed on that artifact:

- personal ScreenScraper credential prompt, and the prompt disappearing after username and password are saved
- `/storage` artwork written beside that ROM's `.media`
- SD2 artwork written beside the SD2 ROM's `.media`
- Libretro cheat install under `/storage/Cheats`
- state owned by `/storage/.config/ZcrapeGoat`
- no `/storage/.config/ScrapeGoat` and no `.userdata/shared/ScrapeGoat` created
- MENU+START returns to NextUI
- OTA removal of the old `ScrapeGoat.pak`, with only `ZcrapeGoat.pak` visible
- PortMaster Zlyme scheme, orange selection, persistence, and normal PAK handoff

Still open on that exact artifact:

- the logical system list was incomplete across libraries
- Settings → Manual download directory aborted ZcrapeGoat
- the About popup was too long
- a same-name ROM on two cards was not explicitly confirmed on hardware

The first two are code defects in that build. System emptiness was checked only on the representative first library, so an empty `/storage` folder hid a populated SD2 folder of the same name. The manual picker aborted because Apostrophe's POSIX `realpath` wrote into a 1024-byte buffer; glibc fortification expects `PATH_MAX` and aborted with `*** buffer overflow detected ***` (exit 134). PortMaster's accepted scheme, color, and persistence are unchanged. Phase 9 stays open until the next focused candidate is accepted. Duplicate same-name rows remain a host-covered data-model check unless a later hardware run shows otherwise.

## Live result of 93a6714

The maintainer installed `zlyme-my355-20261002-93a6714f658f.tar` (`93a6714f658f659f3cdebf31c2cff155f9b99846`).

Known from that run:

- ScreenScraper artwork works
- manual downloading works
- ZcrapeGoat cheats do not work

Cheats stop before the Libretro database clone. The log is `cheats: git binary not found: /usr/lib/zlyme/zcrapegoat/resources/bin/git`. The bundled `git` and `git-remote-https` are in the PAK, and the launcher already exports that directory as `GIT_EXEC_PATH`. This artifact looks beside the executable instead. No other focused check on this image was reported. PortMaster's earlier acceptance is unchanged. Phase 9 stays open.

## Live result of 4d4b110

The maintainer installed `zlyme-my355-20261003-4d4b110b32ea.tar` (`4d4b110b32ead08908504c687df4aaa9da3d4d5d`). `/boot/zlyme` is SHA-256 `8d9bcf918053f20702cb78164823aeb85d47672f3e5389028dbd77287fc3747a`, which is that image. The cheat log selected `/storage/Tools/my355/ZcrapeGoat.pak/resources/bin/git` and did not keep Git's fatal text.

On that device the PAK Git is the image copy (`5b3317865c045a3d357a3c582450c36fb2f45476a909103a144ebce5311afb28`), `git --version` is 2.53.0, and `--exec-path` is the PAK `resources/bin`. `git-remote-https` runs. The production checkout `/storage/.config/ZcrapeGoat/libretro-database` was absent. One `ls-remote` of the public Libretro database failed with `fatal: unable to access 'https://github.com/libretro/libretro-database.git/': Could not resolve host: github.com` while the link was unstable. After name resolution worked, the same `ls-remote` returned `HEAD`, and a clone with ZcrapeGoat's options into `libretro-database.debug` exited 0. That directory was removed. Phase 9 stays open.

## Current ZcrapeGoat build

An earlier draft of this record described `package/system/scrapegoat`, the patch `0001-zlyme-libraries.patch`, copied state from `.userdata/shared/ScrapeGoat`, and PortMaster selected text `#FFD7B0`. That draft is not the current build. `daebc6f` accepted the orange `#FC9C14` selection. The pale color remains only as the `1f5dab` hardware note above.

`BR2_PACKAGE_ZCRAPEGOAT` compiles `package/system/zcrapegoat/src/`. The import is pristine upstream v2.3.0 at `c52f749eae21a4c02c767e485fef2abbb773f2d7`. Zlyme changes after that import are normal commits. There is no ScrapeGoat patch stack. Apostrophe headers are the vendored copy, which keeps the my355 virtual-pad map and does not write cpufreq. The PAK is `Tools/ZcrapeGoat.pak`. The binary is `/usr/lib/zlyme/zcrapegoat/zcrapegoat`. Bundled `git` and `git-remote-https` stay in the PAK `resources/bin`. The launcher exports that directory as `GIT_EXEC_PATH`, and the cheat client uses it. There is not a second copy beside the executable.

ScreenScraper developer credentials are supplied privately at build time. A local build reads the ignored file `package/system/zcrapegoat/credentials.local`. The GitHub Actions build reads `SCREENSCRAPER_DEV_ID` and `SCREENSCRAPER_DEV_PASSWORD`. The credential-bearing compile sets `CCACHE_DISABLE=1`. The values are not committed and are not printed. A personal ScreenScraper account is still entered on the device and is separate from those developer credentials.

Libraries are the lines in `/run/zlyme/libraries` (`ZLYME_LIBRARIES_FILE` in tests). One system folder name is one logical row. A logical system is present when any physical copy has visible ROM content. ROMs are the union of those copies, and each ROM keeps its real path. Two files with the same display name stay separate; only the colliding rows add the library root. Artwork is `<ROM directory>/.media/<stem>.png`. Cheats go to `/storage/Cheats/<tag>/<stem>.cht`. Private state is `/storage/.config/ZcrapeGoat`. There is no migration from `/storage/.config/ScrapeGoat` or from `.userdata/shared/ScrapeGoat`, and those trees are not created.

PortMaster stays on upstream `default_theme`. The `Zlyme` scheme is Darkest Mode with `list_unselectable` set to `#FA7C08`, `list_selected` set to `#FC9C14`, and `selection-fill` set to `#8A3E06`. A stored theme named `Zlyme` becomes `default_theme` with the `Zlyme` scheme. Other stored themes and schemes are left alone. `themes/Zlyme` is not installed.

Artwork Scraper, Cheat Downloader, the Weston test PAK, and `ScrapeGoat.pak` are not in the image. After a successful OTA, `post-update.sh` removes `Tools/my355/Weston.pak`, `Tools/my355/Artwork Scraper.pak`, `Tools/my355/Cheat Downloader.pak`, and `Tools/my355/ScrapeGoat.pak` from the OS card.

```text
F0143DD = MAINTAINER ACCEPTED for the items listed above
ARTWORK SCRAPER = REMOVED; ZCRAPEGOAT OWNS ARTWORK
CHEAT DOWNLOADER = REMOVED AFTER f0143dd ACCEPTANCE; ZCRAPEGOAT OWNS CHEATS
PORTMASTER THEME = default_theme SCHEME Zlyme; SELECTED #FC9C14; CLONED themes/Zlyme REMOVED
PHASE 9 RELEASE = NOT COMPLETE; FOCUSED LOCAL IMAGE NOT YET ACCEPTED
```
