# Phase 19 plan

Status: active-phase planning, from 2026-11-21. Temporary. When Phase 19 closes, its surviving facts go to their owners and this file becomes a retirement candidate under [Documentation retention](../WRITING.md#documentation-retention). Closing the phase does not itself delete it. It is not a contract. The phase summary is [docs/phases/phase-19.md](../phases/phase-19.md).

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

A Git bundle of every ref was made on 2026-11-21 at 12:48:54 UTC, before any branch was deleted. SHA-256 `b8f784b1c5e071ab0733e9f541607f447162275fcec465a063bfdb98a657589a`. `git bundle verify` passed. A mirror clone of it contained `0dd8b86e`, `803664a9`, the four Phase 18C commits, all 14 branch heads then present, and the original release tags. The bundle and its inventory stay outside the repository. This plan records the hash and the time.

Twelve remote and local branches whose tips were ancestors of `main` were deleted after a second SHA check: `ci/ccache-8gib`, `ci/require-product-image`, `docs/18c5-gba-wine-status`, `docs/phase-18g-roadmap-restructure`, `docs/phase-19-preflight`, `release/zlyme44.5-direct`, `release/zlyme44.5-prepare`, and `zlyme45-phase-18a`, `-18b`, `-18d`, `-18e`, `-18f`. The only pull request, #4 from `zlyme45-phase-18a`, was already merged. Their commits stay in `main`. Older documents still name those branches, and the commits they recorded are in `main`.

The Phase 18C investigation tip is annotated tag `archive/phase-18c-investigation`, peeled commit `2525168d0a81de4f85a864f1a4559e694edb0616`. The pre-Phase-19 documentation tree is annotated tag `archive/pre-phase-19-docs`, peeled commit `0dd8b86e26c69c55b691ea5b6824aa7b77f0385d`. Neither tag is a firmware release. Neither is protected, and neither is immutable; tag protection is 19D. The branch name `zlyme45-phase-18c` was removed after the investigation tag was verified locally and on GitHub. The investigation forks from `d4159da87570d8ddb60e31e7fe8968a2d078a472` and has four commits not in `main`:

- `71fc0f835aa90f00f8b63791573743b84643f798`, 2026-11-05, test: record how RetroArch reads GBA ZIP names. Adds `scripts/tests/gba_zip_parse.c` and `scripts/tests/test_gba_zip_names.sh`, and edits `docs/ROADMAP.md` and `docs/research/phase-18-plan.md`.
- `02ab6223c1174abc985c959752802e69cbd4c448`, 2026-11-07, test: give the GBA ZIP fixtures a readable local header. Edits that test and the plan.
- `fcc100c77997b776737cc606f9cfc37990451b6b`, 2026-11-07, test: record Wine UTF-8 argument preservation. Adds `scripts/tests/test_wine_utf8_args.sh`, and edits the roadmap and the plan.
- `2525168d0a81de4f85a864f1a4559e694edb0616`, 2026-11-07, docs: record the unread Flip locale and the missing GBA archive. Edits the roadmap and the plan.

`main` records the 18C closure in [phase-18.md](../phases/phase-18.md). Those investigation tests and plan sections are not on `main`. They remain reachable from `archive/phase-18c-investigation`. They are not merged.

## 19A. Retention policy and recoverable baseline

Objective: a verified backup, removal of branches already contained in `main`, the retention policy, this plan, and an end to the instruction to load all of `docs/` into an AI tool.

Allowed: the policy section in `docs/WRITING.md`, including the correction that a closed phase does not automatically relocate its planning into `docs/archive/` or `docs/research/`; the safeguards for changing an authoritative contract; routing sentences in `README.md`, `docs/README.md`, `docs/research/README.md`, and the documentation skill, which now cites `docs/WRITING.md` rather than the Phase 17 plan; this plan, the Phase 19 summary, and the roadmap row; the two archival tags; the current-state sentences that name those tags instead of the removed branch.

Excluded: deleting a historical research, archive, logbook, or ADR file; rewriting a technical contract beyond those current-state sentences; changing the Phase 17 plan; `AGENTS.md`; the logbook and its checksum manifest; GitHub settings; Dependabot; firmware, build, release, and runtime files; the NextUI pin; existing release tags.

Preconditions: the baseline above, a verified bundle, and a clean worktree apart from the untracked ARMHF compiler cache.

Acceptance: the link, contract, logbook-order, changelog-notes, and Phase 13A documentation tests pass; `git diff --check` is clean; the diff deletes no file; blob IDs of the archive, research bodies other than this plan and the research index, the logbook, the ADRs, `AGENTS.md`, and package provenance records match the baseline, except the authorized writing-policy edits and the two current-state sentences; one reviewer reads the diff against `0dd8b86e`; the maintainer integrates the pull request. 19A is complete when that integration is on `main`.

Rollback: close the pull request unmerged, or revert its merge. A deleted branch is restored from the bundle with `git fetch <bundle> refs/heads/<name>:refs/heads/<name>` and a normal push.

Evidence to keep: the bundle and inventory outside the repository; the SHAs above.

Firmware build: no. Hardware: no. Maintainer approval: yes, the pull request.

## 19B. Evidence-led deletion of historical records

Objective: a measured fall in historical bytes in the tree, with each surviving fact moved to its existing owner.

Allowed: retirements that pass the seven checks, in batches. Each batch lists files, dispositions, the check record, bytes removed and added, link and test-list repairs, and any open debt moved into the Open validation debt index in `docs/MAINTENANCE.md`. An ordinary batch stays within the 0.20 addition budget in `docs/WRITING.md`.

Excluded: the protected documents in `docs/WRITING.md`; ADRs; licensing, provenance, and recovery evidence; vendored package documentation; a new archive or history file; weakening a test to let a file go. The logbook and its checksum manifest are excluded from 19B1. Their later treatment is a separate high-risk decision.

Phase 19B is closed. Its files, blobs, and seven-check records stay in pull requests #6 through #13. The Theme Manager note, the PortMaster capability inventory, the Phase 14 device log, the button-layout audit, and the Phase 14 stability note stay. Recovery stays `archive/pre-phase-19-docs` and the verified Phase 19 backups. 17C waits for 19C. `docs/research/phase-12d-usb-mtp.md`, deep-suspend research, the Linux 7.2.10 records, and the Phase 17 kernel-upgrade preflight stay.

Preconditions: original bytes in a recorded commit and a verified backup; record the batch baseline; compare blobs with the pre-Phase-19 tree on `archive/pre-phase-19-docs`; extend the backup before retiring newer bytes it lacks; no extra full bundle when recovery is already shown; never replace the original backup.

Acceptance: the documentation tests pass; `test_doc_links.py` loses entries only for retired files; added bytes stay within the budget the maintainer sets; no open item exists only in a retired file; a reviewer reads the diff.

Rollback: `git revert` the batch. The retired text stays in Git history.

Evidence to keep: each batch's check record in its pull request.

Firmware build: no. Hardware: no. Maintainer approval: yes, per batch, and per MANUAL REVIEW file.

## 19C. Root agent context

19C1 is the instruction-routing preflight. It records the clause proposal and what Cursor and OpenCode actually load. It does not edit `AGENTS.md` or the always-applied rules. A reduction is 19C2, and only after that proposal is accepted.

Objective: less always-applied context with the same safety.

Allowed: a clause-level candidate map of `AGENTS.md` and the always-applied rules: universal safety, task routing, subsystem rules, duplicates, history, and rules that can become path-scoped or nested guidance. After that map is accepted, a restructure of `AGENTS.md`, the Cursor rules, and the OpenCode agent file.

Excluded: losing the authorization boundary, hardware safety, the source-of-truth order, licensing limits, the physical-SD transfer rule, or the difference between host, build, and hardware results.

Preconditions: 19A merged. The Phase 17C clause ledger stays as the comparison until 19C is accepted.

Acceptance: every kept clause maps to a place that is still loaded for its scope; always-applied bytes before and after; the same representative tasks run in Cursor and OpenCode before and after (a documentation typo, a NextUI package change, an audio change, a boot or storage change, a dependency update, a hardware investigation), recording what each read before its first source edit; a reviewer reads the diff.

Rollback: revert the commit.

Evidence to keep: the clause map and the before-and-after load results, in the pull request.

Firmware build: no. Hardware: no. Maintainer approval: yes.

## 19D. GitHub governance, required checks, and CI security

Objective: required lightweight pull-request validation; `main` protection that still suits one primary maintainer; protection for release tags and for the archival tags; least-privilege workflow permissions; immutable Action commit pins. Secret scanning and push protection are included when the account offers them.

Allowed, after a separate maintainer approval, and not during 19A or 19B1: a ruleset or branch protection; release-tag and archival-tag protection; workflow permission reductions; pinning each external Action to a commit SHA; secret scanning and push protection. The Build workflow stays manually dispatched. Publishing firmware still requires `publish_release` true on that dispatch. This subphase does not change that authorization and does not run a Build.

Excluded: changing release semantics, secrets, self-hosted runners, paid features, and anything that dispatches the Build workflow without separate authorization. The archival tags from 19A are not immutable until this protection exists.

Preconditions: the maintainer decides whether `main` becomes pull-request-only. Today documentation and release fixes are pushed to `main` directly.

Acceptance: a test pull request is blocked until Validation passes; Validation still passes; a pinned action resolves; the setting is read back through the API.

Rollback: remove the ruleset or setting; revert the workflow commit.

Evidence to keep: the before and after setting state.

Firmware build: only if `build.yml` or `build-stage.yml` change, then one authorized `publish_release` false Build. Hardware: no. Maintainer approval: yes.

## 19E. Dependency updates and upstream visibility

Objective: Dependabot for the ecosystems it supports, a Buildroot-native inventory of package versions, licenses, and hashes, and continued use of the existing upstream watchers.

Allowed: a `.github/dependabot.yml` for the `github-actions` and `docker` ecosystems; a script and test that list package versions, sources, licenses, and hashes from the `.mk` and `.hash` files, including custom packages, the ARMHF runtime, and the two unknown-license exceptions. The existing watch skills stay the review path for Buildroot, the kernel, U-Boot, and NextUI.

Excluded: auto-merge; silent upgrades; treating Buildroot packages as a Dependabot ecosystem; relabeling an unknown license. The NextUI pin follows `docs/MAINTENANCE.md`. Vulnerability matching and an SBOM belong to 19F, and only where the exact Buildroot pin provides them.

Preconditions: 19D required checks in place.

Acceptance: the configuration validates; an update pull request needs review; the pin inventory matches the `.mk` files in a test.

Rollback: delete the configuration; close the pull requests.

Evidence to keep: the pin inventory output for the release source.

Firmware build: one authorized `publish_release` false Build before merging an update that changes the build container or a Build action. Hardware: no. Maintainer approval: yes.

## 19F. SBOM, provenance, and supply-chain checks

Objective: evaluate Buildroot-native licensing, vulnerability, and SBOM output at the exact pin; evaluate dependency submission, dependency review, and release-artifact attestations; cover custom packages, the ARMHF runtime, and the license exceptions accurately.

Allowed: evaluate `show-info`, `legal-info`, and any SBOM or vulnerability output this Buildroot release actually has; evaluate GitHub dependency submission, dependency review, and artifact attestations. Adopt one only after that evaluation and a separate approval.

Excluded: relabeling the two unknown-license exceptions; a release-asset change without maintainer approval; firmware content changes; claiming a facility the pin does not have.

Preconditions: 19D and 19E accepted. Adding an asset changes `scripts/check-release-assets.py` and the `fail_on_unmatched_files` asset list, which is a release-contract change.

Acceptance: the SBOM names the same packages, versions, and license identifiers as the `.mk` files; the release checks still pass; the root hash of a candidate does not change because of the SBOM step.

Rollback: revert the workflow and checker commit. A published release is not edited.

Evidence to keep: the SBOM and attestation of the first release that carries them.

Firmware build: yes, one authorized `publish_release` false Build. Hardware: no. Maintainer approval: yes.

## Decisions, 2026-11-21

These are decided. They are not a second copy of the policy.

- `docs/WRITING.md` is the current retention policy. It supersedes the Phase 17 sentence that research, the archive, the logbook, and the ADRs are not deleted. It does not supersede technical architecture, engineering principles, the source-of-truth hierarchy, hardware safety, licensing and attribution, reproducibility, evidence requirements, authorization boundaries, or the safeguards for relocating or shortening a current contract. Those safeguards are under Changing an authoritative contract in `docs/WRITING.md`. [phase-17-plan.md](phase-17-plan.md) stays unchanged as the record of what Phase 17 authorized.
- An ordinary retirement adds at most 0.20 bytes of documentation for each gross byte removed from the retired files. The ratio is a maximum. Reference repair is counted and reported on its own line. Safety evidence is not discarded to meet it.
- `docs/archive/` is not deleted as a directory in one step. Each file still needs the seven checks. Closing a phase does not require a new or permanent in-tree archive.
- The logbook, its existing dated entries, its introduction, and `scripts/tests/logbook_entries.sha256` stay unchanged through 19B1. How a later retirement would treat that checksum is a separate high-risk decision.
- MANUAL REVIEW means automated classification cannot establish a safe disposition. Incomplete evidence is retention. A review is not maintainer approval.
- `archive/pre-phase-19-docs` peels to `0dd8b86e26c69c55b691ea5b6824aa7b77f0385d`. `archive/phase-18c-investigation` peels to `2525168d0a81de4f85a864f1a4559e694edb0616` and still reaches the four investigation commits. The branch name was removed. Neither tag is a firmware release, and neither is immutable until 19D. The recovery bundle SHA-256 is `b8f784b1c5e071ab0733e9f541607f447162275fcec465a063bfdb98a657589a`, taken 2026-11-21 at 12:48:54 UTC, and the bundle stays outside the repository. A second bundle, SHA-256 `50f03181b70b992446a34c42536516b00da82ae73562d9b56b9f4f57a8bcfff2`, taken 2026-11-22 at 09:05:00 UTC, contains `9439d82fd99a859ad6b185275676f08b3fd02477` and requires `0dd8b86e`. It covers the NOTES migration plan after its 19B3 wording change. The original bundle was not replaced.
- Whether `main` becomes pull-request-only, and which security settings are turned on, remains 19D. That choice is not open inside 19A. GitHub settings, Dependabot, Action pins, and SBOM work stay in 19D, 19E, and 19F.
