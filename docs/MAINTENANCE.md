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

`./build.sh` writes a full OTA only. A GitHub `Build` dispatch can produce that same kind of clean candidate and upload the stage artifacts without publishing a release. The `publish_release` input defaults to false. Setting it true runs the release job, which writes `release-manifest.json` and any deltas and publishes the stable/latest release (`prerelease: false`, `make_latest: true`). A clean build candidate is not hardware acceptance. Only an explicitly published, validated release is the public stable/latest release. Release notes describe accepted user behavior, not this log. They match the `CHANGELOG.md` entry, under the rules in `docs/WRITING.md`. Architecture of the apply path is in `docs/ARCHITECTURE.md`. The device runbook is in `docs/OPERATIONS.md`.

Published `zlyme44` is `zlyme-37164297221`, built by run `37164297221` from `337ccbce2587393463a4b49c551f94e33e318e44`, with zero deltas. Its root differs from the locally accepted image because the build dates differ (`docs/DEVELOPMENT.md`, Release artifacts).

The installer is a separate repository, `Zetarancio/zlymeOS-Installer`, branch `zlyme-installer`. Build All Platforms moves only the reused `beta-zlyme-installer` tag to the commit it builds, and the platform builds refuse to upload a different commit. Create Latest Release targets that exact commit. Later commits may touch only Markdown or the release workflow. The first normal release, `V1.8.0`, predates that fix. Its tag is at `678f6440f1409dbf0e824fb4e3d6d4a1499d23c0`, and its binaries were built at `b33d31b42b3726305724e7b59c3b397d1bdc6edd`. Between those commits only the README and the release workflow changed.

## Open validation debt

Every Phase 10 finding `(a)` through `(q)` is triaged in `docs/research/documentation-audit-phase10.md` ("Finding triage" and "zlyme44.1 maintenance dispositions"). This section is that index. It is not a shorter substitute. Before a change touches one of these paths, read the original finding first. Published `zlyme44` (`337ccbce2587393463a4b49c551f94e33e318e44`) still has the source the original findings describe. The fixes below are in the `zlyme44.1` source at `6a398b311310246ef6a5515ed72805c6f58d787d`. That SHA was developed on `zlyme44.1-maintenance`, which stays there as the frozen release-source branch. The maintainer device-accepted that runtime. `zlyme44.1` is not published. GitHub Actions run `37375071442` is the clean-build and publication gate. Deferred items `(i)`, `(m)`, `(n)`, and `(q)` are not Phase 10 blockers.

Fixed in the `zlyme44.1` source:

- **(a)** `zlyme-update uboot` resolves the disk that backs `/boot`, requires that mount to be `ZLYME_BOOT_DEVICE` on `ZLYME_OS_DISK`, requires exactly one `uboot` partition on that disk, checks the 8 MiB / LBA 16384 geometry, and refuses a disk whose logical block size is not 512 bytes. `ZLYME_UPDATE_TEST=1 uboot-target` reports the choice and does not write. On the Flip that command resolved `/dev/mmcblk0`, partition `mmcblk0p1`, LBA 16384. The installed idbloader and U-Boot FIT bytes matched the local artifacts. Raw `zlyme-update uboot` was not run and is not required for release acceptance.
- **(b)** The initramfs mounts `ZLYME_BOOT_DEVICE` and `ZLYME_STORAGE_DEVICE` after each node's label matches. It does not search by label and does not substitute the second card. The splash starts from the still in the ramdisk and picks up the boot-volume animation after the boot FAT mounts. On the Flip, `/boot` stayed `/dev/mmcblk0p2` and `/storage` stayed `/dev/mmcblk0p3`. A real secondary card appeared as `mmcblk1`. A reboot with both cards kept primary-card ownership. A duplicate-label card was not manufactured. The fail-closed source and host tests cover that case.
- **(c)** The installed suspend helper is `sync`, write `mem` to `/sys/power/state`, and `exit`. It does not read, clear, or replace `/sys/class/rtc/rtc0/wakealarm`. Prior deep-suspend hardware acceptance remains the suspend evidence. No new 24-hour suspend test was required. Published `zlyme44` still clears that node and writes `+86400`. The `zlyme44` changelog line stays the description of the published helper.
- **(d)** `post-build.sh` requires the gamepad module, `zlyme-keylidmon`, firmware, ssh, jackd, and the NextUI pak stamp only when the active config selects them. A minimal config that builds Mesa Panfrost and does not select the Mali stack drops the panfrost blacklist. The minimal image remains a developer and bring-up target. A separate minimal-image build is not a `zlyme44.1` release gate. This closure does not claim a completed minimal image.
- **(e)** `zlyme-boot-write` holds an exclusive `flock` for one transaction. It does not share that transaction with a nested call. The helper returns the wrapped command's status when `/boot` is read-only again. If that remount fails, a `/run` marker refuses later writes until reboot. It also refuses a mount whose source is not `ZLYME_BOOT_DEVICE`, and it restores read-only before opening the volume. Catchable signals do not abort the write. On the Flip, a disposable sentinel was created and then removed. `/boot` returned read-only after both operations. No poison marker appeared.
- **(f)** `nextui-session` applies Smart before each `nextui.elf` start. A late DMC probe and `zlyme-update reapply` call `resume`. `S27led` only drives the LEDs. In a pak, `zlyme-keylidmon` sets Idle around mem and then resumes the pak profile. The governor holds an exclusive `flock` for that apply and reads the saved profile in the same process. Frequency policy is unchanged. On the Flip, `resume` passed, Smart stayed selected, and the lock was released. CPU, GPU, and DMC policy stayed on that profile.
- **(g)** Every `SITE_METHOD = local` package is in the `build.sh` fingerprint list, or named with a rationale in `scripts/tests/fingerprint-exceptions.txt`. There are no exceptions.
- **(h)** A failed OTA pack fails the product image, removes that invocation's `zlyme.img`, and does not leave a partial versioned tar or checksum. `ZLYME_SKIP_OTA=1` is the only skip, and no supported defconfig sets it. The local `zlyme44.1 (2026-10-05)` product image built successfully. The expected OTA artifacts were present, and no partial artifact remained. The installed root SHA-256 is `9e4f8a772b04e937a87b92ed4ffd5e950b756bcbcf0beda55c1b7b0744058b65`.
- **(j)** `&sdmmc1` keeps `cap-sd-highspeed` and has no `sd-uhs-*` properties. `&sdmmc0` still requests SDR12, SDR25, SDR50, and SDR104. Both slots share `vccio_sd`. On the Flip, a real second card enumerated as `mmcblk1` at SD high-speed, 50 MHz, and did not negotiate UHS. The primary slot stayed SDR104. A hot insertion while the primary slot was already at 1.8 V left the second slot in high-speed; that sample's debugfs signal voltage read 1.80 V because the shared rail was already there, and the primary slot did not reset or report I/O errors. The following boot reported high-speed at 50 MHz and 3.30 V. Both-card reboot passed. The card mounted at `/mnt/sd2`, and `/run/zlyme/libraries` listed `/storage` and `/mnt/sd2`. The wiki was not edited.
- **(k)** The mergerfs package is gone. Historical ROADMAP and LOGBOOK text stays.
- **(l)** `board.mk` no longer copies `dts-overrides`. The foreign DTS files are gone. A targeted clean Linux rebuild left only the upstream copies in the Linux source tree.
- **(o)** `.github/workflows/docker-image.yml` labels `zlyme-build:latest` with `zlyme.dockerfile` set to the SHA-256 of `Dockerfile`, the same value `build.sh` checks.
- **(p)** `S15bootpart` does not seed `boost` or `merge`. `zlyme-ctl` ignores those names and deletes leftover files. Settings reset still deletes them. `zlyme-storage merge` remains a library-list refresh.
- **Provenance.** `rtl8733bu-power` is credited to Zetarancio, archived fork `fbd8dd1545309950b0e13a495c659501549a957c` (2026-02-26), under GPL-2.0-only. It is not described as original Zlyme source or as an official ROCKNIX driver.

Deferred. These are not part of `zlyme44.1` and are not Phase 10 blockers:

- **(i)** The LED watcher still polls every 2 seconds. Change it only after measuring the cost.
- **(m)** Literal `my355` in generic-looking paths matters when a second device exists.
- **(n)** Boot-timing and NextUI emergency snapshots are still copied when system logs are off. That is a deliberate diagnostic tradeoff.
- **(q)** PortMaster's `sleep 0.4` stays until the readiness condition it covers is known. `S15bootpart` and `S13resize` use `ZLYME_STORAGE_DEVICE` and do not fall back to another `ZLYME` label. Implemented and host-tested. Flip validation of that path is deferred and is not a `zlyme44.1` gate.
