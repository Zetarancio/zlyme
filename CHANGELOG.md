# Changelog

What changed for people who run Zlyme. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Zlyme does not use Semantic Versioning: `zlymeNN` is a baseline release, and `zlymeNN.M` is a point release on that same baseline. Writing rules are in [docs/WRITING.md](docs/WRITING.md).

Earlier development builds were published as GitHub prereleases. Their history is in [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/LOGBOOK.md](docs/LOGBOOK.md), not here.

## [Unreleased]

### Added

- Settings → Game → Orphan game preferences removes a per-ROM governor or emulator choice when that ROM is gone. A folder or system choice stays. A choice for the second card stays while that card is out.
- The system list shows a transparent Art Book picture behind each system when you have not chosen your own image. A game list does not add a second wallpaper. Each included tool has an illustration of that tool, and the firmware draws the tool's name on it, centered like the system names. The pictures are part of the firmware. You do not download an artwork pack. Your `.media` art and `/storage/bg.png` stay in front. The pictures are CC BY-NC-SA 2.0. Settings → Appearance → Use folder background for ROMs starts on, and turning it off keeps the plain background.
- Recently Played shows the built-in picture even when that folder is gone. Your own replacement goes in the NextUI shared art folder, and deleting it brings the built-in picture back. `/storage/bg.png` still applies when you have not set one of those. A picture left in the folder is not used. An update from zlyme44.3 keeps a picture you put there when it is not a built-in render. Names stay off the built-in picture.
- The firmware includes SDL 3.4.12 with KMS, OpenGL ES, and Wayland. SDL 2 is unchanged. An SDL 3 game is not a promise that every SDL 3 program runs.
- PortMaster can explicitly run a 32-bit x86 Linux program through Box86. Box64 and Wine are unchanged. This does not make every x86 game compatible.
- PortMaster can explicitly select a firmware GL4ES runtime when a port does not bring its own. It does not replace the system OpenGL or GLES libraries.
- Delete game removes that ROM, its matching saves, its artwork, its own governor and emulator choices, and its Recently Played entry. A folder or system choice stays. A save for another system stays. A game with the same name on another card stays. If the delete stops early, the game stays in the list.
- SSH, Samba, and Syncthing run only while Wi-Fi is on. Turning Wi-Fi off stops them and leaves each switch as it was. Turning one on while Wi-Fi is off leaves that switch on and the service stopped.

### Fixed

- Opening a game list no longer puts the previous system's picture back after you have moved on.
- A long name in a game list scrolls inside its selection. The first row stops before the clock and battery. A ROM picture, and an Art Book picture, keep the name beside the art. Game art width shows a percent.
- Settings → Bluetooth lists a nearby device again, including one whose type is not known yet. It does not connect until you choose Pair or Connect.
- The volume buttons update the on-screen level without waiting for the mixer. The saved level is what the mixer applies, including when audio is not ready yet.
- A paired headset is asked for its audio profile once BlueZ has registered that device. The request does not keep retrying, and it does not run before the device exists.
- A port whose launcher exits before its game no longer leaves that game holding the screen. If Zlyme cannot prove that every owned process stopped, it leaves the frontend stopped instead of starting a second graphics client.

### Changed

- Sound from a game, HDMI, and Bluetooth headphones goes through one PipeWire mixer. Unplugging HDMI returns sound to the speaker and clears the headset-looking mark. Plugging it back in returns sound to the television. Disconnecting Bluetooth returns the speaker, and connecting it again returns the headset. Volume and mute, including sound coming back, were accepted. Headphones still switch themselves when the plug goes in. A saved volume number is kept. A normal boot leaves the internal screen on. Turning Wi-Fi off and on brings the enabled network services back.
- PortMaster uses Zlyme's own platform setup. A PortMaster installation you already updated stays, including its downloaded runtimes.
- PortMaster is told this system can run a 32-bit ARM hard-float program. That does not mean every 32-bit port runs.
- Tools → USB Transfer is the file-copy tool. An update removes that tool's old stock folder when it still matches the copy Zlyme shipped. A folder you changed is kept outside the tool list.

### Known limitations

- A normal boot leaves the internal screen on. HDMI at 720p, the internal screen coming back, and Abombniball leaving on MENU+START were accepted on an installed development image. The final runtime candidate still needs its own PortMaster, SDL 3, GL4ES, and Box86 hardware pass. A connected charger has suppressed the shutdown at 0%. That delay was not measured.

## [zlyme44.3] - 2026-10-16

### Added

- Tools → RetroArch opens RetroArch with no game. Quitting that menu returns to the list, and closing a game from inside it stays in RetroArch. Closing a game you started from the list returns to the list.
- Settings → Game → Reset RetroArch configuration restores the stock RetroArch file. Core options, cores, saves, and BIOS stay.
- Tools → USB File Transfer shares the data card as SDCARD1, a mounted second card as SDCARD2, and a USB stick that is already mounted as OTG, on the lower USB-C port. Details are in the [user guide](https://github.com/Zetarancio/zlyme/blob/main/docs/USER_GUIDE.md#usb-file-transfer).
- Panfrost can load Mesa's experimental Vulkan driver. PPSSPP still uses the Mali driver.

### Changed

- Settings → About shows the SSH, Samba, and Syncthing account and password status, then the IP address. A Samba password you changed, and the Syncthing password, are not shown.
- Syncthing stays off until you turn it on. The first web login is username `zlyme` and password `zlyme`. Change it in Syncthing's own page. A login you already set stays. Recovery is in the [user guide](https://github.com/Zetarancio/zlyme/blob/main/docs/USER_GUIDE.md#network).
- Samba stays off until you turn it on. It shares `/storage` as `zlyme`, and the first password is `zlyme`. Change it under Settings → Network → Samba Password. An empty entry leaves the saved password. If Samba cannot start, the switch goes back off. The [user guide](https://github.com/Zetarancio/zlyme/blob/main/docs/USER_GUIDE.md#network) has the Windows address.
- Closing the lid sleeps the same way as a short press of the power button, in the list and during a game. Opening the lid wakes the Flip.
- On a new RetroArch configuration, quitting from the menu writes a savestate and the next launch loads it. A configuration you already saved stays. Hardcore RetroAchievements leaves that state unloaded, and MENU+START still leaves immediately.
- Included libretro cores are copied to the card once, about 213 MiB, before the list appears. A reboot leaves a core you replaced. An update replaces each included file. A core the image does not include stays. The file is a native program and has to come from a source you trust.
- On a new Flycast configuration, quitting writes a savestate and the next launch loads it. A configuration you already saved stays. MENU+START does not write that savestate.
- A new RetroArch setup uses the Classic Orange menu. A theme you already saved stays. The menu text stays small.
- FinalBurn Neo looks for a BIOS archive in the game folder, then `Bios/fbneo/`, then `Bios/`. MAME 2003-Plus reads ROM and BIOS zips from the game folder.
- The boot splash uses the circle-above-word mark. Update progress uses the stars loop.
- At 10% battery or below, the red LED stays on and flashes about once a minute. Two 0% readings in a row, with the charger offline, shut the Flip down. That shutdown has not been confirmed on a Flip.
- SSH stays on with an empty root password until you set one. A password you set is kept.
- After the menu is up, the clock can set itself from the network. The first picture does not wait for that.
- Update says an install may reboot more than once, and it shows a recent transfer rate.
- Flycast is v2.7.
- The kernel is Linux 7.2.10.
- A fresh card image gives the data partition the Windows basic-data type. The filesystem is still exFAT, labeled ZLYME. A card already in use keeps its partition type.
- Tools → Files uses VTree's own words for commands such as copy and cut. A theme or a hidden-file setting you already chose stays.

### Fixed

- Leaving PortMaster adds a port's cover or screenshot as that port's artwork on the same card. A JPEG stays a JPEG. Artwork you already chose stays.
- Leaving a PortMaster game removes a filesystem that game mounted through Zlyme when that filesystem is still the one at its path. Anything else mounted inside storage stays, and USB File Transfer will not start while it does.
- With System logs off, PortMaster keeps its transcript off the card. An error on screen still comes from that transcript.

Thanks to Icy_Mammoth1805 for the RetroArch menu-quit, Samba, lid-sleep, and arcade BIOS suggestions.

## [zlyme44.2] - 2026-10-11

`zlyme44.1` was not published on its own. Its fixes are in this release.

### Added

- A fresh card includes `miyoo355_fw.img`. Stock runs it and patches this unit's preloader so the Flip can boot from the card. An update does not copy that file and does not touch the preloader.
- Beside the card image are `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`, each with a checksum. Stock only runs a file named `miyoo355_fw.img`, so rename the one you need. A fresh image contains only the multiboot installer. An update contains none of them. Restore works only while stock still boots, and it is not how you leave an armed recovery preloader. The helpers refuse a preloader that fails their checks.
- Settings → System → Advanced → Recovery shows preloader status, arms or disarms MASKROM recovery, or restores the stock preloader. Each write asks twice and starts on Cancel. Arm installs a recovery preloader. A bootable card in the right slot still boots. With none, startup enters MASKROM. Disarm writes back the image saved when recovery was armed. Restore uses this unit's saved original when that backup is there.
- Settings → Network → Proxy sends online services through HTTP or SOCKS5. It is not a VPN, and it has no username or password.

### Changed

- PortMaster runs from the library you choose. The first launch unpacks it there, and a PortMaster update you install stays when Zlyme is updated. Reset PortMaster removes PortMaster and its downloaded runtimes and keeps installed ports.
- After the new PortMaster opens, an older `/storage/PortMaster` can be deleted. `Roms/Ports (PORTS)/PortMaster` from another layout is unused and can be deleted. Do not delete `Roms/Ports (PORTS)` or the games in it. Old runtimes are not carried over.
- After a verified Recovery write, Settings offers shut down or a normal restart, and that choice does not write the preloader again until Settings is opened again. Restart does not enter MASKROM. To enter MASKROM after arming, shut down, take out the right-hand bootable card, and power on.
- A failed stock restore, or a failed erase, rolls back to the preloader that was installed before the attempt. Erasing the preloader does not by itself enter USB MASKROM while a bootable card is inserted.
- The bootloader no longer waits for a key at startup.
- OpenBOR keeps saves in `Saves/OPENBOR`.
- RPG Maker opens a project in one top folder of a `.zip`, `.7z`, or `.mkxpz`, and still opens a project that already sits at the archive root.
- Windows games use the bundled Wine under Box64. The prefix is files on the card. An update removes the old `wine-prefix.ext4`.
- Update can reinstall the release you are already running.
- Suspend no longer sets a 24-hour RTC wake alarm. An alarm you set on purpose stays.

### Fixed

- PortMaster's first launch unpacks its fonts.
- LÖVE 11.5 ports can load the Theora decoder they were built against.
- The selected setting's description stays above the button hints.
- The standalone MASKROM and restore helpers no longer reboot after a verified write. Power the Flip off before you change cards.
- An update is rejected when the archive is truncated or missing a required file.
- 32-bit Windows programs can load Wine's libraries from the card prefix.
- `zlyme-update uboot` writes the bootloader only on the right-hand card, and only when that card is the boot disk it can prove.
- Boot and the first-boot resize use the right-hand card, confirmed by the `ZLYMEBOOT` and `ZLYME` labels. A second card with those labels is left alone.
- The second SD slot stays at high-speed signaling, so it does not drop the other card.
- A game started right after boot, or right after an update, keeps that game's CPU profile.

### Removed

- Tools → Preloader Recovery. Recovery is Settings → System → Advanced → Recovery.
- Reboot to MASKROM. Use Arm and Disarm on the Recovery page.
- The unused mergerfs package. Each card stays its own library.

## [zlyme44] - 2026-10-04

The first stable release.

### Added

- Zlyme's gamepad driver: sticks, buttons, calibration, a deadzone, and rumble. Settings → System → Joysticks has the tests and the tuning.
- Games see a virtual Xbox 360 pad for the built-in controls and for each external controller. External controllers come first.
- Deep suspend from the power button, with the logic rail switched off.
- Per-system CPU floors. A governor you pick with MENU+Y still wins.
- BIOS files and existing saves are found on any mounted card. The game's own card wins a duplicate BIOS.
- Settings → System → Storage can create game folders, eject a card, format a second SD or USB disk, and choose where PortMaster installs.
- Delete game, from MENU+Y on a ROM.
- Music Player, and Flash games through Ruffle.
- Time zone, Wi-Fi country, and System → Advanced: GPU, CPU undervolt, ZRAM, USB OTG, HDMI, the second SD slot, logs, Reset Settings, and Factory Reset.
- Updates are checked before they install. A smaller delta is used only when the installed system matches its base. This release ships no delta.

### Changed

- The version is `zlyme44`. The build date sits beside it and in update file names.
- gpSP is the faster Game Boy Advance build.
- A system appears only when a library has a game it can launch.
- ScrapeGoat is now ZcrapeGoat. Enter your ScreenScraper account again. Old ScrapeGoat settings are not carried over. Cheats stay under `/storage/Cheats`.
- PortMaster uses its default theme with a Zlyme color scheme.
- Native PICO-8 uses the runtime you put in `Bios/PICO/` on any library. Fake-08 is its own system, and MENU+Y switches a Pico-8 game between them.
- Boot and updates use the graphical splash.

### Removed

- Artwork Scraper. ZcrapeGoat replaces it, and an update deletes the old copy from the card.
- The Autocal tool. Calibrate sticks in Settings → System → Joysticks.
- The Weston test pak.

### Known limitations

- The Miyoo Flip is the only supported device.
- Closing the lid while a game runs blanks the screen and stops the radios. It does not deep-suspend. Use the power button.
- Sleep can still set a 24-hour RTC wake alarm. That is this release's software, not a hardware limit of the Flip.
- Replacement Switch-style sticks have not been tried.
- CPU undervolt stays off unless you turn it on.

[Unreleased]: https://github.com/Zetarancio/zlyme/compare/zlyme-38098037074...HEAD
[zlyme44.3]: https://github.com/Zetarancio/zlyme/compare/zlyme-38098037074...HEAD
[zlyme44.2]: https://github.com/Zetarancio/zlyme/compare/zlyme-37164297221...zlyme-38098037074
[zlyme44]: https://github.com/Zetarancio/zlyme/releases/tag/zlyme-37164297221
