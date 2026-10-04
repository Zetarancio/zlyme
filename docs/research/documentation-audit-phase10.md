# Phase 10 documentation audit

> **Status: audit evidence, not architecture.** Date: 2026-10-04.
>
> - Current architecture lives in the canonical documents: `AGENTS.md`, `docs/ENGINEERING_PRINCIPLES.md`, `docs/ARCHITECTURE.md`, `docs/DEVICE_PORTING.md`, `docs/DEVELOPMENT.md`, `docs/OPERATIONS.md`, `docs/UPSTREAMS.md`, and `docs/MAINTENANCE.md`.
> - This file records the Phase 10 reconciliation of source, git history, and documentation.
> - Runtime evidence remains the Phase 9 SHA `337ccbce2587393463a4b49c551f94e33e318e44` (`zlyme44 (2026-10-03)`).
> - The later Phase 10 documentation SHA is documentation guidance. It is not replacement runtime evidence.

## Scope and method

- History range: `dffddbacfcc8dcbffe96316013e9255c71941729` ("Start the Zlyme Buildroot tree.") through `d3bee63568e0482916f66821093b102b115eb19f` on `phase-10-maintenance`.
- 487 commits. 484 are on the first-parent chain. 2 are merges: `19aebc095a6f` and `be4278767518`.
- Every commit was inventoried (SHA, date, subject) and assigned one phase and one of 38 subsystems. Subsystem 0 (23 commits) holds README-only edits, NOTES/docs restructuring, Phase 10 doc reconciliation, and the link test.
- Diffs were read, not only subjects, for mechanism, ownership moves, supersession, acceptance records, and safety corrections.
- Each subsystem was compared with source at the tip and with the canonical documents. Hardware acceptance is cited only where ROADMAP, LOGBOOK, or research records an installed image. Build-only and source-review results are labelled.
- Read-only audit: no build, no Docker, no SSH, no device. Line numbers are at `d3bee63568e0482916f66821093b102b115eb19f` unless noted.
- The full per-commit mapping is reproducible from `git log` and was produced as a working file. It is not committed.

| Phase | First SHA | Last SHA | Dates | Commits |
| --- | --- | --- | --- | --- |
| pre-roadmap | `dffddbacfcc8dcbffe96316013e9255c71941729` | `bb3aef4653f4` | 2026-09-11..09-20 | 173 |
| 0 | `99a0ac45e222` | `196dce141b87` | 09-21..09-22 | 11 |
| 1 | `9f2dc9ec3939` | `56cc4c38c518` | 09-22..09-23 | 15 (incl. `047cad5fa879`) |
| 2 | `7d844a367489` | `a50316331413` | 09-23 | 11 (incl. merge `19aebc095a6f`, `11aecdc2aa3b`) |
| 3 | `3afd4f20d186` | `2b208cf0dcd1` | 09-23..09-25 | 41 (incl. merge `be4278767518`, `cddf9590b6e0`) |
| 4 | `cbbf3661762f` | `04442328d421` | 09-25..09-28 | 39 |
| 5 | `66f2cc44b586` | `d2094007a866` | 09-28 | 16 |
| 6 | `bbf386d6fca3` | `c85eb0a27f72` | 09-28..09-29 | 12 |
| 7 | `81c7fc87331d` | `baadc22b4be1` | 09-29..09-30 | 12 |
| 8 | `a44d6ee08658` | `72af121091b3` | 09-30 | 25 |
| 9 | `9ee03745f7a5` (+ `1452b2f26ebd`) | `337ccbce2587393463a4b49c551f94e33e318e44` | 09-30..10-04 | 125 |
| 10 | `59a75beaa25e` | `d3bee63568e0482916f66821093b102b115eb19f` | 10-04 | 7 |
| **Total** | | | | **487** |

- One interleave: `1452b2f26ebd` ("docs: refine Phase 9 product and release gates") is Phase 9 content committed inside the Phase 8 first-parent run, between `07aacf303475` and `4c077262b628`. Every other phase is one contiguous run.
- Three commits are off the first-parent chain. `047cad5fa879` (Phase 1: its parent is the Phase 1 closure `56cc4c38c518` and it undoes a Phase 1 Wayland side effect) and `11aecdc2aa3b` (Phase 2: fixes the suspend loop found in the Phase 2C hardware test, LOGBOOK:360) were made on `main` and merged by `19aebc095a6f`. `cddf9590b6e0` is the `main` twin of `dccbdc0c43eb`, merged by `be4278767518`.

## Source facts

- Buildroot `2026.02.3`, shallow git tag, upstream tree not patched (`build.sh:16-17`, `:102-116`). `external.mk:1-7` includes every package `.mk`, and includes `board/my355/board.mk` only for `BR2_ZLYME_DEVICE_MY355=y`.
- `build.sh` defaults to `zlyme_my355_minimal_defconfig`; the product is `--config zlyme_my355_defconfig` (`build.sh:25-27`). The repository is mounted read-only in the container (`build.sh:171`).
- Userspace builds at `-O3` with `-mcpu=cortex-a55+crc+crypto+fp+simd+rcpc` (`configs/zlyme_my355_defconfig:1-11`). `libretro-genesisplusgx.mk` and `libretro-dosbox-pure.mk` pin `-O2`. The kernel keeps `-O2`.
- Linux `7.0.2`, kernel.org tarball, `board/my355/linux/linux.config` plus `my355.fragment` (`configs/zlyme_my355_defconfig:56-62`).
- U-Boot `2026.01` from `quartz64-a-rk3566`, forced onto the local Flip control DTS, `BOOTDELAY=-2`, `PREBOOT` `blkcache configure 32 32; my355 fg`, patches `001`–`006` (`configs/zlyme_my355_defconfig:70-85`, `board/my355/board.mk:9-77`, `board/my355/uboot/patches/uboot/`).
- rkbin TPL `rk3566_ddr_1056MHz_v1.23.bin` and BL31 `rk3568_bl31_v1.44.elf` (`configs/zlyme_my355_defconfig:91-92`). On a normal card boot the Miyoo SPI-NAND preloader does DDR init and SPL, so only BL31 and U-Boot come from the card (`:87-89`). The FIT has no BL32.
- `ZLYME_VERSION` is `zlyme44`. The OS string `zlyme44 (YYYY-MM-DD)` uses one `ZLYME_IMAGE_DATE` per build (`board/my355/post-build.sh:170-193`, `build.sh:245-254`).
- NextUI is `Zetarancio/NextUI` at `70344ade993c` (full SHA in `package/system/nextui/nextui.mk:14-16`), forked from LoveRetro `ae652648548e`, PolyForm Noncommercial 1.0.0.
- InputPlumber `v0.81.0` at `ea60d873cca1` plus `0001-rescan-devices.patch` (`package/system/inputplumber/inputplumber.mk:7-11`).
- 16 Linux patches under `board/my355/linux/patches/`, applied in `BR2_GLOBAL_PATCH_DIR` order with `-F0` (`configs/zlyme_my355_defconfig:22`, `patches/README.md:1-3`):
  - `10-mainline`: `0005` RTL8733BU Bluetooth.
  - `20-rk3566`: RK817 `0002` names, `0003` NVRAM SoC, `0007` `SYS_CAN_SD`, `0030` ON/OFF source log; SoC/DT `0001` 1992 MHz OPP, `0008` mali_kbase DT, `0021` UART dma-names, `0666` CMA, `1001` idle states; `1010` DFI PM; `1011a`/`1011b` RK3568 pm-config (deep suspend); `1013` VOP2 BCSH.
  - `30-default`: `9901` async suspend/resume off. `40-kernel-7.0`: `0006` DualSense Edge.
  - `1012a`/`1012b` (DMC) are gone. In Zlyme, `1013` means BCSH, not the archived fork's suspend patches.
- DMC is `package/drivers/rk3568-dmc` (`VERSION = local`, GPL-2.0-only, `depends on BR2_ZLYME_DEVICE_MY355`). It installs `rk3568_dmc.ko` in `/lib/modules/7.0.2/updates/` and autoloads from `rockchip,rk3568-dmc` during `S29udevtrigger`, after the first frame. OPPs 324/528/780/1056 MHz at 900 mV, `center-supply = <&vdd_logic>` (DTS `:355-388`).
- Deep suspend: DTS node `rockchip-suspend`, `compatible = "rockchip,pm-rk3568"`, sleep mode `0x5ec` (`CENTER_OFF | ARMOFF_LOGOFF | PMIC_LP | HW_PLLS_OFF | PMUALIVE_32K | OSC_DIS | 32K_PVTM`), wake `0x10` (`GPIO_WKUP_EN`), debug 0 (DTS `:333-353`). Built-in `CONFIG_ROCKCHIP_PM_CONFIG=y` (`linux.config:5939`) calls SIP `0x82000003`.
- Rails in mem suspend: `vdd_logic` (RK817 `DCDC_REG1`) is off and keeps `always-on`/`boot-on` (DTS `:635-653`). Also off: `vdd_gpu`, `vdd_cpu` (RK8600), `vcc_3v3`, `vcc_1v8`, DVP/codec LDOs, BOOST, OTG, USB host 5 V, LCD. On: `vcc_ddr`, PMU LDOs, `vccio_sd` at 3.3 V. Wake: power key, volume keys, lid open.
- `board/my355/fsoverlay/usr/share/zlyme/device.conf:4-12`: `ZLYME_DEVICE_ID=my355`, `ZLYME_SOC=rk3566`, `ZLYME_DTB=rk3566-miyoo-flip.dtb`, `ZLYME_NEXTUI_PLATFORM=my355`, `ZLYME_PORTMASTER_HW_DEVICE=miyoo-flip`, `ZLYME_UPDATE_PREFIX=zlyme-my355`, labels `ZLYMEBOOT` and `ZLYME`.
- Image (`board/my355/genimage.cfg`): `idbloader.img` raw at 32 KiB; GPT `uboot` 4 MiB at 8 MiB; FAT32 `ZLYMEBOOT` 1300M at 12 MiB with `Image.gz`, DTB, `extlinux/`, `overlays/`, `zlyme-boot.conf`, the squashfs file `zlyme`, and anims; exFAT `ZLYME` as a 32 MiB seed (`post-image.sh:22-28`) that `S13resize` grows. No root partition.
- `/boot` is read-only at runtime. Every write goes through `zlyme-boot-write` (`board/my355/fsoverlay/usr/sbin/zlyme-boot-write:1-71`).
- Init: `rcS` runs only Class A (`S10udevd`, `S11modules`, `S12bootfs`, `S12splash`, `S13resize`, `S15bootpart`, `S15gpudriver`, `S16display`, `S17sd2` forked, `S18zlymeupdate`, `S20alsa`, `S25jackd`, `S26keylidmon`, `S28minui`) (`rcS:21-86`). `rc.late` is `::once:` (`post-build.sh:290-300`). It waits up to 20 s for `nextui-first-flip` (`rc.late:17-27`), restores calibration and rumble (`:31-40`), then starts Class B in the background.
- Defaults (`S15bootpart:62`, `zlyme-ctl:9-23`): Rumble Strength displayed 40% (`package/system/nextui/zlyme/gamepad-ff/ff_gain.h:5`); GPU `libmali`; governor `smart` after boot; ZRAM on, 384 MiB lz4; undervolt off; boost off; logs off; Wi-Fi, Bluetooth, SSH on; Samba and Syncthing off; stick deadzone 0; no Wi-Fi `country=` line; RTC and system clock in UTC.

## Subsystem traceability matrix

Disposition terms:

- `fix canonical (this pass)`: a canonical document contradicts, overstates, or mislabels source. The Phase 10 documentation pass corrects it.
- `status banner (this pass)`: a research file's opening reads as current. A dated banner is added. The body is kept.
- `comment corrected (this pass)`: a Zlyme-owned source comment contradicts the code beside it. Comment-only change.
- `preserve historical`: intentionally left as history.
- `wiki-sync later (Phase 10E)`: a hardware-wiki statement, edited in the wiki repository after this pass.
- `maintainer review (not changed)`: a suspected defect or design decision. Nothing was changed.
- `no action`: consistent with source, or a coverage gap recorded here only ("gap recorded").

### 1. Buildroot / build container / reproducibility

- **Implementation:** `external.mk`, `Config.in`, `external.desc`, `configs/zlyme_my355{,_minimal}_defconfig`, `build.sh`, `Dockerfile`, `board/my355/{board.mk,image-date.sh,assert-input-rootfs.sh}`.
- **Invariant:** Buildroot stays unmodified and runs as a `BR2_EXTERNAL` tree in the pinned container. Board hooks load only for the my355 device symbol, and one image date feeds both the OS string and the OTA.
- **History:** `dffddbacfcc8dcbffe96316013e9255c71941729` tree start; `1889fd74f1c5` `-O3` with `-O2` pins; `80eef380bf08` my355 defconfig names; `bc2accb796d7` hooks into `board.mk`; `c22175e43e43` refresh changed input packages and check the packed rootfs; `7796b98ae752` one image date.
- **Hardware acceptance:** build-only. Phase 0 clean build and boot: ROADMAP:87-89, LOGBOOK:609.
- **Canonical owner:** `docs/DEVELOPMENT.md` "Build system", "Defconfigs", "Reproducibility", "Build container", "Compiler policy".
- **Wiki owner:** n/a.
- **Findings:** DEVELOPMENT lists `savedefconfig` as working (V2), has an incomplete fingerprint list (V3, V4), misses options and env overrides (V5), versions (V6), compiler facts (V8), and overstates hashes (V10, 61 of 67 downloaded packages have none). It calls the done `board.mk` move future work (V11) and names `storage.sh` instead of `storage.sh.example` (V13). README:17 "fastest setting". Defconfig `:65` and `:182` comments are stale. The minimal build cannot pass post-build (issue (d)). Unrefreshed local packages stay stale (issue (g)).
- **Disposition:** fix canonical (this pass) for V2–V13 and README:17; comment corrected (this pass) for `zlyme_my355_defconfig:65`, `:182`; maintainer review (not changed) for issue (d), issue (g), the missing hashes, the same `:65` comment in `zlyme_my355_minimal_defconfig`, and the misplaced keylidmon comment at `build.sh:360-362`.

### 2. Kernel config, patch ownership, DTS

- **Implementation:** `board/my355/linux/{linux.config,my355.fragment}`, `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`, `board/my355/linux/patches/*/linux/`, `board/my355/linux/sources/panel-generic-dsi.c`, Linux hooks in `board/my355/board.mk:82-144`.
- **Invariant:** 16 patches apply in a fixed order with `-F0`. A patch stays only when an external module would be artificial. `board.mk` asserts critical symbols and that `rk3566-miyoo-flip.dtb` was built.
- **History:** `d843dbecf314` board bring-up; `2d0c7f081291` `1013` VOP2 BCSH; `68f6ca0dea6d` Phase 2B classification; `c66fb88b954f`..`a50316331413` Phase 2C removals; `73ea83554117` drop input-polldev; `29cc570326b2` restore `0021`; `8119387e0fdb` 16-patch record.
- **Hardware acceptance:** Phase 2C: ROADMAP:320. Corrected Phase 5 stack: ROADMAP:1648, LOGBOOK:142.
- **Canonical owner:** `docs/ARCHITECTURE.md` "Kernel extension policy"; `docs/MAINTENANCE.md` "Kernel and board patches"; `board/my355/linux/patches/README.md`. The per-patch inventory is research only.
- **Wiki owner:** `docs/drivers-and-dts.md`, `docs/drivers-and-dts/board-dts-pmic-ddr-updates.md`; Zlyme status on `docs/implementations/zlyme.md`.
- **Findings:** No canonical doc names Linux 7.0.2 (V6, M2). DTS `:36` and `:998` say SARADC ch0 belongs to the joypad; the sticks are on UART1. `board.mk:88-92` copies `dts-overrides/` that no patch uses (issue (l)). `kernel-patch-audit.md:3` and `kernel-patch-audit-phase5.md:3` read as current.
- **Disposition:** fix canonical (this pass) for the version; comment corrected (this pass) for DTS `:36`, `:998`; status banner (this pass) for both research files; maintainer review (not changed) for `dts-overrides` and its `board.mk:88` comment; wiki-sync later (Phase 10E) for W1.

### 3. U-Boot, BL31, boot chain, boot filesystem

- **Implementation:** `board/my355/board.mk:9-77`, `board/my355/uboot/{dts,patches/uboot}/`, `board/my355/extlinux.conf`, `configs/zlyme_my355_defconfig:70-92`.
- **Invariant:** TPL v1.23 and BL31 v1.44 are a matched pair. Routine OTA never writes idbloader or the FIT; only `zlyme-update uboot` does.
- **History:** `a53743f42a17` no key wait, absent controllers off; `99562f9ea60c` `Image.gz` only; `af7ddb68d8f8` patch `004` sdmmc divider; `c0478b61277e` patch `005` dcache; `ebe19ab5fdec` Flip U-Boot DTS, patch `006` with `my355 fg`; `ebad15834db6` FIT write made explicit.
- **Hardware acceptance:** no dedicated U-Boot entry. The Phase 0 etched image booted (LOGBOOK:609-625). BL31 v1.44 SIP calls accepted in Phase 6 (ROADMAP:1671-1673).
- **Canonical owner:** `docs/ARCHITECTURE.md` §5 "Boot architecture"; `docs/DEVELOPMENT.md` "Kernel and U-Boot"; `docs/OPERATIONS.md` "Boot identity".
- **Wiki owner:** `docs/boot-and-flash.md`, `docs/stock-firmware-and-findings/spi-and-boot-chain.md`.
- **Findings:** ARCHITECTURE's boot path omits BL31, the preloader role, and `FDTOVERLAYS` (A13). The U-Boot patch set and `my355 fg` are in board files and LOGBOOK only. `zlyme-update uboot` does not check its target disk (issue (a)). The wiki says working SD boots carried OP-TEE; Zlyme's FIT has no BL32 (W25).
- **Disposition:** fix canonical (this pass) for A13; no action for the U-Boot patch gap (gap recorded); maintainer review (not changed) for issue (a); wiki-sync later (Phase 10E) for W25 and WO3 after a serial capture.

### 4. Initramfs and squashfs-root design

- **Implementation:** `package/boot/zlyme-initramfs/{init,busybox.config,splash.c,zlyme-initramfs.mk}`, `board/my355/board.mk:120-137`.
- **Invariant:** `/init` mounts ZLYMEBOOT read-only and opens it read-write only to commit `pending/zlyme` or write a requested boot dmesg. It attaches the root only when the vfat and the loop are both read-only.
- **History:** `234b97268b84` tmpfs pivot and `dd` (superseded the same day); `4bf848d295a1` squashfs as a FAT file with initramfs commit; `2c379f8ae609` framebuffer splash; `4c6f099ba01a` mount by label; `dccbdc0c43eb`/`cddf9590b6e0` include grep; `37d41679996f` read-only ZLYMEBOOT.
- **Hardware acceptance:** OTA copy on the Phase 0 smoke (LOGBOOK:617-621). `loop0/ro=1` and `/boot` ro on the `37d41679996f` image (LOGBOOK:66-68). The grep fix had no Flip boot of its own (LOGBOOK:280).
- **Canonical owner:** `docs/ARCHITECTURE.md` §5, §6; `docs/OPERATIONS.md` "Updates".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE omits the second read-write reason (`/boot/zlyme-logs`) and the `post-update.sh` run (A14). The early `mmcblk0p2`/`mmcblk1p2` mount can pick the second card (issue (b)). `zlyme-initramfs.mk:7` points at `external.mk` for a hook now in `board.mk`. No ADR recorded why the root is one file replaced whole.
- **Disposition:** fix canonical (this pass) for A14 and the missing decision (ADR 0006); maintainer review (not changed) for issue (b) and the `zlyme-initramfs.mk:7` comment.

### 5. Image layout and first-boot resize

- **Implementation:** `board/my355/{genimage.cfg,post-image.sh,zlyme-boot.conf}`, `board/my355/fsoverlay/etc/init.d/S13resize`, `rcS:59-64`.
- **Invariant:** there is no root partition. After GPT edits the resize never runs `partprobe` on the live FAT. It reformats ZLYME, reboots with `reboot -f`, and disarms only on a later boot when ZLYME is over 600 MB.
- **History:** `7fdebf50819d` first resize (512 MB seed); `4bf848d295a1` three-partition FAT layout, 32 MB seed, 1300M ZLYMEBOOT; `6217fccb0d3f` skip GPT work once grown, after a FAT1 wipe; `239d475fd1fb` no `partprobe`, `reboot -f`; `d59622f484c7` rcS skips an unarmed resize.
- **Hardware acceptance:** LOGBOOK:1269 (resize without `partprobe`); LOGBOOK:1098-1100 (fresh card).
- **Canonical owner:** `docs/OPERATIONS.md` "Current image layout", "First-boot resize"; `docs/ARCHITECTURE.md` §6.
- **Wiki owner:** n/a (image names: `docs/boot-and-flash.md:50`, WO1).
- **Findings:** ARCHITECTURE's layout omits sizes, the 32 MB seed, and first-boot growth (A15). OPERATIONS is correct. `S15bootpart:15-16` prefers `/dev/mmcblk0p3` over the label; normally unreachable.
- **Disposition:** fix canonical (this pass) for A15; maintainer review (not changed) for `S15bootpart`; wiki-sync later (Phase 10E) for WO1.

### 6. /boot write ownership and safety

- **Implementation:** `board/my355/fsoverlay/usr/sbin/zlyme-boot-write`, `etc/init.d/S12bootfs`, initramfs `init`, `zlyme-halt:46-50`; callers `zlyme-update`, `S12splash`, `S13resize`, `S18zlymeupdate`, `zlyme-ctl`, `zlyme-logs`, `nextui-session`.
- **Invariant:** `/boot` is read-only at runtime. Each writer wraps one transaction in `zlyme-boot-write`, which fails if `/boot` stays writable. Shutdown never remounts `/boot`, because the squashfs loop backs onto it.
- **History:** `37d41679996f` read-only ZLYMEBOOT, 16 callers converted; `f4fa78a2fad6` comment on the staging splash flag.
- **Hardware acceptance:** Phase 8A on `zlyme-my355-20260930-37d41679996f.tar` (LOGBOOK:66-68, ROADMAP:1809, :1822). A direct `/boot` write failed, as intended (LOGBOOK:68).
- **Canonical owner:** `docs/ARCHITECTURE.md` §5, §7; `docs/OPERATIONS.md` "Updates".
- **Wiki owner:** n/a.
- **Findings:** `docs/DEVELOPMENT.md:200-213` copies a DTB straight onto read-only `/boot` and hard-codes `root@192.168.0.108` (V1). `:200` names `S12bootfs` as the mounter; it is the fallback (V12). `zlyme-boot-write` treats any live holder as the caller's own transaction (issue (e)).
- **Disposition:** fix canonical (this pass) for V1, V12; maintainer review (not changed) for issue (e).

### 7. /storage persistence and filesystem ownership

- **Implementation:** `etc/init.d/S15bootpart`, `etc/zlyme.conf`, `usr/sbin/{zlyme-halt,zlyme-storage}`, `package/system/nextui/nextui-session`.
- **Invariant:** persistent state is `/storage/.config/<owner>`, per-library content roots, and app-owned paths; POSIX-only state stays on tmpfs. Frontend shutdown does a normal `umount /storage` before `reboot -f` or `poweroff -f`.
- **History:** `5d988f219c90` eudev, `zlyme-storage`, `zlyme-halt`; `09414af59a23` NextUI userdata under `.config/nextui`; `632202865c71` real `/storage` unmount at shutdown; `8718d71a98e1` drop test markers; `2bf48ac71bb1` app state on the library and `.config`.
- **Hardware acceptance:** Phase 8A2 on `zlyme-my355-20260930-632202865c71.tar` (LOGBOOK:62-64).
- **Canonical owner:** `docs/ARCHITECTURE.md` §6; `docs/OPERATIONS.md` "Persistent state".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE:182 does not say that a shell `poweroff` uses BusyBox `rcK`, not `zlyme-halt` (A18). `/mnt/SDCARD` links to `/storage` (`post-build.sh:75`), so a copied `.userdata` path lands on the card root; no AGENTS invariant says so (AG2). `Overlays.pak/README.md:42-65` documents `.userdata` paths.
- **Disposition:** fix canonical (this pass) for A18; maintainer review (not changed) for the AGENTS invariant and the Overlays README.

### 8. Multi-library SD2/USB

- **Implementation:** `usr/sbin/{zlyme-storage,zlyme-storage-udev,zlyme-storage-format,zlyme-library-populate}`, `etc/udev/rules.d/99-zlyme-storage.rules`, `etc/init.d/S17sd2`, `package/system/nextui/zlyme/zlyme-game-cleanup.sh`.
- **Invariant:** each card keeps its own games and saves. Active roots are listed in `/run/zlyme/libraries`, with no pooling. Formatting accepts only removable volumes the scanner already classified, never the OS disk.
- **History:** `a0b049ec1ae4` mergerfs pool (superseded); `3c7f987b1d3a` per-card libraries; `bdbf8189be79` guarded formatting; `1f3c46851284` delete one ROM on its own library; `d70d39dec01f` Settings calls the format backend directly.
- **Hardware acceptance:** LOGBOOK:667 (per-card libraries); disposable-card format on `b9f8947780ec` (`docs/research/product-phase9.md:340`); SD2 artwork on `daebc6f5dbab` (ROADMAP:1894).
- **Canonical owner:** `docs/ARCHITECTURE.md` §6; `docs/OPERATIONS.md` "Persistent state".
- **Wiki owner:** `docs/drivers-and-dts/board-dts-pmic-ddr-updates.md:140`, `:225` (slot 2 UHS).
- **Findings:** `package/system/mergerfs` is still sourced and selectable, and its help describes pooling (issue (k)). `merge=on` is still seeded, `zlyme-storage merge` is a no-op, and `rcS:47` names mergerfs. DTS `&sdmmc1` enables SDR50/SDR104 against the wiki, and the comments at `:1006`, `:1031` disagree with the properties under them (issue (j)). Formatting and per-ROM delete are in ROADMAP/research only. AGENTS has no per-card invariant (AG2).
- **Disposition:** maintainer review (not changed) for issue (j), issue (k), the `merge` flag, the `rcS:47`, `:1006`, `:1031` comments, and the AGENTS invariant; no action for the formatting coverage (gap recorded).

### 9. BIOS/save selection and runtime views

- **Implementation:** `package/system/nextui/zlyme/zlyme-library.sh` (`/usr/sbin/zlyme-library`), `board/my355/fsoverlay/usr/share/zlyme/bios-union.py`, `package/system/nextui/zlyme/ra-run.sh`.
- **Invariant:** one tmpfs BIOS union of all libraries, with the ROM's library winning duplicates, cached per winning card and generation. One writable save root is chosen by a fixed order. Nothing is copied.
- **History:** `3c7f987b1d3a` first per-card model; `a73f655d91c5` shared BIOS, one save root; `e21cccddcc56` resolve once and cache; `be0da7b452b9` one view per winning card; `22e115089bb6` cleanup follows the resolver.
- **Hardware acceptance:** 9L timing, 1.519 s cold and 0.059 s cached (`docs/research/product-phase9.md:310-312`); part of `zlyme44` (ROADMAP:1898). A same-name ROM on two cards was not confirmed on the device (ROADMAP:1894).
- **Canonical owner:** `docs/ARCHITECTURE.md` §6.
- **Wiki owner:** n/a.
- **Findings:** none against canonical text. The cache mechanism is research only. `product-phase9.md:320` keeps the superseded ROM-only rule in a dated section.
- **Disposition:** no action; preserve historical (`product-phase9.md:320`).

### 10. OTA / update / release architecture

- **Implementation:** `usr/sbin/zlyme-update`, `etc/init.d/S18zlymeupdate`, initramfs `commit_update`, `board/my355/{make-update-tar.sh,pre-update.sh,post-update.sh}`, `package/system/nextui/zlyme/github-release.py`, `device.conf`.
- **Invariant:** an OTA is staged complete on ZLYME. Kernel, DTB, and overlays are written through `zlyme-boot-write`; loader blobs are parked, not written. Only the initramfs replaces `/boot/zlyme`, on the next boot. A failure quarantines to `.update/failed/` and keeps the old root.
- **History:** `234b97268b84` first OTA (superseded by `4bf848d295a1`); `09374dd14ffb` hashed GitHub tar; `0a08c2a0b09c` S18 runs before NextUI; `2656f1443400` pre/post hooks; `572d3421b45e` update moves into Settings; `ebad15834db6` explicit FIT write; `837fff5aad39` names from `device.conf`.
- **Hardware acceptance:** first OTA, LOGBOOK:1430. Every phase gate is an installed OTA. Final: `zlyme44` (ROADMAP:1898, LOGBOOK:24).
- **Canonical owner:** `docs/ARCHITECTURE.md` §7; `docs/OPERATIONS.md` "Updates"; `docs/DEVICE_PORTING.md` "Update compatibility"; `docs/MAINTENANCE.md` "Releases".
- **Wiki owner:** n/a (WO1 image names only).
- **Findings:** ARCHITECTURE:242 and DEVICE_PORTING:288 overstate artifact identity: a full tar has no device field and the delta check is a literal `my355` (A3, D4, E4). OPERATIONS:179 lists only some status keys (O5). README:72's glob also matches delta tars. OTA pack failure is soft (issue (h)). Literal `my355` remains in the updater and release scripts (issue (m)). `post-update.sh:18-23` and `nextui-session:88`, `:377` remove retired paks.
- **Disposition:** fix canonical (this pass) for A3, D4, E4, O5, README:72; maintainer review (not changed) for issue (h), issue (m); preserve historical for the retired-pak removals.

### 11. Incremental delta OTA

- **Implementation:** `zlyme-update` `stage_delta`, `github-release.py`, `scripts/{zlyme_release.py,make-release-deltas.py}`, `.github/workflows/build.yml:115-123`, `scripts/tests/{test_delta_stage.sh,test_zlyme_release.py}`.
- **Invariant:** a delta is chosen by the installed root's SHA-256, never by version string. It is decoded on `/storage` with `--mmap-dict`, and only a size- and hash-verified result moves to `pending/`. `/boot/zlyme` is never patched in place.
- **History:** `607ef7c270b2` manifest selection; `d12503e32279` verified reconstruction; `2193d7a0cdfc` CI deltas; `e235e4b4785a` `NEED_BYTES`; `a951706c1f2c` distinct names and `--memory`; `337ccbce2587393463a4b49c551f94e33e318e44` `--mmap-dict` after a device OOM.
- **Hardware acceptance:** root-sized reconstruction through the installed updater (LOGBOOK:24, ROADMAP:1898). OOM on `7796b98ae752` before the fix (LOGBOOK:24). No point release is published yet.
- **Canonical owner:** `docs/ARCHITECTURE.md` §7; `docs/OPERATIONS.md` "Updates"; `docs/MAINTENANCE.md` "Releases".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE:214 omits the base rule (baseline plus last three points), the 70% cut, and smallest-delta selection (A11). The runtime SHA and release model are stated in both DEVELOPMENT:126-131 and MAINTENANCE:17, :44-48.
- **Disposition:** fix canonical (this pass) for A11 and the duplicate (MAINTENANCE owns it).

### 12. Power-off and RK817 / SYS_CAN_SD

- **Implementation:** patches `0007`, `0003`, `0030`, `0002`; `usr/sbin/zlyme-halt`; `nextui-session:484-519`; U-Boot patch `006` (`my355 fg`).
- **Invariant:** `0007` clears `SYS_CAN_SD` so the PMIC does not keep the ~8 mA off-state drain. Frontend power-off runs `/tmp/poweroff`, then `zlyme-halt poweroff`, unmount, and `poweroff -f`. Userspace writes no PMIC register.
- **History:** `d843dbecf314` brings `0007`; `5d988f219c90` `zlyme-halt`; `ebe19ab5fdec` `my355 fg` gauge check; `50976769205b`/`4720beb89f79` drop, then restore `0030`; `5fb63c23f425` add `0003`; `632202865c71` real unmount.
- **Hardware acceptance:** ~8 mA vs ~0.05 mA and overnight `OFF_CNT` reseed (ROADMAP:1642, LOGBOOK:160); corrected stack ON/OFF source and clean shutdown (ROADMAP:1648, LOGBOOK:142). No ammeter measurement on the current image.
- **Canonical owner:** `docs/OPERATIONS.md` "Hardware-wiki invariants"; `docs/ARCHITECTURE.md` "Hardware source of truth"; `docs/DEVICE_PORTING.md` `zlyme-halt`.
- **Wiki owner:** `docs/troubleshooting.md:61`, `:65` (WO4, WO5); `docs/miyoo-flip-power-off-investigation.md` (historical, keep).
- **Findings:** OPERATIONS:223-236 has the `ON_SOURCE` paragraph inside the bullet list (O6) and does not name `0007` (O7). README:9 "does not drain while off". The `/tmp/poweroff` path and `my355 fg` are not in canonical docs.
- **Disposition:** fix canonical (this pass) for O6, O7, README:9; no action for the power-off path (gap recorded); wiki-sync later (Phase 10E) for WO4, WO5.

### 13. Standard suspend

- **Implementation:** `package/system/nextui/zlyme/suspend`, `usr/sbin/zlyme-radios`, `package/system/zlyme-keylidmon/zlyme-keylidmon.c`, `etc/init.d/S26keylidmon`, patch `9901`, NextUI fork `PWR_*` (pinned).
- **Invariant:** menu and pak use one mem path. Radios stop with Bluetooth before Wi-Fi, `suspend` writes `mem`, and resume restarts Wi-Fi first. With a pak on screen, power is mem and the lid is screen and radios off; a 1 s guard ignores the wake press.
- **History:** `aafdcd7e5143` stop radios before mem; `083e8061c473` `suspend` helper; `e546879b37ac` split lid from power; `11aecdc2aa3b` wake-press guard.
- **Hardware acceptance:** Phase 0 s2idle/deep cycles (LOGBOOK:633-640); Phase 2C pass (ROADMAP:320); one cycle each in Phase 5 (ROADMAP:1638, :1648).
- **Canonical owner:** `docs/ARCHITECTURE.md` "Hardware source of truth", §10; `docs/OPERATIONS.md` "Hardware-wiki invariants".
- **Wiki owner:** `docs/drivers-and-dts/suspend-and-vdd-logic.md` (generic flow).
- **Findings:** OPERATIONS:236 "standard suspend works independently of deep suspend" is ambiguous now that mem suspend is deep suspend. The helper, radio order, RTC alarm, and lid/power split are not canonical (G9). `suspend:4-6` arms a 24 h RTC wake with no recorded reason (issue (c)). The `zlyme-radios:13-14` DMC kick comment predates Phase 7.
- **Disposition:** fix canonical (this pass) for OPERATIONS:236; no action for G9 (gap recorded); maintainer review (not changed) for issue (c) and the `zlyme-radios` comment.

### 14. Phase 6 BL31 deep suspend and vdd_logic

- **Implementation:** patches `1011a`, `1011b`; DTS `:329-353`, `:635-653`; `CONFIG_ROCKCHIP_PM_CONFIG=y`; BL31 v1.44 (`configs/zlyme_my355_defconfig:92`).
- **Invariant:** `vdd_logic` off in mem suspend is safe only with `ARMOFF_LOGOFF` in the BL31 mask. The driver sends mode, wake, and debug at probe and resends `LINUX_PM_STATE`, mode, and wake in `.prepare`. A non-zero required result aborts that suspend.
- **History:** `bbf386d6fca3`/`c554e666a97d` 6A research; `88e5c698ddd1` `1011a/b`; `4730aec69a7c` node on with `vdd_logic` on; `28675fb2dded` `vdd_logic` off; `b709719aac5c` 6D image; `c85eb0a27f72` close.
- **Hardware acceptance:** ROADMAP:1671-1680 (runtime `b709719aac5c`), LOGBOOK:104-108, :120. Not done: long cycle counts, USB/BT matrices, standby current, a lid-specific test (ROADMAP:1727).
- **Canonical owner:** `docs/ARCHITECTURE.md` "Hardware source of truth"; `docs/OPERATIONS.md` "Hardware-wiki invariants"; the DTS.
- **Wiki owner:** `docs/drivers-and-dts/suspend-and-vdd-logic.md`; `README.md:91`, `:104`, `:108`; `docs/drivers-and-dts.md:51`; `docs/rk3566-reference/datasheet-specs.md:103`, `:112`.
- **Findings:** OPERATIONS:238 "Deep suspend should be validated…" predates Phase 6. ARCHITECTURE:448 uses a phase label for a present fact (A16). DTS `:331` says `vdd_logic` stays on; `:651` turns it off. `deep-suspend-phase6.md:3` says nothing was activated. The wiki says Zlyme does not ship deep suspend.
- **Disposition:** fix canonical (this pass) for OPERATIONS:238 and A16; comment corrected (this pass) for DTS `:331`; status banner (this pass) for `deep-suspend-phase6.md`; wiki-sync later (Phase 10E) for W2, W3, W6, W11–W20.

### 15. DMC/DFI packaging and runtime policy

- **Implementation:** `package/drivers/rk3568-dmc/{rk3568-dmc.mk,Config.in,README.md,src/rk3568_dmc.c}`, patch `1010`, DTS `:355-388`, `package/system/nextui/zlyme/governor.sh`, `zlyme-radios:6-21`.
- **Invariant:** DMC is the out-of-tree `rk3568_dmc.ko`. It autoloads during the deferred coldplug and fails closed on BL31 transition errors. DFI PM (`1010`) stays a kernel patch.
- **History:** `a63c8340beb6` DMC in governor profiles; `81c7fc87331d` 7A module; `b3bb23748aa6` 7B external package; `99beef951bde` fail closed; `21de8081d6e6` drop `1012a`; `70acb1d27443` voltage retention (source and build only).
- **Hardware acceptance:** ROADMAP:1733-1740, LOGBOOK:72-76 (final `21de8081d6e6`). `70acb1d27443` had no hardware test of its own.
- **Canonical owner:** `package/drivers/rk3568-dmc/README.md`; `docs/ARCHITECTURE.md` "Kernel extension policy"; `docs/OPERATIONS.md` "Hardware-wiki invariants".
- **Wiki owner:** `docs/stock-firmware-and-findings/bsp-and-ddr-findings.md:181`; `README.md:88`, `:106`; `suspend-and-vdd-logic.md:215`.
- **Findings:** ARCHITECTURE:479 still describes DMC as an in-kernel tristate driver inside a patch. OPERATIONS:235 names no owner (O8). DEVICE_PORTING:330-342 says SoC-family drivers should not depend on the device symbol; `rk3568-dmc/Config.in:3` does (D5). `apply-gov` may run before the coldplug loads DMC (LOGBOOK:96, issue (f)).
- **Disposition:** fix canonical (this pass) for ARCHITECTURE:479, O8, D5 (record the gate); maintainer review (not changed) for the gate choice and issue (f); wiki-sync later (Phase 10E) for W5, W17, W21.

### 16. CPU governor, per-system floors, ZRAM, IRQ affinity

- **Implementation:** `package/system/nextui/zlyme/{governor.sh,test-governor-floors.sh}` (installed as `/usr/sbin/zlyme-governor`, `nextui.mk:193`), `usr/sbin/zlyme-zram`, `etc/init.d/{S22zram,S36irqaffinity}`, undervolt overlays, `zlyme-ctl apply-gov`.
- **Invariant:** boot runs `performance` until `rc.late`, then `smart` on the list. Launchers call `zlyme-governor emu <tag>`, which applies the Spruce floor rounded up to the next mainline OPP. Undervolt and boost stay off by default.
- **History:** `48b0205cd13d` undervolt overlays; `a7c8a279c192` zram and IRQ pinning; `a63c8340beb6` one profile for CPU, DMC, hotplug; `1e80cc235fa1` heavy floor 1104 MHz; `8210debf2d2a` per-pak tags; `01efbcdc9430` Spruce floors for 57 paks.
- **Hardware acceptance:** floors are static-checked only; gameplay is not a Phase 9A gate (ROADMAP:1838). DMC under Smart/Play observed in Phase 7 (ROADMAP:1733-1739). ZRAM and IRQ pinning: none recorded.
- **Canonical owner:** `docs/DEVICE_PORTING.md` `zlyme-governor`; `docs/ARCHITECTURE.md` §12.
- **Wiki owner:** n/a.
- **Findings:** DEVICE_PORTING:168-184 lacks `emu <tag>` and the aliases (D2). DEVICE_PORTING:240, AGENTS:95, and OPERATIONS:117 put governor logic in the board; it ships from the generic `nextui` package (D3, AG1, O3). ARCHITECTURE's command list is incomplete (A7). The `boost` flag is seeded and `apply-boost` is a no-op. A late `apply-gov` can reset an in-game profile (issue (f)). `performance.md` reads as policy.
- **Disposition:** fix canonical (this pass) for D2, D3/AG1/O3 (state the exception), A7; status banner (this pass) for `performance.md`; maintainer review (not changed) for moving the governor, the `boost` flag, and issue (f).

### 17. GPU stacks (libmali/Panfrost) and graphics ownership

- **Implementation:** `package/system/gpudriver/{gpudriver,S15gpudriver,gpudriver.mk}`, `package/system/libmali`, `package/drivers/mali-kbase` (patch `002`), `etc/zlyme-gpu-env.sh`, `etc/modprobe.d/zlyme-gpu.conf`, `external.mk:9-21`.
- **Invariant:** one kernel GPU driver per boot, chosen by Class A `S15gpudriver` from `/storage/.config/zlyme/gpu` (default `libmali`). For libmali the blob is bind-mounted over Mesa's sonames. Vulkan exists only with libmali. A change needs a reboot.
- **History:** `cd153aded477` first switch; `95b9913d3d32` libmali default and bind mounts; `b80e48d74195` lowercase IRQ lookup; `50d13c36fc3f` Mesa picks Panfrost through kmsro; `f9a62947fbfb` GLES 3.0 context; `210f21f6bdad` PPSSPP Vulkan on the Mali display surface.
- **Hardware acceptance:** both stacks in Phase 1 (ROADMAP:137); PPSSPP Vulkan live pass (`product-phase9.md:362`).
- **Canonical owner:** `docs/ARCHITECTURE.md` §8 "Miyoo Flip GPU stacks"; `docs/OPERATIONS.md` "GPU".
- **Wiki owner:** `docs/drivers-and-dts/drivers.md:117` (WO6, optional).
- **Findings:** ARCHITECTURE:412-418 says board-specific packages are Kconfig-gated; `gpudriver`, `libmali`, and `mali-kbase` are not (A8). Neither ARCHITECTURE nor OPERATIONS states the libmali default (A12, O4). README:17 "only mali supports Vulkan as of now". The minimal image blacklists panfrost without `gpudriver` (issue (d)).
- **Disposition:** fix canonical (this pass) for A8, A12, O4, README:17; maintainer review (not changed) for issue (d); wiki-sync later (Phase 10E) for WO6.

### 18. Direct DRM/KMS, temporary Weston, PortMaster WestonPack

- **Implementation:** `usr/sbin/zlyme-weston-run`, `package/system/nextui/zlyme/drm-release.py` (`/usr/bin/zlyme-drm-release`), `etc/profile.d/sdl-kmsdrm.sh`, `package/system/portmaster/{zlyme-portmaster-exec,zlyme-portmaster-cleanup}`, `zlyme-bcsh.c`, `configs/zlyme_my355_defconfig:315-327`.
- **Invariant:** frontend and paks draw through SDL2 KMSDRM, and the session drops DRM master before every pak. Weston, built without Xwayland, runs only inside `zlyme-weston-run` for one client. WestonPack stays PortMaster's; the session cleans it up.
- **History:** `4424768aa183` retry KMSDRM; `6badf288df30` `zlyme-drm-release`; `9cdca4cbd556` Weston tracer; `db84a5b8ac18` builtin libseat; `f5fe1c022eba` WestonPack DRM wrapper; `047cad5fa879` drop PPSSPP Wayland WSI; `0b139e9099ee` PPSSPP KMSDRM; `c35faf8eca49` drop Weston.pak.
- **Hardware acceptance:** Phase 1 gate on both GPU stacks (ROADMAP:137, LOGBOOK:384); PPSSPP KMSDRM (ROADMAP:1628); Vulkan on KMSDRM (`product-phase9.md:361-362`).
- **Canonical owner:** `docs/ARCHITECTURE.md` §8; `docs/OPERATIONS.md` "DRM ownership"; ADR `0002-direct-kms.md`.
- **Wiki owner:** n/a (one status line on `zlyme.md`, W1).
- **Findings:** README:7 "no desktop and no compositor" leaves out app-scoped Weston and WestonPack. ARCHITECTURE:278, :289 do not say the session runs the WestonPack cleanup (A10). Defconfig `:148` says "no X11/Wayland" and `:316` says "Xwayland stays off until the tracer is proven". `weston.md:41` says WestonPack and Wine are pending. ADR 0002 does not name the two runtime owners. VOP2 BCSH is not canonical.
- **Disposition:** fix canonical (this pass) for README:7, A10, and the ADR 0002 owner note; comment corrected (this pass) for defconfig `:148`, `:316`; status banner (this pass) for `weston.md`; no action for BCSH (gap recorded).

### 19. Audio, speaker/headphones, HDMI, Bluetooth audio

- **Implementation:** `usr/sbin/{zlyme-audio,zlyme-btsink}`, `etc/asound.conf`, `package/system/zlyme-jackd/src/zlyme-jackd.c`, `etc/init.d/{S20alsa,S25jackd,S45bluealsa,S46btsink}`.
- **Invariant:** the default PCM follows `ZLYME_SINK` (codec, hdmi, bt) on card ID `rk817ext`, with one shared `FlipVolume`. Only `zlyme-jackd` owns speaker/headphone routing (`Playback Mux`). `zlyme-btsink` starts after the first frame.
- **History:** `cd153aded477` jack watcher; `aafdcd7e5143` A2DP switch with `zlyme-btsink`; `68d0071e8799` HDMI ELD parser; `de3dca055885` rename to `zlyme-jackd`.
- **Hardware acceptance:** LOGBOOK:1066-1121 (audio matrix, ELD on two displays, A2DP); Phase 0 codec sink (LOGBOOK:627-629).
- **Canonical owner:** `docs/ARCHITECTURE.md` §9; `docs/OPERATIONS.md` "Audio"; `docs/DEVICE_PORTING.md` `zlyme-audio`.
- **Wiki owner:** n/a (no sync row).
- **Findings:** DEVICE_PORTING:160-166 says `zlyme-audio` owns codec routing; `zlyme-audio:26` and `zlyme-jackd.c:27-28` give it to `zlyme-jackd` (D1). OPERATIONS:133 "currently uses".
- **Disposition:** fix canonical (this pass) for D1 and the wording.

### 20. Wi-Fi, Bluetooth, rfkill, RTL8733BU power and persistence

- **Implementation:** `package/drivers/{rtl8733bu,rtl8733bu-power,rtl8723fu-firmware}`, `usr/sbin/{zlyme-wifi,zlyme-combo,zlyme-radios,zlyme-bluetooth}`, `etc/init.d/{S30wifi,S35btusb,S40bluetoothd}`, `etc/modprobe.d/{8733bu.conf,rtl8733bu-combo.conf,btusb.conf}`.
- **Invariant:** the combo chip loads on demand after the first frame, `btusb` binds only after `8733bu`, and power save stays off. The power GPIO drops only when both radios are blocked. BlueZ state is a tar on exFAT, restored to tmpfs.
- **History:** `be471f85e3be` radio packages; `7995ed189745` `zlyme-wifi`; `0a75485f6bbf` power save off; `a7bf6fc4c5ff` rfkill toggle through `zlyme-combo`; `2147f2485341` BlueZ tar; `713d7d558f50` persist the Wi-Fi country.
- **Hardware acceptance:** LOGBOOK:1066-1116; BT enable and scan in Phase 5 (ROADMAP:1638, :1648); Wi-Fi after deep suspend (ROADMAP:1677). Wi-Fi country: no live entry found.
- **Canonical owner:** `docs/OPERATIONS.md` "Wi-Fi and Bluetooth".
- **Wiki owner:** `docs/drivers-and-dts/wifi-bt-power-off.md:31`; `docs/drivers-and-dts/drivers.md:30-32`, `:36`, `:46-55`.
- **Findings:** OPERATIONS:141 omits the BT firmware, the load order, and the real-kmod requirement (O9). Power-save policy, the BlueZ tar, and country ownership are not canonical. `rtl8733bu.mk:10` fetches from a different GitHub owner than the wiki cites; the commit `c46aa25e237c` is the same.
- **Disposition:** fix canonical (this pass) for O9; no action for the rest (gap recorded); wiki-sync later (Phase 10E) for W22–W24 (cite the commit, not the owner).

### 21. Physical gamepad driver

- **Implementation:** `package/drivers/miyoo-flip-gamepad/`, DTS `&uart1` `:1114-1140`, `etc/modules-load.d/joypad.conf`.
- **Invariant:** one input device, `Miyoo Flip Gamepad`: UART1 serdev at 9600 for sticks, 17 GPIO buttons, PWM5 `FF_RUMBLE`. The kernel never opens calibration files. The module loads in Class A (`S11modules`).
- **History:** `be471f85e3be` ROCKNIX joypad import (superseded); `e03eba3fad22` new driver and DTS node; `61ef8c98c260` remove the ROCKNIX gamepad; `c0635b9376d9` retire legacy state on OTA; `00ba2b66b11b` NextUI cutover.
- **Hardware acceptance:** 3B tracer on zlyme41 (ROADMAP:552, LOGBOOK:320); 3C1 (LOGBOOK:308); 3D closure (ROADMAP:1506, LOGBOOK:264).
- **Canonical owner:** `docs/ARCHITECTURE.md` §10; ADR `0005-controller-ownership.md`.
- **Wiki owner:** `docs/hardware/input.md:11-12`, `:31`.
- **Findings:** DTS `:1115` "Phase 3B does not remove them" and `:1123-1124` "Phase 3B tracer … No calibration" describe a finished phase. AGENTS has no "do not restore the ROCKNIX joypad" invariant (AG2). `joypad-driver.md` checkpoints read as current.
- **Disposition:** comment corrected (this pass) for DTS `:1115`, `:1123-1124`; status banner (this pass) for `joypad-driver.md`; maintainer review (not changed) for the AGENTS invariant; wiki-sync later (Phase 10E) for W8–W10.

### 22. Calibration / deadzone / rumble

- **Implementation:** `usr/sbin/zlyme-gamepad-cal`, `package/system/nextui/zlyme/joystick-cal/` (MIT, Calibrage), `package/system/nextui/zlyme/gamepad-ff/{zlyme-gamepad-ff.c,ff_gain.c,ff_gain.h}`, driver sysfs, `rc.late:31-40`.
- **Invariant:** calibration, deadzone, and rumble gain live in `/storage/.config/zlyme/miyoo-flip-gamepad/` and are restored after the first frame. A missing or invalid `rumble.config` means displayed 40%; a saved value is kept. The driver rejects a center outside the active range.
- **History:** `159f7c346819` DTS calibration and Autocal (superseded); `e2674f979254` persistent userspace calibration; `cbdee3c0f9ba` `-ERANGE` guard; `501886870a28` radial deadzone; `6d6d82cd19b8` Settings → Joysticks; `9faec306362e` memless rumble; `09d8853789f2` default 30% → 40%.
- **Hardware acceptance:** 3C2a on zlyme42/43 (ROADMAP:660, LOGBOOK:286-306); 3C3 (ROADMAP:1475-1496, LOGBOOK:272). The 40% default ships in `zlyme44` without a dedicated re-test.
- **Canonical owner:** `docs/ARCHITECTURE.md` §10.
- **Wiki owner:** `docs/hardware/input.md:31` (W8).
- **Findings:** ARCHITECTURE:327 says displayed 30%; `ff_gain.h:5` is 40. `joypad-driver.md:561` and LOGBOOK:276 keep 30% in dated checkpoints.
- **Disposition:** fix canonical (this pass) for ARCHITECTURE:327; status banner (this pass) for `joypad-driver.md`; preserve historical for LOGBOOK:276.

### 23. InputPlumber, composites, virtual xb360

- **Implementation:** `package/system/inputplumber/` (v0.81.0, `0001-rescan-devices.patch`, device and capability YAML, `S31inputplumber`), `package/system/zlyme-input/`, `package/system/nextui/zlyme/{pak-input.sh,gamecontrollerdb.txt}`.
- **Invariant:** InputPlumber starts after the first frame with `auto_manage: false`. `zlyme-input` is the only bus client: it enables management, orders external pads first, and releases or reclaims only the built-in composite. Applications read the virtual `xb360` pad.
- **History:** `032b9c1fe7d2` package; `699bb62eb467` start after first frame; `fbb2b6842422` `RescanDevices`; `00ec122226b7` `zlyme-input`; `2fe5c77436ae` NextUI handoff; `9a7846324d0f` SDL sees only xb360 in paks; `09ee19c07f9d` drop the A/B swap.
- **Hardware acceptance:** 4B (ROADMAP:1620); 4C on `e911db674811` (ROADMAP:1624, LOGBOOK:216); 4D on `0b139e9099ee` (ROADMAP:1628, LOGBOOK:180). External controllers were not physically validated (ADR 0005).
- **Canonical owner:** `docs/ARCHITECTURE.md` §10; ADR `0005-controller-ownership.md`.
- **Wiki owner:** `docs/implementations/zlyme.md` (one line, W1); `docs/hardware/input.md:31` (W8).
- **Findings:** OPERATIONS:150-155 "board-specific controller handling" (O2). ENGINEERING_PRINCIPLES:230 "InputPlumber may later define…" and the §14–16 migration wording (E5). ADR 0005:35 "Phase 4D still retargets emulators". AGENTS has no InputPlumber ownership invariant (AG3). `inputplumber.md:3`, `:7`, `:293` carry old dates and a pre-migration filename.
- **Disposition:** fix canonical (this pass) for O2, E5, ADR 0005:35; status banner (this pass) for `inputplumber.md`; maintainer review (not changed) for AG3; wiki-sync later (Phase 10E) for W1, W8.

### 24. Lid / power / volume input ownership

- **Implementation:** `package/system/zlyme-keylidmon/zlyme-keylidmon.c`, `etc/init.d/S26keylidmon`, `package/system/nextui/zlyme/hotkey_logic.h`, NextUI `my355` platform.
- **Invariant:** NextUI owns volume, brightness, lid, and power while it is on screen. `zlyme-keylidmon` (Class A, msettings shm host) owns them while a pak runs, reading devices by name and MENU from the virtual pads. These inputs stay outside InputPlumber.
- **History:** `5c20089efd63` `keymon.elf` (superseded); `e546879b37ac` lid is screen-off, power is mem; `b897ca6baafe` `zlyme-keylidmon`; `11aecdc2aa3b` wake guard; `48631ed5ed37` MENU from the virtual pad; `06f9ed78f866` unused-result fix.
- **Hardware acceptance:** 4C (ROADMAP:1624, LOGBOOK:216); 4D in-pak brightness (ROADMAP:1628).
- **Canonical owner:** `docs/ARCHITECTURE.md` §10; `docs/OPERATIONS.md` "Input and lid".
- **Wiki owner:** `docs/hardware/input.md:13-18` (verified, no edit).
- **Findings:** ARCHITECTURE:324-334 lists lid and power without the in-pak behavior (A17).
- **Disposition:** fix canonical (this pass) for A17.

### 25. NextUI fork and platform ownership

- **Implementation:** `package/system/nextui/{nextui.mk,Config.in,CREDITS,LICENSE,paks-version.sh}`, the `*.txt` system tables, `package/system/{minui-list,minui-presenter}`, `ZLYME_VERSION`.
- **Invariant:** Buildroot fetches `Zetarancio/NextUI` at an exact commit and builds `workspace/$(BR2_PACKAGE_NEXTUI_PLATFORM)`. The product version is `ZLYME_VERSION`, separate from the NextUI hash. minui-list and minui-presenter are vendored with `UPSTREAM` records.
- **History:** `0c72077fcd74` vendored NextUI (superseded); `ada53c266a06` NextUI on squashfs; `4c077262b628` `ZLYME_VERSION`; `bd7a8e5d1b0f` pinned git fetch; `895d068a755a` drop the vendored tree; `cbb8c83a1f3d`/`1aad41c149b7` vendor helpers; `dec32240a377` last pin bump.
- **Hardware acceptance:** Phase 8 on `7a0fc397cb5b`, recorded as hardware-equivalent with seven physical checks (ROADMAP:1828, LOGBOOK:42-44).
- **Canonical owner:** `docs/ARCHITECTURE.md` §11; `docs/DEVICE_PORTING.md` "Frontend platform contract"; `docs/MAINTENANCE.md` "NextUI fork", "Vendored helpers".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE:372 says the package must not hard-code `my355`; `nextui-session` does (A4, issue (m)). DEVICE_PORTING:217-223 describes the platform string as a proposal; it is done (D9). UPSTREAMS "Compared revisions" does not name the fork pin (U1). `frontend-source-phase8.md:3` reads as current.
- **Disposition:** fix canonical (this pass) for A4, D9, U1; status banner (this pass) for `frontend-source-phase8.md`; maintainer review (not changed) for issue (m).

### 26. Frontend session and resource cleanup

- **Implementation:** `package/system/nextui/nextui-session`, `package/system/nextui/zlyme/{zlyme-pak-hotkey.c,hotkey_logic.h,drm-release.py,pak-input.sh}`, `zlyme-portmaster-cleanup`, `package/emulators/wine-amd64/zlyme-wine-prefix`, `etc/init.d/S28minui`.
- **Invariant:** each pak runs in its own session after `zlyme-drm-release`, and MENU+START on one virtual pad kills that process group. The session, not the pak, cleans WestonPack and the Wine prefix, and turns `/tmp/poweroff` and `/tmp/reboot` into `zlyme-halt`.
- **History:** `d411b537adbd` first MENU+Start hotkey; `6badf288df30` DRM release before paks; `eafc97caf537` PortMaster cleanup in the session; `c4495c52d8b0` Wine prefix cleanup in the session; `48631ed5ed37` hotkey from virtual pads only.
- **Hardware acceptance:** Phase 1 repeated NextUI ↔ Weston/WestonPack (ROADMAP:137); Phase 4D MENU+START from RetroArch, Splore, PortMaster (ROADMAP:1628).
- **Canonical owner:** `docs/ARCHITECTURE.md` §10, §11; `docs/OPERATIONS.md` "DRM ownership".
- **Wiki owner:** n/a.
- **Findings:** none against canonical text. `nextui-session:378` removes the renamed `RUFFLE.pak` without a comment. `nextui-session:462` keeps a commented `sleep 0.4` after the DRM release.
- **Disposition:** no action; preserve historical (`RUFFLE.pak` cleanup).

### 27. Tools and PAK ownership

- **Implementation:** `package/system/nextui/paks/Tools/` (Files, Moonlight, Music Player, Overlays, PortMaster, Settings, ZcrapeGoat), `package/system/zcrapegoat/`, `package/system/{vtree,music-player,zmusic,ruffle-handheld}`, `board/my355/post-update.sh`, `paks-version.sh`.
- **Invariant:** seven stock Tools paks ship. Stock Emus and Tools are copied to the card when the pak version changes. ZcrapeGoat is built from vendored ScrapeGoat v2.3.0 plus Zlyme commits, with credentials compiled from a generated header.
- **History:** `0c72077fcd74` scraper paks; `c396b6f7d876` Files and Moonlight; `dc6015428e6e` independent pak version; `846948253570` drop redundant scrapers; `b4b16a4a8a62`/`58da92f7fa78`/`55ba2bf7901d` vendor and rename ZcrapeGoat; `4d4b110b32ea` usable git before exec.
- **Hardware acceptance:** ROADMAP:1890-1898, including a fresh cheat under `/storage/Cheats/GB` on `zlyme44`; `product-phase9.md:520-601`.
- **Canonical owner:** `docs/ARCHITECTURE.md` §11; `docs/UPSTREAMS.md` "ZcrapeGoat"; `docs/MAINTENANCE.md` "Vendored helpers".
- **Wiki owner:** n/a.
- **Findings:** README:80, :179 put System logs under Settings → About; the pinned fork has it under System → Advanced (`workspace/all/settings/zlymemenu.cpp:361`). README:41 calls Settings a community pak. README credits miss zolek86 NextUI-Overlays, nborodikhin nextui-music-player, and SilverPsychoo Ruffle-Handheld. README Factory Reset wording differs from the UI. Files, Moonlight, Overlays, Music Player, and Ruffle ownership are not canonical.
- **Disposition:** fix canonical (this pass) for the README logs path, README:41, and the Factory Reset wording; maintainer review (not changed) for the credits; no action for the ownership gap (gap recorded); preserve historical for `post-update.sh:18-23` and the vendored ScrapeGoat names.

### 28. Emulator / standalone architecture

- **Implementation:** `package/emulators/*` (51 packages), `package/system/nextui/paks/Emus/*.pak/launch.sh` (54 paks), `package/system/nextui/{emu-defaults,emu-alts,emu-paks,rom-dirs,rom-exts}.txt`, `ra-run.sh`, `arcade-stage.sh`, `etc/retroarch.cfg`.
- **Invariant:** one default launcher per system; alternates exist only in `emu-alts.txt` (MD, MS, GG, PICO, P8). RetroArch runs through `ra-run.sh`, which appends `/etc/retroarch.cfg`. The curated set is intentional.
- **History:** `80f060094b8a` RetroArch and cores; `6c5d7d765985` drop unused cores; `5f0d3c3bc671` standalones; `91f8225696fe` a pak per core; `314be674ca16` AetherSX2 and Dolphin; `3e6059ff806a` gpSP at the ROCKNIX-carried revision; `93e2dba84366` Flash as FLASH.
- **Hardware acceptance:** RetroArch, PPSSPP, Splore, PortMaster in 4D (ROADMAP:1628); PPSSPP and a GBC save on 9L/9N (`product-phase9.md:312`, `:340`). Per-emulator gameplay is not a recorded gate.
- **Canonical owner:** `docs/ARCHITECTURE.md` §12; `docs/UPSTREAMS.md` "Package update workflow"; README systems table.
- **Wiki owner:** n/a.
- **Findings:** README:91 "Mednafen SuperFaust" (the core is Supafaust); README:123 Wii omits `.gcm` (`rom-exts.txt:56`); README:128 PSP Bios cell holds a renderer note; the MD/MS/GG/PICO/P8 alternates are not shown. Optional/required BIOS wording for GBA, PS, Saturn, A78, DC depends on upstream cores. UPSTREAMS:16-18 does not allow the distribution-carried commit that gpSP uses (U5).
- **Disposition:** fix canonical (this pass) for README:91, :123, :128, the alternates, and U5; maintainer review (not changed) for the BIOS wording; no action for `emulators.md` (existing banner adequate).

### 29. PICO-8 / Splore

- **Implementation:** `package/system/nextui/paks/Emus/PICO.pak/launch.sh`, `usr/sbin/{zlyme-pico-splore,zlyme-pico-bbs}`, `usr/share/zlyme/pico-runtime.sh`, `package/emulators/pico8`, `package/system/pico8-data-extractor`.
- **Invariant:** native PICO-8 is user-supplied (`pico8_64` and `pico8.dat`), searched on the ROM's library, then on every library. The Splore row exists only while that pair exists, on that library. fake08 is the fallback.
- **History:** `bd3698460ecd` first pak; `29a861db328b` Splore on the virtual pad, no grabber; `48c824e0bcf5` runtime across libraries; `4e3a9865df21` Splore only with a runtime; `7eec83a9a957` row on the runtime's library; `f83dcf07d315` BBS carts, Splore sorted first.
- **Hardware acceptance:** 4D Splore (ROADMAP:1628, LOGBOOK:204); BBS carts and sort on `b9f8947780ec` (`product-phase9.md:337-340`).
- **Canonical owner:** none (ROADMAP:1841 and `product-phase9.md` only).
- **Wiki owner:** n/a.
- **Findings:** no canonical text, and nothing contradicts source.
- **Disposition:** no action (gap recorded).

### 30. PortMaster

- **Implementation:** `package/system/portmaster/{portmaster.mk,portmaster-launch,control.txt,mod_Zlyme.txt,patch-hardware.py,zlyme-theme/}`, `paks/Tools/PortMaster.pak`, `paks/Emus/PORTS.pak`, `usr/sbin/zlyme-portmaster-root`.
- **Invariant:** PortMaster-GUI `2026.05.04-1202` uses HarbourMaster paths from a saved library that never falls back to `/storage`, and SDL sees only the virtual pad. WestonPack stays PortMaster's; the session cleans `/tmp/weston`.
- **History:** `cd153aded477` packaged; `d314d7ffb27b` python3 with ssl and sqlite; `ecc469db0d53` `Roms/Ports (PORTS)`; `efd5fa7ef84f` one writable state root; `92853013580f` library install root; `0e0bf4100139` Zlyme device identity; `99e0594c9d07` Zlyme default-theme scheme.
- **Hardware acceptance:** Alex the Allegator 2 through WestonPack/Xwayland on both GPU stacks (ROADMAP:137); 4D (ROADMAP:1628); theme on `daebc6f5dbab` (ROADMAP:1894).
- **Canonical owner:** `docs/ARCHITECTURE.md` §8; `docs/OPERATIONS.md` "DRM ownership".
- **Wiki owner:** n/a.
- **Findings:** cleanup ownership (A10, see subsystem 18). `portmaster-launch:140` has an unexplained `sleep 0.4`. Install root, identity, and theme are not canonical.
- **Disposition:** fix canonical (this pass) for A10; maintainer review (not changed) for the sleep; no action for the rest (gap recorded); preserve historical for the superseded "ROCKNIX on a Miyoo Flip" identity (`e41ef825763a`).

### 31. Wine / Box64

- **Implementation:** `package/emulators/wine-amd64/{wine-amd64.mk,wine.sh,wineserver.sh,zlyme-wine-prefix}`, `package/system/box64`, `paks/Emus/WINE.pak/launch.sh`, `usr/sbin/zlyme-weston-run`.
- **Invariant:** Kron4ek Wine 11.0 amd64 runs under Box64 inside one `zlyme-weston-run` Weston. Its ext4 prefix image lives under `/storage/.config/nextui/<platform>/` and the session unmounts it afterwards. Wine never uses WestonPack.
- **History:** `5f0d3c3bc671` wine-amd64; `cf50feff61d4` own pak; `6badf288df30` no SDL3, no stuck DRM master; `c4495c52d8b0` native Weston and ext4 prefix; `56cc4c38c518` e2fsprogs dependency.
- **Hardware acceptance:** Wine 11 and Box64 ran PuTTY through `winewayland.drv` on both GPU stacks (ROADMAP:137, LOGBOOK:400).
- **Canonical owner:** `docs/ARCHITECTURE.md` §6, §8; `docs/OPERATIONS.md` "DRM ownership".
- **Wiki owner:** n/a.
- **Findings:** none.
- **Disposition:** no action.

### 32. SSH / Samba / Syncthing / network services

- **Implementation:** `etc/init.d/{S50sshd,S70samba,S75syncthing,S91smb}`, `etc/ssh/sshd_config`, `etc/samba/smb.conf`, `package/system/syncthing`, `zlyme-ctl want`.
- **Invariant:** services start in `rc.late` after the first frame. OpenSSH copies its ed25519 host key from exFAT to tmpfs. Samba and Syncthing stay off until enabled, and `zlyme-halt` stops both before unmount.
- **History:** `5bdc8c4b62e6` SSH listens, Samba off the boot path; `b976c4b49faa` Dropbear → OpenSSH; `916c2b3f9faa` Samba socket on tmpfs; `3a24625d0050`/`c46fafbd20f5` services after the first frame.
- **Hardware acceptance:** SSH is the test channel of every acceptance (e.g. ROADMAP:1677). No dedicated Samba or Syncthing entry.
- **Canonical owner:** `docs/ARCHITECTURE.md` §6, §13; `docs/OPERATIONS.md` "Persistent state".
- **Wiki owner:** n/a.
- **Findings:** defconfig `:129` "S27sshd starts before NextUI"; sshd is `S50sshd`, started from `rc.late`. The same text is in `zlyme_my355_minimal_defconfig:129`. Host-key handling is not canonical.
- **Disposition:** comment corrected (this pass) for `zlyme_my355_defconfig:129`; maintainer review (not changed) for the minimal defconfig copy; no action for host keys (gap recorded).

### 33. Time / NTP / timezone

- **Implementation:** `etc/init.d/S49ntp`, `usr/sbin/zlyme-timezone`, `S15bootpart:37-39`, `usr/sbin/zlyme-card-defaults`.
- **Invariant:** the system clock and RTC are UTC. After Wi-Fi, `S49ntp` sets the clock from an HTTP `Date` header and writes the RTC with `hwclock -u -w`. `/etc/localtime` points at `/storage/.config/nextui/shared/localtime`, which exists before NextUI starts.
- **History:** `7c59518443b3` HTTP Date after Wi-Fi; `ef6b8a8ef7f6` persistent timezone; `bd3d6370d178` seed before the frontend; `a8ed1a6399ef` RTC in UTC; `9341bd947116` clock on by default.
- **Hardware acceptance:** offline clock after a network sync on `b9f8947780ec` (`product-phase9.md:340`, `:367`).
- **Canonical owner:** none beyond "NTP is deferred" (`docs/ARCHITECTURE.md` §5, §13).
- **Wiki owner:** n/a.
- **Findings:** no canonical text beyond the deferral, and nothing contradicts source.
- **Disposition:** no action (gap recorded).

### 34. Logging and diagnostics

- **Implementation:** `usr/sbin/zlyme-logs`, `package/system/nextui/zlyme/pak-log.sh`, `etc/init.d/S28minui:28-37`, `rc.late:96-106`, initramfs boot dmesg.
- **Invariant:** logging is off by default. When on, `zlyme-logs` keeps 5 boot generations in `/storage/.logs` and `pak-log.sh` keeps 3 launches per pak. With logs off, the session log stays in `/tmp`.
- **History:** `dce2d76f091b` ignore DEVLOGS; `bce121c836db` boot and per-pak logs; `36ce0510026f` bounded history; `4720beb89f79` kernel ON/OFF source log.
- **Hardware acceptance:** none dedicated; ships in `zlyme44` (ROADMAP:1898).
- **Canonical owner:** `docs/ARCHITECTURE.md` §6; `docs/OPERATIONS.md` "Persistent state".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE:206 implies nothing is written with logs off; `rc.late:96-106` copies boot timing and `nextui.txt` to `/storage/.config` on every boot (A9). README logs path (subsystem 27). Pak `launch.sh` comments also say "About → System logs".
- **Disposition:** fix canonical (this pass) for A9; maintainer review (not changed) for the `rc.late` writes (issue (n)) and the pak comments.

### 35. First-frame boot architecture

- **Implementation:** `etc/init.d/{rcS,rc.late,S28minui,S12splash,S16display}`, `board/my355/post-build.sh:290-300`, initramfs `init` and `splash.c`, `usr/sbin/zlyme-splash-progress`, `board/my355/extlinux.conf`.
- **Invariant:** `rcS` runs only the Class A whitelist and starts NextUI. `rc.late` waits for `nextui-first-flip` (at most 20 s), restores calibration and rumble, then starts optional services in the background. The splash runs on every product boot, and serial is the only console.
- **History:** `2c379f8ae609` initramfs splash; `3a24625d0050` rcS/rc.late split; `c46fafbd20f5` list before Wi-Fi and udev; `3af4666f5e3c`/`a343fefaf51d` splash across `switch_root`; `d59622f484c7` udev and the pad stay Class A; `ffd468b6cd0e` drop the LCD text console.
- **Hardware acceptance:** first flip at 10.90 s (LOGBOOK:623-625), then 9.95 s and 9.53 s (LOGBOOK:42, :62); quiet graphical boot on `b9f8947780ec` (`product-phase9.md:340`).
- **Canonical owner:** `docs/ARCHITECTURE.md` §5, §13; `docs/OPERATIONS.md` "Boot classes"; ADR `0003-busybox-init.md`; `docs/DEVELOPMENT.md` "Boot-time development".
- **Wiki owner:** n/a.
- **Findings:** ARCHITECTURE:169 does not name the gate, its 20 s cap, or the restores after it (A19). The Class A list and splash ownership are not canonical (G4). ROADMAP:1841 lists the quiet-gated splash as done next to its removal.
- **Disposition:** fix canonical (this pass) for A19; no action for G4 (gap recorded); preserve historical for ROADMAP:1841.

### 36. Settings ownership and reset behavior

- **Implementation:** Settings UI in the pinned NextUI fork; backends `usr/sbin/{zlyme-ctl,zlyme-reset,zlyme-bootcfg,zlyme-card-defaults}`, `package/system/nextui/zlyme/{zlyme_prefs.c,zlyme_prefs.h,zlyme-game-cleanup.sh}`, `S15bootpart:62`.
- **Invariant:** each policy flag is one file in `/storage/.config/zlyme/`. An empty file means the default, and `zlyme-ctl` defaults must match the `S15bootpart` seed. Reset Settings deletes an explicit list and never deletes user content.
- **History:** `2a88005ffffb` replace governor pickers; `e96485ae9297` drop NTP, boost, merge rows; `3fafcf215fca` reset settings only; `8e38b7db59eb` `zlyme-reset` and `zlyme-bootcfg`; `f12fe69bbff2` `zlyme-card-defaults`; `eeb38a71e28e` confirm format.
- **Hardware acceptance:** Settings rows on `8e8116f00969` (`product-phase9.md:368-378`); Create game folders on `f0143dd5b067` (ROADMAP:1890).
- **Canonical owner:** none (ROADMAP:1840, `product-phase9.md:168-224`). `docs/ARCHITECTURE.md` issue (n)ames the directory only.
- **Wiki owner:** n/a.
- **Findings:** no canonical owner for flags or reset semantics. The `boost` and `merge` flags are still seeded and reset although their rows are gone.
- **Disposition:** no action (gap recorded); maintainer review (not changed) for the residual flags (issue (p)).

### 37. CI, release generation, GHCR

- **Implementation:** `.github/workflows/{build.yml,build-stage.yml,docker-image.yml}`, `.github/zlyme-cache.md`, `scripts/{make-release-deltas.py,zlyme_release.py}`, `scripts/tests/{test_release_tag_target.sh,test_ci_container_image.sh}`.
- **Invariant:** `Build` is manual only. It runs three ccache-carrying stages and publishes a non-prerelease tag `zlyme-<run_id>` at `github.sha` with the full tar, sha256, manifest, deltas, and `zlyme.img`. The remote clean build is the release gate, not hardware acceptance.
- **History:** `1432f2a91236` first CI; `94d740a2802c` three stages; `7b39f4a21ed7` manual only; `a794c895779d` full release; `2193d7a0cdfc` deltas; `3267f78512d6` tag pinned to the source SHA; `d070dfef8283` zlyme44 baseline; `59a75beaa25e` lowercase GHCR owner.
- **Hardware acceptance:** n/a. Build run `37164297221` built `337ccbce2587393463a4b49c551f94e33e318e44` cleanly and succeeded, and published the stable release `zlyme-37164297221` (`zlyme44 (2026-10-04)`), tag at that SHA, zero deltas. That run is the release gate, not hardware acceptance.
- **Canonical owner:** `docs/DEVELOPMENT.md` "Release artifacts", "Build container"; `docs/MAINTENANCE.md` "Releases"; `docs/DEVICE_PORTING.md` "CI".
- **Wiki owner:** n/a.
- **Findings:** DEVELOPMENT:133-135 implies the GHCR image is reused; without the `zlyme.dockerfile` label `build.sh` rebuilds it (V9, inferred). OTA pack failure costs a stage instead of failing the job (issue (h)). DEVICE_PORTING:298 "now".
- **Disposition:** fix canonical (this pass) for V9 and DEVICE_PORTING:298; maintainer review (not changed) for the label (issue (o)) and issue (h).

### 38. Upstream, provenance, licenses

- **Implementation:** `docs/UPSTREAMS.md`, `docs/MAINTENANCE.md`, `AGENTS.md`, `.cursor/rules/{zlyme-core.mdc,knulli-packages.mdc}`, per-package `LICENSE` and `*.hash`, `UPSTREAM` files, `package/system/nextui/{CREDITS,LICENSE}`.
- **Invariant:** a package's own upstream is the version authority; KNULLI and ROCKNIX are packaging references; the wiki is the hardware authority; the archived ROCKNIX fork is history. Every package and stock pak carries its license, and vendored trees record repo, tag, and commit.
- **History:** `9e8cdbb8175e` "prefer Knulli recipes" rule (superseded); `f3620e7ca3c4` LICENSE files; `4f4bf8ecc213` archived hierarchy marked superseded; `7a0fc397cb5b` ship the parson license; `5af14f683e15` upstream-is-authority rule.
- **Hardware acceptance:** n/a.
- **Canonical owner:** `docs/UPSTREAMS.md`; `docs/MAINTENANCE.md`; `docs/ARCHITECTURE.md` §15; `AGENTS.md` "Licensing".
- **Wiki owner:** wiki `AGENTS.md` and `docs/DOCUMENTATION_MODEL.md` (model only; no edit).
- **Findings:** DEVELOPMENT:116-121 puts the ROCKNIX-derived implementation in the hardware precedence (V7). `knulli-packages.mdc:18` reads as making ROCKNIX a hardware source (U3). UPSTREAMS omits the revisions current code depends on, SpruceOS, and the ROCKNIX branch (U1, U2, U4). `zlyme-core.mdc:39` "planned work only" (AG6). Reading lists are duplicated and drift (AG5, AG7). MAINTENANCE:23 does not pin ROCKNIX. 61 of 67 downloaded packages lack `.hash` (V10, AG4).
- **Disposition:** fix canonical (this pass) for V7, U1–U4, AG4–AG7 (state the hash gap), and MAINTENANCE:23; maintainer review (not changed) for adding the missing hashes.

## Canonical contradictions found

Line numbers are at `d3bee63568e0482916f66821093b102b115eb19f`. Labels match the audit working notes: A = ARCHITECTURE, O = OPERATIONS, V = DEVELOPMENT, D = DEVICE_PORTING, U = UPSTREAMS, M = MAINTENANCE, E = ENGINEERING_PRINCIPLES, AG = AGENTS and Cursor rules, G = ARCHITECTURE coverage gaps. Wiki rows use W and WO.

### ARCHITECTURE

- :327 "default is displayed 30%" → `FF_DEFAULT_GAIN_PERCENT 40` (`package/system/nextui/zlyme/gamepad-ff/ff_gain.h:5`, since `09d8853789f2`) → fix canonical (this pass).
- :479 DMC is an in-kernel `tristate` driver inside a kernel patch → external module package, no DMC patch left (`package/drivers/rk3568-dmc/rk3568-dmc.mk`; `b3bb23748aa6`, `21de8081d6e6`) → fix canonical (this pass).
- :242 artifacts identified by prefix, DTB, and board identity → a full tar is checked for DTB, `zlyme`, `Image.gz`; no device field; delta `DEVICE=my355` is literal (`zlyme-update:141-155`, `:235`) → fix canonical (this pass).
- :372 the package must not hard-code `my355` → `nextui-session:12-13`, `:150`, `:162-163`, `:375-378` do → fix canonical (this pass).
- :82 `board/<device>/device.conf` → `board/my355/fsoverlay/usr/share/zlyme/device.conf` → fix canonical (this pass).
- :77, :87 `uboot/` holds the config integration; the board "owns most" → config hook is `board.mk:9-66`; the board owns all of them → fix canonical (this pass).
- :117-131 command list and board ownership → `zlyme-governor` ships from `nextui.mk:187-193`; `zlyme-ctl`, `zlyme-radios`, `zlyme-input`, `zlyme-boot-write` and others missing → fix canonical (this pass).
- :412, :418 board-specific packages are Kconfig-gated → `gpudriver`, `libmali`, `mali-kbase` are not (`Config.in` files) → fix canonical (this pass).
- :206 logs only under `/storage/.logs` when enabled → `rc.late:96-106` writes to `/storage/.config` on every boot → fix canonical (this pass).
- :278, :289 WestonPack cleanup belongs to PortMaster → `zlyme-portmaster-cleanup`, run by `nextui-session:267-279` → fix canonical (this pass).
- :214 point versions publish same-major deltas → baseline plus last three points, 70% cut, smallest delta (`scripts/zlyme_release.py:17`, `:49-77`; `github-release.py:182-192`) → fix canonical (this pass).
- :296-301 GPU stacks without a default → `libmali` (`package/system/gpudriver/gpudriver:71-75`, `S15bootpart:62`) → fix canonical (this pass).
- :26-31, :139-145 boot path without BL31, preloader, or overlays → `configs/zlyme_my355_defconfig:87-92`, `extlinux.conf:5-10` → fix canonical (this pass).
- :148-150 one read-write reason → also `/boot/zlyme-logs` and `post-update.sh` (`init:95-121`, `:182-212`) → fix canonical (this pass).
- :173-180 layout without sizes or first-boot growth → `genimage.cfg`, `post-image.sh:22-28`, `S13resize` → fix canonical (this pass).
- :448 "Phase 6 enables…" → present-tense fact (DTS `:333-353`, `:635-653`) → fix canonical (this pass).
- :324-334 lid and power without in-pak behavior → `zlyme-keylidmon.c:167-216` → fix canonical (this pass).
- :182 shutdown always uses `zlyme-halt` → a shell `poweroff` uses BusyBox `rcK` → fix canonical (this pass).
- :169 `rc.late` gate unnamed → `nextui-first-flip`, 20 s cap, restores first (`rc.late:17-40`) → fix canonical (this pass).
- :70, :87, :262, :267, :283 time-ambiguous "eventually", "current", "temporary" → present tense, "per-launch" → fix canonical (this pass).

### OPERATIONS

- :238 "Deep suspend should be validated specifically under Zlyme/NextUI" → Phase 6 accepted on `b709719aac5c` (ROADMAP:1671-1729; DTS `:333-353`) → fix canonical (this pass).
- :236 "standard suspend works independently of deep suspend" → shipped mem suspend is BL31 deep suspend (`suspend:9`, DTS `:333-353`) → fix canonical (this pass).
- :150-155 "board-specific controller handling" → `miyoo-flip-gamepad` plus InputPlumber virtual pads (`rc.late:72-81`) → fix canonical (this pass).
- :117 GPU/devfreq knowledge stays in the my355 implementation → `gpudriver` and `zlyme-governor` live in `package/system/` → fix canonical (this pass).
- :110-115 no GPU default → `libmali` → fix canonical (this pass).
- :179 `zlyme-update status` keys → more keys printed (`zlyme-update:686-702`) → fix canonical (this pass).
- :223-236 `ON_SOURCE` paragraph splits the list → move it after the list and name `0030` → fix canonical (this pass).
- :225 "the current `SYS_CAN_SD` handling" → patch `0007` → fix canonical (this pass).
- :235 DMC owner unnamed → `package/drivers/rk3568-dmc` → fix canonical (this pass).
- :141 RTL8733BU without firmware or order → `rtl8723fu`, `rtl8733bu-combo.conf`, real kmod → fix canonical (this pass).
- :3, :5, :32, :43, :133, :179, :234 "current…" status wording → plain present tense → fix canonical (this pass).

### DEVELOPMENT

- :200-213 DTB copied straight onto `/boot`, `root@192.168.0.108` → `/boot` is read-only since `37d41679996f`; use `zlyme-boot-write` and `<flip>` → fix canonical (this pass).
- :59 `./build.sh savedefconfig` works → the repo is mounted `:ro` (`build.sh:171`) and `BR2_DEFCONFIG` points into it; output would also strip the defconfig comments (inferred, not run) → fix canonical (this pass).
- :200 `/boot` mounted by `S12bootfs` → initramfs mounts it read-only; `S12bootfs` is the fallback (`rcS:53-58`) → fix canonical (this pass).
- :66-73 refreshed-package list → `build.sh:345-369` also refreshes `zcrapegoat` → fix canonical (this pass).
- :75-77 a normal full build picks up source edits → eight local packages are not refreshed; overlay rsync keeps removed files → fix canonical (this pass).
- :36, :54-62 options; no `--config` builds minimal → `--clean`, `--shell`, `--rebuild-image`, env overrides; `storage.sh.example` sets the product defconfig → fix canonical (this pass).
- :17-21 "pinned" without versions → Buildroot 2026.02.3, Linux 7.0.2, U-Boot 2026.01, BL31 v1.44 / TPL v1.23 → fix canonical (this pass).
- :116-121 ROCKNIX-derived implementation in the hardware precedence → wiki is the authority, archived fork is evidence (`AGENTS.md:11-17`, `docs/UPSTREAMS.md`) → fix canonical (this pass).
- :169-182 compiler policy without facts → `-O3`, Cortex-A55 flags, two `-O2` pins, kernel `-O2` → fix canonical (this pass).
- :133-135 GHCR image is reused → `build.sh:141-157` rebuilds an unlabelled image (inferred) → fix canonical (this pass).
- :99-107 packages carry hashes → 61 of 67 downloaded packages have none → fix canonical (this pass).
- :160-167 moving hooks to `board.mk` is the "highest-value" future change → done (`external.mk:5-7`) → fix canonical (this pass).
- :95 `storage.sh` → `storage.sh.example`, copied to a gitignored `storage.sh` → fix canonical (this pass).
- :276-291 validation gates omit `scripts/tests/` and build-time assertions → fix canonical (this pass).
- :295-302 doc list omits MAINTENANCE, UPSTREAMS, ROADMAP, and ADRs → fix canonical (this pass).
- :3, :5, :139, :171, :216, :251 "current", "later" wording → fix canonical (this pass).

### DEVICE_PORTING

- D1 :160-166 `zlyme-audio` owns codec routing → `zlyme-jackd` does (`zlyme-audio:26`, `zlyme-jackd.c:27-28`) → fix canonical (this pass).
- D2 :168-184 profiles without `emu <tag>` → `governor.sh:252-283` → fix canonical (this pass).
- D3 :240 governor logic in `board/my355/fsoverlay` → `package/system/nextui/zlyme/governor.sh` → fix canonical (this pass) by stating the exception; moving it is maintainer review (not changed).
- D4 :288 generic updater reads board identity → board-local `zlyme-update`, literal `my355` at `:235` and in the release scripts → fix canonical (this pass).
- D5 :330-342 SoC-family drivers are not gated on the device → `package/drivers/rk3568-dmc/Config.in:3` is gated → fix canonical (this pass) by recording the decision.
- D6 :259-268 "examples to audit" → audit is done; list gated and ungated packages → fix canonical (this pass).
- D7 :49-61 `device.conf` at the board root; board files missing → real path; `extlinux.conf`, `image-date.sh`, OTA hooks → fix canonical (this pass).
- D8 :104-123 "move hooks out of external.mk" → done → fix canonical (this pass).
- D9 :217-223 "prefer a hidden Buildroot string" → done (`Config.in:14-17`, `nextui.mk:22-26`) → fix canonical (this pass).
- D10 :87-98 Kconfig snippet "for now" → point at `Config.in` → fix canonical (this pass).
- D11 :186-192 `zlyme-led`, `zlyme-halt` without verbs → `zlyme-led:252-293`, `zlyme-halt:14` → fix canonical (this pass).
- :9, :203, :286, :298 "current", "today", "now" → fix canonical (this pass).

### UPSTREAMS

- U1 :190-203 "Compared revisions" omits ROCKNIX `next` `a55d58a1209b`, ROCKNIX `fe127fad01f6`, KNULLI `6a23957a19a1`, SpruceOS `2b7bc4a79359`, and the NextUI fork `70344ade993c` → fix canonical (this pass).
- U2 :5-59 no entry for SpruceOS policy data → governor floor source (`governor.sh:180`) → fix canonical (this pass).
- U4 :73-81 ROCKNIX branch unnamed → `next`, pinned per comparison → fix canonical (this pass).
- U5 :16-18 latest-release rule → gpSP uses a distribution-carried commit (`libretro-gpsp.mk:10`) → fix canonical (this pass).
- :61 "Current KNULLI repository" heading → fix canonical (this pass).

### MAINTENANCE

- M1 :17 runtime SHA also stated at DEVELOPMENT:130 → MAINTENANCE owns it → fix canonical (this pass).
- M2 Linux version not stated → 7.0.2 → fix canonical (this pass).
- M3 :36 versions stated without the `UPSTREAM` files as the record → fix canonical (this pass).
- M4 no route for governor floors or `-O2` pins → fix canonical (this pass).
- :23 "current official ROCKNIX RK3566 work" → a pinned `next` commit → fix canonical (this pass).

### ENGINEERING_PRINCIPLES

- E1 §18 polling is acceptable when measured → `zlyme-led watch` polls every 2 s, unmeasured (`zlyme-led:202-247`) → maintainer review (not changed) (issue (i)).
- E2 §8 fail fast at build boundaries → OTA pack failure is soft (`post-image.sh:87-90`) → maintainer review (not changed) (issue (h)).
- E3 §9 one source of truth for the DTB name → literals in `genimage.cfg:11`, `board.mk`, `extlinux.conf:9` → fix canonical (this pass) by listing them in DEVICE_PORTING; a `genimage.cfg` assertion is maintainer review (not changed).
- E4 :113 update packages carry a device identity → only deltas do → fix canonical (this pass) (with D4).
- E5 :197-199, :216-221, :230 migration and "may later" wording → InputPlumber is the application controller since Phase 4 → fix canonical (this pass).

### AGENTS and Cursor rules

- AG1 `AGENTS.md:95` `zlyme-governor` as a device runtime → ships from the generic package → fix canonical (this pass) by stating the exception.
- AG2 `AGENTS.md:68-84` no per-card, no ROCKNIX-joypad, no `.userdata` invariants → missing rules, not contradictions → maintainer review (not changed).
- AG3 no InputPlumber ownership invariant → maintainer review (not changed).
- AG4 `AGENTS.md:136-143` hashes required → 61 of 67 lack them → fix canonical (this pass) by stating the gap; adding hashes is maintainer review (not changed).
- AG5 `AGENTS.md:34-36` and `:43-45`, `zlyme-core.mdc:8`, `:15-17` list ENGINEERING_PRINCIPLES twice → fix canonical (this pass).
- AG6 `zlyme-core.mdc:39` "describes planned work only" → ROADMAP also holds acceptance history → fix canonical (this pass).
- AG7 `zlyme-core.mdc:8-29` vs `AGENTS.md:32-62` reading lists drift → fix canonical (this pass).
- U3 `knulli-packages.mdc:18` "the current ROCKNIX comparison" as a hardware source → the wiki is the hardware authority → fix canonical (this pass).

### README

- :7 "no desktop and no compositor" → app-scoped Weston (`zlyme-weston-run`) and PortMaster WestonPack exist → fix canonical (this pass).
- :9 "The device does not drain while off" → `0007` removes the abnormal ~8 mA drain; a small drain remains (ROADMAP:1642) → fix canonical (this pass).
- :11 "if needed other systems will be supported" → only my355 is supported and no port is planned (`AGENTS.md`) → fix canonical (this pass).
- :17 "fastest setting this CPU will take (`-O3`)", "usual performance profile", "only mali supports Vulkan as of now" → `-O3` userspace with two `-O2` pins, kernel `-O2`, Vulkan only with libmali → fix canonical (this pass).
- :80, :179 "Settings → About → System logs" → Settings → System → Advanced → System logs (NextUI fork `zlymemenu.cpp:361`) → fix canonical (this pass).
- :41 "each community pak below" includes Settings → fix canonical (this pass).
- :57 "(or prerelease)" → the workflow never publishes prereleases; Settings has a prerelease channel → fix canonical (this pass).
- :72 `zlyme-my355-*.tar` also matches delta tars → the full tar only → fix canonical (this pass).
- :91 "Mednafen SuperFaust" → Supafaust → fix canonical (this pass).
- :123 Wii omits `.gcm` → `rom-exts.txt:56` → fix canonical (this pass).
- :128 PSP Bios cell holds a renderer note → "—" → fix canonical (this pass).
- :43 Factory Reset text → UI strings in `zlymemenu.cpp` → fix canonical (this pass).
- :55 "not called physically validated", :175 "adapt them in a breeze" → plain wording → fix canonical (this pass).
- :195 `--minimal` is "bootable" → the minimal build is expected to fail post-build (issue (d)) → the README build table was replaced by a pointer to `./build.sh --help` and `docs/DEVELOPMENT.md` (this pass); issue (d) stays maintainer review (not changed).
- Credits missing for zolek86 NextUI-Overlays v0.1.1, nborodikhin nextui-music-player v1.17.0, moonlight-embedded, and SilverPsychoo Ruffle-Handheld v4.2 → fix canonical (this pass), each checked against its `pak.json` or recipe.
- BIOS required/optional for GBA, PS, Saturn, A78, DC depends on upstream cores → maintainer review (not changed).

### ADRs (not in the canonical set; recorded for completeness)

- `0005-controller-ownership.md:35` "Phase 4D still retargets emulators" → Phase 4D closed 2026-09-28 (ROADMAP:1626-1630) → fix canonical (this pass).
- `0004-device-boundaries.md:7` and `0001-single-device-first.md:25` describe the pre-Phase-0 state as current → dated context → fix canonical (this pass) for 0004; no action for 0001.
- `0002-direct-kms.md` does not name the two runtime owners → fix canonical (this pass).
- No ADR records why the root is one file replaced whole → ADR 0006 → fix canonical (this pass).

## Source comments corrected (this pass)

Comment-only changes. With comments and blank lines stripped, both files are identical to `d3bee63568e0482916f66821093b102b115eb19f`, so the built DTB and the configuration do not change.

- `rk3566-miyoo-flip.dts:36`: "saradc ch0 is owned by joypad" → the sticks are on UART1 (`miyoo-flip-gamepad` uses serdev on UART1).
- `rk3566-miyoo-flip.dts:331`: "vdd_logic stays on in this image" → off in mem suspend, which needs `ARMOFF_LOGOFF` (`28675fb2dded`).
- `rk3566-miyoo-flip.dts:998`: SARADC "used by joypad driver" → no consumer in this DTS.
- `rk3566-miyoo-flip.dts:1115`: "Phase 3B does not remove them" → CTS pinmux and DMA match stock and are not proven removable (`joypad-driver.md`).
- `rk3566-miyoo-flip.dts:1123-1124`: "Phase 3B tracer … No calibration" → one production input device; calibration lives in userspace files.
- `rk3566-miyoo-flip.dts:1493`: GPIO0 D0/D1 "uart2, needed for deep sleep resume" → `uart2m0`, the debug console (`4730aec69a7c`; UART2's role in resume is not established in `deep-suspend-phase6.md`).
- `zlyme_my355_defconfig:65`: dtb line "in external.mk" → `board/my355/board.mk`.
- `zlyme_my355_defconfig:129`: "S27sshd starts before NextUI" → `rc.late` starts `S50sshd` after the first frame.
- `zlyme_my355_defconfig:148`: "no X11/Wayland" → no X11; Wayland is for the temporary Weston.
- `zlyme_my355_defconfig:182`: old defconfig names → `zlyme_my355_defconfig` / `zlyme_my355_minimal_defconfig` (`80eef38`).
- `zlyme_my355_defconfig:316`: "Xwayland stays off until the tracer is proven" → no Xwayland; PortMaster's WestonPack brings its own.

The same stale `:65` and `:129` comments remain in `zlyme_my355_minimal_defconfig`. `board.mk:88`, the `rtl8733bu_power.c` header, the `zlyme-radios` header, `build.sh:360-362`, and the "About → System logs" comments in `zlyme-logs` and `pak-log.sh` were not changed. They are listed for the next comment pass.

## Suspected runtime and build issues (not changed)

Nothing here was changed or tested on hardware. Each item is maintainer review (not changed).

- **(a) `zlyme-update uboot` can pick the wrong disk.** Evidence: `uboot_part_dev` returns the first `PARTLABEL=uboot` it finds: `/dev/disk/by-partlabel/uboot`, then sysfs `PARTNAME=uboot`, then `blkid` (`board/my355/fsoverlay/usr/sbin/zlyme-update:484-501`). `install_uboot` writes `idbloader.img` at sector 64 and `u-boot.itb` at sector 16384 of that partition's parent disk (`:520-552`, `dd` at `:548-549`). Nothing checks that the disk also holds `/boot`. Why: a removable SD2 card or USB disk with a GPT `uboot` partition (another Zlyme card, a Rockchip SDK image) could be the target of a destructive write. It is an explicit maintainer command, not part of routine OTA (`board.mk:7`). Validation: with a second Zlyme card in SD2, read `/dev/disk/by-partlabel/uboot` and the `uboot_part_dev` result without writing; a fix would compare the parent disk with the disk behind `/boot`.
- **(b) Initramfs can mount the second card as the boot volume.** Evidence: for the early splash, `/init` tries `mount_boot /dev/mmcblk0p2`, or `/dev/mmcblk1p2` if the first node does not exist yet, with no label check (`package/boot/zlyme-initramfs/init:140-144`). It then skips the `LABEL=ZLYMEBOOT` search when `/boot_root` is already mounted (`:164-169`). GPT nodes appear late (`:66-70`); the boot slot is `mmc0 = &sdmmc0` (DTS `:27`). Why: a FAT partition 2 on the SD2 card could become `/boot_root`, so the boot drops to a shell with "no /zlyme" or runs and commits that card's root. Validation: hardware check. Boot several times with a second Zlyme card in SD2 and confirm the device behind `/boot`.
- **(c) Suspend arms a 24 h RTC wake.** Evidence: `package/system/nextui/zlyme/suspend:4-6` writes `+86400` to `rtc0/wakealarm` before every `mem` (from `083e8061c473`). No reason is recorded; the comment at `:3` cites ROCKNIX `sleep.sh`. Neither NextUI nor `zlyme-keylidmon` (`zlyme-keylidmon.c:195-216`) checks the wake reason. Why: a suspended Flip wakes after 24 h with backlight and radios on, and with a pak on screen nothing suspends it again. Validation: maintainer intent first, then a timed resume test.
- **(d) The default minimal build is expected to fail post-build.** Evidence: `build.sh:27` defaults to `zlyme_my355_minimal_defconfig`, which selects none of `BR2_PACKAGE_MIYOO_FLIP_GAMEPAD`, `BR2_PACKAGE_ZLYME_KEYLIDMON`, `BR2_PACKAGE_GPUDRIVER`, `BR2_PACKAGE_LIBMALI` (product `:203`, `:236`, `:281-282`). `board/my355/post-build.sh:9` `note()` sets `fail=1`; `:21-23` require `miyoo-flip-gamepad.ko`; `:114` requires `zlyme-keylidmon`; `:327` exits `${fail}`. `etc/modprobe.d/zlyme-gpu.conf:3` blacklists panfrost, and only `gpudriver` lifts it. Why: the default `./build.sh` should fail; if it passed, the image would have no pad and no GPU stack, although README:195 calls it bootable. Validation: one minimal build. Source-only inference; not built.
- **(e) `zlyme-boot-write` is not a lock.** Evidence: `holder_alive` accepts any live pid in `/run/zlyme-boot-write.pid` (`zlyme-boot-write:25-30`), and a caller then runs its command without its own remount (`:48-51`). Why: an unrelated overlapping writer can hit a read-only `/boot` when the holder closes, or make `remount,ro` fail so the holder exits 1 with `/boot` writable. OTA staging and Settings are not expected to overlap (`frontend-source-phase8.md:228`). Validation: decide whether ancestry should be checked; a host-side test with two overlapping callers.
- **(f) Late governor reset after the first frame.** Evidence: `S27led:23` runs `zlyme-ctl apply-gov`, which applies `smart`. `rc.late:53` starts `S27led` in the background after the gate, and `:56` starts `S29udevtrigger` (which loads `rk3568_dmc`) in parallel. After an OTA, `rc.late:92-93` and `zlyme-update:712` run `apply-gov` again. LOGBOOK:96 notes `apply-gov` may run before the DMC probe. Why: a game started in that window can drop to `smart` (2 cores, DMC 324 MHz) for the session, and DMC can keep its probe default until the next profile change. Validation: launch a game right after the first frame and after an OTA reboot, then read the governor, online CPUs, and the devfreq state. Unverified on hardware.
- **(g) Unfingerprinted local packages keep stale binaries.** Evidence: `refresh_compiled_package` (`build.sh:327-369`) covers nextui, minui-list, minui-presenter, zcrapegoat, zlyme-keylidmon, openbor, ppsspp. These `SITE_METHOD = local` packages are not covered: zlyme-input, zlyme-jackd, miyoo-flip-gamepad, rk3568-dmc, rtl8733bu-power, gpudriver, pico8, rtl8723fu-firmware. The overlay rsync does not delete removed files. Why: a source edit can build "successfully" with the old binary; `assert-input-rootfs.sh` catches only a subset. Validation: edit one such source, run a full build, and compare the packed binary.
- **(h) OTA pack failure is non-fatal.** Evidence: `board/my355/post-image.sh:87-90` runs `make-update-tar.sh … || echo "post-image: update tar skipped"`. In CI that becomes another stage (`build-stage.yml:121-138`). Why: a build can succeed without an OTA tar, against ENGINEERING_PRINCIPLES §8. Validation: force the pack step to fail in a local build and decide whether it must be fatal.
- **(i) LED watcher polls every 2 s.** Evidence: `usr/sbin/zlyme-led` `watch()` loops with `sleep 2` (`:202-247`, `:245`), started by `S27led:21`; each pass forks `zlyme-ctl` and several `cat`/`tr`. Why: indefinite wakeups while power_supply already raises uevents; no measurement is recorded. Validation: measure wakeups and CPU on the Flip, or move to uevents in a separate change.
- **(j) SD slot 2 enables UHS modes the wiki says were removed.** Evidence: DTS `&sdmmc1` (`:1032-1043`) has `sd-uhs-sdr12`, `-sdr25`, `-sdr50`, `-sdr104`, unchanged since `d843dbecf314`. Its own comment at `:1031` says "no UHS modes". The wiki (`board-dts-pmic-ddr-updates.md:140`, `:225`) says SDR50 was removed from slot 2 because the shared vqmmc limits stable UHS, and the stock DTB has no UHS mode on `fe2c0000`. Why: a hardware conflict on a rail shared by both slots. Validation: a runtime DTS change needs Flip testing with cards in both slots.
- **(k) Dormant mergerfs is still selectable.** Evidence: `package/system/Config.in:22` sources `package/system/mergerfs/Config.in`; neither defconfig selects it; its help describes the pooling that `3c7f987b1d3a` replaced. Why: it can revive a superseded design. Validation: none at runtime; removal would be a separate commit.
- **(l) `board.mk` copies unused `dts-overrides`.** Evidence: `board/my355/board.mk:88-92` rsyncs `board/my355/linux/dts-overrides/rockchip/{rk3566-powkiddy-rk2023.dtsi,rk3568-anbernic-rg-ds.dts}` into the kernel tree. No current patch or DTS references either file; both came with `d843dbecf314` for foreign-board patches that Phase 2C removed. Why: dead kernel-build input and a misleading comment. Validation: a kernel build without the hook.
- **(m) Literal `my355` in generic paths.** Evidence: `zlyme-update:235` (`DEVICE` check); `nextui-session:12-13`, `:88`, `:150`, `:162-163`, `:375-378`; `rc.late:103`; `scripts/zlyme_release.py`; `scripts/make-release-deltas.py`; `init:113-117`. `device.conf` already has `ZLYME_DEVICE_ID`. Why: porting seams, not bugs today. Validation: none until a second device exists.
- **(n) Card writes with logs off.** Evidence: `rc.late:96-106` copies `/tmp/boot-timing` and `/tmp/nextui.txt` to `/storage/.config` every 5 s for 30 s on every boot, whatever the `logs` flag says. Its comment gives the reason: `/tmp` is lost when a hung panel forces the card out. `docs/ARCHITECTURE.md` and `docs/OPERATIONS.md` now describe it (this pass). Why it stays open: AGENTS asks to avoid pointless writes, and whether this snapshot should follow the `logs` flag is maintainer intent. Validation: confirm intent; check exFAT writes on a logs-off boot.
- **(o) The GHCR builder image is always rebuilt.** Evidence: `docker-image.yml:35` builds without the `zlyme.dockerfile` label that `build.sh:145`, `:156` compare. Why: CI time, and the container then comes from an unpinned `apt-get` run. Inferred; CI logs not inspected. Validation: read one CI log.
- **(p) Residual `boost` and `merge` flags.** Evidence: seeded at `S15bootpart:62`, reset at `zlyme-reset:18`, and still read by `zlyme-ctl`; `apply-boost` is a no-op and the Settings rows were removed in `e96485ae9297`. Why: inert state a later change could misread. Validation: none; maintainer decision.
- **(q) Two unexplained choices.** Evidence: `portmaster-launch:140` `sleep 0.4` (from `d314d7ffb27b`); `S15bootpart:15-16` prefers `/dev/mmcblk0p3` over `LABEL=ZLYME`. Why: ADR 0003 asks for observable readiness, and label lookup is the stated mount rule. Validation: maintainer intent.

## Hardware wiki synchronization plan

The wiki is `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` at `b08e335d31fca41383e01176390914c3d4550ec5`, the same pin as `docs/UPSTREAMS.md:197`. This plan was written against that pin. `docs/ROADMAP.md` names the work "10C. Wiki synchronization". The result is recorded below.

### Synchronization result

- Zlyme runtime evidence: `337ccbce2587393463a4b49c551f94e33e318e44`. That is the hardware-accepted runtime that Build run `37164297221` built cleanly. The run succeeded and published the stable release `zlyme-37164297221`, `zlyme44 (2026-10-04)`.
- Zlyme documentation content used for the wiki wording: `d2e2496b7fe935d5123d082d1ef28b6ac28ed139` on `phase-10-maintenance`. It is not a hardware-tested runtime. Later Zlyme commits, including this record, are bookkeeping and were not the sync source.
- Wiki commits on `main`, from `b08e335d31fca41383e01176390914c3d4550ec5`: `4ea7548041d63387c80a26b2152330a2bfbf4181` ("docs: synchronize the Zlyme zlyme44 implementation") and `609ec338b6d3bf7b34d8dc70ad27c3adea7d8f8a` ("docs: document the current Zlyme install path"). Fourteen Markdown pages changed. No evidence file, log, or dump changed.
- Not done in this sync, and waiting on the maintainer: the multiboot distro-table row, the DDR v1.18 with BL31 v1.44 data point, and any boot-message claim that needs a fresh serial capture. The hardware-fact conflicts below stay open.
- Zlyme Installer (`Zetarancio/zlymeOS-Installer`): a fork of `spruceUI/spruceOS-Installer`. SundownerSport made the first Zlyme adaptation (`9400fc625eae57729f83f5bc2eeba2724a94a8c1`). The Zlyme branch is `zlyme-installer`. Its README now leads with the Zlyme Installer (`a7393d60c5d03956315f237ddf1430e9b2ad3e1c`). On 2026-10-04 only prereleases were published: `beta-zlyme-installer` and `beta-main`. The `beta-zlyme-installer` tag points at `main` (`ab3d7cf86b62093a984f076d05b402db024b536b`), not at the branch it was built from. The repository's default branch is still `main`, which shows the SpruceOS README.
- The clean-build root differs from the locally accepted one. The published `zlyme44` root SHA-256 is `a831ad6aa8e2543a44fd8810ec4d76a18b317deebaf8dfcdaaec23b7011f650b`. The accepted local image was `9462f77f78bb750680b36f1ab720ef22e6954be6d76f7caab5127b7010288213`. The source SHA is the same. A later delta built against the published root does not match a device that still runs the local image, so that device gets the full OTA.

Constraints a Phase 10E edit must preserve:

- Roles: the wiki holds hardware, firmware, protocol, and reverse-engineering truth; Zlyme holds the active implementation; the archived ROCKNIX fork is history (wiki `AGENTS.md:45-64`, `docs/DOCUMENTATION_MODEL.md:7-23`).
- Placement test: a statement that stays true under any OS goes on a hardware page; anything else is one line on `docs/implementations/zlyme.md` (`AGENTS.md:670-677`).
- Every Zlyme claim carries a Zlyme revision (`AGENTS.md:132`, `zlyme.md:23`). The snapshot line on `zlyme.md` names repository, branch, commit, and date (`DOCUMENTATION_MODEL.md:34`).
- Keep the evidence labels. Never upgrade an inference while rewriting (`DOCUMENTATION_MODEL.md:30`).
- Qualify "current" as "Zlyme as of commit X" (`AGENTS.md:281-299`).
- Patch numbers are not identities. Name the mechanism, not "1011" or "1013" (`AGENTS.md:301-315`).
- OS policy (InputPlumber, Weston, WestonPack, NextUI) gets a one-line status only (`AGENTS.md:317-328`).
- Historical ROCKNIX pages stay in past tense; `rocknix.md` is not refreshed (`AGENTS.md:214-228`).
- Investigations get a current-conclusion banner, not a rewrite. Evidence artifacts are never edited.
- No developer-local paths or LAN addresses. No new conclusions by documentation; compilation is not hardware validation.
- Do not paste the Zlyme architecture manual into the wiki (ROADMAP §10C).

All rows are evidenced against runtime `337ccbce2587393463a4b49c551f94e33e318e44`. The SHA column lists the phase revisions to cite as well. "R" numbers are the evidence-register rows of the working notes.

| Wiki file | Stale statement (line) | Zlyme evidence | Phase SHA | Replacement scope | Kind |
| --- | --- | --- | --- | --- | --- |
| W1 `docs/implementations/zlyme.md` | :9 "No Zlyme commit, branch, or device capture is snapshotted here yet."; :11-17 does not claim deep suspend, joypad driver, InputPlumber, DMC packaging, Weston; :19 "not current"; :21 "Roadmap (not current)" | R1–R10; ROADMAP Phases 1–9 status blocks | all below | Snapshot line; one line per mechanism; a "not claimed" list; links into Zlyme docs | implementation status |
| W2 `README.md` | :91 "Not claimed for Zlyme." (suspend row) | DTS `:333-353`, `:635-653`; ROADMAP:1669-1681 | `b709719aac5c` | Keep the fork sentence; Zlyme ships deep suspend with `vdd_logic` off as of that revision | implementation status |
| W3 `README.md` | :108 "Zlyme has not been recorded here as enabling it." | same as W2 | `b709719aac5c` | Replace the last sentence with the revision | implementation status |
| W4 `README.md` | :73 "'Demonstrated' means observed on the archived ROCKNIX fork…" | — | — | Allow "Zlyme (with revision)" as a source | implementation status |
| W5 `README.md` | :88, :106 "carried it as patch 1012" | `package/drivers/rk3568-dmc`; ROADMAP:1737-1741 | `21de8081d6e6` | Add: Zlyme ships the V2-SIP mechanism as an external module on Linux 7.0.2 | implementation status |
| W6 `README.md` | :104 "…carried that as an rk8xx/suspend patch set and then left it disabled." | same as W2 | `b709719aac5c` | Add a pointer that Zlyme enables it | implementation status |
| W7 `docs/README.md` | :64 "No feature snapshot recorded here yet"; :42 "archived-fork shipping state at the end" | R1–R10 | snapshot | "Status snapshot zlyme44 / `337ccbce2587393463a4b49c551f94e33e318e44`"; :42 after W18 | implementation status |
| W8 `docs/hardware/input.md` | :31 "does not yet record a Zlyme joypad driver or an InputPlumber policy" | `package/drivers/miyoo-flip-gamepad`, `package/system/inputplumber`; ROADMAP:1504-1531, :1626-1630 | `4d1c1d44d2a2`, `0b139e9099ee` | Two or three sentences: driver, sysfs calibration, InputPlumber as OS policy | implementation status |
| W9 `docs/hardware/input.md` | :12 "Byte-level frames are not copied into this page" | stock `joystick_study/miyoo_inputd.c` (wiki repo); `docs/research/joypad-driver.md:22-51`; LOGBOOK:308-326 | Phase 3B/3C1 | UART1 9600 8N1, frame `FF YL XL YR XR FE`, ~66.8 frames/s on the tested unit; stock vs observed labels | generic hardware truth |
| W10 `docs/hardware/input.md` | :11 17 GPIO switches, "not restated here" (addition) | `joypad-driver.md:53-155`; DTS `:1136-1237` | Phase 3B, 4B | L2/R2 are digital; stock `gpio-keys-polled`; edge IRQs with 10 ms debounce on the tested unit; Switch-stick reports unvalidated | generic hardware truth |
| W11 `docs/drivers-and-dts/suspend-and-vdd-logic.md` | :10 "Zlyme has not been recorded here as shipping deep suspend." | same as W2 | `b709719aac5c` | Zlyme ships it as of that revision; link the W18 section | implementation status |
| W12 same | :16, :20, :60-62 driver named `rk3568-suspend`, `rk3568` namespace | stock DTB `miyoo355_20250527_0.dts:652-658`, `:1260-1273`; `deep-suspend-phase6.md:94-153`; DTS `:333-334` | `b709719aac5c` | Lead with SIP `0x82000003` and the stock/BSP DT shape; move archived names into a labelled subsection | generic + implementation |
| W13 same | :70 `late_initcall_sync`, `rk3568,pm-config`; :78 re-send config | `deep-suspend-phase6.md:136-160`, `:395-408`; LOGBOOK:134 | `ff92191bb51c`, `b709719aac5c` | BSP lifecycle as the protocol; a built-in driver with the same `.prepare` works (observed in Zlyme) | generic hardware truth |
| W14 same | :154-164 SIP table without `0x09` | `deep-suspend-phase6.md:125-133`, `:415-455`; ROADMAP:1673 | `b709719aac5c`, `21de8081d6e6` | Add `LINUX_PM_STATE 0x09`; BL31 v1.44 returned `res.a0=0` for `0x09`, `0x01`, `0x02`, and `0x05`=0 | generic hardware truth |
| W15 same | :91 "ARM cores and OP-TEE secondary CPUs reinitialize." | no BL32 in the Zlyme FIT; `docs/archive/NOTES.md:66` | `b709719aac5c` | "OP-TEE, when the FIT carries one"; stronger label only after a serial capture | generic hardware truth |
| W16 same | :168-176 "Historical capture … 1013 patches" | `deep-suspend-phase6.md:430-444`; ROADMAP:1673-1675; LOGBOOK:120 | `b709719aac5c` | Keep it; add a Zlyme block (7.0.2, BL31 v1.44, `.prepare` lines, recovered devices); no standby current measured | generic (observed in Zlyme) |
| W17 same | :215 suspend and DMC "independent but complementary" (fork only) | ROADMAP:1739; LOGBOOK:72 | `21de8081d6e6` | DMC with `center-supply = <&vdd_logic>` coexists with `vdd_logic` off and settles at 324 MHz; DFI patch present in every test | generic hardware truth |
| W18 same | after :229-240, no Zlyme section; :240 battery estimates are fork-only | `deep-suspend-phase6.md:446-455` | `b709719aac5c` | "Zlyme implementation" section; open questions (PMIC_LP vs `SLPPIN_SLP_FUN`; standby current unmeasured); no 100–120 h claim | implementation + generic |
| W19 `docs/drivers-and-dts.md` | :51 "Not claimed for Zlyme." | same as W2 | `b709719aac5c` | Zlyme enables deep suspend as of that revision | implementation status |
| W20 `docs/rk3566-reference/datasheet-specs.md` | :103 "understood, but not enabled"; :112 "Zlyme's choice is not recorded here." | DTS `:635-653`; stock DTB `:1260-1273` | `b709719aac5c` | Retitle; stock off, archived fork on, Zlyme off with `ARMOFF_LOGOFF` | implementation (+ stock) |
| W21 `docs/stock-firmware-and-findings/bsp-and-ddr-findings.md` | :181 "Zlyme's packaging of the same mechanism is not recorded here." | `package/drivers/rk3568-dmc/README.md` | `21de8081d6e6` | External module, modalias autoload, refuses SIP API below `0x101`; 324–1056 MHz and resume observed | implementation status |
| W22 `docs/drivers-and-dts/wifi-bt-power-off.md` | :31 "does not record whether Zlyme ships RTL8733BU-POWER, an rfkill policy, or a sleep hook" | `package/drivers/rtl8733bu-power`; DTS `:112-117`; `zlyme-radios` | `b709719aac5c`, `21de8081d6e6` (resume) | Same-design enable-GPIO driver, on-demand load, radios stopped before mem; script names stay in Zlyme | implementation status |
| W23 `docs/drivers-and-dts/drivers.md` | :36 "Zlyme's equivalent is not recorded here."; :55 "does not record what Zlyme builds" | `package/drivers/rtl8733bu/rtl8733bu.mk:9-10` | runtime only | Same upstream commit `c46aa25e237c` with six patches matching 001–006 by subject; not byte-identical | implementation status |
| W24 `docs/drivers-and-dts/drivers.md` | :30-32 module tunables; :46-51 init-script load order | `etc/modprobe.d/8733bu.conf:1-23`, `rtl8733bu-combo.conf:1-7` | runtime only | Attribute both to the archived fork; add the generic order constraint (BT after `8733bu`; IPS drops BT firmware), labelled observed in Zlyme | generic + implementation |
| W25 `docs/boot-and-flash.md`, `README.md`, `spi-and-boot-chain.md` | boot-and-flash :83 and README :112 "also carried ATF and OP-TEE"; spi :24, :286 | `configs/zlyme_my355_defconfig:70-92`; `docs/archive/NOTES.md:66` | runtime only | Zlyme's BL31-only FIT boots and resumes; stronger label needs a fresh serial capture | generic hardware truth |

Optional rows, or rows waiting on maintainer confirmation:

| Wiki file | Stale statement (line) | Zlyme evidence | Phase SHA | Replacement scope | Kind |
| --- | --- | --- | --- | --- | --- |
| WO1 `README.md`, `docs/boot-and-flash.md` | :152 and :50 "does not yet document Zlyme image names" | Zlyme README Install | runtime only | Link the Zlyme README; optional | implementation status |
| WO2 `docs/boot-and-flash/sd-multiboot-apommel.md` | :84-93 distro table without Zlyme | which preloader the accepted unit runs is inferred (LOGBOOK:1948-1950) | — | Add a Zlyme row only after the maintainer confirms; do not edit :34-41 | implementation status (waiting) |
| WO3 `spi-and-boot-chain.md` | :41-42 loader/trust version match | NAND DDR v1.18 with BL31 v1.44 and working DMC is inferred | — | Needs a serial capture of the DDR banner and `dmc_fsp` line | generic (waiting) |
| WO4 `docs/troubleshooting.md` | :65 gauge reseed after a long off | Phase 5 `OFF_CNT` data (LOGBOOK:160, :164) | `7eaecf794830` | Optional data point | generic hardware truth |
| WO5 `docs/troubleshooting.md` | :61 "archived ROCKNIX fork shipped that as patch 0007" | `0007-power-supply-rk817-clear-sys-can-sd-fix-drain.patch` | `8119387e0fdb` | Optional: Zlyme carries the same clear | implementation status |
| WO6 `docs/drivers-and-dts/drivers.md` | :117 "does not record Zlyme's GPU userspace" | gpudriver, libmali, mali-kbase | runtime only | One line on `zlyme.md` instead | implementation status |
| WO7 `troubleshooting.md`, `drivers-and-dts/display.md` | :141, :15 kernel version not recorded | Linux 7.0.2 | runtime only | Optional pointer to `zlyme.md` | implementation status |
| WO8 `board-dts-pmic-ddr-updates.md` | :188 analog `vcc_3v3` | Zlyme DTS still labels it EXPERIMENTAL (`:1268`) | runtime only | Evidence-level wording: implementation choice, no observed failure | generic hardware truth |
| WO9 `docs/DOCUMENTATION_MODEL.md` | :34 snapshot format | — | — | Optional wiki-policy note on the `zlyme.md` snapshot line | n/a |

Never claim for Zlyme: a measured standby or off-state current; validated Switch 1 replacement sticks; validated external controller models; long scripted suspend cycles or USB/Wi-Fi/BT matrices; a separate lid deep-suspend test; hardware validation of `70acb1d27443` on its own.

Before the wiki edit: fill in the Phase 10 documentation SHA, land the Zlyme-side fixes so the wiki agent quotes current text, and get the maintainer answer for WO2 and any serial captures for W15, W25, and WO3.

### Hardware-fact conflicts

- **SD slot 2 UHS (conflict; Zlyme side).** Wiki `board-dts-pmic-ddr-updates.md:140`, `:225`: SDR50 removed from slot 2 because the shared vqmmc limits UHS. Stock DTB: no UHS mode on `fe2c0000`. Zlyme DTS `&sdmmc1` `:1040-1043` enables SDR12–SDR104, and its own comment at `:1031` says "no UHS modes". A runtime change needs Flip testing (issue (j)).
- **Analog stick source in Zlyme comments.** Wiki `docs/hardware/input.md:12`: UART1, not an ADC stick. Zlyme DTS `:36` and `:998` named SARADC ch0 as the joypad source. Comment corrected (this pass).
- **`vdd_logic` comment in Zlyme DTS.** `:331` "vdd_logic stays on in this image" vs `:651` off in mem suspend, which matches the wiki and stock. Comment corrected (this pass).
- **Archived suspend driver identity.** Wiki `suspend-and-vdd-logic.md:62`, `:70` and `patch-portability.md:129-171` describe an `rk3568-suspend` node, `rk3568,pm-config`, and `late_initcall_sync`. Zlyme `deep-suspend-phase6.md:56-68`, reading the archived fork at its recorded stamp `d249b09bd9`, found `rockchip,rk3568-suspend` and `module_platform_driver()`. Both cannot describe the same file. This is historical implementation evidence, not physical hardware. Both sides agree on the stock/BSP ABI (`rockchip-suspend`, `rockchip,pm-rk3568`). Wiki-sync later (Phase 10E): the wiki agent re-reads the archive.
- **BL31 version label inside the wiki.** `spi-and-boot-chain.md:48` "ROCKNIX BL31 (rkbin v1.44)" vs `stock-firmware-and-findings.md:57` "BL31 v1.45". Zlyme uses v1.44, and all Zlyme suspend and DMC evidence is v1.44. Wiki-internal.
- Evidence gaps, no conflict: UART1 CTS stays pinned in Zlyme until the wiki has a measurement; `vdd_logic` off without `ARMOFF_LOGOFF` was never tried by Zlyme; the loader/trust match (WO3); OP-TEE (W25). `rtl8733bu.mk:10` and the wiki name different GitHub owners for the same commit `c46aa25e237c`; cite the commit. The `zlyme-radios:13-14` DMC kick comment is not a hardware fact.

## Historical references kept

These were left unchanged on purpose:

- The Phase 9 failure chain in ROADMAP, LOGBOOK, and `product-phase9.md`: the root-sized decode OOM on `7796b98ae752` before `--mmap-dict`, the `4d4b110b32ea` DNS failure during the cheat test, and the per-image acceptance records.
- `zlyme43` notes: the ROADMAP:13 caveat, ROADMAP:660, and LOGBOOK entries such as :48, :60, :288.
- Old package, file, and patch names in ROADMAP, LOGBOOK, and research: `rocknix-joypad`, `retrogame_joypad`, `flip-jackd`, `keymon.elf`, `mergerfs`, `Update.pak`, `zlyme_defconfig`, `1012a/b`, archived `1013a/b`, `9998`, `9999`, `RESEARCH-*.md`.
- Dated defaults in checkpoints: LOGBOOK:276 and `joypad-driver.md:561` (30% rumble), ROADMAP:1841 (quiet-gated splash), `product-phase9.md:320` (ROM-only BIOS rule).
- `board/my355/post-update.sh:18-23` removals of `Autocal.pak`, `Weston.pak`, `Artwork Scraper.pak`, `Cheat Downloader.pak`, `ScrapeGoat.pak`, and `.config/miyoo-serial-joypad`; `nextui-session:88`, `:377` remove `Update.pak`.
- `RUFFLE.pak` cleanup: `nextui.mk:146` and `nextui-session:378`.
- The vendored ZcrapeGoat source keeps upstream ScrapeGoat names (`package/system/zcrapegoat/src`, `src/UPSTREAM`).
- Archived ROCKNIX notes: `docs/archive/NOTES.md`, `docs/archive/PLAN.md`, `docs/MIGRATION_FROM_NOTES.md`, and the wiki's `docs/implementations/rocknix.md`.
- Research bodies under their new banners: `performance.md` and `emulators.md` recommendations that were not adopted.
- Developer LAN addresses and local paths inside LOGBOOK, research, and archive captures. They stay as capture context and must not be copied into canonical docs or the wiki.
