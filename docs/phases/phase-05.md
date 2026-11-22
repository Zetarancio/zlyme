# Phase 5. Second patch reduction

Objective: drop kernel patches the new gamepad and the newer kernel made obsolete, and record what stayed.

Disposition: Closed, 2026-09-28.

Accepted behavior: the first accepted runtime is `7eaecf794830a15c53f6b417a1b408dd31ceee53`. The corrected stack that entered Phase 6 is `8119387e0fdb729f1f013bed9dbc48c76e37a1df`. `7eaecf79` was not rewritten as that later stack.

Records: the RK817 limits are in [docs/OPERATIONS.md](../OPERATIONS.md), and the sleep-gauge result is in [docs/research/phase-06-deep-suspend.md](../research/phase-06-deep-suspend.md). The Phase 5 record is [docs/research/phase-05-kernel-patch-audit.md](https://github.com/Zetarancio/zlyme/blob/e6c33fddaa38ade4ce062f1c9f4dbb357e2eb40d/docs/research/phase-05-kernel-patch-audit.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-5-second-patch-reduction).
