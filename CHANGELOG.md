# Changelog

What changed for people who run Zlyme. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Zlyme does not use Semantic Versioning: `zlymeNN` is a baseline release, and `zlymeNN.M` is a point release on that same baseline. Writing rules are in [docs/WRITING.md](docs/WRITING.md).

Earlier development builds were published as GitHub prereleases. Their history is in [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/LOGBOOK.md](docs/LOGBOOK.md), not here.

## [Unreleased]

Unreleased work is `zlyme44.2`. Phase 11 is closed. This is not a published release, and it is not marked Latest. The unpublished `zlyme44.1` fixes stay listed here until that release is published. The `zlyme44` notes below stay the description of the shipped release.

### Added

- A fresh card image includes `miyoo355_fw.img` on the boot partition. Stock runs that installer and patches this unit's own preloader so the Flip can boot from the card. An update does not copy that file and does not touch the preloader.
- Standalone stock helpers are published beside the card image: `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`, each with a checksum. Stock only runs a file named `miyoo355_fw.img`, so rename the one you need before putting it on the card. A fresh `zlyme.img` still contains only the multiboot installer. An update contains none of them. The restore helper runs only while stock still boots, and it is not the way out of an armed recovery preloader. On 2026-10-08 one Flip accepted the restore helper, the MASKROM helper from the repaired preloader, the MASKROM helper from the original stock preloader, a right-slot Zlyme boot of that recovery image, and Disarm back to the repaired preloader. The hashes and raw logs are in the hardware wiki. That acceptance is that unit. The helpers still refuse a preloader that fails their checks.
- Settings → System → Advanced → Recovery shows preloader status on a fixed page, arms or disarms MASKROM recovery, or restores the stock preloader. Each write asks twice and starts on Cancel. Arm installs a recovery preloader. A bootable card in the right slot still boots. Without one, startup enters MASKROM. Disarm writes back the image saved when recovery was armed. Restore prefers this unit's `mtd5-original-<sha256>.img`. If that backup is absent, it can write the shipped stock image only for the one supported preloader revision. The build also publishes `miyoo355_fw.img` and its checksum beside the card image. An update does not install that file.
- Settings → Network → Proxy: HTTP or SOCKS5 for online services that honor a proxy. It is not a VPN. There is no username or password.

### Changed

- PortMaster runs from the library you selected, not from the read-only system image. The first launch unpacks the included PortMaster there. A PortMaster update you install yourself stays when Zlyme is updated. Settings → Game → Reset PortMaster removes PortMaster and its downloaded runtimes and keeps installed ports.
- PortMaster's layout changed in Zlyme 44.2. After the new PortMaster opens, an older `/storage/PortMaster` can be deleted. A games card may also have `Roms/Ports (PORTS)/PortMaster` from another layout. That PortMaster folder is not used and can be deleted. Do not delete `Roms/Ports (PORTS)` itself, or the game folders and scripts in it. Runtimes from those old installations are not carried over and can be downloaded again.
- After a verified Recovery arm, disarm, or stock restore, Settings offers shut down or a normal restart. That action does not write again until Settings is opened again. Restart does not enter MASKROM. To enter MASKROM after arming, shut down, remove the right-hand bootable card, and power on. Ordinary Settings pages show B and A hints. Pages with their own controls keep those controls.
- The card image is published with `zlyme.img.sha256`. An update does not include that file.
- A failed stock preloader restore rolls back to the preloader that was installed before the attempt. A failed erase does the same. Erasing the preloader does not by itself enter USB MASKROM when a bootable card is inserted.
- The development card's diagnostic U-Boot countdown is gone. The installed bootloader does not wait for a key.
- Preloader status shows whether the internal image is the normal preloader or a recovery preloader, whether recovery is ready or armed, and whether the source backup and stock restore are available. It does not show hashes.
- OpenBOR keeps saves in `Saves/OPENBOR`. Its paks, screenshots, and engine logs stay out of the ROM folder.
- RPG Maker XP, VX, and Ace open a `.zip`, `.7z`, or `.mkxpz` whose project is in one top folder, and still open a project that already sits at the archive root. The extensions on the system list match the core: `.ini`, `.json`, `.rxproj`, `.rvproj`, `.rvproj2`, `.mkxpz`, `.zip`, `.7z`.
- Windows games use Kron4ek Wine 11.6 WoW64 under Box64 0.4.4. The prefix is files on the card at `/storage/.config/nextui/my355/wine-prefix`, with a 1 MiB temporary `dosdevices` folder. An update removes `wine-prefix.ext4`.
- Settings stays the first Tools entry. The name on screen is still Settings.
- Update can download the release you are already running. It says when the version matches, and when the firmware file itself matches, and it still lets you reinstall.
- Release notes scroll, with the usual button hints. A release with no notes is not the same message as notes that could not be fetched.

### Fixed

- PortMaster extracts its included fonts with xz, then tar. The first launch no longer stops because the system tar cannot open an `.xz` archive.
- LÖVE 11.5 ports can load the Theora 1.1 decoder they were built against. Zlyme's own Theora library stays the current one.
- Settings keeps the selected item's description above the button hints.
- The standalone MASKROM and restore helpers no longer reboot after a verified write. Stock's block-device number is not which physical slot the card is in. Power the device off before changing cards.
- An update archive is accepted only when listing the whole archive succeeds and the required files are present. A truncated archive that prints those names and then fails is rejected before it is extracted.
- 32-bit Windows programs can load Wine's builtin libraries from the exFAT prefix. `prepare` creates `drive_c` and copies the libraries wineboot cannot symlink onto that filesystem.
- Suspend no longer reads or writes the RTC wake alarm. The 24-hour alarm that `zlyme44` programmed is gone, and an alarm set on purpose is left in place.
- `zlyme-update uboot` writes the bootloader only on the right-hand card, and only when `/boot` is that card's boot partition and the disk uses 512-byte logical sectors. It refuses a target it cannot prove.
- Boot, storage, and the first-boot resize use the right-hand card. The `ZLYMEBOOT` and `ZLYME` labels confirm those partitions. A second card with the same labels is left alone.
- The second SD slot stays at high-speed signaling. Both slots share one I/O-voltage rail, and a UHS switch on the second slot was dropping the other card.
- A game started right after boot, or right after an update reboot, keeps that game's CPU profile. Returning to the list uses Smart again.
- A product image build stops when the update tar cannot be packed. That failed build does not keep a finished-looking disk image or a partial update archive.

### Removed

- Tools → Preloader Recovery. Recovery is Settings → System → Advanced → Recovery.
- Reboot to MASKROM. That action wrote a boot-file request and restarted. It is not the recovery preloader. MASKROM recovery is Arm and Disarm on the Recovery page.
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
