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

`board/my355` provides all of these. It also holds `zlyme-boot.conf` (boot flags on ZLYMEBOOT), the OTA hooks `pre-update.sh` and `post-update.sh`, and build helpers (`image-date.sh`, `assert-input-rootfs.sh`). SDL3 is Buildroot's package. `post-build.sh` checks that `libSDL3.so.0` exports `SDL_Init` and does not replace that library.

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

`zlyme-governor` holds my355 knowledge: the RK3566 CPU OPP list, the DMC rates, and core hotplug. It is installed by the NextUI package from `package/system/nextui/zlyme/governor.sh`, not from `board/my355`. `nextui-session` applies `smart` before each `nextui.elf` start, which is the list and the return from a pak. Emulator PAKs call `zlyme-governor emu <tag>`. NextUI's my355 platform code sets `idle` on the way into sleep and `smart` in `PWR_exitSleep` when the frontend resumes. In a pak, `zlyme-keylidmon` sets `idle` around mem and then `resume`, which reapplies the pak profile in that same invocation. Applies are serialized with an exclusive `flock` on an empty file under `/run`. The kernel drops the lock when the process exits. `S27led` runs `zlyme-led watch`. That is the LED policy and the only battery monitor. It samples every 10 seconds. At 10% or below the red LED stays on and flashes about once a minute. Two consecutive numeric 0% readings call `zlyme-halt poweroff` when no non-battery supply has `online` of 1. On 2026-10-19 the maintainer observed one automatic shutdown when the Flip reached 0%. The individual samples and the charger reading were not captured. That is one shutdown, not a cycle count and not a test that the charger suppresses it. A missing or non-numeric capacity does not count. LED Off still runs that check. Charging colour still treats battery status `Charging` or `Full` as charging, including when `online` and status disagree. A late DMC probe and `zlyme-update reapply` call `resume`, which reapplies the profile already recorded. `zlyme-ctl apply-gov` still means frontend `smart`. It is a manual or reset action; no boot service calls it.

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

NextUI writes `nextui-first-flip` to `/tmp/boot-timing` after its first flip. `rc.late` polls for that mark every 0.5 s for at most 20 s, so a hung frontend still brings the late services up. SSH starts there only when Wi-Fi is on. It then restores stick calibration and rumble gain, then starts Class B in the background. The first frame therefore comes before calibration and rumble gain are restored. Section 13 lists both classes.

## 6. Image and storage model

The Miyoo Flip image (`board/my355/genimage.cfg`) uses:

- raw `idbloader.img` at 32 KiB, outside the partition table;
- GPT `uboot` partition at 8 MiB, 4 MiB, holding `u-boot.itb`;
- FAT32 `ZLYMEBOOT` at 12 MiB, 1300 MiB, holding `Image.gz`, the DTB, `extlinux/`, `overlays/`, `zlyme-boot.conf`, the splash animations, and the root squashfs;
- exFAT `ZLYME` storage partition, GPT type Microsoft Basic Data (`ebd0a0a2-b9e5-4433-87c0-68b6b72699c7`, genimage alias `F`);
- no rootfs GPT partition;
- root squashfs (zstd, 1 MiB blocks) stored as a file named `zlyme` on `ZLYMEBOOT`.

An update does not rewrite that partition table. A card written before the storage type was Microsoft Basic Data keeps the type it was given.

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
- `/storage/.config/syncthing` for Syncthing's persistent home. The first time the service is enabled, `syncthing generate` creates that home with GUI user `zlyme` and a bcrypt hash of the password `zlyme`. The password is not stored as plaintext and is not a program argument. A later start does not run `generate` again. A home that already has GUI authentication is left unchanged. `zlyme-syncthing-gui` parses `config.xml` with Python's ElementTree (`BR2_PACKAGE_PYTHON3` and `BR2_PACKAGE_PYTHON3_PYEXPAT`). Authentication matches Syncthing 2.0.13 `IsAuthEnabled`: LDAP, or a nonempty user and password. An XML comment is ignored. More than one `gui`, `user`, `password`, or `authMode` element is refused. A home that fails that check does not start the listener on `0.0.0.0:8384`;
- `/storage/.config/<application>` for an emulator or tool, or a NextUI subtree that NextUI itself owns.

Mounted libraries are the lines in `/run/zlyme/libraries`. A USB library is `/mnt/media/<name>`, one directory under `/mnt/media`. Spaces in the label stay. `/` and control characters are replaced with `-`. `.`, `..`, and an empty result use the kernel device name. Two devices that sanitize to the same name do not share a mountpoint: the second is `/mnt/media/<name>-<device>`. The library list stores the decoded path, including a space that `/proc/mounts` wrote as `\040`. Content stays on the library that holds it:

- `$library/Roms` for games;
- `$library/Saves` for saves. Existing saves are searched on every mounted library. The game card wins a duplicate, and a new save is created on the game card;
- `$library/Bios` for BIOS files. The running game sees a union of those folders. A duplicate path uses the copy on the game card.

User media is not configuration. Music and podcasts stay `/storage/Music` and `/storage/Podcasts`. Installed cheats stay `/storage/Cheats`. ZcrapeGoat state stays `/storage/.config/ZcrapeGoat`.

Transient POSIX-only data belongs under `/run` or `/tmp`. Samba's live private database stays `/tmp/samba-lib` because exFAT cannot store the mode bits that database needs. The NT hash export is `/storage/.config/zlyme/samba.account`. That file is not the live database. Samba 4.24.6 writes uid 0 into the smbpasswd export. `zlyme-samba-auth` rewrites that field to the unix uid before the file is kept and before import. `S70samba` creates `/var/run/samba` before `smbd`, because `smbd` does not create that parent, and it reports failure if `smbd` does not stay running. SSH, Samba, and Syncthing also stay down while the Wi-Fi flag is off. Their own enable flags stay.

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

`zlyme-hdmi` owns the physical HDMI choice. It runs only when `ZLYME_HDMI_720P` is exactly `1`. A normal boot leaves that unset, the command prints `ZLYME_HDMI_ACTIVE=0`, and it does not open a DRM device. With the gate set, it reads connected connectors on `/dev/dri/card0` and `card1`. A read-only open is tried first. A read-write open drops master only when `drmIsMaster` says this process became master. The choice is an HDMI-A connector, identified by connector id, preferring 1280×720 within 0.5 Hz of 60 Hz from `clock / (htotal * vtotal)`, then a mode with `DRM_MODE_TYPE_PREFERRED`, then the first usable mode. The same width on the DSI connector is not that choice. `hdmi-session.sh` exports those assignments. `eval` alone leaves them in the launching shell, so `nextui.elf` and RetroArch would see the gate and not the connector or the mode. A failed query clears a previous success. On the installed candidate, a temporary wrapper exported the policy and did not change the boot image. HDMI-A-1 then scanned `1280x720` at 74250 kHz, 1650×750, which is 60.000 Hz. The panel CRTC stayed `640x480` at 32000 kHz. NextUI logged the 960×720 viewport at x=160, y=0. The sysfs `mode` file stayed empty while that CRTC was active. After the gated process exited, HDMI returned to `1024x768` at 78750 kHz. The stock session on that image did not export the variables. Phase 14's HDMI case is a cable connected after boot, then a new emulator process. Changing the cable while that process is already running is not the requirement. Releasing DRM master restored the previous HDMI mode on that boot, so the next client still has to select 1280×720 itself. Those candidates kept the panel CRTC active. The gated SDL path disables the DSI CRTC only after HDMI scanout has succeeded, and only when that CRTC is a different CRTC from the HDMI one. A DTS mode, a `video=` command line, or `drm.edid_firmware` does not remove the sink's other modes from the connector list. The DRM client still chooses the CRTC mode. The session gate stays the HDMI policy.

SDL 2.32.10 KMSDRM reads the connector id, the mode index, and the width and height. The index selects `connector->modes[index]` after the width and height confirm it. Integer refresh is not the selector. The patch does not set the window's fullscreen flag. It stores the policy mode, including its pixel clock, when the request is the desktop mode entry or the policy size. A windowed client keeps the fullscreen flag clear; its first GBM surface still uses the policy mode. A later fullscreen request for a different size is programmed as requested. A request for the desktop mode entry, or for the policy size, uses the recorded EDID mode, including its pixel clock. A Vulkan window is skipped. `drmModeSetCrtc` still runs on the swap. The patch is `board/my355/patches/sdl2/0001-kmsdrm-honor-zlyme-hdmi-mode.patch`.

NextUI keeps a 640×480 logical surface. `PLAT_initVideo` calls `PLAT_hdmi_after_window` after the window and renderer exist. The function letterboxes only when SDL's current display mode already has the policy size. It does not open DRM and it does not call `SDL_SetWindowFullscreen`. `SDL_RenderSetLogicalSize(640, 480)` letterboxes renderer copies. Final GL draws use `zlyme_hdmi_viewport`. On 1280×720 that box is 960×720 at x=160, y=0. After the first present, `PLAT_hdmi_note_present` reads `/sys/class/drm/cardN-<connector>/mode`. That file is the connector's current width and height. It does not include the pixel clock. `SDL_GetCurrentDisplayMode` is not a CRTC read either. The hardware pass reads the CRTC mode from debugfs `dri/0/state` when that file is mounted, and looks at the picture. With the gate unset, Zlyme does not request the forced 720p policy or disable DSI. The maintainer reports that connecting HDMI normally moved NextUI to the television while the internal panel remained on; no CRTC clock, timing, or DSI power state was recorded. With the gate set, an SDL client disables the DSI CRTC only after `drmModeSetCrtc` has succeeded on the HDMI connector. The disable request is the one Linux accepts for a CRTC that should go idle: framebuffer 0, no connectors, and no mode. A failed HDMI modeset leaves the panel untouched. The marker `/run/zlyme/hdmi-panel-off` is the single line `panel-off`. It carries no framebuffer id and no serialized mode. After a DSI modeset, the client reads the CRTC again and clears the marker only when that CRTC is scanning the framebuffer this process just programmed. A cached buffer id of 0 is not that proof. On exit, if the DSI CRTC had no framebuffer when this process opened it, the marker is written again so the next ungated client still opens the panel. That client allocates its own framebuffer. RetroArch has its own KMS path and does not use this SDL patch to turn the panel off. The saved `display_mode` value and its sysfs replay stay.

`ra-run` adds a session `--appendconfig` for `video_monitor_index`, `video_fullscreen_x`, `video_fullscreen_y`, and `video_refresh_rate` when the policy is active and the user file does not already set a non-zero `video_fullscreen_x`. It does not write `retroarch.cfg` and it does not set an aspect ratio. RetroArch's KMS driver then matches that size on the connector selected by `video_monitor_index`, using the mode clock for refresh. `zlyme-weston-run` writes a temporary output mode for the named connector. AetherSX2's EGLFS launcher writes a temporary KMS config. Dolphin's EGLDRM path opens the first connected connector, so `/var/run/drmMode` is not the HDMI policy and nothing writes it. PPSSPP's Vulkan `VK_KHR_display` path uses the first Vulkan display. The SDL patch covers its OpenGL window. PortMaster ports that ship their own DRM or a static SDL are outside this policy. The comparison and the per-backend status are in `docs/research/phase-14-portmaster-capability.md`.

`GetHDMI` in NextUI's msettings reads HDMI status on card0 and card1. RetroArch, PPSSPP, a native SDL port, and PortMaster's WestonPack each take DRM after NextUI releases it and choose their own mode. Return to NextUI creates the KMSDRM window again. HDMI sound is the PipeWire HDMI sink when the display ELD reports audio.

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

PortMaster software that needs X11 uses PortMaster's own WestonPack, which brings Xwayland for that launch. WestonPack is application-scoped and stays owned by PortMaster. Its cleanup is Zlyme's: `nextui-session` runs `zlyme-portmaster-cleanup` before and after every `PORTS.pak` launch, outside the pak session, because the launcher `exec`s the port and cannot run its own trap after session cleanup. The cleanup sends TERM to processes holding `/tmp/weston`, sends KILL after 6 s, and unmounts it. A mount through `zlyme-portmaster-exec` is recorded under `/run/zlyme-portmaster/owned-mounts` only when that command adds one new `/proc/self/mountinfo` id at its target. The registry line is that id, a tab, and the path. A remount is not recorded. Cleanup unmounts a line only when that id is the visible mount at the path. That mount is the one at the path which is not the parent of any other mount there, and the top mount of each shorter prefix is its ancestor. The order of mountinfo lines is not that relation. If the id is gone, the table is ambiguous, or the recorded mount is covered or hidden, the current mount stays. A mount id can be reused after unmount, and the check and the path unmount are not one operation. A line with no id is reported and kept. A mount that appears while the port is running stays mounted. A port that calls `mount` directly, bypassing the wrapper, is in that same position. Before the wrapper's `mount` or `umount` runs, an operand that is `//opt/system/Tools/PortMaster` or a file under that directory is passed with one leading slash when that local path exists. That directory is the symlink to the selected library, on the OS card or the second card. Option values are not rewritten. Any other `//` path, including a network share, is left unchanged. BusyBox otherwise reads the extra slash as a host name. The cleanup orders recorded paths deepest first and unbinds `/roms/ports` through `zlyme-library.sh`. It does not unmount `/storage`, `/boot`, `/mnt/sd2`, `/mnt/media`, or a library root listed in `/run/zlyme/libraries`. A busy `umount` stays registered and is not detached with a lazy unmount. The next launch tries those recorded mounts again. USB File Transfer still refuses a nested mount that remains. `/tmp/weston` is the WestonPack directory and is still unmounted by path after its holders exit.

Leaving PortMaster runs `zlyme-portmaster-art` once. It copies a cover, or a screenshot when there is no cover, into that card's Ports `.media` directory, named for the launcher script. A PNG stays a PNG. A JPEG is copied as `.jpg`. NextUI prefers `.png` and reads `.jpg` or `.jpeg` when the PNG is absent. Nothing is converted. Artwork already in `.media` is left alone.

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

`/etc/zlyme-gpu-env.sh` exports one Vulkan ICD. libmali uses `/usr/share/vulkan/icd.d/mali_icd.json`. Panfrost uses `/usr/share/vulkan/icd.d/panfrost_icd.cortex-a55.json` (`libvulkan_panfrost.so`). Mesa names that manifest for the Buildroot CPU. The product image builds that driver. The minimal image builds Panfrost GLES and does not build PanVK. Mali-G52 is Panfrost architecture v7. Mesa 26.1.8 returns `VK_ERROR_INCOMPATIBLE_DRIVER` for that device unless `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1`. The script exports that variable only when the saved choice is exactly `panvk`. `panfrost` is the OpenGL stack and does not export it. libmali and an unrecognized choice unset it. RetroArch's stock file sets `video_driver` to `gl`. The PPSSPP seed sets `GraphicsBackend` to `0`. Flycast's seed sets `pvr.rend` to `0`. A saved user file is left in place. PortMaster `2026.06.23-0015` does not publish a Vulkan capability bit. `nextui-session`, `ra-run`, and login shells source the script, so a launched program inherits the value. On 2026-10-14 a temporary process, with the opt-in set for that process only, acquired DRM master on `card0`, created a device, surface, and 640×480 swapchain, presented one orange frame, and returned to NextUI. A second launch did the same. No new kernel warning or Panfrost fault appeared. PPSSPP 1.19.3 is built with Vulkan. Its `VK_KHR_display` path does not call `vkGetDrmDisplayEXT` or `vkAcquireDrmDisplayEXT`, so that frame is not a PPSSPP result. The libmali Vulkan path and Panfrost OpenGL ES are unchanged. GLES applications do not read the ICD variables.

This dual-stack mechanism is a Miyoo Flip/RK3566 implementation detail, not a requirement for every future Zlyme device.

## 9. Audio

One PipeWire daemon is the mixer, with one WirePlumber and one `pipewire-pulse`. ALSA is the hardware backend. Playback sinks are identified by `alsa.id`: `rk817ext` for the codec, `HDMI` for HDMI, and a `bluez_output.` name for A2DP. `zlyme-policy.lua` selects the default after WirePlumber's priority and configured-default hooks. `auto` uses a connected A2DP sink, then HDMI when the connector is connected and the published ELD state is `yes`, then the codec. A disconnected HDMI-A connector is `no` even when the ELD file still lists a format. A connected connector whose ELD has no `sad_count` field is still being parsed. That pending state does not select HDMI and does not move a stream that is already on the HDMI node. A parsed `sad_count` of 0 is `no`. An explicit preference wins while that node can play, and the saved preference is not replaced by the fallback. The shell publishes the ELD and the preference as metadata. A change of `zlyme.hdmi` or `zlyme.pref` schedules a default-node rescan. WirePlumber 0.5.14 schedules a linking rescan when `default.audio.sink` changes, and it pauses that linking rescan for two seconds after a BlueZ session item is removed. The route file is written after the default is applied. Updating the file does not move a stream. The policy script reads those keys. WirePlumber's Lua sandbox has no `io` library, so the hook does not open files. `zlyme-audio follow` writes `/run/zlyme/pipewire/active` from the effective `default.audio.sink` after apply. The file is derived status. It does not select the sink. A missing key, an unknown name, or removal of that metadata deletes the file, so a stale `bt` cannot outlive the default. NextUI reads it as the effective sink: `bt` is Bluetooth, `hdmi` is HDMI, and anything else is the codec. A radio link draws the rune. Any non-default sink draws the external-audio glyph, including when that is the only extra mark. The volume pill uses the rune for a Bluetooth sink that is above zero and the headset glyph at zero. Every other sink uses the speaker and mute glyphs. A DRM change can precede a parsed ELD. One detached recheck reads the ELD for up to thirty seconds and publishes a change. It does not choose a sink. The shell does not call `wpctl set-default`, because that metadata outranks `priority.session`. `setSystemVolume` writes the saved percent and returns. One background apply holds a kernel flock until it has re-read the latest percent. A killed apply does not keep the lock. PipeWire being down does not discard the percent. `bluez5.auto-connect` is `[ a2dp_sink ]` on the card, which is one `ConnectProfile` for a paired trusted device that already lists the remote Audio Sink. The local role stays `a2dp_source`. HSP and HFP are not requested. The PipeWire ready path does not call `ConnectProfile`. A file `/storage/.config/zlyme/hdmi-audio-trace` makes the next twelve HDMI events append one line to `/storage/.logs/hdmi-audio-trace.log` and then removes the flag. ACP marks both ports available-unknown, so the ELD file is the HDMI signal. The event that publishes it is a DRM `change` with `HOTPLUG=1` on the primary card minor, `card0` or `card1`. Linux 7.2 `drm_sysfs_hotplug_event` and `drm_sysfs_connector_hotplug_event` both emit that event on the card. DesignWare HDMI reaches them through `drm_helper_hpd_irq_event`. The handler reads HDMI-A status and the ELD. A render node, a lease change, and a connector sysfs device do not run it. A new sink takes the saved cubic gain, including 0. The route default before that is 0.064. `main-embedded` does not store route state; the saved percent lives in `/storage/.config/audio.conf`. `zlyme-jackd` still sets the RK817 mux, because ACP does not expose it. Both images use that graph. The default PCM is the PipeWire plugin, so an ordinary ALSA client and a native `libpulse` client share it. BlueZ A2DP is PipeWire's BlueZ monitor. BlueALSA is not started. There is no PulseAudio daemon and no network listener. `module-switch-on-connect` is not loaded. `autospawn` is off. The minimal image omits emulators and NextUI, and `rc.late` does not wait for a frontend that is not installed. Image-specific route results, including `0b35a90`, `74597688`, and `be5d8c0`, stay in `docs/LOGBOOK.md` and `docs/research/phase-14-audio.md`.

For the Miyoo Flip, the codec is the RK817 and its stable ALSA card ID is `rk817ext`. HDMI is a separate card. `zlyme-audio` roles are `codec`, `hdmi`, and `bt`. `rcS` does not start PipeWire. After the first frame, `rc.late` starts `S33pipewire` beside InputPlumber. `/run/zlyme/pipewire/service` reaches `ready` only when a codec Audio/Sink exists. `zlyme-jackd` follows the headphone-jack switch and sets the RK817 `Playback Mux`; that mux change does not restart a game. Volume buttons call `zlyme-audio setSystemVolume`. The saved percent stays in `/storage/.config/audio.conf`. A program that opens `hw:` bypasses the mixer. The named diagnostic PCMs are `hw_codec` and `hw_hdmi`. The earlier PulseAudio server, BlueALSA, and `zlyme-btsink` are not installed. Their behavior is in `docs/research/phase-14-audio.md`.

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
- NextUI, lid close: `PWR_sleepNow`, the same mem path as a short power press. A second close while the lid stays shut does not stack another request. The one-second resume guard drops a lid edge as well as a power edge.
- NextUI, screen timeout: `PWR_sleep` is hybrid sleep, with the screen and radios off while it waits for a wake input. After the suspend timeout it enters the same mem suspend, unless the device is charging or USB keep-awake applies.
- Pak on screen, power press: `zlyme-keylidmon` runs `zlyme-governor idle`, `zlyme-radios pre`, the suspend helper, then `zlyme-governor resume` and `zlyme-radios resume`, and ignores the wake press for 1 s.
- Pak on screen, lid close: the same mem sequence as the power press. A close while that period is already asleep does not request mem again. Opening the lid clears the period. The hall node is unchanged. On the installed candidate, one lid open woke the device after that close. A long suspend was not part of that check.

The suspend helper is `package/system/nextui/zlyme/suspend`, installed as `/usr/share/nextui/bin/suspend`. It syncs and writes `mem` to `/sys/power/state`. It leaves an existing RTC wake alarm in place. Published `zlyme44` clears any RTC wake alarm, then programs a relative alarm of 86400 s before it syncs and writes `mem`. That timer is software policy left over from the 2026-09-13 timed-suspend test (`083e8061c47354325e7356966541642bb3062cfe`). No Miyoo Flip hardware limit of 24 hours is documented, and a full 24-hour suspend was not part of hardware acceptance. Normal wake sources (power button, volume keys, lid open) are separate. Published `zlyme44.2` does not read, clear, or program `/sys/class/rtc/rtc0/wakealarm`. An alarm programmed on purpose is preserved. RTC support stays in the kernel, and an RTC wake remains a valid hardware wake source. That helper was device-accepted in the unpublished `zlyme44.1` source at `6a398b311310246ef6a5515ed72805c6f58d787d` and shipped in `zlyme44.2`. The helper in this tree is that same program. The acceptance record is in `docs/MAINTENANCE.md`.

`zlyme-radios pre` stops Bluetooth before Wi-Fi: it saves the BlueZ store, then stops `bluetoothd` and Wi-Fi. Bluetooth goes first so `rtl8733bu_power` can cut the combo chip in its late suspend phase without hanging `hci_dev_close`. `zlyme-radios resume` starts Wi-Fi first, then `btusb` and `bluetoothd`, and reopens the DMC range once. NextUI runs `zlyme-radios resume` in the background. `/tmp/zlyme-keep-emu` still suppresses a library rescan while a test holds it. The 25-second hold that existed for `zlyme-btsink` is gone.

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
nextui-session stops the splash and drops DRM master
  v
zlyme-pak-spawn creates the pak session and waits for that session
while zlyme-pak-hotkey watches MENU+START
  v
RetroArch / standalone / PortMaster / native application
  v
application exits
  v
session runs per-pak cleanup and restores runtime policy
  v
NextUI restarts/resumes
```

`zlyme-pak-spawn` publishes the leader only after `setsid()` succeeds and records both the leader's and its own `/proc` start times. `zlyme-pak-hotkey` opens and retains a pidfd for that exact spawn waiter before reading input. MENU+START signals only the waiter through the pidfd; the helper never targets the frontend or a numeric process group. The waiter owns bounded TERM/KILL cleanup of the recorded pak session. When the leader exits, it enumerates the original session. Zombies do not count as owners. A member is signaled only while its PID, start time, session, and process group still match, using a pidfd; it never falls back to an unchecked numeric PID. Enumeration errors, allocation failures, identity changes, and members that remain after bounded TERM and KILL waits return status 125. A pak's own status 125 is remapped to an ordinary launch failure so it cannot imitate that ownership result. Per-pak mount and Wine cleanup still runs, then `nextui-session` records `/run/zlyme/pak-cleanup-failed` and does not start another direct-KMS frontend. A physical reboot is the recovery path.

That ownership boundary is the session created for the launch. A process that deliberately creates a new session leaves it. PortMaster's known detached Wine and compatibility resources have separate recorded cleanup owners. Zlyme does not add a subreaper, global process-name killer, or launcher watchdog without runtime evidence that a supported port needs a broader boundary.

PAK and emulator behavior should be portable across devices where possible.

Device-specific frontend integration belongs in a NextUI platform directory such as:

```text
workspace/my355/
```

`nextui.mk` builds the platform named by `BR2_PACKAGE_NEXTUI_PLATFORM`, so platform selection is part of the selected device configuration. `nextui-session` still hardcodes `my355` (section 4).

NextUI selects `zlyme-artbook`. That package runs only on the build host. It installs the finished system and Tool PNGs, `special/recent.png`, and `special/tools.png` for the Tools root, at `/usr/share/nextui/artbook` in the root squashfs. The full card image stores that squashfs as `zlyme` on the boot partition, and the normal OTA carries the same `zlyme` member. The Flip does not download an artwork pack. User `.media` images and `/storage/bg.png` stay on the card. The minimal image does not build NextUI, so it does not install these files. `board/my355/assert-input-rootfs.sh` checks the packed list when NextUI is in the image. NextUI resolves Recently Played in this order: `/storage/.config/nextui/shared/artbook/special/recent.png`, then `/storage/bg.png`, then `/usr/share/nextui/artbook/special/recent.png`. A file left at `/storage/Recently Played/.media/bg.png` is not used. The folder can be absent. Only the firmware file reserves the name column. `zlyme-stock-seed` does not copy, delete, or rewrite that picture. `board/my355/post-update.sh` copies a regular file from the zlyme44.3 folder path into the shared override when the override is absent and the file is not one of the two built-in renders. It leaves the old file and the history list in place.

### Frontend source and Settings

Frontend behavior comes from the `Zetarancio/NextUI` fork at the exact commit pinned by `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`. The fork records its LoveRetro base in `UPSTREAM`. `nextui.elf`, `settings.elf`, the `PWR_*` sleep path, the my355 platform code, and the Settings menus (GPU, Joysticks, update, reset) live in that fork, not in this repository. The Zlyme side is `package/system/nextui/`: `nextui-session`, the `zlyme/` helpers, and the stock PAKs. A frontend change is a fork commit plus a pin change. `docs/MAINTENANCE.md` describes that workflow.

Settings stores Zlyme policy as one file per flag, `/storage/.config/zlyme/<name>`, through `zlyme-ctl get` and `set`. Init scripts read the same flags with `zlyme-ctl want`. An empty or missing file means the default in `zlyme-ctl`, which matches the `S15bootpart` seed. The application proxy is one exception: one file, `/storage/.config/zlyme/proxy.conf`, read and written by `zlyme-proxy`. The updater asks that helper on each request. `nextui-session` applies it inside the pak process at launch, from `zlyme-proxy get`, not by evaluating shell text. It is not a transparent tunnel. The helper creates that file with a restrictive mode when the filesystem can store one. `/storage` is exFAT, so the mode is not stored and is not a confidentiality control. The file has no credentials.

The SSH password is the other exception. `zlyme-ssh-auth` stores it as plaintext in `/storage/.config/zlyme/ssh.password`. A missing file is an empty password, and SSH stays enabled. OpenSSH accepts that empty password only when the shadow field is empty as well as `PermitEmptyPasswords`. A set password becomes a SHA-512 hash in a shadow built under `/run` and bind-mounted over `/etc/shadow`. The hash comes from `openssl passwd -6 -stdin`. `BR2_PACKAGE_LIBOPENSSL_BIN` installs that command; without it libopenssl is built with `no-apps`. The squashfs copy is not written. Only the root field changes. Settings → Network sets, changes, and clears it without a reboot. About shows the live value. About reads that SSH password and the Samba account file when the page opens, and again if you leave and come back. It does not read them on every redraw. The Samba account row is `zlyme`. The Samba password row is `zlyme` only when the stored NT hash is still MD4 of the UTF-16LE initial password, `(changed)` for another valid hash, and `(unavailable)` when the file is missing or damaged. The Syncthing rows come from `zlyme-syncthing-gui about`, once per opening. That is the same parse the init script uses. The account row is the GUI user. The password row is `(set)` when the parsed value is a bcrypt hash, and `(unavailable)` otherwise. An XML comment is not a username or a password. About does not display the hash, does not keep a second copy of either password, and does not start Syncthing. It does not edit Samba or Syncthing passwords. Clearing removes the password file only after the empty shadow field is written. If that write fails, the previous file and hash stay. Reset Settings and Factory Reset delete the file and restore the empty field. The exFAT mode is not a confidentiality control.

The updater's download confirmation and queued-reboot screen say that installing may reboot more than once. The displayed rate is about two seconds of newly received bytes. A resumed prefix is not part of that rate. Byte progress and the total size stay as they were.

Reset Settings runs `zlyme-reset settings`. It deletes an explicit list of Zlyme flags, `proxy.conf`, the SSH password file, the NextUI settings file, the timezone, and the Files (VTree) config. It then recreates the timezone and card defaults and asks the owning scripts to apply the restored defaults. Games, saves, Wi-Fi networks, and paired Bluetooth devices stay. Factory Reset runs `zlyme-reset factory`: the same reset plus a `factory-reset` marker, which makes the next `nextui-session` start overwrite the stock Tools and Emus PAKs on the card. Personal content stays. Reset PortMaster is on the Game page. It runs `zlyme-reset portmaster`. It deletes the selected live PortMaster tree and PortMaster's own config. Installed ports stay. The next PortMaster or port launch unpacks the seed again. Settings lists use the standard button hints. The list area ends at the top of those hint pills, so the selected description is not drawn on them. A custom page that draws its own controls owns that area: the keyboard, the color picker, release notes, and the full-screen joystick tools. After a verified Recovery arm, disarm, or stock restore, Settings offers Shut down or Restart. Those write `/tmp/poweroff` or `/tmp/reboot`, and `nextui-session` runs `zlyme-halt`. That verified action does not write NAND again in the same Settings process: Back returns to the confirmation, and A reopens the power choice. A failed write, a verified rollback, a refusal, or a CRITICAL result stays on the diagnostic text and can be tried again. Restart is a normal reboot. MASKROM entry is still shut down, the right-hand bootable card removed, then a cold power-on.

### PortMaster installation

`/usr/share/portmaster/PortMaster.zip` in the squashfs is the immutable seed. `<root>/Roms/.portmaster/PortMaster` on the selected library is the active installation. Font archives in that tree are decompressed with xz and then unpacked with tar. The system tar does not open an `.xz` file by itself. `zlyme-portmaster-prepare` owns that lifecycle. Tools → PortMaster and `PORTS.pak` both call it, so a port started after reboot does not depend on the PortMaster GUI having run earlier in the boot. PortMaster-GUI has one ports directory, the library selected for installs. NextUI still lists each card's Ports folder. A union of those folders is not used.

`<root>` is the library from `zlyme-portmaster-root`. An empty choice is `/storage`. An explicit non-primary choice is mounted only when that exact path is a line in `/run/zlyme/libraries` and the same path is a current mount. A library-list line without that mount, or a mountpoint directory that remains after the card is gone, is not a mounted volume. `/storage` is the built-in primary. A non-primary choice that fails either check reports `PortMaster disk is not inserted`. Prepare does not switch to another disk.

`/opt/system/Tools/PortMaster` links to `/run/portmaster/PortMaster`. Prepare points that runtime path at the live tree. `libs/` and `runtimes/` are directories in that tree. They are not separate links.

A valid live tree is left in place when a later Zlyme update ships a different seed. The seed is used only when no valid live tree exists, or after Reset PortMaster. Replacing an invalid tree moves the old directory aside first. If the new tree cannot be published and the old directory cannot be moved back, prepare leaves that old directory at the backup path it prints. Zlyme integration (`control.txt`, `mod_Zlyme.txt`, the hardware identification patch, and the Zlyme scheme) is applied from `/usr/share/portmaster/zlyme/` at prepare time. An upstream PortMaster update may replace upstream files. The next prepare puts the Zlyme files back. The proposed files are checked before any of them replace the live copies, and a file whose bytes did not change is not rewritten. Miyoo Flip's device identity, `PlatformZlyme` as a subclass of `PlatformBase`, the Zlyme colour scheme, and the control and mod files all have to be present. A live tree that still maps `zlyme` to `PlatformROCKNIX` is rewritten to that class. The class does not copy JELOS PortMaster files. If the upstream tree no longer accepts that patch, prepare fails and does not publish a half-applied tree.

The launcher does not pass `pugwash --no-check`. That flag only skips the startup version offer. Update PortMaster in the GUI still installs `PortMaster.zip` into the live tree and creates `.pugwash-reboot`. The launcher treats that file as a restart: it prepares again, then starts the new GUI.

`/storage/PortMaster` and `<root>/Roms/Ports (PORTS)/PortMaster` are obsolete PortMaster engines. Prepare does not read them, copy them, or delete them. Installed games stay in `Roms/Ports (PORTS)`. A new live tree does not contain downloaded runtimes. PortMaster refreshes its own catalogue, and a port downloads the runtime it needs.

A missing live path, or a path that is not a real PortMaster directory, is installed from the seed. Prepare moves the previous path aside only while that publish is in progress. After the new tree is in place, that temporary copy is removed. A failed publish puts the previous path back. The seed is not merged with the previous tree.

PortMaster `control.txt` sets `clibs=/usr/lib/compat` and `get_controls` prepends that directory to `LD_LIBRARY_PATH`. Runtime wrappers then prepend their own library directory. The system dynamic linker does not search `/usr/lib/compat`. `portmaster-theora-compat` installs the libtheora 1.1.1 decoder there (`libtheoradec.so.1`) because LÖVE 11.5 was built against that SONAME. The system libtheora remains 1.2 (`libtheoradec.so.2`). `portmaster-xml2-compat` installs libxml2 2.13.9 as `libxml2.so.2` in that directory. `portmaster-rocknix-compat` installs the allowlisted legacy SONAMEs from pinned `ROCKNIX/packages` `691f24bceb72228f20d41ddb4a1e76ed76a1b0b8` there as well. It does not install the archive's SDL2 objects. NextUI's session path does not include `/usr/lib/compat`. Port scripts that prepend their own library directory after `get_controls` keep that directory ahead of the compat path.

`nextui-session` exports `LD_LIBRARY_PATH=/storage/.config/zlyme/lib:/usr/lib`. `portmaster-launch` starts the PortMaster GUI and prepends `/usr/share/nextui/lib:/usr/lib`. `PORTS.pak/launch.sh` starts one port and does not set `LD_LIBRARY_PATH`, so the port inherits the session value. A port that calls `get_controls` then has `/usr/lib/compat` in front of that. `zlyme-portmaster-exec` does not change the variable. The Weston wrapper it can install prepends that runtime's `lib_aarch64` for the AArch64 Weston path.

`zlyme-armhf-runtime` installs `/lib/ld-linux-armhf.so.3` and `/usr/lib/zlyme-armhf/` into the product rootfs. The bytes come from `output-armhf`, built by `scripts/build-armhf-sysroot.sh` from `configs/zlyme_my355_armhf_defconfig`. glibc's `libdir` and `slibdir` are the private directory, and `rtlddir` is `/lib`, so the loader's built-in search path is `/usr/lib/zlyme-armhf/`. AArch64 `libc.so.6` and `ld-linux-aarch64.so.1` stay where they are. The recipe reads `/zlyme/armhf/zlyme-armhf-runtime.manifest`, checks the hashes and the defconfig, and fails if the tree is missing, stale, or AArch64. It does not start a second Buildroot. The minimal image does not select the package. Kernel `CONFIG_COMPAT` and `CONFIG_COMPAT_BINFMT_ELF` are already enabled. `control.txt` exports `DEVICE_HAS_ARMHF=Y` after `device_info.txt`. On a Flip, `xdelta3.armhf` printed `Xdelta version 3.1.1` through `/lib/ld-linux-armhf.so.3`, with `libc.so.6` from `/usr/lib/zlyme-armhf`. The bit is that ABI. It does not mean every ARMHF port runs. `DEVICE_ARCH` stays `aarch64`.

Box86 is built natively by that ARMHF target and imported through its own manifest. `zlyme-box86-run` accepts only ELF32 little-endian i386 input, replaces the inherited AArch64 native library search with the private ARMHF search, and then starts Box86. A port can name additional verified ARMHF directories through `ZLYME_BOX86_NATIVE_LIBRARY_PATH`; x86 guest paths remain Box86's own contract. There is no binfmt registration or service. Box64 remains the AArch64 x86-64 runtime, `BOX32` stays off, and Wine remains the amd64 WOW64 build.

The ARMHF target's supported graphics provider is Mesa/Panfrost. Zlyme has no licensed matching ARMHF build of the proprietary libmali stack. ARMHF EGL, GLES, GBM, the Panfrost DRI driver, and their libraries stay under `/usr/lib/zlyme-armhf/`; they are not copied into the AArch64 library directories. ARMHF `libgbm` looks for its backend in `/usr/lib/zlyme-armhf/gbm`, not in the AArch64 `/usr/lib/gbm`.

Native ARMHF PortMaster programs, such as GameMaker's 32-bit `gmloader`, find SDL2 2.32.10 (KMSDRM and OpenGL ES, with the board SDL2 patches), OpenAL Soft, FreeType, and bzip2 in that same directory. A port launcher may put AArch64 directories on `LD_LIBRARY_PATH`. The ARMHF loader skips an AArch64 object of the same name and continues to the private directory. Launch scripts and the global library path are unchanged. ARMHF audio does not use ALSA, because the default ALSA PCM is the AArch64 PipeWire plugin. SDL2 and OpenAL load the PulseAudio client library, which reads `/etc/pulse/client.conf` and connects to `pipewire-pulse`. The ARMHF build has no PulseAudio daemon and no second audio graph. GLib, libsndfile, and libltdl come in because Buildroot's PulseAudio recipe selects them. Native ARMHF graphics need a Panfrost boot. ARMHF GL4ES is under `/usr/lib/zlyme-armhf/gl4es`, outside the global linker search path. Box86 ports opt in through `ZLYME_BOX86_GL4ES_RUN`, after any explicitly named port-bundled native library path. System EGL/GLES/GL links are unchanged. Port-bundled AArch64 GL4ES also stays private to its game. Zlyme's unused AArch64 fallback and its acceptance probes were removed during Phase 14P after the installed fallback produced a black screen and the consumer audit found no installed port using it.

## 12. Emulator model

Zlyme deliberately ships a curated set.

Prefer one default backend per system. Multiple backends are justified only when they provide real compatibility/performance value.

The emulator packages themselves should remain device-agnostic when upstream allows it.

Device-specific tuning belongs in:

- launch/runtime profiles;
- board governor implementation;
- device-specific core/build flags only when measured.

PICO-8 runs the user-supplied native runtime pair `pico8_64` + `pico8.dat`. `pico-runtime.sh` looks in the ROM library's BIOS first, then in every active library. `PICO.pak` runs that runtime, or the `fake08` core when that core is selected. `zlyme-pico-splore`, called by `zlyme-storage`, shows one synthetic Splore entry only while a runtime pair exists, in the Pico-8 folder of the library that holds it.

RetroArch's stock configuration is `/usr/share/zlyme/retroarch/retroarch.cfg`. `zlyme-stock-seed` copies it to `/storage/.config/retroarch/retroarch.cfg` when that file is missing or empty, and when Reset RetroArch configuration runs. `ra-run` does not write that file. Session values go through `--appendconfig`. RetroArch 1.22.2 installs a file at `/etc/retroarch.cfg` and uses it as the skeleton only when it creates a missing user file. The overlay at that path has no settings. The stock file sets `config_save_on_exit` to false. Saving the configuration from RetroArch's own menu still writes the running settings.

`zlyme-core-sync` copies `/usr/lib/libretro/*_libretro.so` to `/storage/.config/retroarch/cores/`. A reboot without an update leaves a file you replaced. An update restores each included filename. A core the image does not include stays. The online core installer is not built.

FinalBurn Neo and MAME 2003-Plus look up BIOS archives themselves. The order is in `docs/USER_GUIDE.md`. `zlyme-arcade-stage` is not in the tree.

RetroArch 1.22.2 draws RGUI into a 320×240 buffer and scales that buffer. The scale options in that version do not enlarge the glyphs. That limit stays open.

AetherSX2 1.0.0 has no folder argument. `-bios` starts the system menu. `start_aethersx2.sh` rewrites the BIOS, savestate, and memory-card lines to the active library on each launch. The other lines in `PCSX2.ini` stay.

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
S20alsa          restore the RK817 hardware mixer
S25jackd         zlyme-jackd
S26keylidmon     zlyme-keylidmon
S28minui         start nextui-session in the background
```

### Deferred

Can start after first frame, such as networking, Bluetooth, SSH, time sync, Samba, Syncthing, noncritical udev triggering, and similar services.

After the first-frame gate (section 5), `rc.late` starts these in the background: seedrng, syslogd, klogd, sysctl, Avahi setup, zram, LEDs and the `smart` governor profile (`S27led`), udev coldplug for everything except block devices (`S29udevtrigger`), IRQ affinity, network, Avahi, crond, `zlyme-net-services`, Samba's init script, Wi-Fi, and `S49ntp`. `zlyme-net-services` starts SSH, Samba, and Syncthing only when Wi-Fi is on and that service is enabled. Turning Wi-Fi off stops all three. Settings and the quick menu call that same helper without waiting for it. One short-lived worker serializes those passes and rereads the saved flag after it takes the lock. `rc.late` still starts the helper in the background after the first frame. The quick menu treats the saved Wi-Fi flag as enabled, whether or not the radio has associated. A separate background chain starts D-Bus, then forks InputPlumber, `zlyme-input`, `btusb`, and `bluetoothd` beside `S33pipewire`. PipeWire does not wait for Bluetooth, and input does not wait for a codec node. There is no `S21pulse`, `zlyme-btsink`, or BlueALSA in that chain. After an OTA it also runs `zlyme-update reapply`.

Because udev coldplug is deferred, modules that load from a Device Tree modalias, such as `rk3568_dmc.ko`, load after the first frame.

### On demand

Should not run persistently unless enabled or requested.

The BusyBox `rcS` / `rc.late` split is intentional.

### USB file transfer

USB file transfer stays off through boot. A cable on the lower USB-C port does not start it. Tools → USB Transfer calls `zlyme-usb-transfer start` after the confirmation screen. There is no init script. fstab and the initramfs do not mount configfs. The initramfs mounts sysfs.

`zlyme-usb-transfer` (`package/system/zlyme-usb-transfer/zlyme-usb-transfer`) owns one configfs gadget, `zlyme-mtp`. On start it mounts configfs at `/sys/kernel/config` when that path is not already a configfs mount, and it refuses to mount over a different filesystem. An existing configfs mount is reused. It then mounts FunctionFS and starts Buildroot's `umtprd` through `/usr/sbin/zlyme-usb-enter` (`package/system/zlyme-usb-transfer/zlyme-usb-enter.c`). That program creates a private mount namespace, bind-mounts only the export directories and the FunctionFS mount, and `pivot_root`s onto that tree before exec. The configuration stays under `/run/zlyme/usb-transfer`. The helper waits until `ep1`, `ep2`, and `ep3` exist. It writes the UDC name only when the lower PHY extcon reports SDP or CDP. That name is `ZLYME_USB_GADGET_UDC` from `device.conf`. On my355 it is `fcc00000.usb`, the DWC3 at `usb@fcc00000`. The helper binds that directory only. DCP, no cable, and a classification that is still all zeros leave the responder and FunctionFS up and the UDC unbound. A missing or unreadable extcon fails the start. It is not treated as DCP. Writing the UDC name starts DWC3 and enables EP0, so that write waits for a data-capable reading. The watcher stays up while the gadget directory exists. When SDP or CDP appears, it binds once and does not also write `soft_connect`. That bind is the connection attempt. `ep0out/transfer_type` is the descriptor class of an enabled endpoint. It is not an input. After the bind, `configured` and `suspended` are left alone, including when a later reading says DCP. If the host state leaves those two values, the watcher does not write `soft_connect`. A returning data cable does not write it either. Linux 7.2.10's disconnect event leaves `DCTL.RUN_STOP` set. The sysfs `disconnect` path is what clears that bit, and the matching `connect` path sets it again after a core soft reset. This helper does not take that path. A bound UDC whose kernel state is not `configured` or `suspended` stays latch `pending`. That latch is not a reconnected host. A physical replug inside one session was not measured. On 2026-10-14 the installed image is the E32 archive: squashfs `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c` and helper `9fc37d2e9f2f831f194691be3f3ff6de046f8d188fad86a3094bdecb6ee00859`, with no `soft_write`. The maintainer accepts that image for ordinary transfer and for opening the tool again with the cable left in place. Within-session cable recovery stays unverified. The earlier E30 image remains the rollback. 12D-E33 had read an earlier boot that was still E30. That reading is not this install. A `failed to enable ep0out` line does not get a disconnect and a connect. That one-shot repair is absent from the installed development image. The maintainer reports that USB File Transfer works on it. That report is not a new file checksum. The installed kernel no longer republishes a missing SDP or CDP extcon from the USB2 PHY peripheral state. The maintainer reports that USB File Transfer works on that image. That report is not a new file checksum. The board DTS no longer sets `snps,dis_enblslpm_quirk` on the lower USB controller. On 2026-10-14 that image was installed. The live tree lacks the property, and a stopped read of `GUSB2PHYCFG(0)` was `0x40101508`, so bit 8 was set. Later the same boot had a PAK session at high speed. Disposable files copied both ways through MTP, including one file on the mounted second card, and the SHA-256 values matched. The cable was left in place. B and a second Start were not pressed. `snps,dis_u2_susphy_quirk` remains. DCP and the RK817 charger type do not count as a data host. Linux 7.2.10's `soft_connect` store returns the write length and does not check the DWC3 pull-up result, so a write is not enumeration and it is not repeated after a failure. The responder stays running: its configuration sets `loop_on_disconnect`, and FunctionFS disable does not close the endpoint files. `stop` still owns unbinding the UDC. The watcher is in the tool's process group and `stop` kills it. On 2026-10-12 that sequence was hardware-exercised and the host did not enumerate the gadget. The investigation is `docs/research/phase-12d-usb-mtp.md`. No role, VBUS, or regulator write is added. An empty UDC class, any other controller, or a gadget that already holds `fcc00000.usb` is a failed start. The other gadget's UDC file is left as it was. The helper does not write a USB role, a VBUS supply, or a regulator. The Settings OTG overlay disables the upper host (`usb@fd800000` and `usb@fd840000`) and is not a switch for this gadget. A missing `fcc00000.usb` is reported as-is.

The export list is the roots of mounted data filesystems, snapshotted when the session starts. `/storage` is the MTP storage `SDCARD1`. `/mnt/sd2` is `SDCARD2` when `/run/zlyme/libraries` lists it and that path is the mount. Each `/mnt/media/<name>` line in that file is one USB volume, shown as `OTG`, then `OTG 2`, and so on. The directory name is the mountpoint, not the MTP label. A second label that matches an earlier one gets a ` 2` suffix. A missing second card or USB stick is skipped and does not fail the SDCARD1 share. A stick that appears after `start` is not added. uMTP accepts 16 storage entries. Further volumes are skipped, and `status` names them.

A share does not require a `Roms` or `Bios` directory. The filesystem has to be kernel `exfat`, `vfat`, or `ext4`. ext4 is included only while `zlyme-usb-enter` confines the responder. A read-only mount is included with uMTP's `ro` option and is not remounted read-write. NTFS, FUSE, and the other types stay mounted and are not shared. A nested mount under `/storage` refuses the session, because the clone is not recursive and would hide that content. A nested mount under another volume skips that volume.

`/boot` is not a share, and the session does not unmount it. A mount whose source is the filesystem mounted at `/boot`, or `ZLYME_BOOT_DEVICE` when that is set, is the boot volume even if its path is `/mnt/sd2` or a USB directory. A filesystem label, including another `ZLYMEBOOT`, does not decide that. `/dev`, `/sys`, and `/proc` are not shares. The configuration does not name a block device.

Exporting `/storage` includes `.config`, `.logs`, and `.update`. They live on that filesystem. They are not separate MTP entries, and a path that names one of them is refused. uMTP-Responder 1.8.1 follows symlinks (`stat64` in `fs_entry_stat`, and `open` in `entry_open`), including a link created while the session is up. The private namespace is the confinement: each export is opened with `O_NOFOLLOW` and cloned with `open_tree` without `AT_RECURSIVE`. A link can reach a directory inside the cloned filesystem, including `.config`. It cannot name `/boot`, `/dev`, `/proc`, `/sys`, or a path that was not cloned. A nested mount is not copied in. The unreleased uMTP `realpath` prefix check was not adopted. `start` returns before creating the gadget when `/storage/.update/reconstruct` or `/storage/.update/pending/zlyme` exists. The session uses the mounted filesystem. It does not unmount `/storage` and it does not remount a read-only volume.

`stop` clears this gadget's UDC file, signals the recorded pid only when `/proc/<pid>/cmdline` is this `umtprd` and this configuration file, unmounts the FunctionFS mount, and removes the `zlyme-mtp` configfs directory. If this session mounted configfs and no other gadget, nested mount, or second configfs mount is using it, `stop` unmounts that configfs too. Otherwise the configfs filesystem stays mounted. That is not an active gadget. If the owned responder cannot be killed, the pid file and configuration path stay, and `stop` fails. A later `start` or `stop` can try again. It does not signal a pid whose command line is some other process.

MENU+START keeps the same user behavior: `zlyme-pak-hotkey` signals the identity-pinned spawn waiter, which performs bounded TERM/KILL cleanup of the PAK session. Before the gadget exists, `start` runs `setsid` on a reaper that is not in that session. The rootfs BusyBox provides `setsid`. The initramfs BusyBox does not, and this helper does not run there. The reaper calls `stop` once when the group leader's `/proc` start time is gone, then it exits. It is not a boot service. A normal exit from the tool calls `stop` in the PAK and shows the failure when teardown did not finish. After reboot the `/run` directory is gone, so transfer is off.

The USB identity is the Linux Foundation PTP gadget id used by the uMTP sample, `1d6b:0100`. It is a shared sample id. The serial string is the constant `zlyme`. `max_speed` is `high-speed` because the uMTP 1.8.1 FunctionFS descriptors have no SuperSpeed configuration. The configuration is self-powered (`bmAttributes` `0xC0`) with `MaxPower` 2, which is 2 mA on Linux 7.2.10. Charging stays on the RK817 path.

`status` reports `off` when this session owns nothing, `waiting` when the responder and FunctionFS are ready and the UDC is not bound, `bound` when this gadget holds the controller, and `partial` when the session is incomplete. `host=configured` is the kernel UDC state. The waiting screen says it is waiting for a USB data connection and shows B to stop. The bound screen says the session is open, names the storages that were exported, and shows B to stop. Neither screen says the computer is connected, and `state=bound` is not host enumeration. On 2026-10-12 the host did not see the gadget. On 2026-10-13, 12D-E21 enumerated `1d6b:0100` at high speed on one identified host port, and a separate read-only mass-storage gadget on that same port. No file was copied. The filesystem-root export in this section is host-tested. It is not the image used for 12D-E21. 12D-E22 installed it, the gadget started, and that computer saw no USB device. On 2026-10-14 the installed image that contains this bind was seen at high speed as `1d6b:0100`. 12D-E25 listed storage names and did not verify a file. The maintainer later reported that the cable was disconnected during that pass. 12D-E26, on the following boot, copied disposable files both ways through MTP and the SHA-256 values matched, including one file on the mounted second card. That match is the file baseline. 12D-E27 found the gadget gone. The maintainer reports a second Start and MENU+START succeeded. The host log shows the disconnect and no later device. That E27 report is not hardware acceptance. The later installed E32 image is accepted by the maintainer, with within-session cable recovery unverified. The record is `docs/research/phase-12d-usb-mtp.md`.

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

The Phase 6 hardware acceptance record is in `docs/archive/roadmap-2026-10-15.md` and `docs/research/phase-06-deep-suspend.md`.

### DDR frequency scaling (DMC)

DDR devfreq is the out-of-tree module `rk3568_dmc.ko` from `package/drivers/rk3568-dmc`, installed by Buildroot's kernel-module package under `/lib/modules/<running release>/updates/`. The release is the Linux pin in `docs/DEVELOPMENT.md`, currently 7.2.10, so the file is `updates/rk3568_dmc.ko` in that directory. It is not a kernel patch. Its Device Tree contract is that package's `README.md`. It needs BL31's DDR SIP API version `0x101` or newer, the in-tree Rockchip DFI devfreq-event driver for load, and `center-supply = <&vdd_logic>`. Kernel patch `1010` adds suspend/resume to that DFI driver. The Flip OPPs are 324, 528, 780, and 1056 MHz, all at 900 mV. The driver's default governor is `simple_ondemand`.

There is no `modules-load.d` entry or init script for it. It loads from the `rockchip,rk3568-dmc` modalias during the deferred udev coldplug in `rc.late`. Before suspend it returns DDR to the boot rate.

Runtime policy belongs to `zlyme-governor`. The `smart` and `idle` profiles hold DMC at `powersave` 324 MHz. The `play` and `heavy` profiles use `simple_ondemand` from 528 to 1056 MHz. After resume, `zlyme-radios resume` reopens the DMC range once and restores the previous profile.

The Phase 7 hardware acceptance record is in `docs/archive/roadmap-2026-10-15.md`.

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
