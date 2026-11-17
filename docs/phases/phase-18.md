# Phase 18. Zlyme 45

Objective: prepare the next product release after `zlyme44.4`. The order is 18A community and CI, 18B ARMHF compiler cache, 18C Unicode paths, 18D Nintendo DS, 18E startup governor and timezones, 18F NextUI engineering, and 18G review. This feature plan was Phase 17 earlier on 2026-11-02.

Disposition: 18G integration is active. `ZLYME_VERSION` stays `zlyme44.4`. `zlyme45` is not published.

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

## Integration

18G is the integration of the accepted implementation through 18F. NextUI `zlyme` is `3aff9c42777bf69ff476601b7011b05f753ba8cd`. The installed F3 sign-off is not repeated as a new hardware result.

## Candidate build

One unpublished candidate is building from `8d61d33d263434de4cd4e5f5f6200becd3756908`. The workflow run is [44055637428](https://github.com/Zetarancio/zlyme/actions/runs/44055637428). It has no artifact name or checksum yet. It is not installed.

## Release authorization

Publication of `zlyme45` still needs an explicit maintainer decision. This summary does not authorize that release.

Records: [docs/research/phase-18-plan.md](../research/phase-18-plan.md) and [docs/research/phase-18d-nds-preflight.md](../research/phase-18d-nds-preflight.md). The phase heading is in the [2026-11-17 roadmap snapshot](../archive/roadmap-2026-11-17.md#phase-18-zlyme-45).
