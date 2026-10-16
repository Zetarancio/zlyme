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

The canonical technical docs are listed in `AGENTS.md`. They are calmer and more literal than the README.

- Present tense for current behavior. Name the owner of each mechanism (a file, a package, a command).
- Give exact versions or SHAs when state depends on them. Don't write "latest", "current" or "now" without a subject.
- Keep the source-of-truth model. Source is the authority for what Zlyme ships, the hardware wiki for hardware facts, and ROADMAP, LOGBOOK and `docs/research/` are history.
- Link to the owning document instead of copying its content. When an exact value has to be repeated, `scripts/tests/test_doc_contracts.py` can check it against source.
- Never claim hardware validation that did not happen. Keep built, booted, launched, tested and stress-tested apart.

## Research and history

`docs/research/`, `docs/LOGBOOK.md`, and `docs/archive/` record what was tried, measured, and decided. New logbook entries go at the top, newest date first. Entries from the same day keep the order they were written. `docs/ROADMAP.md` is the short sequencing map. How to write it is below. Don't rewrite a failure out of a historical file. When a later phase supersedes an early statement, add a short dated status note that links to the current document. Leave the old text in place.

## Roadmap

`docs/ROADMAP.md` is non-normative. Current architecture stays in `docs/ARCHITECTURE.md` and the other owning technical documents. The roadmap answers five questions:

- Where are we?
- What has been completed?
- What is next?
- What blocks progress?
- What evidence or reference closes a phase?

It does not answer what happened on every test attempt, which files changed in every small commit, every intermediate design that was rejected, or which command was run while debugging. Minor cosmetic adjustments are not milestones. A rejected approach is one line: `REJECTED`, a short reason, and a research link when one exists.

A closed phase keeps a concise summary: the objective, the status, important dependencies, remaining work, significant blockers, and the closure date and reference. Long planning, test transcripts, and superseded investigations move to `docs/archive/` or `docs/research/`, or stay in `docs/LOGBOOK.md` when that is already where they live. Link to that material. Do not copy it back.

A gate has to match the risk. A source-only change does not automatically need a hardware test. Hardware-facing changes, destruction of persistent data, boot changes, and filesystem-integrity risks may need stronger evidence. Do not add an acceptance check for a risk that was imagined. A feature the maintainer already accepted does not become incomplete because a redundant check was not repeated. Do not claim a hardware result that did not happen.

## Changelog and release notes

`CHANGELOG.md` is for people who use Zlyme. It is not an engineering log, a phase report, a source tour, or a hardware-test transcript. The roadmap names the phase. `docs/LOGBOOK.md` and `docs/archive/` keep the engineering history. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

- Describe the result a person can see. One sentence is the usual entry. A second sentence is for an instruction, a warning, or compatibility.
- Group related work into one change. Do not describe the same feature under more than one heading.
- Leave out paths, hashes, commit IDs, package internals, and rejected experiments unless a person using Zlyme needs them. A longer procedure belongs in the user guide.
- Write the entry in GitHub Flavored Markdown. Headings, lists, and links have to stay readable when the section is copied into a GitHub Release. Use an absolute `https://github.com/Zetarancio/zlyme/blob/main/...` link for a guide page. A repository-relative link does not resolve there. Do not use HTML in place of Markdown, a branch URL, or a code fence around the release section.
- Do not record which hardware tests were or were not run. Do not describe a feature that has not been shown to work. A limitation a person can hit stays in the entry, in plain language.
- Newest release first, ISO dates (`YYYY-MM-DD`), and an `Unreleased` section for work that is not in a release. Headings are Added, Changed, Deprecated, Removed, Fixed, Security, and Known limitations. Leave out empty headings.
- Zlyme does not use Semantic Versioning. `zlymeNN` is a baseline. `zlymeNN.M` is a point release on the same major. Release and delta policy is in `docs/MAINTENANCE.md`.
- A removal or a change in behavior goes under its own heading and says what users have to do.
- GitHub release notes use that release's changelog wording. A raw git log or a generated compare link alone is not release notes. The release workflow prints the `## [ZLYME_VERSION]` section and fails if that section is missing or empty. It does not ask GitHub to build notes from the commit list. `Unreleased` is not a release body.

## AI-assisted documentation

The goal is good documentation that also gives an AI tool enough coherent context to help a contributor, not documentation written for a model. Stable terminology, explicit owners, concrete paths and interfaces, explicit supersession, and evidence kept apart from inference all serve both readers. Don't rely on private chat history. If it matters, it is written down here.

When starting AI-assisted work on Zlyme, give the tool the repository and the `docs/` folder as context. Review generated text against this file and against the source before committing it.

## References

- GitHub: [About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes), [Setting guidelines for repository contributors](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors)
- [Google developer documentation style guide](https://developers.google.com/style)
- [Diátaxis](https://diataxis.fr/)
- [Write the Docs: style guides](https://www.writethedocs.org/guide/writing/style-guides/)
- [Standard Readme](https://github.com/RichardLitt/standard-readme)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
