# Frontend source — Phase 8

> Status: historical Phase 8 record, 2026-09-30, started at `baadc22b`. The opening and "Current frontend architecture" describe the vendored tree before the migration.
> Phase 8 then created the `Zetarancio/NextUI` fork (branch `zlyme`), switched `nextui.mk` to a pinned git fetch, vendored minui-list and minui-presenter, made ZLYMEBOOT read-only, and unmounted `/storage` before forced shutdown. It closed on runtime `7a0fc397`.
> Phase 9 moved the NextUI pin and removed Artwork Scraper, ScrapeGoat.pak, and Weston.pak, which "Image audit" still lists. ZcrapeGoat replaced ScrapeGoat.
> For the shipped behavior, read [docs/ARCHITECTURE.md](../ARCHITECTURE.md) §5 to §7 and §11, and [docs/MAINTENANCE.md](../MAINTENANCE.md) "NextUI fork".

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

## Fetch migration

The local reconstruction commit `b56771b1fad1a85620ed47685c6c4be379276157` could not be pushed. Its clone was missing ancestor blobs. The same tree, `912da6253ab156a57a1d6c420a98397670f18f34`, was replayed onto a complete LoveRetro history and published as `Zetarancio/NextUI` branch `zlyme` at `40cc8a64c7fe4e22e9fd746a49b11d083d4f1f59`. That commit is still rooted at `ae652648548edf6ab24cbb816cf4e4194e609fb3`. It does not include the two newer LoveRetro commits. Quick Menu order is unchanged.

`Zetarancio/NextUI` is now Zlyme's GitHub fork of `LoveRetro/NextUI`. The Zlyme branch is `zlyme`. Buildroot pins commit `40cc8a64c7fe4e22e9fd746a49b11d083d4f1f59`, not the branch name. LoveRetro/NextUI itself descends from Shaun Inman's MinUI. That fork network is left as GitHub records it. Upstream `main` is not merged into `zlyme`.

`NEXTUI_VERSION` is that fork commit. `ZLYME_VERSION` is `zlyme43` and is what `/usr/share/zlyme/version`, os-release, and the Actions release title use. `/usr/share/nextui/version.txt` is the fork commit. The duplicate `package/system/nextui/src` tree was removed after a `nextui-dirclean nextui` build whose fetched sources matched the vendored delta and whose image install did not include other device trees. `zlyme-keylidmon` still compiles the staged `msettings.h` from the nextui package.

## MinUI helper vendoring

`minui-list` 0.15.2 is the upstream commit `a5f5b456c2704bbf6ec92aa26bc58d268488696f`. `minui-presenter` 0.13.2 is `4d9f6ea350f663a72ef3621f1b4a11fdb8279f7a`. Both are MIT. Their trees are vendored under each package's `src/` with `SITE_METHOD=local`. No helper source was edited.

Parson stays `ec53fb6528b45811df9db0db22cab96a94a96a11`, MIT. Upstream minui-list gitignores `include/`, which is where `<parson/parson.h>` is found, so the three pinned files live in `package/system/minui-list/parson/` and the recipe copies them there at build time. Presenter still compiles that same `parson.c`. There is no extra download.

`-DPLATFORM`, the NextUI include paths, and `bin/<platform>/` come from `BR2_PACKAGE_NEXTUI_PLATFORM`. An empty value fails the build. On this defconfig that value is `my355`, and the install paths stayed `bin/my355/`. The helpers still link NextUI's `scaler.o`, `utils.o`, `config.o`, `api.o`, `palette.o`, `platform.o`, and `libmsettings`. They do not copy that code.

The rebuilt binaries are not byte-identical to the pre-vendoring builds (`minui-list` `78e96273…` to `68afd637…`, `minui-presenter` `ebc2f587…` to `657d5503…`). The NEEDED libraries match. The helper sources do not call SDL gamecontroller functions. Those new imports come from the current `nextui` `platform.o`, which this recipe has always linked and which was rebuilt for the fork fetch. `0.15.4` and `0.13.4` were not taken.

A full image build now treats `nextui.mk` as an input of both helpers, and the `minui-list` package as an input of `minui-presenter`. A pin or recipe change dircleans NextUI and both helpers. A parson or list change dircleans list and presenter. The downloaded NextUI tree is not fingerprinted. The parson MIT text is installed as `/usr/share/minui-list/parson-LICENSE`.

The migration image is `output/images/zlyme-my355-20260930-7a0fc397cb5b.tar`, SHA-256 `eff4cd7643b32f53ed7bb284bbc6b3c60732f54da85527150de19c358f1a9bac`. Its `VERSION` file and the runtime it was built from are `7a0fc397cb5b3e0f7c4b19f4f3abe8626eaccaf8`. `/usr/share/zlyme/version` in that image is `zlyme43 (2026-09-30)`. `/usr/share/nextui/version.txt` is `40cc8a64c7fe4e22e9fd746a49b11d083d4f1f59`. Later documentation commits are not inside the image.

## Migration hardware equivalence

The maintainer installed that OTA. Remote checks matched the image: product version `zlyme43 (2026-09-30)`, NextUI `40cc8a64c7fe4e22e9fd746a49b11d083d4f1f59`, helper SHA-256 values `df1b81df…` and `e000e3c9…` at `/usr/bin` and under `bin/my355/`, parson license present, `/boot` vfat read-only, `/` squashfs read-only, `/storage` exFAT read-write, `loop0/ro=1`, backing file `/boot/zlyme` at 648376320 bytes. `apply.log` names `zlyme-my355-20260930-7a0fc397cb5b.tar`. No oops, panic, I/O error, or segfault. The inherited exFAT dirty-volume warning remained.

The maintainer then passed all seven physical checks: menu and buttons, Quick Menu still Wi-Fi then Bluetooth then Settings, Settings rendering, my355 System and joystick calibration, one helper Tool opened and exited, one existing game launched, and that game returned to NextUI. Those checks were not repeated.

The first timing sample was the OTA-commit boot (`rcS-start` 46.28). Initramfs copies the squashfs before `rcS`, and that boot also rewrote the stock paks because the image pak stamp did not match the card. It is not a normal-boot benchmark.

The following normal reboot, uptime 287 seconds at capture, with `nextui-session` and `nextui.elf` running:

| Mark | Baseline | Normal reboot |
| --- | ---: | ---: |
| `rcS-start` | 3.68 | 3.62 |
| `rcS-nextui-ready` | 4.92 | 4.84 |
| `session-nextui` | 6.04 | 5.96 |
| `nextui-enter` | 6.78 | 6.72 |
| `nextui-settings` | 6.80 | 6.74 |
| `nextui-gfx` | 7.73 | 7.54 |
| `nextui-menu` | 9.47 | 9.00 |
| `nextui-first-flip` | 9.95 | 9.53 |
| `inputplumber-start` | 11.25 | 11.24 |

From `rcS-start` to `nextui-first-flip` is 5.91 seconds, against 6.27 on the baseline. From `nextui-enter` to first flip is 2.81 seconds, against 3.17. From `session-nextui` to `nextui-enter` is 0.76 seconds, against 0.74. `session-copy` to `session-paks` is 0.22 seconds. The eight-second gap on the OTA-commit boot is the stock-pak overwrite that runs when `paks-version.txt` does not match the card. A matching stamp returns before that copy. This sample is not a regression.

## Upstream review

Fetched 2026-09-30. Nothing below was merged.

LoveRetro/NextUI `main` is still `a0628cdc0cee8e173a9bb94144f5c8baa22ab8e7`, two commits after `ae652648548edf6ab24cbb816cf4e4194e609fb3`.

`afbdb83735e2efb8f7828a74d7af802d40c7566e` changes only `workspace/tg5040` and `workspace/tg5050` Gearcoleco patches. Those trees are not compiled or installed for my355. Disposition: does not apply, no my355 image effect, ignore.

`a0628cdc0cee8e173a9bb94144f5c8baa22ab8e7` adds `mallopt` and a 1 MiB SDL thread-stack hint in `workspace/all/minarch/minarch.c`, and routes the vibration and battery `pthread_create` calls in `workspace/all/common/api.c` through a 1 MiB stack. Zlyme does not build MinArch; `nextui.mk` deletes `minarch.elf` if one is present, and games launch through RetroArch. The `api.c` hunk is shared code that this image does compile. The Zlyme fork already carries its own `api.c` delta (223 insertions against the pin) and still uses the plain `pthread_create` at those two sites. There is no demonstrated Zlyme failure that needs the smaller stacks. Disposition: shared hunk is technically relevant, original problem is MinArch/dynarec, defer. Do not move the pin just to match upstream.

`minui-list` `0.15.4` is `47f111762c6229ab16284d7eeab72e27a1461154`. Against vendored `0.15.2` (`a5f5b456c2704bbf6ec92aa26bc58d268488696f`) the diff is Makefile, docs, tests, and upstream-pin scripts. No `.c` or `.h` changes. Disposition: evaluated, no Zlyme runtime benefit, keep 0.15.2.

`minui-presenter` `0.13.4` is `6d71bbeb136eca476168f65522c59310f84f9f6a`. Against vendored `0.13.2` (`4d9f6ea350f663a72ef3621f1b4a11fdb8279f7a`) the diff is the same kind of maintenance. No `.c` or `.h` changes. Disposition: evaluated, no Zlyme runtime benefit, keep 0.13.2.

## Profile

The normal-reboot marks are the profile. `nextui.c` writes `enter` at `main`, `settings` after `InitSettings`, `gfx` after `GFX_init`, `menu` after pad, vibration, power, and `Menu_init`, and `first-flip` on the first `GFX_flip`. On this sample those steps are 0.02, 0.80, 1.46, and 0.53 seconds. The baseline `gfx` to `menu` interval was 1.74 seconds. `libraryReload` runs before graphics init. Folder art is skipped until first flip, and thumbnail workers start after it. The bluetooth `sleep` calls in `nextui-session` run while a pak is starting, not before the menu. No hot-path change is justified from this sample. The helpers were not retimed; their physical Tool check already passed, and this audit found no separate helper cost to chase.

## Image audit

Other-platform NextUI source is intentionally retained in the fork. Platform selection excludes it from the my355 build and image. Future Zlyme devices may reuse it. That includes other device workspaces, MinArch, platform-specific core patches, and generic upstream implementation that another platform may use. Deleting those files would only increase fork divergence. They do not enlarge the my355 squashfs when Buildroot neither compiles nor installs them. Dead-code cleanup is concerned with unreachable installed content, and with Zlyme-only code proven to have no caller. It is not a reason to delete upstream source merely because today's board does not use it.

`nextui.mk` compiles `libmsettings`, the common objects `scaler`, `utils`, `config`, `api`, `palette`, and `platform`, plus `nextui.elf`, `settings.elf`, `show.elf`, and `nextval.elf`. It deletes `keymon.elf`, `minarch.elf`, and `gametimectl.elf` if a previous package left them in the target, and it drops Update, Autocal, and the old Joystick Calibration pak. Parallel N64 and melonDS DS cores are removed from the image. MinArch source stays in the NextUI fork.

`/usr/share/nextui` paks are reachable Tools, including ScrapeGoat and Artwork Scraper. `show.elf` and `nextval.elf` stay installed under `/usr/bin` and `/usr/share/nextui/bin`. `font2.ttf` and the `BPreplay` names stay. Settings offers `font2.ttf` as OG, and `show.elf` keeps the `BPreplay` path as a fallback. Weston.pak stays; removing that Tools entry is a Phase 9 image cleanup, not this phase.

`package/system/nextui/res/branding/` stays in git. `scripts/rasterize-zlyme-branding.py` and the README still read it. The recipe copies `res/` and then removes only the target directory `/usr/share/nextui/res/branding`. After `nextui-reinstall`, that directory is absent. These runtime files were still present, at the same sizes: `background.png` (360905), `charging-640-480.png` (355964), `logo.png` (202183), 19 palette files, `splash.rgb565` and `progress.rgb565` (614400 each), `splash.anim` (29419220), `progress.anim` (19612820), and the PortMaster Zlyme theme `logo.png` (202183). The installed branding directory had been 3699882 bytes (`COLORS.md`, `zlyme_static_fog_transparent.png`, and `Z.png`). `/usr/share/nextui/res` went from 9279922 bytes to 5580040. A squashfs rebuilt from that target, without packing a new OTA, went from 648376320 bytes to 644694016 bytes (3682304 bytes smaller). mksquashfs reported 633178.52 KiB before and 629582.21 KiB after, and three fewer files. The accepted migration tar was not replaced.

```text
res/branding = KEEP IN SOURCE
res/branding = EXCLUDE FROM RUNTIME IMAGE
```

## Phase 8 close

Phase 8 is complete. The hardware-equivalent runtime is `7a0fc397cb5b3e0f7c4b19f4f3abe8626eaccaf8`. The accepted OTA is `zlyme-my355-20260930-7a0fc397cb5b.tar`, SHA-256 `eff4cd7643b32f53ed7bb284bbc6b3c60732f54da85527150de19c358f1a9bac`. Commit `b7c5a19` later excludes build-only branding from the target image. That change was verified by package reinstall and a squashfs rebuild. It did not get a second device OTA, and it is not part of the hardware-tested runtime. The final Phase 8 git HEAD is therefore not itself a hardware-tested image.

```text
PHASE 8 STORAGE PREFLIGHT = COMPLETE
PHASE 8 FRONTEND BASELINE = COMPLETE
PHASE 8 NEXTUI SOURCE OWNERSHIP = COMPLETE
PHASE 8 MINUI HELPER OWNERSHIP = COMPLETE
PHASE 8 MIGRATION HARDWARE EQUIVALENCE = PASS
PHASE 8 UPSTREAM REVIEW = COMPLETE
PHASE 8 PERFORMANCE AUDIT = COMPLETE
PHASE 8 DEAD-CODE/SOURCE AUDIT = COMPLETE
OTHER-PLATFORM NEXTUI SOURCE = INTENTIONALLY RETAINED
BUILD-ONLY BRANDING IN TARGET = REMOVED
PHASE 8 = COMPLETE
```
