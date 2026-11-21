# Phase 19 plan

Status: active-phase planning, from 2026-11-21. Temporary. When Phase 19 closes, its surviving facts go to their owners and this file is retired under [Documentation retention](../WRITING.md#documentation-retention). It is not a contract. The phase summary is [docs/phases/phase-19.md](../phases/phase-19.md).

Phase 19 is development infrastructure and maintainability. It has two separate goals. Repository reduction removes records that no longer belong in the tree. Context reduction cuts what an agent loads by default. Deleting a file does not shrink the always-applied context, and shortening `AGENTS.md` does not shrink the tree. Each is measured on its own.

The starting proposal was an external research report the maintainer supplied on 2026-11-21. It is not committed. Its citations are not project evidence, and its file classifications are proposals.

## Baseline, 2026-11-21

`main` was `0dd8b86e26c69c55b691ea5b6824aa7b77f0385d`. Published `zlyme44.5` is tag `zlyme-44857224770`, `803664a98875b0c128f16726b8d117e2b1b41e25`. `ZLYME_VERSION` is `zlyme44.5`. The NextUI pin is `3aff9c42777bf69ff476601b7011b05f753ba8cd`.

Tracked Markdown: 135 files, 2,726,104 bytes.

| Area | Files | Bytes |
| --- | ---: | ---: |
| `docs/research/` | 42 | 1,318,297 |
| `docs/archive/` | 7 | 343,143 |
| `docs/LOGBOOK.md` | 1 | 333,361 |
| Other files directly under `docs/` | 13 | 363,455 |
| Package and source Markdown under `package/` | 23 | 206,556 |
| Root: `README.md`, `AGENTS.md`, `CHANGELOG.md`, `CONTRIBUTING.md` | 4 | 60,402 |
| `docs/phases/` | 20 | 37,341 |
| `docs/decisions/` | 12 | 26,856 |
| Agent skills and reviewer instructions | 8 | 26,207 |
| `docs/architecture/` | 1 | 5,302 |
| `board/` and `tools/` READMEs | 2 | 3,111 |
| `.github/` | 2 | 2,073 |

Research, archive, and logbook are 1,994,801 bytes, 73% of the Markdown. The largest single files are `docs/LOGBOOK.md`, `docs/research/phase-12d-usb-mtp.md` (201,484), `docs/archive/roadmap-2026-10-15.md` (170,713), `docs/research/phase-10-documentation-audit.md` (118,943), and `docs/ARCHITECTURE.md` (98,619). Package Markdown includes source documentation for `minui-list`, `minui-presenter`, ZcrapeGoat, Art Book, and the DMC driver. Its ownership is classified per package before any change.

Always-applied agent context before any task routing is `AGENTS.md` (22,009 bytes) plus the two Cursor rules with `alwaysApply: true`, `zlyme-core.mdc` (1,581) and `knulli-packages.mdc` (1,193): 24,783 bytes.

GitHub state, read on 2026-11-21 and not changed: the repository is public. `main` has no branch protection and no ruleset. Auto-merge is off. Delete-branch-on-merge is off. Dependabot alerts are on. Dependabot security updates, secret scanning, and push protection are off. There is no `.github/dependabot.yml` and no `CODEOWNERS`. There are four workflows. Each declares `permissions`. There are 29 `uses:` lines. Three call the local `build-stage.yml`. The other 26 name an external action by version tag, not by commit SHA.

## 19A recovery baseline

A Git bundle of every ref was made on 2026-11-21 at 12:48:54 UTC, before any branch was deleted. SHA-256 `b8f784b1c5e071ab0733e9f541607f447162275fcec465a063bfdb98a657589a`. `git bundle verify` passed. A mirror clone of it contained `0dd8b86e`, `803664a9`, the four Phase 18C commits, all 14 branch heads, and 11 tags. It is kept outside the repository, with the branch inventory. The 19A pull request names the path.

Twelve remote and local branches whose tips were ancestors of `main` were deleted after a second SHA check: `ci/ccache-8gib`, `ci/require-product-image`, `docs/18c5-gba-wine-status`, `docs/phase-18g-roadmap-restructure`, `docs/phase-19-preflight`, `release/zlyme44.5-direct`, `release/zlyme44.5-prepare`, and `zlyme45-phase-18a`, `-18b`, `-18d`, `-18e`, `-18f`. The only pull request, #4 from `zlyme45-phase-18a`, was already merged. Their commits stay in `main`. Older documents still name those branches, and the commits they recorded are in `main`.

`zlyme45-phase-18c` stays at `2525168d0a81de4f85a864f1a4559e694edb0616`. It forks from `d4159da87570d8ddb60e31e7fe8968a2d078a472` and has four commits not in `main` or any tag:

- `71fc0f835aa90f00f8b63791573743b84643f798`, 2026-11-05, test: record how RetroArch reads GBA ZIP names. Adds `scripts/tests/gba_zip_parse.c` and `scripts/tests/test_gba_zip_names.sh`, and edits `docs/ROADMAP.md` and `docs/research/phase-18-plan.md`.
- `02ab6223c1174abc985c959752802e69cbd4c448`, 2026-11-07, test: give the GBA ZIP fixtures a readable local header. Edits that test and the plan.
- `fcc100c77997b776737cc606f9cfc37990451b6b`, 2026-11-07, test: record Wine UTF-8 argument preservation. Adds `scripts/tests/test_wine_utf8_args.sh`, and edits the roadmap and the plan.
- `2525168d0a81de4f85a864f1a4559e694edb0616`, 2026-11-07, docs: record the unread Flip locale and the missing GBA archive. Edits the roadmap and the plan.

`main` records the 18C closure in [phase-18.md](../phases/phase-18.md). Those branch tests and plan sections are not on `main`. The branch is not merged.

## 19A. Retention policy and recoverable baseline

Objective: a verified backup, removal of branches already contained in `main`, the retention policy, this plan, and an end to the instruction to load all of `docs/` into an AI tool.

Allowed: the policy section in `docs/WRITING.md`; routing sentences in `README.md`, `docs/README.md`, `docs/research/README.md`, and the documentation skill that point to it; this plan, the Phase 19 summary, the roadmap row; adding this plan to the link check.

Excluded: deleting or rewriting any existing record; `AGENTS.md`; the logbook and its checksum manifest; GitHub settings; Dependabot; firmware, build, release, and runtime files; the NextUI pin; tags.

Preconditions: the baseline above, a verified bundle, and a clean worktree apart from the untracked ARMHF compiler cache.

Acceptance: the link, contract, logbook-order, changelog-notes, and Phase 13A documentation tests pass; `git diff --check` is clean; the diff deletes no file; blob IDs of the archive, research bodies other than the index, the logbook, the ADRs, `AGENTS.md`, and package provenance records match the baseline; one reviewer reads the diff; the maintainer reviews the draft pull request.

Rollback: close the pull request unmerged, or revert its merge. A deleted branch is restored from the bundle with `git fetch <bundle> refs/heads/<name>:refs/heads/<name>` and a normal push.

Evidence to keep: the bundle and inventory outside the repository; the SHAs above.

Firmware build: no. Hardware: no. Maintainer approval: yes, the pull request.

## 19B. Evidence-led deletion of historical records

Objective: a measured fall in historical bytes in the tree, with each surviving fact moved to its existing owner.

Allowed: retirements that pass the seven checks, in batches. Each batch lists files, dispositions, the check record, bytes removed and added, link and test-list repairs, and any open debt moved into the Open validation debt index in `docs/MAINTENANCE.md`.

Excluded: the protected documents in `docs/WRITING.md`; ADRs; licensing, provenance, and recovery evidence; vendored package documentation; a new archive or history file; weakening a test to let a file go.

Candidates the maintainer is asked to rule on first: the Phase 10 and Phase 15 documentation audits, the Phase 17 documentation inventory and preservation-decision record, the closed Phase 18 plan and DSperate preflight, and the archived roadmap snapshots. The Phase 17C instruction map and clause ledger wait for 19C. `docs/research/phase-12d-usb-mtp.md`, the logbook, and early kernel, boot, suspend, and recovery research are MANUAL REVIEW.

Preconditions: 19A merged; the commit being changed is in a verified backup; for the logbook, a maintainer decision on how the checksum manifest treats a retired entry.

Acceptance: the documentation tests pass; `test_doc_links.py` loses entries only for retired files; added bytes stay within the budget the maintainer sets; no open item exists only in a retired file; a reviewer reads the diff.

Rollback: `git revert` the batch. The retired text stays in Git history.

Evidence to keep: each batch's check record in its pull request.

Firmware build: no. Hardware: no. Maintainer approval: yes, per batch, and per MANUAL REVIEW file.

## 19C. Root agent context

Objective: less always-applied context with the same safety.

Allowed: a clause-level candidate map of `AGENTS.md` and the always-applied rules: universal safety, task routing, subsystem rules, duplicates, history, and rules that can become path-scoped or nested guidance. After that map is accepted, a restructure of `AGENTS.md`, the Cursor rules, and the OpenCode agent file.

Excluded: losing the authorization boundary, hardware safety, the source-of-truth order, licensing limits, the physical-SD transfer rule, or the difference between host, build, and hardware results.

Preconditions: 19A merged. The Phase 17C clause ledger stays as the comparison until 19C is accepted.

Acceptance: every kept clause maps to a place that is still loaded for its scope; always-applied bytes before and after; the same representative tasks run in Cursor and OpenCode before and after (a documentation typo, a NextUI package change, an audio change, a boot or storage change, a dependency update, a hardware investigation), recording what each read before its first source edit; a reviewer reads the diff.

Rollback: revert the commit.

Evidence to keep: the clause map and the before-and-after load results, in the pull request.

Firmware build: no. Hardware: no. Maintainer approval: yes.

## 19D. GitHub governance, required checks, and CI security

Objective: protect `main` with the Validation checks, keep token permissions minimal, and decide on action SHA pinning, `CODEOWNERS`, secret scanning, and push protection.

Allowed: a ruleset or branch protection, workflow permission changes, action pins, `CODEOWNERS`, and security settings the maintainer selects after reading the current state above.

Excluded: release semantics, secrets, self-hosted runners, paid features, and anything that dispatches the Build workflow without separate authorization.

Preconditions: the maintainer decides whether `main` becomes pull-request-only. Today documentation and release fixes are pushed to `main` directly.

Acceptance: a test pull request is blocked until Validation passes; Validation still passes; a pinned action resolves; the setting is read back through the API.

Rollback: remove the ruleset or setting; revert the workflow commit.

Evidence to keep: the before and after setting state.

Firmware build: only if `build.yml` or `build-stage.yml` change, then one authorized `publish_release` false Build. Hardware: no. Maintainer approval: yes.

## 19E. Dependency updates and upstream visibility

Objective: update notices for GitHub Actions and the Docker base image, and a readable inventory of Buildroot package pins.

Allowed: a `.github/dependabot.yml` for the `github-actions` and `docker` ecosystems; a script and test that list package versions, sources, and hashes from the `.mk` and `.hash` files.

Excluded: auto-merge; silent upgrades; the NextUI pin, which follows `docs/MAINTENANCE.md`; Buildroot, kernel, and U-Boot bumps. Buildroot packages are not a Dependabot ecosystem. The existing watch skills stay the review path for them.

Preconditions: 19D required checks in place.

Acceptance: the configuration validates; an update pull request needs review; the pin inventory matches the `.mk` files in a test.

Rollback: delete the configuration; close the pull requests.

Evidence to keep: the pin inventory output for the release source.

Firmware build: one authorized `publish_release` false Build before merging an update that changes the build container or a Build action. Hardware: no. Maintainer approval: yes.

## 19F. SBOM, provenance, and supply-chain checks

Objective: an SBOM and build provenance for each published release, from the exact release source.

Allowed: evaluate Buildroot's own `show-info` and `legal-info` output, and whether this Buildroot release includes an SBOM generator; build attestations for the OTA and card image if the account supports them; dependency-graph submission.

Excluded: relabeling the two unknown-license exceptions; a release-asset change without maintainer approval; firmware content changes.

Preconditions: 19D and 19E accepted. Adding an asset changes `scripts/check-release-assets.py` and the `fail_on_unmatched_files` asset list, which is a release-contract change.

Acceptance: the SBOM names the same packages, versions, and license identifiers as the `.mk` files; the release checks still pass; the root hash of a candidate does not change because of the SBOM step.

Rollback: revert the workflow and checker commit. A published release is not edited.

Evidence to keep: the SBOM and attestation of the first release that carries them.

Firmware build: yes, one authorized `publish_release` false Build. Hardware: no. Maintainer approval: yes.

## Decisions for the maintainer

- Keep `zlyme45-phase-18c`, or replace it with an annotated tag after verifying the tag reaches all four commits.
- The 19B budget: the ratio of added to removed bytes. The report proposed at most 10 to 20 KB added for every 100 KB removed.
- How a retired logbook entry is treated by `scripts/tests/logbook_entries.sha256`.
- Whether `docs/archive/` is retired as a whole. The Roadmap section of `docs/WRITING.md` still sends long closed-phase planning to `docs/archive/` or `docs/research/`. 19A left that rule unchanged. Under the new retention rule that move is relocation, so the maintainer decides whether it stays.
- Whether `main` becomes pull-request-only, and which security settings are turned on.
- The Phase 17 preservation contract in [phase-17-plan.md](phase-17-plan.md) says research, the archive, the logbook, and ADRs are not deleted. That was Phase 17's working rule. If 19A is accepted, `docs/WRITING.md` is the current owner of retention and that sentence stays as Phase 17 history.
