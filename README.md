# Zlyme

**Low latency. High viscosity.**

*It's engineered to ooze, cultured for speed.*

*It’s not buttery smooth. It’s slime-smooth.*

Zlyme is a Linux system for the Miyoo Flip. It boots straight into [NextUI](https://github.com/LoveRetro/NextUI), which grew out of [MinUI](https://github.com/shauninman/MinUI) by Shaun Inman. The frontend is direct to the screen. There is no desktop in the way.

The Miyoo Flip is the only device this release supports. The root filesystem is read-only. Your games, saves, and settings stay on the card.

The installer, the image, and the update files are on the [Releases](https://github.com/Zetarancio/zlyme/releases) page. How to play, where BIOS files go, and what the Recovery page does are in the [user guide](docs/USER_GUIDE.md).

## Install

Use the [Zlyme Installer](https://github.com/Zetarancio/zlymeOS-Installer/releases) on Windows, macOS, or Linux. It writes the card for you: `zlyme.img` and the small `miyoo355_fw.img` the Flip's stock system runs once.

If you already know how to write a disk image, you can do that part yourself with Raspberry Pi Imager, balenaEtcher, or `dd`. The installer is the easier path.

The Flip has two card slots.

- The **right-hand slot**, next to the power button, holds the Zlyme card. That is the one the system boots from.
- The **left-hand slot** is a second library. Games on that card show up beside the ones on the boot card. It cannot boot the Flip.

Boot the Flip's stock system with the new card in the right-hand slot. Stock runs `miyoo355_fw.img`, powers off, and that file is removed. That one-time step is what makes the card bootable. An update does not copy that file and does not touch the internal flash.

Put the card back in the right-hand slot and power on. The first boot makes room for your files and reboots once. After that you are in the menu.

If stock never runs the installer, the card will not boot. The [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/preloader-tools.md) is where that mechanism is documented. **Advanced → Recovery** is a later repair for a Flip that already boots Zlyme. It is not part of a normal install. [Card preparation and preloader recovery](docs/USER_GUIDE.md#card-preparation-and-preloader-recovery) says what those menu rows do.

## Games

Put games on the boot card or on a card in the left-hand slot. A USB drive works too. Each card or drive is its own library. Zlyme does not merge them into one folder.

On a library the games live under `Roms`, in a folder whose name ends with the system tag in parentheses: `Roms/Nintendo Game Boy (GB)/`. BIOS files live in `Bios` on that same card. Saves follow the game back to the card it was launched from.

The folder names, BIOS filenames, and disc layout are in [Systems and emulators](docs/USER_GUIDE.md#systems-and-emulators).

## Update

**Settings → Update** when the Flip is on Wi-Fi. It checks the file before it asks you to reboot. The reboot is what applies it.

You can also download the full update from [Releases](https://github.com/Zetarancio/zlyme/releases), check `zlyme-<version>.sha256`, and copy `zlyme-<version>.tar` to `/.update` on the boot card's storage partition. Reboot. The Flip deletes the file after a good apply.

An update replaces Zlyme on the card. It does not run `miyoo355_fw.img` again, and it does not write the Flip's internal flash.

## Controls

| Input | Action |
| --- | --- |
| D-pad, stick, A, B, X, Y, L1, L2, R1, R2, Start, Select | The same in every emulator |
| Menu | Open the shortcut menu while a game is running |
| Menu+Start | Leave the emulator and return to the menu |

Volume is the rocker. Power sleeps, and a one-second hold turns the Flip off. Closing the lid turns the screen off. Brightness is **Settings → Display**.

## Settings and tools

**Settings** is Wi-Fi, display, sound, the LED, the joysticks, sleep, language, and startup options. **Advanced** holds SSH, Samba, Syncthing, HDMI, the GPU driver, and logs. **About** shows the version, the IP address, and the guides.

**Tools** is the other menu:

- **ZcrapeGoat** downloads box art and manuals. It is [ScrapeGoat](https://github.com/Helaas/nextui-scrapegoat-pak) by Kevin Vranken, with the [Apostrophe](https://github.com/Helaas/Apostrophe) interface.
- **Overlays** browses the [NextUI community overlays](https://github.com/LoveRetro/nextui-community-overlays) and installs a previewed one. The tool is [NextUI Overlays](https://github.com/zolek86/NextUI-Overlays) by zolek86.
- **Moonlight** streams from a PC running Sunshine or GeForce Experience. The menu is [nextui-moonlight-pak](https://github.com/richieszemeredi/nextui-moonlight-pak) by Richie Szemeredi.
- **PortMaster** installs ready-made ports. It is [PortMaster](https://github.com/PortsMaster/PortMaster-GUI). Ports show up under `Roms/Ports (PORTS)/`.
- **Files** opens the card. The file manager is [vtree](https://github.com/MustardOS/vtree) from MustardOS. The launcher that starts it on Zlyme is ours.
- **Music Player** plays files you put in `Music` on the boot card. It is [nextui-music-player](https://github.com/nborodikhin/nextui-music-player) by nborodikhin.

Joystick calibration in Settings follows [Joe's Calibrage](https://github.com/Helaas/nextui-Joe-s-Calibrage-pak) by Kevin Vranken.

## User Systems and Tools and the Right to Experiment

The stock menu covers the usual systems. Your own stuff belongs on the card, next to it.

A personal emulator or tool is a folder under `Emus/my355/` or `Tools/my355/` with a `launch.sh`. Give a personal system a new name, such as `GBA2.pak`, and put its games in a matching `Roms/… (GBA2)/` folder. An update replaces the stock pak names and leaves the ones you added.

Factory Reset puts the stock names back. It does not delete your games.

[Custom paks](docs/USER_GUIDE.md#custom-paks) is the short version of where those folders go. [CONTRIBUTING.md](CONTRIBUTING.md) is how to send a change back.

## Thanks

The [installer](https://github.com/Zetarancio/zlymeOS-Installer) started from the SpruceOS Installer. SundownerSport made the original Zlyme adaptation. The [Discord](https://discord.gg/KjR5uMQQt9) is the SpruceOS one.

Card boot on the Flip follows [apommel's baseos-my355](https://github.com/apommel/baseos-my355).

Windows games use a vanilla Wine WoW64 build, the same kind of package [lazydog/lazywine](https://github.com/lazydog/lazywine) documents for this machine.

## License

Zlyme's own build scripts, board integration, and system utilities are [MIT licensed](LICENSE). Third-party components keep their own licenses: Linux and U-Boot are GPL-2.0, NextUI is PolyForm Noncommercial 1.0.0, and each emulator and tool ships under the license recorded in its package.
