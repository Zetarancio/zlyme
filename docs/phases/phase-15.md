# Phase 15. Documentation and zlyme44.4 preparation

Objective: correct the documentation against the Phase 14 source, retest two measured RetroArch issues, match original-system face buttons where the mapping is proved, and prepare the release only after approval.

Disposition: Closed with limitations, 2026-10-27. 15A through 15F are closed. Publication is the release operation below. It is not Phase 16.

Accepted behavior: `ZLYME_VERSION` is `zlyme44.4`. The installed image is `zlyme-my355-20261027-14ad7238a42e.tar`, rootfs `0b1f9ae3a9b1078f979a5f6d0d48151d6d1463fc9b99ee777103f18f8e6e4daa`, built from `14ad7238a42e61dd8660d76a5e50699de8fe51b1`. The session file on that image sets `input_joypad_driver` to udev and player 1 index `1`, which is the virtual pad at `event5`. The maintainer accepts built-in player 1. Issue #2 is not currently reproduced. Issue #3's joypad driver is udev, and the session sets the index from joystick syspath order. Accepted on the built-in pad: NextUI and the RetroArch menu confirm on east A and go back on south B, Game Boy gameplay matches that layout, and PPSSPP's menu and gameplay use south Cross and east Circle after Reset standalone settings. Splore is accepted from the maintainer's report.

The release operation is not a phase. It was published, 2026-10-27. Tag `zlyme-40439819817`, source `cb9770424011c1ccfc32cd99457364ca97ac19ea`, release [zlyme44.4](https://github.com/Zetarancio/zlyme/releases/tag/zlyme-40439819817), workflow [run 40439819817](https://github.com/Zetarancio/zlyme/actions/runs/40439819817). Commits after that source, including Phase 16, are not in the published release. `zlyme44.4` retains the two existing unknown-license exceptions. Redistribution rights remain unverified. The records are not license grants.

Limitations: a second controller with the same name was not part of that acceptance. A second controller that shares the Xbox name still uses the SDL2 joypad driver for that session, and that arrangement was not replayed with a second physical controller. A gpSP launch on the installed image initialized ALSA and did not log `-EPIPE`. Debugfs was not mounted, so the effective pixel clock was not read, and no PipeWire xrun count was taken. The historical 31,578,948 Hz divider is not claimed to be fixed. On the installed `e2c80ec` image the virtual pad was autoconfigured on udev port 2 and player 1 stayed at index 0, the physical pad. The 45.5 / 124.6 figures stay the earlier measurement. Dolphin has no hardware gate. Flycast's Dreamcast faces stay deferred. Other cores were not each observed. ADR 0011 stays proposed. The Quickswitcher and orphan-text NextUI pin is local OTA `zlyme-my355-20261027-c67613b766ee.tar`, rootfs `0f86cc108bf0c83606f31062f633de6e5b745feac0443dcc83255b66bbbd860b`. It was not installed and is not a release. The maintainer waived a hardware pass for those two settings changes.

Records: [Phase 15 audit](https://github.com/Zetarancio/zlyme/blob/2c6851c72d3b5930ef3ff781969ad852a6494b11/docs/research/phase-15-documentation-audit.md), [docs/research/phase-15c-retroarch-input-audio.md](https://github.com/Zetarancio/zlyme/blob/67a8245796b8c6ae80f70bcbf06f2febd88ab1ea/docs/research/phase-15c-retroarch-input-audio.md), [docs/research/phase-15d-button-layouts.md](../research/phase-15d-button-layouts.md), and [docs/research/phase-15d-save-bind-ownership.md](../research/phase-15d-save-bind-ownership.md). Each 15A–15F heading, and the release-operation heading, remains in the snapshot.

## Headings in the 2026-11-17 snapshot

- [Phase 15. Documentation and zlyme44.4 preparation](../archive/roadmap-2026-11-17.md#phase-15-documentation-and-zlyme444-preparation)
- [15A. Documentation inventory and scope](../archive/roadmap-2026-11-17.md#15a-documentation-inventory-and-scope)
- [15B. Documentation reconciliation and ADRs](../archive/roadmap-2026-11-17.md#15b-documentation-reconciliation-and-adrs)
- [15C. GitHub issues #2 and #3](../archive/roadmap-2026-11-17.md#15c-github-issues-2-and-3)
- [15D. Original-system button layouts](../archive/roadmap-2026-11-17.md#15d-original-system-button-layouts)
- [15E. Research names and architectural decisions](../archive/roadmap-2026-11-17.md#15e-research-names-and-architectural-decisions)
- [15F. Final validation and zlyme44.4 release preparation](../archive/roadmap-2026-11-17.md#15f-final-validation-and-zlyme444-release-preparation)
- [Release operation for zlyme44.4](../archive/roadmap-2026-11-17.md#release-operation-for-zlyme444)

