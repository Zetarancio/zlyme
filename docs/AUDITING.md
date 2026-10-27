# Auditing

This file is the procedure for an AI-assisted search for defects. It says how a finding is discovered, checked, classified, and, after authorization, fixed.

It does not own architecture, release policy, package intake, or the ordinary change review. Those stay in `docs/ARCHITECTURE.md`, `docs/MAINTENANCE.md`, `docs/UPSTREAMS.md`, and `AGENTS.md`. Prose rules stay in `docs/WRITING.md`. Design priorities stay in `docs/ENGINEERING_PRINCIPLES.md`.

## When this procedure applies

The ordinary pre-commit review is the change policy in `AGENTS.md`: read the implementation, search for an existing helper, make the smallest change, run the narrowest test, and inspect the diff. That review is part of every code change. It is not a dedicated audit, and this procedure does not add another pass on top of it.

Use a dedicated audit when one of these is true:

- a suspected defect is not yet understood;
- the change touches the bootloader, kernel, DTS, persistent storage, OTA or initramfs, power, suspend, the NAND preloader, or recovery;
- the change crosses two of those boundaries;
- the maintainer asks for an audit of a named area.

A typo, a comment, a documentation edit, a pin that does not change behavior, or a focused fix whose call path and test are already known does not need this procedure. A source-only change stays at source depth. It does not acquire a hardware gate, a full image build, or a pass over the rest of the repository.

Do not audit the whole tree as a precondition for a change. Name the paths and the contract being examined. Leave the rest unread, and say so.

## Stages

Discovery, verification, and remediation stay separate. A stage does not borrow the conclusion of a later one.

### Discovery

Discovery is read-only. Record the commit that was read. If the worktree is dirty, say which paths differ from that commit and do not treat those edits as the commit.

- Read the implementation and the callers that actually reach it.
- Trace that path from a real entry point: an init script, a `zlyme-*` command, a PAK launch, the updater, or a board hook.
- Compare the path with the contract that owns it. Architecture, board files, and the command's own interface are the contracts. A research note or an old logbook entry is history unless the owning document still says the same thing.
- State a hypothesis a current image can reach: the precondition, the path, and the behavior that would be wrong.
- Name the files that were not read.

A hypothesis is not a finding. "The code could" is not a call path.

### Verification

Verification tries to falsify the hypothesis.

- Reachability: the precondition occurs on the current init, command, or update path. A branch that no caller takes is unreachable.
- Reproduction: an existing test under `scripts/tests/`, a command whose output was captured from the tree that was read, or a device observation already recorded with its image identity in `docs/LOGBOOK.md` or `docs/OPERATIONS.md`.
- Static checks already used by the tree, when they match the change: ShellCheck, compiler warnings, and the package and kconfig checks in `docs/DEVELOPMENT.md`. A new scanner, CI job, or generated report is outside this procedure.
- Safeguards: the early return, the ownership check, the fail-closed path, and the test that already rejects the case.

A successful compile, a test that does not exercise the path, and a coherent explanation are each one input. None of them is confirmation. None of them is hardware acceptance. Host execution and on-device inspection are different claims, and `docs/WRITING.md` keeps built, booted, launched, and tested apart. `AGENTS.md` keeps that rule for agents.

If a required piece of evidence is missing, report the gap. Do not invent a SHA, a command result, a measurement, or a Flip outcome.

### Remediation

Remediation starts only when the task or the review asks for a fix. Discovery and verification do not edit the tree.

- Change the smallest span that restores the violated invariant.
- Follow the change policy in `AGENTS.md` and, for a nontrivial bug, the upstream-first procedure in `docs/UPSTREAMS.md`.
- Add or extend the narrowest existing regression test that fails on the defect and passes on the fix.
- Review the diff for unrelated edits.
- Validate at the depth in the next section. An audit does not by itself build an OTA, dispatch a release, or start a hardware experiment.

Kernel-patch classification stays the procedure in `docs/MAINTENANCE.md`. This file does not add a second scheme.

## Classification

Confidence and severity are separate. Say both.

Confidence is one of:

| Status | Meaning |
| --- | --- |
| Confirmed | The invariant, the reachable path, and the expected-versus-actual evidence are all in hand. |
| Probable/unverified | The source reading is coherent, and at least one required piece of evidence is still missing. |
| Rejected | The path is unreachable, a safeguard already holds, or a reproduction attempt contradicted the hypothesis. |
| Explicitly deferred | The finding remains open, and a named decision leaves it unfixed. The limit is recorded. Deferral is not acceptance. |

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

The stronger row asks for a deeper reading and an honest hardware gap. It does not authorize a new device experiment, and it does not pull unrelated subsystems into the audit.

## Independent challenge

A high-risk finding is challenged by a reader that did not produce the hypothesis, when that is practical. A maintainer, a fresh reading of the cited source, or an existing test that would fail if the claim were wrong can be that challenge.

A second prompt in the same conversation is not an independent review. It still has the earlier conclusion in front of it.

A trivial edit, a documentation change, and a hypothesis that an existing test already falsifies do not need a second AI review. If a separate challenge is not practical, say so. Leave the finding at the evidence that exists. Do not describe the same conversation as a second reviewer.

## Boundaries that stay where they are

- Zlyme source is the authority for what the OS ships. The hardware wiki named in `docs/UPSTREAMS.md` is the authority for device facts. Comparison trees are not Zlyme behavior. `docs/ROADMAP.md`, `docs/LOGBOOK.md`, and `docs/research/` are history.
- An audit reads the hardware wiki when the finding depends on a device fact. It does not edit the wiki unless the task says to.
- Accepted behavior stays accepted inside the scope of its record. Superseded designs in `AGENTS.md` stay superseded.
- Release, delta, and publication decisions stay in `docs/MAINTENANCE.md`.
- A result that fixes, accepts, supersedes, or defers a validation finding updates the Open validation debt index in the same change. `docs/WRITING.md` owns that rule. A dated logbook entry is for evidence worth keeping, under the same file. This procedure does not add an audit log, a template, a tracker, or a generated report.
- Add a script or a CI check only after the same manual check has been needed again and the script would replace that repetition. The checks in `scripts/tests/` are the current automation.

## Report

Report the classification, the severity, the nine evidence items, and any verification gap. Also report what was read, what was rejected, and which checks were not run. A gap is part of the result.
