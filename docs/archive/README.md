# Archived notes

`NOTES.md` was the catch-all engineering diary. `PLAN.md` was the original plan. Durable facts from them are in:

- `docs/ARCHITECTURE.md` — boot, storage, graphics, audio, update, services
- `docs/OPERATIONS.md` — serial, resize, GPU, audio, Wi-Fi, updates
- `docs/DEVELOPMENT.md` — Docker, defconfigs, package policy
- `docs/UPSTREAMS.md` — where emulator and hardware facts come from
- `docs/LOGBOOK.md` — chronology

`NOTES.md` is kept because it still contains session-specific warnings, SHA pins, and measurements that are not all copied into the canonical docs. It also contains workstation paths and a "still open" list that has gone stale (for example the U-Boot delay line). The original plan is not in this tree.

`NOTES.md` is never normative. It may still say, in the present tense, things that were true when it was written and are not current policy: architecture, which repository has which role, what counts as a source of truth, and what was implemented or still open. The current authority model is in `docs/ARCHITECTURE.md` and `docs/UPSTREAMS.md`.

`TODO.md` stays gitignored under `NOTES/`.

`roadmap-2026-11-17.md` is the active roadmap as it stood at `8d61d33d263434de4cd4e5f5f6200becd3756908`. That source file is Git blob `bafdc503836eac0b4355b53691bf024162a1d340`, SHA-256 `2a0758db17af6876d63c409e26d4cdfa0b997aa2331fe92fe5de48f6a911b4b7`. At the move, relative links were retargeted for `docs/archive/`. Later reference-only repairs point at retired records by commit. It is not current policy. The current sequence is `docs/ROADMAP.md`.
