# Phase 17. Documentation and local agents

Objective: record documentation ownership, preserve the agent instructions, and add the documented local skills without changing firmware.

Disposition: Closed, 2026-11-04, and integrated into main. This is not a firmware acceptance.

Accepted behavior: documentation ownership, the lossless audio move, preserved agent instructions, the documented skill and agent-test limits, the document reconciliation, and the five upstream and kernel-planning skills. The moved audio body was 5294 bytes, SHA-256 `2ce1ad0ca0d60d151fae866a01ddcaf04671719ad22b787b326b9cd23d46921f`. `AGENTS.md` was not shortened. At this closure, `ZLYME_VERSION` stayed `zlyme44.4`. That is not the current product version.

Limitations: the Linux pin stays 7.2.10. Reviewed-through stays unknown for every watched upstream. Cursor automatic skill selection remains unverified. OpenCode runtime testing remains deferred. The 17E4 reviewer returned HTTP 403.

Documentation tests do not check agreement between architecture and operations, an ADR against the code, a reviewer prompt, Cursor rule scope, or the allowlist count. They do not execute the safety rules in `AGENTS.md`.

Records: [docs/research/phase-17-plan.md](../research/phase-17-plan.md), [docs/research/phase-17-documentation-inventory.md](https://github.com/Zetarancio/zlyme/blob/07a7e80e24371117f2e709ce18054899ac24fffc/docs/research/phase-17-documentation-inventory.md), [docs/research/phase-17b-preservation-decisions.md](https://github.com/Zetarancio/zlyme/blob/07a7e80e24371117f2e709ce18054899ac24fffc/docs/research/phase-17b-preservation-decisions.md), [docs/research/phase-17c-agent-instruction-map.md](../research/phase-17c-agent-instruction-map.md), [docs/research/phase-17c-agent-clause-ledger.md](../research/phase-17c-agent-clause-ledger.md), [docs/research/phase-17-upstream-monitor.md](../research/phase-17-upstream-monitor.md), and [docs/research/phase-17g5-kernel-upgrade-preflight.md](../research/phase-17g5-kernel-upgrade-preflight.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-17-documentation-and-local-agents).
