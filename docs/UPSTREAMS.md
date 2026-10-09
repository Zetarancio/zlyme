# Upstream and package-update policy

This document tells an agent how to research package/emulator updates without blindly copying another distribution. The short index is `docs/MAINTENANCE.md`.

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

For an upstream without releases, a commit that ROCKNIX or KNULLI already carries may be chosen. Record both the upstream commit and the distribution revision that carries it. gpSP is the current example (see Compared revisions).

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

This document owns the hardware-authority model. Other documents link here.

| Source | Role |
| --- | --- |
| `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` (the device wiki) and the primary evidence it cites | Hardware and firmware authority |
| This Zlyme repository | Authority for current implementation state |
| Upstream Linux for the selected kernel | Whether kernel behavior is upstream, backported, changed, or obsolete |
| Official ROCKNIX (`next`) | Comparison evidence for RK3566 kernel, DTS, and driver work |
| `Zetarancio/distribution` | Historical evidence only |
| KNULLI | Not a hardware source |

The device wiki is distribution-independent after its documentation refactor. Treat its hardware/firmware conclusions as the canonical device reference.

`Zetarancio/distribution` is archived. It remains useful historical evidence for known-working Miyoo Flip kernel/DTS/driver solutions, but it is not current project state and must not be maintained or synchronized.

Do not take board facts from KNULLI or another RK3566 handheld simply because the SoC is similar.

### Policy data from another distribution

`zlyme-governor emu <tag>` uses the per-system `scaling_min_freq` values from SpruceOS `2b7bc4a79359de14ea4d4f00da9801a937e2846d` (`Emu/*/config.json`). Each value is resolved to the lowest my355 OPP at or above it. That table is the only thing taken from SpruceOS. Do not copy Spruce's governor, core layout, or DMC policy.

## KNULLI repository

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

Use official ROCKNIX for generic RK3566, kernel, driver, emulator, and packaging comparisons when relevant. Use its `next` branch and pin the commit you compared.

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

## Unspecified vendor binaries

Some artifacts have no usable license text. An unknown license does not grant redistribution. Zlyme ships one only when the maintainer has accepted that specific file and the provenance record can stand on its own.

All of the following are required:

- the maintainer explicitly chose to redistribute that artifact;
- the exact bytes or build are identified;
- origin and provenance are documented;
- SHA-256 is recorded where practical;
- whether the file is unmodified or modified is explicit;
- its purpose is documented;
- package metadata uses a `LicenseRef-...-unspecified` identifier rather than MIT, GPL, or another known license;
- the provenance record says that it is not a license grant and that redistribution rights are unverified;
- the exception is artifact-specific.

Without meaningful provenance, do not ship the file. Accepted wording: `Redistribution status: maintainer-approved as-is; upstream/vendor license unspecified.` That sentence is a Zlyme distribution decision, not a legal conclusion.

The current exception is `package/system/zlyme-preloader/preloader-stock.img`.

| Field | Record |
| --- | --- |
| Bytes | unmodified 2 MiB image, SHA-256 `dfdd7d20d6fd3beb18350dcf8fa58740b40b4baaf39467d45076f949053a2922` |
| Origin | hardware wiki `preloader-stock-rocknix/App/apommel-multiboot/preloader-stock.img`, introducing commit `8ef495f5711ce13645e9c68df63b7d7a9934cf7e`, recorded again at wiki commit `c126d3235face9ddca5bf021258a84758dca543c` |
| Purpose | Zlyme-side restore of that one stock revision, and only when the live preloader is its paired apommel image and the DDR payloads match |
| Metadata | `LicenseRef-Miyoo-vendor-preloader-unspecified` beside MIT for the script and checker |
| Record | `preloader-stock.PROVENANCE`, which includes `This record is not a license grant.` |

The stock-side helper images `miyoo355_fw.img`, `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img` are generated from pinned `apommel/baseos-my355` `e09d37bb0f03c34e564d61bd02164f332d8515a8` plus Zlyme scripts. They are MIT. They do not contain `preloader-stock.img` or any other preloader binary.

## Compared revisions

These are recorded comparisons, not a promise to track any tree. Local clone paths are not part of the contract; the remotes are.

### Revisions current code depends on

| Role | Remote | Revision | Used for |
| --- | --- | --- | --- |
| Stock preloader installer | `apommel/baseos-my355` | `e09d37bb0f03c34e564d61bd02164f332d8515a8` | `MY355_FW_INSTALLER_VERSION`. MIT. `mkfwimg.py` writes `miyoo355_fw.img`. `pack-fwimg.py` writes `miyoo355_fw-maskrom.img` and `miyoo355_fw-restore.img` in the same container. `miyoo355_fw-multiboot.img` is a copy of `miyoo355_fw.img`. `post-image.sh` writes a `.sha256` for each. The Build workflow uploads all four images and their checksums. A fresh card receives only `miyoo355_fw.img`. The OTA receives none. To bump: review the upstream diff, change the pin and `.hash`, rebuild, compare `miyoo355_fw.img`, rerun `scripts/tests/test_fw_helpers.sh` and `scripts/tests/test_phase11c.sh`. Do not track `main` |
| NextUI fork | `Zetarancio/NextUI` | `cf4a16ccbb54320af963a796b173ab8b77e25017` | `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`. Branch `zlyme44.2-portmaster-writable` puts Reset PortMaster on Game. A verified Recovery write offers shutdown or restart and does not write again in that Settings session. The selected description sits above the hint pills |
| PortMaster | `PortsMaster/PortMaster-GUI` | `2026.06.23-0015` | `PORTMASTER_VERSION`. Stable channel. SHA-256 `772f2d56fc1abfbf79a3404ca78f240776c81c5a5b92786a0a748ae554339b7b` in `portmaster.hash`. The image ships the zip as a seed. ROCKNIX `next` at `5e81daa9748b5139eaca899578da43c4e10e8724` was compared for the unpack-on-storage pattern and is not the version authority |
| NextUI base | `LoveRetro/NextUI` | `ae652648548edf6ab24cbb816cf4e4194e609fb3` | `UPSTREAM` file inside the fork pin |
| OpenBOR | `DCurrent/openbor` | `v7533` | `OPENBOR_VERSION`. Directory overrides are `package/emulators/openbor/0003-runtime-directories.patch` |
| mkxp-z | `white-axe/mkxp-z` | `650cb0888a07d0b5044e131160ddfa53feaf595b` | `LIBRETRO_MKXP_Z_VERSION`. One wrapper directory is `0001-one-wrapper-archive-root.patch` |
| Wine | `Kron4ek/Wine-Builds` | `11.6` asset `wine-11.6-amd64-wow64.tar.xz` | SHA-256 `045549657b513c2fb191734b0434c81000b36ba4d482d1688bf99f80a8ee07a5` in `wine-amd64.hash`. Vanilla `amd64-wow64`, not staging |
| Box64 | `ptitSeb/box64` | `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` (v0.4.4) | `BOX64_VERSION`. `BOX32=OFF` |
| ROCKNIX | `ROCKNIX/distribution` `next` | `a55d58a1209b35e287dd55a3aad67a5543b467ce` | carries gpSP `8d268a6bb2cd799f8f2791ebb544a7ef550cfc6f`, the `package/emulators/libretro-gpsp` pin |
| KNULLI | `knulli-cfw/knulli-linux` `knulli-main` | `6a23957a19a1df18989ac6aa5e9fff003ae611ed` | carries the older gpSP `d6decfa3`; compared, not adopted |
| SpruceOS | `spruceUI/spruceOS` | `2b7bc4a79359de14ea4d4f00da9801a937e2846d` | CPU floor table in `package/system/nextui/zlyme/governor.sh` |
| ROCKNIX | `ROCKNIX/distribution` | `fe127fad01f6006bea1734ebde87d1c02cc6d256` | RK817 patch `001`, applied as local `0003`; `002`, `005`, `008` not adopted |

The gpSP comparison is in `docs/research/product-phase9.md`. The RK817 dispositions are in `docs/research/kernel-patch-audit-phase5.md` and `docs/research/deep-suspend-phase6.md`. ZcrapeGoat's import is recorded below.

### Phase 0 comparison snapshot

| Role | Remote | Revision seen |
| --- | --- | --- |
| Hardware wiki | `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` | `b08e335` |
| Archived ROCKNIX fork | `Zetarancio/distribution` (`flip`) | `d249b09bd9` |
| SpruceOS | `spruceUI/spruceOS` | `90a10ed1a` |
| NextUI | `LoveRetro/NextUI` | `ae652648` |
| BaseOS | `apommel/baseos-my355` | `85b67b4` |
| KNULLI | `knulli-cfw/knulli-linux` | `0b1fd94` |

The SpruceOS row is the Phase 0 snapshot. The governor table uses `2b7bc4a` above. The longer Phase 0 notes, including which tip each clone was behind, stay in `docs/archive/NOTES.md`.

## Safe agent request

A maintainer can ask:

> Check whether `<package>` has a newer stable upstream version. Compare Zlyme's current recipe with the active KNULLI `knulli-linux` repository and ROCKNIX `distribution`. Do not modify anything yet. Report versions, relevant patches, build-option changes, license changes, and what you would update in Zlyme.

Then, after reviewing the report:

> Apply the `<package>` update following `AGENTS.md`, `docs/ENGINEERING_PRINCIPLES.md`, and `docs/UPSTREAMS.md`. Preserve Zlyme's direct-KMS/ALSA architecture and do not import unrelated distro integration.

This two-step workflow is safer than telling an agent to "update everything".

## ZcrapeGoat

Vendored source, not a git submodule and not a patch stack.

```text
upstream: https://github.com/Helaas/nextui-scrapegoat-pak
tag: v2.3.0
commit: c52f749eae21a4c02c767e485fef2abbb773f2d7
license: MIT
tree: package/system/zcrapegoat/src
record: package/system/zcrapegoat/src/UPSTREAM
```

Zlyme modifications after that import are ordinary commits in this repository. A later update compares a new pinned upstream revision with this tree and imports that revision. Do not follow upstream HEAD.
