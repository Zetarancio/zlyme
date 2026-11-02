# Phase 17A documentation ownership inventory

Status: research for review, 2026-11-02. Not an architecture specification. Not 17A closure. Not authorization for 17B.

Audited tree: `docs/phase-17a-inventory` at `93f329b92e02e31ab54907ac730af070602124e5`, which is the parent of this report. `main` was `b9c46f428493c214e31aece13f82453e51979803` and was not moved. Phase 16 is closed. Phase 18 is the postponed feature plan.

Facts below were read from headings, line ranges, and tests. Proposals are marked as proposals.

## B. Document ownership map

[docs/README.md](../README.md) is the map. [AGENTS.md](../../AGENTS.md) lines 32–78 are the agent reading list. `.cursor/rules/zlyme-core.mdc` repeats a short form of that list and is `alwaysApply: true`.

| Role | Owner | Not the owner |
| --- | --- | --- |
| How to change the code | [docs/ENGINEERING_PRINCIPLES.md](../ENGINEERING_PRINCIPLES.md), sections 1–26 | `AGENTS.md`, which says how an agent applies those principles |
| What the system is | [docs/ARCHITECTURE.md](../ARCHITECTURE.md), sections 1–16 | `docs/ROADMAP.md`, which `AGENTS.md` lines 76–78 call non-normative |
| Why a durable choice was made | `docs/decisions/0001` through `0012` | Research files, which `docs/research/README.md` says are not normative |
| Board boundary | [docs/DEVICE_PORTING.md](../DEVICE_PORTING.md), `## Runtime command contract` | A second-device design that does not exist |
| Build and package | [docs/DEVELOPMENT.md](../DEVELOPMENT.md) | `docs/MAINTENANCE.md`, which owns pins, releases, and debt |
| Live device and recovery | [docs/OPERATIONS.md](../OPERATIONS.md) | The user guide, which is task-oriented |
| Pins, releases, open debt | [docs/MAINTENANCE.md](../MAINTENANCE.md), `## NextUI fork`, `## Releases`, `## Open validation debt` | `docs/UPSTREAMS.md`, which owns where a version comes from |
| Provenance and update comparison | [docs/UPSTREAMS.md](../UPSTREAMS.md), `## Source hierarchy` and `## Unspecified vendor binaries` | KNULLI or ROCKNIX trees |
| Defect classification | [docs/AUDITING.md](../AUDITING.md), `## Classification` | The code reviewer, which does not assign a disposition |
| Sequencing | [docs/ROADMAP.md](../ROADMAP.md) | The logbook |
| Dated evidence | [docs/LOGBOOK.md](../LOGBOOK.md) | A summary that replaces an entry |
| Human use of the Flip | [docs/USER_GUIDE.md](../USER_GUIDE.md) | Architecture |
| Prose rules | [docs/WRITING.md](../WRITING.md) | — |
| Experiments | `docs/research/` | Current behavior |

## C. Contract matrix

Observed source and tests are the ones named. A blank test cell means no dedicated assertion was found in the documentation tests. That is not proof no package test exists.

| Contract | Authoritative heading | Supporting | Source | Tests that would notice a move | Disposition |
| --- | --- | --- | --- | --- | --- |
| Engineering priorities | `AGENTS.md` `## Project`; principles sections 1–26 | `AGENTS.md` `## Rule precedence` | — | Link test includes both files | Retain. Confidence high |
| Buildroot and device boundary | Architecture `## 3` and `## 4`; ADR 0001 and 0004 | `docs/DEVICE_PORTING.md` `## Principle` | `board/my355/`, `external.mk` | `device.conf` block must match in architecture and device porting (`test_doc_contracts.py` lines 101–111) | Retain together. Confidence high |
| Hardware source of truth | Architecture `## Hardware source of truth`; upstreams `### Miyoo Flip hardware` | `AGENTS.md` external source list | Hardware wiki, not this tree | None for the wiki URL | Retain. Confidence high |
| Boot, init, shutdown | Architecture `## 5`; operations `## Boot classes` | ADR 0003 | `package/boot/zlyme-initramfs/init`, `board/my355/fsoverlay/etc/init.d/S15bootpart`, `S28minui`, `S90minui`, `usr/sbin/zlyme-halt` | `scripts/tests/test_s90_shutdown.sh` runs `S90minui`. It does not parse the docs | Do not split from storage or OTA. Confidence high |
| Storage and card ownership | Architecture `## 6`; ADR 0010 | User guide `## Libraries and storage`; operations `## Persistent state` | `usr/sbin/zlyme-storage`, `zlyme-halt` lines 76–88 | `scripts/tests/test_storage_gpt_type.py` reads `device.conf`, not the prose | Same coupling as boot. Confidence high |
| OTA and recovery | Architecture `## 7`; ADR 0006 | Operations `## Updates`; maintenance `## Releases` | `usr/sbin/zlyme-update` | `scripts/tests/test_update_archive.sh`, `test_delta_stage.sh` | Do not split from boot. Confidence high |
| Preloader and MASKROM | Operations `## Boot identity`; user guide `## Card preparation and preloader recovery` | Architecture hardware section; upstreams preloader rows | `package/system/zlyme-preloader/` | `scripts/tests/test_fw_helpers.sh`, `test_phase11c.sh` named in upstreams lines 253–270 | User guide owns the operator steps. Architecture owns the invariant. Confidence high |
| Kernel, DTS, board | Maintenance `## Kernel and board patches`; device porting `## Board make integration` | Architecture `## Kernel extension policy` | `board/my355/linux/`, `board/my355/` | No doc test locks patch filenames | Owner is maintenance for process, board tree for bytes. Confidence high |
| DRM/KMS and Weston | ADR 0002; architecture `## 8` | Operations `## DRM ownership` | `zlyme-weston-run`, session DRM release | None found in the doc tests | Graphics shares the session. See section F. Confidence high |
| GPU and HDMI | ADR 0008; architecture `### Miyoo Flip GPU stacks` | Operations `## GPU` | board GPU scripts | No doc test locks the PanVK sentence | Retain with graphics until 17B reviews the section. Confidence medium |
| PipeWire and Bluetooth | ADR 0007; architecture `## 9` | Operations `## Audio` and `## Wi-Fi and Bluetooth`; maintenance `## Audio on a live Flip` | `zlyme-audio`, PipeWire init | No doc test locks the version string | Version is repeated. See section H. Confidence high |
| Input, mappings, suspend | ADR 0005; architecture `## 10` | User guide `## Joysticks and rumble`; operations `## Input and lid` and `## Suspend` | InputPlumber, `miyoo-flip-gamepad`, `zlyme-keylidmon` | Rumble default must remain stated in architecture and the user guide (`test_doc_contracts.py` lines 113–126) | Do not move the rumble sentence without the assertion. Confidence high |
| NextUI pin | `package/system/nextui/nextui.mk` line 25; upstreams table row `NextUI fork` | Maintenance `## NextUI fork` | `nextui.mk` | Contract test lines 96–99 require that row's SHA to equal `NEXTUI_VERSION` | The makefile is the value. The table is the checked prose. Confidence high |
| Emulators and PortMaster | Architecture `## 12` and `### PortMaster installation`; ADR 0009 | User guide `## Systems and emulators` and `## PortMaster` | `package/system/nextui/paks/`, `package/emulators/` | `scripts/tests/test_systems_table.py` reads the user-guide table | Guide owns the table a person sees. Architecture owns the model. Confidence high |
| Package updates and provenance | Upstreams `## Package update workflow` | Maintenance `## Emulator, core, and package updates`; `.cursor/rules/knulli-packages.mdc` | package recipes | The rule is not in the doc tests | Rule and upstreams must stay in agreement. Confidence high |
| Licenses and exceptions | Upstreams `## Unspecified vendor binaries` lines 218–248; `AGENTS.md` `## Licensing` | `preloader-stock.PROVENANCE`, `portmaster-rocknix-compat/PROVENANCE` and `allowlist.sha256` | those packages | No doc test counts the allowlist | See the open count question in section J. Confidence medium |
| Logging | ADR 0012; architecture logging paragraphs | Inventory `docs/research/phase-16-logging-inventory.md`; operations `## Logs` | `usr/sbin/zlyme-logs`, `package/system/nextui/zlyme/pak-log.sh` | `test_pak_logging.sh`, `test_log_history.sh`, `test_log_boot_scope.sh`, `test_portmaster_log.sh` test code, not the ADR text | ADR owns the decision. Inventory owns the launcher list. Confidence high |
| Reproducibility and cache | Development `## Reproducibility` and `## Build output and caches` | `.github/zlyme-cache.md`; Phase 18 plan section 18B | `build.sh` | No doc test asserts `BR2_CCACHE` | Phase 18 owns the investigation. Do not move that plan. Confidence high |
| Hardware evidence | Logbook entries, with the image SHA in the entry | Roadmap closure summaries | — | Doc tests do not check logbook claims | Do not replace an entry with a summary. Confidence high |
| Release publication | Maintenance `## Releases` | `CHANGELOG.md`; `scripts/zlyme_release.py` | `scripts/tests/test_changelog_release_notes.sh` | That test locks published headings, not Unreleased prose | Changelog owns user-facing notes. Maintenance owns the workflow. Confidence high |
| Reviews and audits | `AGENTS.md` change policy; auditing `## Two reviews` | `.cursor/agents/zlyme-code-reviewer.md`; `.opencode/agents/zlyme-code-reviewer.md` | — | No test executes the reviewer | Policy in `AGENTS.md` and auditing. Adapters are tool-specific. Confidence high |
| Documentation history | `docs/WRITING.md` `## Research and history` | Research index; `docs/archive/` | — | `test_doc_links.py` checks archive Markdown links, not backtick paths | Retain. Confidence high |

## D. Agent instruction inventory

Observed. `AGENTS.md` headings from `## Project` through `## Rule precedence` are the contract. Universal rules, which must load without a skill, are the invariants (`## Current architecture invariants`), superseded designs, the device boundary, change policy, licensing, validation, hardware payload transfer, and the rule that a Flip run is the only hardware acceptance.

Task routing already exists at `AGENTS.md` lines 36–78. A code change reads the principles. Boot, graphics, audio, storage, packaging, update, or runtime also reads architecture and device porting. Build reads development and upstreams. Maintenance, kernel patches, NextUI, and releases read maintenance. Prose reads writing. Live device reads operations. A defect investigation reads auditing. Sequencing reads the roadmap, which is not architecture.

`.cursor/rules/zlyme-core.mdc` is always applied and points at that list. `.cursor/rules/knulli-packages.mdc` is also `alwaysApply: true` and restates the package-update comparison. That second rule is the candidate to scope later, under 17D, not under 17B. `.cursor/agents/zlyme-code-reviewer.md` is `readonly: true` and tells the reviewer not to assign a disposition. `.opencode/agents/zlyme-code-reviewer.md` denies every action and then allows read, glob, and grep. Those permission blocks are not interchangeable. This tree has no `.agents/skills/` directory. Whether both tools would load one was not checked.

Proposal, not an edit: keep the universal list in `AGENTS.md`. Route task detail to the owner table in section B. A skill may point at upstreams for a package update. It must not be the only copy of a safety rule.

## E. Test coverage and gaps

`scripts/tests/test_doc_links.py` lines 8–35 name the files whose links and anchors are checked. The list includes the roadmap, the logbook, the research index, and the Phase 10 audit. It does not include `docs/research/phase-17-plan.md`, `docs/research/phase-18-plan.md`, or this inventory. Backtick paths are skipped for the roadmap, the logbook, and that audit (lines 55–59). Archive Markdown links are checked. A passing run does not prove a contract's meaning survived.

`scripts/tests/test_doc_contracts.py` hardcodes the canonical list at lines 11–22. It fails if `docs/DEVELOPMENT.md` loses the baseline table row, if the upstreams NextUI row SHA drifts from `nextui.mk`, if the `device.conf` code block moves out of architecture or device porting, if architecture or the user guide stops stating the Rumble Strength default, or if `README.md` loses `## Install`. Those assertions must follow the fact if ownership moves. They must not be deleted to allow a move.

`scripts/tests/test_systems_table.py` reads `docs/USER_GUIDE.md`. `scripts/tests/test_phase13a_docs.sh` locks the README GIF width and rejects a Known limitations heading in Unreleased. `scripts/tests/test_changelog_release_notes.sh` locks published changelog headings.

Not mechanically checked: agreement between architecture and operations on shutdown, the allowlist count, ADR text versus code, reviewer prompts, and Cursor rule scope. Semantic safety rules in `AGENTS.md` are not executed by these tests.

## F. Candidate extractions

Recommendation is a proposal. None of these are authorized.

| Heading | Self-contained? | Machine dependency | Recommendation |
| --- | --- | --- | --- |
| Architecture `## 5` through `## 7` | No. Boot, storage, shutdown, and OTA share failure behavior | `zlyme-halt`, init, `zlyme-update`; S90 test is code | Retain |
| Architecture `## 8` and `## 9` | Partly. They cite the session in `## 11` | Rumble sentence in section 10 is tested, not these two | Investigate further before any extraction. Do not extract in the first 17B unit |
| Architecture `## 11` | No. It is the session that graphics and audio return to | NextUI pin is upstreams, not this section | Retain |
| Operations recovery sections | Procedures sit next to the same invariants as architecture | None in the doc tests | Clarify long steps in place before moving them |
| Development `## Pinned baseline` | The table is the checked fact | `test_doc_contracts.py` lines 90–94 | Retain until the assertion moves with it |
| Maintenance `## Open validation debt` | Yes, as an index | None | Retain. It is already the index |
| Upstreams comparison tables | Mixed with policy | NextUI row is tested | Retain the row. Do not split the file to shrink it |
| Device porting command headings | They restate architecture's command contract | `device.conf` block is tested in both files | Retain both copies of that block until one owner is chosen and the test follows it |
| Roadmap phases 0–15 | Evidence is also in the logbook and research | Link test checks anchors | Clarify only where the logbook already has the fact. Not a split |
| `docs/LOGBOOK.md`, `docs/decisions/`, `docs/archive/`, user guide, principles, auditing, writing | They are the record or the rule | User-guide rumble and systems table | Remain unchanged |

## G. Leave unchanged in 17B

`docs/LOGBOOK.md`, `docs/archive/`, `docs/decisions/`, `docs/USER_GUIDE.md`, `docs/ENGINEERING_PRINCIPLES.md`, `docs/AUDITING.md`, `docs/WRITING.md`, `AGENTS.md`, `.cursor/`, `.opencode/`, and [phase-18-plan.md](phase-18-plan.md). Also leave `README.md` `## Install` where it is. The installer link depends on that heading (`test_doc_contracts.py` lines 128–130).

## H. Risks

A link test can pass after a sentence loses its meaning. The shutdown rule is stated in architecture, operations, and `AGENTS.md`. Moving one copy without checking the others can leave a reader on the stale copy.

`device.conf` is duplicated in two documents and locked in both. Choosing one owner is a contract-test move, not a cosmetic one.

The Rumble Strength default is a tested sentence in two files. Deleting either fails `test_doc_contracts.py`.

PipeWire `1.6.6` appears in maintenance, ADR 0007, the logbook, and a research note. The ADR and maintenance are current. The research note is historical where it still calls another mixer current. That is already labeled in the research index. Do not merge those into one paragraph.

The compat exception says 41 installed files (`docs/UPSTREAMS.md` line 248). `allowlist.sha256` has 41 entries. The comparison table at line 277 says the archive has fifty ELF files and then names exclusions. Those two sentences were not reconciled in this pass.

## I. What 17B may do first

Proposal: the first 17B unit is a written decision, under the preservation contract, for architecture sections 5–7 and 11. The expected outcome is retain. A later unit may investigate section 8 or 9 only as a pure relocation, with the session contract left in section 11 and with no contract wording change. Roadmap shortening of phases 0–15 is a separate editorial unit and only where the logbook already holds the evidence.

## J. Questions for the maintainer

1. Should the `device.conf` block have one prose owner, with the other file only linking to it, given the test currently requires both?
2. Is the compat archive's "fifty" count the archive membership, with 41 the installed allowlist, or is one of those sentences stale?
3. May 17B shorten roadmap phases 0–15, or is that out of scope until each phase's logbook entry is checked?
4. Should `knulli-packages.mdc` stop being `alwaysApply` in 17D, or stay global?

## K. Not authorized inside 17B

Do not shorten `AGENTS.md`. Do not add skills or edit `.cursor/` or `.opencode/`. Do not change a contract's meaning in the same commit as a move. Do not delete research, archive, logbook, or ADR text. Do not drop `test_doc_contracts.py` checks. Do not move the development baseline table, the upstreams NextUI row, the `device.conf` blocks, the rumble sentences, or `## Install` unless the assertion moves with them in an accepted change. Do not set a file-size target. Do not start Phase 18. Do not build an OTA or publish a release.
