# Phase 12D USB MTP investigation

This is the investigation record for the lower-port MTP session. It is not a driver patch, and it does not say that a proposed change is correct. Shipped behavior is in `docs/ARCHITECTURE.md`. Phase 12 development closed on 2026-10-14. Section 41 is that reading. Earlier sections keep the wording from the day they were written. Sequencing is `docs/ROADMAP.md`.

2026-10-15: the active roadmap no longer has an "After Phase 12" wiki task. The hardware wiki was already updated for the development Linux 7.2.10 boot and the lower-port session. The 2026-10-14 logbook note is that update. It does not call the device tree proven. A comparison that would establish the minimum USB device tree against upstream Linux and the stock evidence has not been done. That comparison stays here. It is not an open roadmap item.

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
| 12D-E20 | 2026-10-13 18:20Z–18:45Z | fresh SDP, restore unexercised, no enumeration | [Extcon and enumeration session](#23-extcon-and-enumeration-session) |
| 12D-E21 | 2026-10-13 19:17Z–19:45Z | both gadgets enumerated on the identified port | [Host port and gadget session](#25-host-port-and-gadget-session) |
| 12D-E22 | 2026-10-13 21:05Z–21:22Z | gadget started, host saw no device | [Installed root export](#27-installed-root-export) |
| 12D-E23 | 2026-10-13 | source defect in the watcher; installed later the same day | [Connection watcher](#28-connection-watcher) |
| 12D-E24 | 2026-10-13 22:21Z | installed watcher image, PHY DCP, gadget stopped | [Deferred UDC bind](#29-deferred-udc-bind) |
| 12D-E25 | 2026-10-14 00:45Z–01:26Z | E24 image installed; MTP enumerated; file bytes not checked; boot restarted | [Installed E24 acceptance](#30-installed-e24-acceptance) |
| 12D-E26 | 2026-10-14 01:50Z–02:21Z | disposable SHA-256 matched both ways; B not pressed; same boot | [PAK MTP file match](#32-pak-mtp-file-match) |
| 12D-E27 | 2026-10-14 02:26Z–02:35Z | E26 session gone; second enumeration not logged | [Stopped session](#33-stopped-session) |
| 12D-E28 | 2026-10-14 | EP0 recovery removed; image installed; maintainer reports MTP works; no new file hash | [EP0 recovery removal, installed](#34-ep0-recovery-removal-installed) |
| 12D-E29 | 2026-10-14 | patch 1015 removed; installed; maintainer reports MTP works; host logged enumerations; no new file hash | [USB2 PHY extcon resync, installed](#35-usb2-phy-extcon-resync-installed) |
| 12D-E30 | 2026-10-14 | `snps,dis_enblslpm_quirk` removed; installed; idle bit 8 set; file match in 12D-E31 | [ENBLSLPM property, candidate](#36-enblslpm-property-candidate) |
| 12D-E31 | 2026-10-14 | fixed-cable MTP SHA-256 match accepted; B and second Start pending | [ENBLSLPM property, installed, coverage open](#37-enblslpm-property-installed-coverage-open) |
| 12D-E32 | 2026-10-14 | cable-loss `soft_connect` pair removed; candidate built; not installed | [Cable recovery pair, candidate](#39-cable-recovery-pair-candidate) |
| 12D-E33 | 2026-10-14 | Flip still on the E30 image; E32 not installed; removal not tested | [Cable recovery pair, not installed](#40-cable-recovery-pair-not-installed) |
| 12D-E34 | 2026-10-14 | E32 installed and accepted; cable recovery not measured | [E32 installed and accepted](#41-e32-installed-and-accepted) |

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

- When: 2026-10-13 18:20Z through 18:45:51Z. The cable cycle is 18:31:29Z–18:31:33Z. The gadget samples are 18:36:23Z and 18:41:48Z.
- Source: installed OTA `zlyme-my355-20261013-dd0d717f331f.tar`. Kernel `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. Patch `1015` is `dd0d717f331f`. Notes tree `908f91f1669d`. No source edit in this session. The earlier tar `zlyme-my355-20261013-07de7365fda6.tar` stayed superseded and was not the installed image.
- Setup: USB File Transfer stopped until SDP was present. Dynamic debug only for `rockchip_usb2phy_otg_sm_work` and `rockchip_chg_detect_work`. Demetria's kernel journal, USB uevents, and `lsusb` poll started before the cable moved. One lower-port unplug/replug. The maintainer opened the PAK. B dismissed it. No second replug, no GRF write, no PMIC write, no new quirk.
- Hypothesis: Gate A is that a finished SDP or CDP session with missing extcon is republished by the existing worker, without a new BC1.2 pass. Gate B is that a gadget started while SDP or CDP is present enumerates on Demetria while `snps,dis_enblslpm_quirk` is active.
- Action: confirm the booted kernel, the DTB, and the stopped regdump. Record one cable cycle. Start MTP from NextUI only after SDP. Take two active snapshots under the host monitors. Restore dynamic debug.
- Observed: the boot began near 18:17:11Z and was still that boot at 18:45:51Z, uptime 1720. Idle extcon was DCP. The replug logged charger states 0, 1, 2, and 5, then `sdp cable is connected`. The string `restored peripheral extcon` does not appear. Extcon became USB=1, SDP=1. The PAK bound the gadget, `DCTL` was `0x80f00000`, and both EP0 directions read `control`. `GUSB2PHYCFG(0)` stayed `0x40101408`. Demetria's journal, udev monitor, and `lsusb` poll have no `1d6b:0100`.
- Result: Gate A was not exercised. This was a fresh detection, not a restore of an empty extcon. Gate B did not enumerate. Clearing bit 8 did not make the host see the running gadget. That is the same host silence as 12D-E17, with bit 8 now clear.
- Excludes: the restore line as a description of this replug. An EP0 enable failure, a host reset, and a descriptor error as the description of this gadget session. A missing `snps,dis_enblslpm_quirk` as the reason Demetria stayed silent.
- Unknown: whether D+ or D- changed at the connector. `snps,dis-u2-freeclk-exists-quirk` was not applied. `GUSB2PHYCFG` bit 30 was still 1. The 17:00:49Z restart is still unexplained. This boot did not restart.
- Evidence: section 23.
- Code: left untouched. Dynamic debug was restored to `=_`. No new image.

### 12D-E21 Host port and two gadgets

- When: 2026-10-13 19:17Z through 19:45:21Z, on the same boot as 12D-E20.
- Source: the same installed image. Kernel `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. No kernel, DTS, PMIC, bootloader, or register write.
- Setup: Demetria journal, USB uevents, and a full `lsusb` poll were running before any cable move. One known USB hub identified the host receptacle. The Flip was then put back in the original orientation. USB File Transfer was started from NextUI. After B, one temporary read-only mass-storage gadget was bound and removed.
- Hypothesis: the 12D-E20 silence is either the cable and host port, the USB2 PHY or DWC3 connection sequence, or something specific to the MTP gadget.
- Action: read the controller through debugfs. Do not write `mode`, `link_state`, or `testmode`. Do not write `soft_connect` unless the MTP gadget is up and a client is not already using it. Bind one disposable configfs mass-storage function only after MTP is gone.
- Observed: bus 7 port 1 enumerated the hub, then `1d6b:0100` at high speed, then `1d6b:0104` at high speed. `GUSB2PHYCFG(0)` stayed `0x40101408` during both gadget sessions. The link watcher did not create `link.writes`. The soft-connect cycle was not run.
- Result: both gadgets enumerated on the port that had just enumerated a hub. The 12D-E20 silence did not repeat. A file copy was not checked.
- Excludes: an MTP-only failure as the description of 12D-E20, for this cable and this receptacle. A missing `soft_connect` write as the step that created the 12D-E21 connection. Clearing `U2_FREECLK_EXISTS` as a requirement for this enumeration. 12D-E06 stays the older image's watcher-write result.
- Unknown: which receptacle was used in 12D-E20. Whether a file copy matches. The 17:00:49Z restart is still unexplained. This boot did not restart.
- Evidence: sections 24 and 25.
- Code: left untouched. The test gadget was removed before the notes were copied. No new image.

### 12D-E22 Installed root export

- When: 2026-10-13. The PAK log starts at 21:05:32Z. The stopped reading is 21:22:22Z.
- Source: installed OTA `zlyme-my355-20261013-4a2b752bafbe.tar`, SHA-256 `4767e45ffdf7ae7fa48e0c1b1d26a2fcdd50f762916d21119f53930b3ddbe08d`. `/boot/zlyme` is `87de255b083a05842233233e81346cd83bcf2ac6700a48d572b053f959a14da3`. `zlyme-usb-transfer` is `0fc7ce834f3e91392679fd4453c89e36836ec1b285859346c540676741b689c7`. `zlyme-usb-enter` is `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. The installed `launch.sh` is `5c7c8c78978a6943b2cef83a97242db3dca9ed9dc71b9a01237a91665784d0f9`. Kernel banner `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`.
- Setup: the maintainer used the same cable and the same Demetria receptacle as 12D-E21, and tried one physical reconnection. The diagnostic SSH started after the page was already closed. The helper was not started from SSH.
- Hypothesis: the new root export, the update-staging guard, or a nested mount under `/storage` stopped MTP from appearing.
- Action: compare the installed hashes with the OTA. Read the update paths, the mount table, this boot's `dmesg`, the UDC, and both PHY extcon groups. On Demetria, read `lsusb`, `lsusb -t`, and the kernel journal.
- Observed: `/storage/.update/reconstruct` and `/storage/.update/pending/zlyme` are absent. `/storage` has no nested mount. `/mnt/sd2` is mounted ext4. The gadget reached the kernel: `failed to enable ep0out` at 26.788 s, then a SETUP timeout, a STALL failure, and one later unqueued EP0 request at 57.459 s. After the page was closed, UDC was `not attached` and extcon0 was DCP=1, SDP=0, CDP=0, USB=0. Demetria bus 7 had only its root hub. `lsusb -d 1d6b:0100` was empty. The kernel journal had no `usb 7-`, `1d6b:0100`, or `1d6b:0104` line in that window.
- Result: category C. The helper created the gadget. The computer did not see a USB device. The update guard and the nested-mount guard were not the refusal on this boot. The PHY was reporting a dedicated charger when it was read, which is not the SDP state from 12D-E21.
- Excludes: a mismatched install. A present `pending/zlyme` or `reconstruct` directory. A nested mount under `/storage` as the reason this session stopped. A config-parse crash before the kernel tried EP0.
- Unknown: the live `umtprd.conf`, responder log, FunctionFS state, link latch, and DWC3 registers. Those files were already gone. Whether extcon was DCP or SDP while the page was open. Whether the one reconnection happened before or after B.
- Evidence: section 27.
- Code: no kernel, DTB, PHY, or bootloader change. No exporter change from this session. The screen text in the tree was shortened afterwards and was not on this image.

### 12D-E23 Connection watcher

- When: 2026-10-13, after 12D-E22. No new Flip session.
- Source: `13071973a350`. The installed image for 12D-E22 is still `4a2b752bafbe`.
- Setup: read `link_once` against Linux 7.2.10 `soft_connect_store`, `dwc3_transfer_type_show`, and `dwc3_gadget_pullup`. Host tests use mocked sysfs. They do not open a USB controller.
- Hypothesis: `ep0out/transfer_type` of `control` was being used as proof that the link was healthy, so a later data cable could be ignored.
- Action: replace that decision with the PHY cable and the UDC state. Build one product OTA. Do not change the kernel.
- Observed: `transfer_type` prints `control` when the endpoint is enabled and its descriptor class is control. The old `link_once` returned immediately on that string and stored `healthy`, without reading the UDC state. `soft_connect_store` returns the byte count and ignores the pull-up result. The product OTA is `zlyme-my355-20261013-13071973a350.tar`, SHA-256 `2f41f13de96f231bd8cf8f95cb01b7b2029c6cb17a0010779afb2692a2a89945`. Its kernel, DTB, and bootloader members match 12D-E21. It had not been installed when this note was written. Section 29 records the later install.
- Result: the source defect is real. It is not evidence that the defect caused 12D-E20 or 12D-E22. 12D-E21 stays a successful enumeration. 12D-E22 stays the failed session on the root-export image. This OTA is not hardware-accepted.
- Excludes: a storage-layout change as the response to 12D-E22. A kernel, DTB, PHY, or bootloader edit. Treating a `soft_connect` write as enumeration.
- Unknown: whether SDP or CDP was present while the 12D-E22 page was open. Whether this watcher enumerates on bus 7 port 1.
- Evidence: section 28. No new hardware log.
- Code: `package/system/zlyme-usb-transfer/zlyme-usb-transfer`. The filesystem-root exports and `zlyme-usb-enter` are unchanged.

### 12D-E24 Deferred UDC bind

- When: 2026-10-13 22:21:06Z. The PAK was not launched.
- Source: installed OTA `zlyme-my355-20261013-13071973a350.tar`. The tree change after the reading is `7951a37668e3`.
- Setup: compare `/boot/zlyme` and the helper hashes with the 12D-E23 archive. Read the UDC and extcon0 before any cable move. On Demetria, read `lsusb` and the kernel journal. Do not start the helper from SSH.
- Hypothesis: `cmd_start` binds `fcc00000.usb` before the watcher can see SDP or CDP, so EP0 setup can fail before a data cable exists. 12D-E21 had SDP before the PAK and wrote no `soft_connect`.
- Action: read the installed image and the Linux 7.2.10 configfs bind path. If FunctionFS is already ready before that write, postpone the bind until SDP or CDP. Do not change the kernel, the PHY, or the export list.
- Observed: the installed hashes match the 12D-E23 archive. Status was `off`. The UDC was `not attached`. extcon0 was DCP=1, SDP=0, CDP=0. Demetria bus 7 was empty. `gadget_dev_desc_UDC_store` calls `usb_gadget_register_driver` before the write returns, and `__dwc3_gadget_start` enables EP0 inside that path.
- Result: the premature-bind reading is source-supported. The live port was not in the 12D-E21 precondition, so this session does not say whether the installed image enumerates when SDP or CDP is already present. The postponed bind is host-tested. It is not a Flip enumeration.
- Excludes: a storage-root change as the response to this reading. A kernel, DTB, PHY, or bootloader edit. Calling the 64 KiB 12D-E21 disk image a mount success or a mount failure. It had no filesystem.
- Unknown: whether the new image enumerates when SDP or CDP is present before launch. Whether a file copy matches.
- Evidence: section 29.
- Code: `zlyme-usb-transfer` binds only after SDP or CDP. The PAK accepts `state=waiting`. Exports and `zlyme-usb-enter` are unchanged.

### 12D-E25 Installed E24 acceptance

- When: 2026-10-14 00:45:29Z through 01:26:26Z.
- Source: installed OTA `zlyme-my355-20261013-7951a37668e3.tar`, SHA-256 `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`. `/boot/zlyme` is `06b5f3577aea9ba45dc85c9763375a9e555283b40403f6d2623929c8ed8e712d`. `zlyme-usb-transfer` is `15e2e682012eb08363a02e2c888814d524d5c7f32b34562cc81c2dc06f332557`. `zlyme-usb-enter` is `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. Both copies of USB File Transfer `launch.sh` are `fd7f9d58ef38d7a6b0411dff17951e10423fef68e3882213d0987a9b9fdbf766`. `Image.gz` and `rk3566-miyoo-flip.dtb` match 12D-E21. The root loop is `/boot/zlyme`. `ZLYMEBOOT` is `/boot`, read-only. `ZLYME` is `/storage`.
- Setup: the maintainer reported that a bad cable had been corrected and that MTP was working. Demetria's lower-port history for this window is bus 1 port 2, not the bus 7 port 1 of 12D-E21. The helper was started from a held SSH after extcon0 already read SDP. The cable was not unplugged for this pass.
- Hypothesis: the installed deferred-bind image can enumerate and a disposable file survives MTP with a matching SHA-256.
- Action: compare the installed hashes with the E24 archive. List the MTP storages. Copy disposable files through KIO and compare SHA-256 on the Flip. Leave the cable seated.
- Observed: before the SSH start, Demetria had already enumerated `1d6b:0100` at high speed on bus 1 port 2 (`usb 1-2`, device 26, 00:48:05Z). The same port had connected and disconnected devices 21 through 25 from 00:32:54Z to 00:42:32Z. After the SSH start the helper reported `state=bound`, one `bind` line, high-speed, and exports `ZLYME` (`/storage`) and `SD Card` (`/mnt/sd2`). KIO listed those two names. `ZLYMEBOOT` was not a storage. `kioclient` mkdir and copy failed. `kiod6` logged PTP `02ff` I/O errors for object handles, folder creation, and object info. `mtp-detect` found no raw device. No disposable file was confirmed on the Flip. The UDC state file read `not attached` while `current_speed` was `high-speed`. String descriptors for the configuration and interface read as errors. Device 26 disconnected at 01:05:24Z. Wi-Fi then stopped answering until 01:11:59Z. The next boot is about 01:11:35Z. The saved `/boot/zlyme-dmesg.txt` from that boot has no panic line. After the reboot the gadget was off and extcon0 was all zeros. Battery capacity was 99 and status was Discharging. Charger `online` was 0.
- Result: the E24 archive is the installed image, and this host enumerated it at high speed. A file copy was not verified. The restart is unexplained. Phase 12D stays open. Earlier failures are unchanged. A bad cable may explain some of them. This session is not that comparison.
- Excludes: a mismatched install. A second Start, a physical B press, and MENU+START on this image. A SHA-256 match. Treating KIO's storage names as a completed copy.
- Unknown: why object operations returned PTP `02ff` after the storage names were listed. Whether the SSH start replaced a session that was already enumerated at 00:48:05Z. Why the boot restarted. Whether bus 1 port 2 is the receptacle the maintainer intends to keep.
- Evidence: section 30.
- Code: left untouched. No kernel, DTS, watcher, or export change.
- Clarification, 2026-10-14: the maintainer reports that the USB cable was disconnected during this pass. The setup line that says the cable was not unplugged is the assumption written at the time, and it is withdrawn. The original evidence file is unchanged. The host logged `usb 1-2` device 26 disconnecting at 01:05:24Z. That line is not identified as the maintainer's action. The same port then logged more connect attempts and descriptor errors. High-speed enumeration was observed. The storage names `ZLYME` and `SD Card` were listed. A file transfer was not observed. PTP `02ff` was observed. The restart was observed and its cause is unknown. Physical B was not tested. A second PAK start with the cable left seated was not tested. The enumeration at 00:48:05Z and the SSH helper start at 00:50:27Z are not one proven continuous session. None of this is hardware acceptance. The restart and the Mali workqueue warning stay separate observations.

### 12D-E26 PAK MTP file match

- When: 2026-10-14 01:50:05Z through 02:21:00Z. The file copies ran from 02:02:36Z to 02:14:14Z.
- Source: the same installed OTA as 12D-E25. `/boot/zlyme` read at 02:17:07Z is `06b5f3577aea9ba45dc85c9763375a9e555283b40403f6d2623929c8ed8e712d`. `/boot` stayed read-only. No source file changed.
- Setup: the maintainer reported that MTP was already connected and working. The helper was not started from SSH. The cable was not unplugged. Demetria's device was bus 1 port 2, PCI `0000:c4:00.3`, device 48, from 01:50:17Z. `kiod6` held that usbfs node. No second MTP client was started.
- Hypothesis: the already-open PAK session can copy disposable bytes in both directions with matching SHA-256 values.
- Action: list the storages with `kioclient`. Create `zlyme-mtp-test-20261014-E26` through MTP. Copy a 4096-byte file and a 1048576-byte file onto `ZLYME`. Hash them on the Flip over SSH. Create a third file on the Flip and copy it back through MTP. Repeat one file on `SD Card`. Rename and delete only those paths.
- Observed: helper `state=bound`, UDC `configured`, `current_speed` `high-speed`, one `bind` line, FunctionFS `ep0` through `ep3`, responder pid 23929. extcon0 (`fe8a0000.usb2phy`) at 02:12:00Z was USB=1, SDP=1, CDP=0, DCP=0. KIO listed `ZLYME` and `SD Card`. `ZLYMEBOOT` was absent. The responder mount namespace had `/storage`, `/mnt/sd2`, the configuration file, FunctionFS, and the responder binary. It did not have `/boot`. Host-to-Flip SHA-256 `3b9ccb9cea630922d5ea2320b00f932d9f835e5007c0fcffc806382cc7edf5f7` (4096 bytes) and `d7f02edbe6d89ed61d10038a71bbdc827c1b20ee4744bbac8e5bec1aadb9e5cc` (1048576 bytes) matched on `/storage` and again when KIO read the files back. The Flip-created file `b3fb756a1c6d5f819d65f35e6c9ac6024d04f59000cccda28e854c1f08059f08` matched after the MTP copy to Demetria. The ext4 card at `/mnt/sd2` matched `3b9ccb9cea630922d5ea2320b00f932d9f835e5007c0fcffc806382cc7edf5f7`. Rename kept that hash. Delete removed both test directories. `/mnt/media` was an empty tmpfs and was not exported. Boot id `6b0451a8-3c6d-42bc-ac50-2ddc73c6037c` was unchanged from uptime 2915.25 seconds to 3883.87 seconds. No PTP `02ff` was logged during the copies. `umtprd.log` still ends at the 01:50:12Z read error from the device 45 disconnect, before device 48. One `dwc3` line at 1157 seconds, `request was not queued to ep0out`, is earlier on this boot. The Mali probe warning at 3.64 seconds was not repeated. At 02:21:00Z device 48 was still present and the helper was still `bound`.
- Result: disposable file bytes matched in both directions, and on the mounted second card. Rename and delete of those files matched the Flip directories. PTP `02ff` was not reproduced in this session. That does not assign a cause to the 12D-E25 errors. B was not pressed, so cleanup and a second Start are not results. Phase 12D stays open. The 12D-E25 restart stays unexplained.
- Excludes: an SSH-started gadget. A USB-stick copy. A write to `/boot`. Treating this match as hardware acceptance of audio, controls, charging, or the earlier restart.
- Unknown: why one SSH read of the new exFAT file did not return within 8 seconds, while a later read hashed correctly. Why device 45 disconnected and device 46 logged `-71` before device 48 stayed up. Why B cleanup behaves on this image.
- Evidence: section 32.
- Code: left untouched.

### 12D-E27 Stopped session

- When: 2026-10-14 02:26:43Z through 02:35Z.
- Source: the same installed E24 image. The local archive `zlyme-my355-20261013-7951a37668e3.tar` hashes to `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`. It was not overwritten.
- Setup: the maintainer accepts the E26 file match and reports that a second Start and MENU+START succeeded. No new PAK launch was requested for this reading. No `stop` was sent over SSH.
- Hypothesis: the session that copied the E26 files is gone, and the data mounts are unchanged.
- Action: read helper status, the UDC, configfs, mounts, and the process list. Read Demetria's `usb 1-2` log from the E26 device through the following minutes.
- Observed: device 48 disconnected at 02:26:43Z. No later `usb 1-2` device was logged. Helper `state=off`. UDC `not attached`. Configfs was not mounted. FunctionFS was not mounted. No `umtprd` and no watcher process. `nextui.elf` was running. `/storage` and `/mnt/sd2` stayed read-write. `/boot` stayed read-only. Boot id unchanged. Reaper pid file 22803 was not a running process.
- Result: the E26 gadget is gone. That is the observed cleanup. The maintainer's second Start and MENU+START stay reports, because the host log has no second enumeration. The E26 hashes stay the file baseline. Phase 12 stays open.
- Excludes: naming the 02:26:43Z disconnect as B or as MENU+START. A logged second Start. Charging, audio, and the earlier restarts.
- Unknown: which control ended device 48. Whether the reported second Start enumerated on a port this log does not show.
- Evidence: section 33.
- Code: left untouched.

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
| Awake BVALID / extcon loss after reconnect | 12D-E10, 12D-E13, and 12D-E18 left extcon at zero with `utmi_bvalid` 1. 12D-E19 found the worker already in `b_peripheral`, logging every 2 seconds, and not publishing | 12D-E19's observed disconnect ran detection from state 0 and published SDP. 12D-E20's one replug did the same and never logged `restored peripheral extcon`. Cable-first SDP sessions still failed to enumerate. 12D-E09, 12D-E17, 12D-E20 | The stuck loop is measured on the earlier boots. 12D-E20 did not enter it. The restore path is implemented and was not the path this replug took. Enumeration with a running gadget and SDP still failed | A later boot that is already in `b_peripheral` with empty extcon, if the restore line and the sysfs cable are still missing |
| DWC3 USB2 LPM (`snps,dis_enblslpm_quirk`) | Stock sets the property. 12D-E17 had bit 8 set and sat in Suspend with no host | 12D-E18, the 12D-E19 reboot, and 12D-E20 all read `GUSB2PHYCFG(0) = 0x40101408`. 12D-E20 started the gadget while SDP was present and Demetria still saw no device | Property applied. Not sufficient for enumeration in the 12D-E20 SDP window | A later SDP session whose host result differs, or a sample where bit 8 is set again |
| Rockchip BSP wrapper and clock differences | Stock has `pipe_clk` and the `dwc3` wrapper. Zlyme does not | The core programs registers and reached `RUN_STOP`. 12D-E14, 12D-E17 | Recorded difference. Not shown to be the cause | A clock or reset the core cannot program without that wrapper |

## 18. Next-experiment queue

Phase 12D stays open. Enumeration is not accepted. Do not repeat the speed-cap edit, an RK817 bit toggle, or the current soft-connect watcher unchanged.

1. `snps,dis_enblslpm_quirk` on `&usb_host0_xhci` only. 12D-E18 measured the register change. Enumeration was not scored. The DTS line stays as built. Do not add a second quirk from that session.
   - Preconditions: the pre-boot gate. The property was absent on `fcc00000`, live `GUSB2PHYCFG(0)` bit 8 was set, and 7.2.10 `dwc3_phy_setup()` clears that bit when the property is set. No other quirk, role, speed, PHY, or RK817 change was in that build. The booted tree now has the property.
   - Observable: `GUSB2PHYCFG(0)` bit 8 becomes 0. The prediction from `0x40101508` is `0x40101408`. 12D-E18 measured that value. `GUCTL1`, the speed cap, and the device role stayed as they were. The success line still requires SDP or CDP.
   - Success: with SDP or CDP already reported, the host enumerates and one small file round trip matches. Failure: bit 8 is clear and the host still sees no device. If extcon is not SDP or CDP, that is the replug problem below, not a result about this bit.
   - Safety: one DTS property on the lower controller. The upper port is the EHCI/OHCI host on `usb2phy1`, not this node. Rollback is deleting the property and rebuilding that configuration. Do not add another quirk in the same test.
2. Republish a finished SDP or CDP extcon from `B_PERIPHERAL`. The source change is section 22. 12D-E20 installed that image. The one replug took the ordinary detection path and published SDP. The restore line did not appear, so Gate A was not exercised and is not a failed restore. Gate B ran on that SDP and the host still saw nothing. Another schedule of `rockchip_usb2phy_otg_sm_work()` is not the repair: 12D-E19 already saw that work every 2 seconds. Rerunning BC1.2 is not the repair either. The vendor resume-only rescan is not this repair.
   - Preconditions: 12D-E19. VBUS valid, worker in `b_peripheral`, extcon all zero, no charger restart.
   - Single variable against the installed 12D-E18 image: patch `1015` only. The DTB is byte-identical. `snps,dis_enblslpm_quirk` stays.
   - Observable: `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER` without a new `chg detection work` sequence, then the matching sysfs cable. A fresh detection that logs `sdp cable is connected` does not pass this gate.
   - Success is two separate results. Gate 1 is that restore. Gate 2, only after SDP or CDP is actually present, is host enumeration with the gadget running. Failure of Gate 1 is extcon staying zero. Failure of Gate 2 is SDP or CDP present, the gadget running, and the host still seeing nothing.
   - Safety: do not write GRF from userspace. Do not touch `0007`. Do not start the gadget on DCP.
3. `snps,dis-u2-freeclk-exists-quirk`. The precondition is now met: 12D-E20 had SDP, a running gadget, bit 8 clear, and no host device. Not attempted. `GUSB2PHYCFG(0)` bit 30, `U2_FREECLK_EXISTS`, was still 1 during that session. `GUCTL1` bit 26 is `DEV_FORCE_20_CLK_FOR_30_CLK` and is not this bit. Stock sets the free-clock property. Clearing bit 30 is a hypothesis, not a measured cause. Do not add it from this result alone.

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

Status 2026-10-13 18:45Z: 12D-E20 completed the list on the patch `1015` image. Step 4 found fresh SDP, not the restore path. Steps 5 through 8 ran. The host saw no device, so step 9 did not run. Step 10 confirmed B cleanup and RK817 still online. An added upper-port peripheral and suspend/resume were not run. The record is section 23.

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

Built 2026-10-13 and installed for 12D-E20. The hardware result is section 23. The restore path was not the path that replug took.

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

On 2026-10-14, 12D-E29 deletes that file from the patch directory. The text stays in git history and in this section. Section 35 is the build record. The maintainer later installed that image.

The helper runs only from `OTG_STATE_B_PERIPHERAL` when `utmi_bvalid` is set. It returns without writing unless `chg_state` is `USB_CHG_STATE_DETECTED` and `chg_type` is SDP or CDP. It reads `EXTCON_USB_HOST`, SDP, CDP, DCP, SLOW, and `EXTCON_USB`. A negative read returns before any value is treated as detached. USB-host mode returns before a write. For stored SDP, an already asserted CDP, DCP, or SLOW cable returns with no write; otherwise a missing SDP bit and a missing `EXTCON_USB` bit are written. For stored CDP, an already asserted SDP, DCP, SLOW, or `EXTCON_USB` bit returns with no write; otherwise a missing CDP bit is written and `EXTCON_USB` is left alone. A cable that already matches is not written again. The helper does not clear a contradictory cable. A successful write stores that cable in the function-static `cable` and sets `vbus_attached`, so the existing falling-edge path can clear the cable this helper published. A refused write leaves that cache alone. A failed `extcon_set_state_sync()` logs once with `dev_err_once` and does not log success. A repair logs one `dev_info`: `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER`. The 2-second schedule is unchanged. PHY `power_on` and `power_off` are unchanged.

The first revision could publish SDP or CDP beside a charger cable that was still asserted. That combination is reachable. `devm_extcon_dev_allocate()` is called with the cable list and no mutually exclusive mask, so the core accepts SDP together with CDP, DCP, or SLOW. The `B_IDLE` publish writes only the static `cable`, plus `EXTCON_USB` when that cable is SDP. The falling edge clears only that same id. `B_PERIPHERAL` on loss of VBUS does not clear extcon in that call. It moves to `B_IDLE` and schedules the worker immediately. If VBUS is present again on that next pass, the pass starts detection and returns before the edge compare, so the old bits and `vbus_attached` stay. Detection can then enter `B_PERIPHERAL` as SDP or CDP and skip the publish because the cached VBUS level already matches. The helper then sees the new internal type and the old extcon bits together. This driver never writes `EXTCON_CHG_USB_SLOW`, and the extcon state file is read-only, so SLOW is a guard for a registered cable rather than a path this file is shown to take. The SDP, CDP, DCP, and `EXTCON_USB` overlap does not have that excuse. The guard refuses the write. It does not clear the old cable.

Left unchanged: RK817 `0007`, `dr_mode = "otg"`, DWC3 clocks and resets, `maximum-speed`, USB-C pinctrl, `snps,dis_u2_susphy_quirk`, `snps,dis_enblslpm_quirk`, the MTP helper, the reaper, the upper host port, and suspend and shutdown.

### Static check

This static check did not run the function on the Flip. A host model of the guarded helper, compiled with `gcc -Wall -Wextra -Werror`, passed the cases below and a sweep of the SDP/CDP stored types against every combination of the six extcon bits. The sweep checks that a call never raises the number of asserted charger cables when one was already set, and that CDP never writes `EXTCON_USB`. That model is not the patched kernel. `patch -p1 -F0` reproduced the intended source from the unpatched 7.2.10 file. The target toolchain compiled `drivers/phy/rockchip/phy-rockchip-inno-usb2.o` in the build container. Buildroot then applied the same patch to a fresh Linux 7.2.10 tree, with no hunk offset, and compiled that file again. `strings` on `output/images/Image` contains `restored peripheral extcon %s` and `failed to restore peripheral extcon`.

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

`VERSION` in the tar is `dd0d717f331f` and `20261013`. The tar members `Image.gz`, `rk3566-miyoo-flip.dtb`, and `zlyme` match those hashes. Decompiled `usb@fcc00000` still has `dr_mode = "otg"`, `maximum-speed = "high-speed"`, `snps,dis_u2_susphy_quirk`, and `snps,dis_enblslpm_quirk`. It does not have `snps,dis-u2-freeclk-exists-quirk`. `usb@fd000000` is still `dr_mode = "host"` with `snps,dis_u2_susphy_quirk` and `maximum-speed = "high-speed"`. The upper EHCI node is unchanged. This OTA was later installed. Section 23 is that boot.

`zlyme-my355-20261013-07de7365fda6.tar`, SHA-256 `195ecc2fc9f563565a51ab696cbe61cc8405b38b270027cba4bc6be63a00cb6f`, is the first helper revision. It is superseded for testing. Do not install it.

### Predicted hardware result

When the PHY is already in a completed SDP or CDP peripheral session and the published extcon is empty, the existing worker writes the matching cable within one 2-second period. The `dev_info` line is the evidence that this path ran. A new detection that logs `sdp cable is connected` is the old publish path, not this one.

The patch does not choose SDP. A DCP result stays DCP. It does not make DWC3 enumerate. 12D-E17, SDP with `RUN_STOP` and endpoint 0 and no host device, stays open. The 17:00:49Z restart stays unexplained.

### Maintainer test

Copy `zlyme-my355-20261013-dd0d717f331f.tar` on the OS card. Do not send it over Wi-Fi, and do not install `zlyme-my355-20261013-07de7365fda6.tar`. Put the new tar in `/storage/.update/`. Newest `zlyme-my355-*.tar` wins, so remove older tars in that directory first. Check SHA-256 `7d600ea6cc604c9be2ae69ff9872431e606b02c86ff9c100060b365c55d036e0` on the card. Boot. `S18zlymeupdate` applies a queued tar and reboots. After that second boot, `uname -a` should show `7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. Do not flash SPI NAND and do not run `zlyme-update uboot`.

Start the host kernel journal and an `lsusb` poll before moving the cable, and keep a device `dmesg` or `/dev/kmsg` capture over that same interval. The two clocks need a shared note of when the cable moved. A host log from outside that interval does not score either gate.

Gate 1, extcon recovery. Leave USB File Transfer stopped. Enable dynamic debug only for `rockchip_usb2phy_otg_sm_work` and `rockchip_chg_detect_work`, so a fresh detection is visible. With the cable in the lower port, a pass is `restored peripheral extcon USB_SDP_CHARGER` or `USB_CDP_CHARGER` with no `chg detection work` sequence in front of it, and the sysfs cable matching that line. The host poll in that window should stay empty, because the gadget is stopped. `sdp cable is connected` after charger states 0 through 5 is a fresh detection and does not pass Gate 1. If the edge path already published and the restore line never appears, the stuck state did not occur. Replug and watch again. If another charger cable is already asserted, the helper is supposed to stay silent. Record that and do not clear it by hand. If the PHY stays DCP, stop and do not start the gadget.

Gate 2, enumeration. Run it only while SDP or CDP is actually present, whether that presence came from Gate 1 or from a later fresh detection. Keep the host journal and `lsusb` poll running from before USB File Transfer starts until the gadget is stopped. Sample `GUSB2PHYCFG(0)`, `DCTL`, `DSTS`, `DALEPENA`, and the UDC state during that interval. Bit 8 should still be clear. If the host sees `1d6b:0100`, copy one small file and then check B cleanup. If SDP or CDP never appears, Gate 2 stays untested.

12D-E20 followed this procedure for one cable cycle and did not replug again. The result is section 23.

## 23. Extcon and enumeration session

12D-E20, in the ledger above, is this hardware session. The image was the maintainer-installed OTA from section 22. No source file changed during the session.

### Installed image

`uname -a` was `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. At 18:20:04Z uptime was 173 seconds, so this boot started near 18:17:11Z. The same boot was still up at 18:45:51Z, uptime 1720. Live `usb@fcc00000` had `dr_mode = "otg"`, `maximum-speed = "high-speed"`, `snps,dis_enblslpm_quirk`, and `snps,dis_u2_susphy_quirk`. It did not have `snps,dis-u2-freeclk-exists-quirk`. `usb@fd000000` stayed `dr_mode = "host"` with `snps,dis_u2_susphy_quirk` only. `/usr/sbin/zlyme-usb-transfer` matched the tree copy, SHA-256 `09e933511df5daa53c9b4ba55fd0941a52df26f0638afa5475451fa39b8d0288`.

Stopped `fcc00000.usb` at 18:21:35Z, gadget not started:

| Register | Value | Reading |
| --- | --- | --- |
| `GUSB2PHYCFG(0)` | `0x40101408` | Bit 8 is 0. Bit 30, `U2_FREECLK_EXISTS`, is 1 |
| `GUCTL1` | `0x8504018a` | Bit 26 is `DEV_FORCE_20_CLK_FOR_30_CLK`, not the free-clock bit |
| `GSNPSID` | `0x5533300a` | DWC3 3.00a |
| `DCFG` | `0x00080804` | Bits 2:0 are 4, the SuperSpeed encoding, while the gadget has not started. This is not a lost high-speed cap |
| `DCTL` | `0x00f00000` | `RUN_STOP` is 0 |
| `DSTS` | `0x00d29f2c` | Stopped |

Lower extcon was USB=0, USB-HOST=0, SDP=0, CDP=0, DCP=1, SLOW=0. GRF `0x0000` was `0x00000dd1` and `0x00c0` was `0x003846c0`, the same words as the 12D-E18 DCP idle. IRQ 20 count was 0. RK817 was online with `usb_type` DCP. The helper was `state=off`. `nextui.elf` was running. The private debugfs mount was read-only and was unmounted in that command.

### Gate A

Dynamic debug was enabled only for the two workers. Before the cable moved, the worker logged `b_idle otg sm work` and `dcp cable is connected` every 2 seconds. That debug line sits in the DCP branch and is not gated on the VBUS edge. The extcon write below it still is. Extcon stayed DCP=1, so those lines are the idle DCP schedule, not a repeated publish.

The maintainer unplugged and replugged the lower cable once. At 18:31:29Z, uptime 857, extcon DCP went to 0, IRQ 20 went from 0 to 1, and RK817 `online` went to 0. At uptime 860.868 through 861.014 the log is charger states 0, 1, 2, and 5, then `b_idle`, then `sdp cable is connected` and `charger = USB_SDP_CHARGER`. By 18:31:33Z, uptime 862, extcon was USB=1, SDP=1, CDP=0, DCP=0. IRQ 20 was 2. The worker then logged `b_peripheral otg sm work` every 2 seconds and nothing else. A search of the capture finds zero `restored peripheral extcon` lines.

That sequence is a new BC1.2 pass, the same short path as 12D-E19, not a recovery of a cable the worker already knew. After the edge publish, SDP and `EXTCON_USB` were already set, which is the helper's no-write case. The empty-extcon `b_peripheral` loop from 12D-E19 did not occur on this boot, so the repair was not required and was not shown. This is not a failed restore.

With the gadget still stopped, GRF `0x0000` was `0x00000c00` and `0x00c0` was `0x00384e73`. Those match the 12D-E19 SDP sample. RK817 stayed online with `usb_type` DCP while the PHY reported SDP. That split is the 12D-E12 observation again.

### Gate B

SDP was still present at 18:34:35Z, helper `state=off`, UDC `not attached`, `nextui.elf` still pid 519. The maintainer opened USB File Transfer from NextUI. The presenter said MTP is on. The helper was not started from the SSH session.

At 18:36:23Z, uptime 1151:

| Item | Value |
| --- | --- |
| Helper | `state=bound`, responder running, exports for both cards' Roms and Bios |
| UDC | function `zlyme-mtp`, state `not attached`, speed `UNKNOWN` |
| Configfs | `idVendor=0x1d6b`, `idProduct=0x0100`, `UDC=fcc00000.usb`, `functions/ffs.mtp/ready=1` |
| FunctionFS | mounted at `/dev/ffs-mtp` |
| Watcher | `link.latch=connect`. No `link.writes` file and no `link.err` |
| Extcon | USB=1, SDP=1, CDP=0, DCP=0 |
| Processes | `launch.sh` pid 1949, reaper pid 2226, `umtprd` pid 3753, link watcher pid 3813, presenter pid 3880 |

`soft_connect` on `fcc00000.usb` is write-only. The watcher's first decision saw an endpoint state other than `failed` and set the latch to `connect` without writing. Debugfs was not mounted for that check, and the kernel log has no `failed to enable ep0out`, so the script's dmesg fallback returns unknown rather than failed. `DALEPENA` later showed EP0 enabled. `RUN_STOP` was already 1. The missing write is that no-toggle branch, the same shape as 12D-E17, not a rejected write.

Two active reads, 18:36:23Z and 18:41:48Z, under the host monitors:

| Register | 18:36Z and 18:41Z | Against 12D-E17 |
| --- | --- | --- |
| `GUSB2PHYCFG(0)` | `0x40101408` | 12D-E17 was `0x40101508`. The only difference is bit 8 |
| `GUCTL1` | `0x8504018a` | Unchanged |
| `DCFG` | `0x008e0800` | High-speed in bits 2:0. Device address bits are 0 |
| `DCTL` | `0x80f00000` | `RUN_STOP` set. Same value. Bits 23:20 are the NYET threshold |
| `DSTS` | `0x008e0001` | Same value. Connect-speed field 1, full-speed. Link field 3, which `dwc3_gadget_hs_link_string()` calls Suspend |
| `DALEPENA` | `0x00000003` | Same value. EP0 in and out enabled |
| EP0 | `ep0out` and `ep0in` read `control` at 18:41:48Z | Same as 12D-E17 |

The kernel log still begins at `Booting Linux`. It contains no `dwc3`, `fcc00000`, `ep0`, `FunctionFS`, or `configfs` line, and no `failed to enable ep0`. `umtprd.log` records the 18:35:32Z startup strings and no connection. During the gadget, GRF `0x0000` stayed `0x00000c00` and `0x00c0` was `0x00384e51`. Bit 6 of that word stays set, which is the VBUS-valid reading used for `0x00384e73` and `0x003840c8` in 12D-E19.

Demetria, from 18:27:53Z through 18:52:00Z, logged `no-gadget-id` on every `lsusb -d 1d6b:0100` sample. `lsusb` and `lsusb -t` at 18:36:29Z match the pre-PAK tree. `udevadm monitor` printed its banner and no USB event. `journalctl -k --since "2026-10-13 20:34:00"` at 18:41:48Z printed no entries. The follower's only later line is an amdgpu message at 20:50:21+02, after the gadget was already gone. No descriptor was read. No file was copied.

This is a gadget that started and a host that never saw a connection. `RUN_STOP` and EP0 do not make it an enumeration.

### What the registers do and do not explain

Supported by this session: the controller was running, the device address stayed 0, the link field stayed Suspend, and the host controller logged no connect. That is no host-visible connection while `RUN_STOP` was set.

Contradicted for this session: EP0 setup failure. Both directions were `control`, `DALEPENA` was `0x3`, and the enable error was absent. A host reset or a descriptor error is also contradicted, because the host log has no USB event to fail. A userspace failure to start the gadget is contradicted: configfs, FunctionFS, and `umtprd` were up.

Not isolated: PHY electrical signaling or the free-clock bit. Bit 30 of `GUSB2PHYCFG(0)` remained 1. The DTB does not clear it. Stock sets `snps,dis-u2-freeclk-exists-quirk`. Whether clearing that bit would change D+ and D- is not measured here, and this pass does not add the property.

### Cleanup

B returned NextUI. At 18:45:51Z the helper was `state=off`, the UDC function was empty, configfs had no gadget, and FunctionFS was not mounted. `umtprd`, `launch.sh`, the presenter, and the link watcher were gone. `nextui.elf` was pid 14589. Reaper pid 2226 was not running. `/run/zlyme/usb-transfer` still had `generation`, `jail`, `lock`, and the `reaper.*` files. Those are leftover files, not a live reaper. Dynamic debug was back to `=_` for both workers. No debugfs mount remained.

RK817 stayed online with `usb_type` DCP. Battery status stayed `Discharging` at capacity 100, which is the pre-test reading. `current_now` is not present, so this does not measure charge current. The upper EHCI bus had the internal Realtek WLAN `0bda:b733` and no added device. A separate upper-port peripheral and suspend/resume were not run. This boot did not restart.

Phase 12D stays open. Enumeration is not accepted. The next useful step is one electrical or host-port check that can show whether this cable and receptacle ever produce a connect, before any further controller property. The upper USB-C port is not that check. Its EHCI and OHCI controllers are host-only.

Status 2026-10-13 19:45Z: 12D-E21 did that port check on the same boot. The result is section 25. This paragraph stays the 12D-E20 conclusion.

## 24. Upstream RK3566 comparison

12D-E21 compared the lower port with the Linux 7.2.10 tree that this image builds. The tarball is `linux-7.2.10.tar.xz`, SHA-256 `2feaa70453e91f541be6a5c9078d8168e081af45a3d9718054850538cff2ebf3`. That extracted tree is not a separate git checkout, so this section cites the tarball and the file, not a kernel commit. Another board's DTS is not evidence that its gadget enumerates.

`rk356x-base.dtsi` describes `usb@fcc00000` as `rockchip,rk3568-dwc3` and `snps,dwc3` on one node. It sets `dr_mode = "otg"`, `phy_type = "utmi_wide"`, clocks `ref_clk`, `suspend_clk`, and `bus_clk`, the PIPE power domain, one reset, and `snps,dis_u2_susphy_quirk`. The node is disabled. It has no `phys`, no `extcon`, no `maximum-speed`, and no `usb-role-switch`. There is no glue child. `rk3566-base.dtsi` adds `phys = <&usb2phy0_otg>`, `phy-names = "usb2-phy"`, `extcon = <&usb2phy0>`, and `maximum-speed = "high-speed"`. Those are SoC properties. `rk3568.dtsi` gives the same controller `usb2phy0_otg` plus a USB3 combophy. The Flip is RK3566, so it does not inherit that second PHY.

The Flip board enables the node, repeats `dr_mode`, `extcon`, and `phys`, and adds `snps,dis_enblslpm_quirk`. It does not repeat `maximum-speed`. The running DTB still has `maximum-speed = "high-speed"`, which 12D-E15 already recorded and 12D-E21 read again. `usb2phy0_otg` has no `phy-supply`. The board file says the lower USB-C is charge and gadget and has no VBUS supply.

Quartz64-A sets this controller to `dr_mode = "host"`. Quartz64-B and ODROID-M1S enable it without a `dr_mode` override, so they inherit `otg`, and each gives `usb2phy0_otg` a 5 V `phy-supply`. ROCK 3A is RK3568: it sets `extcon` and a `phy-supply`, and it inherits the USB3 PHY. PineNote keeps `otg` and connects `usb2phy0_otg` through a port endpoint to a WillSemi WUSB3801 TCPC whose child is a `usb-c-connector` with dual power and data roles. That is a different connector arrangement. The Flip DTS has no `usb-c-connector`, and this pass does not add one.

Linux 7.2.10 has no `dwc3-rockchip` driver. `dwc3-of-simple` matches `rockchip,rk3399-dwc3` and does not match `rockchip,rk3568-dwc3`. The Flip node binds through `snps,dwc3`. The May 2025 stock excerpt uses a wrapper compatible with `rockchip,rk3568-dwc3` and `rockchip,rk3399-dwc3`, adds `pipe_clk`, and puts `snps,dwc3` on a child. Stock also sets `snps,dis-u2-freeclk-exists-quirk`. Stock enumeration was not captured.

`dwc3_hs_phy_setup()` runs from core init. It clears `SUSPHY` (bit 6). `snps,dis_enblslpm_quirk` clears `ENBLSLPM` (bit 8); otherwise the driver sets it. `snps,dis-u2-freeclk-exists-quirk` clears `U2_FREECLK_EXISTS` (bit 30). There is no sysfs or debugfs file that changes these bits on a live device. A DTS change needs a reboot. Among the RK3566 and RK3568 boards searched in this tree, `snps,dis_enblslpm_quirk` appears on the Flip and `snps,dis-u2-freeclk-exists-quirk` does not appear. The free-clock property does appear on other Rockchip SoCs. This pass does not add it.

The upper USB-C port uses EHCI and OHCI on `usb2phy1_otg`. Those controllers are host-only. They are not a substitute for the `fcc00000` gadget.

`CONFIG_USB_ROLE_SWITCH=y` does not create a switch by itself. `dwc3_setup_role_switch()` runs when the `usb-role-switch` property is present. The running Flip node does not have that property. `/sys/class/usb_role/` existed and was empty. Debugfs `mode` is writable on a dual-role build. 12D-E21 read it and did not write it. `soft_connect` is the UDC sysfs store in `drivers/usb/gadget/udc/core.c`. On DWC3, connect calls `dwc3_gadget_soft_connect()`, which is a driver reset and run sequence, not a userspace register write. `link_state` and `testmode` were not written.

| Difference | Relevance to 12D-E20 | Evidence | Runtime test | Risk if changed in DTS |
| --- | --- | --- | --- | --- |
| No host event while `RUN_STOP` and EP0 were up | Highest for 12D-E20. 12D-E21 did not reproduce it on bus 7 port 1 | Sections 23 and 25 | Done, without a rebuild | None for the reading |
| Flip lower OTG has no `phy-supply` and no Type-C connector | VBUS and SDP already worked in 12D-E20. 12D-E21 enumerated without adding either | Board DTS and PineNote `rk3566-pinenote.dtsi`. Confidence: high that the descriptions differ. Low that the missing node explains 12D-E20 | Not by copying another board's connector | A guessed connector can change charging and role |
| Direct `snps,dwc3` bind, no `pipe_clk` wrapper | The controller reached `RUN_STOP` in 12D-E20 and enumerated in 12D-E21 | Stock excerpt and `dwc3-of-simple.c`. Confidence: high for the source difference. Low that the wrapper was required | No supported runtime switch | A wrapper port is a kernel change and can change boot |
| `U2_FREECLK_EXISTS` still 1 | Not required for the 12D-E21 enumeration. The same `0x40101408` enumerated | `dwc3_hs_phy_setup()`, stock excerpt, sections 23 and 25. Confidence: high for the register. The bit is not a remaining blocker for this port | No. Probe-time only | Another image, with unknown suspend effect |
| `snps,dis_enblslpm_quirk` present | Bit 8 was already clear in 12D-E20 and stayed clear while 12D-E21 enumerated | Running DTB and `GUSB2PHYCFG(0)`. Confidence: high | Already measured | Do not stack more quirks onto it |
| `snps,dis_u2_susphy_quirk` inherited | Bit 6 of the measured word is 0. This matches the SoC DTS | `rk356x-base.dtsi` and the regdump. Confidence: high | Already present | Not an E21 change |
| Upper EHCI/OHCI | Not a gadget path | `rk356x-base.dtsi` and the Flip DTS. Confidence: high | Not attempted | Moving the gadget there is the wrong controller |

## 25. Host port and gadget session

12D-E21 is the ledger entry above. The boot is the 12D-E20 boot. At 19:17:21Z uptime was 3609. At 19:44:30Z uptime was 5238. `nextui.elf` was pid 14589 before USB File Transfer and pid 31236 after B. No reboot occurred.

At 19:17:40Z, with the gadget stopped, debugfs `mode` was `device` and `link_state` was `Disconnected`. `GUSB2PHYCFG(0)` was `0x40101408`, `DCTL` was `0x00f00000`, and `DALEPENA` was 0. GRF `0x0000` was `0x00000c00` and `0x00c0` was `0x00384e73`. For `usb2phy0` at `fe8a0000`, Linux 7.2.10 puts `utmi_bvalid` in bit 9 of `0x00c0`, `utmi_avalid` in bit 10, and `utmi_id` in bit 6. The OTG port has no `utmi_ls` field. The clocks `clk_usbphy0_ref`, `clk_usb3otg0_ref`, `clk_usb3otg0_suspend`, `aclk_usb3otg0`, and `clk_usbphy0_480m` were enabled. Runtime PM status was `active`, control was `on`, and the suspended time was 0. IRQ 20 count was still 2 from 12D-E20. No `dwc3` interrupt line was present while the gadget was stopped.

`modprobe usbmon` on Demetria returned `Operation not permitted`. No package was installed. The host record is the kernel journal, `udevadm monitor`, and `lsusb`.

The maintainer plugged a known device into the host receptacle and also into the Flip. At 21:22:04+02 Demetria enumerated a Genesys Logic USB 2.0 hub, `05e3:0608`, at high speed on `usb 7-1`. That bus had been empty. The Flip's USB device list afterwards had no added peripheral. The hub disconnected at 21:25:40+02. The Flip was put back in the original orientation. At 19:30:26Z the lower port was USB=1, SDP=1, DCP=0, and the UDC was `not attached`. Bus 7 stayed empty. The cable orientation was not reversed.

The maintainer opened USB File Transfer. At 21:31:49+02 Demetria enumerated `1d6b:0100`, product `Zlyme File Transfer`, at high speed on `usb 7-1`, with one MTP interface and three endpoints. Dolphin had `kio_mtp` and thumbnail workers on the device. `mtp-detect` found `1d6b:0100` at bus 7 device 3 and could not claim the interface because that client already held it. On the Flip at 19:35:24Z the helper was `state=bound`, the responder was running, FunctionFS `ready` was 1, the UDC was `configured` at `high-speed`, debugfs `mode` was `device`, and `link_state` was `On`. `DCTL` was `0x8cf00a00`, `DSTS` was `0x000a0ce0`, `DCFG` was `0x00ce0808`, and `DALEPENA` was `0x2f`. `GUSB2PHYCFG(0)` was still `0x40101408`. The watcher latch was `connect`. `link.writes` did not exist. At 19:36:10Z the `dwc3` interrupt count was 624 and IRQ 20 was 56. The controlled `soft_connect` cycle was not run: the gadget was configured and a client was reading it. 12D-E06 remains the older image, where the watcher did write `soft_connect` and the host still saw nothing.

B closed the PAK. Demetria logged `usb 7-1: USB disconnect, device number 3` at 21:37:55+02. At 19:40:47Z the helper was `state=off`, the UDC was `not attached`, SDP was still 1, and `nextui.elf` was pid 31236.

The mass-storage session then used the existing built-in configfs function. The writes were: mount configfs at `/sys/kernel/config`; create `/sys/kernel/config/usb_gadget/zlyme-e21-ms`; set `max_speed` to `high-speed`, `bcdUSB` to `0x0200`, device class fields to 0, `idVendor` to `0x1d6b`, `idProduct` to `0x0104`, and `bcdDevice` to `0x0100`; set manufacturer `Zlyme`, product `E21 mass storage`, and serial `e21-ro`; set configuration `bmAttributes` `0xC0`, `MaxPower` `2`, and configuration string `E21 read-only`; set `lun.0/ro` to 1 before setting `lun.0/file` to a 64 KiB mode `444` file on `/run`; link the function; write `fcc00000.usb` to `UDC`. `stall` was read as 0 and was not written. The vendor is the same Linux Foundation vendor as the MTP gadget. `0x0104` is the multifunction composite id, not MTP `0x0100`. The speed and power attributes match `make_gadget()` in `zlyme-usb-transfer`.

At 21:44:28+02 Demetria enumerated `1d6b:0104`, product `E21 mass storage`, serial `e21-ro`, at high speed. `usb-storage` attached it. The SCSI disk had 128 blocks of 512 bytes and write protect on. The backing file was a raw image with no filesystem. A desktop not mounting it is not a mount success or a mount failure. The result is the USB and SCSI enumeration. The Flip snapshot at 19:44:30Z showed UDC `configured`, function `zlyme-e21-ms`, speed `high-speed`, `lun_ro=1`, `mode=device`, `link=On`, `DALEPENA=0x0000000f`, and `GUSB2PHYCFG(0)` still `0x40101408`. The new `dmesg` lines are the mass-storage function banner and `LUN: removable file: (no medium)` from function creation, before the backing file was stored. The host inquiry is the record that the medium was visible.

The session exited on its own timer at 19:45:21Z. Cleanup wrote an empty `UDC`, removed the function link, the function, the configuration, the strings, and the gadget directory, deleted the image, and unmounted configfs. The recorded result was `cleanup_rc=0`, an empty UDC function, no gadget directory, the image removed, helper `state=off`, and `nextui.elf` still pid 31236. Demetria logged the disconnect of device 4 at 21:45:21+02. A later check found no `1d6b:0104` and no `sdb`. `/run/zlyme-e21-ms` was removed after these notes were copied. No debugfs `mode`, `link_state`, `testmode`, GRF, or PHY write occurred. No `soft_connect` write occurred.

Both gadgets produced a host connection. The failure in 12D-E20 is not specific to MTP on this receptacle, and it was not repaired by a `soft_connect` write. `GUSB2PHYCFG(0)` did not change between the silent session and these two enumerations. The supported difference is the host port: 12D-E20 never identified the receptacle, and 12D-E21 used bus 7 port 1 after that port had enumerated a hub. Which port 12D-E20 used is still unknown.

Phase 12D stays open. Enumeration happened. A matching file copy did not. The next step is that file copy on this same port. It is not another DTS quirk, not a DWC3 wrapper, and not a move to the upper host controllers.

## 26. Storage roots and retained patches, 2026-10-13

This section is a source change after 12D-E21. It is not a new hardware session and it does not change the 12D-E01 through 12D-E21 results. The installed image for 12D-E21 still shares ROM and BIOS directories. The tree after this note shares filesystem roots. That export is host-tested. It was not installed for 12D-E21, and no file round trip has been run.

`zlyme-usb-transfer` exports `/storage` as `ZLYME`, `/mnt/sd2` as `SD Card` when that library is mounted, and each mounted `/mnt/media/<name>` volume. `/boot` is excluded by the boot mount's source, or by `ZLYME_BOOT_DEVICE`, not by the filesystem label and not by `mmcblk` order. `.config`, `.logs`, and `.update` on `/storage` are inside that one share. `start` refuses while `/storage/.update/reconstruct` or `/storage/.update/pending/zlyme` exists. The private mount namespace stays. No kernel, DTB, PHY, or bootloader file was edited for this.

The first file check, if a supervised session is available, still belongs on the installed 12D-E21 image and the confirmed Demetria receptacle, bus 7 port 1. It is one disposable file in the existing ROM export, with hashes on both sides, and that file is the only one removed. It is not a test of the filesystem-root export. Installing the later image before that check makes the round trip a different experiment.

Patch classification for the Phase 12D USB changes, without removal:

| Change | Class | Why it stays |
| --- | --- | --- |
| `snps,dis_u2_susphy_quirk` | Upstream baseline | It comes from `rk356x-base.dtsi`. 12D-E21 did not add or remove it. |
| `snps,dis_enblslpm_quirk` | Experimentally retained | 12D-E18 applied it. 12D-E21 enumerated with `GUSB2PHYCFG(0)` bit 8 clear. That session does not prove the bit had to be clear. |
| `1015-phy-rockchip-inno-usb2-resync-peripheral-extcon.patch` | Experimentally retained, unexercised in 12D-E20 and 12D-E21 | 12D-E19 is the stale-extcon observation that motivated it. Enumeration without calling the repair does not make the repair obsolete. |
| `snps,dis-u2-freeclk-exists-quirk` | Not enabled | 12D-E21 enumerated while bit 30 stayed set. It is not a removal candidate because it was never added. |
| PMIC and off-current patches, including `0007` | Unrelated to this MTP export | They are not candidates for a storage-export change. |

A later A/B uses the same receptacle and the same cable. One image omits patch `1015` and keeps the LPM property. Another omits `snps,dis_enblslpm_quirk` and keeps `1015`. They are separate boots. Each one only asks whether MTP `1d6b:0100` enumerates at high speed on bus 7 port 1. This change does not build either image.

The product rebuild from `4a2b752bafbe` produced `zlyme-my355-20261013-4a2b752bafbe.tar`, SHA-256 `4767e45ffdf7ae7fa48e0c1b1d26a2fcdd50f762916d21119f53930b3ddbe08d`. When this section was written, that archive had not been installed. Its `Image.gz`, `rk3566-miyoo-flip.dtb`, `idbloader.img`, and `u-boot.itb` match the 12D-E21 OTA. The squashfs member contains the new `zlyme-usb-transfer`, `zlyme-usb-enter`, and USB File Transfer `launch.sh`. Section 27 is the later installation.

## 27. Installed root export, 2026-10-13

12D-E22 is the ledger entry above. The maintainer installed `zlyme-my355-20261013-4a2b752bafbe.tar`. The installed `/boot/zlyme`, `zlyme-usb-transfer`, `zlyme-usb-enter`, and USB File Transfer `launch.sh` match that archive. The kernel banner is the same 7.2.10 `#1` build as 12D-E21. `/etc/os-release` still says `zlyme44.2` and was not used as the identity.

The PAK log header is 21:05:32Z. The diagnostic connection began after `zlyme-usb-transfer status` already said `state=off`. The helper was not started over SSH. `/run/zlyme/usb-transfer` had already been removed, so the responder configuration, export list, skip list, and link latch were not available.

`/storage/.update` remains. `reconstruct` and `pending/zlyme` do not. A successful apply removes `pending` in the initramfs, so their absence is the expected leftover of a finished update. `/storage` is `/dev/mmcblk0p3` exfat and has no child mount. `/mnt/sd2` is `/dev/mmcblk1p1` ext4. `/mnt/media` is the empty `zlyme-media` tmpfs. The startup guards that refuse a staged update or a nested `/storage` mount did not refuse this boot: the kernel logged `dwc3 fcc00000.usb: failed to enable ep0out` at 26.788 seconds.

That EP0 line means the gadget was created and the responder had written far enough for the controller to try the control endpoint. The following lines are a SETUP timeout, a failed STALL, transfer error `-110`, and one unqueued EP0 request at 57.459 seconds. There is no other `dwc3` line on this boot.

At 21:22:22Z the UDC was `not attached`. extcon0 was USB=0, USB-HOST=0, SDP=0, CDP=0, DCP=1, SLOW-CHARGER=0. extcon1 was all zeros. DCP is a dedicated charger. 12D-E21 enumerated while SDP was 1. This reading is not that electrical state, and it was taken after the page had closed.

Demetria at the same minute had an empty `lsusb -d 1d6b:0100`. Bus 7, the 12D-E21 receptacle, had only its root hub. The kernel journal from 22:50 local through that minute has no `usb 7-`, `1d6b:0100`, or `1d6b:0104` line. The host did not record a connection or a disconnection for this Flip boot.

uMTP-Responder 1.8.1 stores a `storage` line without stating the directory. `storage "/storage" "ZLYME" "rw"` is not, by itself, a parse rejection. This session does not show the generated configuration, so it does not prove what the responder did with that line. It does show that the failure reached the kernel's EP0 path.

No exporter change or kernel patch follows from this reading. The tree's USB File Transfer introduction was shortened after the reading. That text was not on the installed image. Section 28 is the later watcher correction. It does not replace this observation.

## 28. Connection watcher, 2026-10-13

12D-E23 is the ledger entry above. It is a source reading and a userspace correction. It is not a Flip session, and it does not change 12D-E21 or 12D-E22.

`dwc3_transfer_type_show` in Linux 7.2.10 prints `control` when `DWC3_EP_ENABLED` is set and `usb_endpoint_type` is control. Otherwise it prints `--`. That file is the descriptor class. The old `link_once` treated `control` as healthy and returned before it looked at the PHY or the UDC. A UDC state of `not attached` could therefore be latched healthy, and a later change from DCP to SDP wrote nothing.

`soft_connect_store` calls `usb_gadget_udc_start_locked` and `usb_gadget_connect_locked`, then returns the write length. It does not return their results. `dwc3_gadget_pullup` returns without `dwc3_gadget_soft_connect` when the pull-up is already in the requested state. A shell write can succeed while the controller does not run endpoint setup again. Binding with no VBUS can log `failed to enable ep0out` from `__dwc3_gadget_start`. The old watcher recovered from that line only while debugfs did not say `control`.

The replacement uses three inputs. No SDP or CDP means one disconnect. A data cable after that idle state means one connect. `configured` and `suspended` are not disconnected by a later pass. One `failed to enable ep0out` for this bind, with SDP or CDP and a UDC that is not configured, gets one disconnect and one connect. A failed write is recorded and not repeated. The responder is not recreated. `loop_on_disconnect` stays 1, and uMTP's `FUNCTIONFS_DISABLE` path keeps the endpoint files open. `start` still binds the UDC after `ep1`, `ep2`, and `ep3` exist. `stop` still unbinds it. Exports stay `/storage`, `/mnt/sd2`, and mounted `/mnt/media/<name>` roots. uMTP 1.8.1 accepts `rw`, `ro`, and `removable` on a storage line and does not reject a filesystem root at parse time.

This does not say the old shortcut caused every silent session. 12D-E20 had `transfer_type` `control`, no `failed to enable ep0out` line, and SDP already present. The corrected watcher also leaves that first bind alone. 12D-E22 logged the enable error, and the DCP reading was taken after the page had closed.

The product rebuild from `13071973a350` is `zlyme-my355-20261013-13071973a350.tar`, SHA-256 `2f41f13de96f231bd8cf8f95cb01b7b2029c6cb17a0010779afb2692a2a89945`. Squashfs `/boot/zlyme` in that pack is `3747acda65ef1417b24df47cb1c34758750e00f8a3b6575de68e2b74de906b3e`. `Image.gz`, `rk3566-miyoo-flip.dtb`, `idbloader.img`, and `u-boot.itb` match the 12D-E21 OTA. The squashfs `zlyme-usb-transfer` is `f5a692fd5865f9cfce4a427b90144b3b60b69ceb0bf631bff677aeaf2acf37be`. `zlyme-usb-enter` is unchanged at `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. USB File Transfer `launch.sh` is `bf24365857f71c3c47a5122c82155bf6f5e02009b987e8565da6cd22186c7c18`, and its introduction is `Connect your computer to the lower USB-C port.` When this section was written, the archive had not been installed. A reading at 22:21:06Z the same day found it on the Flip. Section 29 is that reading. Host enumeration is still required. A file copy is still required after that.

## 29. Deferred UDC bind, 2026-10-13

12D-E24 is the ledger entry above. It separates three things that the later sessions had started to treat as one failure: the lower PHY classification, the moment the UDC is bound, and the filesystem-root export.

The installed userspace at 22:21:06Z is the 12D-E23 archive, not the 12D-E22 archive. `/boot/zlyme` is `3747acda65ef1417b24df47cb1c34758750e00f8a3b6575de68e2b74de906b3e`. `zlyme-usb-transfer` is `f5a692fd5865f9cfce4a427b90144b3b60b69ceb0bf631bff677aeaf2acf37be`. `zlyme-usb-enter` is `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. USB File Transfer `launch.sh` is `bf24365857f71c3c47a5122c82155bf6f5e02009b987e8565da6cd22186c7c18`. `zlyme-usb-transfer status` was `state=off`. The UDC was `not attached`. extcon0 was USB=0, USB-HOST=0, SDP=0, CDP=0, DCP=1, SLOW-CHARGER=0. That is a DCP classification. It is not proof that the cable was in a dedicated-charger receptacle, and it is not the SDP-before-launch state from 12D-E21. Demetria bus 7 had only its root hub. `lsusb -d 1d6b:0100` was empty. The kernel journal's only USB device in that window was `usb 5-1.1`, `05e3:0751`, which is not the Flip. The PAK was not started. No cable was moved. No DWC3 register dump was taken, because the gadget was not bound. `/run/zlyme/usb-transfer` was already absent.

The successful 12D-E21 order was: the lower PHY already reported SDP, the UDC was `not attached`, the PAK was launched from NextUI, DWC3 bound, and the host enumerated `1d6b:0100` at high speed. `link.writes` was not created. `GUSB2PHYCFG(0)` was `0x40101408`. The core kernel files have not changed since that session. This pre-start reading does not reproduce that order, so it does not test whether the installed image enumerates when SDP or CDP is already present.

Linux 7.2.10 `gadget_dev_desc_UDC_store` calls `usb_gadget_register_driver` before the configfs write returns. That path reaches `__dwc3_gadget_start`, which enables EP0 and can log `failed to enable ep0out` before `spawn_link` runs. `wait_ready` already requires FunctionFS `ep1`, `ep2`, and `ep3`, and uMTP writes those descriptors without a host. Postponing the UDC write does not require a change to uMTP-Responder, and it does not unbind and rebind for the initial wait. `soft_connect_store` still returns the write length and ignores the pull-up result, so a later disconnect/connect is not a reliable repair and it is not the 12D-E21 path.

The helper now leaves the responder running and the UDC unbound until the lower PHY reports SDP or CDP. DCP, no cable, and an unfinished classification stay in `state=waiting`. The PAK shows `Waiting for a USB data connection.` and B to stop. It does not treat waiting as a failed start. A missing extcon fails the start and is not called DCP. The watcher stays up while the gadget directory exists. It binds once when SDP or CDP appears, and that bind does not also write `soft_connect`. A UDC that is already `configured` or `suspended` is left alone, including when a later reading says DCP. If the host state leaves those values and the data cable is gone, one disconnect is written. A later data cable writes one connect. One EP0 enable error, while bound and not configured, still gets one recorded recovery. A failed write is not repeated. `stop` and MENU+START still remove a waiting session. The export list is unchanged: `/storage`, mounted `/mnt/sd2`, and mounted `/mnt/media/<name>`. No `/boot` path, no raw block device, and no change to the private mount namespace.

This reading does not show a filesystem-root failure. The PHY classification and the UDC state were taken with the gadget stopped. A ROM-directory comparison is not justified until a session with SDP or CDP already present, and this bind order, still fails to enumerate.

The host tests in `scripts/tests/test_usb_transfer.sh` and `scripts/tests/test_usb_link.sh` cover the waiting and bound paths with mocked sysfs. They do not open a USB controller. The target `umtprd` is aarch64. This host has no `qemu-aarch64` and no `functionfs` filesystem, so the real responder was not executed here. The generated configuration is still the one those tests check, and uMTP 1.8.1 does not reject a filesystem root at parse time.

The product rebuild from `7951a37668e3` is `zlyme-my355-20261013-7951a37668e3.tar`, SHA-256 `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`. Squashfs `/boot/zlyme` in that pack is `06b5f3577aea9ba45dc85c9763375a9e555283b40403f6d2623929c8ed8e712d`. `zlyme-usb-transfer` inside it is `15e2e682012eb08363a02e2c888814d524d5c7f32b34562cc81c2dc06f332557`. `zlyme-usb-enter` is unchanged at `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. USB File Transfer `launch.sh` is `fd7f9d58ef38d7a6b0411dff17951e10423fef68e3882213d0987a9b9fdbf766`. `Image` is `1bda9d4258b70f0e6e1693071344590189f1a49315dfac98805df95e5e145fed`. `Image.gz`, `rk3566-miyoo-flip.dtb`, `idbloader.img`, `u-boot.itb`, and `u-boot-rockchip.bin` match the 12D-E21 kernel generation. It had not been installed when this section was written. Section 30 records the later install.

## 30. Installed E24 acceptance

12D-E25 is the ledger entry above. The installed hashes match the E24 archive. The root loop's backing file is `/boot/zlyme`. `ZLYME` is `/dev/mmcblk0p3` on `/storage`. `ZLYMEBOOT` is `/dev/mmcblk0p2` on `/boot`, still read-only. `/mnt/sd2` is the ext4 card and is listed in `/run/zlyme/libraries`. No USB volume was mounted.

Demetria bus 1 port 2 enumerated `1d6b:0100` at high speed before the SSH start, and KIO then showed storage names `ZLYME` and `SD Card`. Object creation and copy failed with PTP `02ff`. No SHA-256 pair exists. The gadget disconnected at 01:05:24Z. The following boot, about 01:11:35Z, has no panic in `/boot/zlyme-dmesg.txt`. After that boot the lower PHY was all zeros, the battery read 99% and Discharging, and the charger `online` value was 0. RK817 `usb_type` still showed DCP while extcon0 was all zeros. Those are different reporters.

The other Phase 12 checks from this boot are inspections, not acceptance of behavior. NextUI was running and its maps include `/dev/mali0`. `mali_kbase` was loaded. `panfrost` was not. The PanVK ICD file is installed. It was not opened. `/proc/config.gz` has `CONFIG_MMC_TEST`, `CONFIG_SND_TEST_COMPONENT`, and `CONFIG_SND_AUDIO_GRAPH_CARD2_CUSTOM_SAMPLE` unset. Module vermagic is `7.2.10 SMP preempt mod_unload aarch64`. One `ntpd` was running. `zlyme-led watch` was running. The panel node was connected and enabled. ALSA had `rk817_ext`. The input names included the Miyoo Flip gamepad and a virtual Xbox 360 pad. DMC was `powersave` at 324 MHz. None of those were changed, and none of audio, buttons, picture, or charging was exercised. Mali logged a workqueue warning at 3.64 seconds and then probed as `mali0`. There is no pending update. `/storage/.config/zlyme/ssh.password` is absent, so a saved-password reboot was not available to test. No password was set or cleared.

Host tests that passed the same morning are named in the evidence file. They do not open the Flip. A PortMaster launch, a 0% shutdown, a clock step, and the updater screen were not run on the device.

The next file check needs SDP or CDP on the receptacle that enumerated, the same MTP client, and a SHA-256 on both sides. It does not need a new image. It has not been started again after the reboot.

Clarification, 2026-10-14: the maintainer reports that the cable was disconnected during 12D-E25. The evidence file is unchanged. The 01:05:24Z host disconnect is not identified as that action. After it, `usb 1-2` kept attempting to enumerate and logged descriptor errors. A storage name on the computer was not a confirmed file. The restart remains unexplained, and it is not attributed to the Mali warning or to the cable report.

12D-E26, later the same day and on the following boot, recorded the file match. Section 32. It does not close the 12D-E25 restart.

## 31. MTP reduction candidates

This section is a plan. Nothing in it was removed, rebuilt, or retried.

The working comparison for a later pass is the E24 image, Demetria bus 1 port 2, the cable that enumerated on 2026-10-14, KIO or libmtp, the filesystem-root exports, and a SHA-256 of a disposable file in both directions. Each candidate keeps that image, or a newer image built only to drop that one candidate, as the rollback. A candidate that was not on the path of one successful enumeration is not obsolete.

| Candidate | Why it is here | What 12D-E25 did with it | Removal risk |
| --- | --- | --- | --- |
| `snps,dis_u2_susphy_quirk` | Inherited USB2 suspend-PHY quirk. | Present. Not isolated. | Highest. Leave it until the others have a rollback that still enumerates. |
| Deferred UDC bind and the SDP/CDP watcher | E24 waits for a data cable before `usb_gadget_register_driver`. The watcher binds once. | One `bind` line after SDP was already 1. Enumeration happened on this image. | High. This is the image that enumerated, and 12D-E26 matched a SHA-256 on it. Dropping it returns to the earlier bind-at-start path. Leave it until B cleanup is recorded on this image. |
| `1015-phy-rockchip-inno-usb2-resync-peripheral-extcon.patch` | Experimental resync of the peripheral extcon. | Not shown to run. Ordinary detection can publish SDP without it, as in 12D-E20. | Medium. One quiet session does not prove it is unused. |
| `snps,dis_enblslpm_quirk` | Experimentally retained. 12D-E21 enumerated with `GUSB2PHYCFG(0)` bit 8 clear. | Not read in this pass. | Medium. E21 does not prove the bit had to be clear. |
| EP0 recovery and `soft_connect` | One disconnect plus one connect after `failed to enable ep0out`. A failed write is not repeated. `configured` and `suspended` are not written. | No `failed to enable ep0out` in the lines read after the SSH start. `link.recover` was not present. Unplug was not tested. | Medium for the unplug path. The steady configured path already avoids a gratuitous write. |
| debugfs `transfer_type` | Old health check. | Not used. `ep0_failed` reads `dmesg`. | Low as a runtime dependency. The comment that rejects it should stay until the recovery path is the thing under test. |
| Filesystem-root export and `zlyme-usb-enter` | The share. Private mount namespace, `O_NOFOLLOW`, non-recursive clone. | Names were listed. Bytes were not copied. Confinement was not re-probed on the device. Host confinement tests passed. | Not a link simplification. Removing it changes the product. |

The first A/B, when a file hash has already passed on this image, is one candidate at a time. The rollback is this OTA, written to the card from the host, not over Wi-Fi. Do not combine the quirk, the extcon patch, and the watcher in one image.

12D-E26 later recorded matching SHA-256 values in both directions on this image, including one file on the mounted ext4 card. The responder mount namespace contained `/storage`, `/mnt/sd2`, the configuration file, FunctionFS, and the responder binary. It did not contain `/boot`. Section 33 records the stopped session. No candidate is removed in that section.

## 32. PAK MTP file match

12D-E26 is the ledger entry above. The installed image is still the E24 archive. `/boot/zlyme` at 02:17:07Z is `06b5f3577aea9ba45dc85c9763375a9e555283b40403f6d2623929c8ed8e712d`, and `/boot` stayed read-only.

The session was already open. Demetria bus 1 port 2, PCI `0000:c4:00.3`, had device 48, `1d6b:0100`, at high speed from 01:50:17Z. The helper was `bound`, the UDC was `configured` at high speed, and extcon0 reported SDP. KIO was the only MTP client. It listed `ZLYME` and `SD Card`. `ZLYMEBOOT` was not a storage. No USB stick was mounted.

A 4096-byte file and a 1048576-byte file copied from Demetria to `/storage` matched SHA-256 on the Flip. A 4096-byte file created on the Flip matched after KIO copied it back. The same 4096-byte hash matched on `/mnt/sd2`. Rename kept the hash. Delete removed both test directories. PTP `02ff` did not recur. The boot id did not change. B was not pressed, and the gadget was still bound at 02:21:00Z.

The pairs, the namespace, and the earlier `ep0out` line from this boot are in `docs/research/evidence/usb-mtp-phase12d/20261014T020236Z-e26-file-match.txt`. This match does not explain the 12D-E25 restart, and it is not Phase 12 acceptance. Section 33 records the later reading of the stopped session.

## 33. Stopped session

12D-E27 is the reading after the maintainer left the 12D-E26 session. The maintainer accepts the E26 file match and reports that a second Start and MENU+START succeeded. Those two reports are not tied to a host connect line. Demetria logged `usb 1-2` device 48 disconnecting at 02:26:43Z and no later device on that port. At the following Flip reading, `zlyme-usb-transfer status` was `off`, `fcc00000.usb` was `not attached`, configfs was not mounted, FunctionFS was not mounted, and no `umtprd` or watcher process remained. `/storage` and `/mnt/sd2` stayed mounted. `/boot` stayed read-only. `nextui.elf` was running. The boot id was still `6b0451a8-3c6d-42bc-ac50-2ddc73c6037c`. Stale reaper files under `/run/zlyme/usb-transfer` name pid 22803, which was not running. `state=off` does not treat them as a session. The local E24 archive still hashes to `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`.

The E26 hashes are the MTP file baseline for later A/B images. The archive above is the rollback. A second enumeration after the disconnect was not captured, so the maintainer's second Start is not rewritten here as a logged host session.

| Piece | In the E26 session | Role |
| --- | --- | --- |
| Deferred UDC bind | One `bind`, then `configured` at high speed | The start order on this image. Leave it. |
| SDP/CDP wait | extcon0 was SDP=1 before the copies | Binds only for a data cable. DCP and no cable wait. Leave it. |
| `soft_connect` after the UDC leaves `configured` | `link.writes` contained `disconnect` and `connect` during bring-up. No timed unplug was recorded | One disconnect when the data cable is gone, one connect when it returns. Leave it. A configured session is not written. |
| EP0 recovery | No `failed to enable ep0out` and no `link.recover` during the matched copies | One `soft_connect` disconnect plus one connect after that kernel line. Separate from the cable path. Earlier sessions did log the enable error. Removal is a hypothesis. |
| dmesg scan for that line | Present. debugfs `transfer_type` is not the check | Feeds the recovery decision only. |
| Responder, FunctionFS, configfs ownership | Running, then gone after the disconnect | Required for the session and for cleanup. |
| Export jail | `/storage` and `/mnt/sd2` only. No `/boot` | The share. Leave it. |
| Patch `1015`, `snps,dis_enblslpm_quirk`, `snps,dis_u2_susphy_quirk` | Not isolated in E26 | Not removed because they were quiet. |

## 34. EP0 recovery removal, installed

`52e84b069d9aacde39ca7a95c38be78a4d4746b1` removes `ep0_failed` and the one disconnect-then-connect that followed `failed to enable ep0out`. The deferred bind, the SDP/CDP wait, the single disconnect after a configured session loses its data cable, and the single connect when that cable returns are still there. `soft_connect` is not written while the UDC is `configured` or `suspended`. The jail and the export list are unchanged. Host tests, including the mocked enable-error case, pass and do not open a USB controller. Patch `1015` and the LPM quirks are unchanged.

When this section was first written, `zlyme-my355-20261014-d4feee1e9e08.tar` had not been installed. The maintainer later installed that archive from the card and reports that USB File Transfer works. That sentence is the maintainer's report. This reading did not copy a file, so it does not add a SHA-256 pair. The archive hashes to `0bf1e16c24c132fb6ffc98afbfb2eba5e5c7d9e7c800f3722b139102b291f5b6`. The Flip `/boot/zlyme` hashes to `d35d18971158d6724d7a73523b7644763cc84e302723ac0860cb5028452a8f19`. The live helper hashes to `30f8d89fdd98a42857ecad753bbfc650720f3f17d5d2254360fd21caacd2b9b6`. `uname` is `Linux zlyme 7.2.10 #1 SMP PREEMPT Tue Oct 13 18:02:11 UTC 2026`. At that reading `zlyme-usb-transfer status` was `off`, Demetria had no `1d6b:0100`, and the boot id was `3c3ebcc5-7d49-4c5b-a86b-a5da35f344cd`. That boot's dmesg has no `restored peripheral extcon` line. The line is `dev_info` and appears only when the helper changes an extcon bit, so its absence does not show that patch `1015` was skipped. The E24 archive is still `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`. The E26 file hashes remain the instrumented baseline.

The comparison, after that candidate is installed from the card, uses the same cable, the same Demetria receptacle (bus 1 port 2, PCI `0000:c4:00.3`), KDE's MTP client, and the USB File Transfer PAK:

1. Start with the cable already connected. Expect `1d6b:0100` at high speed and UDC `configured`.
2. Copy one disposable file to `/storage` and compare SHA-256.
3. Copy one disposable file back and compare SHA-256.
4. If `SD Card` is listed, copy one small file and compare SHA-256.
5. Press B and confirm the gadget is gone.
6. Open the PAK again without moving the cable and confirm a new enumeration, then stop.
7. In a separate idle session, unplug once and plug back in. Confirm it enumerates again without a controller reset.

Those steps were not run in the install reading. The maintainer's report is not that list. Keep the responder log and any `failed to enable ep0out` line if a later session is instrumented. If this image fails where the E24 archive succeeds on that same cable and receptacle, put the recovery back. The maintainer's report does not retire patch `1015` or the LPM quirks.

## 35. USB2 PHY extcon resync, installed

12D-E29 removes only `1015-phy-rockchip-inno-usb2-resync-peripheral-extcon.patch`. No renamed copy remains in the patch directory. Deferred UDC binding, the SDP/CDP wait, cable `soft_connect`, the gadget identity, uMTP, the export list, the jail, RK817, Linux 7.2.10, the kernel configuration, U-Boot, and the preloader are unchanged. `snps,dis_enblslpm_quirk` stays on the lower DWC3 node. `snps,dis_u2_susphy_quirk` stays in `rk356x-base.dtsi`. The compiled DTB hash is the same as the installed image.

`./build.sh --config zlyme_my355_defconfig linux-dirclean` removed `output/build/linux-7.2.10`. The product build then extracted `linux-7.2.10.tar.xz` and applied the remaining patches. The log applies `1013` and then `9901`. It does not apply `1015`. After that extract, `drivers/phy/rockchip/phy-rockchip-inno-usb2.c` has no `rockchip_usb2phy_resync_peripheral_extcon`. In `OTG_STATE_B_PERIPHERAL`, loss of VBUS returns to `B_IDLE` and powers the PHY off. While VBUS stays, that state only reschedules. Linux master, fetched 2026-10-14, has that same branch and does not publish extcon from it. `B_IDLE` still writes SDP, CDP, or DCP only when `vbus_attached` changes and `notify_charger` is set. A charger state between `UNDEFINED` and `DETECTED` stores the VBUS level with `notify_charger` clear, so the later `DETECTED` pass can enter `B_PERIPHERAL` with the edge already consumed.

The helper was the only extcon write inside `B_PERIPHERAL`. It republished a stored SDP or CDP result. It did not rerun BC1.2 and it did not change PHY power. DCP stays in `B_IDLE` and does not call it. `A_HOST` does not call it. The same driver file serves `fe8a0000.usb2phy` and `fe8b0000.usb2phy`. The call site is the OTG worker only.

12D-E19 measured `b_peripheral` with VBUS present and extcon zero, on an image that did not have this helper. That condition is observed. The 12D-E19 and 12D-E20 replugs published SDP through `sdp cable is connected`. 12D-E20 had the helper and did not log `restored peripheral extcon`. The installed boot read for 12D-E28 also has no such line, and the helper was off. The info line is logged only when a bit changes, so a quiet log does not show that the function was skipped. Whether a cold start on the unpatched image publishes SDP is untested. Whether upper-port host, Wi-Fi, charging, or suspend change is untested. The code path for those does not call the helper.

`phy-rockchip-inno-usb2.o` was compiled at 11:08:49 +0200. `vmlinux` was linked at 11:09:06 +0200. `nm` on that object has no resync symbol. `strings` on the new `Image` has no `restored peripheral extcon`. The previous `Image`, SHA-256 `1bda9d4258b70f0e6e1693071344590189f1a49315dfac98805df95e5e145fed`, contains that string. The new `Image` is `e54daf5c4fde61c2d6e8c79cb180d14b1e423ba45c9f2100eaa20a08c29a404b`. `Image.gz` is `affdb99bcae1bf32127d0c51249a5a7ef810ed59fcc34c6da705f3a5335f1b38`. The kernel release is `7.2.10`. `CONFIG_PHY_ROCKCHIP_INNO_USB2=y`. Extracted configuration from the new `Image` and from the installed image's `Image.gz` matches. `Module.symvers` matches the copy saved before `linux-dirclean`. `mali_kbase.ko`, `miyoo-flip-gamepad.ko`, `rk3568_dmc.ko`, `8733bu.ko`, and `rtl8733bu_power.ko` were not rebuilt. Their vermagic is `7.2.10 SMP preempt mod_unload aarch64`, the same string as this kernel and as the in-tree `panfrost.ko` built in this run.

The squashfs is `a73d6198e1509e7e5ad05c80322bcfaaf28716fd9ad8e34293667479e8a2d1dd`. Inside it, `zlyme-usb-transfer` is `30f8d89fdd98a42857ecad753bbfc650720f3f17d5d2254360fd21caacd2b9b6`, `zlyme-usb-enter` is `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`, and the USB File Transfer `launch.sh` is `fd7f9d58ef38d7a6b0411dff17951e10423fef68e3882213d0987a9b9fdbf766`. The DTB is `cbb249cd244b32595c29d3df61cd968b7cd6e0533085072549f78b14280eefed`. `idbloader.img` is `2d714dff7b1af96dabcbc172c269276f36f6409afa3c9f7940addce0ca6af380`. `u-boot.itb` is `0e2a5e6ed9d669401ee43a3df58cc8613797118bca435b830f14a8342b87ee56`. `u-boot-rockchip.bin` is `9b5d9a4819e1865a4c24de30315b1d61a10f601b626bdc7b64e933f49f4f95d8`.

The archive is `output/images/zlyme-my355-20261014-97fbcfb253c1.tar`, SHA-256 `af6a54666715b8cb41fe1c4a477a6270d04189462746550f406896b3435af95d`, from `97fbcfb253c11200d70df05a5b180367a7da9ac6`. When this section was first written, that archive was not installed. `zlyme-my355-20261014-d4feee1e9e08.tar` and `zlyme-my355-20261013-7951a37668e3.tar` stay in `output/images` with their previous hashes.

Install it from the card. Use the same cable and the Demetria receptacle on bus 1 port 2, PCI `0000:c4:00.3`. Start the host log and the device log before opening the PAK. Do not write VBUS, a USB role, or a regulator. Do not force suspend.

Test A, cable already connected:

1. Read the lower PHY. Expect SDP or CDP.
2. Open USB File Transfer.
3. Expect `1d6b:0100` at high speed and UDC `configured`.
4. Expect the host to list ZLYME and SD Card.
5. Copy one disposable file to ZLYME and compare SHA-256.
6. Copy one file back and compare SHA-256.
7. If the second card is present, copy one small file to SD Card and compare SHA-256.
8. Press B and confirm the gadget, FunctionFS, and responder are gone.

Test B, cable left in place: open the PAK again, confirm a new enumeration and host access, then stop.

Test C, one unplug and one replug during an idle session: record the extcon bits before the unplug, the transition after it, and the bits after the replug. Expect MTP to return without a reboot or a host-controller reset. A pass after the replug does not show that a cold start publishes SDP.

Test D: charging on the lower connector, the upper USB host with a known device if one is available, Wi-Fi after a reboot, both cards, NextUI, and the absence of new PHY, DWC3, or PMIC faults.

If this image fails where the installed 12D-E28 image succeeds on that cable and receptacle, restore the patch. A pass covers the scenarios that were run. It is not a general reliability result.

Installed 2026-10-14. The maintainer installed `zlyme-my355-20261014-97fbcfb253c1.tar` from the card and reports that MTP works, including file copying, cleanup, and the other operations that were tried. That report is the maintainer's. This reading did not copy a file, so it adds no SHA-256 pair. The E26 hashes remain the instrumented file baseline.

The Flip `/boot/zlyme` hashes to `a73d6198e1509e7e5ad05c80322bcfaaf28716fd9ad8e34293667479e8a2d1dd` and is the backing file of the read-only root loop. `/boot/Image.gz` hashes to `affdb99bcae1bf32127d0c51249a5a7ef810ed59fcc34c6da705f3a5335f1b38`. `/boot/rk3566-miyoo-flip.dtb` hashes to `cbb249cd244b32595c29d3df61cd968b7cd6e0533085072549f78b14280eefed`. `uname` is `Linux zlyme 7.2.10 #1 SMP PREEMPT Wed Oct 14 09:09:00 UTC 2026`. Decompressing that `Image.gz` and searching for `restored peripheral extcon` returns no match. `snps,dis_enblslpm_quirk` and `snps,dis_u2_susphy_quirk` are both present on `/proc/device-tree/usb@fcc00000`. Boot id `43ef641a-5ae8-4142-a8b5-15e129eb44ea`.

After the last host disconnect, `/boot` was read-only vfat, `/storage` was read-write exfat, and `/mnt/sd2` was read-write ext4. Configfs had no gadget directory. `fcc00000.usb` was `not attached`. No `umtprd` and no `zlyme-usb` process were running. `nextui.elf` was pid 491. `zlyme-usb-transfer status` did not return in this pass, so the pieces above are the cleanup reading.

Demetria bus 1 is PCI `0000:c4:00.3`. Its kernel log, in local time UTC+2, shows five high-speed `1d6b:0100` enumerations named Zlyme File Transfer on `usb 1-2`, and a disconnect after each: device 7 at 11:18:24–11:20:17, device 8 at 11:23:57–11:24:37, device 9 at 11:25:10–11:28:52, device 10 at 11:34:14–11:34:21, and device 11 at 11:34:54–11:47:01. Those lines do not include a descriptor error, a reset, or a failed enumeration. They do not show which button ended each session, and they do not show file bytes. At 11:51 local, `lsusb -d 1d6b:0100` was empty. This is a hardware-exercised image for the reported operations. It is not a measurement of every PHY transition.

## 36. ENBLSLPM property, candidate

12D-E30 removes only `snps,dis_enblslpm_quirk` from `&usb_host0_xhci` in `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`. `dr_mode = "otg"`, `extcon = <&usb2phy0>`, `phys = <&usb2phy0_otg>`, and `phy-names = "usb2-phy"` stay. `snps,dis_u2_susphy_quirk` stays in `rk356x-base.dtsi`. Patch `1015` stays absent. The MTP helper, the jail, RK817, U-Boot, and the preloader are unchanged.

Linux 7.2.10 `dwc3_get_properties()` reads the property into `dis_enblslpm_quirk`. `dwc3_hs_phy_setup()` clears `DWC3_GUSB2PHYCFG_ENBLSLPM`, which is `BIT(8)`, when the flag is set, and sets that bit otherwise. `DWC3_GUSB2PHYCFG_SUSPHY` is `BIT(6)` and follows `snps,dis_u2_susphy_quirk`. The binding example lists the two properties as separate booleans. The kernel comment says the ENBLSLPM quirk clears the suspend signal to the PHY. The host-role suspend path sets both bits when either quirk is set, then clears ENBLSLPM on resume only when this quirk is set. The lower controller's gadget role does not take that host branch. Removing the property restores the stock set of bit 8 at PHY setup. It does not change bit 6.

12D-E17 measured `GUSB2PHYCFG(0) = 0x40101508` before the property, with the gadget running and Demetria silent. 12D-E18 measured `0x40101408` after the property. The XOR is `0x100`, bit 8. 12D-E20 kept bit 8 clear and still did not enumerate. Later MTP sessions, including the installed 12D-E29 image, worked with the property present. That does not show the clear bit was required. A register value belongs to the controller state in which it was read.

`linux-rebuild` recopied the board DTS. The copy matches the board file. `rk3566-miyoo-flip.dtb` was compiled at 12:01:16 +0200. `dtc -s` of that blob against the 12D-E29 DTB differs by one line: `usb@fcc00000` no longer has `snps,dis_enblslpm_quirk`, and it still has `snps,dis_u2_susphy_quirk`, `dr_mode = "otg"`, `maximum-speed = "high-speed"`, `phy-names = "usb2-phy"`, `phy_type = "utmi_wide"`, and the same `phys` and `extcon` phandles. No other node moved.

The same rebuild relinked `Image`. The C files compiled in that run were `init/version.o`, `init/version-timestamp.o`, and `drivers/gpu/drm/panel/panel-generic-dsi.o`. The pre-build hook recopies the panel file and regenerates the version headers. The new `Image` is `07601d1bd80168a133968bdf5c7efd6b8632883ec716ae81732106902e6c215d`, 26273800 bytes, the same length as the 12D-E29 `Image`. Sixty-six bytes differ: the compile-user token `d1a099486495` became `5d81166beb6b`, the build count `#1` at 09:09:00 became `#2` at 10:01:20 UTC, and one 20-byte build id changed with that relink. Extracted kernel configuration matches. `strings` has no `restored peripheral extcon`. `Image.gz` is `8b5ceb6dec96b998904afef3a5cb6e87ee020eb157a1b2e1ca25ec8a0ea0d938`, and decompressing it returns the new `Image`. The product build did not compile the kernel again.

`mali_kbase.ko`, `miyoo-flip-gamepad.ko`, `rk3568_dmc.ko`, `8733bu.ko`, and `rtl8733bu_power.ko` keep their 13 October timestamps. Vermagic is `7.2.10 SMP preempt mod_unload aarch64`, the same string as this kernel. The bootloader hashes match 12D-E29. The squashfs is `a568584c4ff9b4fad976ac126bb63bb923dd19c47f027e94eaa8b83d95a27bce`. Inside it, `zlyme-usb-transfer` is `30f8d89fdd98a42857ecad753bbfc650720f3f17d5d2254360fd21caacd2b9b6`, `zlyme-usb-enter` is `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`, and the USB File Transfer `launch.sh` is `fd7f9d58ef38d7a6b0411dff17951e10423fef68e3882213d0987a9b9fdbf766`. The DTB in the archive is `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18`.

The candidate is `output/images/zlyme-my355-20261014-7caa0871a82f.tar`, SHA-256 `2113ee676428eeede198e9aa21a422d3dedebd1bf0112112d880f82a3e7248ea`, from `7caa0871a82f784ffd8889face036fd3955cbf8f`. When this section was first written, that archive was not installed. The 12D-E29, 12D-E28, and E24 archives are still present with their previous hashes. Host tests printed `usb transfer ok`, `usb link ok`, and `post-build config ok`. They do not open the Flip. Section 37 is the later install reading.

Install it from the card. Use the same cable and Demetria bus 1 port 2, PCI `0000:c4:00.3`. Do not write a DWC3 register, VBUS, a USB role, or a regulator. Do not force suspend or a low-battery shutdown.

After boot, compare the squashfs and DTB hashes. Expect Linux 7.2.10, no `snps,dis_enblslpm_quirk` on `usb@fcc00000`, and `snps,dis_u2_susphy_quirk` still present. `fcc00000.usb` is the UDC. Where the existing read-only debugfs method is available, read `GUSB2PHYCFG(0)` once in a comparable idle state and record bit 8. Do not write it.

With the cable already connected, open USB File Transfer. Expect SDP or CDP, high-speed `1d6b:0100`, and UDC `configured`. Copy one disposable file to `/storage` and one back, and compare SHA-256 both ways. Check SD Card if it is present. Press B and confirm cleanup. Leave the cable, open the PAK again, confirm a new enumeration, and stop. On a separate idle session, unplug once and plug back in once. Record the extcon bits. One failed transition is a failure. Leave an ordinary idle interval before the final stop and confirm the session is still usable. Also check lower-port charging, the upper host if a device is available, Wi-Fi, NextUI, both cards, and the absence of new DWC3, PHY, or PMIC warnings.

If this image fails where the installed 12D-E29 image succeeds on that cable and receptacle, restore the property and keep 12D-E29 as the rollback. A pass means clearing bit 8 was not required for the scenarios that were run. It is not a long-term reliability result. The next source audit, if this passes, is the userspace connection watcher. `snps,dis_u2_susphy_quirk` stays until its own pass.

## 37. ENBLSLPM property, installed, coverage open

12D-E31 reads the installed 12D-E30 archive on boot id `6a14efb9-ee1b-47ee-80d3-c75bd6bd9799`. `btime` 1791973075 is 10:17:55Z. At 10:36:52Z the uptime was 1138.25 seconds, the same boot. `/boot/zlyme` hashes to `a568584c4ff9b4fad976ac126bb63bb923dd19c47f027e94eaa8b83d95a27bce`. `/boot/Image.gz` hashes to `8b5ceb6dec96b998904afef3a5cb6e87ee020eb157a1b2e1ca25ec8a0ea0d938`. `/boot/rk3566-miyoo-flip.dtb` hashes to `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18`. `uname` is `Linux zlyme 7.2.10 #2 SMP PREEMPT Wed Oct 14 10:01:20 UTC 2026`. The local archive hash is still `2113ee676428eeede198e9aa21a422d3dedebd1bf0112112d880f82a3e7248ea`. The 12D-E29 archive is still `af6a54666715b8cb41fe1c4a477a6270d04189462746550f406896b3435af95d`.

`/proc/device-tree/usb@fcc00000` lists `snps,dis_u2_susphy_quirk` and does not list `snps,dis_enblslpm_quirk`. `dr_mode` is `otg`, `maximum-speed` is `high-speed`, and `phy-names` is `usb2-phy`. The extcon phandle is `0x15` and the phys phandle is `0x14`, the same values as the sorted 12D-E30 decompile. A stopped debugfs read of `GUSB2PHYCFG(0)`, taken twice and unmounted afterward, is `0x40101508`. Bit 8 is 1. Bit 6 is 0. The with-property word was `0x40101408`. No register was written.

This boot has no `fcc00000` dmesg line. The WARNING count is 0 and the taint is 4096. `mali_kbase`, `panfrost`, `rk3568_dmc`, `8733bu`, `rtl8733bu_power`, and `miyoo_flip_gamepad` are loaded. Vermagic on the five out-of-tree modules is `7.2.10 SMP preempt mod_unload aarch64`. `wlan0` is up. `nextui.elf` is pid 513. `/boot` is read-only vfat, `/storage` is read-write exfat, and `/mnt/sd2` is read-write ext4. The battery reads Discharging at capacity 100. The charger is online with RK817 `usb_type` `Unknown [DCP]`, while extcon0 reads USB=1 and SDP=1. Flip `lsusb` shows the onboard WLAN and the root hubs. No upper-port peripheral was attached.

`zlyme-usb-transfer status` returned `state=off`. The UDC was `not attached`. Nothing held `/run/zlyme/usb-transfer/lock`. The 12D-E29 status command that returned no output is not reproduced. That command also sat in a window of SSH banner timeouts. This pass did not capture a holder, and it does not treat that stall as disproven. The helper still takes a blocking `flock` on that file. The responder, the reaper, and the link watcher are started with that descriptor closed.

Demetria devices 12 and 13, high-speed `1d6b:0100` at 12:13:14–12:13:36 and 12:14:12–12:15:48 local, ended before this Flip boot. After 12:16 local the host log has no `usb 1-2` line. Through 10:36:52Z the helper stayed off and `lsusb -d 1d6b:0100` stayed empty, with SDP already 1. The PAK was not started from SSH. No file was copied, B was not pressed, a second Start was not opened, and the cable was not unplugged. The removal is installed and the idle register matches it. At this reading the file check was still open, and this boot was not a failure against 12D-E29. The evidence file is `docs/research/evidence/usb-mtp-phase12d/20261014T103652Z-e31-installed.txt`. The later session on this boot follows the mechanism table.

The helper was read and not changed. The connection pieces, from that source and from the earlier sessions:

| Piece | Class | Why |
| --- | --- | --- |
| SDP/CDP wait | Essential, and observed on earlier images | 12D-E22 reached EP0 while the PHY reported a dedicated charger, and Demetria saw no device. 12D-E26 enumerated with SDP=1. This boot already had SDP=1 while the gadget was stopped, so the wait itself was not exercised. |
| Deferred initial bind | Essential, and observed on 12D-E26 | `spawn_link` calls `link_once` once before the background loop. A data cable binds the UDC once, latches `pending`, and does not write `soft_connect`. 12D-E26 recorded one `bind` and then `configured`. |
| Link watcher | Essential for the wait, the cable edges, and responder exit | The background loop is what binds if SDP or CDP appears after start, writes the cable edges, and tears the session down if the responder pid is gone. Removing the process would also remove that deferred bind. |
| Cable-loss `soft_connect disconnect` | Unproven on a working MTP session | One write when the host state is neither `configured` nor `suspended` and both SDP and CDP are 0, then latch `idle`. 12D-E26 did not unplug. This boot did not either. |
| Cable-return `soft_connect connect` | Unproven, and separable from the initial bind | Written only from latch `idle` or `idle-failed` when a data cable is present. The first bind does not use it. |
| Latches and the link state files | Essential for not repeating a write | A failed or finished write is not retried. The kernel accepts the write length without proving the pull-up changed. |
| The 0.2 second poll | Essential for this file-based watcher | Extcon and the UDC state are files. The loop closes the lock descriptor before it sleeps. |
| Cleanup reaper | Outside this reduction | It is the MENU+START path. 12D-E27 did not capture a second enumeration for that report. |
| Process-group split | Essential for that reaper | The watcher stays in the PAK group. The reaper calls `setsid` so it can outlive the group. |

No connection function in the helper is uncalled. The full-root export, the mount jail, foreign UDC protection, MENU+START, and the FunctionFS and responder lifecycle stay as they are. `snps,dis_u2_susphy_quirk` stays for its own experiment.

The file check on this image is the later reading below. That fixed-cable transfer is accepted for the scenarios it measured. B, a second Start, and MENU+START were still pending when that reading was written. The one separable candidate after that file check was the cable-return `soft_connect connect`, together with the cable-loss disconnect that creates the `idle` latch. Section 39 is that candidate. It is not installed.

Later on the same boot the PAK was already open. Demetria, PCI `0000:c4:00.3`, bus 1 port 2, logged device 14 at 10:40:12Z–10:40:20Z and device 15 from 10:40:27Z. Both were high-speed `1d6b:0100`. The host log for those lines has no descriptor error. kiod6 recorded the unknown-VID notice and, at the device 14 disconnect, `Could not close session`. No PTP `02ff` line appears. Device 15 was still present at 10:56:37Z, owned by kiod6. The helper was `state=bound`, UDC `configured` at high speed, latch `configured`, SDP=1, FunctionFS `ep0` through `ep3`, one `bind` in `link.binds`, and no `link.writes` file. `umtprd` pid 11807 had started at 10:40:12Z. Its log has `incoming_packet : Read Error (-1)` at 10:40:26Z and no later line. The same pid served device 15. The responder namespace had `/storage`, `/mnt/sd2`, the configuration, and FunctionFS. `/boot` was not in it. KIO listed ZLYME and SD Card.

Disposable copies through kioclient, cable left where it was:

| Path | SHA-256 |
| --- | --- |
| Host `e31-4k.bin`, Flip `/storage/.../e31-4k.bin`, and the MTP read-back | `7927a8660e35db2c573755522b6ef35d3bb05e5dea1c7323d5e8c84bd4586de1` |
| Host `e31-1m.bin`, Flip `/storage/.../e31-1m.bin`, and the MTP read-back | `eafef5ae0d452d6c428231fcd348642b62609bc9120ecce30a18a8fd4fcdb77b` |
| Flip `e31-from-flip.bin` and the MTP copy on Demetria | `47d4a15d546cbc5691098d4470682c399e5978eda54da4fe90a995ba73d61e1b` |
| SD Card `e31-sd-4k.bin`, the Flip hash, and the MTP read-back | `7927a8660e35db2c573755522b6ef35d3bb05e5dea1c7323d5e8c84bd4586de1` |

Rename kept the 4 KiB hash on both storages. MTP delete removed both test directories. After that, the boot id was unchanged, the device number was still 15, and the UDC was still `configured`. The maintainer reports that the connector is contact-sensitive and had been positioned so this session worked. The copies did not move the plug, and the log does not identify the device 14 disconnect as that positioning. E30 MTP functional transfer passes for this fixed position. B, a second Start, and MENU+START were not pressed. The evidence file is `docs/research/evidence/usb-mtp-phase12d/20261014T105637Z-e31-live.txt`. The stopped-session file is unchanged.

## 38. Historical restarts, later classification

The chronological sections still say the restart at about 17:00:49Z on 2026-10-13 and the restart at about 01:11:35Z on 2026-10-14 were unexplained. Those sentences, the timestamps, and the evidence files stay. On 2026-10-14 the maintainer reports that the unexpected restarts occurred only while USB was connected, and that the Flip connector is contact-sensitive. Historical USB-connected restarts: suspected physical connector/contact instability; not currently a separate software release blocker. The report does not electrically prove that contact instability caused the resets. A later restart with USB disconnected, or with a connection that stays seated, reopens the software investigation. Phase 12 still includes a reboot check. USB and PMIC error handling stays in the tree.

## 39. Cable recovery pair, candidate

12D-E32 removes the cable-loss `soft_connect disconnect` and the cable-return `soft_connect connect` from `zlyme-usb-transfer`. The SDP/CDP wait, the one initial bind, the `configured` and `suspended` leave-alone path, the watcher, responder-exit cleanup, B, MENU+START, the jail, and the export list stay. `snps,dis_u2_susphy_quirk` stays. No DTS or kernel source changed.

Linux 7.2.10 `dwc3_gadget_disconnect_interrupt` marks the gadget not-attached and does not clear `DCTL.RUN_STOP`. `soft_connect` `disconnect` calls `pullup(0)`, and `dwc3_gadget_soft_disconnect` clears `RUN_STOP`, then `udc_stop` runs. `soft_connect` `connect` calls `udc_start` and `dwc3_gadget_soft_connect`, which soft-resets the core before setting `RUN_STOP`. That reconnect comment is about a device-initiated disconnect. The pair is required after the helper has written `disconnect`. It is not required by the disconnect-event path. Removing both writes is the experiment. A physical replug while `RUN_STOP` stays set is not established by this reading. The host tests do not assert enumeration from a mock sysfs change.

At 11:08:06Z the open session was device 16 on Demetria bus 1 port 2, high-speed `1d6b:0100`, UDC `configured`, same boot id `6a14efb9-ee1b-47ee-80d3-c75bd6bd9799`. Device 15 had disconnected at 11:06:46Z. The responder, watcher, and reaper pids were new. `link.binds` had one `bind` and `link.writes` was absent. One `ep0out` line matches that disconnect window. The session was left running. It is not a test of this candidate.

The archive is `output/images/zlyme-my355-20261014-522e4573010a.tar`, SHA-256 `e235ca9953fcab8f0bd93ecd7f4feb2f1c3338d15a5201b06c4b8187d69d71e0`, from `522e4573010adb6e04d62b547e5cf373f688750d`. Squashfs `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c`. Packed helper `9fc37d2e9f2f831f194691be3f3ff6de046f8d188fad86a3094bdecb6ee00859`, matching the source, with no `soft_write`. `zlyme-usb-enter` is still `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. `Image`, `Image.gz`, the DTB, and the bootloaders match the installed E30 image. Host tests printed `usb link ok` and `usb transfer ok`. The E30 archive remains `2113ee676428eeede198e9aa21a422d3dedebd1bf0112112d880f82a3e7248ea`. This candidate is not installed. The evidence file is `docs/research/evidence/usb-mtp-phase12d/20261014T111800Z-e32-candidate.txt`. Section 41 is the later install and acceptance.

Install it from the card after the current PAK has been closed normally. E30 is the rollback. Do not write VBUS, a USB role, a regulator, or a DWC3 register. Do not reset the host controller.

First, with the cable already in a working position, open USB File Transfer. Expect high-speed `1d6b:0100`. Copy one small file each way and compare SHA-256. Check SD Card if it is mounted. Press B and confirm cleanup. Leave the cable seated, open the PAK again, and expect a new enumeration. That pass only shows the initial bind still works.

Then, if one unplug and one replug can be done without stressing the contact-sensitive connector, record extcon and the UDC, wait for the host disconnect to settle, reconnect once, and see whether `1d6b:0100` returns without starting the PAK again. One small transfer if it does. Do not wiggle the plug. If the connector makes the result unclear, record it as inconclusive. A working first session does not accept this removal. If E30 recovers on that cable and receptacle and this image does not, keep the pair.

12D-E33 later read the Flip. That boot was still the E30 image. Section 40 is that reading.

## 40. Cable recovery pair, not installed

12D-E33 found the Flip still running the 12D-E30 image. The 12D-E32 archive was not on the card, and this pass did not install it, start the PAK, or move the cable. The removal is not accepted and is not rejected. E30 stays the installed image and the rollback.

Demetria had no `1d6b:0100`. Bus 1 port 2 was absent. The last `usb 1-2` line is a disconnect of device 16 at 11:24:19Z. That device had enumerated at 11:07:37Z as high-speed `1d6b:0100`. The log around the disconnect has no descriptor error, reset, or failed enumeration.

The boot id was `27b291c9-d783-4fa0-a3fd-79f3d249e426`. `btime` 1791977357 is 11:29:17Z. The previous boot was `6a14efb9-ee1b-47ee-80d3-c75bd6bd9799`. `/boot/zlyme` hashes to `a568584c4ff9b4fad976ac126bb63bb923dd19c47f027e94eaa8b83d95a27bce`. `/boot/Image.gz` hashes to `8b5ceb6dec96b998904afef3a5cb6e87ee020eb157a1b2e1ca25ec8a0ea0d938`. `/boot/rk3566-miyoo-flip.dtb` hashes to `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18`. `uname` is `Linux zlyme 7.2.10 #2 SMP PREEMPT Wed Oct 14 10:01:20 UTC 2026`. The live helper hashes to `30f8d89fdd98a42857ecad753bbfc650720f3f17d5d2254360fd21caacd2b9b6` and still contains `soft_write`. `zlyme-usb-enter` is still `302021bd49173579aded79dcdb27072148646d11fff33494ae7c5c32a9cd4982`. `/storage/.update/apply.log` ends with `zlyme-my355-20261014-7caa0871a82f.tar`. The E32 name is not in that log, and no update tar was at `/storage/.update`, `/storage`, or the `/mnt/sd2` root.

`zlyme-usb-transfer status` was `state=off`. The UDC was `not attached`. The run directory held `lock` and no latch or bind file. `nextui.elf` was pid 490. `wlan0` was up. `/mnt/sd2` was read-write ext4. The battery was Discharging at capacity 100. The charger was online with RK817 `usb_type` `Unknown [DCP]`, and extcon0 read USB=1 and SDP=1. Taint was 4096. The new boot's saved dmesg has no WARNING, `dwc3`, panic, or Oops line. pstore was empty.

The previous boot's NextUI log shows PAK launches at 10:40:05Z and 11:07:25Z, then a NextUI banner with no further launch. That banner fits a frontend that had returned after the second PAK. It does not name B, a second Start, or MENU+START. `state=off` on the new boot is not a cleanup measurement of device 16.

The reboot cause was not identified. The host had lost device 16 at 11:24:19Z, and the new boot began at 11:29:17Z. SDP on the new boot shows a data cable after the boot. It does not show the cable state at the reset. This reboot is not an E32 result. It does not electrically explain the earlier restarts, and it is not recorded here as a separate software release blocker. A restart with USB disconnected, or with a connection that stays seated, still reopens that investigation.

Ordinary MTP, B, a second Start, cable recovery, and MENU+START on E32 were not tested. The local archives are unchanged: E30 `2113ee676428eeede198e9aa21a422d3dedebd1bf0112112d880f82a3e7248ea`, E32 `e235ca9953fcab8f0bd93ecd7f4feb2f1c3338d15a5201b06c4b8187d69d71e0`. The evidence file is `docs/research/evidence/usb-mtp-phase12d/20261014T113707Z-e33-not-installed.txt`.

Install the E32 archive from the card before any test of the removal. Close a running PAK normally first. The ordinary path is a high-speed enumeration, one small file each way, B, and a second Start with the cable left seated. The removal itself still needs one unplug and one replug inside a running session, or an inconclusive result if the connector makes that reading unclear. A working first session does not accept the removal.

## 41. E32 installed and accepted

12D-E34 is the later install. The maintainer installed the E32 archive and accepts it for ordinary transfer, including a second Start with the cable left in place. Within-session unplug and replug was not measured. That limit stays. E30 remains the rollback for it. `snps,dis_u2_susphy_quirk` stays. No new evidence file was added for this reading. The harness notes stayed under `/tmp`.

The boot was `5243a19c-f221-420e-9802-d72f12435153`, `btime` 14:42:04Z, and that boot was still running at the idle reading. `/boot/zlyme` hashed to `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c`. The live helper hashed to `9fc37d2e9f2f831f194691be3f3ff6de046f8d188fad86a3094bdecb6ee00859`. `uname` was `Linux zlyme 7.2.10 #2 SMP PREEMPT Wed Oct 14 10:01:20 UTC 2026`. This pass did not hash `Image.gz` or the DTB again. The image was built before `ZLYME_VERSION` became `zlyme44.3`, so the live `os-release` text is still the previous version string.

Demetria bus 1 port 2 saw device 21 and then device 22, both high-speed `1d6b:0100`. Host to Flip matched 4 KiB `6108e445bb8ec73271431f615891d097f363b706c67466ad3fcf589469e5ed2b` and 1 MiB `8b9572ed96dabf7a17e0ceb8449d87bdde8817ea6ac1dfbcff2fc0bb9a9e66ce` on `/storage` and on an MTP read-back. The second card matched the 4 KiB hash over MTP. Flip to host matched `ee5ce3479bcfecf2b4a819e8f4e3cbd501e90672f8b1919fcae692e129aa1900`. A rename matched. Pressing B disconnected device 21. SSH did not answer in that window, so the stopped UDC, responder, and FunctionFS were not read at that instant. Device 22 was the later session on the same boot, cable unmoved, and its 4 KiB MTP read-back matched. Demetria logged device 22 disconnecting at 15:51:50Z. There was no PTP `02ff` and no USB reset in the host log of those two sessions. One kernel `dev_err` at an earlier disconnect said a request was not queued to `ep0out`. There was no Oops and no WARNING.

A later idle reading, at 16:24:34Z on the same boot, found `zlyme-usb-transfer` `state=off`, no `umtprd`, no helper process, no configfs gadget, and FunctionFS not mounted. `/dev/ffs-mtp` was an empty directory from the earlier session, not a mount. Reaper pid files named dead processes. `/boot` was read-only, `/storage` and `/mnt/sd2` were mounted, and NextUI was running. The UDC class was empty and `fcc00000.usb` was still bound to `dwc3`. Extcon reported USB-HOST with no SDP or CDP. That is the idle host role when no data cable is present, not a leftover gadget. Demetria's data port had no `1d6b:0100`. This reading is the resulting state. It is not a trace of the 15:51:50Z transition.

The maintainer accepts this image with the cable-recovery limit. No further reduction is open. The broader Phase 12 closure, including the PortMaster and PanVK readings, is in `docs/ROADMAP.md`.
