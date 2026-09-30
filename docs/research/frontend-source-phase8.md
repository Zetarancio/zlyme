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

`FSCK0000.REC` (and `FSCK0001.REC`, …) is the name dosfstools `fsck.fat` gives a recovered orphan cluster chain in the root directory. It means a FAT was dirty or inconsistent and a checker salvaged lost clusters. It is not a Zlyme log format. Existing files can have older causes. This change does not prove they came from the shutdown path, and it does not prove a later checker will never create another one. The useful observation is whether new `FSCK*.REC` files stop appearing after images with this boot policy are in normal use.

### Live evidence

PROVEN ON DEVICE, 2026-09-30, Phase 7C runtime. Kernel `Linux zlyme 7.0.2 #1 SMP PREEMPT Tue Sep 29 23:00:46 UTC 2026`. `/usr/sbin/zlyme-halt` matched the tree at `24324ff` byte for byte (`a578f41d5c9dbe0a448715b00d6cf01cc93b7ca9746758364c8ba312228c34a8`).

```text
/        /dev/loop0      squashfs  ro
/boot    /dev/mmcblk0p2  vfat      rw
/storage /dev/mmcblk0p3  exfat     rw
/sys/block/loop0/loop/backing_file = /boot/zlyme
/sys/block/loop0/ro = 0
```

`mount -o remount,ro /boot` returned `Device or resource busy` (`remount_ro_rc=255`). BusyBox `fuser -m /boot` printed no PID. No process had `/boot`, `/dev/mmcblk0p2`, or `/dev/loop0` open. The writable hold is the loop: BusyBox `mount -o loop` without `ro` opens the backing file read-write, and Linux 7.0.2 sets `LO_FLAGS_READ_ONLY` only when that file is not opened for write (`drivers/block/loop.c`). The volume stayed writable. The marker files were removed and `/boot` was left read-write. No reboot was performed. Shutdown-time remount is not the fix.

### Reference implementation

PROVEN FROM UPSTREAM SOURCE. Knulli `package/boot/knulli-initramfs/init` (same sequence as Batocera `batocera-initramfs/init`):

1. `do_mount` starts with `mount_options="ro"`.
2. If `knulli.update` / `batocera.update` exists, `mount -o remount,rw`, replace the squashfs, then `mount -o remount,ro`.
3. Only then is the system image mounted, and `/boot_root` is moved to `/boot`.

Zlyme does not copy the overlay root, the update filename, or the rest of that init. The lifecycle is the part that applies.

### Writer inventory

Searched before the change. Classification is of the behavior that existed at `24324ff`.

| Writer | Class | Handling |
| --- | --- | --- |
| `package/boot/zlyme-initramfs/init` `mount_boot` | initramfs, before the loop | Mount `ro,noatime,utf8`. |
| same, `commit_update` copies `/boot_root/zlyme` | OTA, before the loop | Remount RW, copy, `sync`, remount RO, refuse to attach the loop if it is still writable. A failed copy keeps the old file and still closes the vfat. If the RW remount itself fails, the update is skipped and the old read-only root still boots. |
| same, writes `zlyme-splash.progress` when a payload is pending | OTA, before the loop | Inside that same RW window. `S12splash` later moves the signal to `/tmp` and deletes the FAT flag. |
| same, `zlyme-logs` → `zlyme-dmesg.txt` | logging, before the loop | Same window, only if `/boot_root/zlyme-logs` exists. |
| `S12bootfs` fallback mount | runtime mount | `ro,noatime,utf8`. If initramfs already mounted it, remount RO. |
| `zlyme-ctl apply_overlays` (`extlinux.conf`, `FDTOVERLAYS`) | runtime configuration | `zlyme-boot-write`. |
| `zlyme-update install_boot` (Image.gz, DTB, extlinux, overlays, splash anims) | OTA, after the loop exists | One `zlyme-boot-write` transaction. Does not replace `/boot/zlyme`; initramfs does that on the next boot, before the new loop. |
| `zlyme-splash-progress` persist / keep / off | OTA / first-boot flag | FAT create and delete go through `zlyme-boot-write`. `/tmp` stays the live flag. |
| `S18zlymeupdate` and `zlyme-update` fallbacks that wrote the flag directly | OTA | Same helper. |
| `S12splash` seed of missing `splash.anim` / `progress.anim` | first boot / old OTA | One helper transaction, only when a file is missing. Reads stay direct. |
| `S12splash` consume of `zlyme-splash.progress` | one-shot flag | Helper delete after copying the signal to `/tmp`. |
| `nextui-session` `stop_splash` | runtime flag | Helper delete if the file is still there. |
| `S13resize` `remove_trigger` (`zlyme-boot.conf`) | first-boot bookkeeping | `zlyme-boot-write sed`. No GPT work on the vfat. |
| `zlyme-logs` `touch` / `rm` of `/boot/zlyme-logs` | logging flag | Helper. The dmesg copy is a read. |
| `generic_video.c` `unlink("/boot/zlyme-splash.progress")` | NextUI, left unchanged | Best-effort. `S12splash` already removes the file, so this becomes a missing-file unlink. Not a frontend migration. |
| `splash.c`, `S16display`, session splash paths | read | No write. |
| `post-update.sh` | OTA hook | Writes `/storage_root` only, from the initramfs, before the loop. |
| `zlyme-halt` | shutdown | Still skips `/boot` and `/storage`. No remount added. `/storage` clean unmount or remount is a later audit. |
| host `post-image.sh` / `genimage.cfg` | image build | Not a runtime writer. |

`zlyme-boot-write` checks that `/boot` is mounted, remounts it read-write, runs one command, `sync`s, remounts read-only, and checks the mount options. A failed close is an error. A nested call, while the outer pid is alive, does not close the volume early. There is no daemon and no lock. Two overlapping callers are not expected: OTA and Settings do not write the vfat at the same time.

### Expected runtime

```text
/        squashfs  ro
/boot    vfat      ro
/storage exfat     rw
loop0/ro = 1
backing file = /boot/zlyme
```

BusyBox 1.36.1 `mount -o loop,ro` opens the backing file `O_RDONLY` when `MS_RDONLY` is already set (`util-linux/mount.c` passes `BB_LO_FLAGS_READ_ONLY` into `set_loop`). That is the mechanism for `loop0/ro=1`. The initramfs refuses to `switch_root` if the loop is not read-only.

This image is not hardware-accepted until a boot shows that table and one helper transaction returns `/boot` to read-only.

## Phase 8A hardware result

Accepted 2026-09-30 on `zlyme-my355-20260930-37d41679996f.tar`, kernel `#3 SMP PREEMPT Wed Sep 30 09:35:46 UTC 2026`. After a normal NextUI reboot, `/boot` was vfat read-only, `/` was squashfs read-only, `loop0/ro` was 1, and the backing file was `/boot/zlyme`. A direct write was rejected. `zlyme-boot-write` returned the volume to read-only. No `FSCK*.REC` files were on `/boot`. The historical FAT dirty flag is not claimed to be cleared. The two `FAT-fs (mmcblk0p2)` warnings on the pre-reboot boot were the helper remounting a volume that was already dirty, not a new structural error.

## Phase 8A2 — primary `/storage`

PROVEN ON DEVICE before this change, same image, Samba `off`, Syncthing `off`:

| PID | Process | cwd under `/storage` | open fd under `/storage` | Still there when NextUI asks to shut down |
| --- | --- | --- | --- | --- |
| session | `nextui-session` | yes, `/storage` | yes, `/storage/.config/zlyme/nextui-session.log` (stdout/stderr from `S28minui`) | yes: it `exec`s `zlyme-halt` and both holds are inherited |
| frontend | `nextui.elf` | yes, `/storage` | no | no: it has exited before that `exec` |
| sshd | listener cwd `/` | no | no | left running; host key is on tmpfs |
| wpa_supplicant | config path is on the card | no | no open fd at the audit | not stopped merely because the path is in argv |
| smbd / syncthing | not running | — | — | stopped only when the process is actually present |

`zlyme-storage eject` unmounts secondary SD and removable media, not `/storage`. The old `zlyme-halt` skipped `/storage` and did not `cd /`.

PROVEN FROM THE SELECTED KERNEL, `output/build/linux-7.0.2/fs/exfat/super.c`. At mount, `vol_flags_persistent` keeps `VOLUME_DIRTY` if that bit was already set. `exfat_set_vol_flags()` ORs those persistent flags back in. `exfat_put_super()` calls `exfat_clear_volume_dirty()`, which therefore cannot clear a dirty bit inherited from mount. A normal `umount /storage` is still the right teardown. The next boot can keep printing `Volume was not properly unmounted` after a clean unmount of a volume that started dirty. There is no lazy unmount of primary `/storage` and no fsck at boot.

### Phase 8A2 hardware result

Accepted 2026-09-30 on `zlyme-my355-20260930-632202865c71.tar` after a normal NextUI reboot. Uptime at the check was 55 seconds. Kernel still `#3`. `/boot` was vfat read-only, `loop0/ro` was 1, backing file `/boot/zlyme`. `/storage` was exFAT read-write again. `nextui-session` and `nextui.elf` were running. `wlan0` was up and SSH worked.

`/boot/.zlyme-storage-unmounted-test` existed (mtime 10:23 UTC). `/boot/.zlyme-storage-unmount-failed` did not. The success file is written only after `umount /storage` returns 0. This boot's `dmesg` still has `exFAT-fs (mmcblk0p3): Volume was not properly unmounted` at 3.09 s, which matches the inherited dirty bit. No I/O error and no ZLYMEBOOT FAT warning. The historical dirty flag is not repaired. Automatic fsck, a one-time `fsck.exfat`, and secondary-media format stay out of this phase.

The success and failure boot markers, and the holder dump that existed only to fill the failure file, are removed from `zlyme-halt` after this result. A failed `umount /storage` prints one line on the console and shutdown still proceeds. Production shutdown does not reopen ZLYMEBOOT.

The later image `zlyme-my355-20260930-07aacf303475.tar` is the same mechanism without those markers. On the live Flip, `/usr/sbin/zlyme-halt` matched that source byte for byte and contained no `storage-unmounted` string. `/boot` was vfat read-only, `/storage` was exFAT read-write, and `loop0/ro` was 1. No second shutdown cycle was run for the marker removal. The unmount proof remains the `632202865c71` reboot.

`S28minui` redirects the session onto `/storage/.config/zlyme/nextui-session.log`. On the live process those were fds 11 and 12, not only 1 and 2, so `exec` of `zlyme-halt` inherits them. POSIX `exec N>&-` needs a literal number. The close loop uses `eval` only after `n` is checked to be digits. That is the exception to the no-`eval` rule. Moving the session log would change the kept log, and a C helper would not change who owns the descriptor.

## Frontend baseline

Measured on that same accepted boot, `/tmp/boot-timing` (also copied to `/storage/.config/zlyme/boot-timing`). Seconds from boot. This is the cold path to the menu, not a later manual visit to Settings.

| Mark | Seconds |
| --- | ---: |
| `rcS-start` | 3.68 |
| `rcS-nextui-ready` | 4.92 |
| `session-start` | 5.12 |
| `session-nextui` | 6.04 |
| `nextui-enter` | 6.78 |
| `nextui-settings` | 6.80 |
| `nextui-gfx` | 7.73 |
| `nextui-menu` | 9.47 |
| `nextui-first-flip` | 9.95 |
| `inputplumber-start` | 11.25 |

`/usr/share/zlyme/version` is `zlyme43 (2026-09-30)`. `nextui.elf` was built from `nextui-ae652648548edf6ab24cbb816cf4e4194e609fb3-zlyme43`. No navigation beyond this boot path was driven over SSH. No optimization was done.
