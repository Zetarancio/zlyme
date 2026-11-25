# Phase 1. Application-scoped Weston

Objective: run a Wayland or X11 program without a permanent compositor.

Disposition: Closed, 2026-09-23.

Accepted behavior: temporary Weston recovered NextUI on Panfrost and libmali. WestonPack and Wine returned the same way.

Limitations: no open work was recorded. The first tracer returned 0 after `weston-simple-egl` had already aborted with `Assertion ret && n >= 1 failed`. A wrapper exit does not show that the client rendered. That Buildroot Weston 14.0.2 run is not PortMaster's WestonPack.

Records: [docs/research/phase-01-weston.md](https://github.com/Zetarancio/zlyme/blob/391508499a077efeb5e24ca966abab09cd635f5f/docs/research/phase-01-weston.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-1-application-scoped-weston).
