# Phase 17 plan

Status: proposed, 2026-11-02. Not started. This file is not implementation and not hardware acceptance.

Phase 16 is closed. The next public stable release is intended to be `zlyme45`, after this phase is accepted. There is no intermediate Phase 16 release. `ZLYME_VERSION` stays `zlyme44.4` until that acceptance. The sequencing map is [docs/ROADMAP.md](../ROADMAP.md). Integration onto `main` follows [docs/MAINTENANCE.md](../MAINTENANCE.md).

17F is the last major implementation subphase. 17G is the review and release gate. Earlier subphases can be sequenced by what they block, not as one mixed change.

## 17A. Community and CI infrastructure

Purpose: give bugs, features, and contributions a place to land, and fold the separate Art Book check into the general validation workflow.

Existing evidence: Zlyme workflows are `.github/workflows/build.yml`, `build-stage.yml`, `docker-image.yml`, and `artbook.yml`. `artbook.yml` runs `scripts/tests/test_artbook.sh` and uploads `artbook-sheets`. Host checks already cover NextUI packaging, Art Book rendering, and package metadata. There is no Discussions category set, issue template, or pull-request template in this tree.

Source areas: `.github/`, `CONTRIBUTING.md`, `README.md`, `scripts/tests/`.

Investigation: list the current workflow triggers and which host tests they do not run. Decide which checks belong in one validation workflow: NextUI tests, Art Book rendering, packaging tests, and the other source-level checks that are already scripts.

Implementation scope, when authorized: GitHub Discussions categories and templates, issue templates for bugs and feature requests, a pull-request template, an optional commit-message template, and README and CONTRIBUTING links. Consolidate Art Book validation into the general workflow. Remove `.github/workflows/artbook.yml` only after that replacement has run successfully and still keeps the useful contact-sheet evidence. The Art Book workflow is not a permanent architecture requirement.

Host tests: the existing Art Book and documentation tests, plus the consolidated workflow on a pull request.

Hardware gates: none. This subphase does not change the Flip image.

Exclusions: do not remove `artbook.yml` before the replacement is green. Do not publish a release. Do not treat a green host workflow as Flip acceptance.

Done when: the templates and links exist, the consolidated workflow covers the Art Book check and the contact sheets, and `artbook.yml` is gone only because that replacement passed.

Depends on: nothing in Phase 17.

## 17B. Remote ARMHF compiler cache

Purpose: find out whether the ARMHF GitHub cache actually compiles through ccache.

Existing evidence: `.github/workflows/build.yml` restores and saves `.ccache-armhf` and sets `ZLYME_CCACHE` for `scripts/build-armhf-sysroot.sh`. That script does not mention ccache. `configs/zlyme_my355_armhf_defconfig` does not set `BR2_CCACHE`. `build.sh` mounts the cache directory and exports `BR2_CCACHE_DIR`. It does not by itself turn ccache on. A cache artifact is not evidence that the compiler used it. `.github/zlyme-cache.md` describes a separate product-build cache and is not this ARMHF path.

Source areas: `.github/workflows/build.yml`, `scripts/build-armhf-sysroot.sh`, `build.sh`, `configs/zlyme_my355_armhf_defconfig`.

Investigation: read the effective Buildroot config inside an ARMHF build, confirm whether the compiler is wrapped, who owns the cache directory, and whether hit and miss counts move. Check that a restored runtime export and a reused compiler cache do not mix stages. Compare a cached build with a clean build.

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

Investigation: compare the ZIP filename flag, the raw central-directory bytes, and UTF-8 against a legacy Chinese code page. Check a correctly encoded ZIP and an uncompressed Unicode path on the OS card and on the second card. Do not rename the person's ROMs to hide the failure.

Implementation scope: the smallest archive-name fix that keeps ASCII names working. A host fixture can use legal synthetic names. It does not need the copyrighted ROM.

Host tests: one ZIP with a non-ASCII member name that extracts to the same Unicode path, and one ASCII ZIP that still extracts.

Hardware gates: one GBA ZIP with a non-ASCII member name on the Flip, through the stock launcher, if the host fix is in the image.

Exclusions: do not solve it by renaming user files. Do not upgrade RetroArch for this case unless the pinned tree cannot represent the name.

### Wine

Existing evidence: a Chinese directory name reaches Wine and the Windows executable does not open. The example parent is `大富翁4超时空之旅-zhm86平衡修改版20241209`. The launcher is `package/system/nextui/paks/Emus/WINE.pak/launch.sh`. The prefix tools are `package/emulators/wine-amd64/`.

Source areas: that launcher, `wine.sh`, `zlyme-wine-prefix`, and the Wine 11.6 path conversion in the pinned source.

Investigation: record the pathname bytes and whether the file is readable as UTF-8. Compare an ASCII path that opens with the same binary. Check the locale, Wine's code-page conversion, and Box64. Escaped UTF-8 in a log is not proof that the path was stored wrong.

Implementation scope: the smallest path-translation fix that still opens an ASCII program and does not rewrite an existing prefix.

Host tests: an ASCII path and a non-ASCII path against the same loader, without commercial game data.

Hardware gates: one existing user program under a non-ASCII directory, and a check that the current prefix and saves are still there afterward.

Exclusions: do not treat the two cases as one patch unless the evidence joins them. Do not delete or relocate the person's files.

Done when: each case has its own result, a passing host regression, and, if a fix shipped, one Flip check that did not disturb saves.

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

Exclusions: do not download ROMs, BIOS, or another emulator. Do not treat a missing `Bios/NDS` directory as the cause. Do not count the older return-to-NextUI note as acceptance of this image.

Done when: the first failure is named from a Flip run, and either one game runs and returns on the corrected image or the limit is recorded as DraStic itself.

Depends on: the Phase 16 image and the preflight above. It does not wait for 17A–17C.

## 17E. Startup governor and timezones

### Governor

Purpose: measure whether the list should stay on `smart` for the whole startup.

Existing evidence: `nextui-session` calls `zlyme-governor smart` before `nextui.elf`. `package/system/nextui/zlyme/governor.sh` defines `smart` as two cores, schedutil from 408 MHz to 1800 MHz, and DDR fixed at 324 MHz.

Source areas: `package/system/nextui/nextui-session`, `governor.sh`.

Investigation: measure time to the first displayed frame, library scan completion, and responsive input. Record CPU frequency, online cores, DDR, temperature, and battery across that interval. Include background artwork work. A temporary startup profile is worth testing only if those numbers show `smart` is the limiter. Return to `smart` at a readiness point the frontend can observe. Do not use a fixed delay, and do not hold the first frame back to finish background work.

Implementation scope: one profile transition with the measurements beside it.

Host tests: none that can see the panel. A host check can lock the profile name and the handoff point.

Hardware gates: a before-and-after Flip boot with the times above.

Exclusions: do not change in-game profiles in this subphase. Do not raise clocks as a guess.

### Timezones

Purpose: shorten the selector without dropping coverage or breaking a saved choice.

Existing evidence: `package/system/nextui/zlyme/zone.tab` has 418 data lines. `nextui.mk` installs that file as `/usr/share/zoneinfo/zone.tab` and `/usr/share/nextui/zone.tab`.

Source areas: that file, the NextUI settings list that reads it, and the saved timezone value.

Investigation: group entries with current IANA zones. Confirm a saved index and a saved zone name still select the same place, including DST. Confirm `/etc/localtime` stays a real zone. Keep a way to reach an uncommon zone.

Implementation scope: the selector and its compatibility with the old saved value. Not a new zone database.

Host tests: one saved old index, one saved zone name, and one DST transition.

Hardware gates: the settings screen shows the shorter list, and a previously saved zone still matches the clock.

Exclusions: do not change the running device's timezone while investigating. Do not drop a region to make the list short.

Done when: the measurements or the selector change are recorded, and existing saved timezones still resolve.

Depends on: nothing earlier, except that a settings-screen change in 17F should not land before this selector if both edit the same screen.

## 17F. NextUI engineering

Purpose: a measured pass over the fork after the functional subphases, not a rewrite.

Existing evidence: at the time this plan was written, the maintainer's reading was that the Zlyme NextUI branch contained upstream `main` and was 99 commits ahead, zero behind. Refresh that comparison before copying anything. Do not merge a commit that is already present. Keep the current Zlyme behavior.

Source areas: the pinned NextUI tree, `package/system/nextui/nextui.mk`, and the session and pak launchers that call it.

Investigation and possible scope: startup and the main loop, ROM scanning, multi-library behavior, cache invalidation, thumbnail workers, SDL memory, texture and surface lifetime, heap growth, thread ownership, UI transitions, input and sleep, audio and display ownership, pak launch and return, settings save and reset, error recovery, blocking I/O on the UI thread, and dead code. Change a boundary only when the measurement and the owner are clear. Do not rewrite `nextui.c` or `settings.cpp` as a whole. Do not drop a feature to make the code smaller.

Host tests: the existing NextUI and session tests, plus a regression for each change that has a host-visible result.

Hardware gates: a focused Flip pass after a meaningful frontend change. Independent review is required for those changes.

Exclusions: no endless audit. Each unit is one conceptual change. Compatibility stays.

Done when: the upstream comparison is refreshed, the changes that landed have tests and a Flip check, and no unrelated NextUI rewrite came with them.

Depends on: 17C, 17D, and 17E when they change NextUI or the session. 17A and 17B do not block it.

## 17G. Review and zlyme45

Purpose: close the phase and publish `zlyme45` only after explicit acceptance.

Existing evidence: [docs/MAINTENANCE.md](../MAINTENANCE.md) is the integration and release procedure. [docs/WRITING.md](../WRITING.md) is the changelog rule. The Open validation debt index is the deferred list from Phase 16, including status-125 recovery, the unwitnessed direct `reboot`, and the prelaunch window.

Investigation: reconcile the docs with the code that landed. Write the user-facing changelog. Review the debt index. Run the host and integration tests. Validate the final image on the Flip. Confirm the NextUI pin is immutable and reachable from NextUI `zlyme` before it is the pin on Zlyme `main`.

Implementation scope: documentation, the release notes, and the integration steps. The release build uses the existing workflow. `publish_release` stays false until the maintainer accepts the release.

Host tests: documentation tests and the phase's regression tests.

Hardware gates: the final image on the Flip, including one path from each subphase that changed runtime behavior.

Exclusions: do not publish from this plan. Do not publish an intermediate Phase 16 release. Do not call a deferred Phase 16 item fixed because Phase 17 started.

Done when: the maintainer has accepted the image and the release is the published `zlyme45`.

Depends on: 17A through 17F.
