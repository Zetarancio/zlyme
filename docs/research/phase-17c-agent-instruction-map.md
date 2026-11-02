# Phase 17C agent-instruction map

Status: preparation for 17C2, 2026-11-02. This file does not shorten `AGENTS.md`, add a skill, or authorize another document move.

17C1 adds one paragraph to `AGENTS.md` `## Required context`. That paragraph has four sentences: read `docs/architecture/audio.md`; that file is the authoritative detailed audio contract; `docs/ARCHITECTURE.md` remains the entry point and its `## 9. Audio` heading links to the contract; the reads already required above still apply. A later reduction keeps the whole paragraph. Line numbers below are that file after the paragraph. The same headings, two lines earlier from `## Current architecture invariants` onward, are the file at `9a52ae6e91d4e79b71c535e42e53e612f77c619d`.

A repeated safety rule stays until a clause map shows that both copies have the same purpose and that removing one still leaves the instruction on a path the agent actually reads. Similar words in another file are not removal evidence.

## Section matrix

| Heading | Lines | Scope | Consumer | Owner of the facts | Without a skill | Later route |
| --- | --- | --- | --- | --- | --- | --- |
| Project | 3–30 | Universal | Every agent, and a person reading the contract | This section for the source-of-truth order. The wiki for device facts. This repository for the OS. | Stays in `AGENTS.md` | The source list can point at a stable doc only while this section still states the order |
| Required context | 32–82 | The reading index. Each bullet is task-specific. | Cursor, OpenCode V2, and `.cursor/rules/zlyme-core.mdc` | Each named file. Audio detail is `docs/architecture/audio.md`. Surrounding architecture stays `docs/ARCHITECTURE.md`. | Stays. This is how a task finds the other files. | The task map below. 17C2 may implement a route. This file does not. |
| Current architecture invariants | 84–101 | Universal hold-still rules | Any change that could alter the system shape | `docs/ARCHITECTURE.md`, `docs/architecture/audio.md` for the mixer, `docs/MAINTENANCE.md` for the NextUI pin | Stays | Mechanism text stays in the owning doc. The hold-still sentence stays here. |
| Superseded designs | 103–115 | Universal prohibition on revival | Any task that might restore a removed design | `docs/ARCHITECTURE.md` and the decisions that replaced each item | Stays | History can be cited. The prohibition stays here. |
| Device-boundary rule | 117–131 | Universal for hardware and board code | Implementers and reviewers | `docs/DEVICE_PORTING.md`, `board/my355/` | Stays | Examples can be cited from the porting doc if this section still states the rule |
| Change policy | 133–164 | Universal procedure | Editors, and both reviewer adapters | `docs/UPSTREAMS.md` for upstream-first, `docs/AUDITING.md` for high-risk review | Stays | None |
| Buildroot rules | 166–200 | Package and image work. The file currently loads it for every task. | Recipe and image edits | `docs/DEVELOPMENT.md` and the package file | Loads for package and image work with no skill | Route when the task touches `package/`, configs, or the image. Unclear scope loads it. |
| Shell | 202–226 | Shell changes | Target scripts and host bash | This section | Loads for shell work with no skill | Route on shell files. Unclear scope loads it. |
| C and C++ | 228–252 | C and C++ changes | Project C and C++ | This section | Loads for those languages with no skill | Route on C and C++ files. Unclear scope loads it. |
| Runtime | 254–266 | Runtime and service behavior | Service and feature work | `docs/ARCHITECTURE.md` | Loads for runtime work with no skill. Prefer to keep the first-frame and required-failure rules on the always-read path. | Narrow only with a clause map |
| Performance | 268–287 | Measurement policy, plus a universal ban on silent clock and governor edits | Runtime and emulator work | This section. There is no second performance policy. | The silent-change ban stays. The metric list can move only with a clause map. | Split the metric list from the ban only in that map |
| Documentation | 289–306 | Any behavior or comment change | Whoever changes behavior | `docs/WRITING.md`, and the debt index in `docs/MAINTENANCE.md` | Stays | None |
| Licensing | 308–330 | Anything redistributed | Package, PAK, and release work | `docs/UPSTREAMS.md` records the two named exceptions | The prohibition and the exception test stay | A redistribution task can re-read the artifact names from `docs/UPSTREAMS.md` if this section still states the test |
| Validation | 332–352 | Universal evidence rules | Every change | `docs/AUDITING.md`, [ADR 0012](../decisions/0012-diagnostic-logging.md) | Stays | None |
| Hardware payload transfer | 354–356 | Universal transfer ban | Any copy to or from the Flip | This section | Stays. Never a skill-only rule. | None |
| Source investigation | 358–368 | Universal method | Every substantive task | `docs/AUDITING.md` when the work is a defect investigation | Stays | None |
| Agent behavior | 370–392 | Universal, including the completion report | Every task | This section | Stays | The report list stays. A prohibition moves only when the clause map shows it still on the always-read path. |
| Rule precedence | 394–398 | Universal conflict rule and the one-phase limit | A conflict with `docs/ENGINEERING_PRINCIPLES.md`, and a multi-phase task | `docs/ROADMAP.md` sequences. A Zlyme constraint wins. The same section says a task runs one roadmap phase unless the maintainer asks for more. | Stays. Both sentences. | None |

## Copies that are not removal candidates

The Miyoo Flip-only rule appears in Project, in the invariants, and in `.cursor/rules/zlyme-core.mdc`. Each is a discovery point. 17C2 keeps them until every consumer that can see only one of those points still sees the rule.

The PipeWire sentence in the invariants, the body of `docs/architecture/audio.md`, [ADR 0007](../decisions/0007-pipewire-audio.md), and the superseded ALSA item do different jobs. The invariant says the graph stays. The audio document says how it works. The decision says why. The superseded list names what must not return. Removing the invariant because the audio document exists would hide the hold-still rule from a task that does not open the audio document.

Project, the device-boundary section, and Agent behavior all forbid a hypothetical second device. The boundary section is the one with the examples. The behavior section is the change-time check. They stay together until a clause map assigns each sentence.

`docs/ENGINEERING_PRINCIPLES.md` is required for code changes and again for design work. A design task that changes no code still needs the second trigger. The rule that a Zlyme constraint wins is only in Rule precedence, at the end of `AGENTS.md`. Required context does not state it. Deleting Rule precedence would remove that rule. The two principles reads are a separate pair, and both stay.

Validation and Source investigation both separate a host result from Flip acceptance. One governs tests. The other governs an investigation. Change policy owns the reviewer procedure. Validation points back at it. That is one procedure, not two.

`.cursor/rules/zlyme-core.mdc` repeats a short reading list and says `AGENTS.md` wins when they differ. The audio file is named in `AGENTS.md` and is absent from that short list. This task does not edit the Cursor rule. An agent that reads `AGENTS.md`, as that rule already requires, receives the audio route. An agent that treats the short list as the whole index does not. That gap stays open for a later task that is allowed to edit the rule.

## Ambiguities

Audio work matches two reads: the broad architecture bullet and the audio paragraph. Both apply. The paragraph's last sentence keeps the reads named above it, including `docs/ARCHITECTURE.md` and `docs/DEVICE_PORTING.md`.

The graphics contract is still inside `docs/ARCHITECTURE.md`. There is no separate graphics document to route to.

Buildroot's "where applicable" for hashes is a judgment already in the rule. A later edit must not turn it into a weaker default.

Runtime's graceful degradation applies to missing Wi-Fi, Bluetooth, headphones, HDMI, or USB. A required storage, display, or input failure stays diagnosable. Those are different cases in the same section.

Source investigation says to stop when the bounded task has its evidence. Required context still names the reads for that task. The stop rule does not cancel a named read.

Change policy allows a typo or other documentation-only edit to skip the reviewer, and to say why. A task that calls an `AGENTS.md` edit safety-sensitive still runs the reviewer. The skip rule remains for the cases it names.

The device-boundary section describes a future board directory. That describes the seam. It is not permission to add a device. Agent behavior states the same limit at change time.

## Where context is spent

`AGENTS.md` is loaded as a whole. The cost of a task is then the other full documents Required context names. Several of those triggers load an entire file when the task needs one part.

`.cursor/rules/knulli-packages.mdc` is `alwaysApply: true`, so package-comparison text loads on tasks that are not package updates. Scoping that rule belongs to 17D. This map does not change it.

`docs/ARCHITECTURE.md` is one read for architectural, boot, device, graphics, audio, storage, packaging, update, and runtime work. Boot, storage, and update are still one coupled path in that file. Graphics is still in that file. Audio detail is now beside it, while section 9 remains the entry heading. A package update can also load `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md`, and `docs/MAINTENANCE.md` because it matches more than one bullet.

## Proposed task routes

This table is a proposal for 17C2. It does not change the reads required today.

Always-on means an instruction `AGENTS.md` already contains, loaded with no skill. A fact that exists only in another document belongs in another column. Relevant sections are what that category reads. Cross-subsystem documents are mandatory for a correct change. Extra documents apply when the scope grows. The last column is when the whole architecture or operations document is required.

| Task | Always-on | Relevant sections | Also mandatory | Only if the scope grows | Whole architecture or operations document |
| --- | --- | --- | --- | --- | --- |
| Documentation-only | Source-of-truth, hardware-claim rule, payload ban, no silent architecture change, rule precedence | `docs/WRITING.md`, the file being edited, `docs/ROADMAP.md` when the edit is sequencing | The owning technical doc when the prose states a contract. Audio prose includes `docs/architecture/audio.md` and the architecture entry. | `docs/AUDITING.md` for a defect writeup. `docs/LOGBOOK.md` when recording evidence. | Both full documents when the edit can change boot, storage, update, recovery, or the session, and when the scope is unclear. A status sentence by itself does not require the whole runbook. |
| Shell and PAK | Shell rules, first-frame rule, payload ban, validation, licensing when a PAK is shipped | The script and `docs/ARCHITECTURE.md` section 11 for a launcher | `docs/DEVICE_PORTING.md` for a board command. `docs/OPERATIONS.md` when the script runs on the live Flip or in recovery. | `docs/DEVELOPMENT.md` for build integration. `docs/MAINTENANCE.md` for an update hook. | Both full documents when the script mounts, updates, or shuts down. Unclear scope loads both. |
| Buildroot package maintenance | Buildroot rules, licensing, no silent upgrade, `BR2_EXTERNAL`, payload ban | The package, `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md`, `docs/MAINTENANCE.md` | `docs/ARCHITECTURE.md` and `docs/DEVICE_PORTING.md` when the package is on the runtime, boot, graphics, audio, storage, or update path. An audio package also uses `docs/architecture/audio.md`. | `docs/ENGINEERING_PRINCIPLES.md` when the package contains a code change | The whole architecture document when the package can affect init, first frame, storage, or update. A leaf version bump still reads maintenance and upstreams. |
| Graphics and DRM | Direct KMS, no permanent compositor, device boundary, validation, no silent clock change | The graphics section, which is still in `docs/ARCHITECTURE.md`, plus `docs/DEVICE_PORTING.md` and [ADR 0008](../decisions/0008-gpu-and-panvk.md) | Section 11, because launch and return share the display. HDMI sound adds `docs/architecture/audio.md` and the architecture entry. | `docs/OPERATIONS.md` for a live display fault. `docs/MAINTENANCE.md` for kernel or display intake. | The whole architecture document, because graphics has not been extracted. The whole operations document for a live fault or recovery. No skill route. |
| Audio and Bluetooth | PipeWire invariant, the superseded ALSA-only image and `dmix`/`FlipVolume` graph, device boundary, no silent audio change, validation. `AGENTS.md` does not name BlueALSA. | `docs/architecture/audio.md`, the `## 9. Audio` entry in `docs/ARCHITECTURE.md`, `docs/DEVICE_PORTING.md`, [ADR 0007](../decisions/0007-pipewire-audio.md). BlueALSA is stated in those audio documents. | `docs/OPERATIONS.md` `## Audio` for live behavior, including HDMI playback in that section. `docs/MAINTENANCE.md` for live-Flip audio status. Section 11 when NextUI shows the sink or owns volume. | `docs/DEVELOPMENT.md` and `docs/UPSTREAMS.md` for a PipeWire or WirePlumber package update. `docs/AUDITING.md` for a defect. | The whole architecture document when boot order, the session, HDMI display, or services also change. The whole operations document for live diagnosis or recovery. A mixer-only change still opens the architecture entry. |
| Boot, storage, OTA, recovery | Read-only root, BusyBox init, first frame, payload ban, filesystem integrity, no in-place `/boot` patch, no software MASKROM reboot | Architecture sections 5–7, the whole of `docs/OPERATIONS.md`, [ADR 0003](../decisions/0003-busybox-init.md), [ADR 0006](../decisions/0006-root-image-lifecycle.md) | `docs/DEVICE_PORTING.md` for image layout and the update prefix. Section 11 when first frame or shutdown meets NextUI. Licensing when a preloader is involved. | `docs/AUDITING.md`, `docs/LOGBOOK.md`, and the hardware wiki for facts | Always both full documents. Selected headings are not a substitute. This category never depends on a skill. |
| NextUI integration | Immutable pin, no silent upgrade, device boundary, direct KMS, payload ban | `docs/MAINTENANCE.md`, architecture section 11, the pin in the tree, the NextUI row in `docs/UPSTREAMS.md` | `docs/DEVICE_PORTING.md`. Graphics, input, or `docs/architecture/audio.md` when the fork changes that subsystem. | The NextUI checkout only when the task names it | The whole architecture document when launch, return, or first frame changes. The whole operations document for live diagnosis. |
| Hardware diagnosis | Evidence labels, payload ban, no fabricated Flip result | `docs/OPERATIONS.md` and the contract section for the fault | `docs/architecture/audio.md` for sound, the graphics section for display, sections 5–7 for boot and storage, `docs/DEVICE_PORTING.md` for board interfaces | `docs/LOGBOOK.md`, research, and the hardware wiki | The whole operations document for recovery. The whole architecture document when the fault can cross boot, storage, display, and the session. |
| Independent code review | Review procedure, evidence labels, a fresh context, no verdict passed in | The named diff, `AGENTS.md`, `docs/AUDITING.md` | The same documents as the category the diff touches | The reviewer adapter for the tool that runs the review | Both full documents when the diff touches boot, storage, update, recovery, or a mixed scope |
| Release preparation | Licensing prohibition, payload ban, and the required reads of `docs/MAINTENANCE.md` for a release and `docs/WRITING.md` for release notes. `AGENTS.md` has no separate ban on an unapproved release or OTA publication. | `docs/MAINTENANCE.md`, `docs/WRITING.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md` | `docs/ARCHITECTURE.md` when the notes state runtime behavior. `docs/USER_GUIDE.md` when they tell a person to act. | The release workflow when checking that job. `docs/LOGBOOK.md` so the notes do not invent evidence. | The whole architecture document when the notes cover more than one subsystem. Publication stays a separate decision. |

## Requirements for a later reduction

17C2 compares any shorter `AGENTS.md` with the original file, sentence by sentence. A review of the new file alone does not meet that check.

Each original rule maps to one of these:

- the retained sentence,
- or an approved owning document,

plus the condition that loads it, and the check that shows it still applies. A rule that has no row has disappeared, and the reduction stops.

Critical universal instructions stay in the file both tools load. Boot, storage, update, and recovery keep the full `docs/ARCHITECTURE.md` and `docs/OPERATIONS.md` reads. Mixed or unclear work loads the union of the matching categories. That fail-safe is part of the route, not an optional skill.

The 17C1 audio paragraph stays on that always-loaded path, including every sentence in it. `docs/architecture/audio.md` remains the detailed contract. `docs/ARCHITECTURE.md` remains the entry point. The reads that paragraph says still apply remain required.

There is no size target and no token, speed, or model benchmark. One generated summary does not replace the clause map.

## What this map does not do

It does not edit `.cursor/` or `.opencode/`. It does not extract graphics or any other architecture section. It does not start 17C2, 17D, or Phase 18. It does not change firmware, an OTA, or a release.
