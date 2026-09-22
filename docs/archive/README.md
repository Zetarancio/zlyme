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
