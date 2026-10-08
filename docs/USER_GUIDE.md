# Zlyme user guide

The [README](../README.md) is the front door: what Zlyme is, how to install it, where games go, updates, controls, and how to experiment and contribute. This guide owns detailed end-user operation on the Miyoo Flip, including the [systems table](#systems-and-emulators). [OPERATIONS.md](OPERATIONS.md) covers maintainer and device operations, and [DEVELOPMENT.md](DEVELOPMENT.md) covers building. Settings labels below follow the pinned Zlyme NextUI fork and can change when that pin moves.

## Card preparation and preloader recovery

The install steps are in the [README](../README.md#install). Stock, not Zlyme, runs `miyoo355_fw.img` and writes the patched preloader. An update inside Zlyme does not repeat that. The three downloadable helpers, and the rename stock requires, are on the hardware wiki's [preloader tools](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/preloader-tools.md) page. The repair itself is explained on the wiki's [SD multiboot](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/sd-multiboot-apommel.md) page.

While stock itself still boots, those jobs can be done from a card. The restore download undoes the normal multiboot repair. It is not how you leave an armed recovery preloader, because stock does not start in that state. Leave it with Disarm MASKROM recovery below, or with the physical MASKROM button if no right-slot Zlyme card will boot. Download `miyoo355_fw-multiboot.img`, `miyoo355_fw-maskrom.img`, or `miyoo355_fw-restore.img` from the [Zlyme releases page](https://github.com/Zetarancio/zlyme/releases) once that release publishes them, rename the chosen file to `miyoo355_fw.img`, and boot stock with that card. They are not in an ordinary Zlyme update. After the MASKROM or restore helper finishes, power the device off before changing cards. It does not reboot itself. On 2026-10-08 those three helpers were checked on one Flip, including restore of that unit's saved original and the MASKROM helper started from the original stock preloader. The measurements are on the wiki page. They do not add steps to a normal install. Inside Zlyme, use the rows below.

Settings → System → Advanced → Recovery has four rows. Confirmations are lists. Cancel is the first row. B also goes back. Nothing on this page reboots or powers off by itself.

**Preloader status** is the internal boot and recovery state. The rows are Preloader, Recovery, Source backup, Stock restore, and Battery. `Normal` / `Ready` means the current preloader is the saved source and a recovery image is prepared. `Recovery armed` / `Armed` means the recovery preloader is installed. Unknown and Invalid are not a normal boot.

**Arm MASKROM recovery** installs that recovery preloader in internal NAND. A bootable card in the right slot still boots. Without one, startup enters MASKROM. Internal stock boot stays off until recovery is disarmed. The last confirmation is `ARM MASKROM RECOVERY`, and it starts on Cancel. On success the screen says recovery is armed and tells you to keep a bootable card in the right slot. To enter MASKROM, shut down, remove the right card, then power on.

**Disarm MASKROM recovery** writes back the exact pre-recovery image saved when recovery was armed. It does not restore the original Miyoo preloader. The last confirmation is `DISARM MASKROM RECOVERY`, and it starts on Cancel. Success says the normal preloader was restored and verified. If the installed image is not an armed recovery image, the action refuses.

**Restore stock preloader** writes this unit's `mtd5-original-<sha256>.img` from the boot card back to the internal preloader, after saving what is there now. This is separate from disarming MASKROM recovery. The name's hash has to match the file, and the DDR initializer in that backup has to match the preloader already installed. If that backup is not on the card, Restore can use the stock image shipped with Zlyme, and only when the installed preloader is the revision that image belongs to. That shipped image is not this unit's own backup. A different preloader is refused. There is no force option. If the write does not verify, Zlyme tries to put the saved current preloader back. That is a failed restore, not a completed one. The last confirmation is `RESTORE STOCK PRELOADER`, and it starts on Cancel. The battery has to be at least 25%, unless a charger is connected.

Erase is not in this menu. `erase-preloader` is a separate command. It removes the internal preloader. It is not MASKROM recovery. If the boot ROM can still see a bootable card, wiping the internal preloader can boot that card instead of USB recovery. Host recovery with the MASKROM button is in the [hardware wiki](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/flashing.md). The measured recovery-preloader boots are on the wiki's [recovery preloader](https://github.com/Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering/blob/main/docs/boot-and-flash/recovery-preloader.md) page.

## Systems and emulators

Folders sit under `Roms/` on any library. BIOS names are inside `Bios/` on any mounted library. "alt:" marks an emulator you can switch to from the MENU+Y Emulator row.

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
| RPG Maker XP / VX / Ace | mkxp-z (libretro)                                    | `Roms/RPG Maker XP-VX-Ace (MKXPZ)/`               | `.ini` `.json` `.rxproj` `.rvproj` `.rvproj2` `.mkxpz` `.zip` `.7z`          | `mkxp-z/RTP` (optional)                                                                     |
| ScummVM                 | ScummVM                                              | `Roms/ScummVM (SCUMMVM)/`                         | `.scummvm` `.svm` `.zip`; game folders                                       | —                                                                                           |
| OpenBOR                 | OpenBOR                                              | `Roms/OpenBOR (OPENBOR)/`                         | `.pak`                                                                       | —                                                                                           |
| Daphne                  | Hypseus Singe                                        | `Roms/Daphne (DAPHNE)/`                           | `.txt` `.daphne` `.singe`                                                    | —                                                                                           |
| Windows                 | Wine 11.6 WoW64 via Box64, temporary Weston          | `Roms/Windows (WINE)/`                            | `.exe` `.msi` `.bat` `.cmd`                                                  | —                                                                                           |

- **PSP:** PPSSPP renders with OpenGL, or with Vulkan when you pick it in PPSSPP and the Mali driver is active.


## Libraries and storage

- The OS card is `/storage`. It holds your settings in `/storage/.config` and is also a library.
- A second SD card in the other slot, or a USB disk on OTG, is its own library. Settings → System → Advanced can turn the second SD slot and USB OTG off to save power. That takes effect on the next boot.
- Each library uses `Roms/`, `Bios/`, and `Saves/`. For games, Zlyme uses the first of `Roms/`, `roms/`, or `ROMS/` that exists on that library. Only one of them counts per library.
- System folders use `Pretty Name (TAG)`, for example `Game Boy Advance (GBA)`. The tag in parentheses picks the emulator. Use the same names as the [systems table](#systems-and-emulators) on every card.
- NextUI lists a system only when a library has a launchable game for it. An empty folder, a save directory, or artwork does not keep the system on the list.
- Settings → System → Storage → Create game folders asks for a library (SD card 1, SD card 2, or USB). It creates the missing ROM, BIOS, and save folders there. It does not delete ROMs.
- Settings → System → Storage → Eject library card unmounts the second SD or USB disk before you pull it. It appears only while one is mounted. Do not eject while a game from that card is running.
- Settings → System → Storage → Format removable storage erases a second SD or USB disk as exFAT or ext4. The main card cannot be selected. All data on the chosen disk is lost.
- To remove one game, hold MENU and press Y on it, then choose Delete game. That removes the ROM and its matching saves.

### Box art

Box art is NextUI's `{folder}/.media/{rom stem}.png`: the same basename as the game file or playlist, with `.png`. A cart downloaded inside Splore is already a PNG label, so that file is the preview when no `.media` image exists.

## BIOS

- Put BIOS files in `Bios/` on any mounted library. The [systems table](#systems-and-emulators) lists the names and subfolders.
- When a game starts, Zlyme combines the `Bios/` folders of every mounted library. If the same file exists on more than one card, the copy on the card that holds the game wins.
- A file in a one-level subfolder, such as `Bios/PS/scph5501.bin`, is also found at the `Bios/` root, unless a root file already has that name.

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

Settings opens from Tools. When you leave it after a change that needs a restart, it offers to restart.

### Network

- **WiFi**: the radio on or off, diagnostics, and the network list. **Country** sets the two-letter code for regional channel rules. Use the country where the device is being used. The row appears only when the Wi-Fi driver supports it.
- **Bluetooth**: pair HID controllers and headsets.
- **SSH**: OpenSSH with SFTP.
- **Samba**: a file share of `/storage`.
- **Syncthing**: a web UI on port 8384.

SSH, Samba, and Syncthing apply immediately.

### Proxy

Settings → Network → Proxy is an application proxy for online services on a network that requires one. It is not a VPN, and it does not change how the Flip joins Wi-Fi.

- **Proxy**: Off or On. Off is the default. Applications then connect directly.
- **Protocol**: HTTP, or SOCKS5. SOCKS5 asks the proxy to resolve names.
- **Host** and **Port**: the proxy address. There is no username or password.
- **Test proxy**: a short HTTPS request to GitHub. It reports success or failure and does not print the address.

Update, ZcrapeGoat, PortMaster, and other tools and games launched from the list use it when the program honors a normal HTTP, HTTPS, or SOCKS proxy. Wi-Fi association, DHCP, and arbitrary UDP (including Moonlight's game stream) do not.

`localhost`, `127.0.0.1`, and `::1` stay direct. Turn Proxy off to stop using it. Reset Settings removes the saved proxy as well. Games, saves, and Wi-Fi networks stay.

### Game

Besides its game options, this page holds cleanup actions. Each one counts what it would remove and asks before deleting.

- **Clean junk**: desktop metadata and trash folders.
- **Orphan saves / states**: saves whose ROM is missing from that same card.
- **Orphan boxart**: artwork whose ROM is missing.
- **Clear Recents**: the Recently Played list.
- **Reset RetroArch core options** and **Orphan per-ROM RetroArch configs**.
- **Reset standalone settings**: games and saves are kept.

### System

- **Display**: brightness, panel refresh, screen timeout, and the HDMI display resolution.
- **Joysticks**: see [Joysticks and rumble](#joysticks-and-rumble).
- **Storage**: see [Libraries and storage](#libraries-and-storage) and [PortMaster](#portmaster).
- **Advanced**: see below.
- **Status LED**: Auto (green, red while charging, flashing when low), or a fixed Green, Red, or Off.
- **Time zone**: how the clock is shown. Until you pick one, the clock stays on UTC.
- **Haptic feedback**: see [Joysticks and rumble](#joysticks-and-rumble).
- **Backup now** saves `/storage/.config` to `/storage/zlyme-backup.tar.gz`. **Restore backup** unpacks it. Reboot afterwards.

### Advanced

Settings → System → Advanced:

- **GPU**: mali_kbase (the default, OpenGL ES and Vulkan) or Panfrost (OpenGL ES). Takes effect on the next boot.
- **CPU undervolt**: Off, L1, L2, or L3. It stays off unless you turn it on. Takes effect on the next boot.
- **ZRAM swap**: on by default. The menu suggests turning it off if a heavy emulator feels spongy.
- **USB OTG (top)**, **HDMI port**, and **Second SD slot**: on by default. Turning one off saves some power. Takes effect on the next boot.
- **System logs**: off by default. See [Logs](#logs).
- **Reset Settings**: returns Zlyme settings to their defaults. Games, saves, Wi-Fi and paired devices stay.
- **Factory Reset**: restores settings and the stock Tools and Emus paks, then restarts. Games, saves, Wi-Fi and personal content stay.

### Update

Settings → Update has the **Channel** (Releases or Prereleases), the latest release on that channel, its release notes, and the download. **Notes** shows the release text, with the usual button hints. Up and Down scroll, L1 and R1 move a page, and B goes back. If the release has no notes, it says so. If the notes could not be fetched, it says they could not be retrieved. Those are different. If this version is already installed, or the exact firmware file is already on the card, the download asks before it starts and still lets you reinstall. What happens after the download is in the [README](../README.md#update).

## ZcrapeGoat

- Enter your own ScreenScraper username and password for artwork and manuals. Cheats do not need a ScreenScraper account.
- ZcrapeGoat reads every mounted library.
- Art is saved beside the ROM that was scraped, as `.media/<name>.png` in that ROM's folder.
- Cheats are installed under `/storage/Cheats`, even when the ROM is on another card.
- Its settings stay in `/storage/.config/ZcrapeGoat`.

## PortMaster

- Settings → System → Storage → PortMaster location chooses the library for new installs. Existing ports stay where they are.
- A fresh install uses PortMaster's default theme with the Zlyme color scheme. Selected text uses the Zlyme orange. A theme or scheme you pick later is kept.

## Logs

Logs are off by default. Turn on Settings → System → Advanced → System logs, and Zlyme writes `/storage/.logs`:

- `README.txt` explains the layout.
- `system-0/` is the newest logged boot. `system-1/` to `system-4/` are earlier ones. Each holds files such as `dmesg.txt`, `dmesg-boot.txt`, `boot-timing.txt`, and `nextui.txt`.
- `paks/TAG.log` is the newest run of that pak (`FC.log`, `PS2.log`, `Settings.log`, …). `TAG.log.1` and `TAG.log.2` are the two runs before it.

When something fails, copy that folder off the card, or fetch `/storage/.logs` over SSH.

## Custom paks

Why you'd do this, and how to send something back, is in the README's [User Systems and Tools and the Right to Experiment](../README.md#user-systems-and-tools-and-the-right-to-experiment) and [CONTRIBUTING.md](../CONTRIBUTING.md). The rules:

- Stock copies live on the OS card at `Tools/my355/` and `Emus/my355/`.
- An update replaces only pak names that exist in the image. Extra folders you add are left alone. Example: edits to `GBA.pak` are overwritten on the next update. A copy renamed to `GBA2.pak` survives, but its games must sit in `Roms/… (GBA2)/`. Every system pairs `TAG.pak` with `Roms/… (TAG)/` the same way.
- Factory Reset also restores the stock pak names.
- To add a **system**, put an executable `Emus/my355/TAG.pak/launch.sh` on the OS card and a non-empty `Roms/Pretty Name (TAG)/` on a library. The tag in parentheses is the pak name. `launch.sh` receives the ROM path. The existing libretro paks are examples (`ra-run -L …`).
- To add a **tool** (or NextUI pak), use `Tools/my355/My Tool.pak/launch.sh`. It shows up under Tools after the list restarts.
- Stock NextUI paks usually need changes (paths, controls, binaries) before they run on Zlyme.
- MENU+Start closes your pak like any other.
