<img src="package/system/nextui/res/branding/zlyme_slime_loop.gif" alt="Zlyme" width="887">

**Low latency. High viscosity.**

Zlyme is a custom OS for the **Miyoo Flip** based on buildroot, running mainline kernel and latest software available. It's engineered to ooze, cultured for speed. Hardware facts come from this device, emulator recipes are harvested where they already exist. The set is curated so it fits the Flip, instead of shipping a hundred cores nobody on this board will use. 

The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI) (itself from [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman)). There is no desktop and no compositor. It is engineered for fast boot.

**Everything on the device works:** Wi-Fi, Bluetooth (including audio and controller), HDMI, sleep, the lid, analog sticks, the headphone jack, USB OTG, and both SD slots are supported. It feature a dynamic scaling ram driver to save battery when playing light games, does not drain while off.

Pull requests and other contributions are welcome, if needed other systems will be supported.

Kernel, boot, and flashing detail lives in the [Miyoo Flip wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering).

## Features

Userspace is compiled at the fastest setting this CPU will take (`-O3`). A few libretro cores that miscompile are pinned back to `-O2` so they stay correct. The kernel stays on its usual performance profile. It offers both mali and panfrost (only mali supports Vulkan as of now). Optimized core pinning and per-emulator performance settings battle-tested by the friends at [SpruceOS](https://spruceui.github.io/).  

“It’s not buttery smooth. It’s slime-smooth.”

### Controls

**Launcher**

- A open, B back
- MENU tap = quick menu
- Vol = volume
- **MENU+Vol** = brightness
- **MENU+Y** = emulator / governor for the highlighted console, folder, or ROM
- Power = sleep

**In a pak / game**

- **MENU+Start** closes whatever is running (libretro, standalones, PortMaster, Pico-8, Tools)
- MENU tap = RetroArch RGUI; standalones keep their own menu

Speaker vs jack is automatic (`zlyme-jackd`). Bluetooth audio follows the headset connect. `zlyme-audio` stays on the CLI for debug.

### Tools

Each community pak below was ported (paths, Flip joystick, this image’s binaries).

- **Settings** — Wi-Fi, Bluetooth, SSH, Samba, Syncthing, GPU, HDMI, OTG, second SD, governors, undervolt, backup, **Update**. About → System logs writes `/storage/.logs`.
- **Artwork Scraper** — matches ROM names to box art and downloads it. From [minui-artwork-scraper-pak](https://github.com/josegonzalez/minui-artwork-scraper-pak).
- **ScrapeGoat** — ScreenScraper metadata and images. From [nextui-scrapegoat-pak](https://github.com/Helaas/nextui-scrapegoat-pak). Requires a [Screenscraper.fr](http://Screenscraper.fr) account. 
- **Overlays** — browse and install community bezels. From [nextui-community-overlays](https://github.com/LoveRetro/nextui-community-overlays).
- **Moonlight** — stream a PC game to the Flip. From [nextui-moonlight-pak](https://github.com/richieszemeredi/nextui-moonlight-pak).
- **PortMaster** — install game ports. From [PortMaster-GUI](https://github.com/PortsMaster/PortMaster-GUI).
- **Files** — browse the card.  [vtree](https://github.com/MustardOS/vtree).
- **Settings → System → Joysticks** — stick test, manual calibration, live deadzone, and Rumble Strength. A fresh install uses displayed 30% motor gain. A saved value is kept. **Settings → System → Haptic feedback** defaults to on and only turns NextUI's own pulses on or off. The calibration workflow is based in part on Joe's Calibrage by Kevin Vranken, MIT.

Zlyme uses its own Miyoo Flip gamepad driver. Buttons are GPIO-backed. The two analog sticks use the Flip UART protocol. Settings provides stick testing, calibration, a deadzone for each stick, Rumble Strength, and Test Rumble. Rumble is standard Linux force feedback. Switch replacement sticks are not called physically validated.

**Settings → Update** pulls a GitHub release (or prerelease) tar, shows notes, draws a progress bar, and only queues the file after sha256 matches.

### Install

The Flip will not boot an SD OS until you change how it starts. Without one of the steps below, it keeps booting stock from internal storage and ignores the card.

1. **apommel-multiboot** (recommended). Repairs the vendor preloader. No card → stock. Bootable card → that OS. Follow the [wiki how-to](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/sd-multiboot-apommel.md). The on-device app is [apommel-multiboot](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/tree/main/preloader-stock-rocknix/App/apommel-multiboot) in that repo. See the wiki for the supported OS list.
2. **Erase the preloader.** Then the Flip always boots from SD (or enter MASKROM mode if none is inserted). Wiki: [stock ↔ SD-boot without opening the device](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/stock-rocknix-without-disassembly.md).

Download latest release .img file.

Flash `zlyme.img` onto a dedicated OS card (Balena Etcher or any image writer). Do not flash over a card that already has games. Put that card in the **right** slot (next to power).

  
Later updates are **Settings → Update**.  
Manual updates: copy a finished `zlyme-my355-*.tar` into `/storage/.update` and reboot. 

## Systems

Games live on the **ZLYME** partition (mounted at `/storage`). NextUI only lists a system if that folder exists and it contains ROMs. The Roms folders are created at boot, use the hyphenated names in the table.

A second card in the other slot (or an OTG usb stick) is picked up if it has a `roms/` or `Roms/` folder using the **same** `Pretty (TAG)` **names** as the table. Settings → About → System logs writes boot files and a per-pak `TAG.log` to `/storage/.logs` (off by default). 

Box art is NextUI’s `{folder}/.media/{rom stem}.png` (same basename as the game file or playlist, `.png`). 


| System                  | Emulator                         | Folder                                            | Files                                                                        | Bios                                             |
| ----------------------- | -------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------ |
| NES                     | Nestopia (libretro)              | `Roms/Nintendo Entertainment System (FC)/`        | `.nes` `.unif` `.unf` `.fds` `.zip` `.7z`                                    | `disksys.rom` (FDS, optional)                    |
| Game Boy                | Gambatte (libretro)              | `Roms/Game Boy (GB)/`                             | `.gb` `.zip` `.7z`                                                           | `gb_bios.bin` (optional)                         |
| Game Boy Color          | Gambatte (libretro)              | `Roms/Game Boy Color (GBC)/`                      | `.gbc` `.gb` `.zip` `.7z`                                                    | `gbc_bios.bin` (optional)                        |
| Game Boy Advance        | gpSP (libretro)                  | `Roms/Game Boy Advance (GBA)/`                    | `.gba` `.zip` `.7z`                                                          | `gba_bios.bin`                                   |
| SNES                    | Mednafen SuperFaust (libretro)   | `Roms/Super Nintendo Entertainment System (SFC)/` | `.smc` `.sfc` `.fig` `.swc` `.bsx` `.zip` `.7z`                              | —                                                |
| Master System           | Genesis Plus GX (libretro)       | `Roms/Sega Master System (MS)/`                   | `.sms` `.bin` `.zip` `.7z`                                                   | `bios_*.sms` (optional)                          |
| Game Gear               | Genesis Plus GX (libretro)       | `Roms/Sega Game Gear (GG)/`                       | `.gg` `.bin` `.zip` `.7z`                                                    | `bios.gg` (optional)                             |
| SG-1000                 | Genesis Plus GX (libretro)       | `Roms/Sega SG-1000 (SG1000)/`                     | `.sg` `.bin` `.zip` `.7z`                                                    | —                                                |
| Mega Drive / Genesis    | PicoDrive (libretro)             | `Roms/Sega Genesis (MD)/`                         | `.md` `.smd` `.gen` `.bin` `.zip` `.7z`                                      | `bios_CD_U.bin` / `E` / `J` (Mega CD, optional)  |
| 32X                     | PicoDrive (libretro)             | `Roms/Sega 32X (32X)/`                            | `.32x` `.smd` `.md` `.bin` `.zip` `.7z`                                      | same Mega CD files (optional)                    |
| PC Engine               | Mednafen PCE Fast (libretro)     | `Roms/PC Engine (PCE)/`                           | `.pce` `.cue` `.ccd` `.iso` `.img` `.chd` `.sgx` `.zip` `.7z` `.m3u`         | `syscard3.pce` (CD, optional)                    |
| SuperGrafx              | Mednafen SuperGrafx (libretro)   | `Roms/SuperGrafx (SGX)/`                          | `.sgx` `.pce` `.cue` `.ccd` `.chd` `.zip` `.7z`                              | —                                                |
| ColecoVision            | Gearcoleco (libretro)            | `Roms/ColecoVision (COLECO)/`                     | `.col` `.bin` `.rom` `.zip` `.7z`                                            | `colecovision.rom`                               |
| Intellivision           | FreeIntv (libretro)              | `Roms/Intellivision (INTV)/`                      | `.int` `.bin` `.rom` `.zip` `.7z`                                            | `exec.bin` `grom.bin`                            |
| MSX                     | blueMSX (libretro)               | `Roms/MSX (MSX)/`                                 | `.mx1` `.mx2` `.dsk` `.rom` `.cas` `.zip` `.7z`                              | `Machines/` `Databases/` (seeded)                |
| Odyssey 2               | O2EM (libretro)                  | `Roms/Odyssey 2 (O2)/`                            | `.bin` `.zip` `.7z`                                                          | `o2rom.bin`                                      |
| Vectrex                 | vecx (libretro)                  | `Roms/Vectrex (VEC)/`                             | `.vec` `.bin` `.gam` `.zip` `.7z`                                            | —                                                |
| Neo Geo (AES/MVS)       | FinalBurn Neo (libretro)         | `Roms/FBNeo (FBNEO)/`                             | `.zip` `.7z`                                                                 | `fbneo/neogeo.zip`                               |
| Arcade                  | MAME 2003-Plus (libretro)        | `Roms/MAME (MAME)/`                               | `.zip` `.7z`                                                                 | BIOS zips in `Bios/MAME/`                        |
| Neo Geo CD              | NeoCD (libretro)                 | `Roms/Neo Geo CD (NEOCD)/`                        | `.cue` `.iso` `.chd`                                                         | `neocd/neocd.bin` or `neocd/uni-bioscd.rom`      |
| Neo Geo Pocket          | Mednafen NGP (libretro)          | `Roms/Neo Geo Pocket (NGP)/`                      | `.ngp` `.ngc` `.zip` `.7z`                                                   | —                                                |
| WonderSwan              | Mednafen WonderSwan (libretro)   | `Roms/WonderSwan (WS)/`                           | `.ws` `.wsc` `.zip` `.7z`                                                    | —                                                |
| Virtual Boy             | Mednafen VB (libretro)           | `Roms/Virtual Boy (VB)/`                          | `.vb` `.zip` `.7z`                                                           | —                                                |
| Pokémon Mini            | PokeMini (libretro)              | `Roms/Pokemon Mini (PKM)/`                        | `.min` `.zip` `.7z`                                                          | `bios.min` (optional)                            |
| Atari 2600              | Stella (libretro)                | `Roms/Atari 2600 (A26)/`                          | `.a26` `.bin` `.zip` `.7z`                                                   | —                                                |
| Atari 5200              | a5200 (libretro)                 | `Roms/Atari 5200 (A5200)/`                        | `.a52` `.bin` `.zip` `.7z`                                                   | `5200.rom`                                       |
| Atari 7800              | ProSystem (libretro)             | `Roms/Atari 7800 (A78)/`                          | `.a78` `.bin` `.zip` `.7z`                                                   | `7800 BIOS (U).rom`                              |
| Atari 8-bit             | Atari800 (libretro)              | `Roms/Atari 8-bit (A800)/`                        | `.atr` `.atx` `.rom` `.xex` `.cas` `.car` `.zip` `.7z`                       | `ATARIOSB.ROM` `ATARIXL.ROM`                     |
| Atari ST                | Hatari (libretro)                | `Roms/Atari ST (ST)/`                             | `.st` `.msa` `.stx` `.dim` `.ipf` `.zip` `.7z`                               | `tos.img`                                        |
| Atari Lynx              | Handy (libretro)                 | `Roms/Atari Lynx (LYNX)/`                         | `.lnx` `.lyx` `.bll` `.o` `.zip` `.7z`                                       | `lynxboot.img`                                   |
| 3DO                     | Opera (libretro)                 | `Roms/3DO (3DO)/`                                 | `.iso` `.chd` `.cue`                                                         | `panafz10.bin`                                   |
| DOS                     | DOSBox Pure (libretro)           | `Roms/DOS (DOS)/`                                 | `.exe` `.com` `.bat` `.dos` `.dosz` `.zip` `.iso` `.cue` `.m3u` `.m3u8`      | —                                                |
| PlayStation             | PCSX ReARMed (libretro)          | `Roms/Sony PlayStation (PS)/`                     | `.cue` `.chd` `.m3u` `.pbp` `.iso` `.ccd` `.img` `.toc`                      | `scph5500.bin` / `scph5501.bin` / `scph5502.bin` |
| PlayStation 2           | AetherSX2                        | `Roms/Sony PlayStation 2 (PS2)/`                  | `.iso` `.chd` `.cso` `.mdf` `.nrg` `.bin` `.img` `.dump` `.gz` `.m3u` `.elf` | `PS2/` BIOS dumps (not in the ROM folder)        |
| Nintendo 64             | Mupen64Plus-Next (libretro)      | `Roms/Nintendo 64 (N64)/`                         | `.z64` `.n64` `.v64` `.zip` `.7z`                                            | —                                                |
| GameCube                | Dolphin                          | `Roms/Nintendo GameCube (GC)/`                    | `.gcm` `.iso` `.gcz` `.ciso` `.wbfs` `.rvz` `.m3u` `.elf` `.dol`             | `GC/USA/IPL.bin` (optional; also EUR/JAP)        |
| Wii                     | Dolphin                          | `Roms/Nintendo Wii (WII)/`                        | `.iso` `.wbfs` `.gcz` `.ciso` `.rvz` `.wad` `.m3u` `.elf` `.dol`             | same IPL (optional); extra files in `Bios/WII`   |
| Saturn                  | YabaSanshiro (libretro)          | `Roms/Sega Saturn (SATURN)/`                      | `.cue` `.ccd` `.chd` `.iso`                                                  | `saturn_bios.bin`                                |
| TIC-80                  | TIC-80 (libretro)                | `Roms/TIC-80 (TIC)/`                              | `.tic`                                                                       | —                                                |
| Pico-8                  | Official Pico-8 (add `pico8_64`) | `Roms/Pico-8 (PICO)/`                             | `.p8` `.png` `.zip`                                                          | `PICO/pico8_64` `PICO/pico8.dat`                 |
| Pico-8 (fake-08)        | fake-08 (libretro)               | `Roms/Pico-8 fake-08 (P8)/`                       | `.p8` `.png` `.zip`                                                          | —                                                |
| PSP                     | PPSSPP                           | `Roms/Sony PlayStation Portable (PSP)/`           | `.iso` `.cso` `.pbp` `.chd`                                                  | —                                                |
| Dreamcast               | Flycast                          | `Roms/Sega Dreamcast (DC)/`                       | `.cdi` `.gdi` `.cue` `.chd` `.m3u`                                           | `DC/dc_boot.bin` `DC/dc_flash.bin`               |
| Nintendo DS             | DraStic                          | `Roms/Nintendo DS (NDS)/`                         | `.nds` `.zip` `.7z`                                                          | —                                                |
| Amiga                   | Amiberry                         | `Roms/Commodore Amiga (AMIGA)/`                   | `.adf` `.ipf` `.hdf` `.lha` `.cue` `.iso` `.chd` `.zip`                      | kickstarts in `Bios/` (AROS ships)               |
| Doom                    | GZDoom                           | `Roms/Doom (DOOM)/`                               | `.wad` `.iwad` `.pwad` `.pk3`                                                | —                                                |
| Ports                   | PortMaster                       | `Roms/Ports (PORTS)/`                             | `.sh` only                                                                   | —                                                |
| RPG Maker 2000/2003     | EasyRPG Player (libretro)        | `Roms/RPG Maker 2000-2003 (EASYRPG)/`             | `.zip` `.lzh` `.ldb` `.easyrpg`; folders with `RPG_RT.ldb` or `*.easyrpg`    | `rtp/2000` `rtp/2003` (optional)                 |
| RPG Maker XP / VX / Ace | mkxp-z (libretro)                | `Roms/RPG Maker XP-VX-Ace (MKXPZ)/`               | `.rxproj` `.rvproj` `.rvproj2` `.mkxp` `.mkxpz` `.zip` `.7z`                 | `mkxp-z/RTP` (optional)                          |
| ScummVM                 | ScummVM                          | `Roms/ScummVM (SCUMMVM)/`                         | `.scummvm` `.svm` `.zip`; game folders                                       | —                                                |
| OpenBOR                 | OpenBOR                          | `Roms/OpenBOR (OPENBOR)/`                         | `.pak`                                                                       | —                                                |
| Daphne                  | Hypseus Singe                    | `Roms/Daphne (DAPHNE)/`                           | `.txt` `.daphne` `.singe`                                                    | —                                                |
| Windows                 | Wine (box64)                     | `Roms/Windows (WINE)/`                            | `.exe` `.msi` `.bat` `.cmd`                                                  | —                                                |




### Multi-disc (`.m3u`)

NextUI lists the `.m3u` as the game. Put the discs in a folder with the **same name** as the playlist (no leading `.` or `_`):

```
Roms/Sony PlayStation (PS)/
  Game Name.m3u
  Game Name/
    Game Name (Disc 1).chd
    Game Name (Disc 2).chd
  .media/Game Name.png
```

Playlist lines are paths **relative to the** `.m3u`, Unix newlines, no leading slash:

```
Game Name/Game Name (Disc 1).chd
Game Name/Game Name (Disc 2).chd
```

Open the `.m3u`, not a CHD inside the folder, so RetroArch Disk Control can swap discs. Saturn and Amiga do not use `.m3u` on this image. PC Engine, DOS, Dreamcast, and PlayStation do.

### User Systems and Tools and the Right to Experiment

Stock copies live on the card at `Tools/my355/` and `Emus/my355/`. 

OTA replaces only pak **names that exist in the image**. Extra folders you add are left alone. Example: editing `GBA.pak` is overwritten on the next Update; renaming it to `GBA2.pak` survives, but games must sit in `Roms/… (GBA2)/`. The same rule is `TAG.pak` ↔ `Roms/… (TAG)/` for every system.

To add support to new **systems** put an executable `Emus/my355/TAG.pak/launch.sh` plus a non-empty `Roms/Pretty Name (TAG)/`. The tag in parentheses is the pak name. `launch.sh` receives the ROM path; libretro examples are the existing paks (`ra-run -L …`).

On the other hand, to add a **tool (or NextUI .pak)**: `Tools/my355/My Tool.pak/launch.sh`. It shows up under Tools after a restart of the list. Standard nextUI paks are not supported but you can adapt them in a breeze.

To **ship** a pak in the OS, drop it under `package/system/nextui/paks/Emus` or `paks/Tools` in this tree.

**Logs.** Settings → About → System logs (off unless you turn it on). That writes `/storage/.logs`: `dmesg.txt` / `dmesg-boot.txt`, `boot-timing.txt`, session `next.txt`, and one `TAG.log` per pak (`FC.log`, `PS2.log`, `Settings.log`, …). RetroArch cores use `--log-file`; standalones capture stdout. Copy that folder off the card (or `/storage/.logs` over SSH) when something fails. 

## Build

Docker is required.

```sh
cp storage.sh.example storage.sh   # optional; set local paths
./build.sh --config zlyme_my355_defconfig
```

The image lands in `output/images/`. With no `--config`, `./build.sh` builds the minimal image. Options:


| Flag              | What it does                                             |
| ----------------- | -------------------------------------------------------- |
| `--minimal`       | `zlyme_my355_minimal_defconfig` (bootable, no emulators) |
| `--config NAME`   | named defconfig (`zlyme_my355_defconfig` is the product image) |
| `--shell`         | interactive shell in the build container                 |
| `--check`         | print paths and change nothing                           |
| `--loops`         | detach loop devices this build leaked                    |
| `--clean`         | delete the build tree (keeps downloads and ccache)       |
| `--rebuild-image` | rebuild the `zlyme-build` container even if it exists    |
| `-h`, `--help`    | usage                                                    |


With no make target, it builds the image. Any extra arguments are passed to Buildroot `make`, so these work:

```sh
./build.sh --config zlyme_my355_defconfig menuconfig
./build.sh --config zlyme_my355_defconfig linux-rebuild
./build.sh --config zlyme_my355_defconfig nextui-rebuild
./build.sh --config zlyme_my355_defconfig savedefconfig
```

A full image write goes to `output/build.log` (overwritten each run). Watch it with `less +F output/build.log`. Do not start a second `./build.sh` on the same `output/`. 

## Thanks

[Sundownersport](https://github.com/Sundownersport) and the community behind [SpruceOS](https://spruceui.github.io/) for their continuing work and support.  
The frontend is based on [NextUI](https://github.com/LoveRetro/NextUI), a fork of [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman). SD multiboot (repaired preloader) is derived from [apommel](https://github.com/apommel)’s work in [baseos-my355](https://github.com/apommel/baseos-my355). 

## License

See [LICENSE](LICENSE). Original Zlyme glue is MIT. This tree is **not** one license. NextUI (LoveRetro) is PolyForm Noncommercial 1.0.0 and must stay that way; it is a fork of MinUI by Shaun Inman. minui-list and minui-presenter are MIT (Jose Diaz-Gonzalez) and, on this image, link NextUI. Each package and pak ships its own terms.