# Phase 12D USB MTP investigation

This is the investigation record for the lower-port MTP session. It is not a driver patch, and it does not say that a proposed change is correct. Shipped behavior is in `docs/ARCHITECTURE.md`. The open gate is in `docs/ROADMAP.md` section 12.

The raw directories `/tmp/zlyme-usb-testa-47oCJM`, `/tmp/zlyme-usb-testb-xZXaSr`, and `/tmp/zlyme-usb-stage0-20261012T145707Z` were not on the development machine on 2026-10-13. The hardware rows below are the maintainer-supervised session reports from 2026-10-12. They are not a fresh reading of those files.

## 1. Hardware topology

Miyoo Flip, `my355`, RK3566. The board DTS comments and the built DTB agree on this map:

| Address | Node | Role |
| --- | --- | --- |
| `fcc00000` | `usb_host0_xhci` | Lower USB-C, charge and gadget. `dr_mode = "otg"`. PHY `usb2phy0_otg`. Extcon `usb2phy0`. `maximum-speed = "high-speed"`. No `phy-supply`. |
| `fe8a0000` | `usb2phy0` | Lower PHY block. The OTG port has no VBUS regulator. The host port's supply is `vcc_3v3` and that port is not a connector. |
| `fd800000` / `fd840000` | EHCI / OHCI | Upper USB-C host on `usb2phy1_otg`, VBUS `vcc5v0_host`. |
| `usb2phy1_host` | Wi-Fi PHY | RTL8733BU. The board file's supply is experimental `vcc_3v3`. The comment says stock used 5 V. |
| `fd000000` | `usb_host1_xhci` | USB2 host on `usb2phy0_host`. No external connector. |

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

No new hardware test was run for this document. A later test should change one variable:

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

The host still had no connect in the earlier 7.2.10 sessions, including the one where extcon already said SDP. This idle sample does not explain that session. It explains the silent replug: VBUS is visible to the PHY bit and to RK817, and the PHY extcon is not updated.

Phase 12D remains open. Enumeration is not accepted. The maintainer smoke check is not acceptance of the rest of the image.
