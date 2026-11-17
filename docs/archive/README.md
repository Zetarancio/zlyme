# Archived notes

`NOTES.md` and `PLAN.md` were the catch-all engineering diary and the original plan. Durable facts from them are in:

- `docs/ARCHITECTURE.md` — boot, storage, graphics, audio, update, services
- `docs/OPERATIONS.md` — serial, resize, GPU, audio, Wi-Fi, updates
- `docs/DEVELOPMENT.md` — Docker, defconfigs, package policy
- `docs/UPSTREAMS.md` — where emulator and hardware facts come from
- `docs/LOGBOOK.md` — chronology

These two files are kept because they still contain session-specific warnings, SHA pins, and measurements that are not all copied into the canonical docs. They also contain workstation paths and a "still open" list that has gone stale (for example the U-Boot delay line).

They are never normative. They may still say, in the present tense, things that were true when they were written and are not current policy: architecture, which repository has which role, what counts as a source of truth, and what was implemented or still open. The current authority model is in `docs/ARCHITECTURE.md` and `docs/UPSTREAMS.md`.

`TODO.md` stays gitignored under `NOTES/`.

`roadmap-phase-3c.md` is the Phase 3C integration log, moved unchanged from `docs/ROADMAP.md` on 2026-10-14. The roadmap keeps the acceptance note.

`roadmap-2026-10-15.md` is the active roadmap as it stood at `b926b9976c12ccdb3de20b629f8a550e574f8e51`, moved on 2026-10-15. The body was not rewritten except four relative links retargeted for `docs/archive/`.

`roadmap-2026-11-17.md` is the active roadmap as it stood at `8d61d33d263434de4cd4e5f5f6200becd3756908`, Git blob `bafdc503836eac0b4355b53691bf024162a1d340`, SHA-256 `2a0758db17af6876d63c409e26d4cdfa0b997aa2331fe92fe5de48f6a911b4b7`. The body was not rewritten except relative links retargeted for `docs/archive/`. It is not current policy. The current sequence is `docs/ROADMAP.md`.
