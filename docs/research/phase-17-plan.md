# Phase 17 — Documentation architecture and local AI development infrastructure

Status: Proposed. Not started. This file is a draft for review. It does not authorize implementation, a firmware change, an OTA, or a release.

Phase 16 is closed. Phase 18 holds the postponed Zlyme 45 feature plan, in [phase-18-plan.md](phase-18-plan.md). `ZLYME_VERSION` stays `zlyme44.4`. The local tools named for this work are Ollama, a Qwen3.8-27B GGUF IQ4_XS model, a 128K context, and OpenCode, alongside Cursor. This plan does not add speed, token, or model benchmarks.

## 17A. Documentation inventory and ownership

Purpose: name what each document owns before any file is split or shortened.

Existing evidence: [docs/README.md](../README.md) is already the map. `AGENTS.md` is the shared reading list. On 2026-11-02 the larger files were `docs/LOGBOOK.md` (330 KB), `docs/ARCHITECTURE.md` (104 KB), `docs/OPERATIONS.md` (51 KB), `docs/USER_GUIDE.md` (47 KB), `docs/ROADMAP.md` (46 KB), and `docs/UPSTREAMS.md` (36 KB). Size on disk is not the same as text an agent loads. A large logbook is appropriate if nothing in the default task list reads it.

Candidate paths: the map above, `AGENTS.md`, `docs/WRITING.md`, and the research index.

Proposed work: list current contracts, historical evidence, research, and superseded material. Mark repeated instructions, repeated current-state facts, and facts buried in a long paragraph. Say which files a task must open and which it must not. Do not delete history. Do not treat a large file as a defect only because it is large.

Verification: the inventory names one owner for each contract it lists, and it does not propose a deletion of logbook, archive, or research evidence.

Risks: an inventory that copies the documents instead of pointing at them.

Exclusions: no file moves in the inventory pass. No firmware change.

Done when: a short ownership map exists and the maintainer has accepted it as the input to 17C.

Depends on: nothing else in this phase.

## 17B. Universal agent instructions

Purpose: keep one smaller `AGENTS.md` that Cursor and OpenCode both follow, with the safety rules still in that file.

Existing evidence: `AGENTS.md` is about 21 KB and is the reading list. `.cursor/rules/zlyme-core.mdc` is `alwaysApply: true` and already defers to it. `.opencode/agents/zlyme-code-reviewer.md` is a separate adapter with its own permission block.

Rules that stay in `AGENTS.md`, not behind another click: Miyoo Flip only; Buildroot `BR2_EXTERNAL`; hardware and filesystem safety; the source-of-truth order; no speculative architecture; read-only root and `/storage`; direct DRM/KMS; PipeWire and InputPlumber; the immutable NextUI pin; Git safety; no bulk firmware copy over the network; licensing and provenance; no unapproved OTA, release, or dangerous device operation; stay inside the requested scope; separate source inspection, host tests, and Flip acceptance; the independent reviewer; and maintainer authorization for work outside that scope.

Proposed work: add a short routing table. A documentation edit does not load the kernel or emulator sections. A package update loads maintenance and upstreams. A boot or storage change loads architecture and operations. Do not paste those documents back into `AGENTS.md`.

Verification: a reader can point at the rule and the document it routes to. Both Cursor and OpenCode instructions still name `AGENTS.md` as the contract.

Risks: shrinking the file by deleting a safety rule, or leaving two copies that drift.

Exclusions: do not edit `AGENTS.md` as part of writing this plan. No benchmark of how fast the shorter file loads.

Done when: the proposed `AGENTS.md` outline is accepted and every rule listed above still has a sentence in that outline.

Depends on: 17A, so the routes name real owners.

## 17C. Canonical document restructuring

Purpose: split a document only when the new file has a clearer owner than the section it leaves.

Existing evidence: `docs/ARCHITECTURE.md` is the current runtime contract and is the largest of those contracts, at about 104 KB, with numbered sections from scope through services. `docs/OPERATIONS.md` is the live-device runbook. `docs/DEVELOPMENT.md` is the build guide. `docs/MAINTENANCE.md` owns pins, releases, and the debt index. `docs/UPSTREAMS.md` owns provenance. `docs/DEVICE_PORTING.md` owns the board boundary. `docs/ROADMAP.md` is the sequencing map; closed phases 0–15 are still long, and Phase 16 was shortened on 2026-11-02. `docs/LOGBOOK.md` is dated evidence and must stay append-only. `docs/USER_GUIDE.md` is for a person using the Flip.

Worth a look, not an automatic split: architecture sections that are already self-contained, such as graphics, audio, or the update path, if the overview can link to them without breaking a cross-system rule. Operations procedures that are long recovery steps rather than invariants. Roadmap entries for closed phases, only if the evidence already lives in the logbook or a research file.

Leave these as the owner they already are unless 17A finds a repeated fact: `docs/ENGINEERING_PRINCIPLES.md`, `docs/AUDITING.md`, `docs/WRITING.md`, `docs/decisions/`, the user guide, and the logbook. Do not carve the boot, storage, and update contracts into separate files just to make more of them.

Proposed work: one ownership decision per move. The main architecture page stays navigable. A moved section keeps its dates and image identities. Superseded text stays recoverable. Links and heading anchors are updated in the same change. Current status is not restated in a second file.

Verification: `scripts/tests/test_doc_links.py` and `scripts/tests/test_doc_contracts.py`. A human can still read the user guide and the architecture overview without an agent.

Risks: two files claiming the same current fact, or a summary that replaces a measurement.

Exclusions: no dozens of tiny files. No size quota. No silent rewrite of evidence. No runtime or package change.

Done when: each move that landed has one owner, and the files that stayed put are named.

Depends on: 17A. It does not wait for 17D.

## 17D. Portable skills and rule routing

Purpose: see whether Cursor and OpenCode can share a small skill that points at a contract, without copying the contract.

Existing evidence: this repository has no `.agents/skills/` tree. Cursor rules that always apply are `.cursor/rules/zlyme-core.mdc` and `.cursor/rules/knulli-packages.mdc`. The second is package-update guidance and is `alwaysApply: true` even for tasks that do not touch a recipe. Review adapters are `.cursor/agents/zlyme-code-reviewer.md` and `.opencode/agents/zlyme-code-reviewer.md`. The OpenCode file denies every action and then allows read, glob, and grep. Those permission blocks are tool-specific. The review policy they both follow is in `AGENTS.md` and `docs/AUDITING.md`.

Candidate layout, not yet verified: `.agents/skills/<name>/SKILL.md`. Before any skill file is added, check the installed Cursor and OpenCode versions and their current documentation. If that path needs a newer version than the one in use, record that and do not pretend the file loads.

Candidates, not a list that must all be built: package and emulator updates; NextUI integration; Buildroot and release steps; hardware inspection; defect review; documentation and roadmap edits. Each skill names when it applies, points at the owning document, states what it may do, and repeats the safety limits that the task could violate. It does not paste an architecture section.

`knulli-packages.mdc` is the rule to reconsider. Scoping it to package files would stop it loading on an unrelated edit. `zlyme-core.mdc` stays always applied because it is the pointer to `AGENTS.md`. Keep both reviewer adapters. Do not force OpenCode's permission syntax into the Cursor file, or the reverse. One policy owner, two adapters.

Verification: the installed tools can see a trial skill, or the plan records that they cannot. A package task still receives the Knulli and Rocknix comparison rule. A documentation task does not need it.

Risks: a skill that contradicts `AGENTS.md`, or a scoped rule that no longer appears when a recipe changes.

Exclusions: do not add skills or agent configs in this planning commit. No new agent framework, vector database, or retrieval service unless a later task shows the routing table cannot do the job.

Done when: the maintainer has a yes or no on the skill directory, and a decision on whether `knulli-packages.mdc` stays `alwaysApply`.

Depends on: 17B, so skills point at the same routes. It can be drafted beside 17C.

## 17E. Functional validation and safety

Purpose: show that an agent can find the right instructions and still refuse the dangerous action. This is not a performance test.

Representative tasks, using a temporary or read-only setup:

1. A documentation-only correction.
2. A small PAK or shell change.
3. A NextUI investigation that does not edit the fork.
4. A Buildroot package-update reading, not a silent upgrade.
5. A storage or update question that must not unmount, fsck, or build an OTA.
6. An independent review of one named diff.
7. Release preparation that stops before `publish_release`.

Check that the route finds the owning document, the safety rule is still visible, the skill loads when one exists, Cursor and OpenCode are held to the same project policy, and the reviewer adapters still cannot edit. No hardware command is run in order to test the instructions. A host documentation test is enough for links and contracts. Do not record token counts, timings, or model comparisons.

Verification: a written result for each task that says which file was selected and which action was refused. `test_doc_links.py` and `test_doc_contracts.py` still pass.

Risks: a test that "passes" by skipping the safety rule, or a claim that the Flip was tested when it was not.

Exclusions: no destructive device operation, no speed gate, no GPU measurement.

Done when: each of the seven tasks has a result, and any miss is a defect in the instructions rather than a waiver.

Depends on: the instruction and routing changes from 17B and 17D. 17C's link check can run with it.

## 17F. Reconciliation and handoff

Purpose: accept the documentation and agent-tooling result. This phase does not ship firmware.

Check one owner per contract, no missing safety rule, no second copy of a mutable status line, valid links, existing doc tests, research and logbook still present, both agent tools still pointed at `AGENTS.md`, and both reviewer adapters still read-only in the way each tool allows. The README and user guide still make sense to a person. [phase-18-plan.md](phase-18-plan.md) still contains the postponed feature work. The diff has no runtime or packaging change.

Phase 17 closes on that documentation and tooling acceptance. It does not need an OTA or a Flip run only because pages moved. It does not publish a release.

Verification: the documentation tests, a review of the diff, and the seven 17E results.

Risks: calling the phase closed while a safety rule exists only in a skill the tools do not load.

Exclusions: no Phase 18 implementation. No `ZLYME_VERSION` change.

Done when: the maintainer accepts the documentation tree and the agent setup, and Phase 18 is still proposed.

Depends on: 17A through 17E.
