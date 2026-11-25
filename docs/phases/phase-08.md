# Phase 8. NextUI fork

Objective: fetch Zlyme's NextUI from a pinned commit, keep other-platform source in the fork, and leave `/boot` read-only.

Disposition: Closed, 2026-09-30.

Accepted behavior: hardware-equivalent runtime `7a0fc397cb5b3e0f7c4b19f4f3abe8626eaccaf8`. The profile did not justify a frontend optimization. Upstream pins were not moved. `FSCK0000.REC` is the name dosfstools gives a recovered orphan cluster. It is not a Zlyme log. An existing file can predate this boot policy. A Phase 8A boot with no such file leaves open whether a later checker writes one. The `/storage` unmount result belongs to `zlyme-my355-20260930-632202865c71.tar`. `zlyme-my355-20260930-07aacf303475.tar` removed those markers. Its `zlyme-halt` matched that source on the Flip and was not given a second shutdown cycle.

Records: [docs/research/phase-08-frontend-source.md](https://github.com/Zetarancio/zlyme/blob/391508499a077efeb5e24ca966abab09cd635f5f/docs/research/phase-08-frontend-source.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-8-nextui-fork).
