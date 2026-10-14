# Changelog

What changed for people who run Zlyme. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Zlyme does not use Semantic Versioning: `zlymeNN` is a baseline release, and `zlymeNN.M` is a point release on that same baseline. Writing rules are in [docs/WRITING.md](docs/WRITING.md).

Earlier development builds were published as GitHub prereleases. Their history is in [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/LOGBOOK.md](docs/LOGBOOK.md), not here.

## [Unreleased]

### Added

- Tools → USB File Transfer is in the development image. It shares storage on the lower USB-C port and leaves the cards mounted. See Changed and Known limitations.
- The product image builds Mesa's PanVK driver next to the existing Mali library. Selecting Panfrost loads that kernel driver and turns on Mesa's experimental Vulkan setting for programs launched afterwards. One orange frame was shown on a Flip. That is not a claim that games render, and PPSSPP on Panfrost still does not attach the display. The Mali driver remains the Vulkan path PPSSPP can use.

### Changed

- The boot splash and README lockup use the new circle-above-word mark (slime loop). Update and resize progress use the stars loop instead of the galaxy clip.
- The battery sample is every 10 seconds. At 10% or below, the red LED stays on and flashes about once a minute. Two 0% readings in a row, with the charger offline, shut the Flip down. That shutdown has not been tried on a Flip.
- SSH stays on. Until you set a root password, the password is still empty. A password you set is kept on the card.
- After the menu is up, the clock can correct itself from the network. The first picture does not wait for that.
- Update says an install may reboot more than once, and it shows a recent transfer rate.
- Flycast is v2.7. MAME2003-Plus and Mupen64Plus-Next moved to the revisions named in `docs/UPSTREAMS.md`. That is a source pin. It is not a claim that those games run better.
- The development kernel is Linux 7.2.10. It has been booted on one Flip.
- Leaving a PortMaster game returns to the menu and removes temporary filesystems that game mounted. One game on the second card was checked. Games that use Weston were not part of that check.
- Tools → USB File Transfer shares the whole ZLYME data partition, a mounted second card, and USB volumes that are already mounted. A ROM or BIOS folder is not required. Settings, logs, and update files on the data partition are included. The boot partition is not shared. The first screen says to connect the computer to the lower USB-C port. If the lower port is not a data connection yet, the next screen says it is waiting for one and shows B to stop. It does not say the computer is connected. When the controller is bound, the screen says the session is open and shows B to stop. It does not print the kernel USB state. The controller is not bound until the lower port reports a data connection. A charger does not count as that connection. A session the computer has already configured is left alone. The tool does not start while an update is staged. Use a computer you trust.

### Fixed

- Tools → PortMaster writes its transcript to a temporary file when System logs is off. It no longer writes that file onto the card. An error on screen still comes from that transcript. With System logs on, the transcript is stored with the other tool logs.

### Known limitations

- On the installed development image `zlyme-my355-20261013-7951a37668e3.tar` (SHA-256 `be106fe994fef189d7ff150d9b997f28d7c4b96323cb3ec76d8b89f355db528a`), one computer copied disposable files to and from the Flip over MTP and the checksums matched, including a mounted second card. The maintainer reports that opening the tool again and leaving it with MENU+START worked. The computer log shows that connection ending and does not show a separate later connection. A later development build drops the one-shot repair after an EP0 enable error. The maintainer installed that build and reports that USB File Transfer works. No new file checksum was taken on it. The maintainer then installed the build that removes the USB2 PHY extcon resync and reports that USB File Transfer works, including file copying. Demetria logged the enumerations. No new file checksum was taken on that image. The maintainer then installed the build that removes `snps,dis_enblslpm_quirk` from the lower USB controller. The installed squashfs, kernel, and DTB match that archive, and a stopped read of the USB register has the suspend-signal bit set. On that same boot, with the cable left in a working position, disposable files copied both ways over MTP and the checksums matched, including a mounted second card. Opening the tool again and MENU+START were not repeated on that session. The installed development image now drops that cable-loss recovery and keeps the first connection. Ordinary copies matched both ways, including a file on the second card, and opening the tool again with the cable left in place worked. Unplugging and plugging the cable back during one session has not been measured. The session record is `docs/research/usb-mtp-phase12d.md`.
- Panfrost's experimental Vulkan driver showed one frame on a Flip. PPSSPP does not present a game through it. Games that use Weston were checked on an earlier image, not on the installed development image.

## [zlyme44.2] - 2026-10-11

Published as tag `zlyme-38098037074` by GitHub Actions run `38098037074`. The card image and update were built from `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`. Documentation commits after that SHA do not change those files. `zlyme44.1` was not published on its own. Its user-facing fixes are in this point release. The `zlyme44` notes below stay the description of the first stable release.

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

[Unreleased]: https://github.com/Zetarancio/zlyme/compare/zlyme-38098037074...HEAD
[zlyme44.2]: https://github.com/Zetarancio/zlyme/compare/zlyme-37164297221...zlyme-38098037074
[zlyme44]: https://github.com/Zetarancio/zlyme/releases/tag/zlyme-37164297221
