# Research

Research documents preserve alternatives, measurements, upstream comparisons, and experiments.

They are not automatically normative.

A research document may say:

> compare A vs B.

Architecture should say:

> Zlyme currently uses A because ...

Keep evidence and abandoned alternatives here so they remain available without making an agent treat every explored option as current architecture.

Phase files are chronological. A later section in the same file, and the [ROADMAP](../ROADMAP.md) status for that phase, supersede earlier sections. A new file uses the phase prefix in [docs/WRITING.md](../WRITING.md). Shipped behavior is described in [docs/ARCHITECTURE.md](../ARCHITECTURE.md), [docs/OPERATIONS.md](../OPERATIONS.md), and [docs/DEVELOPMENT.md](../DEVELOPMENT.md).

## Index

| File | Phase, dates | Contents |
| --- | --- | --- |
| [phase-01-weston.md](phase-01-weston.md) | 1, 2026-09-22 | Why Zlyme ships Buildroot Weston for application-scoped Wayland and leaves WestonPack to PortMaster. Tracer findings on the Flip. |
| [phase-02-kernel-patch-audit.md](phase-02-kernel-patch-audit.md) | 2, 2026-09-23 | Upstream evidence pins (2A), A–F classification of the 45 inherited Linux patches (2B), and the 2C removals down to 18. |
| [phase-03-joypad-driver.md](phase-03-joypad-driver.md) | 3, 2026-09-23 to 2026-09-25 | Flip pad hardware and UART protocol, the `miyoo-flip-gamepad` design, calibration, rumble, 3B to 3C3 results, and the 3D cutover. |
| [phase-04-inputplumber.md](phase-04-inputplumber.md) | 4, 2026-09-14 to 2026-09-28 | The superseded Switch Pro study, InputPlumber packaging, latency, the NextUI handoff, and the application cutover. |
| [phase-05-kernel-patch-audit.md](phase-05-kernel-patch-audit.md) | 5, 2026-09-28 | Second reduction pass, RK817 gauge patches, `SYS_CAN_SD`, and the 16-patch correction. |
| [phase-06-deep-suspend.md](phase-06-deep-suspend.md) | 6, 2026-09-28 to 2026-09-29 | RK3568 BL31 deep suspend against the BSP and stock firmware, 6B to 6D results, `vdd_logic` off, and the RK817 `005` disposition. |
| (none) | 7, 2026-09-29 to 2026-09-30 | Phase 7 DMC work has no research file. Its evidence is `package/drivers/rk3568-dmc/README.md`, [docs/LOGBOOK.md](../LOGBOOK.md), and [docs/archive/roadmap-2026-10-15.md](../archive/roadmap-2026-10-15.md). |
| [phase-08-frontend-source.md](phase-08-frontend-source.md) | 8, 2026-09-30 | NextUI delta and fork, the pinned fetch, minui helper vendoring, read-only ZLYMEBOOT, the `/storage` unmount, and the frontend profile. |
| [phase-09-product.md](phase-09-product.md) | 9, 2026-09-30 to 2026-10-04 | gpSP pin, Spruce CPU floors, Settings, multi-library BIOS and saves, ZcrapeGoat, incremental OTA, and per-image acceptance. |
| [phase-10-maintenance.md](phase-10-maintenance.md) | 10, from 2026-09-30 | Planning outline. The procedure is [docs/MAINTENANCE.md](../MAINTENANCE.md). |
| [phase-10-documentation-audit.md](phase-10-documentation-audit.md) | 10, 2026-10-04 | Phase 10 full-history documentation audit and hardware-wiki synchronization plan. |
| [preliminary-emulators.md](preliminary-emulators.md) | before Phase 0, 2026-09-10 | Distribution core comparison and benchmark plan from before the curated list. Not the shipped set. |
| [preliminary-performance.md](preliminary-performance.md) | before Phase 0, undated | Generic RK3566 kernel and runtime tuning brainstorm. Not adopted policy. |
| [phase-11-maskrom-entry.md](phase-11-maskrom-entry.md) | 11, 2026-10-07 | Historical. Stock `rbrom` on serial recovered a board that no longer reached USB MASKROM. The later Linux PMUGRF/CRU restart and the boot-FAT marker were removed. They are not the product path. The shipped recovery mechanism is the one-entry recovery preloader, recorded in `docs/ARCHITECTURE.md` and the hardware wiki. |
| [phase-12d-usb-mtp.md](phase-12d-usb-mtp.md) | 12D, 2026-10-12 to 2026-10-14 | Lower-port MTP ledger through 12D-E26, the closed speed-cap check, the active DWC3 sample, the LPM register session, and the PHY trace. 12D-E20 recorded a fresh SDP detection and a running gadget that Demetria did not see. 12D-E21 enumerated MTP and a separate read-only mass-storage gadget on the identified host port. 12D-E22 installed the filesystem-root image; the gadget reached EP0 and Demetria saw no device. 12D-E23 corrects the watcher that treated the EP0 descriptor class as a healthy link. That image was later found installed. 12D-E24 read it with the gadget stopped and the lower PHY reporting DCP, then postponed the first UDC bind until SDP or CDP. 12D-E25 found that image installed. Demetria enumerated MTP at high speed, and a file copy was not checked in that pass. The maintainer later reported that the cable was disconnected during that pass. The Flip restarted, and that cause is unknown. 12D-E26 copied disposable files both ways on the following boot and the SHA-256 values matched. 12D-E27 found that gadget gone. The maintainer reports a second Start and MENU+START succeeded. The host log does not show a second enumeration. 12D-E28 removes the one-shot EP0 repair. The maintainer installed that image and reports that USB File Transfer works. The installed squashfs matches the archive. No new file checksum was taken. 12D-E29 removes the USB2 PHY extcon resync. The maintainer installed that image and reports that USB File Transfer works, including file copying. Demetria logged five high-speed enumerations. No new file checksum was taken. 12D-E30 removes `snps,dis_enblslpm_quirk` from the lower controller. 12D-E31 found that image installed, with the property absent and idle bit 8 set. A later session on that boot matched disposable SHA-256 values both ways, including the second card. That fixed-cable transfer is accepted. B and a second Start were not pressed. The 17:00:49Z and 12D-E25 restarts stay in the original records. The maintainer reports that they occurred only while USB was connected. They are suspected physical contact instability and are not a separate software release blocker. 12D-E32 removes the cable-loss `soft_connect` pair. That candidate is built and not installed. 12D-E33 found the Flip still on the E30 image. The candidate was not on the card, and the removal was not tested. The Flip had rebooted at 11:29:17Z. That cause was not identified, and that boot is not an E32 result. 12D-E34 later found the E32 archive installed. The maintainer accepts it. Cable recovery was not measured. Section 41 is that reading. Bounded copies are in [evidence/usb-mtp-phase12d](evidence/usb-mtp-phase12d/README.md). |
| [phase-12d-linux-7.2.10-preflight.md](phase-12d-linux-7.2.10-preflight.md) | 12D, 2026-10-13 | Read-only review of the then-current stable kernel against the 7.0.2 pin. The defconfig pin did not move in that pass. The deferred-probe recommendation in that file was later corrected. |
| [phase-12d-linux-7.2.10-migration.md](phase-12d-linux-7.2.10-migration.md) | 12D, 2026-10-13 | Host build of Linux 7.2.10. The dirty OTA was later booted. 12D-E21 later enumerated on a clean image. This migration record is not that result, and it is not hardware-accepted. |
| [phase-12d-driver-source-audit.md](phase-12d-driver-source-audit.md) | 12D, 2026-10-13 | RTL, libmali, and mali-kbase source comparison after the 7.2.10 host build. Pins were not moved. |
| [phase-15-documentation-audit.md](phase-15-documentation-audit.md) | 15, 2026-10-26 | Documentation inventory and the contradictions corrected in Phase 15A. Includes the former maintenance status snapshots. |
| [phase-16-logging-inventory.md](phase-16-logging-inventory.md) | 16A, 2026-10-27 | Shipped-launch and system-log inventory, and the selected 16B design. 16B is not implemented. |
| [phase-15c-retroarch-input-audio.md](phase-15c-retroarch-input-audio.md) | 15C1, 2026-10-26 | Read-only investigation of GitHub issues #2 and #3. Not an implementation and not a new hardware measurement of gameplay. |
| [phase-14-audio.md](phase-14-audio.md) | 14, 2026-10-20 | Phase 14 audio experiments. Its PulseAudio and BlueALSA paragraphs are the superseded candidate. The running graph is in [docs/ARCHITECTURE.md](../ARCHITECTURE.md). |
| [phase-14-pipewire-assessment.md](phase-14-pipewire-assessment.md) | 14, 2026-10-19 | PipeWire adoption comparison. Sentences that still call PulseAudio the mixer, or say the minimal image omits PipeWire, are historical. |
| [phase-14-stability.md](phase-14-stability.md) | 14, 2026-10-20 | Notes from an unaccepted candidate's logs. Not a kernel-panic record. |
| [phase-14-portmaster-architecture-proposal.md](phase-14-portmaster-architecture-proposal.md) | 14 | PortMaster layout comparison. The accepted decision is ADR 0009. |
| [phase-14-portmaster-capability.md](phase-14-portmaster-capability.md) | 14 | Which PortMaster runtimes the image can launch. |
| [phase-14-rocknix-compat-coverage.md](phase-14-rocknix-compat-coverage.md) | 14 | Coverage of the imported ROCKNIX compatibility archive. |
| [phase-14-portmaster-matrix.md](phase-14-portmaster-matrix.md) | 14, 2026-10-23 | PortMaster launch results from the Phase 14 gates. |
| [phase-14-device-log.md](phase-14-device-log.md) | 14, 2026-10-23 | Device-log reading from the Phase 14 gates. |
| [phase-14-nextui-theme-manager.md](phase-14-nextui-theme-manager.md) | 14 | Art Book picture ownership. |
| [phase-15d-button-layouts.md](phase-15d-button-layouts.md) | 15D, 2026-10-26 | Face-button audit. The RetroArch menu result on a26f96b is in the logbook. PPSSPP's map was not accepted. |
| [phase-15d-save-bind-ownership.md](phase-15d-save-bind-ownership.md) | 15D, 2026-10-27 | Why the three save-bind scripts stay separate in this pass. |
