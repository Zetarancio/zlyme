# Zlyme user guide

The [README](../README.md) covers what Zlyme is, how to install it, where games go, and how to update. This guide is the rest: the [systems table](#systems-and-emulators), saves, settings, and the recovery page. Device recovery for maintainers is in [OPERATIONS.md](OPERATIONS.md). Dated measurements live on the [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering).

## Card preparation and preloader recovery

A normal install is the [README install](../README.md#install). Stock runs `miyoo355_fw.img` once so the right-hand card can boot. An update does not do that again, and it does not write the Flip's internal flash.

### Images to manipulate the preloader

The release page also has three helpers for a Flip that still starts its stock system or for other projects that are needed: `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, and `miyoo355_fw-restore.img`. They are not part of a Zlyme update. Rename the one you need to `miyoo355_fw.img`, put that card where stock can see it, and boot stock.

`miyoo355_fw-restore.img` undoes the SD-boot repair. It is not how you leave an armed recovery preloader. Stock does not start in that state. Use **Disarm MASKROM recovery** below, or the physical MASKROM button if no right-hand Zlyme card will boot.

After the MASKROM or restore helper finishes, power off before you change cards. It does not reboot itself. What each helper writes, and which preloader revisions it was checked against, is on the wiki's [preloader tools](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/preloader-tools.md) page. The SD-boot repair itself is [SD multiboot](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/sd-multiboot-apommel.md).

### Advanced → Recovery

Open Settings → System → Advanced → Recovery. These rows write the internal flash. They are not part of installing Zlyme. Each confirmation is a list that starts on Cancel. B goes back. A failed write stays on the result so you can try again.

After a successful arm, disarm, or stock restore, the page offers Shut down and Restart. Opening that choice again does not write the flash a second time until you leave Settings and come back. **Restart is a normal reboot. It does not enter MASKROM.**

**Preloader status** shows Preloader, Recovery, Source backup, Stock restore, and Battery. `Normal` / `Ready` means the current preloader matches the saved source and a recovery image is ready. `Recovery armed` / `Armed` means the recovery preloader is installed. Unknown or Invalid is not a healthy boot.

**Arm MASKROM recovery** writes the recovery preloader to internal NAND. A bootable card in the right-hand slot still boots. With no bootable card there, the next power-on enters MASKROM. Internal stock boot stays off until you disarm. The last confirmation is `ARM MASKROM RECOVERY`. To enter MASKROM, shut the Flip down, take out the right-hand card, and power on.

**Disarm MASKROM recovery** writes back the exact image saved when you armed recovery. That is the preloader you had then, not the original Miyoo preloader. The last confirmation is `DISARM MASKROM RECOVERY`. If recovery is not armed, the row refuses and does not offer shut down or restart.

**Restore stock preloader** is a different write. It prefers this unit's own `mtd5-original-<sha256>.img` on the boot card. The hash in the name has to match the file, and the DDR initializer in that backup has to match the preloader already installed. If that backup is missing, Restore can use the stock image shipped with Zlyme, and only for the one preloader revision that image belongs to. The shipped image is not your unit's backup. Anything else is refused. There is no force option. If the new image does not verify, Zlyme tries to put the saved current preloader back. That is a failed restore. The last confirmation is `RESTORE STOCK PRELOADER`. The battery has to be at least 25%, unless a charger is connected. You still need a bootable card in the right-hand slot when the Flip should start Zlyme afterwards.

Erase is not in this menu. Wiping the internal preloader is not MASKROM recovery. If no right-hand card will boot, the physical MASKROM button is the fallback. That procedure is on the wiki's [flashing](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/flashing.md) page, and the recovery preloader itself is on [recovery preloader](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/recovery-preloader.md).

## Systems and emulators

Folders sit under `Roms/` on any library. BIOS names are inside `Bios/` on any mounted library. "alt:" marks an emulator you can switch to from the MENU+Y Emulator row.


| System                  | Emulator                                    | Folder                                            | Files                                                                        | Bios                                                                                        |
| ----------------------- | ------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| NES                     | Nestopia (libretro)                         | `Roms/Nintendo Entertainment System (FC)/`        | `.nes` `.unif` `.unf` `.fds` `.zip` `.7z`                                    | `disksys.rom` (FDS, optional)                                                               |
| Game Boy                | Gambatte (libretro)                         | `Roms/Game Boy (GB)/`                             | `.gb` `.zip` `.7z`                                                           | `gb_bios.bin` (optional)                                                                    |
| Game Boy Color          | Gambatte (libretro)                         | `Roms/Game Boy Color (GBC)/`                      | `.gbc` `.gb` `.zip` `.7z`                                                    | `gbc_bios.bin` (optional)                                                                   |
| Game Boy Advance        | gpSP (libretro)                             | `Roms/Game Boy Advance (GBA)/`                    | `.gba` `.zip` `.7z`                                                          | `gba_bios.bin`                                                                              |
| SNES                    | Beetle Supafaust (libretro)                 | `Roms/Super Nintendo Entertainment System (SFC)/` | `.smc` `.sfc` `.fig` `.swc` `.bsx` `.zip` `.7z`                              | —                                                                                           |
| Master System           | Genesis Plus GX (libretro); alt: PicoDrive  | `Roms/Sega Master System (MS)/`                   | `.sms` `.bin` `.zip` `.7z`                                                   | `bios_*.sms` (optional)                                                                     |
| Game Gear               | Genesis Plus GX (libretro); alt: PicoDrive  | `Roms/Sega Game Gear (GG)/`                       | `.gg` `.bin` `.zip` `.7z`                                                    | `bios.gg` (optional)                                                                        |
| SG-1000                 | Genesis Plus GX (libretro)                  | `Roms/Sega SG-1000 (SG1000)/`                     | `.sg` `.bin` `.zip` `.7z`                                                    | —                                                                                           |
| Mega Drive / Genesis    | PicoDrive (libretro); alt: Genesis Plus GX  | `Roms/Sega Genesis (MD)/`                         | `.md` `.smd` `.gen` `.bin` `.zip` `.7z`                                      | `bios_CD_U.bin` / `E` / `J` (Mega CD, optional)                                             |
| 32X                     | PicoDrive (libretro)                        | `Roms/Sega 32X (32X)/`                            | `.32x` `.smd` `.md` `.bin` `.zip` `.7z`                                      | same Mega CD files (optional)                                                               |
| PC Engine               | Beetle PCE Fast (libretro)                  | `Roms/PC Engine (PCE)/`                           | `.pce` `.cue` `.ccd` `.iso` `.img` `.chd` `.sgx` `.zip` `.7z` `.m3u`         | `syscard3.pce` (CD, optional)                                                               |
| SuperGrafx              | Beetle SuperGrafx (libretro)                | `Roms/SuperGrafx (SGX)/`                          | `.sgx` `.pce` `.cue` `.ccd` `.chd` `.zip` `.7z`                              | —                                                                                           |
| ColecoVision            | Gearcoleco (libretro)                       | `Roms/ColecoVision (COLECO)/`                     | `.col` `.bin` `.rom` `.zip` `.7z`                                            | `colecovision.rom` (or `coleco.rom`)                                                        |
| Intellivision           | FreeIntv (libretro)                         | `Roms/Intellivision (INTV)/`                      | `.int` `.bin` `.rom` `.zip` `.7z`                                            | `exec.bin` `grom.bin`                                                                       |
| MSX                     | blueMSX (libretro)                          | `Roms/MSX (MSX)/`                                 | `.mx1` `.mx2` `.dsk` `.rom` `.cas` `.zip` `.7z`                              | none to add (`Machines/` `Databases/` ship in the image)                                    |
| Odyssey 2               | O2EM (libretro)                             | `Roms/Odyssey 2 (O2)/`                            | `.bin` `.zip` `.7z`                                                          | `o2rom.bin`                                                                                 |
| Vectrex                 | vecx (libretro)                             | `Roms/Vectrex (VEC)/`                             | `.vec` `.bin` `.gam` `.zip` `.7z`                                            | —                                                                                           |
| Neo Geo (AES/MVS)       | FinalBurn Neo (libretro)                    | `Roms/FBNeo (FBNEO)/`                             | `.zip` `.7z`                                                                 | `neogeo.zip` in the game folder, `Bios/fbneo/`, or `Bios/`                                 |
| Arcade                  | MAME 2003-Plus (libretro)                   | `Roms/MAME (MAME)/`                               | `.zip` `.7z`                                                                 | ROM and BIOS zips in the game folder. Samples in `Bios/mame2003-plus/samples/`             |
| Neo Geo CD              | NeoCD (libretro)                            | `Roms/Neo Geo CD (NEOCD)/`                        | `.cue` `.iso` `.chd`                                                         | `neocd/neocd.bin`, `neocd/uni-bioscd.rom`, or `neocd/neocd_z.rom` (`Bios/` root also works) |
| Neo Geo Pocket          | Beetle NGP (libretro)                       | `Roms/Neo Geo Pocket (NGP)/`                      | `.ngp` `.ngc` `.zip` `.7z`                                                   | —                                                                                           |
| WonderSwan              | Beetle WonderSwan (libretro)                | `Roms/WonderSwan (WS)/`                           | `.ws` `.wsc` `.zip` `.7z`                                                    | —                                                                                           |
| Virtual Boy             | Beetle VB (libretro)                        | `Roms/Virtual Boy (VB)/`                          | `.vb` `.zip` `.7z`                                                           | —                                                                                           |
| Pokémon Mini            | PokeMini (libretro)                         | `Roms/Pokemon Mini (PKM)/`                        | `.min` `.zip` `.7z`                                                          | `bios.min` (optional)                                                                       |
| Atari 2600              | Stella (libretro)                           | `Roms/Atari 2600 (A26)/`                          | `.a26` `.bin` `.zip` `.7z`                                                   | —                                                                                           |
| Atari 5200              | a5200 (libretro)                            | `Roms/Atari 5200 (A5200)/`                        | `.a52` `.bin` `.zip` `.7z`                                                   | `5200.rom`                                                                                  |
| Atari 7800              | ProSystem (libretro)                        | `Roms/Atari 7800 (A78)/`                          | `.a78` `.bin` `.zip` `.7z`                                                   | `7800 BIOS (U).rom`                                                                         |
| Atari 8-bit             | Atari800 (libretro)                         | `Roms/Atari 8-bit (A800)/`                        | `.atr` `.atx` `.rom` `.xex` `.cas` `.car` `.zip` `.7z`                       | `ATARIOSB.ROM` `ATARIXL.ROM`                                                                |
| Atari ST                | Hatari (libretro)                           | `Roms/Atari ST (ST)/`                             | `.st` `.msa` `.stx` `.dim` `.ipf` `.zip` `.7z`                               | `tos.img` or EmuTOS `etos*.img` (in `Bios/` or `Bios/ST/`)                                  |
| Atari Lynx              | Handy (libretro)                            | `Roms/Atari Lynx (LYNX)/`                         | `.lnx` `.lyx` `.bll` `.o` `.zip` `.7z`                                       | `lynxboot.img`                                                                              |
| 3DO                     | Opera (libretro)                            | `Roms/3DO (3DO)/`                                 | `.iso` `.chd` `.cue`                                                         | `panafz10.bin`                                                                              |
| DOS                     | DOSBox Pure (libretro)                      | `Roms/DOS (DOS)/`                                 | `.exe` `.com` `.bat` `.dos` `.dosz` `.zip` `.iso` `.cue` `.m3u` `.m3u8`      | —                                                                                           |
| PlayStation             | PCSX ReARMed (libretro)                     | `Roms/Sony PlayStation (PS)/`                     | `.cue` `.chd` `.m3u` `.pbp` `.iso` `.ccd` `.img` `.toc`                      | `scph5500.bin` / `scph5501.bin` / `scph5502.bin`                                            |
| PlayStation 2           | AetherSX2                                   | `Roms/Sony PlayStation 2 (PS2)/`                  | `.iso` `.chd` `.cso` `.mdf` `.nrg` `.bin` `.img` `.dump` `.gz` `.m3u` `.elf` | BIOS dumps in `Bios/PS2/` (not in the ROM folder)                                           |
| Nintendo 64             | Mupen64Plus-Next (libretro)                 | `Roms/Nintendo 64 (N64)/`                         | `.z64` `.n64` `.v64` `.zip` `.7z`                                            | —                                                                                           |
| GameCube                | Dolphin                                     | `Roms/Nintendo GameCube (GC)/`                    | `.gcm` `.iso` `.gcz` `.ciso` `.wbfs` `.rvz` `.m3u` `.elf` `.dol`             | `GC/USA/IPL.bin` (optional; also EUR/JAP; `Bios/IPL.bin` or `Bios/GC/IPL.bin` also works)   |
| Wii                     | Dolphin                                     | `Roms/Nintendo Wii (WII)/`                        | `.gcm` `.iso` `.wbfs` `.gcz` `.ciso` `.rvz` `.wad` `.m3u` `.elf` `.dol`      | same IPL (optional); extra files in `Bios/WII`                                              |
| Saturn                  | YabaSanshiro (libretro)                     | `Roms/Sega Saturn (SATURN)/`                      | `.cue` `.ccd` `.chd` `.iso`                                                  | `saturn_bios.bin`                                                                           |
| TIC-80                  | TIC-80 (libretro)                           | `Roms/TIC-80 (TIC)/`                              | `.tic`                                                                       | —                                                                                           |
| Pico-8                  | Official PICO-8 (you add it); alt: fake-08  | `Roms/Pico-8 (PICO)/`                             | `.p8` `.png` `.zip`                                                          | `PICO/pico8_64` and `PICO/pico8.dat`                                                        |
| Pico-8 (fake-08)        | fake-08 (libretro); alt: official PICO-8    | `Roms/Pico-8 fake-08 (P8)/`                       | `.p8` `.png` `.zip`                                                          | — (the alt needs the PICO pair)                                                             |
| PSP                     | PPSSPP                                      | `Roms/Sony PlayStation Portable (PSP)/`           | `.iso` `.cso` `.pbp` `.chd`                                                  | —                                                                                           |
| Dreamcast               | Flycast                                     | `Roms/Sega Dreamcast (DC)/`                       | `.cdi` `.gdi` `.cue` `.chd` `.m3u`                                           | `dc_boot.bin` `dc_flash.bin` in `Bios/DC/` or `Bios/`                                       |
| Nintendo DS             | DraStic                                     | `Roms/Nintendo DS (NDS)/`                         | `.nds` `.zip` `.7z`                                                          | —                                                                                           |
| Amiga                   | Amiberry                                    | `Roms/Commodore Amiga (AMIGA)/`                   | `.adf` `.ipf` `.hdf` `.lha` `.cue` `.iso` `.chd` `.zip`                      | kickstarts optional; AROS ships in the image                                                |
| Doom                    | GZDoom                                      | `Roms/Doom (DOOM)/`                               | `.wad` `.iwad` `.pwad` `.pk3`                                                | —                                                                                           |
| Flash                   | Ruffle Handheld (SilverPsychoo)             | `Roms/Flash (FLASH)/`                             | `.swf`                                                                       | —                                                                                           |
| Ports                   | PortMaster                                  | `Roms/Ports (PORTS)/`                             | `.sh` only                                                                   | —                                                                                           |
| RPG Maker 2000/2003     | EasyRPG Player (libretro)                   | `Roms/RPG Maker 2000-2003 (EASYRPG)/`             | `.zip` `.lzh` `.ldb` `.easyrpg`; folders with `RPG_RT.ldb` or `*.easyrpg`    | `rtp/2000` `rtp/2003` (optional)                                                            |
| RPG Maker XP / VX / Ace | mkxp-z (libretro)                           | `Roms/RPG Maker XP-VX-Ace (MKXPZ)/`               | `.ini` `.json` `.rxproj` `.rvproj` `.rvproj2` `.mkxpz` `.zip` `.7z`          | `mkxp-z/RTP` (optional)                                                                     |
| ScummVM                 | ScummVM                                     | `Roms/ScummVM (SCUMMVM)/`                         | `.scummvm` `.svm` `.zip`; game folders                                       | —                                                                                           |
| OpenBOR                 | OpenBOR                                     | `Roms/OpenBOR (OPENBOR)/`                         | `.pak`                                                                       | —                                                                                           |
| Daphne                  | Hypseus Singe                               | `Roms/Daphne (DAPHNE)/`                           | `.txt` `.daphne` `.singe`                                                    | —                                                                                           |
| Windows                 | Wine 11.6 WoW64 via Box64, temporary Weston | `Roms/Windows (WINE)/`                            | `.exe` `.msi` `.bat` `.cmd`                                                  | —                                                                                           |


- **PSP:** PPSSPP renders with OpenGL. Vulkan is available when the Mali driver is active and you pick it in PPSSPP. The **Panfrost** setting is Mesa OpenGL ES only. The separate experimental **PanVK** setting enables Mesa's Vulkan driver; PPSSPP on that driver did not attach the display, so a PSP game was not shown that way.
- **Dreamcast:** a new Flycast setup writes a savestate when you quit and loads it the next time that game starts. A Flycast configuration you already have is left as it is, including a setup that does not resume. Hardcore achievements, when that mode is on, leave the savestate unloaded. MENU+START does not write that savestate.



## Libraries and storage

- The OS card is `/storage`. It holds your settings in `/storage/.config` and is also a library.
- A second SD card in the other slot, or a USB disk on OTG, is its own library. Settings → System → Advanced can turn the second SD slot and USB OTG off to save power. That takes effect on the next boot.
- Each library uses `Roms/`, `Bios/`, and `Saves/`. For games, Zlyme uses the first of `Roms/`, `roms/`, or `ROMS/` that exists on that library. Only one of them counts per library.
- System folders use `Pretty Name (TAG)`, for example `Game Boy Advance (GBA)`. The tag in parentheses picks the emulator. Use the same names as the [systems table](#systems-and-emulators) on every card.
- NextUI lists a system only when a library has a launchable game for it. An empty folder, a save directory, or artwork does not keep the system on the list.
- Settings → System → Storage → Create game folders asks for a library (SD card 1, SD card 2, or USB). It creates the missing ROM, BIOS, and save folders there. It does not delete ROMs.
- Settings → System → Storage → Eject library card unmounts the second SD or USB disk before you pull it. It appears only while one is mounted. Do not eject while a game from that card is running.
- Settings → System → Storage → Format removable storage erases a second SD or USB disk as exFAT or ext4. The main card cannot be selected. All data on the chosen disk is lost.
- To remove one game, hold MENU and press Y on it, then choose Delete game. That removes the ROM, its matching saves, its artwork, its own governor and emulator choices, and its Recently Played entry. A choice for a whole folder or a whole system stays. A game with the same name on another card stays. If the delete fails, the game stays in the list. A save, image, or setting may already have been removed.



### Box art

Box art is `{folder}/.media/{rom stem}.png`: the same basename as the game file or playlist. A `.jpg` or `.jpeg` with that name is used when the PNG is not there. A cart downloaded inside Splore is already a PNG label, so that file is the preview when no `.media` image exists.

A system folder uses `{folder}/.media/bg.png` when that file exists. A game list uses `{folder}/.media/bglist.png`. `/storage/bg.png` is the next choice. On the system list, if none of those exist, Zlyme shows a transparent Art Book picture for that system. Inside a game list, Zlyme does not add its own wallpaper. Your images are not replaced. Settings → Appearance → Use folder background for ROMs starts on. Turning it off keeps the plain background. The pictures are CC BY-NC-SA 2.0.

Recently Played shows a built-in picture even when that folder is not on the card. Your own picture goes at `/storage/.config/nextui/shared/artbook/special/recent.png`. `/storage/bg.png` comes after that. Deleting your picture brings the built-in one back. A picture left in the Recently Played folder is not used. An update from zlyme44.3 keeps a picture you put there, unless it is one of the built-in renders, and does not remove it. The built-in picture keeps names off to the left. A long name can scroll there. It is not a separate download.

## USB file transfer

Tools → USB Transfer shares storage over the lower USB-C port, the port you charge with. The upper port stays a USB host. The tool starts only when you confirm it. It is not a background service. If another filesystem is mounted inside storage, the tool says so and does not start. Leaving a PortMaster game removes a filesystem that game mounted through Zlyme. A filesystem mounted another way stays until it is unmounted or the Flip restarts, including one mounted later at the same place.

The first screen says: Connect your computer to the lower USB-C port. A starts the session. B goes back without starting it. If the lower port is not a data connection yet, the next screen says it is waiting for a USB data connection and shows B to stop. It does not say the computer is connected. When the controller is bound, the screen says the session is open, names the storages that were actually shared, and shows B to stop. An open session is not the same as the computer seeing the Flip. MENU+START still leaves the tool. Unplugging the cable leaves the session up until you leave it.

A computer can see:

- SDCARD1, the whole data partition. That includes games, BIOS, saves, settings, logs, and update files.
- SDCARD2, when a second card is mounted. The whole card, including a card that has no ROM folder.
- OTG, each USB stick that was already mounted. A second stick is OTG 2, and the names continue that way.

The boot partition is not shared, and the tool does not unmount it. Use a computer you trust. It can change settings and files staged for an update. If an update is already staged, the tool refuses to start. A missing second card or USB stick is normal and does not stop the SDCARD1 share. A stick plugged in after the screen is up is not added. A read-only volume stays read-only. NTFS is not shared. The computer receives files through MTP. It does not receive the card as a disk.

## BIOS

- Put BIOS files in `Bios/` on any mounted library. The [systems table](#systems-and-emulators) lists the names and subfolders.
- When a game starts, Zlyme combines the `Bios/` folders of every mounted library. If the same file exists on more than one card, the copy on the card that holds the game wins.
- A file in a one-level subfolder, such as `Bios/PS/scph5501.bin`, is also found at the `Bios/` root, unless a root file already has that name.
- FinalBurn Neo looks in the game's folder first, then `Bios/fbneo/`, then `Bios/`. The names are case-sensitive. A folder named `FBNEO` is not searched. A file in the game folder with the same name is the one that runs.
- MAME 2003-Plus reads ROM and BIOS zips from the game's folder. It does not open those zips from `Bios/`. Samples and artwork use `Bios/mame2003-plus/` when that core's system-subfolder option is on, which is the usual setting.



## Saves

- Saves stay in `Saves/` on a library, in one folder per system tag.
- Zlyme looks for existing saves on every mounted card. If more than one card has a save for the game, the card that holds the game wins.
- If no card has a save for the game yet, Zlyme keeps that system's saves together. It uses the game's card when that card already has saves for the system, then another card that does. Otherwise the new save is created on the game's card.
- A Flash game keeps its companion data in that library's `Saves/FLASH/flash_data`.
- OpenBOR saves are in that library's `Saves/OPENBOR`. The engine's paks, screenshots, and log folder are not created in the ROM directory.
- RPG Maker XP, VX, and Ace saves are in `Saves/MKXPZ`.



## OpenBOR, RPG Maker, and Windows

- An OpenBOR `.pak` stays in `Roms/OpenBOR (OPENBOR)/`. Starting it does not create `Paks`, `Saves`, `Logs`, or `ScreenShots` there.
- An RPG Maker XP, VX, or Ace game can be a project file (`.ini`, `.json`, `.rxproj`, `.rvproj`, `.rvproj2`), a `.mkxpz`, or a `.zip` / `.7z`. The project can sit at the archive root or in one top folder. A `.mkxp` file is not a game this core accepts.
- A Windows game uses Wine 11.6 WoW64 under Box64 0.4.4, in a temporary Weston. Its prefix is `/storage/.config/nextui/my355/wine-prefix`. An update deletes an old `wine-prefix.ext4` next to that directory and leaves the new prefix in place.



## Multi-disc games

NextUI lists the `.m3u` as the game. Put the discs in a folder with the **same name** as the playlist (no leading `.` or `_`):

```text
Roms/Sony PlayStation (PS)/
  Game Name.m3u
  Game Name/
    Game Name (Disc 1).chd
    Game Name (Disc 2).chd
  .media/Game Name.png
```

Playlist lines are paths **relative to the** `.m3u`, with Unix newlines and no leading slash:

```text
Game Name/Game Name (Disc 1).chd
Game Name/Game Name (Disc 2).chd
```

Open the `.m3u`, not a CHD inside the folder, so RetroArch Disk Control can swap discs. A playlist works only on systems whose Files column in the systems table lists `.m3u`, such as PC Engine, DOS, Dreamcast, and PlayStation. Saturn and Amiga do not use `.m3u` on this image.

## PICO-8 and Splore

- Native PICO-8 / Splore uses the Raspberry Pi build you bought from Lexaloffle. Put `pico8_64` and `pico8.dat` together in `Bios/PICO/` on the main card, the second SD card, or another mounted library. Zlyme does not include or download those files.
- The Splore row appears first in the `Pico-8 (PICO)` folder of the library that holds that pair.
- Carts downloaded inside Splore show up in the Pico-8 list. They stay in Pico-8's own folder and launch with native PICO-8.
- Fake-08 has its own folder, `Pico-8 fake-08 (P8)`, and does not need the PICO-8 files. Pico-8 and Fake-08 stay separate.
- The MENU+Y Emulator row on a Pico-8 game switches between native PICO-8 and Fake-08.



## Joysticks and rumble

Settings → System → Joysticks has:

- **Test Sticks**: the final stick output.
- **Calibrate Left** and **Calibrate Right**: capture the range, then the center.
- **Tune Left Deadzone** and **Tune Right Deadzone**: a deadzone for each stick, with a live preview.
- **Values**: raw, output, and saved state.
- **Rumble Strength**: the global motor gain. A fresh install uses 40%. A saved value is kept.
- **Test Rumble**: a short motor pulse.

Printed A and B are fixed: A is the east button and B is the south button. Settings → System → Haptic feedback defaults to on and only turns NextUI's own pulses on or off. Replacement Switch-style sticks have not been tested on hardware.

## Settings

Settings opens from Tools. Ordinary pages show B Back and A Okay. A page with its own controls, such as the keyboard, the color picker, release notes, or a joystick test, shows those controls instead. When you leave Settings after a change that needs a restart, it offers to restart. A shutdown or restart already chosen from Recovery skips that question.

### Network

- **WiFi**: the radio on or off, diagnostics, and the network list. **Country** sets the two-letter code for regional channel rules. Use the country where the device is being used. The row appears only when the Wi-Fi driver supports it.
- **Bluetooth**: pair HID controllers and headsets.
- **SSH**: OpenSSH with SFTP. On a fresh install the account is root and the password is empty. SSH stays on with that empty password. **SSH Password** sets or changes it, and **Clear SSH password** removes it, without a reboot. About shows the password as it is currently set.
- **Samba**: off until you turn it on. It shares `/storage`, including settings. Windows may not list the Flip under Network. The address is Settings → About → IP, which is the Wi-Fi address when the Flip is on Wi-Fi. In File Explorer's address bar, type `\\` and that address, then `\storage`. `\\192.168.1.123\storage` is only an example of the shape. The username is `zlyme`. The first password is `zlyme`. Change that password in Settings → Network → Samba Password. The keyboard starts empty. Leaving it empty does not change the saved password. The new password stays on the card across a reboot and an update. Over SSH, `zlyme-samba-auth set` does the same thing: type the new password and press Enter. It is not shown. If Samba cannot start, the switch goes back to off and Settings says why. Reset Settings turns Samba off and leaves the password. If the saved password file is damaged, Samba stays off. Set a new password the same way. It does not go back to `zlyme` on its own.
- **Syncthing**: off until you turn it on. The first time it starts, the web UI username is `zlyme` and the password is `zlyme`. Change that password in Syncthing's own page. A login you already set stays across a reboot and an update. The page is on port 8384. If Syncthing stays off and the log says the GUI authentication is missing, the files already on the card are left there. A username and password that appear only in a comment in that file do not count. Over SSH, run `syncthing --home=/storage/.config/syncthing generate --gui-user=zlyme --gui-password=- --no-port-probing`, type a password, and press Enter. It is not shown. That sets the login and does not replace the device. About shows the username from that same reading. A comment in the file is not shown as the username. It shows `(set)` when a password hash is saved. It does not show the password or the hash.

Settings → About lists the SSH account and password, the Samba account and password, the Syncthing account and password, and the IP address, in that order. It reads them when you open About. The SSH account is root. The SSH password is the one currently set, or `(empty)`. The Samba account is `zlyme`. The Samba password is `zlyme` only while it is still the first password, `(changed)` after you set another, and `(unavailable)` if that saved password cannot be read. About does not change Samba or Syncthing passwords.

SSH, Samba, and Syncthing apply immediately. They run only while Wi-Fi is on. Turning Wi-Fi off stops all three and leaves each switch as you set it. Turning Wi-Fi on starts the ones that are on.

### Proxy

Settings → Network → Proxy is an application proxy for online services on a network that requires one. It is not a VPN, and it does not change how the Flip joins Wi-Fi.

- **Proxy**: Off or On. Off is the default. Applications then connect directly.
- **Protocol**: HTTP, or SOCKS5. SOCKS5 asks the proxy to resolve names.
- **Host** and **Port**: the proxy address. There is no username or password.
- **Test proxy**: a short HTTPS request to GitHub. It reports success or failure and does not print the address.

Update, ZcrapeGoat, PortMaster, and other tools and games launched from the list use it when the program honors a normal HTTP, HTTPS, or SOCKS proxy. Wi-Fi association, DHCP, and arbitrary UDP (including Moonlight's game stream) do not.

`localhost`, `127.0.0.1`, and `::1` stay direct. Turn Proxy off to stop using it. Reset Settings removes the saved proxy as well. Games, saves, and Wi-Fi networks stay.

### Game

Besides its game options, this page holds cleanup actions. Each one asks before it changes anything.

- **Clean junk**: desktop metadata and trash folders.
- **Orphan saves / states**: saves whose ROM is missing from that same card.
- **Orphan boxart**: artwork whose ROM is missing.
- **Orphan game preferences**: per-ROM governor and emulator choices whose ROM is missing. A choice for a whole folder or a whole system stays. A choice for the second card stays while that card is out.
- **Clear Recents**: the Recently Played list.
- **Reset RetroArch core options** removes per-core option files and restores the stock option files. It does not remove core libraries, saves, or the main RetroArch configuration.
- **Reset RetroArch configuration** restores the main RetroArch configuration from the stock file. It does not remove core options, core libraries, saves, or BIOS files.
- **Orphan per-ROM RetroArch configs**.
- **Reset standalone settings**: removes standalone emulator settings, then restores the stock files Zlyme ships. Games and saves are kept. DraStic, PPSSPP, and Flycast have stock files. Dolphin and AetherSX2 write their first settings the next time they start. AetherSX2 updates its BIOS and save folders to the active library on each launch. The other lines in that file stay. GZDoom's settings file is removed. Its soundfonts, FM banks, and autoexec stay, and it is not given a stock configuration. Native PICO-8 and the programs with no stock file are not given an invented configuration.
- **Reset PortMaster**: removes PortMaster and its downloaded runtimes. Installed ports stay. The next launch unpacks PortMaster again. Runtimes that were only in that installation can download again.



### Sound

Volume is one setting for the speaker, the headphone jack, HDMI, and Bluetooth headphones. The first boot after this audio change keeps the volume that was already saved on the device. Plugging in headphones switches the speaker off without leaving the game. Bluetooth headphones are used when they are connected for audio. A Bluetooth controller does not do that. Settings lists a nearby Bluetooth device even when its type is not known yet, and it does not connect until you ask. HDMI sound is used only when the display reports that it can play audio. Pulling the cable returns sound to the speaker or the jack. A normal boot keeps the internal screen on. Turning HDMI on for a new program turns that screen off for that program and brings it back when you leave.

### System

- **Display**: brightness, panel refresh, screen timeout, and the HDMI display resolution.
- **Joysticks**: see [Joysticks and rumble](#joysticks-and-rumble).
- **Storage**: see [Libraries and storage](#libraries-and-storage) and [PortMaster](#portmaster).
- **Advanced**: see below.
- **Status LED**: Auto (green, red while charging, flashing when low), or a fixed Green, Red, or Off. At 0% with no charger connected, the Flip shuts down. Off does not disable that shutdown.
- **Time zone**: how the clock is shown. Until you pick one, the clock stays on UTC. When a network is available, Zlyme sets and corrects the clock in the background. The menu does not wait for that.
- **Haptic feedback**: see [Joysticks and rumble](#joysticks-and-rumble).
- **Backup now** saves `/storage/.config` to `/storage/zlyme-backup.tar.gz`. **Restore backup** unpacks it. Reboot afterwards.



### Advanced

Settings → System → Advanced:

- **GPU**: mali_kbase (the default, OpenGL ES and Vulkan) or Panfrost (OpenGL ES, plus an experimental Vulkan driver). Takes effect on the next boot.
- **CPU undervolt**: Off, L1, L2, or L3. It stays off unless you turn it on. Takes effect on the next boot.
- **ZRAM swap**: on by default. The menu suggests turning it off if a heavy emulator feels spongy.
- **USB OTG (top)**, **HDMI port**, and **Second SD slot**: on by default. Turning one off saves some power. Takes effect on the next boot.
- **System logs**: off by default. See [Logs](#logs).
- **Reset Settings**: returns Zlyme settings to their defaults, including the SSH password. Games, saves, Wi-Fi and paired devices stay.
- **Factory Reset**: restores settings and the stock Tools and Emus paks, then restarts. Games, saves, Wi-Fi and personal content stay.



### Update

Settings → Update has the **Channel** (Releases or Prereleases), the latest release on that channel, its release notes, and the download. **Notes** shows the release text, with the usual button hints. Up and Down scroll, L1 and R1 move a page, and B goes back. If the release has no notes, it says so. If the notes could not be fetched, it says they could not be retrieved. Those are different. If this version is already installed, or the exact firmware file is already on the card, the download asks before it starts and still lets you reinstall. The download confirmation, and the screen that offers reboot, both say that installing may take more than one reboot. Leave the SD card inserted and do not power off the Flip until Zlyme starts normally again. While the file is downloading, the rate is the recent one, in KiB/s or MiB/s. What happens after the download is in the [README](../README.md#update).

## ZcrapeGoat

ZcrapeGoat is [ScrapeGoat](https://github.com/Helaas/nextui-scrapegoat-pak) by Kevin Vranken, using his [Apostrophe](https://github.com/Helaas/Apostrophe) interface.

- Enter your own ScreenScraper username and password for artwork and manuals. Cheats do not need a ScreenScraper account.
- ZcrapeGoat reads every mounted library.
- Art is saved beside the ROM that was scraped, as `.media/<name>.png` in that ROM's folder.
- Cheats are installed under `/storage/Cheats`, even when the ROM is on another card.
- Its settings stay in `/storage/.config/ZcrapeGoat`.



## PortMaster

Open PortMaster from Tools. Browse the list there and install a port. The catalogue, and the fuller instructions, are at [PortMaster](https://portmaster.games/).

Settings → System → Storage → PortMaster location chooses the library for new installs. A port stays on the library where it was installed, and that card has to be in the Flip.

Some ports need the commercial game's own files. When a port needs a runtime, PortMaster can download it.

Settings → Game → Reset PortMaster resets the installer and its downloaded runtimes. It does not delete the ports you installed.

Zlyme runs PortMaster. That does not mean every port runs on the Flip.



## Files

Tools → Files is the file browser. Hidden files are shown until you turn that off, and a theme or hidden-file setting you already chose stays. The controller shortcuts are the [vtree gamepad controls](https://github.com/MustardOS/vtree#gamepad-controls).

## Logs

Logs are off by default. Turn on Settings → System → Advanced → System logs, and Zlyme writes `/storage/.logs`:

- `README.txt` explains the layout.
- `system-0/` is the newest logged boot. `system-1/` to `system-4/` are earlier ones. Each holds files such as `dmesg.txt`, `dmesg-boot.txt`, `boot-timing.txt`, and `nextui.txt`.
- `paks/TAG.log` is the newest run of that pak (`FC.log`, `PS2.log`, `Settings.log`, …). `TAG.log.1` and `TAG.log.2` are the two runs before it.
- Tools → PortMaster writes `paks/portmaster.txt` when system logs are on. When they are off, that transcript stays in a temporary file and an error on screen still comes from it.

When something fails, copy that folder off the card, or fetch `/storage/.logs` over SSH.

## Custom paks

Why you'd do this, and how to send something back, is in the README's [User Systems and Tools and the Right to Experiment](../README.md#user-systems-and-tools-and-the-right-to-experiment) and [CONTRIBUTING.md](../CONTRIBUTING.md). The rules:

- Stock copies live on the OS card at `Tools/my355/` and `Emus/my355/`.
- An update replaces only pak names that exist in the image. Extra folders you add are left alone. Example: edits to `GBA.pak` are overwritten on the next update. A copy renamed to `GBA2.pak` survives, but its games must sit in `Roms/… (GBA2)/`. Every system pairs `TAG.pak` with `Roms/… (TAG)/` the same way.
- Factory Reset also restores the stock pak names.
- To add a **system**, put an executable `Emus/my355/TAG.pak/launch.sh` on the OS card and a non-empty `Roms/Pretty Name (TAG)/` on a library. The tag in parentheses is the pak name. `launch.sh` receives the ROM path. The existing libretro paks are examples (`ra-run -L …`). A core you put on the card in place of an included one is a native program and has to come from a source you trust. An update puts the included cores back and leaves a core the image does not ship.
- To add a **tool** (or NextUI pak), use `Tools/my355/My Tool.pak/launch.sh`. It shows up under Tools after the list restarts.
- Stock NextUI paks usually need changes (paths, controls, binaries) before they run on Zlyme.
- MENU+Start closes your pak like any other.

