---
name: zlyme-nextui-watch
description: Check LoveRetro NextUI upstream for new commits, compare them with Zlyme's fork, and propose useful frontend improvements without importing them. Use when asked to watch NextUI, compare the pinned fork, or plan a frontend update.
---

# NextUI watch

This procedure is optional. Follow `AGENTS.md`. It does not replace `docs/UPSTREAMS.md` or the NextUI section of `docs/MAINTENANCE.md`.

The default operation is read-only. Do not change `NEXTUI_VERSION`, rebase or merge either NextUI repository, edit the fork, drop a Zlyme feature to resolve a conflict, build, make an OTA, or run a hardware test. An observed HEAD is not a reviewed SHA. A pin is not a scan checkpoint. A fork commit is not a new LoveRetro revision. Zero commits after a verified base are not an audit of the history before that base.

These identities are different. Read each one. Do not infer that a moving branch contains another.

- LoveRetro `NextUI` branch `main` is the upstream tip.
- `Zetarancio/NextUI` branch `zlyme` is the fork line a Zlyme `main` pin must be able to reach.
- `Zetarancio/NextUI` branch `main` is the separate fork line.
- `NEXTUI_VERSION` in `package/system/nextui/nextui.mk` is the immutable pin.
- The `UPSTREAM` file in that pin records the LoveRetro revision integrated there.
- The NextUI row in [phase-17-upstream-monitor.md](../../../docs/research/phase-17-upstream-monitor.md) is the scan checkpoint.

Before a comparison, read `docs/UPSTREAMS.md`, the NextUI section of `docs/MAINTENANCE.md`, and the checkpoint. Read the owning architecture, device, and operations documents when a candidate touches display, input, audio, storage, launch, or power. Do not copy those contracts into the report.

Then:

1. Read the pin and the `UPSTREAM` file at that commit.
2. Verify the live LoveRetro `main` tip. List only the commits after the embedded base. Confirm ancestry before calling that range new.
3. Read subjects, paths, and the diffs that can affect the frontend, SDL, layout, launch, RetroArch, hotkeys, Settings, or input. Include a later correction or revert.
4. Compare a portable fix with Zlyme's fork changes and with the my355 platform. Another device's implementation does not transfer by itself.
5. Classify with the classes in `docs/UPSTREAMS.md`. Name the fork files, the smallest integration, the host build, and a Flip check only when runtime behavior changes. State the failure and rollback test. A host build is not Miyoo Flip acceptance.
6. Record the observed tip and the review coverage separately. Do not advance the reviewed-through cursor for a partial scan.
