# Phase 17 — Documentation architecture and local AI development infrastructure

Status: Proposed. Not started. This file is a draft for review. It does not authorize implementation, a firmware change, an OTA, or a release.

Phase 16 is closed. Phase 18 holds the postponed Zlyme 45 feature plan, in [phase-18-plan.md](phase-18-plan.md). `ZLYME_VERSION` stays `zlyme44.4`. The local tools named for this work are Ollama, a Qwen3.8-27B GGUF IQ4_XS model, a 128K context, and OpenCode, alongside Cursor. This plan does not add speed, token, or model benchmarks.

`AGENTS.md` is shortened only after the destination documents and their owners are stable. That is why 17B precedes 17C.

## Preservation contract

Existing documents are the engineering record. They are not prose to shorten for its own sake. Git history can roll a bad edit back. It does not replace a correct current document.

Before a canonical document is changed, the change record names:

- the contracts that document owns;
- incoming references from other documents, `AGENTS.md`, and the agent rules;
- source and test files that cite those paths or headings;
- the original path, heading, and the commit being changed;
- the proposed destination and why that owner is clearer;
- whether the edit is relocation, clarification, or a contract change;
- which safety constraints must still be present afterward;
- a reviewable before-and-after comparison;
- the tests that cover the changed content.

A significant change of ownership needs maintainer acceptance before the next document moves.

Three operations stay separate:

- A is pure relocation. The words move. The contract does not change.
- B is editorial clarification. Wording changes. The contract does not.
- C is a substantive contract change. It is its own change, with its own acceptance.

A and C are not mixed in one operation. Text is not removed because an agent calls it repetitive. Dates, source identities, SHA values, test limits, and accepted dispositions stay with the fact they belong to. Research, the archive, the logbook, and the ADRs are not deleted.

## How a later implementation proceeds

Each migration starts from a recorded clean SHA on a dedicated branch. It changes one coherent unit, reviews the whole diff, checks references and contract tests, and stops if a discrepancy is unresolved. The next major document waits for acceptance.

No script rewrites the canonical set in one pass. No AI summary replaces a measurement or a decision. There is no file-size target.

## Documentation tests, as they stand

`scripts/tests/test_doc_links.py` checks an explicit list. That list includes `docs/ROADMAP.md`, `docs/README.md`, and `docs/research/README.md`. It does not include `docs/research/phase-17-plan.md` or `docs/research/phase-18-plan.md`. It does not include most other research files. Inside the listed files it checks Markdown links and heading anchors. Backtick paths are checked only outside the roadmap, the logbook, and the Phase 10 audit. A new subdocument is invisible to this test until the list names it.

`scripts/tests/test_doc_contracts.py` checks version strings across a canonical list, the pinned baseline table in `docs/DEVELOPMENT.md`, the NextUI row in `docs/UPSTREAMS.md`, the `device.conf` blocks in `docs/ARCHITECTURE.md` and `docs/DEVICE_PORTING.md`, and the Rumble Strength default in `docs/ARCHITECTURE.md` and `docs/USER_GUIDE.md`. It also requires `## Install` in `README.md`. Moving one of those values without moving the assertion would fail the test, or, if the assertion were deleted, would hide the drift.

Later work includes a new canonical file in the link check, checks anchors, and searches the repository for the old path. Existing assertions stay. An assertion moves only when ownership of that fact moves. A check is not removed to make a restructure pass.

## 17A. Documentation inventory and ownership

Purpose: name what each document owns, and what points at it, before any file is split.

Existing evidence: [docs/README.md](../README.md) is the map. `AGENTS.md` is the shared reading list. `.cursor/rules/zlyme-core.mdc` repeats a short form of that list and is `alwaysApply: true`. On 2026-11-02 the larger files included `docs/LOGBOOK.md`, `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md`, `docs/USER_GUIDE.md`, `docs/ROADMAP.md`, and `docs/UPSTREAMS.md`. Disk size is not the same as text an agent loads.

Candidate paths: the map, `AGENTS.md`, `docs/WRITING.md`, and `docs/research/README.md`.

Proposed work: list current contracts, historical evidence, research, and superseded material. Mark repeated instructions, repeated current-state facts, outdated links, and facts buried in a long paragraph. Say which files a task must open. Do not delete history. Do not treat a large file as a defect only because it is large.

Verification: the inventory is read-only. It names one owner for each contract it lists, plus the references that would have to move with that contract. It does not propose deleting the logbook, the archive, or research evidence.

Risks: an inventory that copies documents, or that calls a rule redundant without naming who consumes it.

Exclusions: no file moves. No firmware change. This planning note is not 17A.

The read-only inventory for that review is [phase-17-documentation-inventory.md](phase-17-documentation-inventory.md). It is not approval and not 17A closure.

Done when: the maintainer has reviewed and approved the ownership and dependency inventory.

Depends on: nothing else in this phase.

## 17B. Canonical document restructuring

Purpose: move a section only when the new file is a clearer owner, and only under the preservation contract.

Existing evidence: `docs/ARCHITECTURE.md` is the current runtime contract. Its headings run from scope through architectural invariants, including boot, storage, update, graphics, audio, and the frontend. `docs/OPERATIONS.md` is the live-device runbook. `docs/DEVELOPMENT.md`, `docs/MAINTENANCE.md`, `docs/UPSTREAMS.md`, and `docs/DEVICE_PORTING.md` already have distinct jobs. `docs/ROADMAP.md` is the sequencing map. `docs/LOGBOOK.md` is dated evidence. `docs/USER_GUIDE.md` is for a person using the Flip. The contract test binds specific facts to `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md`, `docs/ARCHITECTURE.md`, `docs/DEVICE_PORTING.md`, and `docs/USER_GUIDE.md`.

Worth a look, not an automatic split: an architecture section that is already cohesive, such as graphics or audio, if the overview can link to it without splitting a boot, storage, or update rule. Long recovery procedures in operations, as distinct from the invariants. Older roadmap phase writeups only where the logbook or a research file already holds the evidence.

Leave these put unless 17A shows a repeated mutable fact: `docs/ENGINEERING_PRINCIPLES.md`, `docs/AUDITING.md`, `docs/WRITING.md`, `docs/decisions/`, the user guide, and the logbook.

Proposed work: one ownership decision per move, classified as A, B, or C. A move keeps dates and image identities, updates links and anchors, and does not restate current status in a second file. A decision that a document should not be split is a recorded result.

Verification: the preservation record for each unit, `scripts/tests/test_doc_links.py`, `scripts/tests/test_doc_contracts.py`, and a search for the old path. Unchanged facts remain equivalent. A human can still read the user guide and the architecture overview.

Risks: two files claiming the same current fact, or a summary that replaces a measurement.

Exclusions: no dozens of tiny files. No size quota. No silent rewrite. No runtime or package change. No mixing of relocation and a contract change.

Done when: every authorized move is complete, references resolve, contracts are still represented, and unchanged facts are still equivalent. A documented decision not to split a file counts.

Depends on: 17A.

## 17C. Universal agent instructions

Purpose: implement a smaller `AGENTS.md` only after 17B's owners are stable. Cursor and OpenCode both follow that file. Critical rules stay in it, not in an optional skill.

Existing evidence: `AGENTS.md` is the reading list. `.cursor/rules/zlyme-core.mdc` defers to it. `.opencode/agents/zlyme-code-reviewer.md` is a separate adapter with its own permission block.

Rules that stay in `AGENTS.md`: Miyoo Flip only; Buildroot `BR2_EXTERNAL`; hardware and filesystem safety; the source-of-truth order; no speculative architecture; read-only root and `/storage`; direct DRM/KMS; PipeWire and InputPlumber; the immutable NextUI pin; Git safety; no bulk firmware copy over the network; licensing and provenance; no unapproved OTA, release, or dangerous device operation; stay inside the requested scope; separate source inspection, host tests, and Flip acceptance; the independent reviewer; and maintainer authorization outside that scope.

Proposed work: add a short routing table to the documents 17B left in place. A documentation edit does not load the kernel sections. A package update loads maintenance and upstreams. A boot or storage change loads architecture and operations. Do not paste those documents back into `AGENTS.md`.

Verification: both tools can use the new routing. Every rule listed above is still present without loading a skill. A reader can point from the rule to the document it names.

Risks: deleting a safety rule to make the file shorter, or leaving two copies that drift.

Exclusions: no benchmark of load time. This planning commit does not edit `AGENTS.md`.

Done when: the smaller `AGENTS.md` is implemented, the invariants above remain available without a skill, and both supported tools follow the routing.

Depends on: 17B. It does not start from an outline alone.

## 17D. Portable skills and rule routing

Purpose: implement a shared skill or another verified route that points at a contract, without copying the contract.

Existing evidence: this repository has no `.agents/skills/` tree. `.cursor/rules/knulli-packages.mdc` is package-update guidance and is `alwaysApply: true`. `.cursor/rules/zlyme-core.mdc` stays the pointer to `AGENTS.md`. Review adapters are `.cursor/agents/zlyme-code-reviewer.md` and `.opencode/agents/zlyme-code-reviewer.md`. The OpenCode file's permission block is tool-specific. The review policy is in `AGENTS.md` and `docs/AUDITING.md`.

Candidate layout, not yet verified on the installed tools: `.agents/skills/<name>/SKILL.md`. Check the installed Cursor and OpenCode versions and their documentation first. If that path does not load, record the limitation and use an alternative the maintainer accepts. Do not claim the file works.

Candidates, not a list that must all be built: package and emulator updates; NextUI integration; Buildroot and release steps; hardware inspection; defect review; documentation and roadmap edits. Each skill names when it applies, points at the owning document, states what it may do, and repeats the safety limits the task could violate.

`knulli-packages.mdc` is the rule to reconsider. Scoping it to package files would stop it loading on an unrelated edit. Keep both reviewer adapters. Do not force one tool's permission syntax into the other.

Verification: the installed Cursor and OpenCode versions actually load the chosen mechanism, or the limitation and the approved alternative are recorded. A package task still receives the comparison rule.

Risks: a skill that contradicts `AGENTS.md`, or a scoped rule that disappears when a recipe changes.

Exclusions: no skills are added in this planning commit. No vector database or retrieval service unless routing cannot do the job.

Done when: the chosen mechanism is implemented and verified on the installed tools, or the verified limitation and the accepted alternative are recorded. A yes-or-no discussion is not completion.

Depends on: 17C, so skills point at the routes that file actually ships.

## 17E. Functional validation and safety

Purpose: record that an agent finds the right instructions and still refuses the dangerous action. This is not a performance test.

Representative tasks, using a temporary or read-only setup:

1. A documentation-only correction.
2. A small PAK or shell change.
3. A NextUI investigation that does not edit the fork.
4. A Buildroot package-update reading, not a silent upgrade.
5. A storage or update question that must not unmount, fsck, or build an OTA.
6. An independent review of one named diff.
7. Release preparation that stops before `publish_release`.

Check that the route finds the owning document, the safety rule is still visible without a skill, the intended skill loads when one exists, Cursor and OpenCode follow the same project policy, and the reviewer adapters still cannot edit. No hardware command is run in order to test the instructions. Do not record token counts, timings, or model comparisons.

Verification: a written result for each task naming the file selected, the rule that applied, and the action refused. The documentation tests still pass.

Risks: a result that skips the safety rule, or a claim that the Flip was tested when it was not.

Exclusions: no destructive device operation and no speed gate.

Done when: instruction discovery, routing, safety behavior, and reviewer permissions have recorded functional checks for these tasks. An outline of the tests is not that result.

Depends on: 17C and 17D.

## 17F. Reconciliation and handoff

Purpose: accept the documentation and agent-tooling result. This phase does not ship firmware.

Check one owner per contract, no missing safety rule, no second copy of a mutable status line, valid links, the documentation tests, research and logbook still present, both tools still pointed at `AGENTS.md`, and both reviewer adapters still constrained as each tool allows. The README and user guide still make sense to a person. [phase-18-plan.md](phase-18-plan.md) still contains the postponed feature work. The diff has no runtime or packaging change.

Phase 17 closes on that documentation and tooling acceptance. It does not need an OTA or a Flip run only because pages moved. It does not publish a release.

Verification: the preservation records, the link and contract tests, the 17E results, and a review that the agent configuration still matches the policy.

Risks: calling the phase closed while a safety rule exists only in a skill the tools do not load.

Exclusions: no Phase 18 implementation. No `ZLYME_VERSION` change.

Done when: the preservation, link, test, ownership, and agent-configuration gates have passed, and the maintainer accepts that result. Phase 18 is still proposed. A proposal or a yes-or-no decision is not completion.

Depends on: 17A through 17E.
