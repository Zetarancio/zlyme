# Research

Research documents preserve alternatives, measurements, upstream comparisons, and experiments.

They are not automatically normative.

A research document may say:

> compare A vs B.

Architecture should say:

> Zlyme currently uses A because ...

Keep evidence and abandoned alternatives here so they remain available without making an agent treat every explored option as current architecture.

Phase files are chronological. A later section in the same file, and the [ROADMAP](../ROADMAP.md) status for that phase, supersede earlier sections. Shipped behavior is described in [docs/ARCHITECTURE.md](../ARCHITECTURE.md), [docs/OPERATIONS.md](../OPERATIONS.md), and [docs/DEVELOPMENT.md](../DEVELOPMENT.md).

## Index

| File | Phase, dates | Contents |
| --- | --- | --- |
| [weston.md](weston.md) | 1, 2026-09-22 | Why Zlyme ships Buildroot Weston for application-scoped Wayland and leaves WestonPack to PortMaster. Tracer findings on the Flip. |
| [kernel-patch-audit.md](kernel-patch-audit.md) | 2, 2026-09-23 | Upstream evidence pins (2A), A–F classification of the 45 inherited Linux patches (2B), and the 2C removals down to 18. |
| [joypad-driver.md](joypad-driver.md) | 3, 2026-09-23 to 2026-09-25 | Flip pad hardware and UART protocol, the `miyoo-flip-gamepad` design, calibration, rumble, 3B to 3C3 results, and the 3D cutover. |
| [inputplumber.md](inputplumber.md) | 4, 2026-09-14 to 2026-09-28 | The superseded Switch Pro study, InputPlumber packaging, latency, the NextUI handoff, and the application cutover. |
| [kernel-patch-audit-phase5.md](kernel-patch-audit-phase5.md) | 5, 2026-09-28 | Second reduction pass, RK817 gauge patches, `SYS_CAN_SD`, and the 16-patch correction. |
| [deep-suspend-phase6.md](deep-suspend-phase6.md) | 6, 2026-09-28 to 2026-09-29 | RK3568 BL31 deep suspend against the BSP and stock firmware, 6B to 6D results, `vdd_logic` off, and the RK817 `005` disposition. |
| (none) | 7, 2026-09-29 to 2026-09-30 | Phase 7 DMC work has no research file. Its evidence is `package/drivers/rk3568-dmc/README.md`, [docs/LOGBOOK.md](../LOGBOOK.md), and ROADMAP section 7. |
| [frontend-source-phase8.md](frontend-source-phase8.md) | 8, 2026-09-30 | NextUI delta and fork, the pinned fetch, minui helper vendoring, read-only ZLYMEBOOT, the `/storage` unmount, and the frontend profile. |
| [product-phase9.md](product-phase9.md) | 9, 2026-09-30 to 2026-10-04 | gpSP pin, Spruce CPU floors, Settings, multi-library BIOS and saves, ZcrapeGoat, incremental OTA, and per-image acceptance. |
| [maintenance-phase10.md](maintenance-phase10.md) | 10, from 2026-09-30 | Planning outline. The procedure is [docs/MAINTENANCE.md](../MAINTENANCE.md). |
| [documentation-audit-phase10.md](documentation-audit-phase10.md) | 10, 2026-10-04 | Phase 10 full-history documentation audit and hardware-wiki synchronization plan. |
| [emulators.md](emulators.md) | before Phase 0, 2026-09-10 | Distribution core comparison and benchmark plan from before the curated list. Not the shipped set. |
| [performance.md](performance.md) | before Phase 0, undated | Generic RK3566 kernel and runtime tuning brainstorm. Not adopted policy. |
| [maskrom-entry.md](maskrom-entry.md) | 2026-10-07 | Historical. Stock `rbrom` on serial recovered a board that no longer reached USB MASKROM. The later Linux PMUGRF/CRU restart and the boot-FAT marker were removed. They are not the product path. The shipped recovery mechanism is the one-entry recovery preloader, recorded in `docs/ARCHITECTURE.md` and the hardware wiki. |
| [usb-mtp-phase12d.md](usb-mtp-phase12d.md) | 12D, 2026-10-12 to 2026-10-14 | Lower-port MTP ledger through 12D-E26, the closed speed-cap check, the active DWC3 sample, the LPM register session, and the PHY trace. 12D-E20 recorded a fresh SDP detection and a running gadget that Demetria did not see. 12D-E21 enumerated MTP and a separate read-only mass-storage gadget on the identified host port. 12D-E22 installed the filesystem-root image; the gadget reached EP0 and Demetria saw no device. 12D-E23 corrects the watcher that treated the EP0 descriptor class as a healthy link. That image was later found installed. 12D-E24 read it with the gadget stopped and the lower PHY reporting DCP, then postponed the first UDC bind until SDP or CDP. 12D-E25 found that image installed. Demetria enumerated MTP at high speed, and a file copy was not checked in that pass. The maintainer later reported that the cable was disconnected during that pass. The Flip restarted, and that cause is unknown. 12D-E26 copied disposable files both ways on the following boot and the SHA-256 values matched. 12D-E27 found that gadget gone. The maintainer reports a second Start and MENU+START succeeded. The host log does not show a second enumeration. 12D-E28 removes the one-shot EP0 repair. The maintainer installed that image and reports that USB File Transfer works. The installed squashfs matches the archive. No new file checksum was taken. 12D-E29 removes the USB2 PHY extcon resync. The maintainer installed that image and reports that USB File Transfer works, including file copying. Demetria logged five high-speed enumerations. No new file checksum was taken. 12D-E30 removes `snps,dis_enblslpm_quirk` from the lower controller. 12D-E31 found that image installed, with the property absent and idle bit 8 set. A later session on that boot matched disposable SHA-256 values both ways, including the second card. That fixed-cable transfer is accepted. B and a second Start were not pressed. The 17:00:49Z and 12D-E25 restarts stay in the original records. The maintainer reports that they occurred only while USB was connected. They are suspected physical contact instability and are not a separate software release blocker. 12D-E32 removes the cable-loss `soft_connect` pair. That candidate is built and not installed. Bounded copies are in [evidence/usb-mtp-phase12d](evidence/usb-mtp-phase12d/README.md). |
| [linux-7.2.10-preflight.md](linux-7.2.10-preflight.md) | 12D, 2026-10-13 | Read-only review of the then-current stable kernel against the 7.0.2 pin. The defconfig pin did not move in that pass. The deferred-probe recommendation in that file was later corrected. |
| [linux-7.2.10-migration.md](linux-7.2.10-migration.md) | 12D, 2026-10-13 | Host build of Linux 7.2.10. The dirty OTA was later booted. 12D-E21 later enumerated on a clean image. This migration record is not that result, and it is not hardware-accepted. |
| [driver-source-audit-phase12d.md](driver-source-audit-phase12d.md) | 12D, 2026-10-13 | RTL, libmali, and mali-kbase source comparison after the 7.2.10 host build. Pins were not moved. |
