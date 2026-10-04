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

`docs/research/`, `docs/LOGBOOK.md`, `docs/ROADMAP.md` and `docs/archive/` record what was tried, measured and decided. Don't rewrite a failure out of them. When a later phase supersedes an early statement, add a short dated status note that links to the current document. Leave the old text in place.

## Changelog and release notes

`CHANGELOG.md` is for people upgrading. ROADMAP and LOGBOOK remain the engineering history.

- The format follows Keep a Changelog: newest release first, ISO dates (`YYYY-MM-DD`), and an `Unreleased` section kept up to date during development. Use Added, Changed, Fixed, Removed and Known limitations, and leave out empty categories.
- Zlyme does not use Semantic Versioning. `zlymeNN` is a baseline. `zlymeNN.M` is a point release on the same major. Release and delta policy is in `docs/MAINTENANCE.md`.
- One entry describes one behavior change, even if it took twenty commits. Internal refactors with no effect on users or contributors stay out.
- A removal or a change in behavior goes under its own heading and says what users have to do.
- GitHub release notes match the changelog entry. A raw git log or a generated compare link alone is not release notes.

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
