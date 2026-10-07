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
| [maskrom-entry.md](maskrom-entry.md) | 2026-10-07 | How stock `rbrom` on serial recovered a board that no longer reached USB MASKROM. A later direct Linux PMUGRF and CRU restart logged `maskrom` and then went silent, with no `2207:350a`, and was removed. The boot-FAT handoff on `0e09c319` left the request in place because U-Boot opened `mmc 0:2`. `rbrom` was not reached. The `mmc 1:2` correction is not hardware-proven. |
