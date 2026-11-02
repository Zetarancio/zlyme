# Phase 17B preservation decisions

Status: first unit only, 2026-11-02. Not an extraction. Not 17B closure.

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

## Operations: no move

`docs/OPERATIONS.md` stays the live-device and recovery runbook. No heading in it is moved. It remains a supporting statement of the same boot, storage, and shutdown behavior, not a second architecture.

## What this unit does not do

It does not shorten `AGENTS.md`. It does not change a technical contract. It does not delete evidence. It does not start Phase 18.
