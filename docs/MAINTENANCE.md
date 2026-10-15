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
| How docs, the README, the changelog, and the roadmap are written | `docs/WRITING.md` |
| How a person starts contributing | `CONTRIBUTING.md` |
| What changed in each release, for users | `CHANGELOG.md` |
| Which phase is active | `docs/ROADMAP.md` |
| Why a past choice was made | `docs/decisions/` and `docs/research/` |

Product status, kept separate:

- Historical Phase 9 acceptance is runtime `337ccbce2587393463a4b49c551f94e33e318e44` (`zlyme44`). A later documentation commit does not replace that SHA. Its acceptance record is in `docs/ROADMAP.md`.
- Published stable `zlyme44.2` is runtime `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`, tag `zlyme-38098037074`. Documentation after that SHA does not replace the published firmware.
- Development branch `zlyme44.3-phase-12` remains the working branch. Phase 12 is closed after the later 2026-10-14 correction in `docs/ROADMAP.md`. Phase 13 is not scoped and stays on this branch. `ZLYME_VERSION` is `zlyme44.3`. No `zlyme44.3` image or release has been published. The published release is still `zlyme44.2`.
- Phase 12D through the 12D-E33 reading. The installed development OTA at the start of that chain was `zlyme-my355-20261013-7951a37668e3.tar`, SHA-256 `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`. On 2026-10-14 one computer copied disposable files both ways over MTP and the checksums matched, including the mounted second card. That copy is the MTP file baseline. After the session the gadget was gone. The maintainer reports a second Start and MENU+START succeeded; the computer log does not show a second connection. That is not Phase 12 acceptance. The maintainer then installed `zlyme-my355-20261014-d4feee1e9e08.tar`, SHA-256 `0bf1e16c24c132fb6ffc98afbfb2eba5e5c7d9e7c800f3722b139102b291f5b6`, which drops the one-shot EP0 repair, and reports that USB File Transfer works. The installed squashfs matches. No new file checksum was taken on that image. The earlier archive remains the file-match rollback. The maintainer then installed `zlyme-my355-20261014-97fbcfb253c1.tar`, SHA-256 `af6a54666715b8cb41fe1c4a477a6270d04189462746550f406896b3435af95d`, which drops the USB2 PHY extcon resync, and reports that USB File Transfer works, including file copying. The installed squashfs, kernel, and DTB match that archive. Demetria logged five high-speed enumerations. No new file checksum was taken. That archive is the rollback for the next DTS experiment. The maintainer then installed `zlyme-my355-20261014-7caa0871a82f.tar`, SHA-256 `2113ee676428eeede198e9aa21a422d3dedebd1bf0112112d880f82a3e7248ea`, which removes `snps,dis_enblslpm_quirk` from the lower controller. The installed squashfs, kernel, and DTB match that archive. A stopped register read has bit 8 set. Later the same boot copied disposable files both ways over MTP and the checksums matched, including the mounted second card, with the cable left in place. B and a second Start were not pressed on that session. That is an accepted functional transfer for that fixed cable position, not a lifecycle pass and not Phase 12 acceptance. The restarts at about 17:00:49Z on 2026-10-13 and about 01:11:35Z on 2026-10-14 stay in the original records as unexplained at the time. The maintainer reports that those restarts occurred only while USB was connected and that the connector is contact-sensitive. They are suspected physical contact instability and are not a separate software release blocker. A restart without USB, or with a connection that stays seated, reopens that investigation. The 12D-E29 archive remains in `output/images`. Candidate `zlyme-my355-20261014-522e4573010a.tar`, SHA-256 `e235ca9953fcab8f0bd93ecd7f4feb2f1c3338d15a5201b06c4b8187d69d71e0`, drops the cable-loss `soft_connect` pair and is not installed. The E30 archive remains the rollback. Kernel and DTB hashes match that installed image. On 2026-10-14 a later boot, id `27b291c9-d783-4fa0-a3fd-79f3d249e426` at 11:29:17Z, still hashed to the E30 squashfs, and the live helper still contains `soft_write`. The E32 archive was not on the card. The PAK was off. The reboot cause was not identified, and that boot is not a test of the removal. The experiment record is `docs/research/usb-mtp-phase12d.md`. Phase status is `docs/ROADMAP.md`. The 7.2.10 host build record is `docs/research/linux-7.2.10-migration.md`.
- On 2026-10-14 the maintainer accepts the installed E32 image. Its squashfs is `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c` and its helper is `9fc37d2e9f2f831f194691be3f3ff6de046f8d188fad86a3094bdecb6ee00859`. That image was built before the `zlyme44.3` version change. Ordinary MTP matched, including a second Start with the cable left in place. Within-session cable recovery was not instrumentally verified. E30 stays the rollback for that limit. After the tool was closed, no MTP process remained and Demetria had no `1d6b:0100`. One PortMaster port on `/mnt/sd2` returned to NextUI with its FRT mount gone. Panfrost is the bound GPU. That image does not export the experimental PanVK opt-in. Later source exports it only for an exact `panfrost` choice, after one orange frame was presented twice. `snps,dis_u2_susphy_quirk` stays. Charging and upper-port host use are accepted by maintainer report and were not measured again.

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

A Buildroot release bump changes `BUILDROOT_VERSION` in `build.sh` and the pinned baseline in `docs/DEVELOPMENT.md`. Linux and U-Boot stay on their own pins. The product image's PanVK selection is a build choice. Mali-G52 Vulkan with that driver needs `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1`. `zlyme-gpu-env.sh` exports that only when the saved GPU choice is exactly `panfrost`. One orange frame was presented twice on a Flip. PanVK stays experimental. PPSSPP on Panfrost does not acquire the DRM display. The result is in `docs/ROADMAP.md`.

## Vendored helpers

`minui-list` 0.15.2 and `minui-presenter` 0.13.2 are vendored snapshots. Repository, tag, commit, and license are recorded in `package/system/minui-list/UPSTREAM` and `package/system/minui-presenter/UPSTREAM`. parson `ec53fb65` is the JSON helper vendored beside minui-list because upstream gitignores the directory the compiler includes. Stay on those recorded commits until a review says otherwise. Do not comment that vendored source for style.

ZcrapeGoat is not a patch stack and not a submodule. `package/system/zcrapegoat/src` is a pristine upstream v2.3.0 import, then ordinary Zlyme commits. A later update imports a new pinned revision. Do not follow upstream HEAD. Record: `package/system/zcrapegoat/src/UPSTREAM` and `docs/UPSTREAMS.md`.

## NextUI fork

`Zetarancio/NextUI` is the fork. `main` on that fork stays the separate upstream and general-development line. Zlyme's `main` pins one immutable commit, `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`, and that commit has to be reachable from the fork's `zlyme` branch. Do not point Buildroot at a moving branch, and do not move the pin without a review. A Zlyme development branch may pin a matching NextUI development branch while the work is in progress. Before that pin lands on Zlyme `main`, the commit has to be on NextUI `zlyme` first. Review LoveRetro changes deliberately. Do not rebase the fork onto upstream HEAD to look current. Keep other-platform source in the fork. Hardware equivalence is required when runtime behavior changes, not for a documentation-only pin note. Never merge a Zlyme change into NextUI `main` to make a pin reachable.

### Integrating a phase onto main

This is the checklist for the current Phase 13 branch and for a later phase that used the same pin rule. Building a candidate is not publishing a release. Nothing in this list publishes one.

1. Finish and accept the phase implementation.
2. Finish the local validation that phase requires.
3. Confirm the exact NextUI development pin that Zlyme will keep.
4. Integrate that commit into NextUI `zlyme` first.
5. Verify the pinned SHA is reachable from NextUI `zlyme`.
6. Review the Zlyme changes and merge the phase branch into Zlyme `main` with the repository's normal fast-forward or reviewed merge. Do not force the history.
7. Verify `main` pins that immutable SHA and does not pin a branch name.
8. Dispatch a remote clean Build from Zlyme `main`. Leave `publish_release` false.
9. Review the remote build result. A failed build is fixed before that `main` is the baseline for the next phase.

Phase 14 starts only after this sequence, on a new Zlyme branch from the accepted `main`. Create a matching NextUI development branch only if Phase 14 changes NextUI.

## Releases

This section owns the release and delta policy. The code is `scripts/zlyme_release.py` and `scripts/make-release-deltas.py`.

- `zlymeNN` is a baseline: a full OTA and a manifest with zero deltas. `zlymeNN.0` is not a version.
- A point release `zlymeNN.M` builds deltas from the same-major baseline and from up to the last three earlier point releases of that major. A base must publish a manifest whose full OTA and root hashes verify. Other majors are never bases.
- Each delta is round-trip verified. A delta at or above 70% of the full OTA size is not published.
- Settings picks the smallest delta whose `from_sha256` exactly matches the installed `/boot/zlyme` SHA-256, otherwise the full OTA. The displayed version string does not select anything.

`./build.sh` writes a full OTA only. A GitHub `Build` dispatch can produce that same kind of clean candidate and upload the stage artifacts without publishing a release. The `publish_release` input defaults to false. Setting it true runs the release job, which writes `release-manifest.json` and any deltas and publishes the stable/latest release (`prerelease: false`, `make_latest: true`). The release assets include `zlyme.img`, `zlyme.img.sha256`, the OTA and its checksum, `release-manifest.json`, `miyoo355_fw.img`, and the standalone helpers `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`, each with a `.sha256`. `zlyme.img.sha256` is the card image checksum in the same two-space `sha256sum` format as the helpers. It is not an OTA member and it is not added to `release-manifest.json`. Those helpers are not OTA members and are not added to `release-manifest.json`. A clean build candidate is not hardware acceptance. Only an explicitly published, validated release is the public stable/latest release. Release notes describe accepted user behavior, not this log. They are the `CHANGELOG.md` section whose heading is `ZLYME_VERSION`, under the rules in `docs/WRITING.md`. The release job fails if that section is missing. It does not publish GitHub's generated commit list. Architecture of the apply path is in `docs/ARCHITECTURE.md`. The device runbook is in `docs/OPERATIONS.md`.

Published `zlyme44` is `zlyme-37164297221`, built by run `37164297221` from `337ccbce2587393463a4b49c551f94e33e318e44`, with zero deltas. Its root differs from the locally accepted image because the build dates differ (`docs/DEVELOPMENT.md`, Release artifacts).

Published `zlyme44.2` is `zlyme-38098037074`, built by run `38098037074` from `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`. Documentation commits after that SHA do not replace the published firmware. `zlyme44.1` was not published as its own release.

The installer is a separate repository, `Zetarancio/zlymeOS-Installer`, branch `zlyme-installer`. Build All Platforms moves only the reused `beta-zlyme-installer` tag to the commit it builds, and the platform builds refuse to upload a different commit. Create Latest Release targets that exact commit. Later commits may touch only Markdown or the release workflow. The first normal release, `V1.8.0`, predates that fix. Its tag is at `678f6440f1409dbf0e824fb4e3d6d4a1499d23c0`, and its binaries were built at `b33d31b42b3726305724e7b59c3b397d1bdc6edd`. Between those commits only the README and the release workflow changed.

## Open validation debt

Every Phase 10 finding `(a)` through `(q)` is triaged in `docs/research/documentation-audit-phase10.md` ("Finding triage" and "zlyme44.1 maintenance dispositions"). This section is that index. It is not a shorter substitute. Before a change touches one of these paths, read the original finding first. Published `zlyme44` (`337ccbce2587393463a4b49c551f94e33e318e44`) still has the source the original findings describe. The fixes below are in the `zlyme44.1` source at `6a398b311310246ef6a5515ed72805c6f58d787d`. That SHA was developed on `zlyme44.1-maintenance`. The branch was removed after the commit was reachable from `main`. The maintainer device-accepted that runtime. `zlyme44.1` is not published. GitHub Actions run `37375071442` is the clean-build and publication gate. Deferred items `(i)`, `(m)`, `(n)`, and `(q)` are not Phase 10 blockers.

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

- **(i)** The LED watcher still polls every 2 seconds. Change it only after measuring the cost. Phase 12A1, on `zlyme44.3-phase-12`, changes that poll to 10 seconds and shuts down at a confirmed 0%. That part is host-tested. On 2026-10-14 the maintainer accepts the battery behavior. A discharge to 0% was not run, so the shutdown itself was not observed.
- **(m)** Literal `my355` in generic-looking paths matters when a second device exists.
- **(n)** Boot-timing and NextUI emergency snapshots are still copied when system logs are off. That is a deliberate diagnostic tradeoff.
- **(q)** PortMaster's `sleep 0.4` stays until the readiness condition it covers is known. `S15bootpart` and `S13resize` use `ZLYME_STORAGE_DEVICE` and do not fall back to another `ZLYME` label. Implemented and host-tested. Flip validation of that path is deferred and is not a `zlyme44.1` gate.
