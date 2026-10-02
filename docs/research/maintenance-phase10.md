# Phase 10 — maintenance outline

Planning only. Phase 10 may start on `main` after the Phase 9 merge and the dispatch of the remote clean build. Do not wait for that remote build to finish, and do not create its branch from this note. Complete the Zlyme documentation in this repository first. The hardware-wiki agent runs only after that documentation exists. Do not add `docs/MAINTENANCE.md` until that phase. The roadmap summary is in `docs/ROADMAP.md`.

## 10A. Zlyme documentation and comments

Zlyme-owned source in this repository only. A comment earns its place when it records a hardware quirk, a safety order, ownership, a lifecycle constraint, a compatibility requirement, an upstream workaround, or why a magic value or a simpler design is unsafe. Do not narrate syntax. Do not comment vendored minui-list, minui-presenter, or parson for style. Do not move the NextUI pin for wording. Do not refactor in the same commit. A real bug gets its own commit.

## 10B. Maintenance playbook

One short page. `AGENTS.md` will point update work at it. The page links to `docs/UPSTREAMS.md`, `docs/DEVELOPMENT.md`, `docs/OPERATIONS.md`, and `docs/ENGINEERING_PRINCIPLES.md`. It does not restate them.

Kernel and ROCKNIX-derived patches: name the selected Linux version, check upstream Linux first, then current ROCKNIX RK3566 changes. `Zetarancio/distribution` is historical Miyoo Flip evidence only. Mark each patch upstream, backport, board-specific, still required, or obsolete. Keep authorship. Re-check hardware contracts when a hardware-facing patch changes.

Emulator and core updates: read that project's upstream first, then the active ROCKNIX and KNULLI recipe, version, patches, and flags. Use Spruce when it has Miyoo Flip policy evidence. Compare dependencies and licenses. Keep direct KMS, input, and audio. Build the package narrowly. Smoke a representative title. A newer pin in another distribution is not a reason to take it.

Vendored helpers: minui-list, minui-presenter, and parson stay at recorded commits until a review says otherwise. Record repository, tag, commit, and license. The local-source fingerprint in `build.sh` must rebuild the helper, and minui-presenter when list or NextUI's pin changes. Prove source and build equivalence before a behavior change.

NextUI: `Zetarancio/NextUI` is a fork of `LoveRetro/NextUI`. Buildroot pins an exact commit on the `zlyme` branch. Review upstream commits. Do not rebase the fork onto upstream HEAD to look current. Keep other-platform source in the fork. Hardware equivalence is required when runtime behavior changes, not for a comment or docs-only pin note.

README and releases: the user-visible delta starts at the last non-prerelease, `zlyme40 (2026-09-23)`, tag `zlyme-35854070921`. Emulator and PAK lists come from the image. Deep technical detail stays in Zlyme docs or the wiki. Release notes describe accepted behavior, not the logbook. The local incremental OTA is the hardware-acceptance image. The remote clean Buildroot run from the merged Phase 9 SHA is the release artifact. Implementation closure does not wait for that run to finish. A failed remote build still blocks a stable release.
## 10C. Wiki synchronization

Repository: `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`.

Keep its `AGENTS.md`, `docs/DOCUMENTATION_MODEL.md`, evidence rules, and hardware-safety rules. Do not invent a second documentation model. The open job is to refresh stale Zlyme implementation text, especially `docs/implementations/zlyme.md`, after the Phase 10 Zlyme documentation in this repository is written. That page currently declines to record a snapshot and does not claim deep suspend, the replacement joypad driver, InputPlumber, current DMC packaging, or the Weston runtime.

Record `Last synchronized against Zlyme <release / exact SHA>` on that page. Runtime evidence is the exact Phase 9 implementation SHA. Documentation guidance is the later Phase 10 Zlyme documentation SHA. A wiki edit uses those pinned SHAs. It does not assume another agent's working tree.

| Topic | Wiki | Zlyme |
| --- | --- | --- |
| Joypad | Controls, UART1 protocol, packet facts, GPIO/UART limits | Driver, InputPlumber topology, virtual pad, calibration plumbing |
| Deep suspend | BL31/SIP, `ARMOFF_LOGOFF`, `vdd_logic` constraint, measured hardware | DTS, packages, init, runtime |
| DMC | RK3566/RK3568 V2 SIP, DFI, firmware API | External module, selected patches, load and runtime policy |

Do not copy architecture manuals across. Do not mirror files in both directions. ROCKNIX notes that are historical evidence stay labeled that way.

