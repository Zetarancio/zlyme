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

Every Phase 10 finding `(a)` through `(q)` is triaged in `docs/research/documentation-audit-phase10.md` ("Finding triage" and "zlyme44.1 maintenance dispositions"). This section is that index. It is not a shorter substitute. Before a change touches one of these paths, read the original finding first. Published `zlyme44` (`337ccbce2587393463a4b49c551f94e33e318e44`) still has the source the original findings describe. The fixes below are on `zlyme44.1-maintenance`. They are not published, and none of them has been accepted on a Flip yet.

Fixed in source on `zlyme44.1-maintenance`:

- **(a)** `zlyme-update uboot` resolves the disk that backs `/boot`, requires exactly one `uboot` partition on that disk, and checks the 8 MiB / LBA 16384 geometry before any raw write. It refuses an ambiguous or unprovable target. `ZLYME_UPDATE_TEST=1 uboot-target` reports the choice and does not write.
- **(b)** The initramfs mounts `LABEL=<expected boot label>` only. The splash starts from the still in the ramdisk and picks up the boot-volume animation after that mount.
- **(c)** The suspend helper does not read, clear, or replace `/sys/class/rtc/rtc0/wakealarm`. `zlyme44` still clears that node and writes `+86400`. No Miyoo Flip 24-hour sleep limit is documented. An alarm programmed by the user or another program is preserved. The `zlyme44` changelog line stays the description of the published helper.
- **(d)** `post-build.sh` requires the gamepad module, `zlyme-keylidmon`, firmware, ssh, jackd, and the NextUI pak stamp only when the active config selects them. A minimal config that builds Mesa Panfrost and does not select the Mali stack drops the panfrost blacklist. The minimal image remains the bring-up target.
- **(e)** `zlyme-boot-write` takes an atomic `mkdir` lock. A descendant of the owner shares the remount. An unrelated caller waits or fails. The owner remounts `/boot` read-only on the way out.
- **(f)** `nextui-session` applies Smart before each `nextui.elf` start. A late DMC probe and `zlyme-update reapply` call `resume`. `S27led` only drives the LEDs. In a pak, `zlyme-keylidmon` sets Idle around mem and then resumes the pak profile.
- **(g)** Every `SITE_METHOD = local` package is in the `build.sh` fingerprint list, or named with a rationale in `scripts/tests/fingerprint-exceptions.txt`. There are no exceptions.
- **(h)** A failed OTA pack fails the product image. `ZLYME_SKIP_OTA=1` is the only skip, and no supported defconfig sets it.
- **(j)** `&sdmmc1` keeps `cap-sd-highspeed` and has no `sd-uhs-*` properties. `&sdmmc0` is unchanged. Both-slot Flip checks are still required. The wiki's shared-rail warning stays.
- **(k)** The mergerfs package is gone. Historical ROADMAP and LOGBOOK text stays.
- **(l)** `board.mk` no longer copies `dts-overrides`. The foreign DTS files are gone. A clean kernel extract is the proof that nothing still includes them.
- **(o)** `.github/workflows/docker-image.yml` labels `zlyme-build:latest` with `zlyme.dockerfile` set to the SHA-256 of `Dockerfile`, the same value `build.sh` checks.
- **(p)** `S15bootpart` does not seed `boost` or `merge`. `zlyme-ctl` ignores those names and deletes leftover files. Settings reset still deletes them. `zlyme-storage merge` remains a library-list refresh.
- **Provenance.** `rtl8733bu-power` is credited to Zetarancio, archived fork `fbd8dd1545309950b0e13a495c659501549a957c` (2026-02-26), under GPL-2.0-only. It is not described as original Zlyme source or as an official ROCKNIX driver.

Deferred. These are not part of `zlyme44.1`:

- **(i)** The LED watcher still polls every 2 seconds. Change it only after measuring the cost.
- **(m)** Literal `my355` in generic-looking paths matters when a second device exists.
- **(n)** Boot-timing and NextUI emergency snapshots are still copied when system logs are off. That is a deliberate diagnostic tradeoff.
- **(q)** PortMaster's `sleep 0.4` stays until the readiness condition it covers is known. `S15bootpart` preferring `/dev/mmcblk0p3` over `LABEL=ZLYME` is still open.
