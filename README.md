<p align="center">
  <img src="package/system/nextui/res/branding/zlyme_slime_loop.gif" alt="Zlyme" width="333">
</p>

<p align="center">
  <strong>“Low latency. High viscosity.”</strong>
</p>

Zlyme is a custom OS for the **Miyoo Flip**, built with Buildroot on a mainline Linux kernel. It's engineered to ooze, cultured for speed. Hardware facts come from this device, and emulator recipes are harvested where they already exist. Every emulator and tool is pinned to a revision that's known to work here, not whatever upstream published last night. The set is curated so it fits the Flip, instead of shipping a hundred cores nobody on this board will use.

The frontend is Zlyme's fork of [NextUI](https://github.com/LoveRetro/NextUI) (itself from [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman)). No desktop, and no compositor sitting in the background: the menu and the games draw straight to the screen.

<p align="center">
  <strong>“It’s not buttery smooth. It’s slime-smooth.”</strong>
</p>

The Miyoo Flip is the only device Zlyme supports. The tree is laid out so another handheld could be ported one day, but nobody is promising one.

## What's Flip-specific in here

Zlyme isn't a generic RK3566 image with a frontend dropped on top. Mainline Linux doesn't know much about this handheld, so Zlyme carries the Flip support itself:

- **The gamepad.** `miyoo-flip-gamepad` is Zlyme's own out-of-tree driver for the Flip's controls: the analog sticks on the UART, the GPIO buttons, stick calibration and deadzone, and force-feedback rumble.
- **Deep suspend.** The BL31 suspend integration the Flip needs, including switching its `vdd_logic` rail off while asleep. Press power, or close the lid, and it sleeps, then wakes with your game where you left it. Opening the lid wakes it.
- **Panel refresh.** Settings → System → Display → Panel refresh offers 60 Hz, 50 Hz, and 40 Hz. They are Zlyme's timings for this panel: a stock-derived 60 Hz mode, plus slower 50 Hz and 40 Hz modes when you want a different pace or a less frequent refresh. 60 Hz is the default.
- **DDR scaling.** The selected mainline kernel has no RK3566/RK3568 DDR frequency driver, so Zlyme carries the external `rk3568_dmc` module. Memory clocks drop for light games and come back up for heavy ones.
- **Wi-Fi and Bluetooth.** They share one RTL8733BU chip, and powering it isn't just a userspace toggle. The radio driver is a pinned third-party `8733bu`. Zlyme adds its own `rtl8733bu-power` module for the chip's power and rfkill, and the kernel carries the Bluetooth support patch for it.
- **The off-state drain.** The Flip's RK817 power chip used to keep draining the battery with the device off under mainline. Zlyme fixes that.

Wi-Fi, Bluetooth audio and controllers, HDMI, sleep, the lid, the sticks, rumble, the headphone jack, USB OTG and both SD slots all work. Two GPU drivers ship: Mali (the default Vulkan path) and Panfrost. Panfrost can also load Mesa's experimental Vulkan driver. Per-system CPU frequency floors are courtesy of [SpruceOS](https://spruceui.github.io/) Miyoo Flip tuning onto Zlyme's mainline frequency table; the governor, core count and memory clocks are Zlyme's own.

The gory details, register by register, live in the [Miyoo Flip hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering).

## Install

### 1. Let the Flip boot from SD

Out of the box the Flip boots stock firmware from internal storage and ignores the card. A fresh `zlyme.img` carries `miyoo355_fw.img` on the boot partition. That file is [apommel](https://github.com/apommel)'s installer from [baseos-my355](https://github.com/apommel/baseos-my355), built from a pinned commit. It is not a replacement preloader.

1. Write `zlyme.img` to the card (the next section).
2. Put the card in the **right** slot, next to power. Stock looks for `miyoo355_fw.img` on a card it can see. The installer reboots into the card when that card is in the right-hand slot.
3. Boot **stock**. Stock runs the installer. The installer reads this unit's own preloader, saves `mtd5-original-<sha256>.img` on the card, patches only the SPL `/pinctrl` data, checks the write, and leaves the DDR blob and SPL code alone.
4. Boot again from the card. No card, the Flip still boots stock.

Writing the image does not modify internal NAND. Stock is what consumes `miyoo355_fw.img`. Zlyme does not do that write during boot or during an update. The saved `mtd5-original-<sha256>.img` is this Flip's own preloader backup.

**Settings → System → Advanced → Recovery** can arm MASKROM recovery, disarm it, or restore this unit's stock preloader. Those are advanced writes to internal flash, and each confirmation starts on Cancel. Arming recovery does not reboot straight into MASKROM: a bootable card in the right-hand slot still boots, and with no bootable card there the next power-on enters MASKROM. Disarm puts back the preloader saved when you armed recovery. Restore prefers this unit's own backup. Restart afterwards is a normal reboot. It does not enter MASKROM. The [user guide](docs/USER_GUIDE.md#card-preparation-and-preloader-recovery) walks through the rows. Standalone helpers for a Flip that is still on stock, and the physical MASKROM button, are on the [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/preloader-tools.md).

### 2. Write the OS card with the Zlyme Installer

The [Zlyme Installer](https://github.com/Zetarancio/zlymeOS-Installer) is the easy way. Grab it from that repository's [Releases page](https://github.com/Zetarancio/zlymeOS-Installer/releases), run it, pick your card. It fetches the latest Zlyme release, takes the `zlyme.img`, writes it to the card as a raw disk image, and reminds you about the preloader. There are builds for Windows, macOS and Linux. They aren't code-signed, so your OS may grumble once.

It's a fork of the [SpruceOS Installer](https://github.com/spruceUI/spruceOS-Installer). [SundownerSport](https://github.com/Sundownersport) kindly made the original Zlyme adaptation.

Writing the image erases the whole card. Use a dedicated OS card, not one that already holds your games.

### Or write it by hand

Download `zlyme.img` from the latest [Zlyme release](https://github.com/Zetarancio/zlyme/releases/latest) and write it with [Balena Etcher](https://etcher.balena.io/) or any raw-image writer. Same warning: the whole card gets overwritten.

### 3. Boot it

Put the OS card in the **right** slot, next to power, and turn the Flip on. The first boot grows the storage partition to fill the card and reboots once by itself.

## Load your games

The OS card is a game library, and so is a second SD card in the left slot or a USB disk on OTG. Each library has `Roms/`, `Bios/` and `Saves/`.

1. On a blank card, run **Settings → System → Storage → Create game folders**. It creates every system folder and leaves existing games alone.
2. Copy each game into its folder under `Roms/`, using the name from the [systems table](docs/USER_GUIDE.md#systems-and-emulators). A Game Boy Advance game goes in `Roms/Game Boy Advance (GBA)/`. The tag in parentheses picks the emulator, so keep it exactly as written.
3. BIOS files go in `Bios/`, under the names in the table.
4. Put the card back (or plug the disk in). A system shows up in the menu once a library holds a game it can launch. Empty folders don't count.

Pulling the card every time gets old. Turn on SSH (it does SFTP) or Samba in Settings and copy over Wi-Fi instead. Your settings live in `/storage/.config` on the OS card.

Which BIOS copy wins, where new saves go, multi-disc playlists and box art are in the [user guide](docs/USER_GUIDE.md#libraries-and-storage).

## Update

**Settings → Update** checks the newest release on the channel you chose (Releases or Prereleases) and shows its notes, which scroll. It downloads the update and queues it only after the SHA-256 matches. If that version is already installed, or the card already has that exact firmware, it says so and still lets you download it again. If your system exactly matches the base of a smaller delta update, it may grab that instead, rebuild a complete system image from it, and check that image too. Nothing on the running system changes until the reboot that installs it. Games, BIOS, saves and settings stay.

Doing it by hand: copy the full `zlyme-my355-<date>-<sha>.tar` from a release (not a delta) into `/storage/.update` and reboot.

Builds you make yourself produce full updates only. What an update does to paks you've edited is under [the Right to Experiment](#user-systems-and-tools-and-the-right-to-experiment).

## Controls

**Launcher**

- **A** open, **B** back
- **MENU tap** = quick menu
- **Vol -/+** = volume
- **MENU+Vol** = brightness
- **MENU+Y** = emulator / governor for the highlighted console, folder or ROM. On a ROM it also offers Delete game.
- **Power** = deep sleep
- **Close lid** = sleep, the same as a short press of power. Opening the lid wakes the Flip.

**In a pak / game**

- **MENU+Start** closes whatever is running (libretro, standalones, PortMaster, Pico-8, Tools)
- **MENU tap** = RetroArch's menu; standalones keep their own

Speaker and headphones switch by themselves. Bluetooth audio follows the headset/HDMI when it connects. HDMI is recognized as connected. Bluetooth controllers are automatically configured.

## Settings and Tools

**Settings** is part of Zlyme's NextUI fork and opens from Tools. The [user guide](docs/USER_GUIDE.md#settings) goes page by page.

- **RetroArch**: Tools → RetroArch opens RetroArch with no game. Quitting that menu returns to the list. Games you start from a library still use their own launchers.

The community tools below were adapted to Zlyme's paths, controls and bundled binaries.

- **ZcrapeGoat**: artwork, manuals and metadata from ScreenScraper, and cheats from Libretro. Bring your own ScreenScraper account for art; cheats don't need one. Based on [ScrapeGoat](https://github.com/Helaas/nextui-scrapegoat-pak) v2.3.0 and [Apostrophe](https://github.com/Helaas/Apostrophe) by Kevin Vranken. Usage: [user guide](docs/USER_GUIDE.md#zcrapegoat).
- **Overlays**: community bezels, one game folder at a time. [NextUI Overlays](https://github.com/zolek86/NextUI-Overlays) v0.1.1 by zolek86; the bezels come from the [NextUI community overlays](https://github.com/LoveRetro/nextui-community-overlays).
- **Moonlight**: stream a PC game to the Flip. The menu is [nextui-moonlight-pak](https://github.com/richieszemeredi/nextui-moonlight-pak) by Richie Szemeredi; the streamer is [moonlight-embedded](https://github.com/moonlight-stream/moonlight-embedded).
- **PortMaster**: install game ports. From [PortMaster-GUI](https://github.com/PortsMaster/PortMaster-GUI) by Jacob. Install location and colours: [user guide](docs/USER_GUIDE.md#portmaster).
- **USB File Transfer**: a Tools pak that copies files over MTP on the lower USB-C port. It can share the main card and other storage that is already available. [User guide](docs/USER_GUIDE.md#usb-file-transfer).
- **Files**: a file browser, [vtree](https://github.com/MustardOS/vtree) from MustardOS. [User guide](docs/USER_GUIDE.md#files).
- **Music Player**: [nextui-music-player](https://github.com/nborodikhin/nextui-music-player) v1.17.0 by nborodikhin. Local music in `/storage/Music`, podcasts in `/storage/Podcasts`, and online radio. The optional YouTube helpers download only when you ask.

## Systems and emulators

Zlyme supports a curated and evolving list of systems. For details on what's currently implemented and where ROMs, saves, and BIOS files go, see the [Systems and emulators](docs/USER_GUIDE.md#systems-and-emulators) section of the user guide.

## User Systems and Tools and the Right to Experiment

The paks on the card are yours to poke at. You don't need to rebuild the OS to try something.

Stock copies live on the OS card in `Tools/my355/` and `Emus/my355/`. Each system is a pair: `Emus/my355/TAG.pak/launch.sh` launches the games in `Roms/Pretty Name (TAG)/`, and gets the ROM path as its argument. A tool is just `Tools/my355/My Tool.pak/launch.sh`; it shows up under Tools once the list restarts. The existing paks are the examples (the libretro ones are a few lines around `ra-run -L …`).

Included libretro cores are copied to `/storage/.config/retroarch/cores/`. You can put your own `*_libretro.so` files there without rebuilding Zlyme. A core the image does not ship stays across an update. A reboot without an update leaves a core you replaced, including one that uses a shipped name. An update puts the image's file back for every name it ships. A core is a native program and has to come from a source you trust.

So copy a pak and break it. Change the launcher, swap the core, point it at another binary, write a new tool, add a system nobody asked for. An update only replaces pak **names that exist in the image**. Edit `GBA.pak` and the next update puts the stock one back. Copy it to `GBA2.pak` and it survives, but its games have to live in `Roms/… (GBA2)/`. Factory Reset restores the stock names too.

Stock NextUI paks from elsewhere usually need their paths, controls or binaries adapted before they run here. Some will just work; plenty won't. The [user guide](docs/USER_GUIDE.md#custom-paks) has the details.

### Bring it back upstream

If an experiment turns into something good, it can ship in the OS. That's the point of all this.

You don't need a finished patch to start. Forks, pull requests, a bug report with the logs attached, a fixed typo in the docs, a core that runs better, a new or improved pak, frame-time numbers, a power or current measurement off a real Flip, a design idea, a review of code that's already here, or just a question before you write any code: all welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how.

Want to talk first? Zlyme hangs out in the [SpruceOS Discord](https://discord.gg/KjR5uMQQt9), where the SpruceOS team has kindly given the project a home.

A lot of time has gone into the documentation in this repository and into the [Miyoo Flip hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering), so nobody has to rebuild this project from old chats and hundreds of commits. If you want to understand or fork Zlyme with an AI coding tool, clone the repository and give it the `docs/` folder. The docs were written to make the project easier to understand, change and extend. The hardware wiki is where the deeper Flip knowledge lives. AI can help you find your way around, but the source, the tests and a real Flip are still the evidence.

## Build it yourself

You need Docker.

```sh
git clone https://github.com/Zetarancio/zlyme.git
cd zlyme
cp storage.sh.example storage.sh   # optional; set local paths
./build.sh --config zlyme_my355_defconfig
```

The image and the update tar land in `output/images/`. `./build.sh --help` lists the options. To ship a pak with the OS, put it under `package/system/nextui/paks/Emus` or `package/system/nextui/paks/Tools`. [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) covers rebuilding one package at a time, so you don't sit through a full image for every edit.

## Documentation

- [docs/USER_GUIDE.md](docs/USER_GUIDE.md): day-to-day use, page by page.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to help.
- [CHANGELOG.md](CHANGELOG.md): what changed in each release.
- [docs/](docs/): how Zlyme is built and why. Start at [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- [Miyoo Flip hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering): the hardware itself, independent of any OS.

## Thanks

- [Sundownersport](https://github.com/Sundownersport) and the community behind [SpruceOS](https://spruceui.github.io/) for their continuing work and support, for the original Zlyme Installer, and for hosting Zlyme's corner of the SpruceOS Discord.
- The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI), a fork of [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman). SD multiboot (repaired preloader) is derived from [apommel](https://github.com/apommel)’s work in [baseos-my355](https://github.com/apommel/baseos-my355).
- The joystick calibration workflow is based in part on Joe's Calibrage by Kevin Vranken, MIT.
- A huge debt to the other bigs in the biz [Knulli](https://github.com/knulli-cfw/knulli-linux), [Rocknix](https://github.com/ROCKNIX/distribution) and [Batocera](https://github.com/batocera-linux/).
- [Anthony Caccese](https://github.com/anthonycaccese) and the contributors to [Art Book Next](https://github.com/anthonycaccese/art-book-next-es-de) for the artwork and visual inspiration used in Zlyme's system and Tools backgrounds.

## License

See [LICENSE](LICENSE). Original Zlyme glue is MIT. This tree is **not** one license. NextUI (LoveRetro) is PolyForm Noncommercial 1.0.0 and must stay that way; it is a fork of MinUI by Shaun Inman. minui-list and minui-presenter are MIT (Jose Diaz-Gonzalez) and, on this image, link NextUI. Each package and pak ships its own terms.
