# Reboot into MASKROM

> Status: research, 2026-10-07. The measurements below stay as they were taken. A later implementation is not a result of this file until the maintainer sees `2207:350a` from it. Shipped boot and preloader behavior stays in [docs/ARCHITECTURE.md](../ARCHITECTURE.md) and [docs/OPERATIONS.md](../OPERATIONS.md).
>
> Later the same day, the maintainer proved `zlyme-preloader restore` on the Flip. A completed preloader erase was not USB MASKROM. The shell experiment in this file stored the flag and did not enumerate `2207:350a`. That Linux path remains a hypothesis. A later Zlyme U-Boot `rbrom` and a kernel restart command named `maskrom` copy the same store-and-reset pair. They are not results of this file until a host sees `2207:350a` from them.
>
> The evening of 2026-10-07, one serial run of `/usr/sbin/zlyme-maskrom` on root `14b2cd609ba37d66a6414627026af2da30001064429674d16aaa0def5bf97a03` logged `Restarting system with command 'maskrom'` and then the UART stayed silent. The host did not see `2207:350a`. The USB gadget was `not attached` before the request. That is not MASKROM success, and it is not a normal reboot. A one-shot scratch register for a U-Boot `rbrom` handoff was not found. The direct Linux path stays the implementation.

The question was why erasing the SPI preloader no longer ends in USB MASKROM, and how a running system can request that mode the way stock U-Boot's `rbrom` does.

## What brought the board back

The board was not reaching USB MASKROM after `zlyme-preloader erase-maskrom` and the apommel multiboot install. On 2026-10-07 serial on `/dev/ttyUSB0` stopped stock U-Boot (Ctrl-C already in the FIFO, then `=>`) and `rbrom` made the SoC enumerate as `2207:350a`. The battery was connected and the bottom USB-C was on this host. The user then wrote `spi_20241119160817.img`, applied the 20250527 card update, installed multiboot, and booted the local Zlyme OTA. That is the recovery. It used stock's `rbrom` at the stock prompt. Zlyme has no such command.

The same request from the running Zlyme shell over that serial port did not reproduce it. `devmem` stored `0xef08a53c` at `0xfdc20200` and the readback matched. `reboot -f` returned as a normal multiboot into Zlyme. A later write of `0xfdb9` to the CRU first-reset register (`0xfdd200d4`) left the UART silent, and the host never logged `2207:350a`. That was tried with the battery connected and again with it disconnected. On the second try `fcc00000.usb` was `not attached` before the reset. UART silence is what a return to the boot ROM looks like, and it is also what a reset looks like when the bottom port has no host. This session did not see the device id, so the Zlyme-shell path is not a proven MASKROM entry.

## What was measured

On 2026-10-07 the unit still booted stock U-Boot from SPI. Serial on `/dev/ttyUSB0` at 1,500,000 8N1, with Ctrl-C already in the FIFO, stopped autoboot (`<INTERRUPT>`, then `=>`). Zlyme's U-Boot is built with `CONFIG_BOOTDELAY=-2` in `board/my355/uboot/patches/uboot/001-fix-defconfig.patch`, so that abort is the stock loader, not the Zlyme one. Sending `rbrom` from that prompt made the SoC reappear as `2207:350a`. The same command had done that on 2026-10-06.

`zlyme-preloader erase-maskrom` had been run before this boot, after the apommel multiboot installer. This session did not read the NAND back. The serial capture is enough to say the SPI loader was still bootable: a blank preloader would not have reached that `=>` prompt with the card out of the way, and a Zlyme SPL would not have stopped for Ctrl-C.

The stock command was taken from the U-Boot in `spi_20241119160817.img` (partition at file offset `0x300000`) and checked again in `miyoo355_fw_20250527/unpack/uboot.img`. Both payloads are uncompressed FITs with `uboot` loaded at `0x00a00000`. In the 2024 image the handler is at `0x00a081f0`. In the 2025 image it is at `0x00a08284`. The store is the same either way:

| Step | Value |
| --- | --- |
| Address | `0xfdc20200` (`PMUGRF_OS_REG0`) |
| Stored word | `0xef08a53c` |
| Then | the normal `reset` command |

The older reboot-mode tag `0x5242c382` is not in that image. Nearby immediates are the `0x5242c300` family (`BOOT_NORMAL` is `+0`, `BOOT_LOADER` is `+1`). `rbrom` uses `0xef08a53c` only.

U-Boot 2026.01, the version in `configs/zlyme_my355_defconfig`, already has the same constant and the same register. `arch/arm/include/asm/arch-rockchip/boot_mode.h` defines `BOOT_BROM_DOWNLOAD` as `0xEF08A53C`. `arch/arm/mach-rockchip/rk3568/Kconfig` defaults `ROCKCHIP_BOOT_MODE_REG` to `0xfdc20200`. `set_back_to_bootrom_dnl_flag()` writes that pair. There is no command that calls it. The only caller in `boot_mode.c` is `rockchip_dnl_mode_check()`, which samples SARADC channel 1 for a value from 0 to 30 and then resets. The Flip's MASKROM button is not that ADC key. The kernel DTS enables `&saradc` and says it has no consumer; the sticks are on UART1.

`arch/arm/mach-rockchip/bootrom.c` in that tree states that the boot ROM does not read the register. TPL/SPL does, in `save_boot_params()`, before it changes the CPU state the ROM needs. A match returns non-zero to the ROM (`BROM_BOOT_ENTER_DNL`), which is the USB download enum we see as `2207:350a`. `setup_boot_mode()` later replaces the register with `BOOT_NORMAL`, so a flag left from the previous boot is gone by the time a prompt exists. The flag has to be stored and then the CPU reset, so the next SPL observes it.

That is why `rbrom` works with a valid SPI preloader and a card inserted, and why a button press on an already-running board does nothing. The button is a ROM strap at a true power-on. The register is an agreement with the next SPL.

## 20241119 SPI image and the 20250527 update

The unit started from the November 2024 SPI image and was then updated with the May 2025 card package. Those two trees are not the same kind of artifact.

`spi_20241119160817.img` is a full SPI NAND dump. Its U-Boot banner is `U-Boot 2017.09 (Nov 02 2024 - 15:59:04 +0800)`. `miyoo355_fw_20250527` is the official card OTA. The unpack tree has `uboot.img` (7 MiB), `boot.img`, and `rootfs.img`. Its U-Boot banner is `U-Boot 2017.09 (May 27 2025 - 21:08:28 +0800)`. The package version string is `20250527210639`. The raw `miyoo355_fw.img` is not in the tree; the comparison used `unpack/uboot.img`.

The OTA script, recorded in the hardware wiki's stock OTA note, erases and rewrites `mtd1` (U-Boot), `mtd2` (boot), and `mtd3` (rootfs). It does not write the preloader. A multiboot preloader installed before that update is still the preloader afterward. The SPL that honors `0xef08a53c` therefore stays whichever preloader was already in SPI. The 2025 package only replaces the U-Boot that contains the `rbrom` command.

That replacement still has the command. Both images abort autoboot with the string `Hit key to stop autoboot('CTRL+C')`. Both short help texts are `Perform RESET of the CPU`. The sixteen instruction bytes from `mov x0, #0x200` through `str w1, [x0]` match. The following `bl` is `reset` in both; only its target address moved. Sending `rbrom` is the same operation on a unit that has taken the 20250527 update as on the 20241119 dump.

## How serial entered MASKROM

Host port `/dev/ttyUSB0`, the FTDI `0403:6001`, at 1,500,000 8N1. The baud is set with `stty` (`raw -echo -ixon -ixoff cs8 -cstopb -parenb clocal`). The port is then opened non-blocking. `termios.B1500000` is not used; on this host it is not the 1.5 Mbaud termios value.

Stock's countdown is already 0, and the abort key is Ctrl-C, not space. The host therefore writes `0x03` continuously from before the power button until a line that is exactly `=>`. The script that did this is a copy of the wiki's `test-scripts/serialbreak.py` with the spam byte changed from space to `0x03`. It lives in `/tmp` and is not part of either tree.

On 2026-10-06 that catch stopped stock U-Boot. `rbrom` at the prompt was followed by USB id `2207:350a`. On 2026-10-07 the same catch stopped it again (`<INTERRUPT>`, then `=>`), and `rbrom` produced `2207:350a` a second time. The command echo came back on the UART; the kernel logged the Rockchip device. `reboot` and `reset` alone were not what entered download mode.

With the bottom USB-C already plugged in, stock can print `Enter U-Boot charging mode` and sit there. Ctrl-C leaves charging mode. The same byte during the display bring-up has also reset the board and restarted DDR training, so the capture has to keep running across that loop until one pass reaches `=>`.

After `rbrom` the loader is the ROM, product `350a`. `xrock flash` is a different stage and needs `xrock extra maskrom` first. A failed bulk write returns the SoC to `350a`, and the loader has to be loaded again.

## Boot captured with the cards out

2026-10-07, cards removed, both USB cables left plugged in, Ctrl-C streaming before power-on. The SPL and U-Boot banners are the November 2024 build, not the May 2025 one:

```text
U-Boot SPL 2017.09 (Nov 02 2024 - 15:59:04)
unrecognized JEDEC id bytes: ff, c8, 01
Trying to boot from MMC2
Card did not respond to voltage select!
Trying to boot from MMC1
Card did not respond to voltage select!
Trying to boot from MTD1
## Checking uboot 0x00a00000 ... sha256(6b05ca538b...) + OK
U-Boot 2017.09 (Nov 02 2024 - 15:59:04 +0800)
Model: Rockchip RK3568 Evaluation Board
Hotkey: ctrl+c
reg_boot_mode=0x00000000
rockchip_read_resource_dtb:rk-kernel.dtb
Bootdev(atags): mtd 1
[u-boot] boot mode: None
Failed to load DTB, ret=-19
Hit key to stop autoboot('CTRL+C'):  0
=> rbrom
```

The FIT check `sha256(6b05ca538b...)` is the U-Boot payload inside `spi_20241119160817.img` (`6b05ca538bffbb43…`). The 20250527 `uboot.img` payload hashes to `c629f6a6bca0d8c4…`. Whatever the May update did on an earlier day, the SPI U-Boot that ran here is the 2024 dump. The `ff, c8, 01` JEDEC line is the usual ESMT read, not a failed ID.

Both card sockets were empty (`mmc_init: -95`). The ROM was not involved; stock SPL found its FIT on MTD. `rk-kernel.dtb` did not load (`ret=-19`), so the model line stayed the FIT's RK3568 evaluation-board name. Autoboot was stopped, so this capture does not show whether the kernel would have mounted.

`rbrom` was echoed and the UART then stayed silent. A return to the loader would have printed DDR training again. Silence is what the boot ROM does. The host did not enumerate `2207:350a` after that. The FTDI adapter was on the Genesys hub (`usb 5-1.4`); the SoC's USB cable produced no new kernel USB message at all.

## Battery is not the switch

The enumeration at 16:17 (`Bus 005 Device 012`, `2207:350a`) happened with the battery connected. The battery was disconnected only at 17:02, after several `rbrom` attempts had already produced a quiet UART and no USB device. The 2026-10-06 flash used the same command with the battery installed.

At 17:03, battery disconnected and the maskrom button left alone, plugging in the bottom USB-C still printed `reg_boot_mode=0x00000000` and booted SPI U-Boot through to the `=>` prompt. `2207:350a` (`Bus 005 Device 020`, high speed on the hub) appeared when the serial listener sent `rbrom` at the end of that boot. A power-on with no battery is another way to start the SPI loader. It is not a maskrom condition. The software path is the flag write and reset, with the bottom USB-C already attached to the host so the ROM has somewhere to enumerate. Imitating a missing battery is the wrong lever.

## Why erase stopped landing in MASKROM

The ROM enters USB download when it finds no bootable medium. A Zlyme card has an idbloader at 32 KiB (sector 64). With the SPI preloader blank and that card installed, the ROM boots the card. The multiboot preloader is the other arrangement: Miyoo's SPL stays in SPI and loads the FIT from the card's `uboot` partition. Erasing it removes that SPL. It does not by itself open USB while the card's own idbloader is present.

Zlyme's U-Boot cannot be stopped from the serial key, and it has no `rbrom`. If that card SPL starts and then hangs, the screen stays dark and `lsusb` never shows `2207:350a`.

A failed `zlyme-preloader` erase is specified to write the previous preloader back and not to report MASKROM success (`docs/OPERATIONS.md`). This session did not capture the tool's exit status. The live `=>` prompt shows the SPI loader was intact afterward, whichever of those paths produced it.

## Proposed fix

Do not add this until it is requested. Two call sites, one mechanism.

U-Boot, which is the path stock already proved: a command that calls `set_back_to_bootrom_dnl_flag()` and `do_reset()`. That is `rbrom`. Putting it on `my355` matches the existing Flip command. It works with a card inserted, because the next SPL returns into the ROM instead of booting the card. `CONFIG_BOOTDELAY=-2` still means a key cannot reach the command; a boot script, a failed `bootcmd`, or Linux has to invoke it.

Linux, for Tools or a shell: write `0xef08a53c` to `0xfdc20200` and reboot without clearing that word. Linux 7.0.2's `rk356x-base.dtsi` gives `pmugrf@fdc20000` no `reboot-mode` child, so `CONFIG_SYSCON_REBOOT_MODE` has no node on this SoC dtsi and will not overwrite the register on its own. `CONFIG_DEVMEM` is enabled and `CONFIG_STRICT_DEVMEM` is off. That userspace write was tried from the running Zlyme shell, below. It stored the flag. It did not produce `2207:350a`. The SPL check above is what turns the write into `2207:350a` when the next loader honors it. If a later kernel adds a `reboot-mode` node at offset `0x200`, the value has to be a `mode-maskrom = <0xef08a53c>` property and the reboot argument has to be `maskrom`. BusyBox `reboot` does not pass that argument.

Leave the SARADC download-key scan alone. It does not describe the Flip button, and a false ADC hit would reset into download mode on every boot.

## Tried from a running Zlyme shell

2026-10-07, battery connected, multiboot installed, Zlyme from the local OTA up on serial (`zlyme login:`, root, empty password). `devmem` is present. The live tree has no `reboot-mode` node. `0xfdc20200` read back as `0x5242C300` (`BOOT_NORMAL`, the value U-Boot stores in `setup_boot_mode()`).

Writing `0xef08a53c` stuck: the next `devmem` read returned `0xEF08A53C`, and `WRITE_RC` was 0. `reboot -f` printed `reboot: Restarting system` and then a normal multiboot: stock SPL `2017.09 (Nov 02 2024)`, `Trying fit image at 0x4000 sector` on MMC2, then `U-Boot 2026.01` and Linux 7.0.2 back to the login prompt. That SPL did not return to the boot ROM. After the new boot the register was `0x5242C300` again, which only says U-Boot stored the normal flag on the way up.

A second shell line stored the flag and then wrote `0xfdb9` to `0xfdd200d4`, the CRU first-reset register U-Boot's rockchip sysreset uses. That call did not return. No new DDR log followed, which is also what a successful `rbrom` looks like on the UART, because the flag is honored before the DDR blob prints. The host did not see `2207:350a`. Hub port `usb 5-1.4` had already failed at 17:22:24 (`Cannot enable. Maybe the USB cable is bad?`) after a Linux gadget enum as `2207:0006` product `miyoo355`. The CRU write is not a proven maskrom entry until that port enumerates. Repeated at 18:47 with the battery disconnected: Zlyme was still at the login, the register went from `0x5242C300` to `0xEF08A53C`, `fcc00000.usb` was still `not attached`, and the same CRU write left the UART silent with no `2207` on the host.

## USB write after MASKROM

Separate from the reboot flag. After `rbrom`, `xrock extra maskrom` and `xrock flash` ran from `/usr/local/bin/xrock` (253176 bytes, the tree under `Extra/XROCK` with 32 KiB bulk chunks and a 10 s timeout). Flash detect succeeded (Samsung, id `53 4e 41 4e 44`, 261120 sectors). `xrock flash write 0 spi_20241119160817.img` then printed `usb bulk send error`.

The kernel log on hub port `usb 5-1.4` (Genesys `05e3:0610`) is the cause. At 16:09:53 the port failed to enable (`error -71`, "Maybe the USB cable is bad?") and power-cycled. At 16:16:46, during the write, the device disconnected and enumerated again as `2207:350a`. The loader was gone. `rock.c` prints `usb bulk send error` when `libusb_bulk_transfer` on the OUT endpoint fails, and `usb bulk recv error` on the IN endpoint. This was the OUT path. The write is capped at `sector_total`, so the image being 512 KiB larger than the reported capacity is not what aborted it.

The chunk patch was already installed. Another chunk size does not repair a port the kernel has already failed to enable. The bottom USB-C has to sit on a motherboard port for the retry, and `xrock extra maskrom` plus `xrock flash` have to be run again before `flash write`, because the failed write left the SoC in MASKROM.

## Direct Linux restart, evening of 2026-10-07

The installed root was `14b2cd609ba37d66a6414627026af2da30001064429674d16aaa0def5bf97a03`, from a fresh `zlyme.img` rather than an OTA. Source was `d05bcd39dc57156a4ecb6191d50d29d6076f08f4`. UART was `/dev/ttyUSB0` (FTDI `0403:6001`, `A50285BI`) at 1500000 8N1, on the AMD xHCI at `0000:c4:00.3`. That is not the Genesys hub that had logged USB `error -71`.

Before the request, `sha256sum /boot/zlyme` matched that root. `uname` was `Linux zlyme 7.0.2`. The command line was `earlycon quiet console=ttyS2,1500000n8`. `dmesg` had no maskrom line, which matches a probe that prints only on failure. `/sys/bus/platform/drivers/miyoo-flip-maskrom/maskrom-restart` was bound. The live node `/proc/device-tree/maskrom-restart` had `rockchip,pmugrf` phandle `0x5f` (`syscon@fdc20000`, `rockchip,rk3568-pmugrf`) and `rockchip,cru` phandle `0x10` (the CRU at `0xfdd20000`). `devmem 0xfdc20200` read `0x5242C300`. `/sys/class/udc/fcc00000.usb/state` was `not attached`.

The only device command was `sync`, then `/usr/sbin/zlyme-maskrom`. The kernel printed:

```text
[  797.416352] reboot: Restarting system with command 'maskrom'
```

Nothing after that for the rest of the capture: no `DDR`, no SPL banner, no `U-Boot 2026.01`. Host `lsusb` never showed `2207:350a`. A black screen and a silent UART are not MASKROM. The missing id also cannot prove the ROM stayed out of download mode, because the gadget was already `not attached`. Two different failures still fit the log: the CRU write did not produce a usable reset from that Linux state, or a reset did return toward the boot ROM and the USB recovery path was not viable. This capture does not choose between them.

A normal reboot on this board prints DDR. This was not that. The priority-192 handler is registered and the command reached `kernel_restart`. Linux `drivers/clk/rockchip/clk.c` `rockchip_restart_notify` already does `writel(0xfdb9, rst_base + reg_restart)` at priority 128, and `clk-rk3568.c` registers that with `RK3568_GLB_SRST_FST`. The Zlyme handler repeats that write only when the command is exactly `maskrom`. The value `0xfdb9` is the same word U-Boot uses for a cold sysreset. This run is not evidence that the constant is wrong.

The board stayed silent. No second reset, no watchdog, and no NAND command was sent. A physical reset is how it comes back. The preloader was not erased by this request.

## PMU OS registers, and why a U-Boot handoff was not added

`OS_REG0` at `0xfdc20200` is `ROCKCHIP_BOOT_MODE_REG`. SPL consumes `BOOT_BROM_DOWNLOAD` there and `setup_boot_mode()` later stores `BOOT_NORMAL`. It cannot also hold a private request that must still be present when U-Boot runs.

`OS_REG2` (`0xfdc20208`) and `OS_REG3` (`0xfdc2020c`) are the DRAM geometry words. U-Boot `sdram_rk3568.c` passes `&pmugrf->pmu_os_reg2` to `rockchip_sdram_size()`, which reads that word and the next. Linux `include/soc/rockchip/rk3568_grf.h` defines `RK3568_PMUGRF_OS_REG2` as `0x208` and `RK3568_PMUGRF_OS_REG3` as `0x20c`, and `rockchip-dfi.c` reads both. The hardware wiki records the same pair.

`OS_REG1` (`0xfdc20204`) and `OS_REG4` through `OS_REG11` (`0xfdc20210` through `0xfdc2022c`) have no reference in U-Boot 2026.01's RK3568 code, Linux 7.0.2's RK3568 headers, the Zlyme patches, the pinned apommel tree, or the RK3566/RK3568 rkbin release notes. The absolute addresses are also absent from `rk3568_bl31_v1.44.elf` and `rk3566_ddr_1056MHz_v1.23.bin`. Those binaries do not embed the PMUGRF base as a little-endian immediate either, so a base-plus-offset use would not show up in that search. Survival of a private word across the DDR blob was not measured. RK3562 release notes, a different SoC, say `OS_REG0` can be cleared by NPOR and that they moved a maskrom flag to `OS_REG8`. That is not an RK3568 allocation.

No register in this window is both unused and shown to survive an ordinary reset. A file on the boot FAT was not used: it would have to be removed before `rbrom`, or a failed entry would request MASKROM again on the next boot. The two-stage idea, a private marker plus a normal reboot plus U-Boot `rbrom`, stays undesigned until a scratch word is actually shown to be free. The Linux handler is still the only MASKROM path.
