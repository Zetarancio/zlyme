# Phase 7. DMC module

Objective: run the RK3568 DMC devfreq driver as an out-of-tree module instead of a kernel patch.

Disposition: Closed.

Accepted behavior: accepted runtime `21de8081d6e6a419d708e8f3c792e4f1357eaafc`. `1012a` and `1012b` are gone. DFI patch `1010` stayed.

Limitations: a later failure-path correction, `70acb1d27443447df84903e2043a2af05dbd9ee3`, was source-reviewed and was not given its own hardware run.

Records: `package/drivers/rk3568-dmc/README.md`. This phase has no research file. The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-7-dmc-module). The older chronology is also in [docs/archive/roadmap-2026-10-15.md](../archive/roadmap-2026-10-15.md).
