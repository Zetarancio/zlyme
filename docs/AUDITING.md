# Auditing

This file is the procedure for an AI-assisted search for defects. It says how a finding is discovered, checked, classified, and, after authorization, fixed.

It does not own architecture, release policy, package intake, or how a change is made. Those stay in `docs/ARCHITECTURE.md`, `docs/MAINTENANCE.md`, `docs/UPSTREAMS.md`, and `AGENTS.md`. Prose rules stay in `docs/WRITING.md`. Design priorities stay in `docs/ENGINEERING_PRINCIPLES.md`.

## Two reviews

Ordinary change review is the change policy in `AGENTS.md`: read the implementation, search for an existing helper, make the smallest change, run the narrowest test, and inspect the diff.

After a nontrivial implementation change, `AGENTS.md` also requires a post-change review by `zlyme-code-reviewer` before the change is finalized or committed. The Cursor and OpenCode implementations are named there. That review reads one named diff from a fresh context. It is not a dedicated audit, and a clean review is not proof that the tree is free of defects.

Use the dedicated audit in the rest of this file only when one of these is true:

- a suspected defect is not yet understood;
- the change touches the bootloader, kernel, DTS, persistent storage, OTA or initramfs, power, suspend, the NAND preloader, or recovery;
- the change crosses two of those boundaries;
- the maintainer asks for an audit of a named area.

A typo, a comment, a documentation edit, a pin that does not change behavior, or a focused fix whose call path and test are already known does not need a dedicated audit. That exemption does not skip the post-change reviewer when `AGENTS.md` requires it. A source-only change stays at source depth. It does not acquire a hardware gate, a full image build, or a pass over the rest of the repository.

Start with a narrow subsystem or diff. Follow the callers, dependencies, or ownership boundary that the finding actually depends on. Report a meaningful exclusion or an execution path that was not completed. Do not list every unread file.

## Stages

Discovery, verification, and remediation stay separate. A stage does not borrow the conclusion of a later one.

### Discovery

Discovery is read-only. Record the commit that was read. If the worktree is dirty, say which paths differ from that commit and do not treat those edits as the commit.

- Read the implementation and the callers that actually reach it.
- Trace that path from a real entry point: an init script, a `zlyme-*` command, a PAK launch, the updater, or a board hook.
- Compare the path with the contract that owns it. Architecture, board files, and the command's own interface are the contracts. A research note or an old logbook entry is history unless the owning document still says the same thing.
- State a hypothesis a current image can reach: the precondition, the path, and the behavior that would be wrong.

A hypothesis is not a finding. "The code could" is not a call path.

### Verification

Verification tries to falsify the hypothesis.

- Reachability: the precondition occurs on the current init, command, or update path. A branch that no caller takes is unreachable.
- Reproduction: a discriminating test with a defined expected result, a command whose output was captured from the tree that was read, or a device observation already recorded with its image identity. A test that merely exits successfully, without exercising the suspected defect, is not evidence.
- An existing check under `scripts/tests/`, ShellCheck, compiler warnings, or the package and kconfig checks in `docs/DEVELOPMENT.md`, when that check actually covers the path.
- A temporary isolated harness, fault injection, sanitizer, fuzzer, or targeted reproduction, when it fits the risk. These are techniques, not infrastructure to add to the tree. They must not modify production code or endanger hardware. A read-only reviewer describes the reproduction. A separately authorized isolated worktree, or the implementation agent, runs it.
- Safeguards: the early return, the ownership check, the fail-closed path, and the test that already rejects the case.
- A historical observation in `docs/LOGBOOK.md` or `docs/OPERATIONS.md` is evidence for the image and conditions it records. Use it for a defect in current source only after checking that the relevant code and conditions still match.

A successful compile and a coherent explanation are inputs. Neither is confirmation. Neither is hardware acceptance. Host execution and on-device inspection are different claims, and `docs/WRITING.md` keeps built, booted, launched, and tested apart. `AGENTS.md` keeps that rule for agents.

If a required piece of evidence is missing, report the gap. Do not invent a SHA, a command result, a measurement, or a Flip outcome.

### Independent verification

The author of a hypothesis does not become an independent reviewer by rereading it.

An independent reviewer starts in a fresh context and does not receive the original conclusion, rationale, or suggested fix. A separate context is useful. It is not independent when the prompt that starts it already contains that conclusion. The parent reports whether a separate reviewer actually ran. A skipped or failed invocation is not an independent review.

An independent, discriminating test can verify a claim without a second reviewer. The test needs a defined expected result for the suspected defect. A passing suite that does not exercise that defect does not.

A trivial edit, a documentation change, and a hypothesis that such a test already falsifies do not need a second reviewer. If a separate review is not practical, say so and leave the finding at the evidence that exists.

## Review cadence and stopping rules

Ordinary implementation uses this cadence. It does not replace a dedicated audit, and it is not a waiver of a confirmed defect.

The implementation agent runs focused tests that can tell the changed behavior from the old one. Related corrections are grouped, and the relevant tests are run, before an independent post-change review. That review normally happens once for a coherent change, not after every edit.

When the reviewer confirms a defect, the implementation agent reproduces it, applies the smallest correction, and runs the tests that cover that correction. One fresh follow-up review then looks at the correction and the ownership or calling boundary it affects. It does not automatically repeat the whole baseline-to-HEAD search.

An ordinary implementation task has a default budget of one comprehensive reviewer pass plus one follow-up pass. The budget is not an evidence threshold and it is not permission to ignore a defect. If a further substantial or safety-critical problem remains, stop, checkpoint the work, and report it. Another review needs a fresh scope from the maintainer.

A confirmed serious defect is not silently accepted, dismissed, or described as fixed without the evidence in Remediation. The independent reviewer still starts in a fresh context. Its prompt carries the baseline, the worktree state, and the scope. It does not carry the author's verdict, a hypothesis, a proposed fix, or an earlier review's conclusion.

The baseline stays the recorded pre-change commit. A later checkpoint does not replace it. The scope includes committed, staged, unstaged, and relevant untracked changes. The reviewer inspects the Git diff against that baseline and the current worktree. If that comparison cannot be made, the review says its coverage is incomplete. A source reading is not a substitute for the diff.

The implementation agent may reuse its own context and the tests that already falsified a hypothesis. That reuse does not make the agent the independent reviewer. After a focused correction, run the affected tests. Do not rerun an unrelated host test unless its contract or a dependency it checks has changed. A host result is not hardware acceptance.

### Remediation

Remediation starts only when the task or the review asks for a fix. Discovery and verification do not edit the production tree.

- Change the smallest span that restores the violated invariant.
- Follow the change policy in `AGENTS.md` and, for a nontrivial bug, the upstream-first procedure in `docs/UPSTREAMS.md`.
- Prefer a regression check that fails on the defect and passes after the correction. When a meaningful check cannot be built safely or practically, record why, and record the strongest evidence that was actually obtained.
- Review the diff for unrelated edits.
- Validate at the depth below. An audit does not by itself build an OTA, dispatch a release, or start a hardware experiment.
- After a substantive correction, one follow-up review covers that correction and the boundary it affects, as in Review cadence and stopping rules. A serious confirmed finding is not waived silently. The follow-up does not restart the whole baseline search, and a remaining safety-critical problem stops for the maintainer.

Kernel-patch classification stays the procedure in `docs/MAINTENANCE.md`. This file does not add a second scheme.

## Classification

Evidence status, remediation disposition, and severity are three separate statements.

Evidence status is one of:

| Status | Meaning |
| --- | --- |
| Confirmed | The invariant, the reachable path, and the expected-versus-actual evidence are all in hand. |
| Probable/unverified | The source reading is coherent, and at least one required piece of evidence is still missing. |
| Rejected | The path is unreachable, a safeguard already holds, or a reproduction attempt contradicted the hypothesis. |

Remediation disposition is one of:

| Disposition | Meaning |
| --- | --- |
| Open | The finding is not yet fixed, deferred, or superseded. |
| Fixed | The authorized correction is in the tree, with the evidence from Remediation. |
| Deferred | An explicit decision leaves a confirmed or still-unverified finding unfixed. The limitation is recorded. Deferral is not acceptance. |
| Superseded | A later change or a recorded decision replaces the finding. The old evidence stays where it was written. |

A confirmed defect can remain deferred. Deferred requires the decision and the limitation, not a lower evidence status.

Confirmed on the host, or confirmed by reading source, is not hardware acceptance. Hardware acceptance is a separate claim and requires a Miyoo Flip run that covered the claim, or an existing acceptance record that already covers it. Quote that record. A new reading does not reopen an acceptance whose evidence still covers the claim.

Severity is the consequence if the defect is real: failed boot, NAND or power damage, persistent-data loss, a wrong device or partition write, a broken runtime contract, or no user-visible effect. Do not raise the severity because confidence is low, and do not treat a small impact as proof that the path is unreachable.

## Evidence for an actionable finding

A finding that justifies a code change has all of the following:

1. Commit SHA of the tree that was read.
2. Exact location: repository path and the function, symbol, or line.
3. The requirement or invariant that is violated, and the document or source that states it.
4. Preconditions that a current boot, command, or update can actually meet.
5. The execution path from a real entry point to that location.
6. Expected behavior and actual behavior.
7. Proof or reproduction, as defined under Verification.
8. Safeguards that were considered, including the one that was expected to prevent the defect.
9. The smallest reasonable fix, still unapplied until remediation is authorized.

A probable finding may be reported with the missing items named. It does not authorize an edit. Filling a gap with a plausible explanation moves the finding backwards, not forwards.

## Depth

Match the work to the risk of the paths being examined. A change that crosses subsystems uses the depth of the riskier side.

| Change | Depth |
| --- | --- |
| Documentation, comments, or a behavior-neutral metadata edit | Read the owning document and the diff. Stop. |
| Userspace with an existing test that exercises the path | Trace the path, run that test, and read the safeguard that would falsify the hypothesis. |
| Bootloader, kernel, DTS, persistent storage, OTA, initramfs, power, suspend, preloader, recovery, or a cross of those | Trace the path across the boundary. Name the invariant from `docs/ARCHITECTURE.md` or `docs/OPERATIONS.md`. Read the existing safeguard. State which device evidence would be required before calling the result hardware-accepted. |

The third row is the high-risk set. `AGENTS.md` requires the post-change reviewer for a change in that set. The row asks for a deeper reading and an honest hardware gap. It does not authorize a new device experiment, and it does not pull unrelated subsystems into the audit.

## Boundaries that stay where they are

- Zlyme source is the authority for what the OS ships. The hardware wiki named in `docs/UPSTREAMS.md` is the authority for device facts. Comparison trees are not Zlyme behavior. `docs/ROADMAP.md`, `docs/LOGBOOK.md`, and `docs/research/` are history.
- An audit reads the hardware wiki when the finding depends on a device fact. It does not edit the wiki unless the task says to.
- Accepted behavior stays accepted inside the scope of its record. Superseded designs in `AGENTS.md` stay superseded.
- Release, delta, and publication decisions stay in `docs/MAINTENANCE.md`.
- A result that fixes, accepts, supersedes, or defers a validation finding updates the Open validation debt index in the same change. `docs/WRITING.md` owns that rule. A dated logbook entry is for evidence worth keeping, under the same file. This procedure does not add an audit log, a template, a tracker, or a generated report.
- Add a permanent script or a CI check only after the same manual check has been needed again and the script would replace that repetition. The checks in `scripts/tests/` are the current automation. A temporary harness used to verify one finding is not that addition.

## Report

Report the evidence status, the remediation disposition, the severity, the nine evidence items, and any verification gap. Also report a meaningful exclusion, an incomplete path, and which checks were not run. A gap is part of the result.
