# Miyoo Flip operations

This document contains durable operational facts for the Miyoo Flip, the only supported Zlyme device.

```text
device id: my355
device:    Miyoo Flip
SoC:       Rockchip RK3566
```

This is a maintainer runbook, not the architecture specification.

## Serial console

The Miyoo Flip debug UART uses:

```text
ttyS2
1500000 baud
8N1
3.3 V
```

Do not depend on a particular host USB-UART device path in repository code or canonical documentation.

The reliable host setup established during bring-up uses `stty` to set 1500000 baud before opening the descriptor.

## Boot identity

The DTB name, the OS-card nodes, and both labels come from `board/my355/fsoverlay/usr/share/zlyme/device.conf`:

```text
kernel DTB:     rk3566-miyoo-flip.dtb
OS disk:        /dev/mmcblk0
boot partition: /dev/mmcblk0p2
storage:        /dev/mmcblk0p3
boot label:     ZLYMEBOOT
storage label:  ZLYME
root payload:   zlyme (squashfs file on boot FAT)
```

The right-hand slot is the OS card. The device nodes select it. The labels confirm the partitions and are not unique across cards. Boot, storage, first-boot resize, and `zlyme-update uboot` do not follow a second card that repeats those labels. This is implemented and host-tested. It is awaiting Flip validation with both cards installed.

## Image layout

The my355 image uses:
- idbloader beginning at 32 KiB;
- `uboot` GPT partition at 8 MiB;
- FAT32 `ZLYMEBOOT`;
- exFAT `ZLYME`;
- no rootfs GPT partition.

The squashfs root is a file on `ZLYMEBOOT`. A fresh image also puts `miyoo355_fw.img` at the FAT root. Stock consumes that installer. An ordinary OTA does not write it.

The image build also leaves `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img` beside `zlyme.img`, with a `.sha256` for each. `miyoo355_fw-multiboot.img` is the same bytes as `miyoo355_fw.img`. The other two are stock-side helpers: one derives the right-slot recovery preloader from the preloader on that unit, and the other writes back the single `mtd5-original-<sha256>.img` saved on the card. The restore helper runs only after stock has booted, so it undoes the normal repaired preloader. An armed recovery preloader does not boot stock; leave that state from Zlyme with Disarm, or with the physical MASKROM button if no right-slot Zlyme card will boot. Stock runs a helper only when the file on the card is named `miyoo355_fw.img`. None of the three extra files is inside `zlyme.img` or the OTA. Host tests cover the derivation, the refusals, the simulated rollback, and that a verified write does not reboot when the card is `/dev/mmcblk0p1`, `/dev/mmcblk1p1`, or `/dev/mmcblk2p1`. On 2026-10-08 one Flip hardware-accepted the public helper paths for this unit. Restore wrote `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` back to the saved original `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922`, and a later stock read of `/dev/mtd5ro` matched that hash with bad blocks 0. The MASKROM helper wrote `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` to `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367`. Started again from that original stock image, the same helper applied the `/pinctrl` repair and wrote the same recovery image. Zlyme then booted from the physical right-hand slot and read `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367` with `mode=recovery` and `recovery=armed`. `disarm-recovery` restored `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` with bad blocks 0, `mode=normal`, and `recovery=ready`. Each of those NAND writes was one verified attempt, with no rollback. The raw logs are in the hardware wiki. An earlier helper card in the physical left slot was classified as `/dev/mmcblk1p*`. A later stock boot of a left-slot card used `/dev/mmcblk2p1` at `/media/sdcard1`. The Zlyme boot above showed only `/dev/mmcblk0`. Those indexes are not a physical-slot map. This acceptance is that unit. It does not cover every vendor SPL revision or another unit's backup. A passing host test is not itself a NAND trial. The physical MASKROM button and `xrock` stay the last-resort path and are separate from these files.

`zlyme-preloader` is the only NAND writer in the image. Settings → System → Advanced → Recovery calls `status-machine` for the status page and `restore` for the write. `status` remains the human reading. `erase-preloader` is CLI-only and is not on that page. `status` and `status-machine` are safe to read. `status` says whether a valid original backup is available. `status` and `status-machine` collect the same facts in the shell that identified `mtd0`. The machine command prints `preloader`, `mode`, `recovery`, `source_backup`, `stock_restore`, `backup`, `battery`, and `charger` as `key=value` lines. It prints `fallback=compatible` when that per-device backup is absent and the live image is the known patched revision whose bundled stock file matches, including DDR. It prints `fallback=incompatible` when the backup is absent and that pair does not match. It omits `fallback` when a valid original backup exists. `backup=unavailable` still means there is no per-device original. `error` is the only line when a gate fails. It does not parse the human log. `mode` is `normal`, `recovery`, or `unknown`. `recovery` is `ready`, `armed`, `not-prepared`, or `invalid`. `source_backup` is `available` or `missing`. `stock_restore` is `available` or `unavailable`. The recovery class comes from the live bytes, the manifest, and the deterministic derivative. The command does not prepare a recovery image. The status page is a fixed list. It does not dump the human log into an overlay. `restore` and `erase-preloader` erase `mtd0` (`preloader`, 2 MiB) and, for restore, `nandwrite` the verified backup. Battery must be at least 25%, or lower only while a charger `online` file reads `1`. The tool refuses a wrong model, a second MTD partition, bad blocks, a current preloader that fails the RKNS checks, or a backup whose filename hash, size, or RKNS IDB hashes do not match. One valid `mtd5-original-<sha256>.img` is the restore source and it wins over the bundled file. If that backup is absent, restore may write `/usr/share/zlyme/recovery/preloader-stock.img` only when the live image is exactly `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`, the bundled file's SHA-256 is `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922`, the structure check passes, and the DDR payloads match. Every other combination refuses before erase. `preloader-stock.PROVENANCE` identifies that file. There is no force switch. Disarm does not write it. Restore also refuses a backup whose DDR payload differs from the current preloader. A failed restore write tries three times, then writes the saved current preloader back and checks that readback. That rollback is not a successful stock restore. A failed erase is not a successful erase; it tries the same rollback. Erase success is `flash_erase`'s own status, not a read of `0xff`, and it is not USB MASKROM. With a bootable Zlyme card installed, the boot ROM can load that card's idbloader. Neither NAND command reboots. Do not run them from SSH as a test.

`prepare-recovery` reads the live preloader, saves that exact image as `preloader-current-<sha256>.img`, and derives the right-slot recovery image under `/storage/.config/zlyme/preloader-recovery/`. The manifest there binds the two hashes, the backup file name, the DDR hash, and the Nov 02 SPL banner. It is not a signature. The same source backup, a note, and a copy of the manifest are published on the boot FAT through `zlyme-boot-write`. This command does not erase or program NAND. `disarm-recovery` restores that saved source only after it regenerates the recovery image from the file and the result is byte-for-byte the live preloader. It uses the same erase, write, readback, and rollback path. A failed write puts the recovery image back. `arm-recovery` takes no pathname. It refuses unless the live preloader, the saved source, the derived image, and the FAT backup, manifest, and note all describe the same source, and `/boot` is already read-only. It then writes that derived image through the same path and does not reboot. A failed arm writes the source back. `restore` does not read `preloader-current-*.img`.

On 2026-10-08, Linux was still running the installed root `b0b3a062eeb52511558f9fffaefade400a3c5f54eb4979cd838a3eda32df6861` (`zlyme44.2 (2026-10-07)`, candidate `fd57d042a890`). A temporary copy of `arm-recovery` wrote the derived image. Battery capacity was 100%. `/sys/class/power_supply/battery/status` read `Discharging` while `/sys/class/power_supply/charger/online` was `1`, which is the charger bit the command accepts. Bad blocks stayed 0. `/boot` stayed read-only. The full `/dev/mtd0ro` readback was `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367`. `disarm-recovery` then restored `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`, and that readback matched the saved source byte for byte. Each command used one erase and one `nandwrite`. The kernel log added no MTD or ECC error. UART stayed silent. The board was not rebooted.

Later the same day, with the recovery image installed and a known-good Zlyme card in the right slot, serial showed the vendor DDR and SPL, `Trying to boot from MMC2`, Zlyme U-Boot, and Zlyme Linux. NAND stayed `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367`. The installed `disarm-recovery` then restored `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. With the recovery image installed and the right card removed, the same SPL tried only MMC2, printed `Card did not respond to voltage select`, `mmc_init: -95`, `SPL: failed to boot from all boot devices`, and `# Reset the board to bootrom #`. The host saw USB `2207:350a`. No MMC1, NAND, MTD, or SPI boot source was attempted. A later `xrock flash` loaded a RAM usbplug to identify the NAND and did not write it. Those loader lines are not preloader behavior. These two hashes are this unit's pair, not a universal allowlist. After that experiment the right card was inserted, Zlyme booted, and `disarm-recovery` restored the same source again. `/boot` stayed read-only. The board was not rebooted after that restore. This does not accept Phase 11C. The card's U-Boot at that moment was still the diagnostic `CONFIG_BOOTDELAY=5` build. Later the same day `zlyme-update uboot` installed the production image. Raw readback matched idbloader `2312107bacc63dacb00f333cec93852d46620ddf015ca054bb767e3adf163719` and FIT `38dd59c86c8f4f7745a38cd555a73c2dfe3378ff275ff13ad3565d1bef29b6ee`, the build whose configuration is `CONFIG_BOOTDELAY=-2`, and Linux booted. That accepts the bootloader install. `status-machine` on the installed closure root still exited 2 with no output, so Phase 11C stays open.

Later on 2026-10-08 the status collector was fixed and the stock fallback was restored. The installed root `b61cb24b4712c375cd7b56d0c6e5932e2b55b46fd47d3b81cc87ca8e0e7be7a0` reported `preloader=valid`, `mode=normal`, `recovery=ready`, `source_backup=available`, `stock_restore=available`, `backup=unavailable`, and `fallback=compatible`, with NAND still `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. Recovery was armed again for the closure UART capture. The no-card log repeated the MMC2 failure and the BootROM reset three times, and the host saw `2207:350a`. The right-slot log then ran from DDR through `zlyme login:` on the production U-Boot, with no countdown. Disarm restored the saved source byte for byte. Restore stock was available and was not executed. Those two logs are `logs/boot_log_ZLYME_recovery-preloader-maskrom-20261008.txt` and `logs/boot_log_ZLYME_right-slot-normal-20261008.txt` in the hardware wiki. The sentence above that leaves Phase 11C open is the state before this closure.

On 2026-10-07 the maintainer ran `restore` on a Flip at 27% with the charger online. The tool saved the current preloader, erased `/dev/mtd0`, wrote the full 2 MiB backup, reported `restored original preloader`, and a later `status` recognized that backup. That run does not accept Phase 11C. The same day `flash_erase` completed and the board did not enter USB MASKROM, because a bootable card was present. `Preloader Recovery.pak` did not work and is not the UI.

The boot-file helper `zlyme-maskrom` and U-Boot `my355 maskrom-request` were removed. They wrote `/boot/zlyme-maskrom.request` and asked for an ordinary restart so U-Boot could call `rbrom`. That path is not the recovery preloader, and it is not shipped. A leftover `/boot/zlyme-maskrom.request` is inert. `rbrom` remains a manual U-Boot command. `erase-preloader` remains the separate CLI erase. It is not deterministic MASKROM.

On 2026-10-07 a fresh `zlyme.img` in the right-hand slot was booted from stock. Stock ran the included `miyoo355_fw.img`, the installer rebooted, and Zlyme came up. `/boot/zlyme` was `14b2cd609ba37d66a6414627026af2da30001064429674d16aaa0def5bf97a03`. That accepts the stock-assisted fresh-install path only. The same image's Recovery confirmations were checked: Cancel stayed the default on both restore confirmations and both MASKROM confirmations, and the final labels were `RESTORE STOCK PRELOADER` and `REBOOT TO MASKROM`. The preloader status overlay was hard to read. Selecting `REBOOT TO MASKROM` turned the screen black. The host did not see USB `2207:350a`. A physical reset booted Zlyme again. The preloader was not erased.

A later serial diagnostic on that same root ran `sync` and `/usr/sbin/zlyme-maskrom` once. The kernel logged `Restarting system with command 'maskrom'`. UART then stayed silent for more than four minutes: no DDR line, no SPL, no U-Boot. The host still did not see `2207:350a`. Before the command, `PMUGRF_OS_REG0` was `0x5242C300` and `/sys/class/udc/fcc00000.usb/state` was `not attached`, so the missing USB id does not by itself prove the boot ROM stayed out of download mode. The run does prove the command reached the kernel and that a normal loader did not print. A normal reboot prints DDR. A physical reset was required. That direct Linux PMUGRF and CRU restart is a failed product path. The kernel driver and the `maskrom` restart command were removed. They are not a fallback. The boot-file request that followed them was also removed. Phase 11C stays open.

Later the same day the maintainer wrote the image from `0e09c31933bd5c429e5f24238307838717231c28`. The fixed preloader status page was readable and the previous text overlap was gone. Reboot to MASKROM wrote `/boot/zlyme-maskrom.request`, rebooted, and returned to Zlyme with that file still present. The uploaded logs are normal boots. They do not show U-Boot inspecting the request. The surviving file means that consumer did not consume it. That U-Boot opened `mmc 0:2`, the `sdhci` alias, so `rbrom` was not reached. That test does not classify `rbrom` as failed. The request consumer was later removed and was not run on a Flip. A leftover `/boot/zlyme-maskrom.request` does not select a boot path.

## First-boot resize

The storage partition is seeded small in the image and grown on first boot.

A critical historical finding:

- do not run `partprobe` in the dangerous first-boot resize sequence while the live boot FAT is mounted;
- the proven sequence grows/reformats storage and reboots;
- protect the boot FAT from unnecessary partition-table reprobe activity.

Treat this as filesystem-integrity-sensitive code. `S13resize` runs only when the mounted `/boot` and `/storage` are the primary nodes in Boot identity and the storage label is `ZLYME`. Otherwise it leaves `autoresize=true` and does not partition or format. That guard is host-tested and awaiting Flip validation.

## Persistent state

The root filesystem is read-only.

Application and system configuration on the OS card lives under:

```text
/storage/.config
```

Examples are `/storage/.config/zlyme` (policy, including whether Samba is enabled), `/storage/.config/syncthing`, and `/storage/.config/<application>`. A NextUI-owned subtree is used only where NextUI actually owns that state.

Per-library user content stays on that library: `Roms`, `Saves`, and `Bios`. User media such as `/storage/Music`, `/storage/Podcasts`, and the Cheats directory is content, not configuration. Transient data belongs in `/run` or `/tmp`. Samba's private database stays `/tmp/samba-lib` because exFAT has no POSIX mode bits. Logs are described below.

`/storage` is SD card 1. A card in the second SD slot (`sdmmc1`, `mmc@fe2c0000`) is mounted at `/mnt/sd2` and shown as SD card 2, including when the card is blank. USB disks are mounted at `/mnt/media/<label>` and shown as `USB: <label>`. Slot identity does not depend on a `Roms` directory already being present.

`/storage` is exFAT. Shutdown syncs it and unmounts it with a normal `umount` before `reboot -f` or `poweroff -f`. Filesystem repair is an offline maintenance operation.

Important classes include:
- Zlyme flags;
- Wi-Fi configuration;
- RetroArch configuration/options;
- NextUI settings;
- SSH host keys;
- Bluetooth state;
- saves/BIOS/ROM libraries;
- optional logs;
- OTA staging.

Do not introduce mutable state into squashfs paths.

## Logs

Every boot, `rc.late` copies `/tmp/boot-timing` to `/storage/.config/zlyme/boot-timing` and `/tmp/nextui.txt` to `/storage/.config/nextui/my355/logs/nextui.txt`. It repeats the copy every 5 s for 30 s after the first frame, whatever the log setting. A boot that hangs the panel still leaves those two files on the card.

Full logs are off by default. Settings → System → Advanced → System logs turns them on. With logs on:

- `zlyme-logs` keeps five boot generations, `/storage/.logs/system-0` through `system-4`. `system-0` is the newest. It holds a kernel log snapshot and the session log `session.txt`.
- Each PAK keeps its last three launches as `/storage/.logs/paks/<tag>.log`, `.log.1`, and `.log.2`.
- The initramfs writes its kernel log to `/boot/zlyme-dmesg.txt` and `/storage/.logs/dmesg-init.txt`.

With logs off, the session log stays in `/tmp`.

## Boot classes

`rcS` is the frontend-critical path.

`rc.late` starts optional/background work after the frontend first-frame gate.

Do not move Wi-Fi, Bluetooth, SSH, NTP, Samba, Syncthing, broad udev coldplug, or similar work back onto the critical path without measuring the impact and proving a dependency.

The OTA apply step is exceptional: when an update is pending, it must not be forked in a way that allows NextUI to appear and then be abruptly rebooted underneath the user.

## GPU

The Miyoo Flip can use:
- Panfrost/Mesa;
- vendor Mali/libmali.

The default is libmali (`mali_kbase`). Settings → System → Advanced → GPU writes `/storage/.config/zlyme/gpu`. `S15gpudriver` reads it and loads one stack before the frontend.

They cannot bind the GPU simultaneously.

Switching stacks is a reboot-level change.

`gpudriver` (`package/system/gpudriver`) selects the stack. `zlyme-governor` (`package/system/nextui/zlyme/governor.sh`) sets the CPU, GPU devfreq, and DMC profiles. Both contain RK3566/my355 knowledge but live under `package/system`, not `board/my355`. `docs/DEVICE_PORTING.md` records that seam.

Do not generalize this dual-stack model into a requirement for future boards.

## Audio

Local codec ALSA ID:

```text
rk817ext
```

Speaker/headphones share the RK817 codec route.

`zlyme-jackd` follows the headphone jack and changes `Playback Mux`.

Every sink uses the one softvol control `FlipVolume`, hosted on `rk817ext`.

HDMI and Bluetooth are separate sinks.

Always use stable ALSA card IDs rather than assuming numeric card order.

## Wi-Fi and Bluetooth

The Miyoo Flip uses the RTL8733BU USB combo chip: Wi-Fi driver `8733bu`, Bluetooth firmware `rtl8723fu`. `rtl8733bu_power` owns the chip's power and rfkill.

Wi-Fi and Bluetooth share power/firmware interactions. Module/startup ordering is not arbitrary. `btusb` loads only after `8733bu` (`rtl8733bu-combo.conf`). That needs real kmod, because BusyBox modprobe ignores `blacklist` and `softdep`. Both radios start from `rc.late` after the first frame.

Do not remove the my355-specific module ordering/blacklist behavior as generic cleanup unless the hardware interaction has been revalidated.

Networking must remain non-critical for frontend startup.

## Input and lid

The built-in pad is the out-of-tree `miyoo-flip-gamepad` driver, input device `Miyoo Flip Gamepad`. It loads early from `modules-load.d`. `rc.late` restores its calibration, deadzone, and rumble gain after the first frame.

InputPlumber starts after the first frame. It owns each player controller as one composite and exposes one virtual `xb360` pad per controller. `zlyme-input` orders the players and enables management. Applications use the virtual pads, not `Miyoo Flip Gamepad`.

Settings → System → Joysticks is the physical-maintenance exception. It releases only the built-in composite for calibration, deadzone, and rumble, then reclaims it on exit.

Volume keys, the power key, and the lid switch are separate evdev devices and stay outside InputPlumber. NextUI handles them while it is on screen. `zlyme-keylidmon` handles them while a PAK runs.

Do not hardcode `/dev/input/eventN`.

Use names/capabilities/stable interfaces.

## Suspend

Every suspend is Linux `mem` sleep, and `mem` is BL31 deep suspend (`/sys/power/mem_sleep` reads `s2idle [deep]`). The node, masks, rail policy, entry paths, and radio ordering are in `docs/ARCHITECTURE.md` ("Sleep and suspend" and "Deep suspend"). Use the power button to suspend. In a PAK, closing the lid blanks the screen and stops the radios. It does not enter `mem`.

Published `zlyme44` clears the RTC wake alarm and then programs a 24-hour relative alarm before every `mem`. That was software policy left from suspend testing, not a Miyoo Flip hardware sleep limit. A full 24-hour suspend was not a hardware-acceptance test. The power button, volume keys, and lid open remain the normal wake sources. The current `zlyme44.1` source does not read, clear, or program `/sys/class/rtc/rtc0/wakealarm`, so an alarm programmed on purpose survives suspend. RTC wake stays available. `zlyme44.1` is device-accepted at `6a398b311310246ef6a5515ed72805c6f58d787d` and is not published. The acceptance record is in `docs/MAINTENANCE.md`.

Phase 6 hardware acceptance (`docs/ROADMAP.md` section 6, accepted runtime `b709719aac5c5540394d0369e5e06981b8aa00bc`) covered repeated power-button cycles, suspend from the NextUI menu, and suspend in game. Display, audio, the built-in and virtual pads, `/storage`, Wi-Fi and SSH, DMC devfreq, and `mali_kbase` recovered. Each Phase 7 image repeated one physical deep suspend. Standby current, long cycle counts, USB-host and Wi-Fi/Bluetooth combinations, and a lid-specific deep-suspend test were not part of that acceptance.

Check a suspend with:

```sh
dmesg | grep 'res.a0='
```

An `xHC error in resume, USBSTS 0x401, Reinit` line is the USB Wi-Fi device recovering.

A suspend started over SSH with `echo mem > /sys/power/state` bypasses NextUI. NextUI then does not ignore the wake press, so it can suspend a second time. Use the power button to test the real path.

The archived Zetarancio/distribution ROCKNIX fork left its own deep-suspend patches disabled (`.testing-disabled`). Its behavior is not Zlyme evidence. The hardware detail, including the `vdd_logic` and `ARMOFF_LOGOFF` constraint, is in the device wiki: [suspend-and-vdd-logic.md](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/drivers-and-dts/suspend-and-vdd-logic.md).

## DRM ownership

NextUI and direct-KMS applications may own DRM master at different times.

Application launch/exit must leave DRM in a state where the next client can acquire it.

The regression check for an application-scoped display stack is:

```text
frontend -> compatibility app -> frontend -> compatibility app -> frontend
```

After the app exits, NextUI must be able to take DRM again. No temporary Weston, WestonPack, or Xwayland process should remain.

PortMaster may mount WestonPack at `/tmp/weston` for one port. MENU+START can kill that port's process group, so NextUI's session cleans the mount, including binds underneath it, before the frontend resumes. A later boot should not show a WestonPack, `seatd`, or Xwayland process left from that launch.

PortMaster itself is not started at boot. `zlyme-portmaster-prepare` runs when the PortMaster tool or a port is launched. It unpacks `/usr/share/portmaster/PortMaster.zip` onto the selected library only when that library has no valid PortMaster tree. Reset PortMaster is `zlyme-reset portmaster`. It removes that tree and PortMaster's config, keeps `Roms/Ports (PORTS)`, and leaves the next launch to unpack the seed. A selected card that is not inserted is an error. The command does not reset `/storage` instead.

Wine's prefix directory is `/storage/.config/nextui/<platform>/wine-prefix/`. `zlyme-wine-prefix prepare` creates it, creates `drive_c`, copies any missing Wine PE builtins into `system32` and `syswow64`, copies the x86 WinSxS common-controls `comctl32.dll` when that assembly file is absent, mounts a 1 MiB tmpfs on `dosdevices`, and links `c:` to `../drive_c` and `z:` to `/`. `cleanup` stops the wineserver for that prefix and unmounts `dosdevices` only when `/proc/mounts` shows a tmpfs on that exact path. The session calls `cleanup`, because MENU+START can kill the pak before a launcher trap runs. Prefix files on the card stay. An update removes `/storage/.config/nextui/my355/wine-prefix.ext4` when that file is present.

Resource cleanup is part of compatibility.

## Updates

OTA artifacts are named `zlyme-my355-*` and carry the my355 DTB. `zlyme-update status` prints:

- `storage=`;
- `queued=yes` with the queued tar path and, when staged, `pending=<VERSION>`, or `queued=no`;
- `failed=` when a failure file exists;
- `reapply=yes` when the governor, LED, and zram settings have not yet been reapplied after an OTA;
- `pending/zlyme=yes (reboot to commit)` when a reconstructed or extracted root is waiting for reboot;
- `root=squashfs-file` when `/boot/zlyme` is present, otherwise `root=other`.

Settings selects a delta only when `from_sha256` equals the SHA-256 of the installed `/boot/zlyme`. Otherwise it uses the full OTA. A baseline release has no deltas. Reconstruction writes the new root under `/storage/.update/reconstruct` and moves it to `/storage/.update/pending/zlyme` only after the hash and size match. `/boot/zlyme` stays the running system until initramfs copies the pending file on reboot. Kernel, DTB, and overlays are written to the boot volume at apply time. A routine OTA does not rewrite U-Boot. `zlyme-update uboot` is a separate command. It writes only the primary card, and only when `/boot` is that card's boot partition and the disk reports 512-byte logical sectors. Host checks do not write. On 2026-10-08 `zlyme-update uboot` wrote the production idbloader and FIT on this unit's right-hand card. The raw card bytes matched that build, and the later UART log shows `U-Boot 2026.01` with no boot-delay countdown.

`test-stage` is not a user command. It runs only when `ZLYME_UPDATE_TEST=1`. It uses the same stage path, so it can create `/boot/zlyme-splash.progress` for the duration of the run. That flag is not a root or kernel write. A test `pending` directory must be removed before any reboot. Do not leave a test tar under `/storage/.update`, where a reboot can queue it.

On the 1 GiB Flip, a root-sized `--patch-from` decode has to map the installed squashfs (`--mmap-dict`). The same decode without that flag mallocs a second copy of the root and was OOM-killed. `--memory=2048MB` only raises the window cap. It does not allocate 2 GiB by itself.

A tar is structurally acceptable only when `tar -tf` itself exits 0 and the complete listing contains the required members. A listing that prints those names and then fails is rejected before extraction. An incomplete download stays `*.tar.part`, which this script ignores. Failure leaves `FAILED` and does not replace `/boot/zlyme`. Clear a known failed attempt before starting another, and do not delete an unexplained failure just to retry. Bootloader writes stay a separate explicit operation with a checked target. Recovery is a new full OTA or the existing boot files, not an in-place patch of the live squashfs.

## Performance checks

For performance-related changes capture more than average FPS.

Useful measurements:
- first-frame boot time;
- p95/p99 frame time;
- audio underruns;
- temperature/throttling;
- CPU/GPU/DMC frequencies;
- battery/power behavior where practical.

Keep thermal protection enabled.

## Live-device truth

A source build and a device test are different states.

When documentation says something is proven on hardware, preserve the distinction between:
- built;
- booted;
- launched;
- tested;
- stress-tested.

Do not turn a newly integrated compatibility path into a supported feature merely because binaries exist.


## Hardware-wiki invariants

The Miyoo Flip hardware wiki is canonical for the following details.

Do not regress these while pruning kernel patches:

- upper USB-C host needs `usb2phy1_otg`, EHCI, OHCI, `vcc5v0_host`, and the OHCI PHY clock;
- both SD slots share `vqmmc`, so mixed 1.8 V / 3.3 V operation is not a supported assumption;
- RK817 off-state drain requires patch `0007`, which clears `SYS_CAN_SD`;
- VDD_CPU is RK8600 (`rk8600@40`) on the retail units this tree supports;
- DMC devfreq is the external module `rk3568_dmc` (`package/drivers/rk3568-dmc`), autoloaded from `rockchip,rk3568-dmc`. It uses the RK3568 V2 SIP protocol;
- `vdd_logic` off-in-suspend requires `ARMOFF_LOGOFF` in the BL31 mode mask.

Patch `0030` logs the RK817/RK809 ON and OFF source registers with `dev_info` at MFD probe:

```sh
dmesg | grep -E 'ON_SOURCE|OFF_SOURCE'
```

That line is only a read of those registers. It helps distinguish boot and shutdown histories. No runtime policy parses it. It does not write a PMIC register, and it does not change shutdown or `SYS_CAN_SD`. Treat the register values as diagnostic evidence. They do not replace a direct physical-current measurement.
