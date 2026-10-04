# Maintenance

This is the maintainer index. The documents below own the detail. This page says which one to open.

| Question | Document |
| --- | --- |
| How an agent should change this tree | `AGENTS.md` |
| Design priorities | `docs/ENGINEERING_PRINCIPLES.md` |
| What the system is | `docs/ARCHITECTURE.md` |
| How a device is isolated | `docs/DEVICE_PORTING.md` |
| How to build | `docs/DEVELOPMENT.md` |
| Live device, recovery, updates | `docs/OPERATIONS.md` |
| Where a version or patch comes from | `docs/UPSTREAMS.md` |
| Which phase is active | `docs/ROADMAP.md` |
| Why a past choice was made | `docs/decisions/` and `docs/research/` |

Phase 9 runtime evidence stays `337ccbce2587393463a4b49c551f94e33e318e44`. A later documentation commit does not replace that SHA.

## Kernel and board patches

1. Name the Linux version this tree builds before comparing anything else.
2. Check upstream Linux for that behavior.
3. Then look at current official ROCKNIX RK3566 work.
4. Hardware facts come from `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`.
5. `Zetarancio/distribution` is archived ROCKNIX evidence. Do not treat it as the current tree.

Classify every local or borrowed patch as upstream, backport, board-specific, still required, or obsolete. Keep provenance and authorship. A hardware-facing change needs hardware revalidation. `docs/UPSTREAMS.md` and `docs/DEVICE_PORTING.md` own the rest.

## Emulator, core, and package updates

The project's own upstream is the version and source authority. Active KNULLI and ROCKNIX recipes are packaging references. Compare version, dependencies, options, patches, and license. Do not import another distribution's integration because the recipe exists.

Keep Zlyme's direct KMS, input, audio, and storage contracts. Build the package by itself before a full image. Hardware smoke is for a runtime change, not for a comment or a pin that does not change behavior. Procedure: `docs/UPSTREAMS.md`. Build mechanics: `docs/DEVELOPMENT.md`.

## Vendored helpers

`minui-list` 0.15.2 and `minui-presenter` 0.13.2 are vendored snapshots with recorded repository, tag, commit, and license. parson `ec53fb65` is the JSON helper vendored beside minui-list because upstream gitignores the directory the compiler includes. Stay on those recorded commits until a review says otherwise. Do not comment that vendored source for style.

ZcrapeGoat is not a patch stack and not a submodule. `package/system/zcrapegoat/src` is a pristine upstream v2.3.0 import (`c52f749eae21a4c02c767e485fef2abbb773f2d7`), then ordinary Zlyme commits. A later update imports a new pinned revision. Do not follow upstream HEAD. Record: `docs/UPSTREAMS.md`.

## NextUI fork

`Zetarancio/NextUI` is the fork. Buildroot pins one commit on branch `zlyme` (`NEXTUI_VERSION` in `package/system/nextui/nextui.mk`). Review LoveRetro changes deliberately. Do not rebase the fork onto upstream HEAD to look current. Keep other-platform source in the fork. Hardware equivalence is required when runtime behavior changes, not for a documentation-only pin note.

## Releases

`zlymeNN` is a baseline: a full OTA and a manifest with zero deltas. `zlymeNN.M` may add deltas from that same major. The installed `/boot/zlyme` SHA-256 selects a delta. The displayed version string does not. `zlymeNN.0` is not a version.

`./build.sh` writes a full OTA only. The GitHub release job writes `release-manifest.json` and any deltas. The clean GitHub `Build` from the accepted implementation SHA is the release artifact. Release notes describe accepted user behavior, not this log. Architecture of the apply path is in `docs/ARCHITECTURE.md`. The device runbook is in `docs/OPERATIONS.md`.
