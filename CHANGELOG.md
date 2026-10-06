# Changelog

What changed for people who run Zlyme. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Zlyme does not use Semantic Versioning: `zlymeNN` is a baseline release, and `zlymeNN.M` is a point release on that same baseline. Writing rules are in [docs/WRITING.md](docs/WRITING.md).

Earlier development builds were published as GitHub prereleases. Their history is in [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/LOGBOOK.md](docs/LOGBOOK.md), not here.

## [Unreleased]

Unreleased work is `zlyme44.2`. It is not hardware-accepted and not published. The unpublished `zlyme44.1` fixes stay listed here until that release is published. The `zlyme44` notes below stay the description of the shipped release.

### Added

- Settings → Network → Proxy: HTTP or SOCKS5 for online services that honor a proxy. It is not a VPN. There is no username or password.

### Changed

- Settings stays the first Tools entry. The name on screen is still Settings.
- Update can download the release you are already running. It says when the version matches, and when the firmware file itself matches, and it still lets you reinstall.
- Release notes scroll. A release with no notes is not the same message as notes that could not be fetched.

### Fixed

- Suspend no longer reads or writes the RTC wake alarm. The 24-hour alarm that `zlyme44` programmed is gone, and an alarm set on purpose is left in place.
- `zlyme-update uboot` writes the bootloader only on the right-hand card, and only when `/boot` is that card's boot partition and the disk uses 512-byte logical sectors. It refuses a target it cannot prove.
- Boot, storage, and the first-boot resize use the right-hand card. The `ZLYMEBOOT` and `ZLYME` labels confirm those partitions. A second card with the same labels is left alone.
- The second SD slot stays at high-speed signaling. Both slots share one I/O-voltage rail, and a UHS switch on the second slot was dropping the other card.
- A game started right after boot, or right after an update reboot, keeps that game's CPU profile. Returning to the list uses Smart again.
- A product image build stops when the update tar cannot be packed. That failed build does not keep a finished-looking disk image or a partial update archive.

### Removed

- The unused mergerfs package. Libraries stay separate cards.

## [zlyme44] - 2026-10-04

The first stable release, built from `337ccbce2587393463a4b49c551f94e33e318e44` by a clean GitHub Actions build. The entries compare it with the development prerelease `zlyme40 (2026-09-23)`, the baseline the Phase 9 README review was checked against.

### Added

- Zlyme's own Miyoo Flip gamepad driver: analog sticks, buttons, stick calibration, a deadzone for each stick, and rumble. Settings → System → Joysticks has Test Sticks, calibration, deadzone tuning, Rumble Strength and Test Rumble.
- Games see a standard virtual Xbox 360 controller for the built-in pad and for each external controller. External controllers come first in player order.
- Deep suspend. The power button puts the Flip into real sleep, with the `vdd_logic` rail switched off.
- Per-system CPU frequency floors adapted from SpruceOS Miyoo Flip tuning. A governor picked with MENU+Y still wins.
- BIOS files are found on any mounted library, and the game's own card wins a duplicate. Existing saves are found on any card.
- Settings → System → Storage: Create game folders, eject a library card, format a second SD or USB disk as exFAT or ext4, and choose the PortMaster install location.
- Delete game from the MENU+Y menu on a ROM.
- Music Player, and Flash games (the `FLASH` system) through Ruffle Handheld.
- Settings: Time zone, Wi-Fi country, and System → Advanced (GPU, CPU undervolt, ZRAM, USB OTG, HDMI, second SD slot, system logs, Reset Settings, Factory Reset).
- Updates can use a smaller delta when the installed system exactly matches its base. `zlyme44` is a baseline and ships none. Every update is checked by SHA-256 before it installs.

### Changed

- The product version is `zlyme44`. The build date appears beside it (`zlyme44 (2026-10-04)`) and in update file names, not in the version.
- gpSP moved to the revision ROCKNIX carries, for Game Boy Advance speed.
- A system appears in the menu only when a library holds a game it can launch.
- ScrapeGoat is now ZcrapeGoat, built from source. It handles ScreenScraper artwork, manuals and metadata with your own account, and Libretro cheats under `/storage/Cheats`. It reads every library and saves art beside the ROM. Its settings live in `/storage/.config/ZcrapeGoat`. Old ScrapeGoat settings are not carried over, so enter your ScreenScraper account again.
- PortMaster keeps its default theme and gets a Zlyme color scheme instead of a separate cloned theme.
- Native PICO-8 and Splore can use the runtime you supply in `Bios/PICO/` on any library. Fake-08 is its own system, and MENU+Y switches a Pico-8 game between them.
- Boot and updates use the graphical splash.

### Removed

- Artwork Scraper. ZcrapeGoat replaces it, and an update deletes the old stock copy from the card.
- The Autocal tool. Stick calibration is in Settings → System → Joysticks.
- The Weston test pak.

### Known limitations

- The Miyoo Flip is the only supported device.
- Closing the lid while a game runs blanks the screen and stops the radios but does not deep-suspend. Use the power button.
- The zlyme44 suspend helper still programs a 24-hour RTC alarm left over from suspend testing. This is software policy, not a Miyoo Flip hardware sleep limit; a 24-hour suspend was not part of hardware acceptance.
- Replacement Switch-style sticks have not been tested on hardware.
- CPU undervolt stays off unless you turn it on.

[Unreleased]: https://github.com/Zetarancio/zlyme/compare/zlyme-37164297221...HEAD
[zlyme44]: https://github.com/Zetarancio/zlyme/releases/tag/zlyme-37164297221
