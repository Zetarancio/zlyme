# Upstream and package-update policy

This document tells an agent how to research package/emulator updates without blindly copying another distribution.

## Source hierarchy

Different sources answer different questions.

### Emulator/core version and source behavior

Primary authority:

```text
the emulator/core's own upstream repository and release history
```

Use this to establish:
- latest stable release/tag;
- supported build options;
- dependency changes;
- license changes;
- relevant upstream fixes.

### Buildroot packaging patterns for handhelds

Strong references:

```text
KNULLI
ROCKNIX
upstream Buildroot
```

Use them to learn:
- known-good commits;
- handheld-specific patches;
- cross-compilation flags;
- dependencies;
- ARM64 quirks;
- KMS/DRM/Wayland options;
- controller/audio fixes.

Do not assume their architecture is Zlyme's architecture.

### Miyoo Flip hardware

Authority:

```text
Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering
current known-good Zlyme behavior for implementation state
primary evidence cited by the device wiki
```

The device wiki is distribution-independent after its documentation refactor. Treat its hardware/firmware conclusions as the canonical device reference.

`Zetarancio/distribution` is archived. It remains useful historical evidence for known-working Miyoo Flip kernel/DTS/driver solutions, but it is not current project state and must not be maintained or synchronized.

Do not take board facts from KNULLI or another RK3566 handheld simply because the SoC is similar.

## Current KNULLI repository

Use the active repository:

```text
https://github.com/knulli-cfw/knulli-linux
```

The older `knulli-cfw/distribution` repository was archived in 2026.

If a local checkout is available, prefer it for fast searching, but do not encode a developer-specific absolute path as the only source.

## ROCKNIX repositories

External upstream reference:

```text
https://github.com/ROCKNIX/distribution
```

Use official ROCKNIX for generic RK3566, kernel, driver, emulator, and packaging comparisons when relevant.

Historical Miyoo Flip implementation evidence:

```text
https://github.com/Zetarancio/distribution
```

That fork is archived. Consult it only when a historical implementation detail or commit is relevant, preferably through provenance recorded by the device wiki. Do not infer current Zlyme state from it.

## Package update workflow

When asked to update an emulator/core/package:

### 1. Establish current Zlyme state

Report:
- current Zlyme version/commit;
- current patches;
- current dependencies;
- current build flags;
- current license metadata.

### 2. Determine current upstream release

Check the project's own upstream.

Do not infer "latest" from KNULLI or ROCKNIX.

### 3. Inspect KNULLI and ROCKNIX

Search both for the same package.

Compare:
- version/commit;
- package recipe;
- patches;
- CMake/Meson options;
- dependencies;
- architecture-specific changes.

If one distribution has a newer recipe, that does not automatically make it correct for Zlyme.

### 4. Classify every borrowed patch

For each patch say:

```text
needed by Zlyme
not needed
already upstream
distribution-specific
unknown — requires test
```

Do not copy a patch stack wholesale.

### 5. Preserve Zlyme constraints

Normal Zlyme assumptions include:

- AArch64 / Cortex-A55;
- direct DRM/KMS where supported;
- no permanent X11/Wayland stack;
- ALSA/BlueALSA policy;
- Buildroot cross compilation;
- curated emulator choices;
- no hidden runtime package manager;
- reproducible pinned source.

Do not enable desktop dependencies merely because another distro does.

### 6. Update reproducibility metadata

Update as applicable:
- version;
- source URL;
- hash;
- license;
- license file hash;
- dependencies;
- patches.

### 7. Build narrowly first

Prefer:

```text
package rebuild
```

before a full image.

Then perform the relevant runtime smoke test.

### 8. Report before/after

An agent should summarize:

```text
Zlyme old -> new
upstream latest
KNULLI version
ROCKNIX version
patches added/removed
dependency changes
validation performed
hardware testing still required
```

## Compared revisions

These are the trees Phase 0 checked, not a promise to track them. Local clone paths are not part of the contract; the remotes are.

| Role | Remote | Revision seen |
| --- | --- | --- |
| Hardware wiki | `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` | `b08e335` |
| Archived ROCKNIX fork | `Zetarancio/distribution` (`flip`) | `d249b09bd9` |
| SpruceOS | `spruceUI/spruceOS` | `90a10ed1a` |
| NextUI | `LoveRetro/NextUI` | `ae652648` |
| BaseOS | `apommel/baseos-my355` | `85b67b4` |
| KNULLI | `knulli-cfw/knulli-linux` | `0b1fd94` |

The longer comparison notes, including which tip each clone was behind, stay in `docs/archive/NOTES.md`.

## Safe agent request

A maintainer can ask:

> Check whether `<package>` has a newer stable upstream version. Compare Zlyme's current recipe with the active KNULLI `knulli-linux` repository and ROCKNIX `distribution`. Do not modify anything yet. Report versions, relevant patches, build-option changes, license changes, and what you would update in Zlyme.

Then, after reviewing the report:

> Apply the `<package>` update following `AGENTS.md`, `docs/ENGINEERING_PRINCIPLES.md`, and `docs/UPSTREAMS.md`. Preserve Zlyme's direct-KMS/ALSA architecture and do not import unrelated distro integration.

This two-step workflow is safer than telling an agent to "update everything".
