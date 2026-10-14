# Zlyme architecture

## 1. Scope

Zlyme is a Buildroot-based gaming appliance operating system.

The only supported device is the Miyoo Flip, identified inside the project as `my355`, using Rockchip RK3566 / Cortex-A55 hardware.

The repository is structured so other hardware can be added later, but code must not pretend that other devices are already supported.

The portability rule is:

> isolate Miyoo Flip implementation details; do not invent generic hardware implementations.

This document describes the current design and who owns each subsystem. Operator procedures are in `docs/OPERATIONS.md`. Build commands are in `docs/DEVELOPMENT.md`. Release, patch, and upstream-intake policy is in `docs/MAINTENANCE.md`. `docs/ROADMAP.md` and `docs/LOGBOOK.md` record plans and history, not the current design.

## 2. Major layers

```text
Buildroot 2026.08
  +
Zlyme BR2_EXTERNAL
  |
  +-- configs/                  product configuration
  +-- package/                  reusable software packages
  +-- board/my355/              Miyoo Flip implementation
  +-- scripts/                  host/developer tools
  |
  v
BootROM / Miyoo SPI-NAND preloader
  v
BL31 + U-Boot (u-boot.itb)
  v
Linux
  v
embedded initramfs
  v
read-only Zlyme squashfs
  v
BusyBox init
  v
NextUI
  v
PAK / RetroArch / standalone / PortMaster application
```

## 3. Buildroot boundary

Zlyme is a `BR2_EXTERNAL` tree named `ZLYME` (`external.desc`).

Upstream Buildroot is not modified. `build.sh` pins Buildroot `2026.08` (a shallow clone of that git tag) and runs Buildroot inside the `zlyme-build` Docker image built from `Dockerfile`. Zlyme adds packages through `Config.in` and `external.mk`, target configurations through `configs/`, and board integration through `board/`.

`Config.in` offers one device choice, `BR2_ZLYME_DEVICE_MY355`. That choice sets `BR2_PACKAGE_NEXTUI_PLATFORM="my355"`.

There are two defconfigs. `zlyme_my355_defconfig` is the product image. `zlyme_my355_minimal_defconfig` leaves out the frontend, emulators, and Mali stack, and is the `build.sh` default.

The global `external.mk` stays small. It includes every `package/*/*/*.mk`, includes `board/my355/board.mk` only when `BR2_ZLYME_DEVICE_MY355=y`, and holds cross-package workarounds that are not board-specific (Mesa without LLVM draw, SDL2 Vulkan, libclc's unwrapped clang, the Python sysconfigdata fix).

Miyoo Flip-only Linux and U-Boot hooks live in `board/my355/board.mk`, not in the global file.

Kernel and U-Boot patches come from `BR2_GLOBAL_PATCH_DIR` in a fixed order: `board/my355/linux/patches/10-mainline`, `20-rk3566`, `30-default`, then `board/my355/uboot/patches`. The order is load-bearing. The same directories carry `linux.hash` and `uboot.hash`. `40-kernel-7.0` held the DualSense Edge paddle patch until Linux 7.2.10, which already reports those buttons. That directory is no longer in the patch path.

## 4. Device boundary

### Supported device

```text
device id:       my355
product:         Miyoo Flip
SoC:             Rockchip RK3566
CPU:             4x Cortex-A55
kernel DTB:      rk3566-miyoo-flip.dtb
NextUI platform: my355
```

### Build-time device contract

A board directory provides:

```text
board/<device>/
├── board.mk                 Linux and U-Boot Buildroot hooks, including the U-Boot .config hook
├── fsoverlay/               hardware/runtime policy for the device
│   └── usr/share/zlyme/device.conf   stable device metadata
├── linux/                   kernel config and fragment, DTS, patches, overlays, out-of-Kconfig sources
├── uboot/                   U-Boot control DTS and patches
├── extlinux.conf            U-Boot boot entry
├── genimage.cfg             boot/storage image layout
├── post-build.sh            board-specific target validation/finalization
├── post-image.sh            board image assembly
└── make-update-tar.sh       device update artifact
```

`board/my355` provides all of these. It also holds `zlyme-boot.conf` (boot flags on ZLYMEBOOT), the OTA hooks `pre-update.sh` and `post-update.sh`, and build helpers (`image-date.sh`, `assert-input-rootfs.sh`, `sdl3-stub.c` and `.map`).

Not every future board must have every file, but the board owns these responsibilities.

### Runtime device metadata

The board installs a shell-readable file from its overlay:

```text
/usr/share/zlyme/device.conf
```

For `my355` it describes stable identity rather than dynamic state:

```sh
ZLYME_DEVICE_ID=my355
ZLYME_DEVICE_NAME='Miyoo Flip'
ZLYME_SOC=rk3566
ZLYME_DTB=rk3566-miyoo-flip.dtb
ZLYME_NEXTUI_PLATFORM=my355
ZLYME_PORTMASTER_HW_DEVICE=miyoo-flip
ZLYME_UPDATE_PREFIX=zlyme-my355
ZLYME_OS_DISK=/dev/mmcblk0
ZLYME_BOOT_DEVICE=/dev/mmcblk0p2
ZLYME_STORAGE_DEVICE=/dev/mmcblk0p3
ZLYME_BOOT_LABEL=ZLYMEBOOT
ZLYME_STORAGE_LABEL=ZLYME
ZLYME_USB_GADGET_UDC=fcc00000.usb
```

`post-build.sh`, `post-image.sh`, `make-update-tar.sh`, `zlyme-update`, and the Settings release lookup read it. The initramfs carries the same file.

`ZLYME_OS_DISK`, `ZLYME_BOOT_DEVICE`, and `ZLYME_STORAGE_DEVICE` are the current my355 OS card. They are not a requirement that another board use MMC or these names. The right-hand slot is `sdmmc0`. The my355 DTS aliases `mmc0` to `&sdmmc0` and `mmc1` to `&sdmmc1`. Linux 7.2.10 uses that `mmc` alias as the MMC host index, and the MMC block driver names the disk `mmcblkN` from that index, so this tree makes the right slot `/dev/mmcblk0`. Pinned U-Boot `arch/arm/dts/rk356x-u-boot.dtsi` aliases `mmc0` to `&sdhci` and `mmc1` to `&sdmmc0`, so that same slot is U-Boot `mmc 1`. The SPL boot order stays `&sdmmc0`. `genimage.cfg` then places GPT partition 1 as `uboot`, partition 2 as `boot` (`ZLYMEBOOT`), and partition 3 as `storage` (`ZLYME`). The paths select those nodes. The labels confirm them. A cloned card repeats the labels, so boot, storage, resize, and raw bootloader writes do not search by label.

Only put values here that generic code genuinely needs.

Do not turn every hardware property into configuration data. If two devices need fundamentally different behavior, give each board its own implementation behind the same command interface.

### Known hardcoded `my355`

`nextui.mk` builds the NextUI workspace named by `BR2_PACKAGE_NEXTUI_PLATFORM`. Some code still names `my355` directly instead of reading `device.conf`:

- `nextui-session` exports `PLATFORM=my355` and `DEVICE=my355`, and copies stock PAKs to `/storage/Emus/my355` and `/storage/Tools/my355`;
- `S26keylidmon` and `rc.late` use `/storage/.config/nextui/my355`;
- `zlyme-update` requires the literal `DEVICE=my355` in a delta manifest, and the initramfs and `S18zlymeupdate` match `zlyme-my355-*` tar names;
- the release scripts (`scripts/zlyme_release.py`, `scripts/make-release-deltas.py`) write and check `my355`.

These are known exceptions to the device boundary. A second device must parameterize them.

### Runtime device command contract

Generic Zlyme and frontend code call stable commands when the feature exists:

```text
command             role                                   installed by
zlyme-audio         sink choice and volume CLI             board overlay
zlyme-governor      CPU, GPU, and DMC profiles, hotplug    nextui package (governor.sh)
zlyme-led           status LED policy and 0% shutdown      board overlay
zlyme-halt          shutdown and reboot                    board overlay
zlyme-ssh-auth      root SSH password and shadow bind      board overlay
zlyme-storage       library mounts and library list        board overlay
zlyme-usb-transfer  MTP session on the lower USB-C         zlyme-usb-transfer package
zlyme-update        OTA verify, stage, apply               board overlay
zlyme-boot-write    one write transaction on /boot         board overlay
zlyme-ctl           Settings and system flags, apply-*     board overlay
zlyme-proxy         application HTTP/SOCKS proxy           board overlay
zlyme-reset         Reset Settings, Factory Reset, and Reset PortMaster  board overlay
zlyme-portmaster-root  selected PortMaster library          board overlay
zlyme-portmaster-prepare  live PortMaster tree for this boot  portmaster package
zlyme-radios        radio stop and start around sleep      board overlay
zlyme-input         InputPlumber ownership and order       zlyme-input package
zlyme-drm-release   drop DRM master before a pak           nextui package
zlyme-weston-run    per-launch Weston for one client       board overlay
zlyme-wine-prefix   Wine prefix and dosdevices tmpfs    wine-amd64 package
gpudriver           GPU stack selection at boot            gpudriver package
```

Settings in the NextUI fork calls `zlyme-ctl`, `zlyme-proxy`, `zlyme-reset`, `zlyme-led`, and `zlyme-ssh-auth`. NextUI's sleep path and `zlyme-keylidmon` call `zlyme-radios`. `nextui-session` calls `zlyme-input ensure`, `zlyme-drm-release`, and `zlyme-halt`. `S15gpudriver` calls `gpudriver`.

Speaker/headphone routing is not a command. The `zlyme-jackd` daemon owns it. `zlyme-audio` reports and selects the sink.

`zlyme-governor` holds my355 knowledge: the RK3566 CPU OPP list, the DMC rates, and core hotplug. It is installed by the NextUI package from `package/system/nextui/zlyme/governor.sh`, not from `board/my355`. `nextui-session` applies `smart` before each `nextui.elf` start, which is the list and the return from a pak. Emulator PAKs call `zlyme-governor emu <tag>`. NextUI's my355 platform code sets `idle` on the way into sleep and `smart` in `PWR_exitSleep` when the frontend resumes. In a pak, `zlyme-keylidmon` sets `idle` around mem and then `resume`, which reapplies the pak profile in that same invocation. Applies are serialized with an exclusive `flock` on an empty file under `/run`. The kernel drops the lock when the process exits. `S27led` runs `zlyme-led watch`. That is the LED policy and the only battery monitor. It samples every 10 seconds. At 10% or below the red LED stays on and flashes about once a minute. Two consecutive numeric 0% readings call `zlyme-halt poweroff` when no non-battery supply has `online` of 1. A missing or non-numeric capacity does not count. LED Off still runs that check. Charging colour still treats battery status `Charging` or `Full` as charging, including when `online` and status disagree. A late DMC probe and `zlyme-update reapply` call `resume`, which reapplies the profile already recorded. `zlyme-ctl apply-gov` still means frontend `smart`. It is a manual or reset action; no boot service calls it.

For the Miyoo Flip, these implementations may know about RK817, DMC, VOP2, GPIOs, regulator overlays, and the RTL8733BU.

Generic callers should not.

A future device can provide another implementation of the same command where the semantics are truly shared. `docs/DEVICE_PORTING.md` states the semantics of each command.

## 5. Boot architecture

### Boot chain

```text
RK3566 BootROM
  v
Miyoo SPI-NAND preloader: DDR init and SPL
(a card booted by the BootROM alone uses Zlyme idbloader.img at 32 KiB:
 TPL rk3566_ddr_1056MHz_v1.23 + SPL)
  v
u-boot.itb at 8 MiB: BL31 rk3568_bl31_v1.44 + U-Boot 2026.01
  v
extlinux/extlinux.conf on ZLYMEBOOT
  v
Image.gz + rk3566-miyoo-flip.dtb + FDTOVERLAYS
  v
Linux 7.2.10 with the embedded Zlyme initramfs
  v
mount /dev/mmcblk0p2 read-only when its label is ZLYMEBOOT, then /dev/mmcblk0p3 when its label is ZLYME
  v
if ZLYME/.update/pending/zlyme exists: open /boot read-write,
copy it over /boot/zlyme, run pending/post-update.sh, close /boot read-only
  v
refuse to continue unless /boot is read-only
  v
loop-mount /boot/zlyme read-only, refuse to continue unless the loop is read-only
  v
switch_root
  v
BusyBox init
  v
rcS: Class A boot work
  v
NextUI first frame
  v
rc.late: Class B services in background
```

The TPL and BL31 come from rkbin and must be a matching pair. On a normal boot the Miyoo preloader has already done DDR init and SPL, so only BL31 from that pair runs. No OP-TEE is built.

U-Boot is mainline 2026.01 from the `quartz64-a-rk3566` defconfig. The `board.mk` hook switches it to the local Flip control DTS, sets `BOOTDELAY=-2`, adds the preboot `my355 fg` (U-Boot patch `006`), and strips PCI, SATA, NVMe, Ethernet, SDHCI, and USB. U-Boot patch `002` sets the SPL boot order to `sdmmc0`. Patch `007` adds `rbrom` and does not change `BOOTDELAY`. The boot-FAT MASKROM request and its preboot hook were removed. They are not a product path.

The kernel command line is `earlycon quiet console=ttyS2,1500000n8`, with `console=` last so serial is `/dev/console`. It does not carry a `label=` key. The initramfs selects `/dev/mmcblk0p2` from device metadata and checks the filesystem label. `zlyme-ctl apply-overlays` writes the `FDTOVERLAYS` line from Settings flags: the HDMI, OTG, and SD2 disable overlays and the CPU undervolt level.

The initramfs is a static BusyBox `1.36.1` `/init` that `board.mk` embeds through `CONFIG_INITRAMFS_SOURCE`. It also starts the framebuffer splash, and writes a boot dmesg when `/boot/zlyme-logs` asks for one. That is the only other reason it opens `/boot` read-write.

Routine OTA never rewrites `idbloader.img` or `u-boot.itb`, and it does not copy `miyoo355_fw.img` onto the boot FAT. Only an explicit `zlyme-update uboot` rewrites the card bootloader.

A fresh `zlyme.img` places `miyoo355_fw.img` at the root of `ZLYMEBOOT`. That file is apommel's stock installer, generated by `tools/preloader-installer/mkfwimg.py` from pinned `apommel/baseos-my355` commit `e09d37bb0f03c34e564d61bd02164f332d8515a8` (`package/boot/my355-fw-installer`). It is not a preloader binary. Stock firmware, not Zlyme, reads it, backs up that unit's own preloader as `mtd5-original-<sha256>.img`, patches `/pinctrl` in the SPL device tree, and writes the result back. Flashing `zlyme.img` does not modify NAND by itself.

The same package also writes three standalone images next to the card image: `miyoo355_fw-multiboot.img` (byte-identical to `miyoo355_fw.img`), `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`, each with a `.sha256`. Stock's `runmiyoo.sh` looks for the literal name `miyoo355_fw.img`, so a downloaded helper has to be renamed to that before it is placed on a card stock can read. `board/my355/genimage.cfg` puts only `miyoo355_fw.img` on `ZLYMEBOOT`. The OTA tar does not contain any of them, and they are not roots in `release-manifest.json`. The MASKROM helper derives a right-slot-only preloader from the unit it is running on. The restore helper writes the one `mtd5-original-<sha256>.img` that helper, or the multiboot installer, saved on that card. It runs only while stock itself is running. It is the undo for the normal repaired preloader, not the way out of an armed recovery preloader. Neither image contains a preloader binary. After a verified write, each helper removes `miyoo355_fw.img`, writes `/tmp/fwupdate_done`, and leaves the stock updater running. It does not reboot. `CARDDEV` only locates the FAT volume the helper is already using. A stock `/dev/mmcblkN` name is not a physical slot. On stock `20250527210639`, one ordinary boot with only the physical left card inserted mounted that card as `/dev/mmcblk2p1` at `/media/sdcard1`. An earlier helper the same day, also from the physical left slot, classified its node as matching `/dev/mmcblk1p*`. A later Zlyme boot of the right-hand OS card showed only `/dev/mmcblk0`, with `/boot` on `/dev/mmcblk0p2` and `/storage` on `/dev/mmcblk0p3`. Those are separate runtime observations. None of them is a physical-slot map. On 2026-10-08 one Flip hardware-accepted the public helper paths for this unit: restore wrote `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` back to the saved original `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922`; the MASKROM helper wrote `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` to `f7d9a25255080ac19e88df88d1232bf45a90bdf2e86c9f7e23b73d32a003f367`; the same helper, started from that original stock image, applied the `/pinctrl` repair and wrote the same recovery image; Zlyme booted that recovery image from the right-hand slot; and `disarm-recovery` restored `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`. Each NAND write was one verified attempt, bad blocks stayed 0, and there was no rollback. The raw logs are in the hardware wiki. This acceptance is that unit's structure and source pair. It does not cover every vendor SPL revision, another unit's backup, or erase-preloader as MASKROM.

On Zlyme, the kernel exports only that 2 MiB region, DTS label `preloader`, so it is `mtd0`. The wiki's SPI NAND is ESMT, 128 KiB erase, 2 KiB pages, 64 B OOB. `zlyme-preloader` refuses any other identity. Settings → System → Advanced → Recovery shows preloader status, arms or disarms MASKROM recovery, or restores the stock backup. Status is read-only. Arm installs a recovery preloader derived from the image already in NAND. With that image installed, a bootable card in the right slot still boots. With no bootable card in that slot, the vendor SPL tries only `/dwmmc@fe2b0000`, fails, and resets into the boot ROM. Disarm writes back the exact source saved when recovery was prepared, and only when that source still derives the live image. The preloader commands themselves do not reboot. After a verified arm, disarm, or stock restore, Settings offers shut down or a normal restart. Restart does not enter MASKROM. Restore is the separate stock-preloader write. A failed NAND write rolls back and does not report success. `erase-preloader` stays CLI-only. It removes the SPI preloader. A finished erase is not USB MASKROM while another loader can boot, and it is not this recovery path. `CONFIG_BOOTDELAY=-2` is unchanged. On 2026-10-07 a direct Linux restart, which stored the download flag and wrote the CRU first reset from the kernel, reached `kernel_restart` on a Flip and then went silent: no DDR, no SPL, no U-Boot, and no USB `2207:350a`. A physical reset was required. That driver was removed and is not a fallback. A later boot-file request for U-Boot `rbrom` was removed as well. Stock U-Boot `rbrom` remains a manual command. None of this runs during an ordinary boot or an update. The image build also writes `miyoo355_fw.img.sha256` beside the installer. The OTA does not include either file.

A normal boot is BootROM, then the internal NAND preloader (DDR init and the stock SPL), then Zlyme U-Boot from the right-hand SD card, then Linux. The apommel repair makes that stock SPL read the card and load its U-Boot FIT. `rbrom` stores `BOOT_BROM_DOWNLOAD` and resets. BootROM loads the internal preloader again, and the early Rockchip SPL returns to BootROM download mode when it sees the flag. Zlyme does not replace the internal U-Boot, put a MASKROM loader in NAND, or erase the preloader in order to enter download mode.

On 2026-10-07 the maintainer wrote the image built from `0e09c31933bd5c429e5f24238307838717231c28`. The fixed preloader status page was readable. Reboot to MASKROM wrote the request, rebooted, and returned to Zlyme with `/boot/zlyme-maskrom.request` still present. The uploaded logs are normal boots and do not show U-Boot reading the file. The surviving marker means that consumer did not consume it. That build opened U-Boot `mmc 0:2` (`sdhci`). `rbrom` was not reached, so that test does not classify `rbrom` as failed. That request path was later removed. It is not the recovery preloader.

`status` and `status-machine` read one set of facts in the shell that identified the preloader device. The machine command prints those facts as `key=value` lines. It does not parse the human log. Restore writes the one valid `/boot/mtd5-original-<sha256>.img` when that file exists. That per-device backup wins over the bundled image. If it does not exist, restore may write the shipped `preloader-stock.img` only for the known pair: live image `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d` and stock image `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922`, after the structure check and a DDR check that runs before erase. Zlyme does not synthesize that stock image. The hardware wiki records it at `preloader-stock-rocknix/App/apommel-multiboot/preloader-stock.img`, commit `c126d3235face9ddca5bf021258a84758dca543c`, as the first 2 MiB of `spi_20241119160817.img`. `package/system/zlyme-preloader/preloader-stock.PROVENANCE` identifies the copy. There is no force switch. A backup whose DDR payload differs from the current preloader is refused. Disarm does not use the bundled file.

`prepare-recovery` reads the installed preloader, keeps that exact file as `preloader-current-<sha256>.img`, and derives the right-slot recovery image under `/storage/.config/zlyme/preloader-recovery/`. The manifest there records the source hash, the recovery hash, the backup file name, the DDR hash, and the Nov 02 SPL banner. It is not a signature. `disarm-recovery` may write the saved source back only after it rebuilds the recovery image from that file and the result matches the live preloader byte for byte. `arm-recovery` takes no image argument. It programs NAND only when the live image is still that source, the saved file matches it byte for byte, regenerating the recovery image matches the prepared file, and the FAT backup, manifest, and note match. `/boot` must already be read-only. It then uses the same write and rollback path as `restore`. `restore` still ignores `preloader-current-*.img`. On 2026-10-08 one Flip completed an arm and disarm cycle, then booted Zlyme from the right slot with the recovery image installed, then reached Rockchip download mode with that card removed. The closure UART logs for both of those boots are in the hardware wiki. Those hashes belong to that unit. `docs/OPERATIONS.md` records them. Phase 11 is closed. `zlyme44.2` is not a published release.

### First-frame gate

The first frontend frame is the meaningful boot-complete target.

Networking, Bluetooth, SSH, Samba, Syncthing, time sync, and similar optional services must not be prerequisites for that first frame.

`rcS` owns frontend-critical work. `rc.late`, started from `inittab` as `::once:` (added by `post-build.sh`), owns non-critical work after the first-frame gate.

NextUI writes `nextui-first-flip` to `/tmp/boot-timing` after its first flip. `rc.late` polls for that mark every 0.5 s for at most 20 s, so a hung frontend still brings SSH up. It then restores stick calibration and rumble gain, then starts Class B in the background. The first frame therefore comes before calibration and rumble gain are restored. Section 13 lists both classes.

## 6. Image and storage model

The Miyoo Flip image (`board/my355/genimage.cfg`) uses:

- raw `idbloader.img` at 32 KiB, outside the partition table;
- GPT `uboot` partition at 8 MiB, 4 MiB, holding `u-boot.itb`;
- FAT32 `ZLYMEBOOT` at 12 MiB, 1300 MiB, holding `Image.gz`, the DTB, `extlinux/`, `overlays/`, `zlyme-boot.conf`, the splash animations, and the root squashfs;
- exFAT `ZLYME` storage partition;
- no rootfs GPT partition;
- root squashfs (zstd, 1 MiB blocks) stored as a file named `zlyme` on `ZLYMEBOOT`.

The flashed `ZLYME` is a 32 MiB exFAT seed. A fresh `zlyme-boot.conf` has `autoresize=true`. On the first boot `S13resize` grows the storage partition (`sgdisk -e`, `parted resizepart 100%`), reformats it with `mkfs.exfat -L` set to `ZLYME_STORAGE_LABEL`, and runs `reboot -f`, but only when `/boot` and `/storage` are already the primary nodes above and the storage label is `ZLYME`. If that is not true, it leaves `autoresize=true` and does not format. The next boot that can prove the identity, and already sees a grown volume, comments out the trigger. `S15bootpart` mounts the primary storage node if the initramfs did not already move it to `/storage`. It does not seed a different card. It ensures the timezone file and seeds `.config`, `.update/`, and the default flags in the background. `docs/OPERATIONS.md` has the operator view.

`/boot` is read-only at runtime. The squashfs loop is backed read-only by `/boot/zlyme`, which lets the vfat be remounted without `EBUSY`. Every runtime write to `/boot` goes through `zlyme-boot-write`. One call is one transaction. It takes an exclusive `flock` on an empty file under `/run`, refuses a mount whose source is not the primary boot partition, and restores read-only before it opens the volume. It then remounts read-write, runs the command in the foreground, syncs, and remounts read-only. Catchable signals during that open transaction do not abort the write. The wrapped command's status is returned when read-only is verified. If read-only cannot be restored, a separate marker under `/run` refuses later transactions until reboot. `S12bootfs` also requires an already-mounted boot volume to be read-only before it reports success. The initramfs remains the normal-boot enforcement point.

The writable persistent filesystem is `/storage` (`ZLYME`). Frontend power-off and reboot exec `zlyme-halt`, which leaves `/boot` mounted, moves off `/storage`, and unmounts that exFAT volume with a normal `umount` before `reboot -f` or `poweroff -f`. A shell `poweroff` or `reboot` takes BusyBox's `::shutdown:` path (`rcK`, then `umount -a -r`) instead.

The root filesystem is read-only squashfs.

Persistent configuration belongs under:

```text
/storage/.config
```

That directory is the OS-card home for application and system configuration. Examples:

- `/storage/.config/zlyme` for Zlyme policy, including Samba's enable state;
- `/storage/.config/syncthing` for Syncthing's persistent home;
- `/storage/.config/<application>` for an emulator or tool, or a NextUI subtree that NextUI itself owns.

Mounted libraries are the lines in `/run/zlyme/libraries`. A USB library is `/mnt/media/<name>`, one directory under `/mnt/media`. Spaces in the label stay. `/` and control characters are replaced with `-`. `.`, `..`, and an empty result use the kernel device name. Two devices that sanitize to the same name do not share a mountpoint: the second is `/mnt/media/<name>-<device>`. The library list stores the decoded path, including a space that `/proc/mounts` wrote as `\040`. Content stays on the library that holds it:

- `$library/Roms` for games;
- `$library/Saves` for saves. Existing saves are searched on every mounted library. The game card wins a duplicate, and a new save is created on the game card;
- `$library/Bios` for BIOS files. The running game sees a union of those folders. A duplicate path uses the copy on the game card.

User media is not configuration. Music and podcasts stay `/storage/Music` and `/storage/Podcasts`. Installed cheats stay `/storage/Cheats`. ZcrapeGoat state stays `/storage/.config/ZcrapeGoat`.

Transient POSIX-only data belongs under `/run` or `/tmp`. Samba's private database stays `/tmp/samba-lib` because exFAT cannot store the mode bits that database needs.

Diagnostic logs are off by default. With the Settings `logs` flag on, `zlyme-logs` keeps five boot generations under `/storage/.logs`, `pak-log.sh` keeps three launches per PAK, and the initramfs writes a boot dmesg. With logs off, the session log stays in `/tmp`. Two files reach the card on every boot regardless of that flag: `rc.late` copies `/tmp/boot-timing` to `/storage/.config/zlyme/boot-timing` and `/tmp/nextui.txt` to `/storage/.config/nextui/my355/logs/nextui.txt` six times, 5 s apart, so a hung panel still leaves evidence after the card is pulled.

`/storage` remains exFAT. Wine's prefix is the directory `/storage/.config/nextui/<platform>/wine-prefix/`. `dosdevices` is a 1 MiB tmpfs (`size=1024k`): `c:` points at `../drive_c` and `z:` points at `/`. Those two links have to be symlinks, and exFAT does not keep them. `zlyme-wine-prefix prepare` creates `drive_c` before that link. The same filesystem drops the DLL symlinks wineboot would place in `syswow64` and `winsxs`, so `prepare` copies any missing PE builtin from the Wine 11.6 `i386-windows` and `x86_64-windows` trees, and the x86 common-controls `comctl32.dll` next to its manifest. The rest of the prefix is ordinary files on the card. An update deletes the exact file `/storage/.config/nextui/my355/wine-prefix.ext4` and does not open it. The kernel config already has `CONFIG_NTSYNC=y`. Wine 11.6 does not require NTSYNC. A dirty-unmount message from an earlier boot is not a reason to change shutdown: `zlyme-halt` already syncs and unmounts `/storage` with a normal `umount` before `reboot -f` or `poweroff -f`. Checking the volume is an offline maintenance step.

Image layout is a board concern. A future device may use another boot layout while preserving the higher-level Zlyme runtime contracts.

## 7. Update architecture

A published release may include `release-manifest.json` beside the full OTA. Settings (`github-release.py`) checks the manifest schema and fields, and rejects a manifest whose `device` is not `ZLYME_DEVICE_ID`. The SHA-256 of the installed `/boot/zlyme` selects the smallest delta whose `from_sha256` matches. No match means the full OTA. The displayed version string is not the selector. A baseline version publishes no deltas. Which earlier releases a point release builds deltas from is release policy in `docs/MAINTENANCE.md`.

`zlyme-update` picks up the tar named by a `WANT` pin (Settings writes one), or else the newest `${ZLYME_UPDATE_PREFIX}-*.tar` in `/storage/.update`. `S18zlymeupdate` applies it in Class A before NextUI starts, and `rcS` waits for it.

A delta tar carries `DELTA-MANIFEST` and `zlyme.patch.zst` in place of the squashfs member. Reconstruction runs under `/storage/.update/reconstruct`. The decoder uses the installed squashfs as a file-backed dictionary:

```text
zstd -d --memory=2048MB --mmap-dict --patch-from
```

The reconstructed file is kept only when its SHA-256 and size match the manifest. That file is `/storage/.update/pending/zlyme`. A `zlyme.new` file is not a pending update. `/boot/zlyme` is not patched in place.

Full and delta staging then share one commit path:

```text
update tar on /storage
  v
verify/stage into /storage/.update/pending
  v
run pending/pre-update.sh
  v
copy kernel/DTB/extlinux/overlays to ZLYMEBOOT through zlyme-boot-write
  v
zlyme-ctl apply-overlays, mark reapply
  v
reboot
  v
initramfs replaces /boot/zlyme and runs pending/post-update.sh
  v
rc.late runs zlyme-update reapply (governor, LED, zram)
```

Routine OTA does not rewrite U-Boot. The tar's `idbloader.img` and `u-boot.itb` are parked in `/storage/.update/bootloader/` for an explicit `zlyme-update uboot`. That command writes only when `/boot` is the primary boot partition on the primary disk, that disk's logical block size is 512 bytes, and the one `uboot` partition on that disk starts at LBA 16384 and can hold the payload. Host checks resolve the target and do not write. A Flip write is still untested.

A tar that fails the structural checks is deleted. A tar that fails to apply is moved to `/storage/.update/failed/`, `FAILED` records the reason, and the old root keeps running.

Artifact identity checks are narrow:

- automatic pickup needs the `ZLYME_UPDATE_PREFIX` file name; a `WANT` pin can name any tar;
- staging a full tar needs the `ZLYME_DTB` member, `Image.gz`, `zlyme`, and `VERSION`. A full tar has no device field;
- a delta needs `DELTA-MANIFEST` with `DEVICE=my355` (a literal in `zlyme-update`, not read from `device.conf`) and a `BASE_SHA256` equal to the SHA-256 of the installed `/boot/zlyme`, plus the DTB, `Image.gz`, and `VERSION` members;
- Settings rejects a release manifest for another device, as above.

A full tar is tied to a board only by its file name and its DTB member name. A second device must add a real device check before it shares this update path, so a my355 artifact is never accepted merely because it contains a member named `zlyme`.

## 8. Graphics

The normal graphics path is compositor-free:

```text
application
  v
SDL2 KMSDRM or EGL/GBM
  v
DRM/KMS
  v
Rockchip display hardware
```

Zlyme does not run a permanent X11 server, Wayland compositor, or desktop environment.

The boot splash runs on fb0. The initramfs starts it, `S12splash` restarts it from the squashfs, and it stops when `nextui-session` stops it or NextUI takes the panel through KMSDRM. Before every pak, `nextui-session` stops the splash, runs `zlyme-drm-release` to drop DRM master, and starts the pak in its own session.

Applications that cannot use direct KMS may launch an isolated compatibility environment for the duration of that application. Two cases exist.

Native Wayland clients use Zlyme's own per-launch Weston through `zlyme-weston-run`. `WINE.pak` is its only user. Wine 11.6 (`amd64-wow64`) runs there under Box64. That Weston build (DRM backend, kiosk shell) does not ship Xwayland and is not a boot service.

```text
NextUI releases DRM
  v
per-launch Zlyme Weston (zlyme-weston-run)
  v
native Wayland application
  v
application exits
  v
Weston exits
  v
NextUI reacquires DRM
```

PortMaster software that needs X11 uses PortMaster's own WestonPack, which brings Xwayland for that launch. WestonPack is application-scoped and stays owned by PortMaster. Its cleanup is Zlyme's: `nextui-session` runs `zlyme-portmaster-cleanup` before and after every `PORTS.pak` launch, outside the pak's process group, because the launcher `exec`s the port and MENU+START kills that group. The cleanup sends TERM to processes holding `/tmp/weston`, sends KILL after 6 s, and unmounts it. A mount through `zlyme-portmaster-exec` is recorded under `/run/zlyme-portmaster/owned-mounts` only when that command increases the mount count at its target. A remount is not recorded. The same cleanup unmounts only those recorded targets, deepest first, and unbinds `/roms/ports` through `zlyme-library.sh`. It does not unmount `/storage`, `/boot`, `/mnt/sd2`, `/mnt/media`, or a library root listed in `/run/zlyme/libraries`.

```text
NextUI releases DRM
  v
per-launch PortMaster WestonPack
  v
Xwayland/X11 application as required
  v
application exits
  v
zlyme-portmaster-cleanup (run by nextui-session)
  v
NextUI reacquires DRM
```

### Miyoo Flip GPU stacks

The Flip supports both:

- Mesa/Panfrost (OpenGL ES, plus PanVK in the product image);
- vendor Mali (`mali_kbase` + libmali, GLES and Vulkan).

They cannot own the GPU simultaneously. Selection is reboot-level policy.

The default is libmali. The choice is the flag `/storage/.config/zlyme/gpu`, which the Settings Advanced → GPU option writes and which takes effect on the next boot. A static `blacklist panfrost` in `/etc/modprobe.d/zlyme-gpu.conf` keeps udev from binding Panfrost before the flag is read. Class A `S15gpudriver` runs `gpudriver`, which reads the flag, bind-mounts a runtime blacklist for the other stack over that file, and loads one kernel module. For libmali it also bind-mounts the blob over the files behind Mesa's `libEGL.so.1`, `libGLESv1_CM.so.1`, `libGLESv2.so.2`, and `libgbm.so.1`, so applications link one set of names.

`/etc/zlyme-gpu-env.sh` exports one Vulkan ICD. libmali uses `/usr/share/vulkan/icd.d/mali_icd.json`. Panfrost uses `/usr/share/vulkan/icd.d/panfrost_icd.cortex-a55.json` (`libvulkan_panfrost.so`). Mesa names that manifest for the Buildroot CPU. The product image builds that driver. The minimal image builds Panfrost GLES and does not build PanVK. Mali-G52 is Panfrost architecture v7. Mesa 26.1.8 returns `VK_ERROR_INCOMPATIBLE_DRIVER` for that device unless `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1`. Zlyme does not set that variable. A built driver is not a device result: enumeration and rendering stay for a later hardware pass. GLES applications do not read the ICD variables.

This dual-stack mechanism is a Miyoo Flip/RK3566 implementation detail, not a requirement for every future Zlyme device.

## 9. Audio

Normal audio is ALSA.

For the Miyoo Flip:

- the local codec is the RK817, identified by stable ALSA card ID `rk817ext`. HDMI is a separate card;
- `/etc/asound.conf` defines three sinks: `flipsink_codec`, `flipsink_hdmi`, and `flipsink_bt`. The default PCM picks one from `$ZLYME_SINK` (default `codec`);
- codec and HDMI go through `dmix` at 48 kHz S16 so a UI sound can play over an emulator. Bluetooth goes straight to BlueALSA;
- every sink uses one softvol control, `FlipVolume`, hosted on `rk817ext`, so volume is one setting on every output. `S20alsa` restores `/storage/.config/asound.state`;
- `zlyme-audio` is the CLI. It stores the selected sink in `/storage/.config/audio.conf`, exports it for the session and paks, and sets `FlipVolume`;
- speaker/headphone switching is the RK817 `Playback Mux` control. `zlyme-jackd` (Class A) follows the headphone-jack evdev switch and sets it. It is not a user choice;
- Bluetooth audio uses BlueALSA;
- `zlyme-btsink` (Class B) picks the sink: an A2DP headset first, then HDMI when its ELD reports audio, then the codec. On a change it kills the frontend or the running emulator so it reopens the default PCM, except while `/tmp/zlyme-keep-emu` exists.

RK817 mixer names must remain inside the `my355` implementation.

A future board may expose the same `zlyme-audio` interface using completely different hardware.

## 10. Input, lid and handheld controls

The Miyoo Flip uses board-specific input integration:

- `miyoo-flip-gamepad` is the physical layer: UART sticks, GPIO buttons, calibration transform, radial deadzone, and `FF_RUMBLE` on PWM5 through ff-memless `FF_GAIN`. `S11modules` loads it from `modules-load.d` before the first frame;
- Settings owns calibration, deadzone, and displayed Rumble Strength. The files live under `/storage/.config/zlyme/miyoo-flip-gamepad/`, and `rc.late` restores them after the first frame. A missing or invalid `rumble.config` uses the displayed product default of 40% (`FF_DEFAULT_GAIN_PERCENT`), which the userspace curve in `ff_gain.c` maps to `FF_GAIN`. A saved `rumble.config` is kept. Fresh Haptic feedback is on. An existing `haptics=` value is kept. Haptic feedback only gates NextUI's own pulses;
- The retired ROCKNIX gamepad package is not part of the product. InputPlumber v0.81.0 starts after the first frame. Its device files `20-zlyme_miyoo_flip.yaml` (built-in pad) and `80-zlyme_external_gamepad.yaml` (external pads) set `auto_manage: false` and target `xb360`. `zlyme-input` then sets `ManageAllDevices` and keeps one composite per player controller. It re-enables management if InputPlumber restarts, and puts external controllers ahead of the built-in pad in player order. The built-in map sends D-pad buttons to hats, digital L2/R2 (`BTN_TL2`/`BTN_TR2`) to binary `ABS_Z`/`ABS_RZ`, and the printed A/B/X/Y buttons to Xbox A/B/X/Y on the `xb360` target. NextUI uses that virtual controller after it appears. Settings → Joysticks releases only the built-in composite, uses the physical pad, then reclaims it. MENU stays on that managed gamepad (`BTN_MODE` physically, Guide on the virtual pad). Volume, power, and the lid switch remain independent system inputs;
- lid switch (`gpio-keys-hall`, `SW_LID`);
- power key (RK817 `rk805 pwrkey`);
- volume keys (`gpio-keys-volume`) and MENU+volume brightness;
- NextUI `my355` platform code;
- `zlyme-keylidmon` while another application owns the screen. It is Class A because it hosts NextUI's msettings shared memory. Its MENU state comes from the virtual Guide button. Volume, power, and the lid stay on their own devices;
- `zlyme-pak-hotkey` exits a pak on MENU+START from one virtual controller. It does not combine those buttons across two controllers. It reads only InputPlumber `xb360` targets, so the MENU+START exit needs InputPlumber running.

These are board/platform responsibilities.

Frontend and emulator launch code should consume normal Linux input/SDL interfaces rather than Miyoo-specific sysfs or GPIO knowledge whenever possible.

### Sleep and suspend

NextUI owns sleep while `nextui.elf` is on screen. `zlyme-keylidmon` owns it while a pak owns the screen. Both use the same suspend helper and radio ordering.

- NextUI, power press: `PWR_sleepNow` mutes audio, turns the backlight off, sends `SIGSTOP` to `zlyme-keylidmon`, sets CPU powersave, syncs, runs `zlyme-radios pre`, then runs the suspend helper. Holding power for 1 s powers off instead.
- NextUI, lid close or screen timeout: `PWR_sleep` is hybrid sleep, with the screen and radios off while it waits for a wake input. After the suspend timeout it enters the same mem suspend, unless the device is charging or USB keep-awake applies.
- Pak on screen, power press: `zlyme-keylidmon` runs `zlyme-radios pre`, the suspend helper, then `zlyme-radios resume`, and ignores the wake press for 1 s.
- Pak on screen, lid close: `zlyme-keylidmon` stops the radios and blanks the screen until the lid opens. It does not enter mem suspend.

The suspend helper is `package/system/nextui/zlyme/suspend`, installed as `/usr/share/nextui/bin/suspend`. Published `zlyme44` clears any RTC wake alarm, then programs a relative alarm of 86400 s before it syncs and writes `mem` to `/sys/power/state`. That timer is software policy left over from the 2026-09-13 timed-suspend test (`083e8061c47354325e7356966541642bb3062cfe`). No Miyoo Flip hardware limit of 24 hours is documented, and a full 24-hour suspend was not part of hardware acceptance. Normal wake sources (power button, volume keys, lid open) are separate. Published `zlyme44.2` does not read, clear, or program `/sys/class/rtc/rtc0/wakealarm`. An alarm programmed on purpose is preserved. RTC support stays in the kernel, and an RTC wake remains a valid hardware wake source. That helper was device-accepted in the unpublished `zlyme44.1` source at `6a398b311310246ef6a5515ed72805c6f58d787d` and shipped in `zlyme44.2`. The acceptance record is in `docs/MAINTENANCE.md`.

`zlyme-radios pre` stops Bluetooth before Wi-Fi: it saves the BlueZ store, then stops `zlyme-btsink`, BlueALSA, `bluetoothd`, and Wi-Fi. Bluetooth goes first so `rtl8733bu_power` can cut the combo chip in its late suspend phase without hanging `hci_dev_close`. `zlyme-radios resume` starts Wi-Fi first, then `btusb`, `bluetoothd`, BlueALSA, and `zlyme-btsink`, reopens the DMC range once, and keeps `/tmp/zlyme-keep-emu` for 25 s so the combo chip's re-enumeration does not make `zlyme-btsink` kill the emulator. NextUI runs `zlyme-radios resume` in the background.

Kernel patch `9901` disables async suspend/resume by default. On the Flip, mem suspend is BL31 deep suspend (see "Deep suspend" below).

## 11. Frontend and PAK runtime

Zlyme is the OS. NextUI is the frontend.

ZcrapeGoat is the built-in artwork, manual, and cheat tool. Its tree is a vendored upstream import plus ordinary Zlyme commits, not a patch stack. It reads `/run/zlyme/libraries`. Artwork stays beside the ROM. Cheats stay on `/storage/Cheats`.

NextUI writes `/tmp/next` and exits. The file is text, not a shell command:

```text
ZLYME1
1 or 2
/absolute/path/launch.sh
/optional/rom
```

The count is 1 for a Tool, Settings, or an assigned function button, and 2 when a ROM is passed. A newline or other ASCII control except a tab is not queued. `nextui-session` rejects a file that is truncated, has the wrong marker, has a count other than 1 or 2, has any bytes after the last field, contains a NUL, contains an ASCII control other than a tab, or names an executable that is not an absolute `launch.sh`. The executable and the ROM are arguments of one fixed shell program. `PORTS.pak` and `WINE.pak` cleanup looks at that executable path. A ROM whose name contains those strings does not select the cleanup. The input filter is sourced inside the pak process. Settings does not get it. The proxy URL is taken from `zlyme-proxy get` inside that same process and exported only when the host and port match the helper's checks.

The launcher lifecycle is approximately:

```text
NextUI
  v
PAK launch.sh
  v
nextui-session stops the splash, drops DRM master, starts the pak under setsid
with zlyme-pak-hotkey watching MENU+START
  v
RetroArch / standalone / PortMaster / native application
  v
application exits
  v
session runs per-pak cleanup and restores runtime policy
  v
NextUI restarts/resumes
```

PAK and emulator behavior should be portable across devices where possible.

Device-specific frontend integration belongs in a NextUI platform directory such as:

```text
workspace/my355/
```

`nextui.mk` builds the platform named by `BR2_PACKAGE_NEXTUI_PLATFORM`, so platform selection is part of the selected device configuration. `nextui-session` still hardcodes `my355` (section 4).

### Frontend source and Settings

Frontend behavior comes from the `Zetarancio/NextUI` fork at the exact commit pinned by `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`. The fork records its LoveRetro base in `UPSTREAM`. `nextui.elf`, `settings.elf`, the `PWR_*` sleep path, the my355 platform code, and the Settings menus (GPU, Joysticks, update, reset) live in that fork, not in this repository. The Zlyme side is `package/system/nextui/`: `nextui-session`, the `zlyme/` helpers, and the stock PAKs. A frontend change is a fork commit plus a pin change. `docs/MAINTENANCE.md` describes that workflow.

Settings stores Zlyme policy as one file per flag, `/storage/.config/zlyme/<name>`, through `zlyme-ctl get` and `set`. Init scripts read the same flags with `zlyme-ctl want`. An empty or missing file means the default in `zlyme-ctl`, which matches the `S15bootpart` seed. The application proxy is one exception: one file, `/storage/.config/zlyme/proxy.conf`, read and written by `zlyme-proxy`. The updater asks that helper on each request. `nextui-session` applies it inside the pak process at launch, from `zlyme-proxy get`, not by evaluating shell text. It is not a transparent tunnel. The helper creates that file with a restrictive mode when the filesystem can store one. `/storage` is exFAT, so the mode is not stored and is not a confidentiality control. The file has no credentials.

The SSH password is the other exception. `zlyme-ssh-auth` stores it as plaintext in `/storage/.config/zlyme/ssh.password`. A missing file is an empty password, and SSH stays enabled. OpenSSH accepts that empty password only when the shadow field is empty as well as `PermitEmptyPasswords`. A set password becomes a SHA-512 hash in a shadow built under `/run` and bind-mounted over `/etc/shadow`. The hash comes from `openssl passwd -6 -stdin`. `BR2_PACKAGE_LIBOPENSSL_BIN` installs that command; without it libopenssl is built with `no-apps`. The squashfs copy is not written. Only the root field changes. Settings → Network sets, changes, and clears it without a reboot. About shows the live value. Clearing removes the password file only after the empty shadow field is written. If that write fails, the previous file and hash stay. Reset Settings and Factory Reset delete the file and restore the empty field. The exFAT mode is not a confidentiality control.

The updater's download confirmation and queued-reboot screen say that installing may reboot more than once. The displayed rate is about two seconds of newly received bytes. A resumed prefix is not part of that rate. Byte progress and the total size stay as they were.

Reset Settings runs `zlyme-reset settings`. It deletes an explicit list of Zlyme flags, `proxy.conf`, the SSH password file, the NextUI settings file, the timezone, and the Files (VTree) config. It then recreates the timezone and card defaults and asks the owning scripts to apply the restored defaults. Games, saves, Wi-Fi networks, and paired Bluetooth devices stay. Factory Reset runs `zlyme-reset factory`: the same reset plus a `factory-reset` marker, which makes the next `nextui-session` start overwrite the stock Tools and Emus PAKs on the card. Personal content stays. Reset PortMaster is on the Game page. It runs `zlyme-reset portmaster`. It deletes the selected live PortMaster tree and PortMaster's own config. Installed ports stay. The next PortMaster or port launch unpacks the seed again. Settings lists use the standard button hints. The list area ends at the top of those hint pills, so the selected description is not drawn on them. A custom page that draws its own controls owns that area: the keyboard, the color picker, release notes, and the full-screen joystick tools. After a verified Recovery arm, disarm, or stock restore, Settings offers Shut down or Restart. Those write `/tmp/poweroff` or `/tmp/reboot`, and `nextui-session` runs `zlyme-halt`. That verified action does not write NAND again in the same Settings process: Back returns to the confirmation, and A reopens the power choice. A failed write, a verified rollback, a refusal, or a CRITICAL result stays on the diagnostic text and can be tried again. Restart is a normal reboot. MASKROM entry is still shut down, the right-hand bootable card removed, then a cold power-on.

### PortMaster installation

`/usr/share/portmaster/PortMaster.zip` in the squashfs is the immutable seed. `<root>/Roms/.portmaster/PortMaster` on the selected library is the active installation. Font archives in that tree are decompressed with xz and then unpacked with tar. The system tar does not open an `.xz` file by itself. `zlyme-portmaster-prepare` owns that lifecycle. Tools → PortMaster and `PORTS.pak` both call it, so a port started after reboot does not depend on the PortMaster GUI having run earlier in the boot.

`<root>` is the library from `zlyme-portmaster-root`. An empty choice is `/storage`. An explicit non-primary choice is mounted only when that exact path is a line in `/run/zlyme/libraries` and the same path is a current mount. A library-list line without that mount, or a mountpoint directory that remains after the card is gone, is not a mounted volume. `/storage` is the built-in primary. A non-primary choice that fails either check reports `PortMaster disk is not inserted`. Prepare does not switch to another disk.

`/opt/system/Tools/PortMaster` links to `/run/portmaster/PortMaster`. Prepare points that runtime path at the live tree. `libs/` and `runtimes/` are directories in that tree. They are not separate links.

A valid live tree is left in place when a later Zlyme update ships a different seed. The seed is used only when no valid live tree exists, or after Reset PortMaster. Replacing an invalid tree moves the old directory aside first. If the new tree cannot be published and the old directory cannot be moved back, prepare leaves that old directory at the backup path it prints. Zlyme integration (`control.txt`, `mod_Zlyme.txt`, the hardware identification patch, and the Zlyme scheme) is applied from `/usr/share/portmaster/zlyme/` at prepare time. An upstream PortMaster update may replace upstream files. The next prepare puts the Zlyme files back. The proposed files are checked before any of them replace the live copies, and a file whose bytes did not change is not rewritten. Miyoo Flip's device identity, the `zlyme` platform mapping, the Zlyme colour scheme, and the control and mod files all have to be present. If the upstream tree no longer accepts that patch, prepare fails and does not publish a half-applied tree.

The launcher does not pass `pugwash --no-check`. That flag only skips the startup version offer. Update PortMaster in the GUI still installs `PortMaster.zip` into the live tree and creates `.pugwash-reboot`. The launcher treats that file as a restart: it prepares again, then starts the new GUI.

`/storage/PortMaster` and `<root>/Roms/Ports (PORTS)/PortMaster` are obsolete PortMaster engines. Prepare does not read them, copy them, or delete them. Installed games stay in `Roms/Ports (PORTS)`. A new live tree does not contain downloaded runtimes. PortMaster refreshes its own catalogue, and a port downloads the runtime it needs.

A missing live path, or a path that is not a real PortMaster directory, is installed from the seed. Prepare moves the previous path aside only while that publish is in progress. After the new tree is in place, that temporary copy is removed. A failed publish puts the previous path back. The seed is not merged with the previous tree.

PortMaster `control.txt` sets `clibs=/usr/lib/compat` and `get_controls` prepends that directory to `LD_LIBRARY_PATH`. Runtime wrappers then prepend their own library directory. The system dynamic linker does not search `/usr/lib/compat`. `portmaster-theora-compat` installs the libtheora 1.1.1 decoder there (`libtheoradec.so.1`) because LÖVE 11.5 was built against that SONAME. The system libtheora remains 1.2 (`libtheoradec.so.2`).

## 12. Emulator model

Zlyme deliberately ships a curated set.

Prefer one default backend per system. Multiple backends are justified only when they provide real compatibility/performance value.

The emulator packages themselves should remain device-agnostic when upstream allows it.

Device-specific tuning belongs in:

- launch/runtime profiles;
- board governor implementation;
- device-specific core/build flags only when measured.

PICO-8 runs the user-supplied native runtime pair `pico8_64` + `pico8.dat`. `pico-runtime.sh` looks in the ROM library's BIOS first, then in every active library. `PICO.pak` runs that runtime, or the `fake08` core when that core is selected. `zlyme-pico-splore`, called by `zlyme-storage`, shows one synthetic Splore entry only while a runtime pair exists, in the Pico-8 folder of the library that holds it.

## 13. Services

Services fall into three classes:

### Boot critical

Needed before frontend operation, such as essential display/input/storage policy.

`rcS` first sets the `performance` CPU governor, then runs only this whitelist, in order. It skips every other script in `/etc/init.d`.

```text
S10udevd         udevd without coldplug
S11modules       modules-load.d: miyoo-flip-gamepad (Buildroot initscripts)
S12bootfs        confirm /boot is the primary boot partition and keep it read-only
S12splash        restart the splash from the squashfs
S13resize        first-boot storage grow (skipped unless autoresize=true)
S15bootpart      mount /storage, timezone file, background seed
S15gpudriver     GPU stack from the gpu flag
S16display       saved panel refresh rate
S17sd2           SD2/USB library mounts (forked, not waited for)
S18zlymeupdate   apply a queued OTA (blocks, reboots on success)
S20alsa          restore mixer state, prime FlipVolume
S25jackd         zlyme-jackd
S26keylidmon     zlyme-keylidmon
S28minui         start nextui-session in the background
```

### Deferred

Can start after first frame, such as networking, Bluetooth, SSH, time sync, Samba, Syncthing, noncritical udev triggering, and similar services.

After the first-frame gate (section 5), `rc.late` starts these in the background: seedrng, syslogd, klogd, sysctl, zram, LEDs and the `smart` governor profile (`S27led`), udev coldplug for everything except block devices (`S29udevtrigger`), IRQ affinity, network, `zlyme-btsink`, crond, sshd, Samba and Syncthing (each off unless enabled), Wi-Fi, and `S49ntp`. A separate background chain starts D-Bus, InputPlumber, `zlyme-input`, `btusb`, `bluetoothd`, and BlueALSA in that order. After an OTA it also runs `zlyme-update reapply`.

Because udev coldplug is deferred, modules that load from a Device Tree modalias, such as `rk3568_dmc.ko`, load after the first frame.

### On demand

Should not run persistently unless enabled or requested.

The BusyBox `rcS` / `rc.late` split is intentional.

### USB file transfer

USB file transfer stays off through boot. A cable on the lower USB-C port does not start it. Tools → USB File Transfer calls `zlyme-usb-transfer start` after the confirmation screen. There is no init script. fstab and the initramfs do not mount configfs. The initramfs mounts sysfs.

`zlyme-usb-transfer` (`package/system/zlyme-usb-transfer/zlyme-usb-transfer`) owns one configfs gadget, `zlyme-mtp`. On start it mounts configfs at `/sys/kernel/config` when that path is not already a configfs mount, and it refuses to mount over a different filesystem. An existing configfs mount is reused. It then mounts FunctionFS and starts Buildroot's `umtprd` through `/usr/sbin/zlyme-usb-enter` (`package/system/zlyme-usb-transfer/zlyme-usb-enter.c`). That program creates a private mount namespace, bind-mounts only the export directories and the FunctionFS mount, and `pivot_root`s onto that tree before exec. The configuration stays under `/run/zlyme/usb-transfer`. The helper waits until `ep1`, `ep2`, and `ep3` exist. It writes the UDC name only when the lower PHY extcon reports SDP or CDP. That name is `ZLYME_USB_GADGET_UDC` from `device.conf`. On my355 it is `fcc00000.usb`, the DWC3 at `usb@fcc00000`. The helper binds that directory only. DCP, no cable, and a classification that is still all zeros leave the responder and FunctionFS up and the UDC unbound. A missing or unreadable extcon fails the start. It is not treated as DCP. Writing the UDC name starts DWC3 and enables EP0, so that write waits for a data-capable reading. The watcher stays up while the gadget directory exists. When SDP or CDP appears, it binds once and does not also write `soft_connect`. That bind is the connection attempt. `ep0out/transfer_type` is the descriptor class of an enabled endpoint. It is not an input. After the bind, `configured` and `suspended` are left alone, including when a later reading says DCP. If the host state leaves those two values and SDP and CDP are both gone, the watcher writes one disconnect. A later data cable writes one connect. One `failed to enable ep0out` for this bind, while SDP or CDP is present and the UDC is not `configured`, gets one disconnect and one connect. DCP and the RK817 charger type do not count as a data host. Linux 7.2.10's `soft_connect` store returns the write length and does not check the DWC3 pull-up result, so a write is not enumeration and it is not repeated after a failure. The responder stays running: its configuration sets `loop_on_disconnect`, and FunctionFS disable does not close the endpoint files. `stop` still owns unbinding the UDC. The watcher is in the tool's process group and `stop` kills it. On 2026-10-12 that sequence was hardware-exercised and the host did not enumerate the gadget. The investigation is `docs/research/usb-mtp-phase12d.md`. No role, VBUS, or regulator write is added. An empty UDC class, any other controller, or a gadget that already holds `fcc00000.usb` is a failed start. The other gadget's UDC file is left as it was. The helper does not write a USB role, a VBUS supply, or a regulator. The Settings OTG overlay disables the upper host (`usb@fd800000` and `usb@fd840000`) and is not a switch for this gadget. A missing `fcc00000.usb` is reported as-is.

The export list is the roots of mounted data filesystems, snapshotted when the session starts. `/storage` is the MTP storage `ZLYME`. `/mnt/sd2` is `SD Card` when `/run/zlyme/libraries` lists it and that path is the mount. Each `/mnt/media/<name>` line in that file is one USB volume. The MTP label is the directory name `zlyme-storage` already chose. A second label that matches an earlier one gets a ` 2` suffix. A missing second card or USB stick is skipped and does not fail the ZLYME share. A stick that appears after `start` is not added. uMTP accepts 16 storage entries. Further volumes are skipped, and `status` names them.

A share does not require a `Roms` or `Bios` directory. The filesystem has to be kernel `exfat`, `vfat`, or `ext4`. ext4 is included only while `zlyme-usb-enter` confines the responder. A read-only mount is included with uMTP's `ro` option and is not remounted read-write. NTFS, FUSE, and the other types stay mounted and are not shared. A nested mount under `/storage` refuses the session, because the clone is not recursive and would hide that content. A nested mount under another volume skips that volume.

`/boot` is not a share, and the session does not unmount it. A mount whose source is the filesystem mounted at `/boot`, or `ZLYME_BOOT_DEVICE` when that is set, is the boot volume even if its path is `/mnt/sd2` or a USB directory. A filesystem label, including another `ZLYMEBOOT`, does not decide that. `/dev`, `/sys`, and `/proc` are not shares. The configuration does not name a block device.

Exporting `/storage` includes `.config`, `.logs`, and `.update`. They live on that filesystem. They are not separate MTP entries, and a path that names one of them is refused. uMTP-Responder 1.8.1 follows symlinks (`stat64` in `fs_entry_stat`, and `open` in `entry_open`), including a link created while the session is up. The private namespace is the confinement: each export is opened with `O_NOFOLLOW` and cloned with `open_tree` without `AT_RECURSIVE`. A link can reach a directory inside the cloned filesystem, including `.config`. It cannot name `/boot`, `/dev`, `/proc`, `/sys`, or a path that was not cloned. A nested mount is not copied in. The unreleased uMTP `realpath` prefix check was not adopted. `start` returns before creating the gadget when `/storage/.update/reconstruct` or `/storage/.update/pending/zlyme` exists. The session uses the mounted filesystem. It does not unmount `/storage` and it does not remount a read-only volume.

`stop` clears this gadget's UDC file, signals the recorded pid only when `/proc/<pid>/cmdline` is this `umtprd` and this configuration file, unmounts the FunctionFS mount, and removes the `zlyme-mtp` configfs directory. If this session mounted configfs and no other gadget, nested mount, or second configfs mount is using it, `stop` unmounts that configfs too. Otherwise the configfs filesystem stays mounted. That is not an active gadget. If the owned responder cannot be killed, the pid file and configuration path stay, and `stop` fails. A later `start` or `stop` can try again. It does not signal a pid whose command line is some other process.

MENU+START is unchanged: `package/system/nextui/zlyme/zlyme-pak-hotkey.c` sends SIGTERM to the PAK process group and SIGKILL after 1.5 seconds. Before the gadget exists, `start` runs `setsid` on a reaper that is not in that group. The rootfs BusyBox provides `setsid`. The initramfs BusyBox does not, and this helper does not run there. The reaper calls `stop` once when the group leader's `/proc` start time is gone, then it exits. It is not a boot service. A normal exit from the tool calls `stop` in the PAK and shows the failure when teardown did not finish. After reboot the `/run` directory is gone, so transfer is off.

The USB identity is the Linux Foundation PTP gadget id used by the uMTP sample, `1d6b:0100`. It is a shared sample id. The serial string is the constant `zlyme`. `max_speed` is `high-speed` because the uMTP 1.8.1 FunctionFS descriptors have no SuperSpeed configuration. The configuration is self-powered (`bmAttributes` `0xC0`) with `MaxPower` 2, which is 2 mA on Linux 7.2.10. Charging stays on the RK817 path.

`status` reports `off` when this session owns nothing, `waiting` when the responder and FunctionFS are ready and the UDC is not bound, `bound` when this gadget holds the controller, and `partial` when the session is incomplete. `host=configured` is the kernel UDC state. The waiting screen says it is waiting for a USB data connection and shows B to stop. The bound screen says the session is open, names the storages that were exported, and shows B to stop. Neither screen says the computer is connected, and `state=bound` is not host enumeration. On 2026-10-12 the host did not see the gadget. On 2026-10-13, 12D-E21 enumerated `1d6b:0100` at high speed on one identified host port, and a separate read-only mass-storage gadget on that same port. No file was copied. The filesystem-root export in this section is host-tested. It is not the image used for 12D-E21. 12D-E22 installed it, the gadget started, and that computer saw no USB device. On 2026-10-14 the installed image that contains this bind enumerated `1d6b:0100` at high speed. A file copy was not verified, and the bind is not hardware-accepted. That session is 12D-E25 in `docs/research/usb-mtp-phase12d.md`.

### Wi-Fi and Bluetooth

Wi-Fi and Bluetooth share one RTL8733BU USB combo chip:

- `rtl8733bu_power` (package `rtl8733bu-power`) owns the chip's enable GPIO. It registers one WLAN and one Bluetooth rfkill and cuts power when both are blocked. It also cuts power in its late suspend phase;
- `8733bu` (package `rtl8733bu`) is the Wi-Fi driver. `/etc/modprobe.d/8733bu.conf` keeps IPS and radio power save off, because the Bluetooth half needs the shared firmware alive;
- `btusb` is blacklisted against modalias loading and has `softdep btusb pre: 8733bu`. `S35btusb` loads it by name after Wi-Fi.

Nothing loads the combo chip at boot. `zlyme-combo` loads `rtl8733bu_power` and `8733bu` on demand and toggles rfkill. `rc.late` runs `S30wifi`, `S35btusb`, and `S40bluetoothd`, and each does nothing unless its `wifi` or `bluetooth` flag is on (both default on). The BlueZ store lives on tmpfs (`/run/bluetooth`) because exFAT cannot hold its file names. `zlyme-bluetooth` saves and restores it as `/storage/.config/bluetooth.tar`. The Wi-Fi regulatory country is the global `country=` line in `/storage/.config/wpa_supplicant.conf`, written by `zlyme-wifi`. No line means world (`00`).

### Time

The RTC and the system clock are UTC. `S49ntp` starts in the background from `rc.late`, after the first frame. If the clock year is before 2024 it reads the HTTP `Date` header from `http://1.1.1.1`, sets the system clock as UTC, and writes the RTC with `hwclock -u -w`. It then starts one BusyBox `ntpd` client against `time.cloudflare.com` and `pool.ntp.org`. The initramfs busybox does not include `ntpd`. BusyBox passes the callback an action argument (`step`, `stratum`, `periodic`, or `unsync`) and puts the offset in the environment. A `step` whose absolute integer seconds are 30 or more writes the RTC, again with `hwclock -u -w`. Smaller steps, and the other actions, do not. `start`, `kick`, and `reopen` share a lock so only one client runs. Wi-Fi association and resume ask `S49ntp` to run again. A start, kick, or reopen with Wi-Fi left off, or with no default route, does not leave a client polling. `/etc/localtime` is a squashfs symlink to `/storage/.config/nextui/shared/localtime`, which `zlyme-timezone` maintains. `S15bootpart` ensures that file exists before NextUI starts. The frontend clock reads the system time when it draws, so a correction shows on the next frame.

## 14. Package boundary

`package/` should contain reusable software packages.

A package may be used only by `my355` today without being moved under a fake generic framework.

When a package is inherently board-specific, express that dependency explicitly in Kconfig or keep the hardware implementation in the board overlay.

Examples:

- `zlyme-jackd`, `zlyme-keylidmon`, `zlyme-input`, `zlyme-usb-transfer`, `miyoo-flip-gamepad`, `rk3568-dmc`, and `rtl8733bu-power` depend on `BR2_ZLYME_DEVICE_MY355` in Kconfig, even where the package directory is under `package/system`. `zlyme-usb-transfer` reads the controller name from `device.conf`.
- `gpudriver`, `libmali`, and `mali-kbase` describe the RK3566 dual-Mali-stack implementation and should not be assumed universal. Their Kconfig does not depend on `BR2_ZLYME_DEVICE_MY355`: `gpudriver` and `libmali` depend only on `mali-kbase`, which depends only on the kernel.
- `zlyme-governor` is my355 policy installed by the generic `nextui` package (section 4).
- emulator recipes are generally reusable.

## 15. Sources of truth

For Zlyme userspace/build behavior, this repository is authoritative.

For frontend behavior, the pinned `Zetarancio/NextUI` commit in `nextui.mk` is authoritative (section 11).

For Miyoo Flip hardware/kernel research, use `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` as the distribution-independent device reference. Its hardware/firmware conclusions are authoritative for device facts; follow its evidence and uncertainty labels.

For current OS behavior, this Zlyme repository is authoritative. `Zetarancio/distribution` is an archived historical ROCKNIX implementation/evidence source only. Official `ROCKNIX/distribution`, KNULLI, and other distributions are external comparison references.

Do not embed developer-local clone paths in canonical documentation.

## Hardware source of truth

Zlyme does not attempt to duplicate the full Miyoo Flip hardware wiki.

For hardware facts, electrical constraints, DTS history, suspend research, DDR/DMC protocol, USB topology, PMIC behavior, and stock-firmware comparison, the canonical reference is:

```text
Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering
```

`Zetarancio/distribution` is the archived historical Miyoo Flip ROCKNIX implementation/evidence. It is not a maintained or current tree.

Zlyme remains authoritative for Zlyme-specific build, runtime, frontend, storage, update, and service behavior.

Hardware facts that affect architecture:

- standard suspend is known working;
- deep suspend is a separate BL31/SIP feature under the standard suspend path. Mem suspend on the Flip uses it, with `vdd_logic` off (below);
- DMC runtime scaling and deep-suspend configuration are independent drivers/features;
- the RK3568 DMC driver uses Rockchip's V2 SIP shared-memory/MCU/IRQ protocol;
- the upper USB host requires EHCI + OHCI and the PHY clock used by OHCI;
- both SD slots share the I/O-voltage rail;
- RK817 `SYS_CAN_SD` handling is required for correct off-state current;
- Miyoo Flip retail units use RK8600 for VDD_CPU.

These facts must not be "cleaned up" based on assumptions from another RK3566 board.

### Deep suspend

The hardware wiki owns the BL31 suspend interface, the meaning of each mask bit, and the electrical evidence. Zlyme owns the DTS node, the kernel patches, and the runtime ordering around suspend (section 10).

- The DTS node `rockchip-suspend` has `compatible = "rockchip,pm-rk3568"`. Its `rockchip,sleep-mode-config` is `CENTER_OFF | ARMOFF_LOGOFF | PMIC_LP | HW_PLLS_OFF | PMUALIVE_32K | OSC_DIS | 32K_PVTM` (0x5ec), and its `rockchip,wakeup-config` is `GPIO_WKUP_EN` (0x10).
- Patches `1011a` (binding header) and `1011b` (driver) add `rockchip-pm-config`, enabled as `CONFIG_ROCKCHIP_PM_CONFIG=y`. It is a `bool` option, so the driver is always built in. It sends the mode and wake masks to BL31 through the `ROCKCHIP_SIP_SUSPEND_MODE` SMC at probe. Before each suspend, `.prepare` sends the Linux sleep state, the mode, and the wake mask again. A rejected call fails that suspend.
- BL31 is rkbin `rk3568_bl31_v1.44.elf` inside `u-boot.itb`.
- In mem suspend the DTS turns off `vdd_logic` (RK817 DCDC1), `vdd_gpu`, `vcc_3v3`, `vdda_0v9`, `vccio_acodec`, `vcc_1v8`, `vcc1v8_dvp`, `vcc2v8_dvp`, BOOST, `otg_switch`, `vdd_cpu` (RK8600), `vcc5v0_host`, and `vcc3v3_lcd0_n`. `vcc_ddr`, `vcca1v8_pmu`, `vdda0v9_pmu`, `vccio_sd` (at 3.3 V), and `vcc3v3_pmu` stay on. The SD card power switches have no suspend state.
- Wake sources are the RK817 power key, the volume keys, and lid open. Lid close does not wake.

The Phase 6 hardware acceptance record is in `docs/ROADMAP.md`.

### DDR frequency scaling (DMC)

DDR devfreq is the out-of-tree module `rk3568_dmc.ko` from `package/drivers/rk3568-dmc`, installed under `/lib/modules/7.0.2/updates/`. It is not a kernel patch. Its Device Tree contract is that package's `README.md`. It needs BL31's DDR SIP API version `0x101` or newer, the in-tree Rockchip DFI devfreq-event driver for load, and `center-supply = <&vdd_logic>`. Kernel patch `1010` adds suspend/resume to that DFI driver. The Flip OPPs are 324, 528, 780, and 1056 MHz, all at 900 mV. The driver's default governor is `simple_ondemand`.

There is no `modules-load.d` entry or init script for it. It loads from the `rockchip,rk3568-dmc` modalias during the deferred udev coldplug in `rc.late`. Before suspend it returns DDR to the boot rate.

Runtime policy belongs to `zlyme-governor`. The `smart` and `idle` profiles hold DMC at `powersave` 324 MHz. The `play` and `heavy` profiles use `simple_ondemand` from 528 to 1056 MHz. After resume, `zlyme-radios resume` reopens the DMC range once and restores the previous profile.

The Phase 7 hardware acceptance record is in `docs/ROADMAP.md`.

## Kernel extension policy

Classify non-upstream kernel work by scope:

```text
board-specific
SoC-family reusable
PMIC/device-family reusable
modification to existing in-tree kernel code
debug-only/historical
```

Prefer an out-of-tree Buildroot kernel-module package for a self-contained driver when:

- the kernel API supports modular operation;
- no required functionality depends on very early boot;
- the module can be self-contained;
- load ordering is explicit and testable.

Keep a kernel patch when the functionality must modify existing in-tree kernel code, bindings, core headers, or boot-critical behavior and an external module would be artificial.

For example, the RK3568 DMC driver is self-contained, so it ships as the out-of-tree module package `package/drivers/rk3568-dmc` and autoloads from its DT compatible. The DFI PM fix (`1010`) modifies the existing in-tree Rockchip DFI driver and stays a kernel patch. The deep-suspend driver (`1011b`) also stays a kernel patch: it adds SIP constants to the in-tree `rockchip_sip.h` header, and its Kconfig option is `bool`, so it is always built in.

Functionality validation and modularization should be separate experiments.

## 16. Architectural invariants

- only Miyoo Flip is supported today;
- future-device readiness must not add unused second-device code;
- upstream Buildroot is not modified;
- board-specific Linux/U-Boot/image policy stays with the board;
- direct DRM/KMS is the default graphics architecture;
- no permanent compositor;
- BusyBox init remains the default;
- optional networking/services do not block first frame;
- root is read-only;
- persistent state is explicit;
- update artifacts are device-specific;
- generic runtime callers use stable interfaces rather than hardware details;
- performance changes are measured;
- hardware protection is never disabled for benchmark numbers.
