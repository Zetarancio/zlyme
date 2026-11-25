# Zlyme roadmap

This is the sequencing map. It is not the architecture. A phase outcome is [docs/phases/](phases/README.md). The full text this file replaced is [docs/archive/roadmap-2026-11-17.md](archive/roadmap-2026-11-17.md), commit `8d61d33d263434de4cd4e5f5f6200becd3756908`.

## Current status

Phase 19 is active and does not change firmware. Phase 19B is closed. Its retirement decisions are pull requests #6 through #13. The Theme Manager note, the PortMaster capability inventory, the Phase 14 device log, the button-layout audit, and the Phase 14 stability note stay. Recovery stays `archive/pre-phase-19-docs` and the verified Phase 19 backups. Phase 19C1 is the instruction-routing preflight and does not shorten instructions. The plan is [Phase 19](phases/phase-19.md).

Phase 18 is closed, 2026-11-21, after `zlyme44.5` was published and this documentation was reconciled. The original plan named `zlyme45`, and that name was not used. 18A and 18B are closed. 18C remains closed as an investigation. The 2026-11-18 launches are later evidence: the five GBA ZIPs started, an ASCII Windows program started, and a non-ASCII Windows filename did not. 18D is closed for the accepted DSperate scope. 18E is accepted by the maintainer. 18F3 is hardware-accepted. 18F4 is in the published source, is source and host-tested, and is not hardware-accepted. The published image has not been installed. The outcome is [Phase 18](phases/phase-18.md).

## Next action

19C1 records which instructions are actually loaded. It does not change `AGENTS.md` or the always-applied rules.

## Blockers and deferred work

These limitations remain. They are not open release blockers:

- The five tested GBA ZIPs launched. Correct display of a non-UTF-8 name is not proven, and the shipped fonts do not contain the Chinese characters that were tried.
- An ASCII Windows program launched. A non-ASCII executable filename did not. A non-ASCII folder name was not the case that failed. Wine does not run a ZIP. The earlier Wine-probe freeze is a separate event.
- The Wine-probe freeze has no identified cause. No further device Wine test is authorized by the 18C closure.
- 18F4 was not run on the Flip. An exceptional `setpgid()` failure remains an integration review item.
- The F3 sign-off does not record individual screen text, a before/after timezone name, or a headset. A headset check is not required for that pill change.
- Older SD2 `EIO`, `EUCLEAN`, and superblock write errors are a maintenance concern.
- Phase 16 still defers a failed `/storage` unmount that continues into forced shutdown, status 125 recovery, a direct `reboot` without `-f` on the Flip, and the prelaunch window.
- Cursor automatic skill selection is unverified. OpenCode runtime testing is deferred.

## Latest installed acceptance

The latest installed image is `zlyme-my355-20261116-9d0fc4e3f12d.tar`, SHA-256 `9159f90d0ebccf1394a9702b799968754574829b54d0c934258868c674bea784`, from `9d0fc4e3f12d52d3b1f56fd3e0a75fc8d6a0e6ea`. The maintainer accepted the applicable F3 checklist on 2026-11-17. Phase 18D's tested scope stays the earlier image `zlyme-my355-20261116-fc414c6ba084.tar`. That installed image is not the published `zlyme44.5` release.

## Phase index

| Phase | Outcome | Summary |
| --- | --- | --- |
| 0 | Closed, 2026-09-22. Product image booted to NextUI. | [Phase 0](phases/phase-00.md) |
| 1 | Closed, 2026-09-23. Application-scoped Weston. | [Phase 1](phases/phase-01.md) |
| 2 | Closed, 2026-09-23. Eighteen kernel patches remained. | [Phase 2](phases/phase-02.md) |
| 3 | Closed, 2026-09-25. Built-in gamepad accepted. | [Phase 3](phases/phase-03.md) |
| 4 | Closed, 2026-09-28. Applications use InputPlumber `xb360` pads. | [Phase 4](phases/phase-04.md) |
| 5 | Closed, 2026-09-28. Second patch reduction. | [Phase 5](phases/phase-05.md) |
| 6 | Closed. Deep suspend from the power button. | [Phase 6](phases/phase-06.md) |
| 7 | Closed. DMC is an external module. | [Phase 7](phases/phase-07.md) |
| 8 | Closed, 2026-09-30. NextUI is a pinned fork. | [Phase 8](phases/phase-08.md) |
| 9 | Closed, 2026-10-04. Published `zlyme44`. | [Phase 9](phases/phase-09.md) |
| 10 | Closed, 2026-10-06. `zlyme44.1` was not published. | [Phase 10](phases/phase-10.md) |
| 11 | Closed, 2026-10-08. Published `zlyme44.2`. | [Phase 11](phases/phase-11.md) |
| 12 | Closed, 2026-10-14, with the recorded limits. | [Phase 12](phases/phase-12.md) |
| 13 | Closed, 2026-10-16, on `ccd99997`. B6 and C1 excluded. | [Phase 13](phases/phase-13.md) |
| 14 | Closed, 2026-10-26. Release not published in that phase. | [Phase 14](phases/phase-14.md) |
| 15 | Closed, 2026-10-27. `zlyme44.4` published separately. | [Phase 15](phases/phase-15.md) |
| 16 | Closed, 2026-11-02. Local logging audit. Not a public release. | [Phase 16](phases/phase-16.md) |
| 17 | Closed, 2026-11-04. Documentation and local agents. Not firmware. | [Phase 17](phases/phase-17.md) |
| 18 | Closed, 2026-11-21. Published `zlyme44.5`. | [Phase 18](phases/phase-18.md) |
| 19 | Active. 19B is closed. 19C1 is the instruction preflight. Not firmware. | [Phase 19](phases/phase-19.md) |

## Historical records

- [Roadmap snapshot, 2026-11-17](archive/roadmap-2026-11-17.md), including [Where we are](archive/roadmap-2026-11-17.md#where-we-are) and [Closed phases](archive/roadmap-2026-11-17.md#closed-phases)
- [Research index](research/README.md)
- [Logbook](LOGBOOK.md)
