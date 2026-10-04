<img src="package/system/nextui/res/branding/zlyme_slime_loop.gif" alt="Zlyme" width="887">

**Low latency. High viscosity.**

Zlyme is a custom OS for the **Miyoo Flip**, built with Buildroot on a mainline Linux kernel. Emulators and tools are pinned known-good revisions, not whatever upstream published last. It's engineered to ooze, cultured for speed. Hardware facts come from this device, and emulator recipes are harvested where they already exist. The set is curated so it fits the Flip, instead of shipping a hundred cores nobody on this board will use.

The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI) (itself from [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman)). There is no desktop environment and no permanently running compositor. The frontend and games draw directly to the display. For Windows games, Zlyme starts its own temporary Weston session for Wine. PortMaster may start its own WestonPack/Xwayland for a single port that needs it. Both go away when the app closes. It is engineered for fast boot.

“It’s not buttery smooth. It’s slime-smooth.”

## Supported hardware

The Miyoo Flip is the only supported device. The tree is structured so another handheld could be ported later, but no other port is promised.

Working on the Flip: Wi-Fi, Bluetooth audio and controllers, HDMI, sleep, the lid, analog sticks, the headphone jack, USB OTG, and both SD slots.

Zlyme fixes the known abnormal off-state battery drain of the RK817 power chip's default setup. A small drain while the device is off is still normal.

## Highlights

- Fast boot to the frontend.
- 54 systems, each on a pinned emulator. See [Systems and emulators](#systems-and-emulators).
- A performance-focused build. Per-system CPU frequency floors are adapted from [SpruceOS](https://spruceui.github.io/) Miyoo Flip tuning onto Zlyme's mainline frequency table. The governor, core count, and memory clocks stay Zlyme's. Memory clocks scale down for light games.
- Two GPU drivers: Mali (the default, with Vulkan) and Panfrost (without Vulkan).
- Games on the OS card, a second SD card, or a USB disk.
- Updates from Settings, checked with SHA-256 before they install.

## Installation

The Flip will not boot an OS from SD until you change how it starts. Without one of the steps below, it keeps booting stock from internal storage and ignores the card.

1. **apommel-multiboot** (recommended). Repairs the vendor preloader. With no card, the Flip boots stock. With a bootable card, it boots that OS. Follow the [wiki how-to](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/sd-multiboot-apommel.md). The on-device app is [apommel-multiboot](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/tree/main/preloader-stock-rocknix/App/apommel-multiboot) in that repo. See the wiki for the supported OS list.
2. **Erase the preloader.** This is destructive. Afterwards the Flip always boots from SD, or enters MASKROM mode when no card is inserted. Wiki: [stock ↔ SD-boot without opening the device](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/stock-rocknix-without-disassembly.md).

Then prepare the OS card:

1. Download `zlyme.img` from a published Zlyme release.
2. Flash it onto a dedicated OS card with Balena Etcher or any image writer. Do not flash over a card that already has games.
3. Put that card in the **right** slot (next to power).

A release carries these files:

- `zlyme.img`: the card image for a fresh install.
- `zlyme-my355-<date>-<sha>.tar` and its `.sha256`: the full update.
- `zlyme-my355-delta-<version>-<hash>.tar`: a smaller update, only on some releases. It applies only to the exact system it was made from.
- `release-manifest.json`: tells Settings → Update which update fits the installed system.

## Updating

**Settings → Update** checks the latest release on the chosen channel (Releases or Prereleases) and shows its notes. It downloads the update and queues it only after the SHA-256 matches. When the installed system exactly matches the base of a delta, it may download that smaller delta instead. The device then rebuilds a complete system image from the delta and verifies it before the reboot that installs it. The running system is not changed until that reboot commits the new image. Games, BIOS, saves, and settings stay.

**Manual update:** copy the full `zlyme-my355-<date>-<sha>.tar` from a release (not a delta) into `/storage/.update` and reboot.

Local builds produce full updates only. For what an update does to paks you added, see [Custom paks](#custom-paks).

## Controls

**Launcher**

- A open, B back
- MENU tap = quick menu
- Vol = volume
- **MENU+Vol** = brightness
- **MENU+Y** = emulator / governor for the highlighted console, folder, or ROM. On a ROM it also offers Delete game.
- Power = sleep

**In a pak / game**

- **MENU+Start** closes whatever is running (libretro, standalones, PortMaster, Pico-8, Tools)
- MENU tap = RetroArch RGUI; standalones keep their own menu

Speaker and headphones switch automatically. Bluetooth audio follows the headset when it connects.

## Games, BIOS, and saves

- **Libraries.** The OS card is `/storage`. A second SD card in the other slot, or a USB disk on OTG, is its own library. Each library uses `Roms/`, `Bios/`, and `Saves/`. System folders use the same `Pretty Name (TAG)` names as the [systems table](#systems-and-emulators). Settings → System → Storage → Create game folders creates the stock folders and does not delete ROMs.
- **BIOS.** Put BIOS files in `Bios/` on any mounted library. If the same file is on more than one card, Zlyme uses the copy on the card that holds the game.
- **Saves.** Saves stay in `Saves/` on the library that holds the game.
- **Settings** stay in `/storage/.config`.

The [user guide](docs/USER_GUIDE.md#libraries-and-storage) covers folder rules, save selection, multi-disc playlists, box art, ejecting, and formatting.

## Settings and Tools

**Settings** is built into the frontend, Zlyme's fork of NextUI. It is not a community pak, though it opens from Tools like one. It covers Wi-Fi, Bluetooth, SSH, Samba, Syncthing, backup, joysticks, storage, the time zone, and **Update**. Hardware choices such as GPU, ZRAM, USB OTG, HDMI, the second SD slot, and system logs are under System → Advanced. CPU undervolt is there too and stays off unless you turn it on. Logs are off by default. Turn on Settings → System → Advanced → System logs, and they are written to `/storage/.logs`. The [user guide](docs/USER_GUIDE.md#settings) walks through each page.

The community tools below were adapted to Zlyme's paths, controls, and bundled binaries.

- **ZcrapeGoat**: based on ScrapeGoat by Helaas. It downloads artwork, manuals, and metadata from ScreenScraper, and cheats from Libretro. Zlyme embeds its application credentials at build time; those are not shown. Upstream is [nextui-scrapegoat-pak](https://github.com/Helaas/nextui-scrapegoat-pak) v2.3.0. Usage: [user guide](docs/USER_GUIDE.md#zcrapegoat).
- **Overlays**: browse and install community bezels for one game folder. The same system on another card is a separate choice. The tool is [NextUI-Overlays](https://github.com/zolek86/NextUI-Overlays) v0.1.1 by zolek86. The bezels come from [nextui-community-overlays](https://github.com/LoveRetro/nextui-community-overlays).
- **Moonlight**: stream a PC game to the Flip. The menu is [nextui-moonlight-pak](https://github.com/richieszemeredi/nextui-moonlight-pak); the streamer is [moonlight-embedded](https://github.com/moonlight-stream/moonlight-embedded).
- **PortMaster**: install game ports. From [PortMaster-GUI](https://github.com/PortsMaster/PortMaster-GUI). Install location and theme: [user guide](docs/USER_GUIDE.md#portmaster).
- **Files**: a file browser. Hidden files are shown until you turn that off in Files. [vtree](https://github.com/MustardOS/vtree).
- **Music Player**: [nextui-music-player](https://github.com/nborodikhin/nextui-music-player) v1.17.0 by nborodikhin. Local files in `/storage/Music`, podcasts in `/storage/Podcasts`, and online radio. Optional YouTube helpers are downloaded only when you ask, into the player's own config. Zlyme updates the player; the player does not update itself.

## Systems and emulators

Folders are shown under `Roms/` on any library. Names in the Bios column are inside `Bios/` on any mounted library. "alt:" marks an emulator you can switch to from the MENU+Y Emulator row.

| System                  | Emulator                                             | Folder                                            | Files                                                                        | Bios                                                                                        |
| ----------------------- | ---------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| NES                     | Nestopia (libretro)                                  | `Roms/Nintendo Entertainment System (FC)/`        | `.nes` `.unif` `.unf` `.fds` `.zip` `.7z`                                    | `disksys.rom` (FDS, optional)                                                               |
| Game Boy                | Gambatte (libretro)                                  | `Roms/Game Boy (GB)/`                             | `.gb` `.zip` `.7z`                                                           | `gb_bios.bin` (optional)                                                                    |
| Game Boy Color          | Gambatte (libretro)                                  | `Roms/Game Boy Color (GBC)/`                      | `.gbc` `.gb` `.zip` `.7z`                                                    | `gbc_bios.bin` (optional)                                                                   |
| Game Boy Advance        | gpSP (libretro)                                      | `Roms/Game Boy Advance (GBA)/`                    | `.gba` `.zip` `.7z`                                                          | `gba_bios.bin`                                                                              |
| SNES                    | Beetle Supafaust (libretro)                          | `Roms/Super Nintendo Entertainment System (SFC)/` | `.smc` `.sfc` `.fig` `.swc` `.bsx` `.zip` `.7z`                              | —                                                                                           |
| Master System           | Genesis Plus GX (libretro); alt: PicoDrive           | `Roms/Sega Master System (MS)/`                   | `.sms` `.bin` `.zip` `.7z`                                                   | `bios_*.sms` (optional)                                                                     |
| Game Gear               | Genesis Plus GX (libretro); alt: PicoDrive           | `Roms/Sega Game Gear (GG)/`                       | `.gg` `.bin` `.zip` `.7z`                                                    | `bios.gg` (optional)                                                                        |
| SG-1000                 | Genesis Plus GX (libretro)                           | `Roms/Sega SG-1000 (SG1000)/`                     | `.sg` `.bin` `.zip` `.7z`                                                    | —                                                                                           |
| Mega Drive / Genesis    | PicoDrive (libretro); alt: Genesis Plus GX           | `Roms/Sega Genesis (MD)/`                         | `.md` `.smd` `.gen` `.bin` `.zip` `.7z`                                      | `bios_CD_U.bin` / `E` / `J` (Mega CD, optional)                                             |
| 32X                     | PicoDrive (libretro)                                 | `Roms/Sega 32X (32X)/`                            | `.32x` `.smd` `.md` `.bin` `.zip` `.7z`                                      | same Mega CD files (optional)                                                               |
| PC Engine               | Beetle PCE Fast (libretro)                           | `Roms/PC Engine (PCE)/`                           | `.pce` `.cue` `.ccd` `.iso` `.img` `.chd` `.sgx` `.zip` `.7z` `.m3u`         | `syscard3.pce` (CD, optional)                                                               |
| SuperGrafx              | Beetle SuperGrafx (libretro)                         | `Roms/SuperGrafx (SGX)/`                          | `.sgx` `.pce` `.cue` `.ccd` `.chd` `.zip` `.7z`                              | —                                                                                           |
| ColecoVision            | Gearcoleco (libretro)                                | `Roms/ColecoVision (COLECO)/`                     | `.col` `.bin` `.rom` `.zip` `.7z`                                            | `colecovision.rom` (or `coleco.rom`)                                                        |
| Intellivision           | FreeIntv (libretro)                                  | `Roms/Intellivision (INTV)/`                      | `.int` `.bin` `.rom` `.zip` `.7z`                                            | `exec.bin` `grom.bin`                                                                       |
| MSX                     | blueMSX (libretro)                                   | `Roms/MSX (MSX)/`                                 | `.mx1` `.mx2` `.dsk` `.rom` `.cas` `.zip` `.7z`                              | none to add (`Machines/` `Databases/` ship in the image)                                    |
| Odyssey 2               | O2EM (libretro)                                      | `Roms/Odyssey 2 (O2)/`                            | `.bin` `.zip` `.7z`                                                          | `o2rom.bin`                                                                                 |
| Vectrex                 | vecx (libretro)                                      | `Roms/Vectrex (VEC)/`                             | `.vec` `.bin` `.gam` `.zip` `.7z`                                            | —                                                                                           |
| Neo Geo (AES/MVS)       | FinalBurn Neo (libretro)                             | `Roms/FBNeo (FBNEO)/`                             | `.zip` `.7z`                                                                 | `neogeo.zip` in `Bios/`, `Bios/fbneo/`, or `Bios/FBNEO/`                                    |
| Arcade                  | MAME 2003-Plus (libretro)                            | `Roms/MAME (MAME)/`                               | `.zip` `.7z`                                                                 | BIOS zips in `Bios/`, `Bios/MAME/`, or `Bios/mame2003-plus/`                                |
| Neo Geo CD              | NeoCD (libretro)                                     | `Roms/Neo Geo CD (NEOCD)/`                        | `.cue` `.iso` `.chd`                                                         | `neocd/neocd.bin`, `neocd/uni-bioscd.rom`, or `neocd/neocd_z.rom` (`Bios/` root also works) |
| Neo Geo Pocket          | Beetle NGP (libretro)                                | `Roms/Neo Geo Pocket (NGP)/`                      | `.ngp` `.ngc` `.zip` `.7z`                                                   | —                                                                                           |
| WonderSwan              | Beetle WonderSwan (libretro)                         | `Roms/WonderSwan (WS)/`                           | `.ws` `.wsc` `.zip` `.7z`                                                    | —                                                                                           |
| Virtual Boy             | Beetle VB (libretro)                                 | `Roms/Virtual Boy (VB)/`                          | `.vb` `.zip` `.7z`                                                           | —                                                                                           |
| Pokémon Mini            | PokeMini (libretro)                                  | `Roms/Pokemon Mini (PKM)/`                        | `.min` `.zip` `.7z`                                                          | `bios.min` (optional)                                                                       |
| Atari 2600              | Stella (libretro)                                    | `Roms/Atari 2600 (A26)/`                          | `.a26` `.bin` `.zip` `.7z`                                                   | —                                                                                           |
| Atari 5200              | a5200 (libretro)                                     | `Roms/Atari 5200 (A5200)/`                        | `.a52` `.bin` `.zip` `.7z`                                                   | `5200.rom`                                                                                  |
| Atari 7800              | ProSystem (libretro)                                 | `Roms/Atari 7800 (A78)/`                          | `.a78` `.bin` `.zip` `.7z`                                                   | `7800 BIOS (U).rom`                                                                         |
| Atari 8-bit             | Atari800 (libretro)                                  | `Roms/Atari 8-bit (A800)/`                        | `.atr` `.atx` `.rom` `.xex` `.cas` `.car` `.zip` `.7z`                       | `ATARIOSB.ROM` `ATARIXL.ROM`                                                                |
| Atari ST                | Hatari (libretro)                                    | `Roms/Atari ST (ST)/`                             | `.st` `.msa` `.stx` `.dim` `.ipf` `.zip` `.7z`                               | `tos.img` or EmuTOS `etos*.img` (in `Bios/` or `Bios/ST/`)                                  |
| Atari Lynx              | Handy (libretro)                                     | `Roms/Atari Lynx (LYNX)/`                         | `.lnx` `.lyx` `.bll` `.o` `.zip` `.7z`                                       | `lynxboot.img`                                                                              |
| 3DO                     | Opera (libretro)                                     | `Roms/3DO (3DO)/`                                 | `.iso` `.chd` `.cue`                                                         | `panafz10.bin`                                                                              |
| DOS                     | DOSBox Pure (libretro)                               | `Roms/DOS (DOS)/`                                 | `.exe` `.com` `.bat` `.dos` `.dosz` `.zip` `.iso` `.cue` `.m3u` `.m3u8`      | —                                                                                           |
| PlayStation             | PCSX ReARMed (libretro)                              | `Roms/Sony PlayStation (PS)/`                     | `.cue` `.chd` `.m3u` `.pbp` `.iso` `.ccd` `.img` `.toc`                      | `scph5500.bin` / `scph5501.bin` / `scph5502.bin`                                            |
| PlayStation 2           | AetherSX2                                            | `Roms/Sony PlayStation 2 (PS2)/`                  | `.iso` `.chd` `.cso` `.mdf` `.nrg` `.bin` `.img` `.dump` `.gz` `.m3u` `.elf` | BIOS dumps in `Bios/PS2/` (not in the ROM folder)                                           |
| Nintendo 64             | Mupen64Plus-Next (libretro)                          | `Roms/Nintendo 64 (N64)/`                         | `.z64` `.n64` `.v64` `.zip` `.7z`                                            | —                                                                                           |
| GameCube                | Dolphin                                              | `Roms/Nintendo GameCube (GC)/`                    | `.gcm` `.iso` `.gcz` `.ciso` `.wbfs` `.rvz` `.m3u` `.elf` `.dol`             | `GC/USA/IPL.bin` (optional; also EUR/JAP; `Bios/IPL.bin` or `Bios/GC/IPL.bin` also works)   |
| Wii                     | Dolphin                                              | `Roms/Nintendo Wii (WII)/`                        | `.gcm` `.iso` `.wbfs` `.gcz` `.ciso` `.rvz` `.wad` `.m3u` `.elf` `.dol`      | same IPL (optional); extra files in `Bios/WII`                                              |
| Saturn                  | YabaSanshiro (libretro)                              | `Roms/Sega Saturn (SATURN)/`                      | `.cue` `.ccd` `.chd` `.iso`                                                  | `saturn_bios.bin`                                                                           |
| TIC-80                  | TIC-80 (libretro)                                    | `Roms/TIC-80 (TIC)/`                              | `.tic`                                                                       | —                                                                                           |
| Pico-8                  | Official PICO-8 (you add it); alt: fake-08           | `Roms/Pico-8 (PICO)/`                             | `.p8` `.png` `.zip`                                                          | `PICO/pico8_64` and `PICO/pico8.dat`                                                        |
| Pico-8 (fake-08)        | fake-08 (libretro); alt: official PICO-8             | `Roms/Pico-8 fake-08 (P8)/`                       | `.p8` `.png` `.zip`                                                          | — (the alt needs the PICO pair)                                                             |
| PSP                     | PPSSPP                                               | `Roms/Sony PlayStation Portable (PSP)/`           | `.iso` `.cso` `.pbp` `.chd`                                                  | —                                                                                           |
| Dreamcast               | Flycast                                              | `Roms/Sega Dreamcast (DC)/`                       | `.cdi` `.gdi` `.cue` `.chd` `.m3u`                                           | `dc_boot.bin` `dc_flash.bin` in `Bios/DC/` or `Bios/`                                       |
| Nintendo DS             | DraStic                                              | `Roms/Nintendo DS (NDS)/`                         | `.nds` `.zip` `.7z`                                                          | —                                                                                           |
| Amiga                   | Amiberry                                             | `Roms/Commodore Amiga (AMIGA)/`                   | `.adf` `.ipf` `.hdf` `.lha` `.cue` `.iso` `.chd` `.zip`                      | kickstarts optional; AROS ships in the image                                                |
| Doom                    | GZDoom                                               | `Roms/Doom (DOOM)/`                               | `.wad` `.iwad` `.pwad` `.pk3`                                                | —                                                                                           |
| Flash                   | Ruffle Handheld (SilverPsychoo)                      | `Roms/Flash (FLASH)/`                             | `.swf`                                                                       | —                                                                                           |
| Ports                   | PortMaster                                           | `Roms/Ports (PORTS)/`                             | `.sh` only                                                                   | —                                                                                           |
| RPG Maker 2000/2003     | EasyRPG Player (libretro)                            | `Roms/RPG Maker 2000-2003 (EASYRPG)/`             | `.zip` `.lzh` `.ldb` `.easyrpg`; folders with `RPG_RT.ldb` or `*.easyrpg`    | `rtp/2000` `rtp/2003` (optional)                                                            |
| RPG Maker XP / VX / Ace | mkxp-z (libretro)                                    | `Roms/RPG Maker XP-VX-Ace (MKXPZ)/`               | `.rxproj` `.rvproj` `.rvproj2` `.mkxp` `.mkxpz` `.zip` `.7z`                 | `mkxp-z/RTP` (optional)                                                                     |
| ScummVM                 | ScummVM                                              | `Roms/ScummVM (SCUMMVM)/`                         | `.scummvm` `.svm` `.zip`; game folders                                       | —                                                                                           |
| OpenBOR                 | OpenBOR                                              | `Roms/OpenBOR (OPENBOR)/`                         | `.pak`                                                                       | —                                                                                           |
| Daphne                  | Hypseus Singe                                        | `Roms/Daphne (DAPHNE)/`                           | `.txt` `.daphne` `.singe`                                                    | —                                                                                           |
| Windows                 | Wine (x86-64 via Box64, in its own temporary Weston) | `Roms/Windows (WINE)/`                            | `.exe` `.msi` `.bat` `.cmd`                                                  | —                                                                                           |

- **PSP:** PPSSPP renders with OpenGL, or with Vulkan when you pick it in PPSSPP and the Mali driver is active.
- **Pico-8:** native PICO-8 uses the Raspberry Pi build you bought from Lexaloffle. Zlyme does not include or download those files. Fake-08 does not need them. Setup and Splore: [user guide](docs/USER_GUIDE.md#pico-8-and-splore).
- **Multi-disc games** use an `.m3u` playlist: [user guide](docs/USER_GUIDE.md#multi-disc-games).

## Custom paks

You can add your own systems and tools as paks. An update replaces only the stock pak names and leaves extra paks alone. Stock NextUI paks usually need changes before they run on Zlyme. How to add a system or a tool: [user guide](docs/USER_GUIDE.md#custom-paks).

## Building Zlyme

Docker is required.

```sh
cp storage.sh.example storage.sh   # optional; set local paths
./build.sh --config zlyme_my355_defconfig
```

The image lands in `output/images/`. `./build.sh --help` lists every option. To ship a pak in the OS, drop it under `package/system/nextui/paks/Emus` or `package/system/nextui/paks/Tools` in this tree.

- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): build commands, defconfigs, caches, and package policy.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): the maintainer index for patches, package updates, the NextUI fork, and releases.
- [AGENTS.md](AGENTS.md): how changes to this tree are made.

Pull requests and other contributions are welcome.

## Documentation

- This README: what Zlyme is, installation, updates, controls, and the systems table.
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md): day-to-day use. Libraries, BIOS and saves, PICO-8, joysticks, Settings, Tools, logs, and custom paks.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): what the system is and why.
- [docs/OPERATIONS.md](docs/OPERATIONS.md): the maintainer runbook for a live Miyoo Flip and recovery.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): building.
- [docs/DEVICE_PORTING.md](docs/DEVICE_PORTING.md): how a future device would be added. It does not mean another device is supported.
- [docs/UPSTREAMS.md](docs/UPSTREAMS.md): where versions and patches come from.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): the maintainer index.
- [Miyoo Flip wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering): kernel, boot, and flashing detail, and the hardware reference.

## Thanks

- [Sundownersport](https://github.com/Sundownersport) and the community behind [SpruceOS](https://spruceui.github.io/) for their continuing work and support.
- The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI), a fork of [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman). SD multiboot (repaired preloader) is derived from [apommel](https://github.com/apommel)’s work in [baseos-my355](https://github.com/apommel/baseos-my355).
- Flash games run on [Ruffle Handheld](https://github.com/SilverPsychoo/Ruffle-Handheld) v4.2 by SilverPsychoo.
- The joystick calibration workflow is based in part on Joe's Calibrage by Kevin Vranken, MIT.

## License

See [LICENSE](LICENSE). Original Zlyme glue is MIT. This tree is **not** one license. NextUI (LoveRetro) is PolyForm Noncommercial 1.0.0 and must stay that way; it is a fork of MinUI by Shaun Inman. minui-list and minui-presenter are MIT (Jose Diaz-Gonzalez) and, on this image, link NextUI. Each package and pak ships its own terms.
