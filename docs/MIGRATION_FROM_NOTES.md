# Migration from `NOTES/`

Applied. The moves below have landed. `NOTES/NOTES.md` and `NOTES/PLAN.md` were not deleted: they still mix live-session status, workstation paths, and measurements, so they live in `docs/archive/`. Canonical behavior is `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md`, and `docs/DEVELOPMENT.md`. Do not treat the archive "still open" list as current.

## Goal

Replace the catch-all `NOTES/` directory with documents that have one clear responsibility, without losing hard-earned engineering facts.

Do not delete the notes first.

## Current categories

The current tree mixes:

- durable architecture and invariants;
- live-device operations/recovery facts;
- development/build policy;
- current project state;
- chronological history;
- research;
- branding-generation source.

The migration should separate these.

## Recommended moves

### Preserve history verbatim

```bash
git mv NOTES/LOGBOOK.md docs/LOGBOOK.md
```

Do not rewrite the historical entries during the structural migration except to fix path references that become invalid.

### Research

```bash
mkdir -p docs/research
git mv NOTES/EMULATORS-RESEARCH.md docs/research/emulators.md
git mv NOTES/OPTIMIZATION-RESEARCH.md docs/research/performance.md
git mv NOTES/RESEARCH-INPUTPLUMBER.md docs/research/inputplumber.md
git mv NOTES/RESEARCH-JOYPAD-DRIVER.md docs/research/joypad-driver.md
```

Research remains research even after a decision is made.

When a decision becomes stable, record the conclusion in architecture/operations and leave the experimental detail in research.

### Branding tooling

`NOTES/LOGOANIM/` contains source/tools, not notes.

Move it to a tooling location, for example:

```bash
mkdir -p tools/branding
git mv NOTES/LOGOANIM tools/branding/experimental
```

Update internal path examples/docstrings and any repository references.

Do not regenerate or modify binary assets merely because their source directory moved.

## `NOTES/NOTES.md`

Do not mechanically rename this file.

It currently contains several classes of information.

Move/extract:

### To `docs/ARCHITECTURE.md`

- stable boot model;
- storage model;
- graphics architecture;
- audio architecture;
- frontend/runtime model;
- service-class model;
- update architecture;
- durable architectural invariants.

### To `docs/OPERATIONS.md`

- serial procedure;
- first-boot resize hazards;
- recovery procedures;
- live filesystem behavior;
- device-specific mixer/card identifiers;
- Wi-Fi/BT ordering hazards;
- device cleanup/restart behavior;
- operational warnings.

### To source comments

A fact that only explains one workaround may belong next to that workaround rather than in a global document.

### To `docs/LOGBOOK.md`

Do not duplicate narrative history. The existing logbook already owns chronology.

### Local paths

Remove workstation-specific clone paths from canonical docs.

Replace them with repository names/roles.

## `NOTES/PLAN.md`

The stable parts split into:

### `docs/ARCHITECTURE.md`

- decision to use Buildroot;
- direct KMS;
- BusyBox init;
- frontend/runtime architecture;
- GPU/audio/service architecture.

### `docs/DEVELOPMENT.md`

- Docker;
- ccache;
- build commands;
- package sourcing policy;
- compiler/build policy;
- CI/development workflow;
- validation and licensing.

### Current status

Current image version, what is copied live, failing test cases, and immediate next actions should not be architecture.

Keep such information in:
- `docs/LOGBOOK.md`;
- GitHub issues;
- a short temporary developer TODO if needed.

## Safety rule

Before deleting `NOTES/NOTES.md` or `NOTES/PLAN.md`:

1. search every heading and unique warning;
2. verify each durable fact has a destination;
3. search the repository for references to `NOTES.md`, `PLAN.md`, and `NOTES/`;
4. update semantic links;
5. keep a temporary archive if any uncertainty remains.

A temporary archive is preferable to losing a hardware fact that took hours to discover.

## Update repository references

Known examples include:
- driver/package comments referencing `NOTES.md`;
- scripts/docstrings referencing `NOTES/LOGOANIM`;
- the note files referencing one another.

Prefer semantic links such as:

```text
docs/OPERATIONS.md#audio
docs/ARCHITECTURE.md#device-boundary
```

rather than unstable references such as "NOTES.md section 4".

## After migration

The desired documentation responsibilities are:

```text
AGENTS.md
  how agents must work

docs/ARCHITECTURE.md
  what Zlyme is

docs/DEVICE_PORTING.md
  how a future board plugs in

docs/DEVELOPMENT.md
  how Zlyme is built and changed

docs/OPERATIONS.md
  how the current Miyoo Flip behaves in the real world

docs/LOGBOOK.md
  how the project got here

docs/research/
  alternatives, experiments, benchmark investigations

docs/decisions/
  why major architectural choices exist
```
