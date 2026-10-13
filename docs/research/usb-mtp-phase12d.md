# Phase 12D USB MTP investigation

This is the investigation record for the lower-port MTP session. It is not a driver patch, and it does not say that a proposed change is correct. Shipped behavior is in `docs/ARCHITECTURE.md`. The open gate is in `docs/ROADMAP.md` section 12.

The raw directories `/tmp/zlyme-usb-testa-47oCJM`, `/tmp/zlyme-usb-testb-xZXaSr`, and `/tmp/zlyme-usb-stage0-20261012T145707Z` were not on the development machine on 2026-10-13. The hardware rows below are the maintainer-supervised session reports from 2026-10-12. They are not a fresh reading of those files.

IDs below are assigned once. Later notes add entries. They do not renumber these.

## Experiment index

| ID | When | Result | Detail |
| --- | --- | --- | --- |
| 12D-E01 | 2026-10-12 | contradicted | [original MTP, EP0 failure](#12d-e01-original-mtp-attempt) |
| 12D-E02 | 2026-10-12 | supported for the jail, untested for host writes | [exFAT and ext4 export](#12d-e02-exfat-export-and-ext4-jail) |
| 12D-E03 | 2026-10-12 | contradicted | [cable-first, older image](#12d-e03-cable-first-on-the-older-image) |
| 12D-E04 | 2026-10-12 | host-tested, not a hardware fix | [soft-connect watcher](#12d-e04-soft-connect-watcher-implementation) |
| 12D-E05 | 2026-10-12 | contradicted | [tool-first EP0 failure](#12d-e05-tool-first-enumeration) |
| 12D-E06 | 2026-10-12 | contradicted | [accepted soft-connect writes](#12d-e06-watcher-writes-accepted) |
| 12D-E07 | 2026-10-13 | source reading | [runtime PM return value](#12d-e07-runtime-pm-return-value) |
| 12D-E08 | 2026-10-13 | booted, not accepted | [7.2.10 migration](#12d-e08-linux-7210-migration) |
| 12D-E09 | 2026-10-13 | contradicted | [cable-first on 7.2.10](#12d-e09-cable-first-on-7210) |
| 12D-E10 | 2026-10-13 | contradicted | [tool-first on 7.2.10](#12d-e10-tool-first-on-7210) |
| 12D-E11 | 2026-10-13 | contradicted for these sessions | [runtime PM stayed active](#12d-e11-runtime-pm-stayed-active) |
| 12D-E12 | 2026-10-13 | supported as a separation | [RK817 charging versus PHY extcon](#12d-e12-rk817-charging-versus-phy-extcon) |
| 12D-E13 | 2026-10-13 13:17Z–13:23Z | reading, not a traced IRQ loss | [idle USB2 PHY](#12d-e13-idle-usb2-phy) |
| 12D-E14 | 2026-10-13 | source comparison | [stock firmware](#12d-e14-stock-firmware) |
| 12D-E15 | 2026-10-13 | contradicted | [speed cap](#12d-e15-speed-cap) |
| 12D-E16 | 2026-10-13 | no demonstrated mechanism | [RK817 SYS_CAN_SD](#12d-e16-rk817-sys_can_sd) |
| 12D-E17 | 2026-10-13 15:01:56Z | gadget start succeeded, enumeration did not | [active DWC3 sample](#12d-e17-active-dwc3-sample) |
| 12D-E18 | 2026-10-13 16:27Z–16:36Z | property applied, enumeration untested | [USB2 LPM property](#12d-e18-usb2-lpm-property) |
| 12D-E19 | 2026-10-13 16:55Z–17:07Z | SDP published, then the boot restarted | [PHY charger trace](#12d-e19-phy-charger-trace) |
| 12D-E20 | not run | reserved for the extcon-recovery gate | [Peripheral extcon resync](#22-peripheral-extcon-resync) |

## Experiment ledger

### 12D-E01 original MTP attempt

- When: 2026-10-12. Clock time was not recorded.
- Source: Linux 7.0.2. The installed image was older than `132b7e04fa6eb08f93ba6938f3b320a7556c2e9b`. The commit SHA was not recorded.
- Setup: lower USB-C, data cable, a Linux computer. The raw directory was already missing when section 10 was written.
- Hypothesis: plugging the cable in and starting the tool would enumerate MTP.
- Action: direct cable test on that image. No source change in the session.
- Observed: the kernel logged `failed to enable ep0out`. The host did not see a USB device.
- Result: contradicted.
- Excludes: a working enumeration on that image.
- Unknown: DWC3 `DCTL` was not read.
- Evidence: section 3, item 1.
- Code: left untouched in the session.

### 12D-E02 exFAT export and ext4 jail

- When: 2026-10-12. Clock time was not recorded.
- Source: `4103de9a45b8bec81d27e3abacab6494d33f4f8a` replaced the exFAT-only export with the ext4 jail. Host tests are `scripts/tests/test_usb_transfer.sh` and `scripts/tests/usb_transfer_confined.sh`.
- Setup: host confinement tests. The host USB controllers were not used.
- Hypothesis: an ext4 ROM or BIOS directory can be exported without unmounting the card, and a symlink cannot escape the share.
- Action: the export list became ext4 as well as exFAT and FAT. `zlyme-usb-enter` uses a private mount namespace. `open_tree` is called without `AT_RECURSIVE`.
- Observed: the host confinement test rejects a symlink and a sibling escape.
- Result: the jail behavior is supported on the host. A computer has not written the share.
- Excludes: treating the block device as the share, and the first exFAT-only limit.
- Unknown: bytes copied from a real host, because enumeration never started.
- Evidence: section 3, item 2, and the two host tests.
- Code: implemented and host-tested. Not a hardware enumeration result.

### 12D-E03 cable-first on the older image

- When: 2026-10-12, Test A. Clock time was not recorded.
- Source: the older installed image, Linux 7.0.2, before the watcher image.
- Setup: data cable already in the lower port, then the tool. Linux host.
- Hypothesis: starting the gadget while the PHY already reports SDP enumerates the device.
- Action: cable first, then USB File Transfer. No DTS or PHY change.
- Observed: lower PHY `USB=1`, `SDP=1`. Gadget `zlyme-mtp` bound. UDC `not attached`, speed `UNKNOWN`. Host saw no device. B removed the gadget.
- Result: contradicted.
- Excludes: "the cable was inserted too late" as the explanation of that session.
- Unknown: whether `DCTL.RUN_STOP` was set. That register was not read.
- Evidence: section 4, Test A. Raw logs were not retained.
- Code: left untouched.

### 12D-E04 soft-connect watcher implementation

- When: 2026-10-12, before Test B.
- Source: `132b7e04fa6eb08f93ba6938f3b320a7556c2e9b` on the phase branch. Linux 7.0.2.
- Setup: host tests of the helper. Hardware is 12D-E05 and 12D-E06.
- Hypothesis: one disconnect write and one connect write, after the gadget is ready, would replace ad-hoc `soft_connect` experiments.
- Action: `zlyme-usb-transfer` watches extcon and writes `soft_connect` only when the desired word changes, or on the failed-EP0 path. A data cable is SDP or CDP. If EP0 is not failed and the desired word is already connect, it latches connect and does not write.
- Observed: host tests passed for that sequence. The image was built and installed.
- Result: the helper behavior is host-tested. It is not a hardware fix.
- Excludes: repeating the same two writes as a new experiment.
- Unknown: whether the controller honors the accepted writes. That is 12D-E06.
- Evidence: section 3, item 4.
- Code: changed, built, installed.

### 12D-E05 tool-first enumeration

- When: 2026-10-12, Test B, the start with the cable out.
- Source: installed image `132b7e04`, Linux 7.0.2.
- Setup: tool first, no cable, then the cable was plugged in. Linux host.
- Hypothesis: binding with no cable, then connecting, enumerates.
- Action: start USB File Transfer with the cable out.
- Observed: `failed to enable ep0out`. The watcher wrote `disconnect` and that write was accepted. After the cable was plugged in, the UDC stayed `not attached` at speed `UNKNOWN`. The host saw no device.
- Result: contradicted.
- Excludes: tool-first order as a fix on that image.
- Unknown: the DWC3 register image during the failed enable.
- Evidence: section 4, Test B.
- Code: the watcher from 12D-E04 was already installed. This session did not change it.

### 12D-E06 watcher writes accepted

- When: 2026-10-12, the connect half of Test B.
- Source: same image as 12D-E05.
- Setup: after the disconnect write, the cable was attached and the watcher wrote `connect`.
- Hypothesis: an accepted `connect` write means the host will see the device.
- Action: the watcher wrote `connect` once. The write was accepted.
- Observed: UDC remained `not attached`, speed `UNKNOWN`. The host saw no device. B still removed the gadget.
- Result: contradicted. An accepted sysfs write is not enumeration.
- Excludes: "the write did not land" as the explanation of Test B.
- Unknown: the electrical line state after the write.
- Evidence: section 4, Test B.
- Code: left untouched in the session.

### 12D-E07 runtime PM return value

- When: 2026-10-13. A source reread, not a new hardware session.
- Source: Linux 7.0.2 `dwc3_gadget_pullup`, as built for that image. The later 7.2.10 tree has the same return-value test.
- Setup: none. No cable session.
- Hypothesis: `pm_runtime_get_sync` returning 0 means the device was already active, so the pull-up skip is impossible.
- Action: read `pm_runtime_get_sync` and `dwc3_gadget_pullup`. No build.
- Observed: 1 means already `RPM_ACTIVE`. 0 means the resume ran. A negative value is an error. The pull-up path skips the gadget start when the return is 0. Probe forbids autosuspend, so the normal probe path does not take that skip.
- Result: the earlier wording that 0 means already active is contradicted. The skip itself was not observed on a Flip in this reread.
- Excludes: using a 0 return as proof the device was already active.
- Unknown: a future session could still hit the skip if something enables autosuspend.
- Evidence: section 5.
- Code: left untouched.

### 12D-E08 Linux 7.2.10 migration

- When: host build 2026-10-13. The dirty OTA was installed and booted later the same day.
- Source: phase branch. The OTA filename is `zlyme-my355-20261013-0a96c787607b-dirty.tar`, SHA-256 `8c77ff9ea2f999587ffe8e46a6fa416704a08eb1da2a4b8894c82d1216b76f90`. The `-dirty` suffix is the tree state at `make-update-tar`, not a clean revision. `Image` SHA-256 `0e84cc7c6797dc76a617ef269ac2f1674eb795ab9b506e8bf7dcd445c5e4c759`. DTB SHA-256 `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18`.
- Setup: `./build.sh --config zlyme_my355_defconfig`. The Flip then ran `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 08:43:04 UTC 2026`.
- Hypothesis: moving the kernel pin to 7.2.10 might change the USB failure, or at least boot.
- Action: kernel pin moved. No USB userspace, DWC3, PHY, or board-DTS edit in that migration.
- Observed: the image booted. A maintainer smoke check reported ordinary use. MTP still did not enumerate. That smoke check is not acceptance of the rest of the image.
- Result: boot is supported for that smoke check. Enumeration is not. Phase 12D stays open.
- Excludes: treating this OTA as a clean rebuild of `8b06618`, `8eae061`, or `f6d57cb`, and treating boot as MTP acceptance.
- Unknown: a full pass of panel, audio, both card slots, gamepad, Wi-Fi, Bluetooth, Mali, DMC, suspend, and the upper USB host.
- Evidence: `linux-7.2.10-migration.md`. Section 11 names the running kernel.
- Code: kernel pin and the patches required to build it. No USB experiment in the migration itself.

### 12D-E09 cable-first on 7.2.10

- When: 2026-10-13, after the dirty image was installed. Clock time for the first cable-first pass is in section 11; the later active sample is 12D-E17.
- Source: the running dirty 7.2.10 image. Tree notes later landed at `f6d57cbfc2c0573e9300929ed50c2741f77264c6`.
- Setup: data cable already in the lower port. Host Demetria, `192.168.0.49`, Linux 7.2.9-2-cachyos-deckify. Flip SSH `192.168.0.108` over Wi-Fi. Flip clock UTC.
- Hypothesis: 7.2.10 plus an already-reported SDP would enumerate.
- Action: start USB File Transfer with SDP already 1. No register write, no replug in the first pass.
- Observed: lower PHY `USB=1`, `SDP=1`. Gadget bound. No new `failed to enable ep0out`. Watcher latched `connect` without writing `soft_connect`. UDC `not attached`, speed `UNKNOWN`. Demetria logged no USB device.
- Result: contradicted.
- Excludes: the 7.0.2 EP0-enable failure as the explanation of this cable-first pass.
- Unknown: at the time, `DCTL` during the bind. 12D-E17 later read it.
- Evidence: section 11. Host journal excerpts under `/tmp/zlyme-usb-12d-20261013/` were not all copied here; the empty journal result is in section 11.
- Code: left untouched.

### 12D-E10 tool-first on 7.2.10

- When: 2026-10-13, the tool-first pass on the same image.
- Source: same running kernel as 12D-E09.
- Setup: tool first with the cable out, then the cable was plugged back in. Same host.
- Hypothesis: the watcher disconnect, then a replug, would publish SDP and enumerate.
- Action: start with no cable. The watcher wrote disconnect after the EP0 failure. The cable was then plugged in. No `soft_connect` write by hand.
- Observed: initial `failed to enable ep0out`. After replug, RK817 was online and charging. Lower PHY extcon stayed all zero. UDC stayed `not attached`. The host saw no device.
- Result: contradicted.
- Excludes: a replug as a repair of the missed extcon update.
- Unknown: whether `utmi_bvalid` was already 1 during that replug. 12D-E13 later read it while the gadget was stopped.
- Evidence: section 11.
- Code: left untouched.

### 12D-E11 runtime PM stayed active

- When: 2026-10-13, during the 7.2.10 sessions and the idle register pass.
- Source: same running kernel.
- Setup: debugfs reads and the gadget sessions above.
- Hypothesis: runtime PM had suspended the controller and skipped the pull-up.
- Action: read runtime PM. No autosuspend change.
- Observed: the DWC3 runtime state stayed `active`. Suspended time stayed 0. `pm_runtime_get_sync` on the debugfs paths returned 1, which means already active.
- Result: contradicted for these sessions.
- Excludes: a suspended controller as the explanation of the 7.2.10 failures that were measured.
- Unknown: a later kernel or a different autosuspend setting.
- Evidence: sections 5 and 11, and the idle note in section 12.
- Code: left untouched.

### 12D-E12 RK817 charging versus PHY extcon

- When: 2026-10-13, the tool-first replug and the idle sample.
- Source: same running kernel.
- Setup: cable attached, gadget stopped or disconnected.
- Hypothesis: if RK817 is charging, the USB2 PHY extcon must also report a cable.
- Action: read RK817 `online` and the lower extcon together. No PMIC write.
- Observed: RK817 online, active type DCP, battery charging, while `fe8a0000` extcon was all zero. The upper PHY `fe8b0000` was also zero.
- Result: the two reports are separate. Charging does not imply a PHY cable notification.
- Excludes: using the charger online bit as proof that extcon ran.
- Unknown: the charger-detect sequence that would have published SDP or CDP. 12D-E13 is the register reading of that gap.
- Evidence: section 11 and section 12.
- Code: left untouched.

### 12D-E13 idle USB2 PHY

- When: 2026-10-13 13:17:19Z and 13:23:18Z.
- Source: same dirty 7.2.10 image. Notes commit after the reading is `f6d57cbfc2c0573e9300929ed50c2741f77264c6`.
- Setup: cable attached, PAK stopped, debugfs mounted read-only and then unmounted. No `soft_connect` write, no GRF write, no replug in this pass.
- Hypothesis: a high `utmi_bvalid` with a clear interrupt status means the IRQ was lost.
- Action: read DWC3 `regdump` and `usb2phy0` GRF. MTP was not started, because extcon was zero and the watcher would have written disconnect.
- Observed: GRF `0x00c0 = 0x00384e73`. `utmi_bvalid` 1, `utmi_avalid` 1. Extcon all zero. `bvalid_det_en` set, `bvalid_det_st` clear. IRQ 20 count stayed 8 across the two samples. PHY power word `0x0000 = 0x00000c00`, the power-on encoding. DWC3 was in device mode with `DCTL = 0x00f00000` (`RUN_STOP` clear) and `DALEPENA = 0`.
- Result: inconclusive as an interrupt trace. The missed-edge reading is an interpretation of this driver against this sample: the level can stay 1 after the status bit is cleared, and `B_IDLE` does not keep the work queued. It is not a trace of a lost IRQ.
- Excludes: a powered-off PHY, and a host-mode DWC3, as the description of this idle sample. It does not exclude a later start failure. 12D-E17 is that later start.
- Unknown: the workqueue history. It was not traced.
- Evidence: section 12. Copies: `docs/research/evidence/usb-mtp-phase12d/20261013T131719Z-idle-baseline.txt`, `20261013T132237Z-idle-debugfs.txt`, `20261013T132318Z-idle-regs.txt`, and the full stopped `regdump` `20261013-fcc00000-regdump.txt`.
- Code: left untouched. No build, no install.

### 12D-E14 stock firmware

- When: 2026-10-13, source comparison. No Flip session and no firmware flash.
- Source: May 2025 stock DTS from the firmware unpack, public BSP USB2 PHY `e36c7f3dc0fe` (2024-08-30) saved as `/tmp/zlyme-usb-bsp/phy-20240830.c`, and the public RK817 charger copy `/tmp/zlyme-usb-bsp/rk817_charger-bsp.c`. A generic unifreq tree at `3b916183` ("up to 5.10.160", 2022-12-21) is not that BSP: it has no `rk3568.dtsi` and no `rk3568-dwc3`.
- Setup: files on the development host. The stock gadget was not run for this note.
- Hypothesis: the stock BSP wrapper, clocks, or PHY state machine contain a repair Zlyme lacks for an awake missed edge, and stock gadget configuration proves the port enumerates.
- Action: read the decompiled DTS, the PHY resume path, and `S50usbdevice`. No Zlyme source change.
- Observed: stock `usbdrd` is `rockchip,rk3568-dwc3` plus `rockchip,rk3399-dwc3`, with `ref_clk`, `suspend_clk`, `bus_clk`, and `pipe_clk`. The child at `fcc00000` is `snps,dwc3`, `dr_mode = "otg"`, `maximum-speed = "high-speed"`, `phy_type = "utmi_wide"`, and `snps,dis_enblslpm_quirk`. The vendor PHY reschedules the OTG state machine on resume if `utmi_bvalid` is already 1. That path is resume-only. It does not scan again while the system is already awake. `S50usbdevice` calls `/usr/bin/usbdevice`, which has UMS, MTP, and ADB hooks. `adbd` is in the unpack. `mtp-server` is not. No host enumeration of stock was captured.
- Result: gadget configuration is present. Hardware enumeration on stock is unproven. The vendor resume rescan is not an awake-state repair.
- Excludes: importing `dwc3-of-simple` on the grounds that the Zlyme core is dead. The core answers register reads. It also excludes treating unifreq 5.10.160 as the Rockchip BSP.
- Unknown: whether a stock unit enumerates on this cable and host.
- Evidence: section 13. Excerpt: `docs/research/evidence/usb-mtp-phase12d/stock-may2025-excerpt.txt`.
- Code: left untouched.

### 12D-E15 speed cap

- When: 2026-10-13. Static check plus the stopped regdump. No new image.
- Source: `rk3566-base.dtsi` in the 7.2.10 tree, the board DTS, and the running `/proc/device-tree`. Tree `f6d57cbfc2c0573e9300929ed50c2741f77264c6`.
- Setup: the booted dirty image. Debugfs read-only. No DTS edit.
- Hypothesis: the lower controller is missing `maximum-speed = "high-speed"`, so DWC3 programs SuperSpeed and never enumerates on a USB2 port.
- Action: decompile the effective DTB and read `GSNPSID`, `GHWPARAMS3`, `GUCTL1`, and `DCFG`. No build and no OTA.
- Observed: `&usb_host0_xhci` inherits `maximum-speed = "high-speed"` from `rk3566-base.dtsi`. The board fragment does not repeat it. The running DTB has the property on `usb@fcc00000`. `GSNPSID = 0x5533300a` is DWC3 3.00a. `GHWPARAMS3 = 0x08290085`. `GUCTL1 = 0x8504018a` already has bit 26 set. `DCFG = 0x008e0800` already selects high-speed.
- Result: contradicted. The missing speed cap is not the cause.
- Excludes: another speed-cap experiment, and a DTS edit whose only change is that property.
- Unknown: nothing further about this property on the current DTB. Enumeration remains unexplained.
- Evidence: section 14 and `20261013-fcc00000-regdump.txt`.
- Code: left untouched. No experimental build.

### 12D-E16 RK817 SYS_CAN_SD

- When: 2026-10-13. Source and register comparison. No PMIC write.
- Source: Zlyme `0007` on Linux 7.2.10, public BSP `rk817_charger.c` as fetched for the stock investigation, May 2025 DTS, historical stock dump `0xe6 = 0x42`. Tree `f6d57cbfc2c0573e9300929ed50c2741f77264c6`.
- Setup: the running Flip stayed up and kept charging during 12D-E17. This entry did not change the PMIC.
- Hypothesis: clearing `SYS_CAN_SD` breaks VBUS detection, BC1.2, DWC3, or the gadget.
- Action: read `0007` and the public driver. Do not remove the patch and do not set the bit.
- Observed: `0007` clears only bit 7 of `0xe6`, from `rk817_battery_init`, once during charger probe. It does not write `USB_SYS_EN` (bit 6), the PHY, or DWC3. Nothing in the USB path calls it. The May 2025 charger node sets `gate_function_disable = <1>`. Public BSP code since `8238cd4ec173` (2021-01-28) skips `rk817_charge_sys_can_sd_disable()` when that field is nonzero, so that public driver plus this DTS does not clear the bit. Stock runtime still shows bit 7 clear. A power-on reset reads `0xc5`, with bit 7 set, and the stock SPL and U-Boot do not clear it. No userspace writer of `0xe6` was identified. The shipped instruction that left bit 7 clear is unknown.
- Result: no demonstrated software mechanism. The patch stays. It was not removed in an A/B test, so this is not an experimental elimination.
- Excludes: a claim that the public driver and the May 2025 DTS together must clear the bit. It does not exclude an untested electrical interaction.
- Unknown: the exact stock write path.
- Evidence: section 15. Dated notes in `kernel-patch-audit.md` and `kernel-patch-audit-phase5.md`.
- Code: left untouched. `0007` remains.

### 12D-E17 active DWC3 sample

- When: 2026-10-13 15:01:56 UTC. Uptime 9310. A pre-start read at 14:55 UTC already had SDP.
- Source: same dirty 7.2.10 image. No source change. Tree still `f6d57cbfc2c0573e9300929ed50c2741f77264c6`.
- Setup: cable already attached, SDP=1, no replug. Host Demetria. The helper was started over SSH and the shell was held open so the reaper would not tear the gadget down. Stop was `zlyme-usb-transfer stop`, the function the PAK B path calls. The panel button was not pressed.
- Hypothesis: with SDP present, the gadget never reaches `RUN_STOP` or never enables EP0.
- Action: one normal start of USB File Transfer. Read registers. Do not write `soft_connect`, GRF, or the PMIC.
- Observed: device mode. `GUCTL1 = 0x8504018a`. `GUSB2PHYCFG(0) = 0x40101508`. `DCTL = 0x80f00000` with `RUN_STOP` set. `DSTS = 0x008e0001`, not halted, link-state field 3. `DALEPENA = 0x00000003`. Both EP0 directions read `control`. PHY VBUS-valid stayed 1. UDC stayed `not attached`, speed `UNKNOWN`. The watcher latched `connect` and did not write `soft_connect`. The host kernel journal had no USB connection. The saved `lsusb` poll ended at 15:01:44Z, about twelve seconds before this sample, so that poll does not cover it. The empty journal does. B-equivalent stop removed the gadget and the responder.
- Result: a universal gadget-start failure is contradicted. USB attachment, negotiation, and enumeration did not happen. A link-state field of 3 is the high-speed Suspend encoding in the 7.2.10 gadget strings. It is not evidence of an established high-speed connection while the host sees no device and the UDC speed is `UNKNOWN`.
- Excludes: "the gadget never starts" as the explanation of every session. It does not exclude a link that never leaves Suspend.
- Unknown: whether clearing `GUSB2PHYCFG.ENBLSLPM` changes that link state. That property is untested.
- Evidence: section 16. Transcription: `docs/research/evidence/usb-mtp-phase12d/20261013T150156Z-active-session.txt`. The raw SSH stdout was not saved. Host poll: `20261013T150134Z-host-lsusb-poll.txt`.
- Code: left untouched. No build and no install.

The first start in that hour is not this sample. Its SSH shell exited, the reaper removed the gadget, and no register line from inside that window was kept.

### 12D-E18 USB2 LPM property

- When: 2026-10-13 16:27:44Z through 16:36:43Z. Demetria monitors ran from 16:30:27Z through 16:38:03Z and covered both replugs.
- Source: clean OTA `zlyme-my355-20261013-4bd0b1ecec72.tar`, SHA-256 `22655eba69186e0241c775d6c8edc5eec8fddb797fd3b4ae002b9d30d0861637`. DTS commit `4bd0b1ecec728aa1e58f091c0aa3f266f80b9c27`. Notes tree `f0c63b8c1bf55ef641dff9b483334c2d5adfb911`. Kernel `Linux zlyme 7.2.10 #2 SMP PREEMPT Tue Oct 13 16:08:35 UTC 2026`. `os-release` still says `zlyme44.2 (2026-10-13)`. `HW_DEVICE` is `miyoo-flip`.
- Setup: lower USB-C, cable already attached, USB File Transfer stopped, NextUI running. Host monitors started before the cable moved. The maintainer unplugged and replugged that cable twice. No `soft_connect` write, no GRF write, no PMIC write, no second quirk.
- Hypothesis: clearing `GUSB2PHYCFG.ENBLSLPM` lets Demetria enumerate the gadget when the lower PHY already reports SDP or CDP.
- Action: confirm the booted DTB and the stopped regdump. Start MTP only if SDP or CDP is present. It was not, so the PAK stayed stopped.
- Observed: `usb@fcc00000` has `snps,dis_enblslpm_quirk`, `maximum-speed = "high-speed"`, and `dr_mode = "otg"`. Mode is device. UDC `fcc00000.usb` exists and reads `not attached`. Stopped `GUSB2PHYCFG(0) = 0x40101408`. Bit 8 is 0. XOR against 12D-E17's `0x40101508` is `0x100`. Before the replug the lower PHY reported DCP and GRF `0x0000` was `0x00000dd1`. After both replugs every lower extcon cable was 0, `utmi_bvalid` stayed 1, `0x0000` was `0x00000c00`, IRQ 20 had moved from 0 to 6 and then stayed, and `bvalid_det_st` was clear. RK817 stayed online with `usb_type` DCP. The host journal, udev monitor, and `lsusb` poll have no `1d6b:0100`.
- Result: the property reached the register. Enumeration was not tested. The LPM hypothesis is neither supported nor contradicted.
- Excludes: a missing property, or bit 8 still set, as the description of this boot.
- Unknown: `DCTL` and `DSTS` while this property is active, and any host result from a session that already has SDP or CDP.
- Evidence: section 20.
- Code: the section 19 DTS line stayed. No second property and no new build.

### 12D-E19 PHY charger trace

- When: 2026-10-13 16:55:53Z through 17:07:52Z. The trace that published SDP ended when the Flip rebooted at about 17:00:49Z.
- Source: the same installed OTA as 12D-E18, `zlyme-my355-20261013-4bd0b1ecec72.tar`. Same kernel `#2`. Notes tree `8f04a8637c8ff663a5f3a3f4d99c54f396b043d0` at the start. No DTS edit and no new image.
- Setup: USB File Transfer stopped. Dynamic debug enabled only for `rockchip_usb2phy_otg_sm_work` and `rockchip_chg_detect_work`. One unplug/replug. Host monitors ran before that replug. The gadget was not started while SDP was present.
- Hypothesis: the lower PHY stays at zero extcon because charger detection is not scheduled, or because a finished detection does not publish.
- Action: read the 7.2.10 state machine, enable those two functions' existing `dev_dbg` lines, and record one cable cycle. No GRF write, no PMIC write, no second quirk.
- Observed: before the replug the worker was already in `b_peripheral`, every 2 seconds, with VBUS still valid and every extcon cable 0. The replug logged `usb disconnect`, then charger states 0, 1, 2, and 5, then `sdp cable is connected` and `charger = USB_SDP_CHARGER`. Extcon became USB=1, SDP=1. RK817 stayed DCP. The helper was still stopped, and Demetria saw no gadget. The Flip then rebooted. On the new boot the PHY reported DCP, the PAK start wrote watcher `disconnect`, and `ep0out` enable failed. `GUSB2PHYCFG(0)` was still `0x40101408`. `DCTL` `RUN_STOP` was 0.
- Result: detection can publish SDP when it is allowed to start from `USB_CHG_STATE_UNDEFINED`. A `b_peripheral` worker does not do that by itself. Enumeration was not tested. The LPM property is still neither supported nor contradicted.
- Excludes: "the worker is not scheduled" as the description of the pre-replug idle, and the six-retry DCD timeout as the classification of this replug.
- Unknown: which SDP or CDP branch first entered `b_peripheral` before debug was enabled. The restart was read later and is still unexplained. Section 22 has that read and the source change that followed.
- Evidence: section 21. The later boot read is `20261013T173112Z-e19-reboot-read.txt`.
- Code: left untouched during this session. Dynamic debug returned to off when the machine rebooted.

### 12D-E20 Peripheral extcon resync

- When: not run. The source change and the development OTA are section 22. This row is the hardware gate, and it stays open until that OTA is installed and the two gates are recorded.
- Source: the corrected patch `1015`, commit `dd0d717f331f`. OTA `zlyme-my355-20261013-dd0d717f331f.tar`, not installed. The earlier tar `zlyme-my355-20261013-07de7365fda6.tar` is superseded and is not the test image.
- Hypothesis: a finished SDP or CDP session that is already in `B_PERIPHERAL` with empty extcon will publish again from the existing worker, without a new BC1.2 pass. A later, separate question is whether that published session enumerates.
- Action: none on the Flip yet.
- Observed: nothing on hardware.
- Result: not run. Do not treat the build as this result.
- Evidence: section 22.


## 1. Hardware topology

Miyoo Flip, `my355`, RK3566. The board DTS comments and the built DTB agree on this map:

| Address | Node | Role |
| --- | --- | --- |
| `fcc00000` | `usb_host0_xhci` | Lower USB-C, charge and gadget. `dr_mode = "otg"`. PHY `usb2phy0_otg`. Extcon `usb2phy0`. `maximum-speed = "high-speed"`. No `phy-supply`. |
| `fe8a0000` | `usb2phy0` | Lower PHY block. The OTG port has no VBUS regulator. The host port's supply is `vcc_3v3` and that port is not a connector. |
| `fd800000` / `fd840000` | EHCI / OHCI | Upper USB-C host on `usb2phy1_otg`, VBUS `vcc5v0_host`. |
| `usb2phy1_host` | Wi-Fi PHY | RTL8733BU. The board file's supply is experimental `vcc_3v3`. The comment says stock used 5 V. |
| `fd000000` | `usb_host1_xhci` | USB2 host on `usb2phy0_host`. No external connector. |

Status 2026-10-13: `maximum-speed = "high-speed"` on `fcc00000` is inherited from `rk3566-base.dtsi`. The board fragment does not repeat it. The running DTB still has it. That check is 12D-E15.

Linux 7.0.2 binds `snps,dwc3` directly on `usb@fcc00000`. There is no Rockchip DWC3 glue child. `dwc3-of-simple` does not match RK3568. Probe calls `pm_runtime_forbid()` and does not call `pm_runtime_allow()` on the success path, so runtime suspend stays forbidden and `power/control` stays `on`.

Charging is the RK817 path. The PHY extcon and the RK817 `usb_type` string are different reporters. SDP and CDP are data-capable. DCP is not.

## 2. Baseline

| Item | Value |
| --- | --- |
| Branch | `zlyme44.3-phase-12` |
| Watcher commit | `132b7e04fa6eb08f93ba6938f3b320a7556c2e9b` (2026-10-12) |
| Installed root SHA-256 | `a32ef7214837e90cebdc95f906c704ca873872fa3917832705fecaef7fc64f87` |
| Kernel | 7.0.2, not rebuilt for the watcher |
| Responder | uMTP-Responder 1.8.1, no Zlyme patch |
| Identity | `1d6b:0100`, serial `zlyme`, high-speed, self-powered |
| Userspace | `zlyme-usb-transfer`, `zlyme-usb-enter` |

`os-release` on that image still says `zlyme44.2`.

## 3. Experiments, in order

1. **2026-10-12, direct cable, older image.** The host saw incomplete high-speed connects and no descriptor. The Flip logged `dwc3 fcc00000.usb: failed to enable ep0out`. The PHY reported SDP. The UDC stayed `not attached`, speed `UNKNOWN`.
2. **Same day, exFAT-only MTP, then the ext4 jail.** Host tests passed. No enumeration claim was made. The ext4 jail superseded the earlier "ext4 is not shared" implementation. See `4103de9a45b8bec81d27e3abacab6494d33f4f8a`.
3. **Test A, cable first, older installed image.** Reported below. The helper on that image had no soft-connect watcher.
4. **`132b7e04`, session watcher.** Host-tested. A product image was built and then installed for Test B. The watcher writes `disconnect` or `connect` to `soft_connect`. A successful write is not a controller state change.
5. **Test B, tool first, watcher image.** Reported below. Enumeration failed.
6. **2026-10-13, source reread.** The earlier report treated `pm_runtime_get_sync() == 0` as "already active". That reading is wrong. Section 5 replaces it. No driver patch was applied.

## 4. Test A and Test B

Both tests are hardware-exercised and not hardware-accepted. Neither enumerated. No ext4 file was written. MENU+START was not repeated on the watcher image. B cleanup was checked on both.

### Test A — cable already attached

Maintainer report, 2026-10-12, about 23:01–23:04 UTC. Image root SHA-256 `4e7b97590170b7bf8761352e308ac33608e3fd102d0503175b7fdb491e28147d`.

Observed:

- PHY SDP, charger online, USB-HOST 0, CDP 0, DCP 0.
- Gadget bound, FunctionFS mounted, responder running, four exports, id `1d6b:0100`.
- No `fcc00000` line in that boot's dmesg. "read descriptors" and "read strings" are the responder writing FunctionFS, not the host reading a device descriptor.
- UDC `not attached`, speed `UNKNOWN`.
- Host kernel journal empty, no `1d6b:0100`.
- After B: gadget absent, FunctionFS unmounted, responder gone.

### Test B — tool first, then the cable

Same date, image root SHA-256 `a32ef7214837e90cebdc95f906c704ca873872fa3917832705fecaef7fc64f87`.

Observed:

- Bind with no cable logged `failed to enable ep0out`.
- The watcher wrote `disconnect` once. `link.err` stayed empty.
- Cable insertion: PHY SDP. The watcher wrote `connect` once. Both sysfs writes were accepted.
- No second `failed to enable ep0out` after that connect.
- UDC stayed `not attached`, speed `UNKNOWN`. The host saw no device.
- Teardown logged `request … was not queued to ep0out`. That line is not the enable failure. See section 5.
- After B: gadget absent, FunctionFS unmounted, watcher and reaper gone, NextUI still running. The panel was not inspected.

A sysfs write that returns success only means the kernel accepted the string. Test B did not show `DCTL.RUNSTOP`, `pullups_connected`, or a resume. Those fields are not in sysfs. Debugfs was not mounted.

## 5. Runtime PM, corrected

Linux 7.0.2 `rpm_resume()` in `drivers/base/power/runtime.c` sets the return value to 1 when `runtime_status` is already `RPM_ACTIVE`. A resume whose callback runs leaves the value at 0 when the callback succeeds. Negative values are errors. `pm_runtime_get_sync()` returns that result and still increments the usage count on failure. The same convention is stated in the 13 November 2023 runtime-PM discussion: [openwall linux-kernel/2023/11/13/867](https://lists.openwall.net/linux-kernel/2023/11/13/867).

`dwc3_gadget_pullup()` in 7.0.2 `drivers/usb/dwc3/gadget.c`:

1. Stores `softconnect`.
2. On disconnect, if the device is already runtime-suspended, returns 0 and does not resume.
3. Calls `pm_runtime_get_sync()`.
4. If the result is 0 or negative, drops the usage count and returns. The comment says a successful resume already ran the controller, so this function must not do it again. Result 0 is that successful resume. It is not "already active".
5. Result 1 means already active. The function does not return there. It continues.
6. If `pullups_connected` already equals the requested state, it returns 0.
7. Otherwise it calls `dwc3_gadget_soft_connect()` or soft-disconnect.

`dwc3_gadget_soft_connect()` calls `__dwc3_gadget_start()` and ignores the return value, then `dwc3_gadget_run_stop(dwc, true)`. `run_stop` sets `pullups_connected = true` when starting, including after a failed endpoint enable. The ignored return is an error-propagation defect. It is not, by itself, the reason the first enable failed.

`__dwc3_gadget_start()` enables EP0 IN and then EP0 OUT. The log `failed to enable ep0out` is that second enable failing.

Runtime resume does not always start the gadget:

- `DWC3_GCTL_PRTCAP_DEVICE`: `dwc3_resume_common()` calls `dwc3_gadget_resume()`, which calls soft-connect when a driver is bound and `softconnect` is set.
- `DWC3_GCTL_PRTCAP_OTG` and `PMSG_IS_AUTO`: resume returns immediately. The comment is "nothing to do on runtime_resume". System suspend of an OTG device role is a different path and does call gadget suspend/resume.

The lower port is OTG, and probe forbids autosuspend. A `get_sync` on that steady state returns 1, already active, and `pullup` continues. The result-0 skip is the path that assumes resume started the controller. On this OTG port an autosuspend resume does not start it. That assumption is false for OTG. Test B's first bind did enter soft-connect, because EP0 enable was logged, so that call was not the result-0 skip. The missing second enable is explained if `pullups_connected` was already true after the ignored failure. It is also explained if a later `get_sync` returned 0 and the skip ran. The session did not record which return value occurred. A sample taken after cleanup showed `runtime_status=active` and `control=on`, which fits return value 1, and that sample was not taken during the connect write.

Linux 7.2.10 still has the same `if (!ret || ret < 0)` skip, still ignores `__dwc3_gadget_start()`, and still does nothing in the OTG autosuspend resume. It adds a mutex around the soft-connect call. That does not change the return-value rule.

### The teardown line

`dwc3_gadget_ep_dequeue()` logs `request %p was not queued to %s` when the request is not on the cancelled, pending, or started list. A request that has already completed is no longer on those lists, so a later dequeue logs this line. The August 2026 note on that message says a completed-request dequeue can produce it: [linux-kernel/2608.2/02325](https://lkml.indiana.edu/hypermail/linux/kernel/2608.2/02325.html). Test B's teardown line is that dequeue message. It does not show that EP0 setup failed. The setup failure is the earlier `failed to enable ep0out`.

## 6. Candidate mechanisms

Each row has evidence for it and evidence against it. None is a patch.

| Mechanism | Supports | Conflicts |
| --- | --- | --- |
| Ignored `__dwc3_gadget_start()` leaves `pullups_connected` true, so a later connect does not try again | Test B logged one enable error and no second one. `run_stop` sets the flag before it knows the enable result. The return value is ignored in 7.0.2 and in 7.2.10. | Test A logged no enable error and still did not enumerate. The ignored return does not explain a start that did not fail that way. |
| `get_sync` returns 0, `pullup` skips, and OTG resume did not start the gadget | The skip is exactly the 0 result. OTG autosuspend resume does not call `dwc3_gadget_resume()`. | The first Test B bind did run soft-connect, so that call was not this skip. Probe forbids runtime suspend, and the after-cleanup sample was active. The 0 result was not measured. |
| PHY powered off when the first EP0 command runs | Test B's enable error happened with no cable. The inno-usb2 OTG state machine calls `rockchip_usb2phy_power_off()` with no VBUS, on DCP, and when peripheral mode loses VBUS. | Test A already had SDP, so `power_on` had returned, and there was still no host device and no new EP0 error. Test B's connect was written after SDP was already reported. PHY-on was not sufficient. |
| `dr_mode = "peripheral"` plus an always-on PHY, as in the July 2026 ODROID-M1S RFC | The RFC author reported the same EP0 symptom. Peripheral mode would make DWC3 use the device resume path, which does call gadget resume. | The RFC author also said peripheral mode alone still failed. The PHY change skips power-off only when the PHY port's mode is peripheral, so it does nothing for the current OTG node. The maintainer objected to an always-on PHY. Zlyme's OTG port has no VBUS supply to delete. Test A conflicts with "PHY on is enough". |
| Repeat the ROCKNIX `soft_connect` trigger | ROCKNIX documents the same EP0 line and writes disconnect/connect from extcon. | Zlyme already did that inside the session. Test B accepted both writes and did not enumerate. |

FunctionFS was mounted and the gadget was bound in both tests. That is userspace reaching the UDC. It is not evidence that userspace caused the link failure, and it is not enumeration.

## 7. Upstream

- **ODROID-M1S RFC**, 7 July 2026, Andreas Zdziarstek, [patchew cover](https://patchew.org/linux/20260706223627.113814-1-andreas.zdziarstek@gmail.com/). Two patches: the PHY skips `power_off` when `rport->mode == USB_DR_MODE_PERIPHERAL`, and the M1S DTS sets `dr_mode = "peripheral"` and removes that port's VBUS supply. Manivannan Sadhasivam's objection is the idle power of an always-on PHY, and he asked whether `power_on` runs on cable connect before DWC3 drives the bus. The series is not in Linux 7.2.10. The Flip must not copy the M1S regulator change. The OTG port already has no `phy-supply`.
- **Rockchip DWC3 glue v16**, Sebastian Reichel, 24 September 2026, [patch 6/6](https://lists.openwall.net/linux-kernel/2026/09/24/2462). Message id `20260924-b4-rockchip-dwc3-rockchip-glue-v16-6-126a2e9133c3@collabora.com`. It adds `usb_udc_vbus_handler()` calls inside `drivers/usb/dwc3/dwc3-rockchip.c` so a glue-managed gadget is told about VBUS after a USB-C unplug left the controller suspended. Linux 7.2.10 has no `dwc3-rockchip.c` and no `USB_DWC3_ROCKCHIP`. The Flip binds `snps,dwc3` directly. That series is not a driver the current DTS probes.
- **ROCKNIX `usbgadget`**, branch `next` at `53829e2bfadb4cefa23f6bf8b8fe1acc90b9f61f` (2026-10-13). Blob `3fced643c647f5a9f09faa43ad914c37b19ef9e8`. GPL-2.0. The trigger writes `soft_connect` from the PHY extcon. Zlyme did not install the script. The session watcher is the same sequence and Test B failed. Do not copy the script again.

## 8. Isolated diagnostics, not authorized here

Status 2026-10-13: the list below was written before the image was booted. Sections 11 and 12 are the later hardware record. They do not authorize the three image changes in this list.

No new hardware test was run for this document. Status 2026-10-13: sections 11 through 16 are later readings. The three image changes in the list below were not combined. A later test should change one variable:

1. A kernel-only image, same DTS and same userspace, if the 7.2.10 migration is built. Expectation: the pull-up bug above is still present. The run is a baseline, not an MTP fix.
2. Only after that baseline, a separate `dr_mode = "peripheral"` image, still without a PHY always-on patch, so the device-role resume path can be compared with Test B.
3. A local DWC3 change, such as propagating the `__dwc3_gadget_start()` error and not setting `pullups_connected` on that failure, only with a power analysis and a rollback. It does not explain Test A.

Do not combine those three in one image.

## 9. Acceptance

Phase 12D is open. Enumeration is not hardware-accepted. File transfer is not hardware-accepted. Cleanup with B was hardware-exercised and passed on the two images above. The watcher is implemented and host-tested. It is not a fix.

## 10. Logs

Not re-read. The directories named at the top of this file were absent on 2026-10-13.

The 2026-10-13 Flip sessions were copied to `/tmp/zlyme-usb-12d-20261013/` on the development host. That tree is not in the repository. The numbers in sections 11 and 12 were taken from those files.

## 11. Linux 7.2.10 sessions, 2026-10-13

The installed kernel was `7.2.10 #1 SMP PREEMPT Tue Oct 13 08:43:04 UTC 2026`. `os-release` was `zlyme44.2 (2026-10-13)`. Git HEAD of the source tree was `8eae061a3941c84bf2e11929809146522de6765d`. The running image is the dirty OTA from the migration build, not a rebuild of that commit. SSH was Wi-Fi from Demetria (`192.168.0.49`) to the Flip (`192.168.0.108`). Demetria's kernel log was `journalctl -k`. Its `dmesg` was not permitted for the user account.

`fcc00000.usb` is the lower port, driver `dwc3`, device-tree `dr_mode` `otg`, PHY `phy-fe8a0000.usb2phy.3`. Extcon `fe8a0000.usb2phy` is that PHY. `fe8b0000.usb2phy` stayed all zero. No gadget was bound at the idle readings. Debugfs was not mounted until the register pass in section 12.

### Cable already attached

The lower PHY reported `USB=1` and `SDP=1`. RK817 was `online=1`, active type `DCP`, and the battery was `Discharging`. The PAK bound `zlyme-mtp` to `fcc00000.usb`. FunctionFS was ready and `umtprd` was running. The screen said MTP is on and `USB: not attached`. That second line is `/sys/class/udc/fcc00000.usb/state`.

This start did not log `failed to enable ep0out`. The watcher latched `connect` and did not create `link.writes`. With debugfs absent it treats a missing EP0 error as unknown, and the unknown-plus-SDP path records `connect` without writing `soft_connect`. The UDC stayed `not attached`, speed `UNKNOWN`. Demetria logged no USB event. `lsusb` did not change.

B removed the gadget, FunctionFS, `umtprd`, and the watcher. `nextui.elf` stayed up. A dead `reaper.pid` file was left behind. An earlier session on the same boot, before these monitors, did log one `failed to enable ep0out` plus a SETUP timeout. Another earlier session logged descriptors and no EP0 enable error. Both of those also ended without a Demetria USB log line. The cable's host during those two earlier sessions was not identified separately.

### Tool first, then the cable

With the cable out, both PHY extcons were zero and RK817 `online` was 0. Starting the PAK logged `failed to enable ep0out` at uptime 2038.626s. The watcher wrote one word, `disconnect`, and latched `disconnect`. There was no SETUP timeout after that line. The UDC stayed `not attached`.

After the cable was plugged back into the lower port, RK817 `online` became 1, the active type stayed `DCP`, and the battery became `Charging`. From 13:02:18Z through 13:05:42Z both PHY extcons stayed all zero. The watcher did not write `connect`. No second EP0 enable error appeared. Demetria still logged nothing.

B cleanup matched the first session: gadget and FunctionFS gone, responder and watcher gone, NextUI up, dead `reaper.pid` left behind. After that stop, with the cable still in, the lower PHY was still all zero and RK817 was still online. The same boot also logged `udc fcc00000.usb: UDC had already stopped` beside the last dequeue. In Linux 7.2.10 that line is `usb_gadget_udc_stop_locked()` seeing `udc->started` already clear. It is a second stop, not an EP0 enable failure.

Runtime PM of `fcc00000.usb` stayed `active`, `control=on`, `runtime_suspended_time=0` across these sessions. That does not record the `pm_runtime_get_sync()` return inside `dwc3_gadget_pullup()`.

## 12. Idle DWC3 and USB2PHY GRF, 2026-10-13 13:23Z

The PAK was stopped. The cable was still in. RK817 was `online=1`, active type `DCP`, battery `Charging` at capacity 99. Lower extcon was all zero. UDC state was `not attached`, speed `UNKNOWN`, no function. `fcc00000.usb` runtime PM was still `active` with suspended time 0. The PHY device's runtime PM was `unsupported`.

`CONFIG_DEBUG_FS=y` in the built 7.2.10 config. Debugfs was mounted read-only at `/tmp/zlyme-dbgfs-12d` for this read and then unmounted. No other debugfs mount existed. `mode`, `link_state`, and `testmode` were not written. No GRF write, `devmem`, or `soft_connect` write was made.

The live device tree phandle in `usb2phy@fe8a0000/rockchip,usbgrf` matched `syscon@fdca0000` (`0xb1`). `syscon@fdca8000` was `0xb2` and was not read. The regmap directory was `dummy-syscon@0x00000000fdca0000`. Offsets below are in that map, which is the `grf` pointer used by `rk3568_phy_cfgs` for `0xfe8a0000`. `property_enabled()` is true when the field is not equal to the config's disable value.

| Register | Raw | Reading |
| --- | --- | --- |
| `GCTL` | `0x30c12004` | Bits 13:12 are 2, `DWC3_GCTL_PRTCAP_DEVICE`. The `mode` file read `device`. The device tree `dr_mode` is still `otg`. |
| `GSTS` | `0x7e800000` | Bits 1:0 are 0, `DWC3_GSTS_CURMOD_DEVICE`. Defined status bits 10:4 were clear. |
| `DCTL` | `0x00f00000` | Bit 31 `RUN_STOP` is 0. Bits 23:20 are the NYET threshold, value `0xf`. The gadget was stopped, so a clear Run/Stop bit is the stopped state. |
| `DSTS` | `0x00d20001` | `DEVCTRLHLT` and `COREIDLE` set. Link field bits 21:18 equal 4, `DWC3_LINK_STATE_SS_DIS`. The `link_state` file read `Disconnected`. Bits 2:0 equal 1, the full-speed encoding, while the link field is disconnected. |
| `GUSB2PHYCFG(0)` | `0x40101508` | `PHYSOFTRST` clear, `SUSPHY` clear, `U2_FREECLK_EXISTS` set. Ports 1–15 read 0. |
| `DALEPENA` | `0x00000000` | No endpoint enable bits. |
| `GEVNTCOUNT(0)` | `0x00000000` | One read. It is not an event history. |
| EP0 `transfer_type` | `--` | `dwc3_transfer_type_show()` prints `--` when `DWC3_EP_ENABLED` is clear or the endpoint has no descriptor. |

`regdump` is a sequence of reads, not one atomic sample. Runtime PM was `active` before and after the `mode` and `link_state` reads. Those reads call `pm_runtime_resume_and_get()` and `pm_runtime_put_sync()`. Suspended time stayed 0.

Lower PHY GRF `0x00c0` read `0x00384e73`. Bit 9, `utmi_bvalid`, was 1. Bit 10, `utmi_avalid`, was 1. Bit 6, `utmi_id`, was 1. The id config's disable value is 0, so `property_enabled()` on that bit is true, and the id path publishes USB-HOST as the inverse. Charger-detect bits 25, 24, and 23 (`dp_det`, `cp_det`, `dcp_det`) were 0. The driver turns those sources off after detection, so zeros outside that sequence do not name a charger type.

`0x0080` read `0x0000003e`. Bits 3:2 are 3, the enable value of `bvalid_det_en`. `0x0084` read `0x000003c1`. Bits 3:2 are 0, so `bvalid_det_st` was not pending. `0x0000` read `0x00000c00`. Bits 8:0 are 0. `power_on()` writes 0 to that field and `power_off()` writes `0x1d1`. This word matches the power-on encoding. It does not record which call ran last. `clk_usbphy0_ref` was enabled at 24 MHz. The host-port word at `0x0004` was `0x000001d2`, which is both the enable and disable value for that port, so it does not say whether the host port is suspended.

`/proc/interrupts` line 20 is GICv3 167, `rockchip_usb2phy`. Device tree `usb2phy0` uses SPI 135, which is hwirq 167. Its count was 8 at 13:17Z and still 8 at 13:23Z. Line 21 is hwirq 168, `usb2phy1`, count 1. No `dwc3` interrupt was listed while the gadget was stopped.

### What this sample supports

`utmi_bvalid` was 1 and the lower extcon was all zero, with bvalid-detect enabled and its status bit clear. The PHY's VBUS-valid bit was set. The extcon notification was not. `rockchip_usb2phy_otg_sm_work()` reads `utmi_bvalid` for `vbus_attach`. It sets `EXTCON_USB` only for SDP, and only together with the SDP cable. CDP sets the CDP cable and moves to peripheral. DCP sets the DCP cable and calls `power_off()`. A falling `vbus_attach` clears charger state and, when `vbus_attached` changes, updates extcon. After that, `B_IDLE` does not keep the work queued. The next entry is the bvalid IRQ, which runs the state machine only when `bvalid_det_st` is set and then clears that status. A high `utmi_bvalid` with a clear status bit and an idle workqueue is the missed-edge case: the level can stay 1 without another notification. That is a reading of this driver against this sample. It is not a trace of the workqueue.

`DCTL.RUN_STOP` clear, `DEVCTRLHLT` set, and `DALEPENA` clear describe a stopped gadget. They do not show that a later start fails. No MTP session was started in this register pass, because extcon was zero and the watcher would write `disconnect` on that state. There is still no sample of Run/Stop during a cable-first bind on 7.2.10.

Status 2026-10-13 15:01:56 UTC: 12D-E17 is that sample. This paragraph stays the stopped-gadget reading.

The host still had no connect in the earlier 7.2.10 sessions, including the one where extcon already said SDP. This idle sample does not explain that session. It explains the silent replug: VBUS is visible to the PHY bit and to RK817, and the PHY extcon is not updated.

Phase 12D remains open. Enumeration is not accepted. The maintainer smoke check is not acceptance of the rest of the image.

## 13. Stock firmware USB comparison

12D-E14. No Zlyme source change and no stock boot for this note.

The May 2025 decompiled DTS is `miyoo355_20250527_0.dts` in the firmware unpack. The lower controller is a wrapper, `usbdrd`, compatible `rockchip,rk3568-dwc3` and `rockchip,rk3399-dwc3`, clocks `ref_clk`, `suspend_clk`, `bus_clk`, and `pipe_clk`. The child `dwc3@fcc00000` is `snps,dwc3`, `dr_mode = "otg"`, one `usb2-phy`, `phy_type = "utmi_wide"`, `maximum-speed = "high-speed"`, and `snps,dis_enblslpm_quirk`. It also sets several other Synopsys properties. Zlyme binds `rockchip,rk3568-dwc3` and `snps,dwc3` on the same address with `ref`, `suspend`, and `bus` clocks and `SRST_USB3OTG0`. The core is alive on 7.2.10, so the missing wrapper is not justified by a dead controller. `pipe_clk` is the extra stock clock. The speed cap is how stock stops the core from needing the USB3 clock, and 12D-E15 already found that cap in effect on Zlyme.

A generic unifreq tree, commit `3b916183`, described as "up to 5.10.160" and dated 2022-12-21, is not this BSP. That tree has no `rk3568.dtsi` and no `rk3568-dwc3`. The PHY comparison used the public BSP file at commit `e36c7f3dc0fe` (2024-08-30), the last PHY commit before the May 2025 firmware date, saved as `/tmp/zlyme-usb-bsp/phy-20240830.c`. On resume, if `utmi_bvalid` is already 1, that driver schedules the OTG state machine. It does not schedule that work while the system is already awake and the edge has been consumed. Zlyme's 7.2.10 PHY does not have that resume rescan. Neither driver polls an idle port after a falling edge.

`S50usbdevice` calls `/usr/bin/usbdevice`. That script has UMS, MTP, and ADB hooks, and it starts `/usr/bin/adbd` and `/usr/bin/mtp-server`. The unpack contains `adbd`. It does not contain `mtp-server`. No session in this investigation captured a host enumerating a stock Flip. Stock gadget configuration is present. Stock enumeration is unproven.

The bounded excerpt is `docs/research/evidence/usb-mtp-phase12d/stock-may2025-excerpt.txt`.

## 14. Speed cap, closed

12D-E15. The board file `rk3566-miyoo-flip.dts` does not set `maximum-speed` on `&usb_host0_xhci`. `rk3566-base.dtsi` does, and the built DTB includes it on `usb@fcc00000`. The running `/proc/device-tree/usb@fcc00000/maximum-speed` is `high-speed`.

From the stopped regdump, which matches the 13:23Z selected lines:

- `GSNPSID = 0x5533300a`, DWC3 3.00a, so the 2.90a-and-later `GUCTL1` path applies
- `GHWPARAMS3 = 0x08290085`
- `GUCTL1 = 0x8504018a`, bit 26 already set
- `DCFG = 0x008e0800`, high-speed device speed
- `DCTL = 0x00f00000`, `RUN_STOP` clear, because the gadget was stopped

No DTS edit, no experimental build, and no OTA came out of this check. The property is already in the effective hardware configuration. A missing speed cap is not the cause. Do not repeat the experiment.

The full dump is `docs/research/evidence/usb-mtp-phase12d/20261013-fcc00000-regdump.txt`.

## 15. RK817 SYS_CAN_SD and MTP

12D-E16. `0007` stays.

The patch adds `RK817_SYS_CAN_SD` as bit 7 of `RK817_PMIC_CHRG_TERM` (`0xe6`) and clears that bit with `regmap_write_bits` inside `rk817_battery_init`. Probe calls that init once. Cable plug does not. `USB_SYS_EN` is bit 6 of the same register. The patch does not write it. A power-on value of `0xc5` already has bit 6 set. Charger current and voltage limits are other registers. The charger driver reads the PMIC plug status. It does not subscribe to the USB2 PHY extcon, and the PHY and DWC3 do not call the clear.

The May 2025 charger node sets `gate_function_disable = <1>`. In the public BSP driver, `rk817_charge_pre_init` calls `rk817_charge_sys_can_sd_disable()` only when that field is zero. Commit `8238cd4ec173` (2021-01-28, "fix shutdown invalid by long press key") is the change that added the condition. The commit's reason is shutdown when the GATE pin does not control an external PMOS, not a USB data fix. With Miyoo's property set, that public function skips the clear. A missing property still clears the bit, because the platform data is zeroed. The historical stock dump `0xe6 = 0x42` has bit 7 clear and bit 6 set. A true power-on reset reads `0xc5`. The stock SPL and U-Boot do not clear the bit, and it is battery-backed. The investigation did not find a userspace writer of `0xe6`. The instruction in the firmware that was actually shipped, which left bit 7 clear, is unknown.

Do not describe the public driver plus the May 2025 DTS as a path that must clear the bit. Do not describe 12D-E16 as an A/B removal of `0007`. The patch remains the off-current fix. There is no demonstrated dependency on MTP.

## 16. Active DWC3 sample, 2026-10-13 15:01:56 UTC

12D-E17. At 14:55 UTC the lower PHY was already `USB=1`, `SDP=1`. RK817 was online. IRQ 20 was 10. The UDC was `not attached`. No replug was done.

The sample that counts is the second start, with the SSH shell held open. While that shell held the session:

| Item | Value |
| --- | --- |
| Extcon | `USB=1`, `SDP=1`, `CDP=0` |
| Helper | `state=bound`, `gadget=zlyme-mtp`, responder running, `host=not attached` |
| UDC | `not attached`, function `zlyme-mtp`, speed `UNKNOWN` |
| `GUCTL1` | `0x8504018a`, bit 26 set |
| `GUSB2PHYCFG(0)` | `0x40101508` |
| `DCTL` | `0x80f00000`, `RUN_STOP` set |
| `DSTS` | `0x008e0001`, not halted, link-state field 3 |
| `DALEPENA` | `0x00000003` |
| EP0 | `control` in both directions |
| GRF `0x00c0` | `0x00384e51`, VBUS-valid bits still 1 |
| IRQ 20 | still 10 |
| Watcher | `link.latch=connect`, no `link.writes` file |

`DSTS` link-state field 3 is what `dwc3_gadget_hs_link_string()` calls Suspend. The connect-speed field is 1. The host journal covering 15:01:56Z has no USB device. UDC speed stayed `UNKNOWN`. Those three facts together are a controller that has started and has not been configured by a host. They are not a completed attachment.

The saved `lsusb` poll, `20261013T150134Z-host-lsusb-poll.txt`, runs from 15:01:34Z to 15:01:44Z and then stops. It does not cover this sample. The transcription of the register values is `20261013T150156Z-active-session.txt`. The raw SSH stdout was not saved.

Stop removed the gadget and the responder. Source, the PMIC patch, and the bootloader were not changed.

Status 2026-10-13: section 12's sentence that there was still no Run/Stop sample during a cable-first bind is the idle reading. This section is that sample.

## 17. Hypothesis register

| Hypothesis | Evidence supporting | Evidence contradicting | Status | Reopen only if |
| --- | --- | --- | --- | --- |
| Missing `maximum-speed` | The board fragment does not repeat the property, which looked like an omission | Effective DTB and live `DCFG` / `GUCTL1` already select high-speed. 12D-E15 | Contradicted by the running configuration | A later DTB drops the property |
| Wrong DWC3 host/device role | `dr_mode` is `otg` in source | Live mode is device on `fcc00000`. Stock is also `otg`. 12D-E13, 12D-E17 | Contradicted for the measured sessions | A sample shows host mode on `fcc00000` during MTP |
| Repeated soft-connect trigger | Writes in 12D-E06 were accepted | The same disconnect-then-connect sequence did not enumerate | Contradicted as a sufficient fix | A trigger that is not the current watcher |
| RK817 `SYS_CAN_SD` interferes with the gadget | `0007` clears the bit; stock runtime is also clear | No call path into PHY, DWC3, or the gadget. The Flip stayed up and kept SDP in 12D-E17 | No demonstrated mechanism. Patch retained. Not an A/B removal | A measured coupling, or a test that actually removes `0007` |
| Gadget start / EP0 fails in every session | 12D-E01 and 12D-E05 logged `failed to enable ep0out` | 12D-E17 had `RUN_STOP` set and both EP0 directions enabled | Contradicted as a universal explanation | A new SDP session fails before `RUN_STOP` |
| USB2 PHY power-down | A powered-off PHY would not detect VBUS | 12D-E13 matched the power-on encoding. 12D-E18's zero-extcon sample also read `0x00000c00`. The DCP latch earlier in that session was `0x00000dd1`, the DCP `power_off` path | Contradicted for the zero-extcon samples | A zero-extcon sample whose power word stays at the off encoding |
| Runtime-PM pull-up skip | `dwc3_gadget_pullup` skips the start when `pm_runtime_get_sync` returns 0 | Probe forbids autosuspend. Measured returns were 1 and suspended time stayed 0. 12D-E07, 12D-E11 | Contradicted for the measured sessions | A session whose get-sync return is 0 or negative during pull-up |
| Awake BVALID / extcon loss after reconnect | 12D-E10, 12D-E13, and 12D-E18 left extcon at zero with `utmi_bvalid` 1. 12D-E19 found the worker already in `b_peripheral`, logging every 2 seconds, and not publishing | 12D-E19's observed disconnect ran detection from state 0 and published SDP. Cable-first SDP sessions still failed to enumerate. 12D-E09, 12D-E17 | The stuck loop is measured. Patch `1015` republishes a finished SDP or CDP cable from that loop. The OTA is built and not installed. Enumeration after a real SDP window is still open | 12D-E20, after that OTA is installed |
| DWC3 USB2 LPM (`snps,dis_enblslpm_quirk`) | Stock sets the property. 12D-E17 had bit 8 set and sat in Suspend with no host | 12D-E18 and the 12D-E19 reboot both read `GUSB2PHYCFG(0) = 0x40101408`. SDP was published in 12D-E19 while the gadget stayed stopped | Property applied. Enumeration untested | A gadget start during a stable SDP or CDP window on this image |
| Rockchip BSP wrapper and clock differences | Stock has `pipe_clk` and the `dwc3` wrapper. Zlyme does not | The core programs registers and reached `RUN_STOP`. 12D-E14, 12D-E17 | Recorded difference. Not shown to be the cause | A clock or reset the core cannot program without that wrapper |

## 18. Next-experiment queue

Phase 12D stays open. Enumeration is not accepted. Do not repeat the speed-cap edit, an RK817 bit toggle, or the current soft-connect watcher unchanged.

1. `snps,dis_enblslpm_quirk` on `&usb_host0_xhci` only. 12D-E18 measured the register change. Enumeration was not scored. The DTS line stays as built. Do not add a second quirk from that session.
   - Preconditions: the pre-boot gate. The property was absent on `fcc00000`, live `GUSB2PHYCFG(0)` bit 8 was set, and 7.2.10 `dwc3_phy_setup()` clears that bit when the property is set. No other quirk, role, speed, PHY, or RK817 change was in that build. The booted tree now has the property.
   - Observable: `GUSB2PHYCFG(0)` bit 8 becomes 0. The prediction from `0x40101508` is `0x40101408`. 12D-E18 measured that value. `GUCTL1`, the speed cap, and the device role stayed as they were. The success line still requires SDP or CDP.
   - Success: with SDP or CDP already reported, the host enumerates and one small file round trip matches. Failure: bit 8 is clear and the host still sees no device. If extcon is not SDP or CDP, that is the replug problem below, not a result about this bit.
   - Safety: one DTS property on the lower controller. The upper port is the EHCI/OHCI host on `usb2phy1`, not this node. Rollback is deleting the property and rebuilding that configuration. Do not add another quirk in the same test.
2. Republish a finished SDP or CDP extcon from `B_PERIPHERAL`. The source change is section 22. 12D-E20 is the hardware gate and has not been run. Another schedule of `rockchip_usb2phy_otg_sm_work()` is not the repair: 12D-E19 already saw that work every 2 seconds. Rerunning BC1.2 is not the repair either. The vendor resume-only rescan is not this repair.
   - Preconditions: 12D-E19. VBUS valid, worker in `b_peripheral`, extcon all zero, no charger restart.
   - Single variable against the installed 12D-E18 image: patch `1015` only. The DTB is byte-identical. `snps,dis_enblslpm_quirk` stays.
   - Observable: `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER` without a new `chg detection work` sequence, then the matching sysfs cable. A fresh detection that logs `sdp cable is connected` does not pass this gate.
   - Success is two separate results. Gate 1 is that restore. Gate 2, only after SDP or CDP is actually present, is host enumeration with the gadget running. Failure of Gate 1 is extcon staying zero. Failure of Gate 2 is SDP or CDP present, the gadget running, and the host still seeing nothing.
   - Safety: do not write GRF from userspace. Do not touch `0007`. Do not start the gadget on DCP.
3. `snps,dis-u2-freeclk-exists-quirk`. Priority: only after an SDP or CDP session on the 12D-E18 image still fails to enumerate. Not attempted. 12D-E18 cleared bit 8 and did not reach that session. Stock sets the property. Stopped bit 30 was still 1. It is a different variable.

Hardware test after item 1 is installed, and only then:

1. Confirm the installed kernel and the effective DTB.
2. Confirm `GUSB2PHYCFG.ENBLSLPM` is 0.
3. Confirm the speed cap, the device role, and `GUCTL1` are unchanged.
4. Confirm the lower PHY reports SDP or CDP before starting MTP.
5. Start one USB File Transfer session with the cable already attached.
6. Capture `DCTL`, `DSTS`, `DALEPENA`, EP0, UDC state, and the watcher.
7. Keep the host `journalctl -k` and USB monitoring running across that whole active interval.
8. Check host enumeration and descriptors.
9. If that succeeds, copy one small file and compare it.
10. Check B cleanup, RK817 charging, the upper USB host, and suspend/resume.

If extcon does not report SDP or CDP, record a PHY resynchronization failure and do not attribute it to the LPM property. If bit 8 clears and the host still sees nothing, record item 1 as unsuccessful and do not add another quirk in that test.

Status 2026-10-13 16:36Z: 12D-E18 completed steps 1 through 3. Step 4 stopped the test. Steps 5 through 10 did not run. The record is section 20.

## 19. ENBLSLPM source change

12D-E18, in the ledger and in section 20, is the hardware session for this DTB. The rest of this section is the pre-boot static check and the build.

Static check on 2026-10-13, tree `9a972906bec72f52189bb1a1d4445652f86e4279`, before this DTS edit:

- `output/images/rk3566-miyoo-flip.dtb` decompiled to `usb@fcc00000` with `snps,dis_u2_susphy_quirk` and `maximum-speed = "high-speed"`. `snps,dis_enblslpm_quirk` was absent. The string does not appear in that blob.
- The stopped regdump has `GUSB2PHYCFG(0) = 0x40101508`. Bit 8, `ENBLSLPM`, is 1. Bit 6, `SUSPHY`, is 0. Bit 30, `U2_FREECLK_EXISTS`, is 1. The active sample in 12D-E17 read the same word.
- Linux 7.2.10 `dwc3_get_properties()` reads `snps,dis_enblslpm_quirk`. `dwc3_phy_setup()` clears `DWC3_GUSB2PHYCFG_ENBLSLPM`, which is `BIT(8)`, when the flag is set, and sets it otherwise.
- No file under `board/my355/linux/patches` mentions the property. `rk3566-base.dtsi` does not set it.
- The upper port is EHCI/OHCI at `fd800000` / `fd840000` on `usb2phy1`. This edit is only `&usb_host0_xhci`. `usb@fd000000` is not edited.

`dwc3_gadget_run_stop()` clears bit 8 for the start or stop sequence and then writes the saved bits back. If `dwc3_phy_setup()` already cleared the bit, the saved value is clear and the restore leaves it clear. The host-role suspend path can set the bit, and the matching resume path clears it again when the quirk is set. MTP on this port uses device role.

The board file now has the one property. The predicted steady value is `GUSB2PHYCFG(0) = 0x40101408`. That prediction is not a measurement. No other Synopsys property, role, speed cap, PHY policy, or RK817 change is in this edit.

Build on 2026-10-13, from commit `4bd0b1ecec728aa1e58f091c0aa3f266f80b9c27`, tree clean (`git describe --always --dirty --abbrev=12` printed `4bd0b1ecec72`). `linux-rebuild` copied the board DTS and compiled `rk3566-miyoo-flip.dtb`. The decompiled `usb@fcc00000` node has `snps,dis_enblslpm_quirk` once, and still has `dr_mode = "otg"`, `maximum-speed = "high-speed"`, and `snps,dis_u2_susphy_quirk`. `usb@fd000000` does not have the new property. The first full `./build.sh --config zlyme_my355_defconfig` stopped in `post-build.sh` with make error 141. The retry completed. The OTA member `rk3566-miyoo-flip.dtb` matches the image DTB byte for byte.

| Artifact | SHA-256 |
| --- | --- |
| `output/images/rk3566-miyoo-flip.dtb` | `cbb249cd244b32595c29d3df61cd968b7cd6e0533085072549f78b14280eefed` |
| `output/images/Image` | `dfed9426f78e63aa1cb7ebe9c5b8847cdfd23d8d55a9a37080a10cb34f2375da` |
| `output/images/Image.gz` | `67745dd7d61b17f7b554b24878b77a45ac7727f0e49a91b8754359fd08821e74` |
| `output/images/zlyme` | `8ba39f24921be6ef27f01508fd0126929d5c1b9177cebe84b5ac094ac8efea3d` |
| `output/images/zlyme-my355-20261013-4bd0b1ecec72.tar` | `22655eba69186e0241c775d6c8edc5eec8fddb797fd3b4ae002b9d30d0861637` |

`VERSION` in the tar is `4bd0b1ecec72` and `20261013`. The kernel string in `Image` is `Linux version 7.2.10 #2 SMP PREEMPT Tue Oct 13 16:08:35 UTC 2026`. That is a relink from `linux-rebuild`, not a second USB source change. The image build also refreshed `rk3568-dmc` because its stored source fingerprint did not match the tree. That package was not edited.

The previous record, written before install, was that this OTA had not been booted and that enumeration was not claimed.

Status 2026-10-13 16:36Z: the Flip booted this OTA. Stopped `GUSB2PHYCFG(0)` read `0x40101408`. SDP and CDP did not appear, so MTP was not started. Enumeration is not claimed. Phase 12D stays open.

## 20. USB2 LPM session, 2026-10-13 16:27 UTC

12D-E18. The installed artifact is `output/images/zlyme-my355-20261013-4bd0b1ecec72.tar`. Its SHA-256 is `22655eba69186e0241c775d6c8edc5eec8fddb797fd3b4ae002b9d30d0861637`, checked again on Demetria before this note. The booted kernel is `Linux zlyme 7.2.10 #2 SMP PREEMPT Tue Oct 13 16:08:35 UTC 2026 aarch64`. Product text in `os-release` is still `zlyme44.2 (2026-10-13)`. That string does not identify the kernel.

The Flip clock is UTC. Demetria is UTC+2. Host `journalctl --since` values below are local. SSH to the Flip answered.

### Preconditions

At 16:35:57Z `/proc/device-tree/usb@fcc00000` had `compatible` `rockchip,rk3568-dwc3 snps,dwc3`, `dr_mode` `otg`, `maximum-speed` `high-speed`, and both `snps,dis_enblslpm_quirk` and `snps,dis_u2_susphy_quirk` present as empty properties. `/sys/class/udc/fcc00000.usb` existed. `zlyme-usb-transfer status` was `state=off`. NextUI's pid stayed 502. Debugfs was not left mounted. No `dwc3` or `fcc00000` line appeared in that boot's dmesg. The phy-supply lines around 0.9s and 1.2s are probe lookups.

The cable was already in the lower port. USB File Transfer stayed stopped for the whole session. Demetria's kernel follow, `udevadm monitor --kernel --subsystem-match=usb`, and a two-second `lsusb` poll started at 16:30:27Z, before either replug, and ran until 16:38:03Z.

### Idle registers, gadget stopped

16:27:44Z. Private debugfs, read-only, unmounted in the same command. That file has no uptime line. The following extcon sample, 16:29:58Z, is uptime 399. Full dump `20261013T162744Z-e18-fcc00000-regdump.txt` is 8201 bytes.

| Register | Value | Reading |
| --- | --- | --- |
| `GSNPSID` | `0x5533300a` | DWC3 3.00a, same as 12D-E15 |
| `GHWPARAMS3` | `0x08290085` | Same as 12D-E15 |
| `GUCTL1` | `0x8504018a` | Bit 26 remains 1 |
| `GUSB2PHYCFG(0)` | `0x40101408` | Bit 8 is 0. Bit 6, `SUSPHY`, is 0. Bit 30, `U2_FREECLK_EXISTS`, is 1 |
| `GCTL` | `0x30c12004` | Device role |
| `GSTS` | `0x7e800000` | Device role |
| `DCFG` | `0x00080804` | Bits 2:0 are 4, the SuperSpeed encoding, while the gadget has not started |
| `DCTL` | `0x00f00000` | `RUN_STOP` is 0 |
| `DSTS` | `0x00d29f64` | Halted, core idle, link field 4 (`SS_DIS`) |
| `DALEPENA` | `0x00000000` | EP0 disabled |
| `GEVNTCOUNT(0)` | `0x00000000` | No pending event |

`DCFG` on the stopped 12D-E15 dump was `0x008e0800`, high-speed. That boot had already run gadget sessions. This boot had not. `dwc3_gadget_set_speed()` writes `DWC3_DCFG_HIGHSPEED` when the gadget starts. The live `maximum-speed` property is still `high-speed`. The halted SuperSpeed encoding is not a measurement of the speed cap.

Lower PHY GRF at the same sample, `dummy-syscon@0x00000000fdca0000`:

| Offset | Value | Reading |
| --- | --- | --- |
| `0x0000` | `0x00000dd1` | Bits 8:0 are `0x1d1`, the `power_off` encoding |
| `0x0080` | `0x0000003e` | `bvalid_det_en` set |
| `0x0084` | `0x000003c1` | `bvalid_det_st` clear |
| `0x00c0` | `0x003846c0` | `utmi_bvalid` 1, `utmi_avalid` 1, `utmi_id` 1. Charger-detect bits 25:23 are 0 |

Lower extcon at 16:29:58Z, still before the replug: USB 0, USB-HOST 0, SDP 0, CDP 0, DCP 1. RK817 `online` 1, `usb_type` `Unknown [DCP]`, battery charging. IRQ 20 count 0 since boot. UDC `not attached`. Upper extcon was not read in that sample. The DCP cable plus `0x1d1` matches the PHY path that publishes DCP and calls `power_off()`. That is a finished DCP classification, not an all-zero missed edge.

### Replug

The maintainer unplugged and replugged the lower-port cable twice while the host monitors were running and the PAK stayed stopped.

At 16:32:49Z, uptime 570s, both PHYs reported every cable 0. RK817 stayed `online` 1, type USB, `usb_type` `Unknown [DCP]`, battery `Charging`. UDC `not attached`. Helper `state=off`. IRQ 20 was 6. IRQ 21 stayed 1.

At 16:33:43Z the GRF read:

| Offset | Value | Reading |
| --- | --- | --- |
| `0x0000` | `0x00000c00` | Bits 8:0 are 0, the `power_on` encoding |
| `0x0080` | `0x0000003e` | `bvalid_det_en` still set |
| `0x0084` | `0x000003c1` | `bvalid_det_st` still clear |
| `0x00c0` | `0x00384e73` | `utmi_bvalid` 1, `utmi_avalid` 1, `utmi_id` 1. Same word as the 12D-E13 idle sample |

Extcon was still all zero. IRQ 20 was still 6. Debugfs was unmounted at the end of that command.

At 16:36:06Z extcon was still all zero, IRQ 20 still 6, helper still `state=off`, UDC still `not attached`, NextUI still pid 502. Battery status read `Discharging`. At 16:36:43Z capacity was 100, charger `online` was still 1, and `usb_type` was still DCP. The earlier 16:32Z sample at the same online bit had read `Charging`. A full battery reading `Discharging` while the charger stays online is not a lost RK817 plug report.

### Host

From 16:30:28Z through 16:37:58Z every poll line is `no-gadget-id`. The kernel follow from 16:30:27Z to 16:38:03Z printed nothing. A one-shot `journalctl -k --since "2026-10-13 18:29:00"` at 16:34:11Z reported no entries. `udevadm monitor` printed its banner and no event. The 16:31:23Z `lsusb` tree contains Demetria's hubs, AX210, Xbox pad, fingerprint reader, keyboard, mouse, and card readers. Root hubs are `1d6b:0002` and `1d6b:0003`. `1d6b:0100` is absent. No descriptor was read. No MTP client was opened. No file was written.

That is no host USB connection event across the replugs. The Flip still had VBUS: `utmi_bvalid` 1 and RK817 online. Those are different observations.

### What did not run

MTP did not start. There is no active `DCTL`, `DSTS`, `DALEPENA`, EP0, UDC speed, or watcher sample on this kernel. There is no file round trip. Cleanup of a gadget did not apply, because no gadget was bound. The upper USB host was not exercised. Suspend and resume were not run. `SYS_CAN_SD` was not touched.

### Conclusion

`snps,dis_enblslpm_quirk` is in the booted tree and bit 8 is clear. The question this property was meant to answer, enumeration while SDP or CDP is valid, did not get a session. Two replugs moved the PHY from a DCP / power-off latch to the power-on, VBUS-valid, extcon-zero state, with the bvalid IRQ consumed. That is the open reconnect gap. It is not a failed LPM result and it is not a successful one.

The next change to design, and not to apply in this note, is one that reruns charger detection when `utmi_bvalid` is already 1 and extcon is all zero. `snps,dis-u2-freeclk-exists-quirk` stays off that change. Bit 30 was still 1, and this session never reached the SDP failure that would rank it. The separate 12D-E17 result, SDP already present and `RUN_STOP` set with no host device, also stays open. This image has not repeated it.

Status 2026-10-13 17:07Z: 12D-E19 found that worker already running in `b_peripheral`. Scheduling it again does not start charger detection. The trace is section 21.

## 21. PHY charger trace, 2026-10-13 16:55 UTC

12D-E19. Same installed image as section 20. No source change. The Flip clock is UTC. Demetria is UTC+2.

### What the 7.2.10 driver does

Linux 7.2.10 `drivers/phy/rockchip/phy-rockchip-inno-usb2.c`. These are source facts. The measurements are below them.

`rockchip_usb2phy_otg_sm_work()` is scheduled from `rockchip_usb2phy_init()` at `OTG_SCHEDULE_DELAY * 3`, from the USB-HOST extcon notifier at `OTG_SCHEDULE_DELAY`, and by itself when `sch_work` is set. `OTG_SCHEDULE_DELAY` is `2 * HZ`. `rockchip_usb2phy_bvalid_irq()` and the charger worker's `USB_CHG_STATE_DETECTED` case call it directly instead of scheduling it. The bvalid handler has no `dev_dbg` line. `rockchip_usb2phy_irq()` is the shared handler for the PHY's ports, so IRQ 20's count is not one sub-event.

Charger detection is scheduled from `B_IDLE` only when VBUS is present and `chg_state` is `USB_CHG_STATE_UNDEFINED`. Other charger states in that switch do not start it. `B_PERIPHERAL` never starts it. While VBUS stays present, `B_PERIPHERAL` sets `sch_work` and returns. The only assignments of `OTG_STATE_B_PERIPHERAL` are the SDP branch and the CDP branch.

Extcon is written only when `rport->vbus_attached` changes and `notify_charger` is set. A charger state that is neither `UNDEFINED` nor `DETECTED` leaves `notify_charger` clear, and that path can still store the new VBUS level. The next `DETECTED` pass then sees the cached level already equal to the pin and skips the extcon write. `B_PERIPHERAL` does not write extcon at all. A function-static `cable` remembers the last type so a later falling edge can clear that cable. It is not a second extcon state.

DCD polls every 100 ms, at most 6 times. One `WAIT_FOR_DCD` pass means contact was seen. Six passes are the timeout. After that, primary detection with `cp_det` clear and a full retry count selects DCP. The same primary result with fewer retries selects SDP. Primary `cp_det` set goes to secondary detection, which selects DCP or CDP from `dcp_det`. The debug lines print the state number and the final charger string. They do not print `dp_det`, `cp_det`, or `dcd_retries`.

State numbers: 0 undefined, 1 waiting for DCD, 2 DCD done, 3 primary done, 4 secondary done, 5 detected.

### Dynamic debug

`/proc/dynamic_debug/control` existed. 5087 lines. `CONFIG_DYNAMIC_DEBUG`, `CONFIG_DYNAMIC_DEBUG_CORE`, and `CONFIG_DEBUG_FS` are set in the built `.config`. `CONFIG_FTRACE` and `CONFIG_KPROBES` are not. No kernel rebuild.

Every `dev_dbg` in the two functions was `=_` before the test. `rockchip_usb2phy_bvalid_irq` has no control-file line. The ten lines were switched to `=p` at 16:55:53Z. Nothing else in that file was enabled for this test. The reboot put those ten lines back to `=_`. That was checked on the new boot.

### Idle, before the replug

16:56:30Z, uptime 1992. Same boot as 12D-E18: IRQ 20 still 6, extcon all zero, GRF `0x0000 = 0x00000c00`, `0x00c0 = 0x00384e73`, RK817 online and `usb_type` DCP, helper `state=off`, UDC `not attached`.

From 1957.197 seconds the only new kernel line was `b_peripheral otg sm work`, about every 2 seconds. There was no `usb disconnect`, no `vbus_attach`, and no charger line. In this driver that means the worker was in `B_PERIPHERAL` and `utmi_bvalid` was still true. That state does not start detection and does not publish a cable. Extcon stayed all zero through 16:58:59Z. The absence of a new IRQ did not mean the worker was idle.

`B_PERIPHERAL` is entered only from the SDP branch or the CDP branch. Debug was turned on after the worker was already there, so this trace does not contain the earlier `sdp cable is connected` or `cdp cable is connected` line. The state and the zero extcon are measurements. Which of those two branches ran, and whether `vbus_attached` was already true when it ran, was not printed.

### One replug

IRQ 20 moved from 6 to 7 in the 16:59:00Z sample. RK817 `online` was 0. GRF `0x0000` was `0x00000dd1`. `0x00c0` was `0x003840c8`, so `utmi_bvalid` was 0. The kernel log at 2141.696 seconds is `b_peripheral otg sm work` and, 50 microseconds later, `usb disconnect`. That pair is one worker invocation. It was about one second after the previous 2-second tick, not on that tick.

A `b_idle` line at 2142.665 seconds has no `vbus_attach` line with it. The next `b_idle` line, at 2146.286 seconds, is followed in the same microsecond burst by `vbus_attach`, charger state 0, then state 1 about 106 ms later, state 2 about 44 ms after that, and state 5 immediately. Then `sdp cable is connected` and `charger = USB_SDP_CHARGER`. One state-1 line is not the six-retry DCD timeout. The separate state-5 invocation matches the source path that schedules another pass when primary detection does not see `cp_det`, and that path selects SDP when the retry count is below the maximum. The log does not show the detect bits themselves.

The 16:59:05Z poll is the first sample with USB=1 and SDP=1. IRQ 20 was 8. `0x0000` was `0x00000c00`. `0x00c0` was `0x00384e73`. RK817 was online again and its `usb_type` was still DCP. PHY SDP and RK817 DCP were true at the same time. The helper stayed `state=off`. UDC stayed `not attached`. SDP was still 1 at 17:00:45Z, the last complete poll before the SSH session dropped.

Demetria's kernel journal and `lsusb` poll covered this window. No `1d6b:0100` appeared. The gadget was stopped, so that empty host log is not a DWC3 enumeration result.

### Reboot, then the PAK

The 17:03:57Z SSH read uptime 188. The boot was about 17:00:49Z, four seconds after the last SDP poll. The new buffer starts at `Booting Linux`. It does not contain the previous boot's oops or panic. The cause of the restart was not captured. Dynamic debug was off again. IRQ 20's count was 0.

The maintainer opened USB File Transfer on that boot. At 17:04:33Z the helper was `state=bound`, the responder was running, and the screen later said MTP was on. Extcon was DCP=1, not SDP. `link.latch` and `link.writes` were `disconnect`. There was no `link.err`. UDC state was `not attached`, speed `UNKNOWN`, function `zlyme-mtp`. This boot's dmesg has `failed to enable ep0out` at 117.606 seconds, then a SETUP timeout and `ep0 out start transfer failed: -110`.

The active regdump at 17:05:02Z, gadget still bound:

| Register | Value | Reading |
| --- | --- | --- |
| `GUSB2PHYCFG(0)` | `0x40101408` | Bit 8 still 0 |
| `GUCTL1` | `0x8504018a` | Bit 26 still 1 |
| `GCTL` / `GSTS` | `0x30c12004` / `0x7e800000` | Device |
| `DCFG` | `0x008e0800` | Bits 2:0 are 0, high-speed. The gadget init wrote this |
| `DCTL` | `0x00f00000` | `RUN_STOP` is 0 |
| `DSTS` | `0x00120000` | Halt clear, core idle clear, link field 4 (`SS_DIS`) |
| `DALEPENA` | `0` | EP0 disabled |
| `GEVNTCOUNT(0)` | `0` | No pending event |

A second read at 17:05:32Z was the same UDC and helper state, SDP 0, DCP 1. Demetria still had no `1d6b:0100`. This start is the DCP / watcher-disconnect path. It is not the missing SDP enumeration test.

`zlyme-usb-transfer stop` at 17:06:07Z reported `state=off`. The UDC function was empty, configfs had no gadget, and FunctionFS was not mounted. The PAK screen was still up at 17:07:52Z, because `launch.sh` and its presenter wait for B. The reaper was still watching that process group. `nextui.elf` is not running while that PAK screen is up. `nextui-session` was still pid 303. B had not been pressed when this note was written.

### What this does and does not decide

The pre-replug loop is measured: `b_peripheral`, VBUS present, extcon zero, no charger work. The replug's SDP publish is measured, and it was not the DCD-timeout DCP path. The host silence during that SDP window is the stopped gadget, not a failed enumeration. The post-reboot PAK start did not have SDP.

A further call to `rockchip_usb2phy_otg_sm_work()` does not repair the loop. That call was already happening every 2 seconds. The later patch publishes the cable detection already chose. It does not start another BC1.2 pass, and it does not turn a real DCP into SDP. `snps,dis-u2-freeclk-exists-quirk` is still a different variable. Enumeration with SDP and a running gadget is still open. Phase 12D stays open. The source change and the reboot read are section 22.

## 22. Peripheral extcon resync

Built 2026-10-13. Not installed. 12D-E20 is the hardware result and has not been run.

### Reboot at 17:00:49Z

The 12D-E19 poll's last SDP sample was 17:00:45Z. The next SSH, at 17:03:57Z, had uptime 188. A read at 17:24:13Z had uptime 1405, and a read at 17:31:12Z had uptime 1823. All three are the boot that started at 17:00:49Z. The new `dmesg` starts at `Booting Linux` and `Linux version 7.2.10 #2`. It contains no Oops, panic, `BUG:`, or watchdog line.

`/sys/fs/pstore` exists and is empty. It was not deleted. The built `.config` has `CONFIG_PSTORE=y`. `CONFIG_PSTORE_RAM` and `CONFIG_PSTORE_BLK` are unset, so the empty directory does not show that the previous boot was clean. `CONFIG_DW_WATCHDOG=y` and `CONFIG_WATCHDOG_SYSFS` is unset, so `watchdog0` has no boot-status file.

`rk8xx-i2c` logged `ON_SOURCE=0x02 OFF_SOURCE=0x08` at 1.109238 seconds. On this board, `0x02` is the on-source previously recorded after a software reboot with the charger connected. `0x80` is the power-key cold start. `OFF_SOURCE` `0x08` is also the value recorded after a clean power-off, so the pair does not separate a panic from an orderly reboot.

The session did not ask for a restart, and the maintainer had not reported pressing reset. The only WARNING in the new buffer is at 3.709264 seconds, inside `mali_kbase` `kbase_mmu_as_init`, after this boot had already started. Dynamic debug during 12D-E19 was one `b_peripheral` line about every 2 seconds. That volume is not, by itself, evidence of a panic. The restart stays unexplained. It is not a reason to call the kernel unstable, and it is not fixed. The read is `docs/research/evidence/usb-mtp-phase12d/20261013T173112Z-e19-reboot-read.txt`.

### Defect

Linux 7.2.10 `rockchip_usb2phy_otg_sm_work()` writes extcon only from `B_IDLE`, and only when `rport->vbus_attached` changes and `notify_charger` is set. A pass while charger detection is still between `UNDEFINED` and `DETECTED` stores the new VBUS level and leaves `notify_charger` clear. The `DETECTED` pass can then enter `B_PERIPHERAL` for SDP or CDP and skip the extcon write because the cached level already matches the pin. `B_PERIPHERAL` reschedules itself every `OTG_SCHEDULE_DELAY` (`2 * HZ`) and, while VBUS stays present, writes nothing. Those two assignments are the only writes of `OTG_STATE_B_PERIPHERAL`. While that state remains and VBUS stays present, the same function does not clear `chg_state` or `chg_type`. The stored result is still the SDP or CDP value detection finished with. 12D-E19 measured the worker and the empty extcon. It did not print `chg_state` or `chg_type` during the stuck loop. The mapping uses that source invariant. An unknown or DCP type takes the default path and publishes nothing.

Linux master, fetched 2026-10-13, still has the same `B_PERIPHERAL` branch. No upstream power-management change was imported.

`rockchip_otg_event()` listens only for `EXTCON_USB_HOST` and schedules this work. The new writes are `EXTCON_CHG_USB_SDP`, `EXTCON_USB` for SDP, or `EXTCON_CHG_USB_CDP`. They do not schedule this work through that notifier. The worker still does not take `rport->mutex` around `extcon_set_state_sync()`, which is the same context as the existing `B_IDLE` publish. `extcon_set_state_sync()` sends a notification even when the value is unchanged, so a cable that already matches is not written again.

The existing `B_IDLE` path sets `EXTCON_USB` for SDP and does not set it for CDP. This patch keeps that split. CDP consumers that require `EXTCON_USB` are a separate candidate. Generic DWC3 in this tree registers the host-role notifier for `EXTCON_USB_HOST` only. The file-transfer watcher reads the SDP and CDP charger cables.

### Patch

`board/my355/linux/patches/20-rk3566/linux/1015-phy-rockchip-inno-usb2-resync-peripheral-extcon.patch`

Commit `dd0d717f331f` replaces the helper in the same patch. `07de7365fda6` was the first revision and has not shipped. It applies after `1013` and before `30-default` `9901`. Number `1014` stays unused because that filename was the removed maskrom restart patch. The permanent change is this file. `output/build` was re-extracted by `linux-dirclean` and patched by Buildroot.

The helper runs only from `OTG_STATE_B_PERIPHERAL` when `utmi_bvalid` is set. It returns without writing unless `chg_state` is `USB_CHG_STATE_DETECTED` and `chg_type` is SDP or CDP. It reads `EXTCON_USB_HOST`, SDP, CDP, DCP, SLOW, and `EXTCON_USB`. A negative read returns before any value is treated as detached. USB-host mode returns before a write. For stored SDP, an already asserted CDP, DCP, or SLOW cable returns with no write; otherwise a missing SDP bit and a missing `EXTCON_USB` bit are written. For stored CDP, an already asserted SDP, DCP, SLOW, or `EXTCON_USB` bit returns with no write; otherwise a missing CDP bit is written and `EXTCON_USB` is left alone. A cable that already matches is not written again. The helper does not clear a contradictory cable. A successful write stores that cable in the function-static `cable` and sets `vbus_attached`, so the existing falling-edge path can clear the cable this helper published. A refused write leaves that cache alone. A failed `extcon_set_state_sync()` logs once with `dev_err_once` and does not log success. A repair logs one `dev_info`: `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER`. The 2-second schedule is unchanged. PHY `power_on` and `power_off` are unchanged.

The first revision could publish SDP or CDP beside a charger cable that was still asserted. That combination is reachable. `devm_extcon_dev_allocate()` is called with the cable list and no mutually exclusive mask, so the core accepts SDP together with CDP, DCP, or SLOW. The `B_IDLE` publish writes only the static `cable`, plus `EXTCON_USB` when that cable is SDP. The falling edge clears only that same id. `B_PERIPHERAL` on loss of VBUS does not clear extcon in that call. It moves to `B_IDLE` and schedules the worker immediately. If VBUS is present again on that next pass, the pass starts detection and returns before the edge compare, so the old bits and `vbus_attached` stay. Detection can then enter `B_PERIPHERAL` as SDP or CDP and skip the publish because the cached VBUS level already matches. The helper then sees the new internal type and the old extcon bits together. This driver never writes `EXTCON_CHG_USB_SLOW`, and the extcon state file is read-only, so SLOW is a guard for a registered cable rather than a path this file is shown to take. The SDP, CDP, DCP, and `EXTCON_USB` overlap does not have that excuse. The guard refuses the write. It does not clear the old cable.

Left unchanged: RK817 `0007`, `dr_mode = "otg"`, DWC3 clocks and resets, `maximum-speed`, USB-C pinctrl, `snps,dis_u2_susphy_quirk`, `snps,dis_enblslpm_quirk`, the MTP helper, the reaper, the upper host port, and suspend and shutdown.

### Static check

The kernel function was not executed on the Flip. A host model of the guarded helper, compiled with `gcc -Wall -Wextra -Werror`, passed the cases below and a sweep of the SDP/CDP stored types against every combination of the six extcon bits. The sweep checks that a call never raises the number of asserted charger cables when one was already set, and that CDP never writes `EXTCON_USB`. That model is not the patched kernel. `patch -p1 -F0` reproduced the intended source from the unpatched 7.2.10 file. The target toolchain compiled `drivers/phy/rockchip/phy-rockchip-inno-usb2.o` in the build container. Buildroot then applied the same patch to a fresh Linux 7.2.10 tree, with no hunk offset, and compiled that file again. `strings` on `output/images/Image` contains `restored peripheral extcon %s` and `failed to restore peripheral extcon`.

| Condition | Result in the patch |
| --- | --- |
| All-zero extcon, detected SDP | Write SDP and `EXTCON_USB` |
| All-zero extcon, detected CDP | Write CDP only |
| SDP set, `EXTCON_USB` missing | Write `EXTCON_USB` only |
| `EXTCON_USB` set, SDP missing | Write SDP only |
| SDP and `EXTCON_USB` already set | No write |
| CDP already set, `EXTCON_USB` clear | No write |
| DCP set, stored SDP | No write. DCP stays |
| SDP set, stored CDP | No write. SDP stays |
| CDP set, stored SDP | No write. CDP stays |
| SLOW set, stored SDP or CDP | No write |
| `EXTCON_USB` set, stored CDP | No write. CDP stays clear |
| `EXTCON_USB_HOST` set | No write |
| Unknown charger type | No write |
| Detection not finished | No write |
| `extcon_get_state()` negative | No write |
| `extcon_set_state_sync()` failure | `dev_err_once`, no success line |
| VBUS low | Existing disconnect path. Helper not called |
| Second pass after a successful repair | No further write |
| Deep suspend and power-off | No change to those paths |

### Build

`./build.sh --config zlyme_my355_defconfig linux-dirclean`, then `./build.sh --config zlyme_my355_defconfig`, from clean `dd0d717f331f`. The first image build linked the kernel and then stopped in `post-build.sh` with make error 141, the same SIGPIPE as the earlier image. The retry completed. Product version in the squashfs is still `zlyme44.2 (2026-10-13)`. The kernel string is `Linux version 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. The `#1` is a new build count after `linux-dirclean`. The installed 12D-E18 kernel was `#2` at 16:08:35 UTC. The DTB hash is unchanged, so the role, the speed cap, and both Synopsys quirks are the same bytes. `u-boot.itb` and `idbloader.img` in this tar match the superseded tar byte for byte. RK817 `0007` is unchanged.

| Artifact | SHA-256 |
| --- | --- |
| `output/images/rk3566-miyoo-flip.dtb` | `cbb249cd244b32595c29d3df61cd968b7cd6e0533085072549f78b14280eefed` |
| `output/images/Image` | `1bda9d4258b70f0e6e1693071344590189f1a49315dfac98805df95e5e145fed` |
| `output/images/Image.gz` | `eafe2a996bf1b0495edf8859ad4a68fbf568c40a8ebafeeace20761b778cd847` |
| `output/images/zlyme` | `9757e47e9512e36f94f136da8f733f2ba749edc77ca3fb2ff347de561a7eb13c` |
| `output/images/zlyme-my355-20261013-dd0d717f331f.tar` | `7d600ea6cc604c9be2ae69ff9872431e606b02c86ff9c100060b365c55d036e0` |

`VERSION` in the tar is `dd0d717f331f` and `20261013`. The tar members `Image.gz`, `rk3566-miyoo-flip.dtb`, and `zlyme` match those hashes. Decompiled `usb@fcc00000` still has `dr_mode = "otg"`, `maximum-speed = "high-speed"`, `snps,dis_u2_susphy_quirk`, and `snps,dis_enblslpm_quirk`. It does not have `snps,dis-u2-freeclk-exists-quirk`. `usb@fd000000` is still `dr_mode = "host"` with `snps,dis_u2_susphy_quirk` and `maximum-speed = "high-speed"`. The upper EHCI node is unchanged. The OTA was not installed.

`zlyme-my355-20261013-07de7365fda6.tar`, SHA-256 `195ecc2fc9f563565a51ab696cbe61cc8405b38b270027cba4bc6be63a00cb6f`, is the first helper revision. It is superseded for testing. Do not install it.

### Predicted hardware result

When the PHY is already in a completed SDP or CDP peripheral session and the published extcon is empty, the existing worker writes the matching cable within one 2-second period. The `dev_info` line is the evidence that this path ran. A new detection that logs `sdp cable is connected` is the old publish path, not this one.

The patch does not choose SDP. A DCP result stays DCP. It does not make DWC3 enumerate. 12D-E17, SDP with `RUN_STOP` and endpoint 0 and no host device, stays open. The 17:00:49Z restart stays unexplained.

### Maintainer test

Copy `zlyme-my355-20261013-dd0d717f331f.tar` on the OS card. Do not send it over Wi-Fi, and do not install `zlyme-my355-20261013-07de7365fda6.tar`. Put the new tar in `/storage/.update/`. Newest `zlyme-my355-*.tar` wins, so remove older tars in that directory first. Check SHA-256 `7d600ea6cc604c9be2ae69ff9872431e606b02c86ff9c100060b365c55d036e0` on the card. Boot. `S18zlymeupdate` applies a queued tar and reboots. After that second boot, `uname -a` should show `7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. Do not flash SPI NAND and do not run `zlyme-update uboot`.

Start the host kernel journal and an `lsusb` poll before moving the cable, and keep a device `dmesg` or `/dev/kmsg` capture over that same interval. The two clocks need a shared note of when the cable moved. A host log from outside that interval does not score either gate.

Gate 1, extcon recovery. Leave USB File Transfer stopped. Enable dynamic debug only for `rockchip_usb2phy_otg_sm_work` and `rockchip_chg_detect_work`, so a fresh detection is visible. With the cable in the lower port, a pass is `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER` with no `chg detection work` sequence in front of it, and the sysfs cable matching that line. The host poll in that window should stay empty, because the gadget is stopped. `sdp cable is connected` after charger states 0 through 5 is a fresh detection and does not pass Gate 1. If the edge path already published and the restore line never appears, the stuck state did not occur. Replug and watch again. If another charger cable is already asserted, the helper is supposed to stay silent. Record that and do not clear it by hand. If the PHY stays DCP, stop and do not start the gadget.

Gate 2, enumeration. Run it only while SDP or CDP is actually present, whether that presence came from Gate 1 or from a later fresh detection. Keep the host journal and `lsusb` poll running from before USB File Transfer starts until the gadget is stopped. Sample `GUSB2PHYCFG(0)`, `DCTL`, `DSTS`, `DALEPENA`, and the UDC state during that interval. Bit 8 should still be clear. If the host sees `1d6b:0100`, copy one small file and then check B cleanup. If SDP or CDP never appears, Gate 2 stays untested.
