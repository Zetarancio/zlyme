# Phase 19. Development infrastructure and maintainability

Objective: make the documentation smaller and cheaper to load as agent context, and add GitHub governance, dependency visibility, and supply-chain checks suited to a Buildroot tree. Firmware does not change.

Disposition: active. 19B1 through 19B7 are merged. Their file lists and seven-check records are pull requests #6 through #12. 19B8 keeps the Theme Manager note, the PortMaster capability inventory, the Phase 14 device log, and the button-layout audit. The Phase 14 stability note stays. 19B stays open.

Baseline: `main` before this change was `0dd8b86e26c69c55b691ea5b6824aa7b77f0385d`. That tree is annotated tag `archive/pre-phase-19-docs`. Published `zlyme44.5` is tag `zlyme-44857224770`, `803664a98875b0c128f16726b8d117e2b1b41e25`. Twelve branches already contained in `main` were deleted after a verified bundle backup. The four Phase 18C commits that are not in `main` are on annotated tag `archive/phase-18c-investigation`, peeled commit `2525168d0a81de4f85a864f1a4559e694edb0616`. Neither archival tag is a firmware release or a protected ref. The branch name was removed after the tag was verified.

The work plan is [docs/research/phase-19-plan.md](../research/phase-19-plan.md). That plan is temporary. It is an active plan, not current architecture. When the phase closes it becomes a retirement candidate under [Documentation retention](../WRITING.md#documentation-retention). Closing the phase does not itself delete it.
