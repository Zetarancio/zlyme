# Phase 18 plan

Status, as first written: Proposed. Not started. This file is not implementation and not hardware acceptance.

Current status, 2026-11-05: 18A is closed and is on main at `946644aafc2c385300de0962a0af53119663a123`. 18B is closed and is on main at `d4159da87570d8ddb60e31e7fe8968a2d078a472`. That local cache measurement does not measure the GitHub Actions cache, and a second empty ARMHF tree was not built. The logbook checksum mismatch stays separate. 18C1 is open on `zlyme45-phase-18c`. The pinned RetroArch ZIP reader keeps raw member bytes. Wine has not started. 18D through 18G have not started. No Phase 18 firmware change is accepted. `ZLYME_VERSION` stays `zlyme44.4`.

Phase 16 is closed. This feature plan was written as Phase 17 on 2026-11-02 and renumbered to Phase 18 the same day, when a documentation phase was placed ahead of it. The next public stable release is intended to be `zlyme45`, after Phase 18 is accepted and the maintainer authorizes publication. This plan does not authorize a Phase 17 or Phase 18 release. `ZLYME_VERSION` stays `zlyme44.4` until that acceptance. The sequencing map is [docs/ROADMAP.md](../ROADMAP.md). Integration onto `main` follows [docs/MAINTENANCE.md](../MAINTENANCE.md).

18F is the last major implementation subphase. 18G is the review and release gate. Earlier subphases can be sequenced by what they block, not as one mixed change.

## 18A. Community and CI infrastructure

Purpose: give bugs, features, and contributions a place to land, and fold the separate Art Book check into the general validation workflow.

Existing evidence: Zlyme workflows are `.github/workflows/build.yml`, `build-stage.yml`, `docker-image.yml`, and `artbook.yml`. `artbook.yml` runs `scripts/tests/test_artbook.sh` and uploads `artbook-sheets`. Host checks already cover NextUI packaging, Art Book rendering, and package metadata. This tree has no issue template or pull-request template. The absence of those files does not prove that GitHub Discussions categories are unset. Categories are a repository setting. Check the live configuration before adding any.

Source areas: `.github/`, `CONTRIBUTING.md`, `README.md`, `scripts/tests/`, and the repository's GitHub settings for Discussions.

Investigation: list the current workflow triggers and which host tests they do not run. Read the configured Discussions categories. Decide which checks belong in one validation workflow: NextUI tests, Art Book rendering, packaging tests, and the other source-level checks that are already scripts. Art Book rendering can be its own job with a path filter. It does not have to run on an unrelated documentation change.

Implementation scope, when authorized: version-controlled issue templates, a pull-request template, an optional commit-message template, and README and CONTRIBUTING links. Enabling Discussions categories is a GitHub setting, not only a file in Git. Consolidate Art Book validation into that workflow as a separate job when a path filter is the right boundary. Keep the render check and the useful contact-sheet artifacts. Remove `artbook.yml` only after the replacement has run and passed. The dedicated Art Book workflow is not an architectural requirement.

Host tests: the existing Art Book and documentation tests, plus the consolidated workflow on a pull request.

Hardware gates: none. This subphase does not change the Flip image.

Exclusions: do not remove `artbook.yml` before the replacement is green. Do not publish a release. Do not treat a green host workflow as Flip acceptance.

Done when: the templates and links exist, the consolidated workflow covers the Art Book check and the contact sheets, and `artbook.yml` is gone only because that replacement passed.

Depends on: nothing in Phase 18.

## 18A1. Templates and lightweight validation

2026-11-04. Issue forms, a pull-request template, and contributor links are in the tree. GitHub Issues and Discussions are enabled. The discussion categories read from the repository are Announcements, General, Ideas, Polls, Q&A, and Show and tell. The SpruceOS Discord link stays.

`.github/workflows/validation.yml` runs the documentation tests, the release-helper unit test, and the workflow-text checks for the publish gate, the container image name, the changelog notes helper, and the release tag target. `scripts/tests/test_logbook_order.py` was not included: on this tree it reports recorded logbook headings that no longer match `scripts/tests/logbook_entries.sha256`. That mismatch was not changed here. The workflow uses `contents: read`. It does not call the Build workflow.

`artbook.yml` stays. It still checks out the pinned NextUI commit, builds the local Docker image, runs `scripts/tests/test_artbook.sh`, and uploads contact sheets. Moving that job into validation, and deleting the old workflow, waits for a green Art Book run of the replacement. 18A is not complete.

## 18A2. Art Book job and logbook mismatches

2026-11-04. `validation.yml` keeps the `source` job. A separate `artbook` job checks out `NEXTUI_VERSION`, builds the branch Docker image locally, runs `scripts/tests/test_artbook.sh`, requires the six contact-sheet PNGs, and uploads `artbook-sheets-<run id>` with `if-no-files-found: error`. It does not push the image. `artbook.yml` is unchanged.

The Art Book job runs when the push or pull-request range touches the same paths as `artbook.yml`, or `validation.yml`. The compared commits are `github.event.before` and `github.sha` for a push, and the pull request's base SHA and `github.sha` for a pull request. A new branch with a zero base runs the job. A manual dispatch runs it. Other changes still run `source` and skip Art Book. A skipped Art Book job is not a render pass.

`scripts/tests/test_logbook_order.py` fails on this tree. The introduction hash matches. There are 331 dated entries and 208 manifest rows. No listed heading is missing. Nine listed bodies differ. Each still matched the manifest at `726e449e23d9f8417938a6881b2cf4b0eea58326` and at `5b6be3a`. The difference entered in `a3e496ea6ea1cd10e75742c3b3f8913ba97d7a03`, "docs: name research files by the phase that needed them", on 2026-10-26. That commit renames 15 research paths inside `docs/LOGBOOK.md`. Nine of those paths sit in manifest entries:

- 2026-10-13 Phase 12D host build: `linux-7.2.10-migration.md` became `phase-12d-linux-7.2.10-migration.md`.
- 2026-10-13 Phase 12D preflight: `linux-7.2.10-preflight.md` became `phase-12d-linux-7.2.10-preflight.md`.
- 2026-10-04 Phase 10 audit: `documentation-audit-phase10.md` became `phase-10-documentation-audit.md`.
- 2026-09-28 Phase 6A: `deep-suspend-phase6.md` became `phase-06-deep-suspend.md`.
- 2026-09-28 Phase 5: `kernel-patch-audit-phase5.md` became `phase-05-kernel-patch-audit.md`.
- 2026-09-23 Phase 3A: `joypad-driver.md` became `phase-03-joypad-driver.md`.
- 2026-09-23 Phase 2B and Phase 2A: `kernel-patch-audit.md` became `phase-02-kernel-patch-audit.md`.
- 2026-09-22 Phase 1 Weston tracer: `weston.md` became `phase-01-weston.md`.

The other six renames are in entries the manifest does not list. The nine bodies are unchanged from that commit through the current tree. The measurements and conclusions remain. The previous filenames remain in the parent commit. This is a research-filename correction, and the entry boundaries are unchanged. It is not lost historical prose. The logbook and `scripts/tests/logbook_entries.sha256` were not edited. The test stays out of the green suite until a separate authorization reconciles the manifest with that rename.

Validation run [41832820570](https://github.com/Zetarancio/zlyme/actions/runs/41832820570) is push `c8616998c6316fd90a9b2a77b42fdb9b4970a627`. `source` succeeded. `artbook-changes` succeeded and the `artbook` job ran. It was not skipped. The job checked out NextUI `f595d7862d8f5dac722aaa9960307609be903db8`, built the branch image, and `scripts/tests/test_artbook.sh` passed. Artifact `artbook-sheets-41832820570` is 1281430 bytes, digest `sha256:24b7d7456e9c5d31c13f0181b4e4c8b9d8777d658503f5238926d07de9691ced`. The six PNGs are nonempty: `systems-light.png` and `systems-dark.png` are 960 by 1080, `tools-light.png` and `tools-dark.png` are 960 by 240, and `special-light.png` and `special-dark.png` are 960 by 120. The system and special light sheets show the rendered labels. `actionlint` is not installed here, so the workflow YAML was not linted with it. A pull request and a manual dispatch were not run. `artbook.yml` remains. Removing it is later work. 18A stays open. 18B through 18G have not started.

## 18A3. Branch coverage and Art Book retirement

2026-11-04. `.github/workflows/validation.yml` runs on a push to every branch. The filter is `**`. A tag push does not start it, because tags are a separate filter and this workflow does not list them. Pull requests and manual dispatch stay. The seven source checks stay. Art Book still runs only when its path gate matches. Each checkout sets `persist-credentials: false`. The workflow does not call the Build workflow or push a container.

Draft pull request [4](https://github.com/Zetarancio/zlyme/pull/4) is `zlyme45-phase-18a` into `main`. It stays a draft. Validation run [41847133501](https://github.com/Zetarancio/zlyme/actions/runs/41847133501) is that pull request at branch `f1c76e00049a2dab5e2988d185f797992a78742c`. The gate compared main `d21dd6290a24b6cf3574e2d6098ef38398be8b10` with the merge commit `43a1022747da00a6397cb058a305ee62fa4c7f42` and logged `artbook decision: true`. `source`, `artbook-changes`, and `artbook` succeeded. The render checkout was `43a1022`, the merge of `f1c76e0` into `d21dd629`. NextUI was `f595d78`. Artifact `artbook-sheets-41847133501`, id `13332186018`, is 1281430 bytes, digest `sha256:bf9e75d8f1d16d44c9ae875b3d97c3259b17bbfbf4ecb18a56a57050e6c39bb0`. The upload contains six files.

`artbook.yml` was removed in `ccf46d44a7ac8161820a171db958e872101bfaa5` after that pull request passed. It had lived at .github/workflows/artbook.yml. Push run [41847681251](https://github.com/Zetarancio/zlyme/actions/runs/41847681251) compared `f1c76e00049a2dab5e2988d185f797992a78742c` with `ccf46d44a7ac8161820a171db958e872101bfaa5` and logged `artbook decision: true`. The `artbook` job ran and succeeded. It was not skipped. Artifact `artbook-sheets-41847681251`, id `13333185504`, is 1281430 bytes, digest `sha256:fa84a0dbb87bb9a55862c3678b83f45f4bbc4999fe8c974573f3dbf6f0b086df`, six files. The workflow conclusion is failure because `source` failed: `scripts/tests/test_doc_links.py` still required the deleted path in three older backticks. Those three tokens now say `artbook.yml`, which is the form the exclusion line already used. The sentences are otherwise unchanged. The `source` job remains. The renderer in `validation.yml` remains.

`scripts/tests/test_logbook_order.py` still fails. The October 26 research-filename correction in `a3e496ea6ea1cd10e75742c3b3f8913ba97d7a03` is unchanged. `docs/LOGBOOK.md` and `scripts/tests/logbook_entries.sha256` were not edited. That mismatch is deferred documentation-integrity debt. It is not an Art Book failure, and this closure does not call the logbook test green.

18A is closed for templates, contributor links, and this CI migration. Phase 18 stays open. 18B through 18G have not started. `ZLYME_VERSION` stays `zlyme44.4`. The Linux pin was not changed. No firmware, OTA, or device test is part of this acceptance. `actionlint` is not installed here.

## 18B. Remote ARMHF compiler cache

Purpose: find out whether the ARMHF GitHub cache actually compiles through ccache.

Existing evidence: `.github/workflows/build.yml` restores and saves `.ccache-armhf` and sets `ZLYME_CCACHE` for `scripts/build-armhf-sysroot.sh`. That script does not mention ccache. `configs/zlyme_my355_armhf_defconfig` does not set `BR2_CCACHE`. That missing line is a suspected configuration defect. It is not yet a measured cache miss. `build.sh` mounts the compiler-cache directory and exports `BR2_CCACHE_DIR`. It does not by itself turn ccache on. The ARMHF runtime export restored by the same workflow is a different artifact. Do not treat it as compiler ccache. `.github/zlyme-cache.md` describes a separate product-build cache and is not this ARMHF path.

Source areas: `.github/workflows/build.yml`, `scripts/build-armhf-sysroot.sh`, `build.sh`, `configs/zlyme_my355_armhf_defconfig`.

Investigation: read the effective Buildroot config inside an ARMHF build and confirm whether the compiler is actually wrapped. Record ccache hit and miss counts. Check directory ownership. Keep that compiler cache separate from the cached ARMHF runtime export. Check that the two do not mix stages. Compare a cached build with a clean build of the same revision. No build is part of this plan.

Implementation scope, if the defect is confirmed: the smallest config or script change that makes the existing cache directory actually used, plus a measurable before-and-after check. If the cache is unused, say so and stop treating the artifact as a speedup.

Host tests: one ARMHF build that prints ccache statistics, and a reproducibility check against a clean build of the same revision.

Hardware gates: none, unless a cache change alters shipped ARMHF bytes. Those bytes then need the usual image check, not a new emulator pass.

Exclusions: do not assume the cache works. Do not retune unrelated compiler flags.

Done when: the effective config, the wrapper, and the hit or miss counts are recorded, and any correction has a regression check.

Depends on: nothing in Phase 18. It can land with 18A if both touch CI, as separate commits.

## 18B1. ARMHF compiler cache is disabled

2026-11-04. The ARMHF job in `.github/workflows/build.yml` restores `output-armhf-export` under `armhf-runtime-` plus a hash of the sysroot inputs. A hit that passes both manifest checks skips the compiler cache, the image build, and the sysroot build. Otherwise it restores `.ccache-armhf` with key `ccache-armhf-` plus the run id, and prefix `ccache-armhf-`. `ZLYME_CCACHE` is that directory. `scripts/build-armhf-sysroot.sh` points `build.sh` at `configs/zlyme_my355_armhf_defconfig` and `output-armhf`. `build.sh` mounts `ZLYME_CCACHE` at `/zlyme/ccache` and exports `BR2_CCACHE_DIR=/zlyme/ccache`. Buildroot 2026.08 copies that environment variable into `BR_CACHE_DIR` before it reads `.config`. The toolchain wrapper calls host ccache only when it was built with `BR_CCACHE`, and `toolchain/toolchain-wrapper.mk` adds that flag only for `BR2_CCACHE=y`. The saved cache is `.ccache-armhf` again. The runtime export stays `output-armhf-export`. The product job uses `.ccache`, the `ccache-my355-` prefix, and the `zlyme-cache` release. That path was not changed.

`configs/zlyme_my355_armhf_defconfig` did not set `BR2_CCACHE`. The product and minimal defconfigs do. The local `output-armhf/.config` is Buildroot 2026.08, generated 2026-10-25, from that defconfig, external version `8579baf-dirty`. It says `# BR2_CCACHE is not set` and has no ccache directory line. `output-armhf/host/bin/ccache` is absent. `toolchain-wrapper` is a stripped host executable with no ccache string. There is no local `.ccache-armhf` directory. The product `.ccache` directory is a different cache and is not ARMHF evidence.

Build [41431921792](https://github.com/Zetarancio/zlyme/actions/runs/41431921792) on 2026-11-02 hit the runtime export, about 13 MB, and did not restore `.ccache-armhf`. Build [40439819817](https://github.com/Zetarancio/zlyme/actions/runs/40439819817) on 2026-10-27 found no `ccache-armhf-` cache, set `ZLYME_CCACHE`, compiled, and saved `ccache-armhf-40439819817`. That log has no host-ccache build and no hit or miss count. No compiler-cache statistic was found.

The cache is disabled. `BR2_CCACHE=y` is now in the ARMHF defconfig, which is the same switch the other two defconfigs use. `scripts/tests/test_armhf_defconfig.sh` requires that line. It does not measure a hit. The exact Actions key changes every run. A later run can restore an older prefix, and Buildroot does not purge the cache when the compiler changes. An ARMHF sysroot build that prints `ccache -s` before and after a repeat is still required. It must not build or publish a Flip image. 18B stays open. 18C through 18G have not started.

## 18B2. Measured ARMHF compiler cache

2026-11-04. The local sysroot command was `ZLYME_CCACHE` set to `.ccache-armhf` and `scripts/build-armhf-sysroot.sh`. That selects `configs/zlyme_my355_armhf_defconfig` and writes `output-armhf`. It does not build the product image. Buildroot is 2026.08. The Docker image label matched the Dockerfile, so the image was not rebuilt. The product `.ccache` directory was not used. Its timestamp stayed 2026-09-10.

Before the build, `output-armhf/.config` was `15c18b78afcb62bf8bfe080b86b6cac0a83c65eb55683ed3973fd163bbf84eef` and said `# BR2_CCACHE is not set`. The toolchain wrapper hash was `7af6465488fbc3cd16e9870a8f55be90e9db48c0db4d4bd527b1267e482b3f24` and contained no ccache string. `.ccache-armhf` did not exist. The defconfig is newer than that saved config, so `build.sh` reapplied it. The new `.config` is `680d96fe4bed40f452104147eb5271848b3da9376c235631a21d6860ddb36da1` and has `BR2_CCACHE=y`. The Kconfig string still defaults the directory to `$(HOME)/.buildroot-ccache`. `build.sh` overrides that with `BR2_CCACHE_DIR=/zlyme/ccache`, and that mount is `.ccache-armhf`.

The first sysroot pass built host ccache and finalized the existing rootfs. It did not rebuild the October wrapper. `host-gcc-final-rebuild` then recompiled the wrapper from the existing GCC build directory. The installed wrapper is now `c0edd0e9f7620176cfb4da61412f88243d07ef156e9dd00fb2da3f449fd9b32d`. Its strings name `bin/ccache`, `BR2_USE_CCACHE`, and `CCACHE_BASEDIR` `/zlyme/output`. `output-armhf/host/bin/ccache` is present.

`zlyme-armhf-probe` was the first repeat candidate. Its recipe compiles and links in one command, which ccache counts as uncacheable, and `zlyme-armhf-probe-rebuild` was not a second compile of separate objects. bzip2 is the measured package. `bzip2-rebuild` left the objects up to date, so the two measured passes are `bzip2-dirclean` followed by `bzip2`.

Before those passes the counters were 0 cacheable calls, 0 hits, 0 misses, and 4 uncacheable calls. The cold pass reached 16 cacheable calls, 0 hits, and 16 misses. The warm pass reached 32 cacheable calls, 16 hits, and 16 misses. The warm pass added 16 hits and no misses. `blocksort.o` is `8db27aae1ea0345d81d4b47eb9208d7917999333e6fbd6dddc36c6bd020d0f32` after both passes. `libbz2.so.1.0.8` in the build directory is `7b29cf634d3392cb8446ab1f8fb2bb34a72fa6dc4ce43a5f323bf2e6e59ce071` after both passes. `.ccache-armhf` is 6.1 MB.

After `target-finalize` and the manifest scripts, both checkers passed. The stripped installed loader, libc, Box86, probe, and `libbz2.so.1.0.8` hashes match the hashes recorded before this build. The manifest files changed because they include the defconfig hash, and that file now contains `BR2_CCACHE=y`. A second empty output tree was not built. `output/` was not modified.

`scripts/tests/test_armhf_defconfig.sh` now runs in the validation `source` job. It checks the defconfig line on the host. It does not compile the sysroot. 18B is closed for this compiler-cache question. 18C through 18G have not started. No Flip image or OTA was produced.

## 18C. Unicode paths

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

Depends on: nothing in Phase 18. It does not wait for 18D.

## 18C1. GBA ZIP member names

2026-11-05. `package/system/nextui/paks/Emus/GBA.pak/launch.sh` sets `ROM="$1"` and runs `ra-run` with `"$ROM"`. `package/system/nextui/zlyme/ra-run.sh` passes that argument to `retroarch`. Neither script recodes the pathname. The gPSP pin does not unzip a ROM. RetroArch `v1.22.2` owns the ZIP read in `libretro-common/file/archive_file_zlib.c`. `zip_parse_file_iterate_step_internal` copies the central-directory filename bytes and does not read the UTF-8 flag or an Info-ZIP Unicode Path extra field. Current RetroArch master still copies those bytes. Its later archive changes are ZIP64, bounds checks, and other decompressors. They are not a filename-encoding fix, and the pin stays `v1.22.2`.

The host check is `scripts/tests/test_gba_zip_names.sh`. It compiles that pinned reader with `scripts/tests/gba_zip_parse.c` and feeds synthetic archives. The content is the text `ZLYMEGBA`, not a ROM. The member name used below is `洛克人.gba`.

- Case A, an uncompressed file named `CN048 洛克人EXE 2.gba`. The shell assignment keeps the pathname bytes, including UTF-8 `e6b49be5858be4baba`.
- Case B, a stored ZIP with general-purpose flag `0800` and member bytes `e6b49be5858be4baba2e676261`. The reader returns those bytes.
- Case C, the same characters encoded as GBK, flag `0000`, member bytes `c2e5bfcbc8cb2e676261`. The reader returns those bytes. It does not turn them into UTF-8 and it does not insert `efbfbd`.
- Case D, member `game.gba`, flag `0000`, bytes `67616d652e676261`. The reader returns those bytes.

A UTF-8 display of the GBK bytes is the replacement-character appearance in the original report. The ZIP format does not say that an unset UTF-8 flag means GBK, so this pass does not guess. No RetroArch patch is added. The launcher is unchanged. The test needs the local RetroArch tree, so it is not in the lightweight validation job. A Flip check is not a gate for a change that was not made. 18C stays open. Wine is 18C2 and has not started.

## 18D. Nintendo DS

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

Depends on: the Phase 16 image and the preflight above. It does not wait for 18A–18C.

## 18E. Startup governor and timezones

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

Depends on: nothing earlier, except that a settings-screen change in 18F should not land before this selector if both edit the same screen.

## 18F. NextUI engineering

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

Depends on: 18C, 18D, and 18E when they change NextUI or the session. 18A and 18B do not block it.

## 18G. Review and zlyme45

Purpose: close the phase. A green build, Flip acceptance, the maintainer's release authorization, and the public `zlyme45` publication are four different steps. A green CI run does not publish.

Existing evidence: [docs/MAINTENANCE.md](../MAINTENANCE.md) is the integration and release procedure. [docs/WRITING.md](../WRITING.md) is the changelog rule. The Open validation debt index is the deferred list from Phase 16, including status-125 recovery, the unwitnessed direct `reboot`, and the prelaunch window.

Investigation: reconcile the docs with the code that landed. Write the user-facing changelog. Review the debt index. Run the host and integration tests. Validate the final image on the Flip. Confirm the NextUI pin is immutable and reachable from NextUI `zlyme` before it is the pin on Zlyme `main`.

Implementation scope: documentation, the release notes, and the integration steps in [docs/MAINTENANCE.md](../MAINTENANCE.md). The NextUI pin stays one immutable commit, and that commit has to be reachable from NextUI `zlyme` before it is the pin on Zlyme `main`. The release build uses the existing workflow. `publish_release` stays false until the maintainer has accepted the image. There is no intermediate Phase 16 release.

Host tests: documentation tests and the phase's regression tests.

Hardware gates: the final image on the Flip, including one path from each subphase that changed runtime behavior.

Exclusions: do not publish from this plan. Do not publish an intermediate Phase 16 release. Do not call a deferred Phase 16 item fixed because Phase 18 started.

Done when: the image has passed its Flip acceptance, the maintainer has authorized the release, and the published result is `zlyme45`. A successful build by itself is not that result.

Depends on: 18A through 18F.
