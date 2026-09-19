# Plan — Zlyme, a minimal fast my355 system on Buildroot

Companion to `NOTES.md` (hardware and operational facts). OS name is
**Zlyme**. Board / NextUI platform is **my355**. Kernel dtb stays
`rk3566-miyoo-flip.dtb`.

`TODO.md` stays gitignored. Device serial dumps are `NOTES/DEVLOGS/`
(also gitignored). `README.md` is the public product readme.

**Where we are (2026-09-19).** Flashed/OTA image is **zlyme40**
(`VERSION="zlyme40 (2026-09-19)"`). NextUI pin is
`ae652648…-zlyme40`. OS update is **Settings → Update**, not a Tools
pak. Do not Etcher a games card. Do not start a second host `./build.sh`
on `output/`. `README.md` edits stay local until asked. `NOTES/` is
in git except `TODO.md` and `DEVLOGS/`. RetroArch A/B plus the zlyme
RGUI theme live in the retroarch package; that is not in the flashed
image until a rebuild.

Live pak pass on the Flip after Etcher: RA cores, NDS/PSP/DOOM/PICO,
PORTS, PS2 (AetherSX2), Tools. Logs on → `/storage/.logs`. Governors
play vs heavy from each `launch.sh`. Pico-8 binary is **only**
`Bios/PICO`. PS2 BIOS is `Bios/PS2` (none on this card besides
`patches.zip`). GC/Wii Dolphin still dies on video backend. Wine
11.0 prints `--version` under box64; wineboot still cannot load
PE `kernel32.dll`. User asked for `workflow_dispatch` after this
push; that is allowed this once.

Last flashed image was the zlyme40 Etcher write. Local tar
`output/images/zlyme-my355-20260918-abee3d8c5354-dirty.tar` is an
older tree.

When I say **commit**: update `LOGBOOK.md`, `PLAN.md`, and `NOTES.md` against the tree as it stands, including what is still uncommitted, ensure there are not leftover attempts that are now uncommitted but should be deleted. Comments in the files and the commit message stay written like a person wrote them. Split into more than one commit when the tree holds more than one reason (a hang fix is not a first-frame cut). Do not squash unrelated work into a single “boot” commit.

Do not Etcher `zlyme.img` onto a card that already has games.
Do not start a second `build.sh` on the same `output/`.
`TODO.md` and `NOTES/DEVLOGS/` stay gitignored.
Propose `README.md` wording when it would help; do not edit `README.md` unless I ask. Uncommitted README changes stay until I say otherwise.

---



## 1. The decision, in one paragraph

Build on **upstream Buildroot** with **our own** `BR2_EXTERNAL` **tree**.
Harvest emulator recipes from Batocera/Knulli; keep ROCKNIX / the device
wiki for kernel, DTS, drivers, and mixer names. When a package needs a
patch, start from Knulli’s (same Buildroot layout) and only refresh
context or replace `/userdata` paths. Put `*.patch` next to the `.mk`;
Buildroot does not apply `package/foo/patches/`. Boot from the SD card,
run on KMSDRM with no compositor, busybox init. We are not a ROCKNIX or
Knulli fork: their 150-package RK3566 set does not fit a GitHub runner
in six hours, and almost none of Batocera’s emulator `.mk` files depend
on Batocera itself. Curated list is section 11. Zero distro trees to
track.

### Sources of truth

Two, and they outrank anything else including this document:

1. **The ROCKNIX fork** at `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/ROCKNIX`
2. **The device wiki** at `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP`

Where Batocera, Knulli, MIMIKI or dArkOS disagree with those two about
this hardware, the two win. The other projects are parts bins.

---



## 2. Repository layout

```
ZETAOS/
├── Dockerfile                 # pinned build container
├── build.sh                   # public build driver
├── storage.sh.example         # template for the private one
├── storage.sh                 # private paths, gitignored
├── external.desc              # BR2_EXTERNAL descriptor
├── configs/
│   ├── zlyme_minimal_defconfig  # bootable, no emulators
│   └── zlyme_defconfig          # everything
├── board/my355/
│   ├── linux/                 # kernel config, DTS, patches, overlays
│   ├── uboot/
│   ├── fsoverlay/             # /etc/init.d/S##, configs, zlyme-update
│   ├── genimage.cfg
│   ├── make-update-tar.sh
│   └── post-image.sh
└── package/
    ├── boot/                  # zlyme-initramfs (tiny static busybox)
    ├── emulators/             # standalones + libretro-* cores
    ├── drivers/               # rtl8733bu, joypad, mali-kbase
    └── system/                # nextui, gpudriver, libmali, zlyme-jackd, zlyme-keylidmon, …
```

`dArkOS/` stays on disk as reference. It is not part of this repo.

The SD image ends with a **32MB empty exFAT** seed (label `ZLYME`),
same as ROCKNIX `STORAGE_SIZE`. First boot `S13resize` grows it to the
card and `mkfs.exfat` (the seed has no packed files). Trigger is
`/boot/zlyme-boot.conf`. GPT is three partitions: `uboot` at 8M, **1300M
(1.3GB)** FAT `ZLYMEBOOT` (Image, dtb, overlays, one squashfs file
`zlyme`), then `ZLYME`. The pending OTA squashfs lives on `ZLYME`, not
beside `zlyme` on FAT. There is no `rootfs` GPT partition.

### Licenses

Standing rule (`f3620e7`): **every package and every pak ships a**
`LICENSE`. Root `LICENSE` is MIT for original Zlyme glue only; it
does not relicense the tree. NextUI is PolyForm Noncommercial 1.0.0.
MinUI's origin has no formal SPDX — see `NOTICE`. Proprietary blobs
(Mali, DraStic, Realtek firmware, user Pico-8) stay proprietary. A new
`.mk` or `.pak` without a `LICENSE` is incomplete.

### Comments and commits

Keep both short. File comments stay in the voice already in the tree;
do not turn them into session write-ups. Commit messages are one or two
sentences on why, same as the existing log. If the staged work answers
two different “why”s, make two commits.

---



## 3. Build in Docker

Everything runs inside a pinned container. No build dependency is
installed on the host.

```dockerfile
FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
```

Buildroot builds its own cross-toolchain. No QEMU — nothing is executed
for the target on the build machine.

Two rules from dArkOS:

- **Pin by digest, not just tag.** Compat libraries pinned only to
`security.debian.org` 404 the moment those versions are superseded.
- **Keep a loop-device cleanup path.** `build.sh --loops` stays.

The container does not need to be privileged for most of the build.
Only image assembly touches loop devices.

Host gcc prefix in this tree is still `/flip/output/host`. `build.sh`
bind-mounts `ZLYME_OUTPUT` at `/flip/output`. Do not byte-replace
`/flip/` → `/zlyme/` in the output tree.

---



## 4. ccache

On from the first build (`BR2_CCACHE=y`). `build.sh` sets
`BR2_CCACHE_DIR=/zlyme/ccache` in the container and bind-mounts
`ZLYME_CCACHE`. The cache lives on the NVMe alongside the build output,
never on the USB stick. Size it generously — 20 GB or more.

---



## 5. Two scripts: `build.sh` and `storage.sh`

`build.sh` — committed, public, no machine paths. Environment:


| Variable          | Default                   | Meaning                          |
| ----------------- | ------------------------- | -------------------------------- |
| `ZLYME_BUILDROOT` | `./buildroot`             | Buildroot source (tag 2026.02.3) |
| `ZLYME_OUTPUT`    | `./output`                | build tree and images            |
| `ZLYME_DL`        | `./dl`                    | download cache                   |
| `ZLYME_CCACHE`    | `./.ccache`               | compiler cache                   |
| `ZLYME_DEFCONFIG` | `zlyme_minimal_defconfig` | which defconfig                  |


`storage.sh` — gitignored. Sets those variables and execs `build.sh`.

`build.sh --minimal` selects the bring-up image. Full product builds use
`zlyme_defconfig` via `storage.sh`. If the tracked defconfig is newer
than `output/.config`, `build.sh` reconfigures. Watch
`output/build.log`. Do not start a second build on the same output.

`build.sh` refuses to start if `board/` / `package/` contain a `dd` of a
raw `/dev/mmcblk*`. The updater copies kernel files onto `/boot`; the
new squashfs stays on `ZLYME` until initramfs. It does not write a
block device.

---



## 6. GitHub Actions

Workflow is `.github/workflows/build.yml`: **three sequential**
ubuntu-24.04 jobs via reusable `build-stage.yml`. Hosted runners
hard-cap a job at 360 minutes — Docker-fixed cold builds
`34801512689` and `34828905859` were cancelled there, so one job
cannot finish a first image. Each stage keeps docker-engine when
maximizing disk (`skip-components`), compiles ~310 minutes, then
packs ccache (stop docker first; prune 1.5G; `ccache-my355.tar.zst`
on public `Zetarancio/zlyme-cache`). `output/` is 51G and cannot
pass between jobs. Later stages skip if an earlier stage already
has `zlyme-my355-*.tar`. A successful run tags `zlyme-<run_id>`
and marks it latest for Update.pak. Private OTA still needs
`/storage/.config/github-token` on the device. Secret `GH_PAT`
writes the cache repo.

Laptop `storage.sh` still builds locally. Attach `zlyme.img`, sha256,
and `zlyme-my355-YYYYMMDD-*.tar`. Update.pak reads
`/usr/share/zlyme/github-repo` (`Zetarancio/zlyme`).

---



## 7. What we compile, and with what flags

**Not compiled** — libmali and its Vulkan blobs, `rkbin` DDR init and
BL31, WiFi and `rtl_bt` firmware, DraStic tarball. pico-8 is commercial
and user-supplied.

**Compiled** — kernel, u-boot, Mesa, SDL2, RetroArch, the cores and
standalones in section 11, NextUI, the base system.

From the ROCKNIX fork:

```
-mcpu=cortex-a55+crc+crypto+fp+simd+rcpc
```

Knulli uses only `-mcpu=cortex-a55 -mtune=cortex-a55`. We take ROCKNIX.
`-O2` globally. `-O3` per package and only when measured — some libretro
cores miscompile at `-O3`.

SDL2, KMSDRM only, GLES2/GLES3 on, desktop GL off. `sdl12-compat` for
the handful of ports that still want 1.2. RetroArch still targets SDL2.

---



## 8. The frontend

Zlyme is the operating system. NextUI is the menu. We keep NextUI's
menu. We do not take their whole SD-card OS.

NextUI Settings is a real screen. Main list on this board: Network,
In-Game, Appearance, System, About (no FN). Display is inside System
(top). In-Game is RetroAchievements plus save format. Notifications
(save/load overlay) stay as CFG keys for `ra-run`, not a menu.
Zlyme pages (`zlymemenu.cpp`): SSH, Samba, Syncthing, GPU, display
resolution (HDMI), OTG, SD2, ZRAM, undervolt, panel refresh, LED,
backup, factory reset (stock paks only). Tools paks that were
one-line light switches are gone. About rows: version, SSH user/pss.

**Still Tools:** Settings, PortMaster, Autocal, Artwork Scraper,
ScrapeGoat, Files, Moonlight, Overlays (zolek86/NextUI-Overlays, 480p).

**Pin.** LoveRetro/NextUI vendored in `package/system/nextui/src` at
`ae652648` (`src/UPSTREAM`). Package is `BR2_PACKAGE_NEXTUI`, version
suffix `-zlyme39`. `PLATFORM=my355`, `SDCARD_PATH=/storage`.
`RES_PATH` / `PAKS_PATH` are `/usr/share/nextui`, not `.system`.
Stock Tools/Emus are glob-copied to `/storage/{Tools,Emus}/my355`.
Ship `nextui.elf` + `settings.elf`. Emu paks run `ra-run`. We do
**not** ship `minarch.elf`, `gametimectl.elf`, or `MinUI.pak`.
minui-list 0.15.2 and minui-presenter 0.13.2 are Jose MIT packages
linked `-DPLATFORM_NEXTUI` against NextUI objects (those stay
PolyForm NC). `wifi_init.sh` / `bt_init.sh` call Zlyme init.
Volume/lid/power while a pak runs is `zlyme-keylidmon`. PolyForm
Noncommercial is required for NextUI — never relicense it as MIT.

Bump the vendored commit on purpose, copy fonts/icons from the matching
release zip, keep my355 diffs (`/storage`, lid, volume) in the vendored
tree. If a bump fails, stop. Do not grow a second string-replacer.

What not to do:

- Replace Zlyme boot with NextUI's `launch.sh`.
- Follow `my355-latest` without pinning a commit.
- Keep adding Zlyme toggles to Tools (Settings pages exist).
- Fork NextUI to clean Tools.

---



## 9. Connectivity, audio and services

- **WiFi** — `wpa_supplicant` + busybox `udhcpc`. RTL8733BU with our
patches; Knulli already packages this (`BR2_PACKAGE_RTL8733BU`). Wait
for COMPLETED before DHCP.
- **Bluetooth** — BlueZ + `bluez-alsa`. Keep the `btusb` blacklist.
Firmware from ROCKNIX. Settings → Network → Bluetooth.
- **Audio** — ALSA only. Card by name (`rk817ext`). Jack watcher is
`zlyme-jackd` (`S25jackd`).
- **SSH** — OpenSSH (`S50sshd`), not dropbear. Keys on exFAT are copied
to `/var/run/sshd` (no Unix mode bits). `scp` works. Empty root
password until a key is installed under `/storage/.config/ssh/authorized_keys`.
- **Samba** — Buildroot `samba4`, off until Settings. `S70samba`.
- **Syncthing** — packaged (Go), off until Settings.
- **PortMaster and box64** — packaged. Image has `bash` and `/roms/ports`
→ `Roms/Ports (PORTS)/`. Gravity Defied launched through PORTS.pak.
Python3 is rebuilt with SSL/SQLite/`PY_PYC` + CA bundle; post-build
asserts `_ssl`.

---



## 10. The GPU stack, and the switcher

Both stacks installed. Runtime select is `gpudriver` / Settings.
**Default libmali.** Impossible on Knulli ("kernel has no Panfrost"); a
mainline kernel is what buys the choice.

Apps `dlopen libEGL.so.1`, so bind-mount the blob onto the **versioned
SONAME real path**, not `libEGL.so`. Blacklist the other kmod.
`S15gpudriver` after `/storage` is up.

Vulkan = Mali ICD when `gpu=libmali`. No PanVK in this Mesa. Pick the
API inside PPSSPP / Flycast / RetroArch, not as an OS-wide mode.

`mali_kbase` is an OOT module built against 7.0.2. After a kernel
`this_module` ABI change (`DEBUG_SPINLOCK`), dirclean OOT drivers.

---



## 11. Stages (status)

Ordered so each was independently testable. They are no longer a
backlog; this is what the image is.

**Stage 1 — minimal bootable image. Done.** Buildroot skeleton,
`BR2_EXTERNAL`, Docker, ccache, `build.sh`/`storage.sh`, mainline 7.0.2
and DTS, u-boot, busybox init, SD boot with GPT legacy-bootable. Serial
shell. RAM is 1 GiB. DDR blob `rk3566_ddr_1056MHz_v1.23.bin` + BL31
v1.44.

**Stage 2 — connectivity. Done.** RTL8733BU, WiFi, Bluetooth, SSH.

**Stage 3 — GPU and audio. Done.** Panfrost GLES (`kmscube`), libmali +
`mali_kbase`, bind-mount switcher, ALSA, jack watcher, A2DP. Default
flipped to libmali on 2026-09-12. Vulkan loader + Mali ICD for emus.

**Stage 4 — RetroArch and cores. Done on hardware.** `zlyme_defconfig`
builds the cores. NextUI only lists systems that have a pak + a line in
`rom-dirs.txt`.

NextUI systems (pak → core or binary):

- NES (FC): nestopia
- GB / GBC: gambatte
- GBA: gpsp
- SNES (SFC): mednafen_supafaust
- SMS (MS) / GG: genesis_plus_gx
- MD: **picodrive**
- 32X: picodrive
- PCE: pce_fast (Knulli install name; `mednafen_pce_fast` is a symlink)
- Neo Geo AES/MVS (FBNEO): fbneo
- Arcade (MAME): mame078plus (symlink `mame2003_plus`)
- Neo Geo CD: neocd
- NGP: mednafen_ngp
- WonderSwan: mednafen_wswan
- Virtual Boy: vb (symlink `mednafen_vb`)
- Pokémon Mini: pokemini
- Atari 2600: stella
- Atari 5200 (A5200): a5200
- Atari 7800: prosystem
- Atari 8-bit (A800): atari800
- Atari ST (ST): hatari
- ColecoVision (COLECO): gearcoleco
- Intellivision (INTV): freeintv
- MSX: bluemsx
- Odyssey 2 (O2): o2em
- Sega SG-1000: genesis_plus_gx
- SuperGrafx (SGX): mednafen_supergrafx
- Vectrex (VEC): vecx
- Lynx: handy
- 3DO: opera
- DOS: dosbox_pure
- PS1: pcsx_rearmed (64-bit)
- N64: mupen64plus_next
- Saturn: yabasanshiro
- TIC-80: tic80
- Pico-8 (PICO): user `pico8_64` + `pico8.dat` (Bios/PICO or the ROM folder); hidden until both exist
- Pico-8 fake-08 (P8): fake08
- Ports (PORTS): `.sh` only
- RPG Maker 2000/2003 (EASYRPG): easyrpg (Knulli Player 0.8.1)
- RPG Maker XP/VX/Ace (MKXPZ): mkxp-z (white-axe libretro)

Standalones with paks: PSP, DC, NDS (DraStic), AMIGA, DOOM, PICO-8,
ScummVM, OpenBOR, Daphne (Hypseus), Windows (Wine/box64). N64 is
mupen64plus_next; NDS is DraStic. parallel_n64 and melondsds are
**not** in the image.

**Not shipping:** mGBA, Snes9x, SwanStation, DuckStation, libretro-Flycast,
Dolphin, Azahar, Vita3K, AetherSX2, Qt6, SDL3, 32-bit userspace.

Locks: GBA = gpsp; SNES = mednafen_supafaust; PS1 = pcsx_rearmed 64-bit;
DC = Flycast standalone; Saturn = yabasanshiro libretro; NES = nestopia.

**Stage 5 — frontend. Done enough to play.** Menu boots. GBA (and
others) launch through emu paks. MENU opens RGUI, MENU+Start quits.
Settings bounce, fonts, `zone.tab`, Bluetooth abort, last.txt newline
are fixed. Scrapers still want a UI retest.

**Stage 6 — standalones. Packaged.** NextUI paks: PSP (PPSSPP), DC
(Flycast), NDS (DraStic), AMIGA (Amiberry), DOOM (GZDoom), **PICO-8**
(user `pico8_64` + `pico8.dat`), ScummVM, OpenBOR, Daphne, Windows
(Wine). Moonlight is a Tools pak.

**Stage 7 — the rest. Done enough.** Samba4, Syncthing 2.0.13,
PortMaster-GUI, box64 v0.4.4. Off at boot until Settings. PortMaster
harbourmaster reads quoted `NAME`/`VERSION`/`HW_DEVICE` in os-release
(not `CFW_NAME`). Image sets `NAME="Zlyme"` `VERSION="zlyme39 (date)"`
`HW_DEVICE="miyoo-flip"` and aliases `zlyme` to the ROCKNIX first_run
path. Samba tmpfs `/var/lib/samba` is in the image.

**Stage 8 — performance pass. Live.** VOP2 BCSH identity only on this
panel (contrast/sat sliders removed; they blacked the DSI). Smart
schedutil cores 01 DMC 324M; PORTS/PSP Performance 0123 DMC 1056M
simple_ondemand. zram 384 MiB lz4. IRQ pin `dw-mci` + `ehci_hcd:usbN`
(fd880000) to CPU0. BT scan starts. `/roms/ports` + bash.

**OTA.** Proven. Drop the newest `zlyme-my355-*.tar` on `ZLYME` and
reboot. Class A **waits** for S18 (do not fork it with NextUI). The
updater copies kernel/dtb/overlays and splash anims onto `/boot`;
initramfs copies `pending/zlyme` over the live FAT file. `ZLYMEBOOT`
is a fixed **1300M**. Do not Etcher over a games card.

---



## 12. Remaining work

Live card is the zlyme40 Etcher image plus tmpfs overlays (pcre2-16,
cairo, fontconfig, libaio, SDL3 stub, wine wrapper). Those belong in
the next squashfs. Do not Etcher a games card. Do not start a second
`./build.sh`. User asked to dispatch GHA after this push; this host
has SSH to GitHub but no `gh` login/token, so `workflow_dispatch`
could not be started from here.

Proved on the card:

- Lid close stays hybrid screen+radios off; power button is mem.
- Splore **download** a cart in the UI (list update already worked).
- Volume in game and Splore. Clock after Wi-Fi is 2026. No NTP row.
`zlyme-keylidmon` / `zlyme-jackd` up. PSP launch.sh has no `--memstick`.
- List governors: smart (2c schedutil 408–1800, DMC 324). GB in-game
was 4c schedutil 408–1800.
- Samba: `zlyme-ctl set samba on`, `smbd` up, `/var/lib/samba` →
tmpfs `/tmp/samba-lib`, `smbclient -N -L localhost` shows `storage`.
- Smash `16777216` at `/storage/Roms/Nintendo 64 (N64)/Super Smash Bros. (USA).z64`.
SSH launch stayed up after `EMU_EXE=mupen64plus-next`. Not walked
from the NextUI list.
- First flip after the zlyme39 OTA is **7.6 s** (`/tmp/boot-timing`).
- Slime boot gif moves. PortMaster launches twice. WiFi list scrolls
(was 4 rows on the flashed image; tree now reserves one pill so 5 fit).

User still needs to test:

- OTA: drop `zlyme-my355-*.tar` in `/storage/.update` and reboot.
Galaxy during extract and resize. `/boot` gets Image/dtb/anims.
- PortMaster version `zlyme39 (date)` after the next image.
- Pico-8 hidden without bios; listed when `pico8_64` + `pico8.dat`
sit in `Bios/PICO` (not the ROM folder).
- Smash from the NextUI list (N64 rumble while in-game).
- Switch Pro in a game after Settings shows **Connected: yes**.
- A2DP vs HDMI by ear.
- MENU+Start to quit a pak.

Still open:

- Dolphin GC/Wii: `Failed to initialize video backend` then double
free, even with NextUI down, `zlyme-drm-release`, `-p drm|fbdev`,
`-v OGL|Software`. Cubeboot.dol is a legal smoke; IPL is optional
and was not on SD2.
- Wine: `wine --version` is wine-11.0. First prefix still
`could not load kernel32.dll, status c0000135`. WINELOADER/WINESERVER
must be the `/usr/bin` box64 wrappers, not the raw x86_64 ELFs.
- GitHub Actions is manual `workflow_dispatch` only. Artifact
retention is 1 day. Device PAT is only needed while the repo is
private (`/storage/.config/github-token`).
- 32-bit (`box86` + armhf libs): not in scope.

Resolved (do not re-open):

- Live U-Boot delay is still 2 until `u-boot.itb` is rewritten.
OTA never writes the FIT; `CONFIG_BOOTDELAY=0` only lands with
Etcher of `zlyme.img` or a UART `setenv`. Do not Etcher a games
card for this.
- RAM is 1 GiB.
- DDR blob is `rk3566_ddr_1056MHz_v1.23.bin` with `rk3568_bl31_v1.44.elf`.
- NextUI is the frontend (not MinUI, not a from-scratch list).
- Emulator set is curated, not ROCKNIX's ~150.
- GPU default is libmali, not Panfrost. `mali_kbase` on 7.0.2 is the
ROCKNIX Flip stack. Lowercase IRQ names first (ROCKNIX patch next
to the `.mk`) so `platform_get_irq_byname` does not print JOB -6.
Default `/etc/modprobe.d/zlyme-gpu.conf` blacklists panfrost before
udev coldplug; S15 bind-mounts the live choice.
- Tools light-switches belong in Settings. OS update is Settings → Update,
  not Tools `Update.pak`.
- Full-disk Etcher of `zlyme.img` is for empty cards; later updates are the tar.
- Every package and every pak ships a `LICENSE` (`f3620e7`).
- GPT has no `rootfs` partition; OS is the `zlyme` file on `ZLYMEBOOT`.
Pending OTA squashfs is on `ZLYME`. `ZLYMEBOOT` is a fixed 1300M.
- First-boot resize keeps `/boot` mounted (Knulli/ROCKNIX). Proved and
committed (`239d475`: skip `partprobe`, `reboot -f`). 32MB seed → 57G,
FAT-proof `/Image`. Do not lazy-umount the boot FAT; that plus
`partprobe` zeros FAT1.
- Game switcher is disabled in NextUI. If one is ever added it must be
session-level (same helper as close) so it works for libretro,
standalones, PortMaster, and Pico-8. Minarch-only or RA-only is not
acceptable.
- `libudev-zero` is not used (image is eudev).
- SSH is OpenSSH. OTA drop-tar-and-reboot. PortMaster Gravity Defied.
Overlays `curl`. BT `scan on`. `cfg80211=m`. S13/S36 live.

