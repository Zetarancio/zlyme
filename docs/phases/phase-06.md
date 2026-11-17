# Phase 6. Deep suspend

Objective: enter and leave Linux mem suspend through the existing RK3568 BL31 path, from the menu and from a game, using the power button.

Disposition: Closed.

Accepted behavior: accepted runtime `b709719aac5c5540394d0369e5e06981b8aa00bc`. The PM config driver stays built in. RK817 `005` stayed unapplied.

Limitations: lid-open wake was not measured for this closure. A later check on the installed Phase 13 candidate saw one lid open wake the device. That check does not reopen this phase. Long cycle counts, a standby-current number, and a full USB or radio matrix were not closure requirements and were not claimed.

Records: [docs/research/phase-06-deep-suspend.md](../research/phase-06-deep-suspend.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-6-deep-suspend).
