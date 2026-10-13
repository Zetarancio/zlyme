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
| USB2 PHY power-down | A powered-off PHY would not detect VBUS | `0x0000` matched the power-on encoding and the refclk was on. 12D-E13 | Contradicted for that idle sample | A sample shows the power-off encoding with the cable attached |
| Runtime-PM pull-up skip | `dwc3_gadget_pullup` skips the start when `pm_runtime_get_sync` returns 0 | Probe forbids autosuspend. Measured returns were 1 and suspended time stayed 0. 12D-E07, 12D-E11 | Contradicted for the measured sessions | A session whose get-sync return is 0 or negative during pull-up |
| Awake BVALID / extcon loss after reconnect | Tool-first replug left extcon at zero while `utmi_bvalid` was later read as 1. IRQ count did not move and the status bit was clear. 12D-E10, 12D-E13 | Cable-first sessions already had SDP and still did not enumerate. 12D-E09, 12D-E17 | Open for the replug path. Distinct from the cable-first SDP failure | A trace of the state machine, or a replug that publishes SDP and then enumerates |
| DWC3 USB2 LPM and clock programming | Stock sets `snps,dis_enblslpm_quirk`. Live `GUSB2PHYCFG(0)` bit 8 is 1. 12D-E17 sat in Suspend with no host | Not tested | Untested | The experiment in section 18 runs |
| Rockchip BSP wrapper and clock differences | Stock has `pipe_clk` and the `dwc3` wrapper. Zlyme does not | The core programs registers and reached `RUN_STOP`. 12D-E14, 12D-E17 | Recorded difference. Not shown to be the cause | A clock or reset the core cannot program without that wrapper |

## 18. Next-experiment queue

Phase 12D stays open. Enumeration is not accepted. Do not repeat the speed-cap edit, an RK817 bit toggle, or the current soft-connect watcher unchanged.

1. `snps,dis_enblslpm_quirk` on `&usb_host0_xhci` only. Priority: first. Not yet attempted.
   - Preconditions: the property is absent on `fcc00000`, live `GUSB2PHYCFG(0)` bit 8 is set, and 7.2.10 `dwc3_phy_setup()` clears that bit when the property is set. No other quirk, role, speed, PHY, or RK817 change in the same build.
   - Observable: `GUSB2PHYCFG(0)` bit 8 becomes 0. The prediction from `0x40101508` is `0x40101408`. That prediction is not evidence until a new kernel is measured. `GUCTL1`, the speed cap, and the device role stay as they are.
   - Success: with SDP or CDP already reported, the host enumerates and one small file round trip matches. Failure: bit 8 is clear and the host still sees no device. If extcon is not SDP or CDP, that is the replug problem below, not a result about this bit.
   - Safety: one DTS property on the lower controller. The upper port is the EHCI/OHCI host on `usb2phy1`, not this node. Rollback is deleting the property and rebuilding that configuration. Do not add another quirk in the same test.
2. Extcon resynchronization after a reconnect, while the system is already awake. Priority: after item 1, and not combined with it. Not attempted as its own experiment. 12D-E13 is the idle reading. The vendor resume-only rescan is not this repair.
   - Preconditions: item 1 has a result, or a session where SDP never returns.
   - Single variable: one change that reruns charger detection when `utmi_bvalid` is already 1 and extcon is zero. Not a PHY power-policy rewrite.
   - Observable: extcon moves from all zero to SDP or CDP without a suspend/resume, and IRQ or state-machine evidence shows why.
   - Success: a following, separate MTP start enumerates. Failure: extcon stays zero, or extcon updates and the host still sees nothing.
   - Safety: do not write GRF from userspace as the experiment. Do not touch `0007`.
3. `snps,dis-u2-freeclk-exists-quirk`. Priority: only if item 1 clears bit 8 and enumeration still fails. Not attempted. Stock sets it. Live bit 30 is 1. It is a different variable and does not belong in the item 1 build.

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
