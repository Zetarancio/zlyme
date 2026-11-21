# Writing

This file owns how Zlyme documentation is written: the README, how-to material, technical docs, research and history, the changelog and release notes, and AI-assisted writing. Who owns which facts is in `docs/MAINTENANCE.md` and `AGENTS.md`.

External style guides (listed under References) are influences. None of them overrides the project's own voice or source-of-truth model.

## README

The README is for users and potential contributors. It says what Zlyme is, why it is interesting, how to install it, where games go, how to experiment with paks, how to contribute, and where the deeper documentation lives. It stays technically accurate, but it is not `docs/ARCHITECTURE.md`.

- Write like a maintainer talking to other handheld users and hackers. Use contractions, `you`, concrete claims, and varied sentence lengths.
- Keep these three lines unless the maintainer removes them: **Low latency. High viscosity.**, *It's engineered to ooze, cultured for speed.*, and *It’s not buttery smooth. It’s slime-smooth.* Don't paraphrase them, and don't spread slime jokes through every section. They work because they're rare.
- Say why a design exists when it matters to a user (no background compositor, a read-only OS, Flip-specific drivers).
- Avoid landing-page and generated-summary prose: "robust", "seamless", "powerful", "comprehensive", "empower", "Whether you're X or Y", "not only X but also Y", a closing "This ensures…", a first sentence that repeats the heading, and every section as a parallel bullet list.
- Don't promise devices, ports or features that do not exist. Don't turn a single hardware test into a general guarantee.
- Keep every credit and license statement. Keep the `## Install` heading: the Zlyme Installer links to that anchor.
- Keep the heading `## User Systems and Tools and the Right to Experiment`.
- Detail belongs in `docs/USER_GUIDE.md`. The README covers the first successful attempt and links onward.

## User guide and how-to material

`docs/USER_GUIDE.md` owns detailed end-user operation. Write task by task: where the setting is, what it does, what it leaves alone. Use the labels the pinned NextUI fork shows on screen. Don't explain internals a user can't act on.

## Technical documentation

The canonical technical docs are listed in `AGENTS.md`. `docs/README.md` is only the map: one line for what each document owns, with a link. Do not copy a contract into that map. The technical docs are calmer and more literal than the README.

- Present tense for current behavior. Name the owner of each mechanism (a file, a package, a command).
- Give exact versions or SHAs when state depends on them. Don't write "latest", "current" or "now" without a subject.
- Keep the source-of-truth model. Source is the authority for what Zlyme ships, and the hardware wiki for hardware facts. `docs/ROADMAP.md` is the current sequence. An active phase plan is temporary sequencing, not architecture. Closed research, `docs/LOGBOOK.md`, and `docs/archive/` are history.
- Link to the owning document instead of copying its content. When an exact value has to be repeated, `scripts/tests/test_doc_contracts.py` can check it against source.
- Never claim hardware validation that did not happen. Keep built, booted, launched, tested and stress-tested apart.

## Research and history

`docs/research/`, `docs/LOGBOOK.md`, and `docs/archive/` record what was tried, measured, and decided. An active phase plan filed under `docs/research/` sequences unfinished work. It is not a current contract, and it is not closed history. New logbook entries go at the top, newest date first. Entries from the same day keep the order they were written. `docs/ROADMAP.md` is the short sequencing map. How to write it is below. Don't rewrite a failure out of a historical file. When a later phase supersedes an early statement, add a short dated status note that links to the current document. Leave the old text in place. That applies while the record stays in the tree. Removing a record, or a section of one, is a retirement under [Documentation retention](#documentation-retention), not an edit.

A new research file is named for the phase that first needs it: `preliminary-<topic>.md` before Phase 0, `phase-09-<topic>.md` for a numbered phase, and `phase-12d-<topic>.md` or `phase-15c-<topic>.md` for a subphase. A later phase adds a dated section to that file. It does not get a second filename. USB evidence captures and vendored files are not research documents and do not use this prefix.

## Documentation retention

The tree keeps what a maintainer needs to understand, change, build, reproduce, test, and maintain Zlyme as it is now. Git history is where a retired record is kept. This rule is prospective. It permits a later change, approved by the maintainer, to retire a record. A reviewer's pass is not that approval. The rule does not by itself delete, move, or rewrite any existing record, and until the maintainer approves such a change every existing record stays as written.

Every candidate gets one disposition. Each has a test that a reviewer can check:

- KEEP. The file is the current owner of behavior, a safety constraint, a build, release, or maintenance procedure, or a user contract. Test: removing it would leave that fact with no current owner.
- KEEP ON DEMAND. The file is durable but specialized: an ADR, a licensing or provenance record, or hardware evidence. Test: losing it could plausibly cause unsafe hardware work, a licensing or provenance error, an irreproducible build, or repetition of a costly or destructive experiment. It is never default agent context.
- EXTRACT MINIMUM THEN DELETE. Most of the file is history, and one or more of its facts still affect current work. Test: each surviving fact is named, and fits in an existing owner in a small fraction of the original size.
- DELETE FROM CURRENT TREE. The file is a completed plan, an obsolete inventory, a finished audit, or abandoned work with no surviving consequence. Test: every claim in it is already owned elsewhere, derivable from source or tests, or no longer needed.
- GIT HISTORY ONLY. The file is narrative with no current consumer. Test: no current document, test, script, or agent instruction needs it, and no named future decision depends on reading it.
- MANUAL REVIEW. Automated classification cannot establish a safe disposition. The file may hold unique hardware, destructive-operation, recovery, provenance, licensing, or reproducibility evidence, or open validation debt, and the reviewer cannot yet say which check fails. Test: the reviewer names the unresolved uncertainty and the evidence it affects. When that evidence is incomplete, the disposition is retention. A completed review is not maintainer approval, and neither is a passing test.

Age, size, and location under `docs/research/` are not reasons for any disposition.

A retirement passes all seven checks, and its change record shows each one:

1. Current owner. Each surviving fact has an authoritative destination, or is recorded as no longer needed.
2. References. Incoming links, path mentions, test lists, scripts, and agent instructions are found and repaired or removed.
3. Source. Where the record describes shipped behavior, the surviving statement agrees with the source.
4. Debt. No open defect, hardware limitation, or validation obligation exists only in that record.
5. Evidence. Licensing, provenance, recovery, binary identity, and hard-to-repeat device evidence survive in a KEEP or KEEP ON DEMAND file.
6. Decision. Rationale a future change still needs is in an ADR or in the owner's short explanation.
7. Recovery. The original is committed, reachable from a named Git ref, and included in a verified backup.

Check 7 does not replace checks 1 through 6.

These are not retirement candidates without a separate, clause-level review: `AGENTS.md`, `docs/ENGINEERING_PRINCIPLES.md`, `docs/ARCHITECTURE.md`, `docs/architecture/audio.md`, `docs/OPERATIONS.md`, `docs/DEVICE_PORTING.md`, `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md`, `docs/MAINTENANCE.md`, `docs/AUDITING.md`, this file, the current ADRs, package provenance records, licensing and attribution notices, hardware recovery instructions, and unique destructive-operation evidence. A later change may improve one of them. That change keeps every invariant discoverable and enforced.

Retirement removes. It does not relocate:

- Do not copy retired prose wholesale into another file.
- Do not create a new archive, legacy, history, summary, or catch-all directory or file to hold it.
- Put an extracted fact in an existing owner, in its shortest form: the conclusion, constraint, identifier, or open debt.
- A skill holds a repeatable procedure. It is not a place to keep retired history.
- A current document does not depend on reading a retired plan.
- A current document does not require a new or permanent in-tree archive merely because a phase closes. `docs/archive/` is not deleted as a set. Each file in it is its own candidate.
- A retirement change reports the bytes it removed and the bytes it added. A change that moves an equivalent amount of text elsewhere does not meet this rule.
- For an ordinary retirement, new documentation bytes divided by the gross bytes removed from the retired files is at most 0.20. That is a maximum, not a target. Count positive additions to surviving and new tracked Markdown files. Do not hide an addition by subtracting an unrelated removal. Report reference repair and policy text separately, and include both in the ratio. Do not extract a fact merely because the budget allows it. An exception needs its own maintainer approval. Evidence that check 5 protects stays even when keeping it exceeds the ratio: retain the candidate, or stop for that approval.

The exception is evidence that check 5 protects. Safety, reproducibility, licensing, and provenance evidence that has no shorter safe form stays, as KEEP ON DEMAND or MANUAL REVIEW.

Existing logbook entries keep their text and their checksums in `scripts/tests/logbook_entries.sha256`. Retiring logbook text is its own maintainer-approved change, and it does not weaken that test. How that checksum treats a retired entry is a separate decision. It is not part of an ordinary retirement batch.

## Changing an authoritative contract

[Phase 17's plan](research/phase-17-plan.md) records the preservation doctrine authorized for that phase, including its rule that research, the archive, the logbook, and the ADRs were not deleted. That file stays as the historical record of what was authorized then. [Documentation retention](#documentation-retention) is the current rule for retiring an obsolete record, and it supersedes that historical prohibition. It does not supersede technical architecture, engineering principles, the source-of-truth hierarchy, hardware safety, licensing and attribution, reproducibility, evidence requirements, authorization boundaries, or the safeguards in this section. An authorization to retire an obsolete record is not an authorization to change the meaning of a current contract.

Before an authoritative contract is relocated, rewritten, divided, or shortened, the change record names:

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

- Relocation moves the words. The contract does not change.
- Clarification changes wording. The contract does not.
- A substantive contract change is its own change, with its own acceptance.

Relocation and a contract change are not mixed. An authorization to relocate a contract is not permission to change its meaning. Dates, source identities, SHA values, test limits, and accepted dispositions stay with the fact they belong to.

A contract migration starts from a recorded clean commit on a dedicated branch. It changes one coherent unit, reviews the whole diff, checks references and the contract tests, and stops on an unresolved semantic discrepancy. The next major contract waits for acceptance. No script rewrites the canonical documents in one pass. No AI summary replaces a measurement or an architectural decision.

## Historical link repair

An approved retirement may replace one relative Markdown link in an ordinary archived roadmap or closed research document with a commit-pinned GitHub link to that file. The file and anchor exist at that commit. The label stays, and no date, SHA, command, measurement, result, limitation, or other byte changes. The original stays in that commit and a verified backup. Record both destinations; restoring only them reproduces the file byte for byte. Excluded: `docs/LOGBOOK.md` and its entries, `scripts/tests/logbook_entries.sha256`, `scripts/tests/test_logbook_order.py`, raw hardware evidence, license and provenance records, and third-party documents. They stay in the link check and are not edited to match current source. No allowed repair keeps the candidate. Do not move `archive/pre-phase-19-docs`.

## Roadmap

`docs/ROADMAP.md` is non-normative. Current architecture stays in `docs/ARCHITECTURE.md` and the other owning technical documents. The roadmap answers five questions:

- Where are we?
- What has been completed?
- What is next?
- What blocks progress?
- What evidence or reference closes a phase?

It does not answer what happened on every test attempt, which files changed in every small commit, every intermediate design that was rejected, or which command was run while debugging. Minor cosmetic adjustments are not milestones. A rejected approach is one line: `REJECTED`, a short reason, and a research link when one exists.

A closed phase keeps a concise summary in `docs/phases/`: the objective, the final disposition, important accepted behavior, material limitations, dependencies, and links to retained evidence. `docs/ROADMAP.md` stays the current-status map and the phase index. It does not repeat each phase. Closing the phase reconciles the current authoritative contracts, records remaining debt in the document that owns it, retains indispensable evidence, and assigns each temporary plan and research file a disposition under [Documentation retention](#documentation-retention). Approved obsolete material is retired to Git history. Closing a phase does not itself authorize that deletion, and it does not require a new archive, research file, or logbook entry. A dated archive snapshot that remains in the tree is the historical roadmap of its date, not a new architecture policy.

A gate has to match the risk. A source-only change does not automatically need a hardware test. Hardware-facing changes, destruction of persistent data, boot changes, and filesystem-integrity risks may need stronger evidence. Do not add an acceptance check for a risk that was imagined. A feature the maintainer already accepted does not become incomplete because a redundant check was not repeated. Do not claim a hardware result that did not happen.

## Changelog and release notes

`CHANGELOG.md` is for people who use Zlyme. It is not an engineering log, a phase report, a source tour, or a hardware-test transcript. The roadmap names the phase. Engineering history that is still in the tree lives in `docs/LOGBOOK.md`, `docs/research/`, and `docs/archive/` until a retention change retires a record. The changelog does not keep a second copy. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

- Write natural, connected English about the result a person can see. A concise bullet is often enough, but a short paragraph is better when related behavior needs context or an instruction. Do not force a feature into sentence fragments or split it into repetitive implementation bullets.
- Group related work by user-visible feature. Name the benefit first, then the compatibility limit or action a person needs. Do not describe the same feature under more than one heading.
- Leave out paths, hashes, commit IDs, package internals, and rejected experiments unless a person using Zlyme needs them. A longer procedure belongs in the user guide.
- Write the entry in GitHub Flavored Markdown. Headings, lists, and links have to stay readable when the section is copied into a GitHub Release. Use an absolute `https://github.com/Zetarancio/zlyme/blob/main/...` link for a guide page. A repository-relative link does not resolve there. Do not use HTML in place of Markdown, a branch URL, or a code fence around the release section.
- Do not record tests, commits, compiler options, internal symbols, package wiring, or debugging history. Do not describe a feature that has not been shown to work. A limitation a person can hit stays in the entry, in plain language.
- Newest release first, ISO dates (`YYYY-MM-DD`), and an `Unreleased` section for work that is not in a release. Headings are Added, Changed, Deprecated, Removed, Fixed, Security, and Known limitations. Leave out empty headings.
- Zlyme does not use Semantic Versioning. `zlymeNN` is a baseline. `zlymeNN.M` is a point release on the same major. Release and delta policy is in `docs/MAINTENANCE.md`.
- A removal or a change in behavior goes under its own heading and says what users have to do.
- Read the whole section as a normal gaming user before publishing it. It should explain the useful changes without requiring the roadmap, and it should be ready to paste into a GitHub Release unchanged.
- GitHub release notes use that release's changelog wording. A raw git log or a generated compare link alone is not release notes. The release workflow prints the `## [ZLYME_VERSION]` section and fails if that section is missing or empty. It does not ask GitHub to build notes from the commit list. `Unreleased` is not a release body.

## End of a phase

Documentation coherence is a condition for closing every phase, including a phase that does not publish a release. Feature notes belong with the change. This pass is the last check that the current documents still agree with the code.

Before a phase is called closed:

- Review the source changes and what a person can see.
- Reconcile `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`, `docs/MAINTENANCE.md`, `docs/OPERATIONS.md`, `docs/UPSTREAMS.md`, `docs/DEVICE_PORTING.md`, and `docs/USER_GUIDE.md` with that code.
- Correct a stale version, pin, release status, or current-state claim that the code now contradicts.
- Make the phase summary say what is implemented, host-tested, hardware-accepted, excluded, deferred, or unproven. Keep `docs/ROADMAP.md` to the current sequence.
- Add a short dated `docs/LOGBOOK.md` entry when the evidence is worth keeping. Leave older entries as written.
- Review `CHANGELOG.md` under the rules above. Record accepted user-visible behavior only.
- Check documentation links, the documentation contract tests, and a factual claim that a test already locks to source.
- Keep licenses, attribution, and provenance.
- Name a remaining limitation. Do not write that support is complete when it is not.
- When a validation finding is fixed, accepted, superseded, or deferred, reconcile the Open validation debt index in `docs/MAINTENANCE.md` in the same change. Do not carry a finished finding forward as open debt. A record that is still needed stays with its current owner until a retention change retires it.
- Give the phase's own planning file a disposition under [Documentation retention](#documentation-retention). A plan marked temporary is a retirement candidate when its phase closes, once its surviving facts have an owner. Closing the phase does not itself delete it.
- The Systems and emulators table in `docs/USER_GUIDE.md` is alphabetically sorted by the displayed System name.

Do not rewrite every document after every commit, copy the same explanation into each file, or invent a test result.

## AI-assisted documentation

The goal is good documentation that also gives an AI tool enough coherent context to help a contributor, not documentation written for a model. Stable terminology, explicit owners, concrete paths and interfaces, explicit supersession, and evidence kept apart from inference all serve both readers. Don't rely on private chat history. If it matters, it is written down here.

When starting AI-assisted work on Zlyme, give the tool the repository. `AGENTS.md` names the documents each kind of task needs. Do not load all of `docs/` as context.

Current authoritative contracts own present behavior. An active phase plan sequences work that is not yet closed. It is not architecture, and it is not closed history. A closed-phase summary records that phase's outcome. Historical research and the logbook record what was tried. Retained indispensable evidence stays because a current decision still depends on it. Retired narrative leaves the working tree under [Documentation retention](#documentation-retention) and remains in Git history. Read one of those records for the question that needs it. Do not load them as default context. A phase summary and that phase's active plan are read when the task is that phase.

Review generated text against this file and against the source before committing it.

## References

- GitHub: [About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes), [Setting guidelines for repository contributors](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors)
- [Google developer documentation style guide](https://developers.google.com/style)
- [Diátaxis](https://diataxis.fr/)
- [Write the Docs: style guides](https://www.writethedocs.org/guide/writing/style-guides/)
- [Standard Readme](https://github.com/RichardLitt/standard-readme)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
