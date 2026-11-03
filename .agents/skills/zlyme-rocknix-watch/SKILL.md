---
name: zlyme-rocknix-watch
description: Check newer official ROCKNIX next commits for RK3566 patches and fixes, and report candidates against Zlyme without applying them. Use when asked to watch ROCKNIX, compare RK3566 kernel or driver fixes, or update the ROCKNIX checkpoint.
---

# ROCKNIX watch

Follow `AGENTS.md`. This skill does not replace `docs/UPSTREAMS.md`.

The default operation is read-only. Do not apply a patch, change a kernel version or source pin, copy a patch stack, build, make an OTA, or run a hardware test. Do not advance the reviewed-through cursor unless the whole interval was enumerated and the relevant candidates were triaged. A failed or partial scan leaves that cursor where it is. If upstream history was rewritten, report it. Do not reset the cursor silently.

Before a comparison:

1. Read `docs/UPSTREAMS.md` for the source hierarchy, the upstream-first procedure, and the patch classes.
2. Read the hardware wiki when a device fact is required. Official ROCKNIX is comparison evidence, not the hardware authority.
3. Use `ROCKNIX/distribution` branch `next`. Do not treat archived `Zetarancio/distribution` as live upstream state.
4. Read Zlyme's current kernel version, configuration, modules, graphics choice, and board files before judging a commit.
5. Read [phase-17-upstream-monitor.md](../../../docs/research/phase-17-upstream-monitor.md). An observed HEAD is not a reviewed SHA. A source pin is not a scan checkpoint.

Then:

1. Verify the live `next` tip. Do not record a stale tip as a completed scan.
2. List commits in order across the whole interval, including merges. Do not stop at a truncated comparison page.
3. Read subjects and paths. Read the diff of a relevant candidate, including a generic fix outside an RK3566 directory, and read later commits that change that diff.
4. Check whether selected upstream Linux or Zlyme already has the fix.
5. Classify the candidate with the classes in `docs/UPSTREAMS.md`. Record the SHA, date, path, and upstream link.
6. Separate a review from an implementation. Name the host checks, and name a device test only when the change is relevant. A host check is not Miyoo Flip acceptance.
