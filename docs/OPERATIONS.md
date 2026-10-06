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

The squashfs root is a file on `ZLYMEBOOT`.

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

Settings selects a delta only when `from_sha256` equals the SHA-256 of the installed `/boot/zlyme`. Otherwise it uses the full OTA. A baseline release has no deltas. Reconstruction writes the new root under `/storage/.update/reconstruct` and moves it to `/storage/.update/pending/zlyme` only after the hash and size match. `/boot/zlyme` stays the running system until initramfs copies the pending file on reboot. Kernel, DTB, and overlays are written to the boot volume at apply time. A routine OTA does not rewrite U-Boot. `zlyme-update uboot` is a separate command. It writes only the primary card, and only when `/boot` is that card's boot partition and the disk reports 512-byte logical sectors. Host checks do not write. A Flip write has not been run.

`test-stage` is not a user command. It runs only when `ZLYME_UPDATE_TEST=1`. It uses the same stage path, so it can create `/boot/zlyme-splash.progress` for the duration of the run. That flag is not a root or kernel write. A test `pending` directory must be removed before any reboot. Do not leave a test tar under `/storage/.update`, where a reboot can queue it.

On the 1 GiB Flip, a root-sized `--patch-from` decode has to map the installed squashfs (`--mmap-dict`). The same decode without that flag mallocs a second copy of the root and was OOM-killed. `--memory=2048MB` only raises the window cap. It does not allocate 2 GiB by itself.

Failure leaves `FAILED` and does not replace `/boot/zlyme`. Clear a known failed attempt before starting another, and do not delete an unexplained failure just to retry. Bootloader writes stay a separate explicit operation with a checked target. Recovery is a new full OTA or the existing boot files, not an in-place patch of the live squashfs.

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
