<img src="package/system/nextui/res/branding/zlyme_slime_loop.gif" alt="Zlyme" width="887">

**Low latency. High viscosity.**

Zlyme is a Linux for the **Miyoo Flip**. It boots to a game list, draws that list straight to the screen, and gets out of the way when a game starts. *It's engineered to ooze, cultured for speed.*

The frontend is Zlyme's fork of [NextUI](https://github.com/LoveRetro/NextUI), which comes from [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman). There is no desktop sitting behind it. Wine gets a compositor for as long as that one program runs, and a PortMaster port that needs X11 brings its own. When the program closes, they're gone.

“It’s not buttery smooth. It’s slime-smooth.”

The Miyoo Flip is the only device Zlyme supports.

The Flip-specific pieces are the gamepad (sticks, buttons, calibration, rumble), real sleep from the power button, and a fix for the battery drain that mainline used to leave on while the Flip was off. Wi-Fi, Bluetooth, HDMI, the headphone jack, USB, and both SD slots work. Per-game CPU floors come from [SpruceOS](https://spruceui.github.io/) tuning, retargeted onto this kernel's frequency table. The hardware itself is documented in the [Miyoo Flip hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering).

## Install

### Prepare the Flip for SD boot

1. Write `zlyme.img` to a microSD card.
2. Put the card in the right-hand slot, next to the power button.
3. On a Flip that has never been prepared for SD boot, turn it on normally. Stock firmware will detect the installer included on the card. Let it finish; do not power the device off during this step.
4. When preparation is complete, boot with the card in the right-hand slot to start Zlyme.
5. With no bootable card inserted, stock remains available.

How the preloader repair works is in the [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/sd-multiboot-apommel.md). If you need the manual or host recovery path, start at [flashing](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/flashing.md). On a Zlyme card, recovery inside the OS is Settings → System → Advanced → Recovery, described in the [user guide](docs/USER_GUIDE.md#card-preparation-and-preloader-recovery).

### Write the card

The [Zlyme Installer](https://github.com/Zetarancio/zlymeOS-Installer) is the easy way. Grab it from that repository's [Releases page](https://github.com/Zetarancio/zlymeOS-Installer/releases), run it, and pick your card. It fetches the latest Zlyme release and writes `zlyme.img`. There are builds for Windows, macOS, and Linux. They aren't code-signed, so your OS will grumble once.

It's a fork of the [SpruceOS Installer](https://github.com/spruceUI/spruceOS-Installer). [SundownerSport](https://github.com/Sundownersport) kindly made the original Zlyme adaptation.

Writing the image erases the whole card. Use a dedicated OS card, not one that already holds your games.

Or download `zlyme.img` from the latest [Zlyme release](https://github.com/Zetarancio/zlyme/releases/latest) and write it with [Balena Etcher](https://etcher.balena.io/) or any raw-image writer.

The first boot grows the storage partition to fill the card and reboots once by itself.

## Load your games

The OS card is a game library, and so is a second SD card in the left slot or a USB disk. Each library has `Roms/`, `Bios/`, and `Saves/`.

1. On a blank card, run **Settings → System → Storage → Create game folders**.
2. Copy each game into its folder under `Roms/`. A Game Boy Advance game goes in `Roms/Game Boy Advance (GBA)/`. The tag in parentheses picks the emulator, so keep it exactly as written.
3. BIOS files go in `Bios/`.
4. Put the card back. A system shows up once a library holds a game it can launch.

Supported systems, ROM folders, file types, and BIOS names are listed in the [user guide](docs/USER_GUIDE.md#systems-and-emulators).

Pulling the card every time gets old. Turn on SSH (it does SFTP) or Samba in Settings and copy over Wi-Fi instead.

Which BIOS copy wins, where new saves go, multi-disc playlists, and box art are in the [user guide](docs/USER_GUIDE.md#libraries-and-storage).

## Update

**Settings → Update** checks the newest release on the channel you chose (Releases or Prereleases) and shows its notes. It downloads the update and queues it only after the SHA-256 matches. If your system exactly matches the base of a smaller delta, it may grab that instead and check the rebuilt system image too. Nothing on the running system changes until the reboot that installs it. Games, BIOS, saves, and settings stay.

Doing it by hand: copy the full `zlyme-my355-<date>-<sha>.tar` from a release (not a delta) into `/storage/.update` and reboot.

## Controls

**Launcher**

- A open, B back
- MENU tap = quick menu
- Vol = volume
- **MENU+Vol** = brightness
- **MENU+Y** = emulator / governor for the highlighted console, folder, or ROM. On a ROM it also offers Delete game.
- Power = sleep

**In a pak / game**

- **MENU+Start** closes whatever is running
- MENU tap = RetroArch's menu; standalones keep their own

Speaker and headphones switch by themselves. Bluetooth audio follows the headset when it connects.

## Settings and Tools

**Settings** opens from Tools and is the first entry there. Wi-Fi, Bluetooth, SSH, Samba, Syncthing, backup, joysticks, storage, the time zone, and **Update** are in there. On a restricted network, Settings → Network → Proxy can send online services through an HTTP or SOCKS proxy. That is not a VPN. Hardware switches sit under System → Advanced. The [user guide](docs/USER_GUIDE.md#settings) goes page by page.

- **ZcrapeGoat**: artwork, manuals, metadata, and cheats. Bring your own ScreenScraper account for art. [User guide](docs/USER_GUIDE.md#zcrapegoat).
- **Overlays**: community bezels, one game folder at a time.
- **Moonlight**: stream a PC game to the Flip.
- **PortMaster**: install game ports. [User guide](docs/USER_GUIDE.md#portmaster).
- **Files**: a file browser.
- **Music Player**: local music, podcasts, and online radio.

## User Systems and Tools and the Right to Experiment

The paks on the card are yours to poke at. You don't need to rebuild the OS to try something.

Stock copies live on the OS card in `Tools/my355/` and `Emus/my355/`. Each system is a pair: `Emus/my355/TAG.pak/launch.sh` launches the games in `Roms/Pretty Name (TAG)/`. A tool is `Tools/my355/My Tool.pak/launch.sh`. The existing paks are the examples.

An update only replaces pak names that exist in the image. Edit `GBA.pak` and the next update puts the stock one back. Copy it to `GBA2.pak` and it survives, but its games have to live in `Roms/… (GBA2)/`. Factory Reset restores the stock names too.

The [user guide](docs/USER_GUIDE.md#custom-paks) has the details.

### Bring it back upstream

If an experiment turns into something good, it can ship in the OS.

You don't need a finished patch to start. Forks, pull requests, a bug report with the logs attached, a fixed typo, a core that runs better, frame-time numbers from a real Flip, or a question before you write any code: all welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how.

Want to talk first? Zlyme hangs out in the [SpruceOS Discord](https://discord.gg/KjR5uMQQt9), where the SpruceOS team has kindly given the project a home.

If you want to understand or fork Zlyme with an AI coding tool, clone the repository and give it the `docs/` folder. The hardware wiki is where the deeper Flip knowledge lives.

## Build it yourself

You need Docker.

```sh
git clone https://github.com/Zetarancio/zlyme.git
cd zlyme
cp storage.sh.example storage.sh   # optional; set local paths
./build.sh --config zlyme_my355_defconfig
```

The image and the update tar land in `output/images/`. `./build.sh --help` lists the options. [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) covers rebuilding one package at a time.

## Documentation

- [docs/USER_GUIDE.md](docs/USER_GUIDE.md): day-to-day use, including systems, folders, and BIOS names.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to help.
- [CHANGELOG.md](CHANGELOG.md): what changed in each release.
- [docs/](docs/): how Zlyme is built and why. Start at [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- [Miyoo Flip hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering): the hardware itself, independent of any OS.

## Thanks

- [Sundownersport](https://github.com/Sundownersport) and the community behind [SpruceOS](https://spruceui.github.io/) for their continuing work and support, for the original Zlyme Installer, and for hosting Zlyme's corner of the SpruceOS Discord.
- The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI), a fork of [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman). SD multiboot (repaired preloader) is derived from [apommel](https://github.com/apommel)’s work in [baseos-my355](https://github.com/apommel/baseos-my355).
- Flash games run on [Ruffle Handheld](https://github.com/SilverPsychoo/Ruffle-Handheld) v4.2 by SilverPsychoo.
- The joystick calibration workflow is based in part on Joe's Calibrage by Kevin Vranken, MIT.
- Discord user `lazydog` for the Wine compatibility suggestion that prompted the zlyme44.2 WoW64 and prefix rework.

## License

See [LICENSE](LICENSE). Original Zlyme glue is MIT. This tree is **not** one license. NextUI (LoveRetro) is PolyForm Noncommercial 1.0.0 and must stay that way; it is a fork of MinUI by Shaun Inman. minui-list and minui-presenter are MIT (Jose Diaz-Gonzalez) and, on this image, link NextUI. Each package and pak ships its own terms.
