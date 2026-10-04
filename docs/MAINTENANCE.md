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
| Which source is the hardware authority | `docs/UPSTREAMS.md` |
| Pinned Buildroot, Linux, U-Boot, BL31; compiler `-O2` pins | `docs/DEVELOPMENT.md` |
| Governor CPU floors (SpruceOS-derived) | `docs/UPSTREAMS.md`, `docs/DEVICE_PORTING.md` |
| How docs, the README, and the changelog are written | `docs/WRITING.md` |
| How a person starts contributing | `CONTRIBUTING.md` |
| What changed in each release, for users | `CHANGELOG.md` |
| Which phase is active | `docs/ROADMAP.md` |
| Why a past choice was made | `docs/decisions/` and `docs/research/` |

The accepted Phase 9 runtime is `337ccbce2587393463a4b49c551f94e33e318e44` (`zlyme44`). A later documentation commit does not replace that SHA. Its acceptance record is in `docs/ROADMAP.md`.

## Kernel and board patches

1. Name the Linux version this tree builds before comparing anything else (`docs/DEVELOPMENT.md`, Pinned baseline).
2. Check upstream Linux for that behavior.
3. Then look at official ROCKNIX `next` RK3566 work at a pinned commit.
4. Hardware facts come from `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`.
5. `Zetarancio/distribution` is archived ROCKNIX evidence. Do not treat it as the current tree.

Classify every local or borrowed patch as upstream, backport, board-specific, still required, or obsolete. Keep provenance and authorship. A hardware-facing change needs hardware revalidation. `docs/UPSTREAMS.md` and `docs/DEVICE_PORTING.md` own the rest.

## Emulator, core, and package updates

The project's own upstream is the version and source authority. Active KNULLI and ROCKNIX recipes are packaging references. Compare version, dependencies, options, patches, and license. Do not import another distribution's integration because the recipe exists.

Keep Zlyme's direct KMS, input, audio, and storage contracts. Build the package by itself before a full image. Hardware smoke is for a runtime change, not for a comment or a pin that does not change behavior. Procedure: `docs/UPSTREAMS.md`. Build mechanics: `docs/DEVELOPMENT.md`.

## Vendored helpers

`minui-list` 0.15.2 and `minui-presenter` 0.13.2 are vendored snapshots. Repository, tag, commit, and license are recorded in `package/system/minui-list/UPSTREAM` and `package/system/minui-presenter/UPSTREAM`. parson `ec53fb65` is the JSON helper vendored beside minui-list because upstream gitignores the directory the compiler includes. Stay on those recorded commits until a review says otherwise. Do not comment that vendored source for style.

ZcrapeGoat is not a patch stack and not a submodule. `package/system/zcrapegoat/src` is a pristine upstream v2.3.0 import, then ordinary Zlyme commits. A later update imports a new pinned revision. Do not follow upstream HEAD. Record: `package/system/zcrapegoat/src/UPSTREAM` and `docs/UPSTREAMS.md`.

## NextUI fork

`Zetarancio/NextUI` is the fork. Buildroot pins one commit on branch `zlyme` (`NEXTUI_VERSION` in `package/system/nextui/nextui.mk`). Review LoveRetro changes deliberately. Do not rebase the fork onto upstream HEAD to look current. Keep other-platform source in the fork. Hardware equivalence is required when runtime behavior changes, not for a documentation-only pin note.

## Releases

This section owns the release and delta policy. The code is `scripts/zlyme_release.py` and `scripts/make-release-deltas.py`.

- `zlymeNN` is a baseline: a full OTA and a manifest with zero deltas. `zlymeNN.0` is not a version.
- A point release `zlymeNN.M` builds deltas from the same-major baseline and from up to the last three earlier point releases of that major. A base must publish a manifest whose full OTA and root hashes verify. Other majors are never bases.
- Each delta is round-trip verified. A delta at or above 70% of the full OTA size is not published.
- Settings picks the smallest delta whose `from_sha256` exactly matches the installed `/boot/zlyme` SHA-256, otherwise the full OTA. The displayed version string does not select anything.

`./build.sh` writes a full OTA only. The GitHub release job writes `release-manifest.json` and any deltas. The clean GitHub `Build` from the accepted implementation SHA is the release artifact. Release notes describe accepted user behavior, not this log. They match the `CHANGELOG.md` entry, under the rules in `docs/WRITING.md`. Architecture of the apply path is in `docs/ARCHITECTURE.md`. The device runbook is in `docs/OPERATIONS.md`.

Published `zlyme44` is `zlyme-37164297221`, built by run `37164297221` from `337ccbce2587393463a4b49c551f94e33e318e44`, with zero deltas. Its root differs from the locally accepted image because the build dates differ (`docs/DEVELOPMENT.md`, Release artifacts).

The installer is a separate repository, `Zetarancio/zlymeOS-Installer`, branch `zlyme-installer`. Build All Platforms moves only the reused `beta-zlyme-installer` tag to the commit it builds, and the platform builds refuse to upload a different commit. Create Latest Release targets that exact commit. Later commits may touch only Markdown or the release workflow. The first normal release, `V1.8.0`, predates that fix. Its tag is at `678f6440f1409dbf0e824fb4e3d6d4a1499d23c0`, and its binaries were built at `b33d31b42b3726305724e7b59c3b397d1bdc6edd`. Between those commits only the README and the release workflow changed.

## Open validation debt

Every Phase 10 finding `(a)` through `(q)` is triaged in `docs/research/documentation-audit-phase10.md` ("Finding triage"). This section is that index. It is not a shorter substitute. Before a change touches one of these paths, read that entry first. Hardware-facing items still need a real Flip when the audit says so. None of the source fixes below are in `zlyme44`.

Decided, not shipped:

- **(c) Suspend RTC timer.** `zlyme44` clears `/sys/class/rtc/rtc0/wakealarm` and then writes `+86400` before every `mem`. That alarm management came from timed suspend testing. No Miyoo Flip 24-hour sleep limit is documented. `zlyme44.1` removes all of it from the production suspend helper: the helper does not read, clear, or replace `rtc0/wakealarm`, and an alarm programmed by the user or another program is preserved. RTC support stays enabled, and RTC wake remains a valid hardware wake source. `package/system/nextui/zlyme/suspend` on `zlyme44` still programs the timer. `CHANGELOG.md` states that as shipped `zlyme44` behavior. This documentation branch does not change `suspend`.

Still open:

- **(a)** `zlyme-update uboot` writes to the parent disk of the first `uboot` partition it finds. It does not prove that disk holds the live `/boot`.
- **(b)** For the early splash, the initramfs mounts `mmcblk0p2` or `mmcblk1p2` without a label check, then skips the `LABEL=ZLYMEBOOT` search.
- **(d)** The minimal defconfig, which `build.sh` uses by default, does not select the gamepad module or `zlyme-keylidmon`, and `post-build.sh` requires both. It is expected to fail. It was not built.
- **(e)** `zlyme-boot-write` treats any live PID marker as a nested owner. Overlapping writers are not excluded.
- **(f)** `S27led` runs `zlyme-ctl apply-gov` after the first frame, so a game started in that window can be reset to Smart. The same apply runs again after an OTA boot.
- **(g)** Several local compiled packages are outside the `build.sh` source fingerprints (`docs/DEVELOPMENT.md`, Source fingerprints).
- **(h)** `post-image.sh` treats a failed OTA pack as non-fatal, so the image build can succeed without an OTA.
- **(i)** The LED watcher polls every 2 seconds. No wakeup cost has been measured.
- **(j)** The DTS enables UHS modes on SD slot 2. The hardware wiki records UHS removed from slot 2 because both slots share the I/O-voltage rail.
- **(k)** `package/system/mergerfs` is dormant but still selectable.
- **(l)** `board.mk` copies unused foreign `dts-overrides` into the kernel tree.
- **(m)** Literal `my355` remains in several generic-looking paths. It matters when a second device exists.
- **(n)** Boot timing and NextUI emergency snapshots are copied to the card even when system logs are off.
- **(o)** The GHCR builder image is built without the `zlyme.dockerfile` digest label that `build.sh` checks.
- **(p)** Seeded `boost` and `merge` state remains after those settings were removed.
- **(q)** `portmaster-launch` sleeps 0.4 s, and `S15bootpart` prefers `/dev/mmcblk0p3` over `LABEL=ZLYME`. The PortMaster delay stays until its readiness condition is known. The partition preference is still open.
- **Provenance.** `rtl8733bu_power.c` declares `MODULE_AUTHOR("ROCKNIX")`, while its `LICENSE` calls the driver original Zlyme source. That pair is false; the correction belongs with the driver metadata, not in `zlyme44`.
