# Zlyme user guide

The [README](../README.md) is the front door: what Zlyme is, how to install it, where games go, updates, controls, the systems table, and how to experiment and contribute. This guide owns detailed end-user operation on the Miyoo Flip. [OPERATIONS.md](OPERATIONS.md) covers maintainer and device operations, and [DEVELOPMENT.md](DEVELOPMENT.md) covers building. Settings labels below follow the pinned Zlyme NextUI fork and can change when that pin moves.

## Libraries and storage

- The OS card is `/storage`. It holds your settings in `/storage/.config` and is also a library.
- A second SD card in the other slot, or a USB disk on OTG, is its own library. Settings → System → Advanced can turn the second SD slot and USB OTG off to save power. That takes effect on the next boot.
- Each library uses `Roms/`, `Bios/`, and `Saves/`. For games, Zlyme uses the first of `Roms/`, `roms/`, or `ROMS/` that exists on that library. Only one of them counts per library.
- System folders use `Pretty Name (TAG)`, for example `Game Boy Advance (GBA)`. The tag in parentheses picks the emulator. Use the same names as the [systems table](../README.md#systems-and-emulators) on every card.
- NextUI lists a system only when a library has a launchable game for it. An empty folder, a save directory, or artwork does not keep the system on the list.
- Settings → System → Storage → Create game folders asks for a library (SD card 1, SD card 2, or USB). It creates the missing ROM, BIOS, and save folders there. It does not delete ROMs.
- Settings → System → Storage → Eject library card unmounts the second SD or USB disk before you pull it. It appears only while one is mounted. Do not eject while a game from that card is running.
- Settings → System → Storage → Format removable storage erases a second SD or USB disk as exFAT or ext4. The main card cannot be selected. All data on the chosen disk is lost.
- To remove one game, hold MENU and press Y on it, then choose Delete game. That removes the ROM and its matching saves.

### Box art

Box art is NextUI's `{folder}/.media/{rom stem}.png`: the same basename as the game file or playlist, with `.png`. A cart downloaded inside Splore is already a PNG label, so that file is the preview when no `.media` image exists.

## BIOS

- Put BIOS files in `Bios/` on any mounted library. The [systems table](../README.md#systems-and-emulators) lists the names and subfolders.
- When a game starts, Zlyme combines the `Bios/` folders of every mounted library. If the same file exists on more than one card, the copy on the card that holds the game wins.
- A file in a one-level subfolder, such as `Bios/PS/scph5501.bin`, is also found at the `Bios/` root, unless a root file already has that name.

## Saves

- Saves stay in `Saves/` on a library, in one folder per system tag.
- Zlyme looks for existing saves on every mounted card. If more than one card has a save for the game, the card that holds the game wins.
- If no card has a save for the game yet, Zlyme keeps that system's saves together. It uses the game's card when that card already has saves for the system, then another card that does. Otherwise the new save is created on the game's card.
- A Flash game keeps its companion data in that library's `Saves/FLASH/flash_data`.

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

Settings → Update has the **Channel** (Releases or Prereleases), the latest release on that channel, its release notes, and the download. **Notes** shows the whole release text. Up and Down scroll, L1 and R1 move a page, and B goes back. If the release has no notes, it says so. If the notes could not be fetched, it says they could not be retrieved. Those are different. If this version is already installed, or the exact firmware file is already on the card, the download asks before it starts and still lets you reinstall. What happens after the download is in the [README](../README.md#update).

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
