# Phase 12. zlyme44.3 development

Objective: battery, SSH, clock, updater, launch logs, Buildroot 2026.08, PanVK as an experimental opt-in, unused kernel-test cleanup, and USB File Transfer.

Disposition: Closed, 2026-10-14, after the same-day correction.

Accepted behavior: the installed image is the E32 archive, squashfs `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c`. It was built before `ZLYME_VERSION` became `zlyme44.3`. The maintainer accepted ordinary MTP on that image, including a second start with the cable left in place, one PortMaster port on the second card, and charging and upper-port host use by report. The maintainer presented one orange frame twice. PPSSPP did not present a game through PanVK. The archive `7951a37668e3` is an earlier file-copy baseline, not this accepted image. A later local candidate, recorded under Phase 13, replaced that image on one Flip and does not reopen this phase.

Limitations: within-session cable removal was not measured. E30 stays the rollback for that limit. `snps,dis_u2_susphy_quirk` stays. A discharge to 0% was not run. The maintainer required no further Phase 12 hardware test. On 2026-10-19, after Phase 13 had closed, the maintainer observed one automatic shutdown at 0%. That later observation is not a Phase 12 retest and does not reopen Phase 13. WestonPack cleanup and removal of obsolete PAKs are not a new hardware gate. The hardware-wiki update for the development Linux 7.2.10 boot and the lower-port session does not call the device tree proven.

Dependencies: published 44.2 source. No Phase 12 item waits on a wiki edit.

Records: [docs/research/phase-12d-usb-mtp.md](../research/phase-12d-usb-mtp.md) and [docs/research/phase-12d-linux-7.2.10-migration.md](../research/phase-12d-linux-7.2.10-migration.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-12-zlyme443-development).
