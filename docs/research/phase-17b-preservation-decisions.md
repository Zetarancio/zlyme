# Phase 17B preservation decisions

Status, first unit, 2026-11-02: first unit only. Not an extraction. Not 17B closure. That status belongs to the retain decision below. It is not the final result.

Status, 2026-11-02: 17B is closed. The later [final disposition](#final-disposition-2026-11-02) supersedes the section 9 retain sentence only.

Baseline: `7d38db090c203fdcc002349ee6ea35a7ee1fb492` on branch docs/phase-17a-inventory. The headings below were read in `docs/ARCHITECTURE.md` and `docs/OPERATIONS.md` at that commit. No sentence in those files was moved or rewritten.

## Architecture sections 5–7: retain

`## 5. Boot architecture`, `## 6. Image and storage model`, and `## 7. Update architecture` stay in `docs/ARCHITECTURE.md`.

They describe one coupled safety path: BusyBox init, the read-only root, persistent `/storage`, shutdown through `zlyme-halt`, and OTA publication of the single root. [ADR 0006](../decisions/0006-root-image-lifecycle.md) is the root-lifecycle decision. [ADR 0003](../decisions/0003-busybox-init.md) is the init decision. Splitting these sections would separate failure behavior that has to be read together.

## Architecture section 11: retain

`## 11. Frontend and PAK runtime` stays in `docs/ARCHITECTURE.md`.

It is the NextUI session and the ownership of a PAK launch, including return to the frontend. Graphics and audio sections refer back to that session. The section stays with them.

## Architecture sections 8 and 9: not authorized

`## 8. Graphics` and `## 9. Audio` are not extracted.

They meet the session in section 11, and they meet HDMI, application launch, and return to the frontend. A later extraction has to list incoming references, those cross-section dependencies, and a preservation record before any move. This unit does not authorize that assessment's conclusion.

That retain decision still stands for graphics. The accepted audio move superseded it for section 9 only. The [final disposition](#final-disposition-2026-11-02) records the distinction.

## Operations: no move

`docs/OPERATIONS.md` stays the live-device and recovery runbook. No heading in it is moved. It remains a supporting statement of the same boot, storage, and shutdown behavior, not a second architecture.

## What this unit does not do

It does not shorten `AGENTS.md`. It does not change a technical contract. It does not delete evidence. It does not start Phase 18.

## Audio relocation

Operation: pure relocation. Baseline `06f550e37e25e538308931ba6a4519f23127345a`.

Source: `docs/ARCHITECTURE.md`, heading `## 9. Audio`, lines 434–442, the body after that heading and before `## 10. Input, lid and handheld controls`. Destination: `docs/architecture/audio.md`. The heading stays in `docs/ARCHITECTURE.md` and links to the moved body. Section 10 and sections 5–8 and 11–16 were not edited.

Incoming checks: no Markdown link used the `#9-audio` anchor. `AGENTS.md` tells an audio change to read `docs/ARCHITECTURE.md`, which still contains the heading. ADR 0007, `docs/OPERATIONS.md` `## Audio`, and `docs/MAINTENANCE.md` `## Audio on a live Flip` keep their own text. No test required the full body to remain inside `docs/ARCHITECTURE.md`. The contract scan now includes the new file so that text stays in the version check.

The original body and the body after the new title are both 5294 bytes. SHA-256 `2ce1ad0ca0d60d151fae866a01ddcaf04671719ad22b787b326b9cd23d46921f`. They match.

Sections 8 and 9 were not both moved. Graphics stays in `docs/ARCHITECTURE.md`. A later graphics extraction is still not authorized.

`scripts/tests/test_doc_links.py` and `scripts/tests/test_doc_contracts.py` were run after the move. The named reviewer agent was not invoked for this unit.

## Final disposition, 2026-11-02

17B is closed on the 17A inventory, the retain decisions in this file, the lossless audio move, and the link and contract coverage of that moved file. This disposition is later than the section 8 and 9 retain decision. It does not erase that decision.

- `## 8. Graphics` remains in `docs/ARCHITECTURE.md`.
- `## 9. Audio` was extracted unchanged to `docs/architecture/audio.md`.
- The original `## 9. Audio` heading remains in `docs/ARCHITECTURE.md`.
- Sections 5–7 and 11 remain in `docs/ARCHITECTURE.md`.
- `docs/OPERATIONS.md` was not moved.
- No other architecture extraction is authorized.

The byte comparison stays in the audio relocation section above. This disposition does not restate the audio contract.
