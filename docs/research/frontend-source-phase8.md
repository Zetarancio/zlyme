# Frontend source — Phase 8

Research only. No NextUI fork was created, no Buildroot recipe was switched off `SITE_METHOD=local`, and no shutdown code was changed.

Date: 2026-09-30. Branch `phase-8-nextui` at the start of this note: `baadc22b4be1e96c67e75ab94482a5f51f13d4c5`. `main` and `origin/main` were the same commit. Working tree was clean.

Evidence labels:

```text
PROVEN FROM SOURCE
PROVEN FROM UPSTREAM GIT
SUPPORTED BY UPSTREAM TOOLING
UNKNOWN
```

## Source revisions

| Source | Revision | What it is |
| --- | --- | --- |
| Zlyme | `baadc22b4be1e96c67e75ab94482a5f51f13d4c5` | Vendored NextUI under `package/system/nextui/src`. |
| LoveRetro/NextUI pin | `ae652648548edf6ab24cbb816cf4e4194e609fb3` | Recorded in `src/UPSTREAM` and as the prefix of `NEXTUI_VERSION`. License transition to PolyForm Noncommercial 1.0.0, 2026-08-15. |
| LoveRetro/NextUI HEAD | `a0628cdc0cee8e173a9bb94144f5c8baa22ab8e7` | Fetched `origin/main` on 2026-09-30. Subject: reduce address space pressure around dynarec JIT caches (#814), 2026-09-15. |
| minui-list | tag `0.15.2` | Current recipe: `josegonzalez/minui-list`, `SITE_METHOD=git`. Latest GitHub release seen: `0.15.4` (2026-09-27). Phase 8 vendors `0.15.2` first. |
| minui-presenter | tag `0.13.2` | Current recipe: `josegonzalez/minui-presenter`, `SITE_METHOD=git`. Latest GitHub release seen: `0.13.4` (2026-09-27). Phase 8 vendors `0.13.2` first. |

The pin checkout used for the file inventory lived outside the Zlyme tree at `/tmp/p8-research/pin`. It is not part of this repository.

## Current frontend architecture

PROVEN FROM SOURCE:

- `package/system/nextui/nextui.mk` vendors the tree (`NEXTUI_SITE_METHOD = local`, `NEXTUI_SITE` is `src/`). The header says the proven fork will become its own repository and Zlyme will fetch it.
- `NEXTUI_VERSION` is `ae652648548edf6ab24cbb816cf4e4194e609fb3-zlyme43`.
- License is PolyForm Noncommercial 1.0.0. `CREDITS` attributes LoveRetro/NextUI, Shaun Inman's MinUI, and the my355 hardware map started from `apommel/NextUI` `my355-latest`.
- `BR2_PACKAGE_NEXTUI_PLATFORM` is a hidden string in the top-level `Config.in`. Its default is `my355` when `BR2_ZLYME_DEVICE_MY355` is selected.
- `minui-list` and `minui-presenter` are fetched from upstream git. Neither recipe has a Zlyme patch directory or a local source tree. Their `CFLAGS` hard-code `-DPLATFORM=\"my355\"` and include `workspace/my355/platform` plus `workspace/my355/libmsettings`. Install paths also place copies under `bin/my355/`. That is the tree today. The Phase 8 decision is to vendor these snapshots locally; it is not a reason to keep fetching them.

## Zlyme delta against `ae652648`

PROVEN FROM UPSTREAM GIT. SHA-256 comparison of every file, ignoring `.git`:

| | files |
| --- | ---: |
| Pin tree | 819 |
| Vendored `src/` | 80 |
| Same path, different bytes | 26 |
| Only in the vendored tree | 14 |
| Only in the pin | 753 |

The 753 pin-only paths are the stock NextUI pieces Zlyme does not vendor: other device workspaces, MinArch, core patches, skeleton ROM/BIOS/overlay trees, and native toolchains. That is an exclusion, not a line-by-line edit. Do not treat it as a commit series that deletes upstream files inside the future fork. The fork should keep the upstream tree and let the Zlyme image build only `workspace/my355` plus the shared `workspace/all` code it actually compiles.

Changed files, added and removed lines versus the pin:

| File | `+` | `-` | Class |
| --- | ---: | ---: | --- |
| `LICENSE` | 4 | 0 | provenance |
| `workspace/all/common/api.c` | 223 | 30 | behavior + input |
| `workspace/all/common/api.h` | 2 | 0 | behavior |
| `workspace/all/common/config.c` | 30 | 4 | settings persistence |
| `workspace/all/common/config.h` | 15 | 14 | settings persistence |
| `workspace/all/common/defines.h` | 19 | 6 | build/product |
| `workspace/all/common/generic_bt.c` | 107 | 88 | my355 integration |
| `workspace/all/common/generic_video.c` | 183 | 32 | startup / KMS |
| `workspace/all/common/generic_wifi.c` | 139 | 206 | my355 integration |
| `workspace/all/common/palette.c` | 19 | 0 | behavior |
| `workspace/all/common/palette.h` | 5 | 0 | behavior |
| `workspace/all/common/sdl.h` | 5 | 0 | build |
| `workspace/all/common/utils.c` | 475 | 13 | library behavior |
| `workspace/all/common/utils.h` | 20 | 0 | library behavior |
| `workspace/all/nextui/makefile` | 1 | 1 | build |
| `workspace/all/nextui/nextui.c` | 805 | 244 | library / product behavior |
| `workspace/all/settings/btmenu.cpp` | 135 | 66 | settings |
| `workspace/all/settings/btmenu.hpp` | 1 | 0 | settings |
| `workspace/all/settings/keyboardprompt.cpp` | 44 | 29 | settings input |
| `workspace/all/settings/keyboardprompt.hpp` | 1 | 0 | settings input |
| `workspace/all/settings/makefile` | 1 | 1 | build |
| `workspace/all/settings/menu.cpp` | 227 | 78 | UI layout |
| `workspace/all/settings/menu.hpp` | 22 | 5 | UI layout |
| `workspace/all/settings/settings.cpp` | 158 | 161 | settings wiring |
| `workspace/all/settings/wifimenu.cpp` | 98 | 50 | settings |
| `workspace/all/settings/wifimenu.hpp` | 1 | 0 | settings |

Only in the vendored tree:

- `UPSTREAM` (the pin record)
- `workspace/all/settings/zlymejoystick.cpp` / `.hpp`
- `workspace/all/settings/zlymemenu.cpp` / `.hpp`
- `workspace/all/settings/zlymeupdate.cpp` / `.hpp`
- `workspace/my355/` (`platform.c`, `platform.h`, `pad_policy.h`, `makefile.env`, `libmsettings`, `README`)

Classification, by concept rather than by line:

1. **my355 hardware/platform.** The whole `workspace/my355` tree. `generic_wifi.c` calls `zlyme-wifi` instead of shelling SSIDs. `generic_bt.c` calls `zlyme-bluetooth` / `zlyme-audio` and refuses a blocking `bluetoothctl scan off`. `generic_video.c` drops the fb0 splash, retries KMSDRM, and asks for GLES 3.0. `platform.c` writes `/tmp/poweroff` and `/tmp/reboot`.
2. **Generic Zlyme frontend behavior.** `utils.c` library roots (`/run/zlyme/libraries`), junk filters, and multi-disc companion skipping. `nextui.c` merged library scans, PICO-8 BIOS presence, EasyRPG directory detection. `api.c` lid/idle blanking and `zlyme-keylidmon` signaling.
3. **Settings / product.** `zlymemenu`, `zlymeupdate`, `zlymejoystick`, and the `settings.cpp` calls that append display, HDMI, LED, storage, backup, factory reset, and game cleanup. Wi-Fi and Bluetooth menus adjusted to those helpers.
4. **Performance / startup.** Timezone init moved off the first frame (`api.c` comment: `zone.tab` parse and `hwclock` blocked first frame). Splash handoff in `generic_video.c`. Menu layout in `menu.cpp` avoids a blank row at `FIXED_SCALE=2`.
5. **Build.** The two makefiles that select the platform objects. `defines.h` / `sdl.h` small deltas. The Buildroot recipe itself is outside `src/` and stays in Zlyme.
6. **Excluded upstream.** The 753 pin-only paths. MinArch, other device workspaces, and the skeleton asset tree are not in the image because they are not in the vendored copy. A fetched fork should exclude them at build/install time, not by deleting them from history.
7. **Provenance.** `LICENSE` grew four lines. `UPSTREAM` and `CREDITS` record the pin and the apommel hardware-map origin. Keep PolyForm Noncommercial 1.0.0 and the LoveRetro / MinUI attribution on the fork.

## Proposed fork commit groups

Do not turn each changed line into a commit. A maintainable series on top of `ae652648` is:

1. Record the pin, license, and attribution (`UPSTREAM`, `CREDITS`, `LICENSE`).
2. Add `workspace/my355` (platform, msettings, pad policy, makefile env).
3. Point the NextUI and Settings makefiles at `$(PLATFORM)`.
4. Library scan helpers in `utils` / `nextui.c` (roots, junk, companions, PICO-8 BIOS, EasyRPG).
5. Boot and video handoff (splash, KMS retry, GLES profile).
6. Wi-Fi and Bluetooth through `zlyme-wifi`, `zlyme-bluetooth`, and `zlyme-audio`.
7. Lid, volume, and `zlyme-keylidmon` in `api.c`.
8. Settings product screens (`zlymemenu`, `zlymeupdate`, `zlymejoystick`) and the menu that hosts them.
9. Menu overlay / 640x480 layout.
10. Keyboard backspace behavior already present on L1.

The visible L1 DELETE pill is not in this delta. `keyboardprompt.cpp` already pops a character on `BTN_L1`. The shared hint pill is Phase 9.

## Boundary

Device code stays under `workspace/my355` and behind commands (`zlyme-wifi`, `zlyme-bluetooth`, `zlyme-audio`, `zlyme-halt`, `zlyme-governor`). Shared `workspace/all` may call those commands. It must not grow RK817 mixer names, GPIO numbers, or DRM connector names. Joystick calibration visibility for a future device is a platform boundary in this phase, not a new calibration feature.

## minui-list and minui-presenter

PROVEN FROM SOURCE: Zlyme has no source delta. Both recipes clone upstream tags and compile them against the NextUI objects. Their `CFLAGS` hard-code `-DPLATFORM=\"my355\"` and `workspace/my355` include paths.

That finding still stands. The maintainer decision after it is to vendor both trees anyway, before any source change is required. Device integration is expected to need local edits later, and a copy in the Zlyme tree keeps the build reproducible without two extra repositories.

Superseded: "do not fork, and keep fetching the tags." Do not create GitHub forks merely because the source is vendored. Reconsider a fork only if Zlyme later carries a long-lived divergence or wants to send changes upstream.

Phase 8 sequence, same split as NextUI:

1. Vendor the exact versions Zlyme already builds: minui-list `0.15.2`, minui-presenter `0.13.2`. Record the upstream repository, tag, and commit. Keep copyright and license. Buildroot builds that `src/` with `SITE_METHOD=local`.
2. Prove the vendored tree builds and behaves like the git-fetched recipes.
3. Only then evaluate upstream `0.15.4` and `0.13.4` (both released 2026-09-27). Do not take those tags as part of the initial vendoring.

Layout, not implemented here:

```text
package/system/minui-list/
    Config.in
    minui-list.mk
    LICENSE / provenance
    UPSTREAM
    src/                 exact 0.15.2 snapshot
package/system/minui-presenter/
    Config.in
    minui-presenter.mk
    LICENSE / provenance
    UPSTREAM
    src/                 exact 0.13.2 snapshot
```

The exact filenames may follow the existing package style. `-DPLATFORM` and the include path come from `BR2_PACKAGE_NEXTUI_PLATFORM`. No behavioral source edits in the first vendoring step.

## Buildroot migration

1. Reconstruct the fork from `ae652648` using the groups above. Do not start that fork at current LoveRetro HEAD.
2. Prove the result matches current Zlyme behavior with targeted frontend builds.
3. Change `nextui.mk` from `SITE_METHOD=local` to an exact commit of the Zlyme fork.
4. One incremental device image is allowed if that is what it takes to show the migration did not regress the Flip. A full clean Buildroot build waits until the end of Phase 9.
5. Source or build comparison is not hardware acceptance.

## Upstream update, later

PROVEN FROM UPSTREAM GIT. `ae652648..a0628cdc` is two commits:

| Commit | Subject | Files |
| --- | --- | --- |
| `afbdb83` | update Gearcoleco core patches (#838) | `workspace/tg5040` and `workspace/tg5050` `gearcoleco.patch` only |
| `a0628cdc` | reduce dynarec JIT address-space pressure (#814) | `workspace/all/common/api.c`, `workspace/all/minarch/minarch.c` |

Gearcoleco patches do not affect the my355 image. `minarch.c` is not in the vendored tree. The `api.c` hunk does touch a file Zlyme has already edited. Rebase or cherry-pick it only after the fork matches today's behavior. Do not combine fork creation with this update.

## ZLYMEBOOT / `FSCK0000.REC`

PROVEN FROM SOURCE.

`FSCK0000.REC` (and `FSCK0001.REC`, …) is the name dosfstools `fsck.fat` gives a recovered orphan cluster chain in the root directory. It means a FAT was dirty or inconsistent and a checker salvaged lost clusters. It is not a Zlyme log format.

Boot path:

- Initramfs mounts `LABEL=ZLYMEBOOT` read-write, loop-mounts the squashfs file `/boot_root/zlyme` as the new root, then `mount --move`s that vfat onto `/boot` (`package/boot/zlyme-initramfs/init`).
- `S12bootfs` mounts the same label at `/boot` with `rw,noatime,utf8` if initramfs did not.
- `S12bootfs stop` would `umount /boot`. Ordinary shutdown does not get there.

Shutdown path:

- `PLAT_powerOff` touches `/tmp/reboot` or `/tmp/poweroff` and exits.
- `nextui-session` execs `zlyme-halt reboot` or `zlyme-halt poweroff`.
- `zlyme-halt` syncs, skips `/boot` and `/storage` while unmounting other mounts, syncs again, sleeps one second, then `reboot -f` or `poweroff -f`.
- `poweroff -f` / `reboot -f` do not run init stop scripts, so `S12bootfs stop` never unmounts `/boot`.

Why a clean unmount is not available: the root filesystem is a squashfs loop whose backing file is on that vfat. Unmounting `/boot` while `/` is mounted fails. `S13resize` already says not to unmount `/boot` for that reason. Writers that still dirty the volume include extlinux overlay edits (`zlyme-ctl apply_overlays`), splash animation copies (`S12splash`), and `/boot/zlyme-splash.progress`.

Credible mechanism, not a completed proof: vfat has no journal. A forced poweroff leaves the volume marked dirty. The next checker, on the device or on a host, turns orphan clusters into `FSCK####.REC`. Skipping `/boot` in `zlyme-halt` is consistent with that, and the loop makes a real `umount` the wrong fix.

Narrow experiment, first implementation gate if this stays the leading explanation:

- Before `reboot -f` / `poweroff -f`, after `sync`, try `mount -o remount,ro /boot`.
- Record whether the remount succeeds and whether anything still has the mount busy (`fuser` / `/proc/mounts`).
- Do not `umount /boot` while the squashfs loop is the root.
- If remount-ro fails, name the holder before changing policy.
- `/storage` is exFAT and is a separate question. Do not fold it into the FAT fix.

This is a storage-integrity defect candidate. It is the first Phase 8 implementation gate. Shutdown code was not changed in this note.
