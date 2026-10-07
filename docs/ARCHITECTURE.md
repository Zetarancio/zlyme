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
Buildroot 2026.02.3
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

Upstream Buildroot is not modified. `build.sh` pins Buildroot `2026.02.3` (a shallow clone of that git tag) and runs Buildroot inside the `zlyme-build` Docker image built from `Dockerfile`. Zlyme adds packages through `Config.in` and `external.mk`, target configurations through `configs/`, and board integration through `board/`.

`Config.in` offers one device choice, `BR2_ZLYME_DEVICE_MY355`. That choice sets `BR2_PACKAGE_NEXTUI_PLATFORM="my355"`.

There are two defconfigs. `zlyme_my355_defconfig` is the product image. `zlyme_my355_minimal_defconfig` leaves out the frontend, emulators, and Mali stack, and is the `build.sh` default.

The global `external.mk` stays small. It includes every `package/*/*/*.mk`, includes `board/my355/board.mk` only when `BR2_ZLYME_DEVICE_MY355=y`, and holds cross-package workarounds that are not board-specific (Mesa without LLVM draw, SDL2 Vulkan, fluidsynth without SDL, libclc's unwrapped clang, the Python sysconfigdata fix).

Miyoo Flip-only Linux and U-Boot hooks live in `board/my355/board.mk`, not in the global file.

Kernel and U-Boot patches come from `BR2_GLOBAL_PATCH_DIR` in a fixed order: `board/my355/linux/patches/10-mainline`, `20-rk3566`, `30-default`, `40-kernel-7.0`, then `board/my355/uboot/patches`. The order is load-bearing. The same directories carry `linux.hash` and `uboot.hash`.

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
```

`post-build.sh`, `post-image.sh`, `make-update-tar.sh`, `zlyme-update`, and the Settings release lookup read it. The initramfs carries the same file.

`ZLYME_OS_DISK`, `ZLYME_BOOT_DEVICE`, and `ZLYME_STORAGE_DEVICE` are the current my355 OS card. They are not a requirement that another board use MMC or these names. The right-hand slot is `sdmmc0`. The my355 DTS aliases `mmc0` to `&sdmmc0` and `mmc1` to `&sdmmc1`. Linux 7.0.2 uses that `mmc` alias as the MMC host index, and the MMC block driver names the disk `mmcblkN` from that index, so this tree makes the right slot `/dev/mmcblk0`. Pinned U-Boot `arch/arm/dts/rk356x-u-boot.dtsi` aliases `mmc0` to `&sdhci` and `mmc1` to `&sdmmc0`, so that same slot is U-Boot `mmc 1`. The SPL boot order stays `&sdmmc0`. `genimage.cfg` then places GPT partition 1 as `uboot`, partition 2 as `boot` (`ZLYMEBOOT`), and partition 3 as `storage` (`ZLYME`). The paths select those nodes. The labels confirm them. A cloned card repeats the labels, so boot, storage, resize, and raw bootloader writes do not search by label.

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
zlyme-led           status LED policy                      board overlay
zlyme-halt          shutdown and reboot                    board overlay
zlyme-storage       library mounts and library list        board overlay
zlyme-update        OTA verify, stage, apply               board overlay
zlyme-boot-write    one write transaction on /boot         board overlay
zlyme-ctl           Settings and system flags, apply-*     board overlay
zlyme-proxy         application HTTP/SOCKS proxy           board overlay
zlyme-reset         Reset Settings and Factory Reset       board overlay
zlyme-radios        radio stop and start around sleep      board overlay
zlyme-input         InputPlumber ownership and order       zlyme-input package
zlyme-drm-release   drop DRM master before a pak           nextui package
zlyme-weston-run    per-launch Weston for one client       board overlay
zlyme-wine-prefix   Wine prefix and dosdevices tmpfs    wine-amd64 package
gpudriver           GPU stack selection at boot            gpudriver package
```

Settings in the NextUI fork calls `zlyme-ctl`, `zlyme-proxy`, `zlyme-reset`, and `zlyme-led`. NextUI's sleep path and `zlyme-keylidmon` call `zlyme-radios`. `nextui-session` calls `zlyme-input ensure`, `zlyme-drm-release`, and `zlyme-halt`. `S15gpudriver` calls `gpudriver`.

Speaker/headphone routing is not a command. The `zlyme-jackd` daemon owns it. `zlyme-audio` reports and selects the sink.

`zlyme-governor` holds my355 knowledge: the RK3566 CPU OPP list, the DMC rates, and core hotplug. It is installed by the NextUI package from `package/system/nextui/zlyme/governor.sh`, not from `board/my355`. `nextui-session` applies `smart` before each `nextui.elf` start, which is the list and the return from a pak. Emulator PAKs call `zlyme-governor emu <tag>`. NextUI's my355 platform code sets `idle` on the way into sleep and `smart` in `PWR_exitSleep` when the frontend resumes. In a pak, `zlyme-keylidmon` sets `idle` around mem and then `resume`, which reapplies the pak profile in that same invocation. Applies are serialized with an exclusive `flock` on an empty file under `/run`. The kernel drops the lock when the process exits. `S27led` only drives the LEDs. A late DMC probe and `zlyme-update reapply` call `resume`, which reapplies the profile already recorded. `zlyme-ctl apply-gov` still means frontend `smart`. It is a manual or reset action; no boot service calls it.

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
Linux 7.0.2 with the embedded Zlyme initramfs
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

U-Boot is mainline 2026.01 from the `quartz64-a-rk3566` defconfig. The `board.mk` hook switches it to the local Flip control DTS, sets `BOOTDELAY=-2`, adds the preboot `my355 maskrom-request; my355 fg` (U-Boot patches `006` and `008`), and strips PCI, SATA, NVMe, Ethernet, SDHCI, and USB. U-Boot patch `002` sets the SPL boot order to `sdmmc0`. Patch `007` adds `rbrom` and does not change `BOOTDELAY`. Patch `008` consumes one boot-FAT request before the fuel-gauge helper.

The kernel command line is `earlycon quiet console=ttyS2,1500000n8`, with `console=` last so serial is `/dev/console`. It does not carry a `label=` key. The initramfs selects `/dev/mmcblk0p2` from device metadata and checks the filesystem label. `zlyme-ctl apply-overlays` writes the `FDTOVERLAYS` line from Settings flags: the HDMI, OTG, and SD2 disable overlays and the CPU undervolt level.

The initramfs is a static BusyBox `1.36.1` `/init` that `board.mk` embeds through `CONFIG_INITRAMFS_SOURCE`. It also starts the framebuffer splash, and writes a boot dmesg when `/boot/zlyme-logs` asks for one. That is the only other reason it opens `/boot` read-write.

Routine OTA never rewrites `idbloader.img` or `u-boot.itb`, and it does not copy `miyoo355_fw.img` onto the boot FAT. Only an explicit `zlyme-update uboot` rewrites the card bootloader.

A fresh `zlyme.img` places `miyoo355_fw.img` at the root of `ZLYMEBOOT`. That file is apommel's stock installer, generated by `tools/preloader-installer/mkfwimg.py` from pinned `apommel/baseos-my355` commit `e09d37bb0f03c34e564d61bd02164f332d8515a8` (`package/boot/my355-fw-installer`). It is not a preloader binary. Stock firmware, not Zlyme, reads it, backs up that unit's own preloader as `mtd5-original-<sha256>.img`, patches `/pinctrl` in the SPL device tree, and writes the result back. Flashing `zlyme.img` does not modify NAND by itself.

On Zlyme, the kernel exports only that 2 MiB region, DTS label `preloader`, so it is `mtd0`. The wiki's SPI NAND is ESMT, 128 KiB erase, 2 KiB pages, 64 B OOB. `zlyme-preloader` refuses any other identity. Settings → System → Advanced → Recovery can show preloader status, restore the stock backup, or reboot to MASKROM. Restore is the proven NAND backend: a failed write rolls back to the pre-operation preloader and does not report success. `erase-preloader` is the CLI name for removing that partition. It is not on the Recovery page, and a finished erase is not USB MASKROM while another loader can boot. `zlyme-maskrom` is the product request. It asks `zlyme-boot-write` to put the exact bytes `ZLYME-MASKROM-1` in `/boot/zlyme-maskrom.request` on the primary `ZLYMEBOOT` volume, checks those bytes, and then uses the ordinary reboot syscall. It does not pass a restart command, and it does not write PMUGRF or the CRU. If the file cannot be written or verified, it exits without rebooting. If that reboot call fails, the file stays and the next boot still carries the request. U-Boot preboot runs `my355 maskrom-request` on mmc 1 partition 2 before `my355 fg`. That is the right-hand `ZLYMEBOOT` volume: Linux calls the controller `mmcblk0`, and U-Boot calls it `mmc 1` because `rk356x-u-boot.dtsi` reserves `mmc 0` for `sdhci`. The command reads only `/zlyme-maskrom.request`. The bytes have to match exactly. It then deletes the file and checks that it is gone, and only then calls the same `zlyme_rbrom()` body as `rbrom`: `set_back_to_bootrom_dnl_flag()` and `do_reset()`. A missing file prints nothing and continues into the fuel-gauge helper. A file that is present prints `found on mmc1:2`, then `consumed, entering rbrom`, `invalid marker, booting normally`, or `could not consume marker, booting normally`. A wrong or empty file is left in place and does not enter download mode. A delete that does not stick does not enter download mode, so a request cannot loop. `CONFIG_BOOTDELAY=-2` is unchanged. On 2026-10-07 a direct Linux restart, which stored the download flag and wrote the CRU first reset from the kernel, reached `kernel_restart` on a Flip and then went silent: no DDR, no SPL, no U-Boot, and no USB `2207:350a`. A physical reset was required. That driver was removed and is not a fallback. The boot-file handoff is implemented and is not hardware-proven. Stock U-Boot `rbrom` remains the sequence that has enumerated `2207:350a`. None of this runs during an ordinary boot or an update. The image build also writes `miyoo355_fw.img.sha256` beside the installer. The OTA does not include either file.

A normal boot is BootROM, then the internal NAND preloader (DDR init and the stock SPL), then Zlyme U-Boot from the right-hand SD card, then Linux. The apommel repair makes that stock SPL read the card and load its U-Boot FIT. `rbrom` stores `BOOT_BROM_DOWNLOAD` and resets. BootROM loads the internal preloader again, and the early Rockchip SPL returns to BootROM download mode when it sees the flag. Zlyme does not replace the internal U-Boot, put a MASKROM loader in NAND, or erase the preloader in order to enter download mode.

On 2026-10-07 the maintainer wrote the image built from `0e09c31933bd5c429e5f24238307838717231c28`. The fixed preloader status page was readable. Reboot to MASKROM wrote the request, rebooted, and returned to Zlyme with `/boot/zlyme-maskrom.request` still present. The uploaded logs are normal boots and do not show U-Boot reading the file. The surviving marker means that consumer did not consume it. That build opened U-Boot `mmc 0:2` (`sdhci`). `rbrom` was not reached, so that test does not classify `rbrom` as failed. The `mmc 1:2` consumer has not been run on a Flip.

Restore writes the one valid `/boot/mtd5-original-<sha256>.img` when that file exists. If it does not, and the installed preloader is byte-for-byte the wiki patched image `ed10591f62ae0b8845ac9bd6cf80c896a2b172d32c7c4ef6564d305e8662c13d`, restore may write `/usr/share/zlyme/recovery/preloader-stock.img` after the same structure and DDR checks. Any other installed preloader is refused, including one whose DDR blob matches and whose SPL does not. There is no force switch. The stock file is `preloader-stock-rocknix/App/apommel-multiboot/preloader-stock.img` from wiki commit `c126d3235face9ddca5bf021258a84758dca543c`, SHA-256 `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922`. The wiki shows that those bytes are the first 2 MiB of `spi_20241119160817.img`. It does not grant a license to redistribute Miyoo's preloader. A public Zlyme release is not cleared to ship the file until that grant exists. `package/system/zlyme-preloader/preloader-stock.PROVENANCE` records the same gap.

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

Mounted libraries are the lines in `/run/zlyme/libraries`. Content stays on the library that holds it:

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

PortMaster software that needs X11 uses PortMaster's own WestonPack, which brings Xwayland for that launch. WestonPack is application-scoped and stays owned by PortMaster. Its cleanup is Zlyme's: `nextui-session` runs `zlyme-portmaster-cleanup` before and after every `PORTS.pak` launch, outside the pak's process group, because MENU+START kills that group. The cleanup sends TERM to processes holding `/tmp/weston`, sends KILL after 6 s, and unmounts it.

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

- Mesa/Panfrost (GLES only);
- vendor Mali (`mali_kbase` + libmali, GLES and Vulkan).

They cannot own the GPU simultaneously. Selection is reboot-level policy.

The default is libmali. The choice is the flag `/storage/.config/zlyme/gpu`, which the Settings Advanced → GPU option writes and which takes effect on the next boot. A static `blacklist panfrost` in `/etc/modprobe.d/zlyme-gpu.conf` keeps udev from binding Panfrost before the flag is read. Class A `S15gpudriver` runs `gpudriver`, which reads the flag, bind-mounts a runtime blacklist for the other stack over that file, and loads one kernel module. For libmali it also bind-mounts the blob over the files behind Mesa's `libEGL.so.1`, `libGLESv1_CM.so.1`, `libGLESv2.so.2`, and `libgbm.so.1`, so applications link one set of names.

`/etc/zlyme-gpu-env.sh` exports the Mali Vulkan ICD only for libmali. Buildroot's Mesa has no PanVK, so Vulkan exists only with libmali.

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

The suspend helper is `package/system/nextui/zlyme/suspend`, installed as `/usr/share/nextui/bin/suspend`. Published `zlyme44` clears any RTC wake alarm, then programs a relative alarm of 86400 s before it syncs and writes `mem` to `/sys/power/state`. That timer is software policy left over from the 2026-09-13 timed-suspend test (`083e8061c47354325e7356966541642bb3062cfe`). No Miyoo Flip hardware limit of 24 hours is documented, and a full 24-hour suspend was not part of hardware acceptance. Normal wake sources (power button, volume keys, lid open) are separate. The current `zlyme44.1` source does not read, clear, or program `/sys/class/rtc/rtc0/wakealarm`. An alarm programmed on purpose is preserved. RTC support stays in the kernel, and an RTC wake remains a valid hardware wake source. `zlyme44.1` is device-accepted at `6a398b311310246ef6a5515ed72805c6f58d787d` and is not published. The acceptance record is in `docs/MAINTENANCE.md`.

`zlyme-radios pre` stops Bluetooth before Wi-Fi: it saves the BlueZ store, then stops `zlyme-btsink`, BlueALSA, `bluetoothd`, and Wi-Fi. Bluetooth goes first so `rtl8733bu_power` can cut the combo chip in its late suspend phase without hanging `hci_dev_close`. `zlyme-radios resume` starts Wi-Fi first, then `btusb`, `bluetoothd`, BlueALSA, and `zlyme-btsink`, reopens the DMC range once, and keeps `/tmp/zlyme-keep-emu` for 25 s so the combo chip's re-enumeration does not make `zlyme-btsink` kill the emulator. NextUI runs `zlyme-radios resume` in the background.

Kernel patch `9901` disables async suspend/resume by default. On the Flip, mem suspend is BL31 deep suspend (see "Deep suspend" below).

## 11. Frontend and PAK runtime

Zlyme is the OS. NextUI is the frontend.

ZcrapeGoat is the built-in artwork, manual, and cheat tool. Its tree is a vendored upstream import plus ordinary Zlyme commits, not a patch stack. It reads `/run/zlyme/libraries`. Artwork stays beside the ROM. Cheats stay on `/storage/Cheats`.

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

Settings stores Zlyme policy as one file per flag, `/storage/.config/zlyme/<name>`, through `zlyme-ctl get` and `set`. Init scripts read the same flags with `zlyme-ctl want`. An empty or missing file means the default in `zlyme-ctl`, which matches the `S15bootpart` seed. The application proxy is the exception: one file, `/storage/.config/zlyme/proxy.conf`, read and written by `zlyme-proxy`. The updater asks that helper on each request. `nextui-session` applies it to the environment of a pak at launch. It is not a transparent tunnel. The helper creates that file with a restrictive mode when the filesystem can store one. `/storage` is exFAT, so the mode is not stored and is not a confidentiality control. The file has no credentials.

Reset Settings runs `zlyme-reset settings`. It deletes an explicit list of Zlyme flags, `proxy.conf`, the NextUI settings file, the timezone, and the Files (VTree) config. It then recreates the timezone and card defaults and asks the owning scripts to apply the restored defaults. Games, saves, Wi-Fi networks, and paired Bluetooth devices stay. Factory Reset runs `zlyme-reset factory`: the same reset plus a `factory-reset` marker, which makes the next `nextui-session` start overwrite the stock Tools and Emus PAKs on the card. Personal content stays.

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

### Wi-Fi and Bluetooth

Wi-Fi and Bluetooth share one RTL8733BU USB combo chip:

- `rtl8733bu_power` (package `rtl8733bu-power`) owns the chip's enable GPIO. It registers one WLAN and one Bluetooth rfkill and cuts power when both are blocked. It also cuts power in its late suspend phase;
- `8733bu` (package `rtl8733bu`) is the Wi-Fi driver. `/etc/modprobe.d/8733bu.conf` keeps IPS and radio power save off, because the Bluetooth half needs the shared firmware alive;
- `btusb` is blacklisted against modalias loading and has `softdep btusb pre: 8733bu`. `S35btusb` loads it by name after Wi-Fi.

Nothing loads the combo chip at boot. `zlyme-combo` loads `rtl8733bu_power` and `8733bu` on demand and toggles rfkill. `rc.late` runs `S30wifi`, `S35btusb`, and `S40bluetoothd`, and each does nothing unless its `wifi` or `bluetooth` flag is on (both default on). The BlueZ store lives on tmpfs (`/run/bluetooth`) because exFAT cannot hold its file names. `zlyme-bluetooth` saves and restores it as `/storage/.config/bluetooth.tar`. The Wi-Fi regulatory country is the global `country=` line in `/storage/.config/wpa_supplicant.conf`, written by `zlyme-wifi`. No line means world (`00`).

### Time

The RTC and the system clock are UTC. After Wi-Fi has a default route, `S49ntp` reads the HTTP `Date` header from `http://1.1.1.1`, sets the system clock as UTC, and writes the RTC with `hwclock -u -w`. It does not use the NTP protocol. `/etc/localtime` is a squashfs symlink to `/storage/.config/nextui/shared/localtime`, which `zlyme-timezone` maintains. `S15bootpart` ensures that file exists before NextUI starts.

## 14. Package boundary

`package/` should contain reusable software packages.

A package may be used only by `my355` today without being moved under a fake generic framework.

When a package is inherently board-specific, express that dependency explicitly in Kconfig or keep the hardware implementation in the board overlay.

Examples:

- `zlyme-jackd`, `zlyme-keylidmon`, `zlyme-input`, `miyoo-flip-gamepad`, `rk3568-dmc`, and `rtl8733bu-power` depend on `BR2_ZLYME_DEVICE_MY355` in Kconfig, even where the package directory is under `package/system`.
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
