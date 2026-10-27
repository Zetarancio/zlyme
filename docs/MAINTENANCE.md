# Maintenance

This is the maintainer index. The documents below own the detail. This page says which one to open.

| Question | Document |
| --- | --- |
| How an agent should change this tree | `AGENTS.md` |
| How an AI-assisted audit finds and classifies a defect | `docs/AUDITING.md` |
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

Product status, kept separate from the procedure below:

- Published `zlyme44` is tag `zlyme-37164297221`, from `337ccbce2587393463a4b49c551f94e33e318e44`.
- Published `zlyme44.2` is tag `zlyme-38098037074`, from `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`.
- Published `zlyme44.3` is tag `zlyme-38828679802`, from `1ce2f56af1ec91a1087a01b23f741464fc6c34f6`, published 2026-10-16.
- Published `zlyme44.4` is tag `zlyme-40439819817`, from `cb9770424011c1ccfc32cd99457364ca97ac19ea`, published 2026-10-27. `ZLYME_VERSION` is `zlyme44.4`. Phase 16 commits after that source are not part of the published release.
- Phase 14 and Phase 15 are closed. The last accepted installed firmware is `zlyme-my355-20261027-14ad7238a42e.tar`. The Quickswitcher candidate is not installed. Gates and image hashes are in `docs/ROADMAP.md` and `docs/LOGBOOK.md`.
- The dated product-status snapshots that used to live here are preserved in `docs/research/phase-15-documentation-audit.md`. They are not the current state.
- The NextUI pin in `package/system/nextui/nextui.mk` is `f595d7862d8f5dac722aaa9960307609be903db8` on NextUI `zlyme44.4-phase-14` and has to be reachable from NextUI `zlyme` before it is the pin on Zlyme `main`. The rule in the NextUI section below still applies.

## Audio on a live Flip

The product mixer is PipeWire 1.6.6 with WirePlumber 0.5.14 (`main-embedded`) and `pipewire-pulse`. `rcS` does not start it. `rc.late` starts D-Bus, then InputPlumber and Bluetooth in one background group and PipeWire in another. `/run/zlyme/pipewire/service` is `launching`, `core`, `wireplumber`, `pulse`, then `ready` only after a codec Audio/Sink exists. `codec-waiting` means the sockets are up and the RK817 node is not. `zlyme-jackd` still owns the RK817 Playback Mux. The minimal image selects the same PipeWire, WirePlumber, `libpulse`, and SBC lines and does not select NextUI. Do not treat a host test as playback on the Flip. PulseAudio 17 and BlueALSA are not either graph. A clean output is how a retired init script leaves the target. `BR2_PACKAGE_PULSEAUDIO_DAEMON` is off, so Buildroot does not install `S50pulseaudio`. The daemon executable is still installed with the client libraries; `external.mk` removes that binary and `pulseaudio-system.conf`. That file only lets a `pulse` user own `org.pulseaudio.Server`. The user is not created. `74597688` had the file, so dbus-daemon logged the unknown name and ignored the policy. `pipewire-pulse` does not use it. Installed `0b35a90` omits the file. That image is accepted for HDMI television audio, disconnect back to the speaker, the external-audio mark clearing, reconnect, and Bluetooth disconnect and reconnect. Volume and mute, including sound returning after mute, are accepted on that image. `74597688` left the speaker silent after HDMI unplug because its rule matched the connector device. The `0b35a90` image matches `HOTPLUG=1` on `card0` or `card1`.

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

The ARMHF runtime is a separate Buildroot tree. `scripts/build-armhf-sysroot.sh` builds `configs/zlyme_my355_armhf_defconfig` into `output-armhf` and writes `zlyme-armhf-runtime.manifest` plus the separate `zlyme-box86.manifest`. The product defconfig selects `zlyme-armhf-runtime` and `zlyme-box86`, which verify and import only their owned files. A product build without matching manifests fails. The manifest hashes are package versions. Recipe edits use the local-package fingerprint list and dirclean only the affected importer or probe package. `ZLYME_FINGERPRINT_CHECK` is the host test of that list. It is unset for a product build. The GitHub image workflow builds `output-armhf` before the product image. The image job receives that runtime as one tar and still fails closed when either manifest does not match. A loose artifact upload dropped the loader mode on run `39031848308` and turned `libatomic.so` into a regular file on run `39035776085`. The minimal defconfig does not select the package. `control.txt` exports `DEVICE_HAS_ARMHF=Y` after `xdelta3.armhf` ran on a Flip. That is the ABI, not a claim that every ARMHF port runs. Box86 CPU execution and ARMHF Mesa/GL4ES graphics are separate validation results. The build commands are in `docs/DEVELOPMENT.md`. The layout is in `docs/ARCHITECTURE.md`.

A Buildroot release bump changes `BUILDROOT_VERSION` in `build.sh` and the pinned baseline in `docs/DEVELOPMENT.md`. Linux and U-Boot stay on their own pins. The product image's PanVK selection is a build choice. Mali-G52 Vulkan with that driver needs `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER=1`. `zlyme-gpu-env.sh` exports that only when the saved GPU choice is exactly `panvk`. Settings offers `mali_kbase` and `panfrost`; `panfrost` remains the OpenGL stack and does not enable PanVK. One orange frame was presented twice on a Flip. PanVK stays experimental. PPSSPP on Panfrost does not acquire the DRM display. The closure note is in `docs/ROADMAP.md`. The session record is `docs/archive/roadmap-2026-10-15.md`.

## NextUI list layout

Phase 14 item 14O is accepted on installed `zlyme-my355-20261023-465207696ff8.tar` for the rows that were looked at: a ROM list's first row and a later row with no art, a ROM thumbnail, Art Book system and tool artwork, a long name staying inside the selection pill, and the default Game art width showing a nonzero percent. A user background was not a separate check. That limit does not reopen the rows that were seen. Do not change the list geometry again without a demonstrated regression. Do not hide Game art width. The notes are in `docs/ROADMAP.md`.

Abombniball's physical MENU+START return is accepted on the maintainer-installed candidate built from `c67692fe7ba7d65b0a1762ee7d26a6ee5ddc4456` with NextUI `b0960dcde4d69d32871d6605c354b1b901621eb5`. Later PAK waiter hardening must re-run that focused gate before release. A source or host test does not inherit the hardware result.

## Vendored helpers

`minui-list` 0.15.2 and `minui-presenter` 0.13.2 are vendored snapshots. Repository, tag, commit, and license are recorded in `package/system/minui-list/UPSTREAM` and `package/system/minui-presenter/UPSTREAM`. parson `ec53fb65` is the JSON helper vendored beside minui-list because upstream gitignores the directory the compiler includes. Stay on those recorded commits until a review says otherwise. Do not comment that vendored source for style.

ZcrapeGoat is not a patch stack and not a submodule. `package/system/zcrapegoat/src` is a pristine upstream v2.3.0 import, then ordinary Zlyme commits. A later update imports a new pinned revision. Do not follow upstream HEAD. Record: `package/system/zcrapegoat/src/UPSTREAM` and `docs/UPSTREAMS.md`.

## NextUI fork

`Zetarancio/NextUI` is the fork. `main` on that fork stays the separate upstream and general-development line. Zlyme's `main` pins one immutable commit, `NEXTUI_VERSION` in `package/system/nextui/nextui.mk`, and that commit has to be reachable from the fork's `zlyme` branch. Do not point Buildroot at a moving branch, and do not move the pin without a review. A Zlyme development branch may pin a matching NextUI development branch while the work is in progress. Before that pin lands on Zlyme `main`, the commit has to be on NextUI `zlyme` first. Review LoveRetro changes deliberately. Do not rebase the fork onto upstream HEAD to look current. Keep other-platform source in the fork. Hardware equivalence is required when runtime behavior changes, not for a documentation-only pin note. Never merge a Zlyme change into NextUI `main` to make a pin reachable.

### Integrating a phase onto main

This is the checklist for a phase that used the NextUI pin rule. Building a candidate is not publishing a release. A candidate dispatch leaves `publish_release` false. A release the maintainer has accepted uses the same Build workflow with `publish_release` true.

1. Finish and accept the phase implementation.
2. Finish the local validation that phase requires.
3. Confirm the exact NextUI development pin that Zlyme will keep.
4. Integrate that commit into NextUI `zlyme` first.
5. Verify the pinned SHA is reachable from NextUI `zlyme`.
6. Review the Zlyme changes and merge the phase branch into Zlyme `main` with the repository's normal fast-forward or reviewed merge. Do not force the history.
7. Verify `main` pins that immutable SHA and does not pin a branch name.
8. Dispatch one remote clean Build from Zlyme `main`. Leave `publish_release` false for a candidate. Set it true only for a release the maintainer has accepted.
9. Review the remote build result. A failed build is fixed before that `main` is the baseline for the next phase.

A phase is not closed until the documentation check in `docs/WRITING.md` has been done. That check is part of step 1, not a separate release.

The 2026-10-26 fast-forward of Phase 14 onto `main` did not dispatch that remote build. The maintainer waived it for that merge because a local product image from the same source had already been built and installed. That waiver does not change step 8 for a later phase.

Phase 14 followed this sequence. A later phase starts from the accepted `main`. Create a matching NextUI development branch only when that phase changes NextUI.

## Default system artwork

Every system in `package/system/nextui/rom-dirs.txt` and every built-in Tool pak under `package/system/nextui/paks/Tools` needs a transparent 640×480 artwork image. Add or rename one only together with that image.

These pictures are firmware. NextUI selects `zlyme-artbook`. The package downloads Art Book Next at the commit in its `.mk` and `.hash`, composes the PNGs on the build host, and installs them at `/usr/share/nextui/artbook`. That directory is in the squashfs. The full image stores the squashfs as `zlyme` on the boot partition, and the normal OTA includes the same member. There is no artwork download, no post-boot converter, and no pack for the user to copy. The minimal image does not select NextUI, so it does not install the pictures.

The build composes `system/(TAG).png` from `_inc/systems/artwork` and `_inc/systems/logos`. A system with no upstream picture uses `tools/custom/<TAG>/background.png`. Every built-in Tool uses `tools/<Exact Name>.pak/background.png`, a 454×1080 RGBA picture. The build clips that picture to `resources/system-art-alpha.png` and draws the logo from the pak name, without `.pak`. Do not add a logo file for one tool. Do not vendor the upstream image set. The mask and the reusable prompt are in that package. Do not ship a ROM-list wallpaper. The styled logo, including its contour and shadow, stays at most 291 pixels wide. It is centered in the right half of the frame, horizontally and vertically, for systems, tools, and Recently Played. Tool pak wordmarks and the Recently Played wordmark are the uppercase FreeType string. System labels, including a shared wordmark such as MKXP-Z, are not. `board/my355/assert-input-rootfs.sh` checks the packed squashfs for the exact PNG list, including `special/recent.png` and `special/tools.png`, when the image includes NextUI. `special/tools.png` is composed from the pinned archive's `tools.png` and `tools.svg`. It is not one of the nine pak pictures. MKXP-Z uses that archive's `easyrpg.png` and a generated MKXP-Z wordmark. Generated wordmarks load `_inc/fonts/ChangaOne-Italic.ttf` with Pillow. System logos that are path geometry stay on the SVG. The drop-in steps are in `package/system/zlyme-artbook/README.md`. A rebuild replaces `system/`, `tools/`, and `special/` in the image staging tree. It does not touch `/storage`.

Recently Played is not a pak. Its source is `special/Recently Played/background.png` and the firmware file is `special/recent.png`. NextUI uses the shared override `/storage/.config/nextui/shared/artbook/special/recent.png` when that file exists, then `/storage/bg.png`, then the firmware file. The folder on the card is not required, and a picture left in it is not used. The firmware file reserves the name column. The override and `/storage/bg.png` do not. `zlyme-stock-seed` does not copy, delete, or rewrite a Recently Played picture and does not write a marker. Factory reset does not delete Recently Played history. `board/my355/post-update.sh` is the only migration. It copies a regular file from `/storage/Recently Played/.media/bg.png` to the shared override when the override is absent and the SHA-256 is not one of the two built-in renders in that script. Those renders are the DejaVu compose and the mixed-case Changa One compose, also listed in `/usr/share/zlyme/recent-stock.sha256`. The old file stays. A picture the person already put in the override stays. The history list stays.

User `.media` images and `/storage/bg.png` stay in front. An update must not copy stock images over them. The license is CC BY-NC-SA 2.0. Provenance is in `docs/UPSTREAMS.md` and `package/system/zlyme-artbook/NOTICE.md`.

## Releases

This section owns the release and delta policy. The code is `scripts/zlyme_release.py` and `scripts/make-release-deltas.py`.

- `zlymeNN` is a baseline: a full OTA and a manifest with zero deltas. `zlymeNN.0` is not a version.
- A point release `zlymeNN.M` builds deltas from the same-major baseline and from up to the last three earlier point releases of that major. A base must publish a manifest whose full OTA and root hashes verify. Other majors are never bases.
- Each delta is round-trip verified. A delta at or above 70% of the full OTA size is not published.
- Settings picks the smallest delta whose `from_sha256` exactly matches the installed `/boot/zlyme` SHA-256, otherwise the full OTA. The displayed version string does not select anything.

`./build.sh` writes a full OTA only. A GitHub `Build` dispatch can produce that same kind of clean candidate and upload the stage artifacts without publishing a release. The `publish_release` input defaults to false. Setting it true runs the release job, which writes `release-manifest.json` and any deltas and publishes the stable/latest release (`prerelease: false`, `make_latest: true`). The release assets include `zlyme.img`, `zlyme.img.sha256`, the OTA and its checksum, `release-manifest.json`, `miyoo355_fw.img`, and the standalone helpers `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`, each with a `.sha256`. `zlyme.img.sha256` is the card image checksum in the same two-space `sha256sum` format as the helpers. It is not an OTA member and it is not added to `release-manifest.json`. Those helpers are not OTA members and are not added to `release-manifest.json`. A clean build candidate is not hardware acceptance. Only an explicitly published, validated release is the public stable/latest release. Release notes describe accepted user behavior, not this log. They are the `CHANGELOG.md` section whose heading is `ZLYME_VERSION`, under the rules in `docs/WRITING.md`. The release job fails if that section is missing. It does not publish GitHub's generated commit list. Architecture of the apply path is in `docs/ARCHITECTURE.md`. The device runbook is in `docs/OPERATIONS.md`.

`zlyme44.4` retains the two existing unknown-license exceptions: `preloader-stock.img` and the 41 ROCKNIX compatibility files named in `package/system/portmaster-rocknix-compat/PROVENANCE`. Each provenance record says maintainer-approved as-is. Redistribution rights remain unverified. The records are not license grants, and they do not cover any other file. `docs/UPSTREAMS.md` names both.

Published `zlyme44` is `zlyme-37164297221`, built by run `37164297221` from `337ccbce2587393463a4b49c551f94e33e318e44`, with zero deltas. Its root differs from the locally accepted image because the build dates differ (`docs/DEVELOPMENT.md`, Release artifacts).

Published `zlyme44.2` is `zlyme-38098037074`, built by run `38098037074` from `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`. Documentation commits after that SHA do not replace the published firmware. `zlyme44.1` was not published as its own release.

The installer is a separate repository, `Zetarancio/zlymeOS-Installer`, branch `zlyme-installer`. Build All Platforms moves only the reused `beta-zlyme-installer` tag to the commit it builds, and the platform builds refuse to upload a different commit. Create Latest Release targets that exact commit. Later commits may touch only Markdown or the release workflow. The first normal release, `V1.8.0`, predates that fix. Its tag is at `678f6440f1409dbf0e824fb4e3d6d4a1499d23c0`, and its binaries were built at `b33d31b42b3726305724e7b59c3b397d1bdc6edd`. Between those commits only the README and the release workflow changed.

## Open validation debt

This is the current index. Historical Phase 10 findings `(a)` through `(q)`, including the ones later accepted, are in `docs/research/phase-10-documentation-audit.md`. When a finding is fixed, accepted, superseded, or deferred, update this index in the same change. `docs/WRITING.md` owns that rule.

Still deferred:

- Flycast's Dreamcast faces follow Xbox letters. A mapping file would replace the whole stick and shoulder map, and the joystick name it must match is not proven. `docs/research/phase-15d-button-layouts.md`.
- The three emulator save-bind scripts still repeat the mount-id sequence. `docs/research/phase-15d-save-bind-ownership.md`. Extract them only as their own change.
- PortMaster still waits `0.4` s before the GUI. Replace that wait when the readiness condition is known.
- `zlyme44.4` keeps the two unknown-license exceptions named above. Redistribution rights remain unverified. The Quickswitcher and orphan-text image was not installed. The maintainer waived a hardware pass for those two settings changes.
