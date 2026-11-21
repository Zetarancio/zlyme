# Phase 18. Zlyme 44.5

Objective: prepare the product release after `zlyme44.4`. The order was 18A community and CI, 18B ARMHF compiler cache, 18C Unicode paths, 18D Nintendo DS, 18E startup governor and timezones, 18F NextUI engineering, and 18G publication. This feature plan was Phase 17 earlier on 2026-11-02. The original plan named `zlyme45`, and that name was not used.

Disposition: closed, 2026-11-21. `zlyme44.5` is the published stable release, tag `zlyme-44857224770`, from `803664a98875b0c128f16726b8d117e2b1b41e25`. The published image has not been installed or hardware-tested. The latest installed acceptance remains the 2026-11-17 F3 image below.

## Implementation

18A is closed, 2026-11-04, for community templates and consolidated Art Book validation, and is on main at `946644aafc2c385300de0962a0af53119663a123`. That fast-forward did not change firmware. The separate Art Book workflow is gone. The logbook checksum mismatch stays separate.

18B is closed, 2026-11-04, on `zlyme45-phase-18b`. The ARMHF sysroot build enabled ccache, and a repeat bzip2 compile hit the cache.

18D replaced DraStic with DSperate in the product source after a DraStic diagnostic image showed a black screen. A source patch binds DS A and B to the virtual pad's A and B. The maintainer waived another hardware run for that narrow change. The corrected binary of that patch was not in the first installed DSperate image.

18E left the governor at `smart`. The timezone selector is one representative row. The short description is `Left/right: change zone.`

18F1 reads `PLAT_btIsConnected()` for the status pill. 18F2 publishes the my355 Bluetooth cache with `SDL_atomic_t` and keeps `settings.bluetooth` a lock-free bool. 18F3 publishes one Wi-Fi signal category and keeps `settings.wifi` a lock-free bool. 18F4 makes `runCmdTimeout()` reap the shell it forked if the calling thread is cancelled.

## Source and host validation

18F4 is accepted as source and a host test. NextUI `3aff9c42777bf69ff476601b7011b05f753ba8cd` contains that helper. It is included in the integrated source. It is not in the previously installed F3 image, and it was not run on the Flip. An exceptional `setpgid()` failure remains an integration review item, not a new cleanup.

The host regression and the earlier host tests are recorded in [docs/research/phase-18-plan.md](../research/phase-18-plan.md).

## Hardware acceptance

18D is closed for the tested scope on installed `zlyme-my355-20261116-fc414c6ba084.tar`: direct KMS play, audible NDS audio, the gamepad, MENU-alone pause, resume, MENU+START return, and a battery save under the selected library's `Saves/NDS/dsperate`. That closure is not every DS game or every emulator function. DraStic files stay.

18E and the installed F3 checklist are accepted for the maintainer's 2026-11-17 sign-off on `zlyme-my355-20261116-9d0fc4e3f12d.tar`, SHA-256 `9159f90d0ebccf1394a9702b799968754574829b54d0c934258868c674bea784`, built from `9d0fc4e3f12d52d3b1f56fd3e0a75fc8d6a0e6ea`. The maintainer reported no regressions. A Bluetooth controller was used. No headset audio check was performed, and that check is not required for this pill change. The normal reboot was reported visually fast. The recorded `nextui-first-flip` of 12.05 s stays next to the older 8.33 s sample, and neither sample proves a startup regression. The sign-off does not record individual screen text, a before/after timezone name, or a headset. SSH before the sign-off read Europe/Berlin at index 316. The NextUI pin inside that image is `e49f0d791a4f91306adc01ef2c407ec4e8101a61`, not the later F4 pin.

The dated paragraphs in the snapshot keep every intermediate image name, size, and checksum. Those paragraphs also keep sentences that were true on the day they were written, including sentences that said a later-closed item was still open.

## Deferred compatibility

18C is closed as an investigation, 2026-11-17. It is not a fix. The pinned RetroArch 1.22.2 ZIP reader returns raw member-name bytes. The original failing archive was not available. Five test ZIPs were written on the second card and were not launched. No decoder change was made. Legacy-encoded GBA ZIP names stay unverified. The Wine launcher keeps UTF-8 arguments in a host test. No Unicode-path fix was made. A disposable Wine start tried to open a window without a display, and the Flip then froze. The cause is unknown. The production Wine prefix was not used. No further device Wine test is authorized by that closure. The branch `zlyme45-phase-18c` stays at `2525168d0a81de4f85a864f1a4559e694edb0616` and is not merged.

Older SD2 `EIO`, `EUCLEAN`, and superblock write errors stay a separate maintenance concern. They are not a Phase 18 release gate.

2026-11-18, after that closure. The maintainer launched five GBA ZIP fixtures through NextUI. All five used the same payload. A was an ASCII ZIP and member. B had 测试 in the ZIP name and an ASCII member. C had 测试 in the member and the UTF-8 ZIP flag. D and E had GBK member bytes. The E log extracted to a path containing the raw bytes `\xb2\xe2\xca\xd4`, then ran the game. All five loaded. That does not prove the legacy member name was decoded as text. RetroArch's ZIP reader was not changed.

The same day, `putty.exe` launched through NextUI. `putty-测试.exe` did not. Wine reported `failed to open` for that path and escaped the UTF-8 bytes of 测试. The launcher passes the path through quoted arguments. ZIP files handed to the Wine launcher are not a path-encoding result: the launcher does not extract archives, and ZIP execution is out of scope. NextUI's shipped `font1.ttf` and `font2.ttf` do not contain 测 or 试, so the list can omit those characters even when the stored path is intact. Those limits are in the published `zlyme44.5` notes. The notes also say a non-ASCII folder name may fail. That sentence is not a record of an observed folder-path failure.

## Integration

18G integrated the accepted implementation through 18F and published it. NextUI `zlyme` is `3aff9c42777bf69ff476601b7011b05f753ba8cd`. The installed F3 sign-off is not repeated as a new hardware result.

## Candidate build

Workflow [44055637428](https://github.com/Zetarancio/zlyme/actions/runs/44055637428) is cancelled. It was built from `8d61d33d263434de4cd4e5f5f6200becd3756908`, where `ZLYME_VERSION` was `zlyme44.4`. It was not installed, and it is not the published release.

## Release authorization

The maintainer authorized one direct Build with `publish_release` true. `zlyme44.5` is a point release on the published `zlyme44` series. The original `zlyme45` name stays in the historical plan.

## Incomplete publication build

Run [44429282687](https://github.com/Zetarancio/zlyme/actions/runs/44429282687), from `f0ccbc64faea1088a07a6cf133202514408e6d3c`, completed with conclusion success. The release job was skipped. That run uploaded no OTA and no `zlyme.img`. It did not publish `zlyme44.5`.

Each image stage ran for 18,600 seconds and ended because the compile window closed. The full logs contain no `make: ***`. Stage A installed `libretro-mame2003-plus` and was downloading `host-libretro-mkxp-z`. Stage B was compiling Amiberry, at about 60% of that package, and every package it installed had already been installed by stage A. Stage C was compiling `qt6base` 6.11.1, ninja step 1341 of 1509, after installing `host-qt6base`. It installed fewer packages than stage A. The glibc `recipe for target` lines in those logs are makefile warnings, not the end of the build.

The compiler cache was restored from the previous stage and was full at 1.5 GB in all three stages. The printed lifetime hit rates were 72.20%, 70.16%, and 68.85%. Those counters travel with the cache. Stage B added 9,101 hits and 59,625 misses. Stage C added 9,750 hits and 41,957 misses. Packages that took at least five seconds to build in stage A took more than 80% of that time again in stage B. Each stage starts a new Buildroot output directory. ccache does not keep that tree. The 1.5G maximum was stored in the restored cache by the pack step. No replacement build was dispatched from that conclusion. The later successful build is below. The cache policy is in [docs/DEVELOPMENT.md](../DEVELOPMENT.md).

## Publication

Workflow [44857224770](https://github.com/Zetarancio/zlyme/actions/runs/44857224770) built `803664a98875b0c128f16726b8d117e2b1b41e25` and published stable release [zlyme-44857224770](https://github.com/Zetarancio/zlyme/releases/tag/zlyme-44857224770), titled `zlyme44.5 (2026-11-21)`. It is not a draft or a prerelease. The tag resolves to that source. ARMHF, stage A, require-image, and the release job succeeded. Stages B and C were skipped because stage A already had the image. The release check printed `release assets ok`. The release has 19 assets.

Stage A restored Actions cache `ccache-my355-44429282687-c`. Host and container ccache both reported a maximum of 8.0 GiB from `ccache.conf` (`max_size = 8GiB`). The raw `ccache -s` lines use GiB: the restored cache was 1.4 GiB of 8.0 GiB, and the stage ended at 2.3 GiB of 8.0 GiB. Counters were zeroed before compilation. The stage then recorded 46,641 direct hits, 4,843 preprocessed hits, 38,502 misses, 89,986 cacheable calls, 30,190 uncacheable calls, and a 57.21% hit rate. The end-of-stage `ccache -s` text has no Cleanups line. The restored text, before the reset, had 11,341 cleanups. Build elapsed 16,179 seconds and returned 0. The saved Actions cache is `ccache-my355-44857224770-a`, 2,110,432,806 bytes. The fallback archive compressed 2.07 GiB to 1.95 GiB and replaced the previous `ccache-my355.tar.zst`. One finished production build does not show that 8 GiB is the best size, or that every later build will finish in one stage.

The full OTA is `zlyme-my355-20261121-803664a98875.tar`, 766,126,080 bytes, SHA-256 `f068e62d841b5e4a994754838da39b377f3317e1012d305c6d9b2ec2253f9828`. The manifest root is 712,646,656 bytes, SHA-256 `cd004e8c2543abab7bee798cce6b948a833dd23338f42efd72bc8791826d416d`. The card image `zlyme.img` is 1,409,306,624 bytes, SHA-256 `605f8e245b42f7c3a63c6a6c3bf1c46f5251cba55062660b131dcb6f42afd31e`. Deltas were published from `zlyme44.2`, `zlyme44.3`, and `zlyme44.4`. The `zlyme44` baseline delta was omitted: 556,093,440 bytes is at least 70% of the full OTA.

Records: [docs/research/phase-18-plan.md](../research/phase-18-plan.md) and [docs/research/phase-18d-nds-preflight.md](../research/phase-18d-nds-preflight.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-18-zlyme-45).
