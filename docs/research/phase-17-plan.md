# Phase 17 plan

Status: proposed, 2026-11-02. Not started. This file is not implementation and not hardware acceptance.

Phase 16 is closed. The next public stable release is intended to be `zlyme45`, after this phase is accepted. There is no intermediate Phase 16 release. `ZLYME_VERSION` stays `zlyme44.4` until that acceptance. The sequencing map is [docs/ROADMAP.md](../ROADMAP.md). Integration onto `main` follows [docs/MAINTENANCE.md](../MAINTENANCE.md).

17F is the last major implementation subphase. 17G is the review and release gate. Earlier subphases can be sequenced by what they block, not as one mixed change.

## 17A. Community and CI infrastructure

Purpose: give bugs, features, and contributions a place to land, and fold the separate Art Book check into the general validation workflow.

Existing evidence: Zlyme workflows are `.github/workflows/build.yml`, `build-stage.yml`, `docker-image.yml`, and `artbook.yml`. `artbook.yml` runs `scripts/tests/test_artbook.sh` and uploads `artbook-sheets`. Host checks already cover NextUI packaging, Art Book rendering, and package metadata. This tree has no issue template or pull-request template. The absence of those files does not prove that GitHub Discussions categories are unset. Categories are a repository setting. Check the live configuration before adding any.

Source areas: `.github/`, `CONTRIBUTING.md`, `README.md`, `scripts/tests/`, and the repository's GitHub settings for Discussions.

Investigation: list the current workflow triggers and which host tests they do not run. Read the configured Discussions categories. Decide which checks belong in one validation workflow: NextUI tests, Art Book rendering, packaging tests, and the other source-level checks that are already scripts. Art Book rendering can be its own job with a path filter. It does not have to run on an unrelated documentation change.

Implementation scope, when authorized: version-controlled issue templates, a pull-request template, an optional commit-message template, and README and CONTRIBUTING links. Enabling Discussions categories is a GitHub setting, not only a file in Git. Consolidate Art Book validation into that workflow as a separate job when a path filter is the right boundary. Keep the render check and the useful contact-sheet artifacts. Remove `.github/workflows/artbook.yml` only after the replacement has run and passed. The dedicated Art Book workflow is not an architectural requirement.

Host tests: the existing Art Book and documentation tests, plus the consolidated workflow on a pull request.

Hardware gates: none. This subphase does not change the Flip image.

Exclusions: do not remove `artbook.yml` before the replacement is green. Do not publish a release. Do not treat a green host workflow as Flip acceptance.

Done when: the templates and links exist, the consolidated workflow covers the Art Book check and the contact sheets, and `artbook.yml` is gone only because that replacement passed.

Depends on: nothing in Phase 17.

## 17B. Remote ARMHF compiler cache

Purpose: find out whether the ARMHF GitHub cache actually compiles through ccache.

Existing evidence: `.github/workflows/build.yml` restores and saves `.ccache-armhf` and sets `ZLYME_CCACHE` for `scripts/build-armhf-sysroot.sh`. That script does not mention ccache. `configs/zlyme_my355_armhf_defconfig` does not set `BR2_CCACHE`. That missing line is a suspected configuration defect. It is not yet a measured cache miss. `build.sh` mounts the compiler-cache directory and exports `BR2_CCACHE_DIR`. It does not by itself turn ccache on. The ARMHF runtime export restored by the same workflow is a different artifact. Do not treat it as compiler ccache. `.github/zlyme-cache.md` describes a separate product-build cache and is not this ARMHF path.

Source areas: `.github/workflows/build.yml`, `scripts/build-armhf-sysroot.sh`, `build.sh`, `configs/zlyme_my355_armhf_defconfig`.

Investigation: read the effective Buildroot config inside an ARMHF build and confirm whether the compiler is actually wrapped. Record ccache hit and miss counts. Check directory ownership. Keep that compiler cache separate from the cached ARMHF runtime export. Check that the two do not mix stages. Compare a cached build with a clean build of the same revision. No build is part of this plan.

Implementation scope, if the defect is confirmed: the smallest config or script change that makes the existing cache directory actually used, plus a measurable before-and-after check. If the cache is unused, say so and stop treating the artifact as a speedup.

Host tests: one ARMHF build that prints ccache statistics, and a reproducibility check against a clean build of the same revision.

Hardware gates: none, unless a cache change alters shipped ARMHF bytes. Those bytes then need the usual image check, not a new emulator pass.

Exclusions: do not assume the cache works. Do not retune unrelated compiler flags.

Done when: the effective config, the wrapper, and the hit or miss counts are recorded, and any correction has a regression check.

Depends on: nothing in Phase 17. It can land with 17A if both touch CI, as separate commits.

## 17C. Unicode paths

Purpose: two reported failures where a Chinese name is involved. They are separate bugs until a shared cause is shown.

### RetroArch and GBA

Existing evidence: a ZIP whose member name is reported as `CN048 洛克人EXE 2.zip` extracting toward `CN048 �����EXE 2.gba`. RetroArch is pinned at `v1.22.2` in `package/emulators/retroarch/retroarch.mk`. The local patches are DRM and fullscreen only. They do not touch archives.

Source areas: the pinned RetroArch tree and its libretro-common archive code, `package/system/nextui/paks/Emus/GBA.pak/launch.sh`, and the library roots in [docs/USER_GUIDE.md](../USER_GUIDE.md).

Investigation: keep four cases apart. An uncompressed UTF-8 pathname. A ZIP whose members are flagged as UTF-8. A ZIP whose members use a legacy Chinese encoding. An ASCII archive that already extracts correctly. Compare the filename flag with the raw central-directory bytes. Do not rename the person's ROMs to hide the failure.

Implementation scope: the smallest archive-name fix that keeps the ASCII case working. A host fixture can use legal synthetic names. It does not need the copyrighted ROM.

Host tests: those four cases. A correct existing archive must still extract to the same names.

Hardware gates: one GBA ZIP with a non-ASCII member name on the Flip, through the stock launcher, if the host fix is in the image.

Exclusions: do not solve it by renaming user files. Do not upgrade RetroArch for this case unless the pinned tree cannot represent the name.

### Wine

Existing evidence: a Chinese directory name reaches Wine and the Windows executable does not open. The example parent is `大富翁4超时空之旅-zhm86平衡修改版20241209`. The launcher is `package/system/nextui/paks/Emus/WINE.pak/launch.sh`. The prefix tools are `package/emulators/wine-amd64/`.

Source areas: that launcher, `wine.sh`, `zlyme-wine-prefix`, and the Wine 11.6 path conversion in the pinned source.

Investigation: use one identical executable under an ASCII path and under a UTF-8 path. Record the pathname bytes, the locale, and what the loader receives. Check Wine 11.6 code-page conversion and Box64. Escaped UTF-8 in a diagnostic log is not proof that the path was stored wrong.

Implementation scope: the smallest path-translation fix that still opens an ASCII program and does not rewrite an existing prefix.

Host tests: an ASCII path and a non-ASCII path against the same loader, without commercial game data.

Hardware gates: one existing user program under a non-ASCII directory, and a check that the current prefix and saves are still there afterward.

Exclusions: do not treat the two cases as one patch unless the evidence joins them. Do not delete or relocate the person's files.

Done when: each case has its own diagnosis, its own regression, and, if a fix shipped, its own Flip check that did not disturb saves. A case that stays open is recorded with the evidence and the maintainer's disposition. That does not declare every Unicode path fixed.

Depends on: nothing in Phase 17. It does not wait for 17D.

## 17D. Nintendo DS

Purpose: find out why Nintendo DS games have not worked, then apply the smallest correction that makes one real game run and return.

Existing evidence: the maintainer's report is undiagnosed. The 2026-11-02 read-only preflight on installed `4d1f74e` found the stock `NDS.pak` launcher calling `start_drastic`, an AArch64 DraStic binary, an AArch64 `libdrastouch.so`, resolved `libSDL2`, `libz`, `libasound`, and `libc`, PipeWire `ready`, one 64 MiB `.nds` file, no `Bios/NDS` directory, and no `NDS.log`. The user guide lists no BIOS file for this system. DraStic was not launched. An older `e2c80ec` image recorded a return to NextUI, which is not gameplay and not this firmware. `libdrastouch` documents a black menu when SDL reports the desktop `opengl` renderer instead of `opengles2`. `nextui-session` exports `SDL_VIDEODRIVER=kmsdrm`. The default ALSA PCM is PipeWire.

Source areas: `package/system/nextui/paks/Emus/NDS.pak/launch.sh`, `package/emulators/drastic/start_drastic.sh`, `package/emulators/drastic/sources/libdrastouch.c`, `package/emulators/drastic/config/drastic.cfg`.

Investigation and implementation, in order:

1. One controlled launch on the Flip through the stock launcher and the ROM already on the card.
2. Record the exit status and the diagnostic lines, without publishing the ROM path.
3. Record the SDL renderer name and the graphics backend.
4. Record who holds the display.
5. Check audio and the virtual pad.
6. Name the first failure.
7. Compare a relevant supported upstream fix. DraStic is proprietary. Do not replace it, and do not add a second emulator, unless that launch shows the binary itself cannot do the job.
8. Apply the smallest correction the evidence supports.
9. If the correction is in the image, one focused local OTA and a Flip run.
10. Confirm one real game runs and returns to NextUI with MENU+START.

Host tests: the existing launcher and button-layout checks. A new test only for a defect this launch isolates.

Hardware gates: the one launch above, and a second launch after any image change. No launch was part of writing this plan.

Exclusions: do not download ROMs, BIOS, or another emulator. Do not treat a missing `Bios/NDS` directory as the cause. Do not count the older return-to-NextUI note as acceptance of this image. A process that merely starts is not acceptance. Do not close this subphase by asserting that DraStic itself is the problem. Another emulator needs its own evidenced design decision.

Done when: one real existing NDS game starts, gameplay is visible, input works, audio and graphics have been checked, MENU+START returns to NextUI, no emulator process remains, and saves and configuration are intact. If a proprietary limit blocks that result, the record names the exact boundary, the evidence, the alternatives that were tried, and whether a supported correction exists. Closing on that limit requires an explicit maintainer disposition.

Depends on: the Phase 16 image and the preflight above. It does not wait for 17A–17C.

## 17E. Startup governor and timezones

### Governor

Purpose: measure whether the list should stay on `smart` for the whole startup.

Existing evidence: `nextui-session` calls `zlyme-governor smart` before it starts `nextui.elf`. That is not a change applied at the first frame. `package/system/nextui/zlyme/governor.sh` defines `smart` as two cores, schedutil from 408 MHz to 1800 MHz, and DDR fixed at 324 MHz.

Source areas: `package/system/nextui/nextui-session`, `governor.sh`.

Investigation: keep these times apart: the first visible frame, system and library scan completion, the menu accepting input, later artwork and thumbnail work, and a rescan after storage changes. Record CPU frequency, online cores, DDR, and whether the menu stays responsive. Temperature and battery belong in the same note. A temporary startup profile is worth testing only if those numbers show `smart` is the limiter. Return to `smart` at a readiness point the frontend can observe, not after a fixed delay, and do not hold the first frame back to finish background work.

Implementation scope: one profile transition with the measurements beside it.

Host tests: none that can see the panel. A host check can lock the profile name and the handoff point.

Hardware gates: a before-and-after Flip boot with the times above.

Exclusions: do not change in-game profiles in this subphase. Do not raise clocks as a guess.

### Timezones

Purpose: shorten the selector without dropping coverage or breaking a saved choice.

Existing evidence: `package/system/nextui/zlyme/zone.tab` has 418 data lines. `nextui.mk` installs that file as `/usr/share/zoneinfo/zone.tab` and `/usr/share/nextui/zone.tab`.

Source areas: that file, the NextUI settings list that reads it, and the saved timezone value.

Investigation: offer a shorter list of commonly used zones without dropping worldwide coverage. A saved zone name and a legacy index must still select the same place, including DST. `/etc/localtime` stays a real zone. An uncommon zone remains reachable.

Implementation scope: the selector and its compatibility with the old saved value. Not a new zone database.

Host tests: one saved old index, one saved zone name, and one DST transition.

Hardware gates: the settings screen shows the shorter list, and a previously saved zone still matches the clock.

Exclusions: do not change the running device's timezone while investigating. Do not drop a region to make the list short.

Done when: the measurements or the selector change are recorded, and existing saved timezones still resolve.

Depends on: nothing earlier, except that a settings-screen change in 17F should not land before this selector if both edit the same screen.

## 17F. NextUI engineering

Purpose: the last major implementation subphase. A structured review of the fork, then bounded fixes. Not a rewrite, and not an open-ended audit.

Existing evidence: at the time this plan was written, the maintainer's reading was that the Zlyme NextUI branch contained upstream `main` and was 99 commits ahead, zero behind. Refresh that comparison before copying anything. Do not merge a commit that is already present. Keep the current Zlyme behavior.

Source areas: the pinned NextUI tree, `package/system/nextui/nextui.mk`, and the session and pak launchers that call it.

Review, in order:

1. Upstream commits. Name any LoveRetro commit that is actually missing. Preserve every current Zlyme deviation.
2. Ownership. List the major frontend subsystems and what they depend on.
3. A performance baseline: startup latency, time until the menu takes input, ROM scan time, frame pacing, and the memory and resource figures that baseline uses.
4. Correctness and lifecycle: scanning, rendering, caches, concurrency, memory ownership, settings, input, session handoff, display, audio, power, and error handling.
5. Ranked findings. Each one names the source, the impact, an attempt to falsify it, and a proposed disposition.
6. Improvements one coherent unit at a time. A deeper structural change is in scope when it fixes a demonstrated ownership or design problem. Do not rewrite `nextui.c` or `settings.cpp` as a whole.
7. Regression on representative paths: the OS card and the second card, folder scanning and navigation, a Unicode ROM name, artwork and thumbnails, a game launch and MENU+START return, settings persistence, input, lid and suspend, quick controls, and the networking, audio, and HDMI paths that the change touches. Also a frontend crash and restart. Do not rerun all 63 launchers for every small change. A host mock is not Flip acceptance.

Independent review is required for a meaningful runtime change. Do not remove a feature to make a number smaller. An audit that finds nothing is not a reason to invent a refactor.

Host tests: the existing NextUI and session tests, plus a regression for each change that has a host-visible result.

Hardware gates: a focused Flip pass when the behavior needs one.

Exclusions: no endless review loop. Compatibility stays.

Done when: every major source area has a recorded disposition. A confirmed finding is fixed, explicitly deferred, or superseded. An accepted improvement has its measurement, its regression check, and Flip acceptance when the behavior requires it.

Depends on: 17C, 17D, and 17E when they change NextUI or the session. 17A and 17B do not block it.

## 17G. Review and zlyme45

Purpose: close the phase. A green build, Flip acceptance, the maintainer's release authorization, and the public `zlyme45` publication are four different steps. A green CI run does not publish.

Existing evidence: [docs/MAINTENANCE.md](../MAINTENANCE.md) is the integration and release procedure. [docs/WRITING.md](../WRITING.md) is the changelog rule. The Open validation debt index is the deferred list from Phase 16, including status-125 recovery, the unwitnessed direct `reboot`, and the prelaunch window.

Investigation: reconcile the docs with the code that landed. Write the user-facing changelog. Review the debt index. Run the host and integration tests. Validate the final image on the Flip. Confirm the NextUI pin is immutable and reachable from NextUI `zlyme` before it is the pin on Zlyme `main`.

Implementation scope: documentation, the release notes, and the integration steps in [docs/MAINTENANCE.md](../MAINTENANCE.md). The NextUI pin stays one immutable commit, and that commit has to be reachable from NextUI `zlyme` before it is the pin on Zlyme `main`. The release build uses the existing workflow. `publish_release` stays false until the maintainer has accepted the image. There is no intermediate Phase 16 release.

Host tests: documentation tests and the phase's regression tests.

Hardware gates: the final image on the Flip, including one path from each subphase that changed runtime behavior.

Exclusions: do not publish from this plan. Do not publish an intermediate Phase 16 release. Do not call a deferred Phase 16 item fixed because Phase 17 started.

Done when: the image has passed its Flip acceptance, the maintainer has authorized the release, and the published result is `zlyme45`. A successful build by itself is not that result.

Depends on: 17A through 17F.
