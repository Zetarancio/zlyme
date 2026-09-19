# Zlyme notes (my355 / Miyoo Flip)

Hardware and operational facts. Every line here cost a debugging session.
What we are building is `PLAN.md`. Running narrative is `LOGBOOK.md`.
`TODO.md` is a one-off prompt and stays gitignored. Device serial dumps
live in `DEVLOGS/` (gitignored). Hardware diary, logbook, and plan are
committed with the tree.

OS is **Zlyme**. Board / NextUI platform is **my355**. Kernel dtb stays
`rk3566-miyoo-flip.dtb`. Image is `zlyme.img`. Storage label `ZLYME`,
boot label `ZLYMEBOOT`.

Two sources of truth outrank this file:

1. The ROCKNIX fork at `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/ROCKNIX`
   (kernel patches, DTS, mixer names, flags known good on this SoC).
2. The device wiki at `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP`.

Knulli/Batocera are the parts bin for **emulator recipes**. Hardware stays
ROCKNIX / the wiki. Busybox init, KMSDRM, no compositor.

## Upstream pins (for “anything new from X?”)

Refresh this table after a merge. Compare the clone you actually harvest
from against GitHub if they have moved. Dated **2026-09-17**.

| Tree | Clone / branch | SHA at last look | GitHub tip if different | Notes |
| --- | --- | --- | --- | --- |
| ROCKNIX **fork** (ours) | `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/ROCKNIX/distribution` `origin` `Zetarancio/distribution` **`flip`** | `d249b09bd9` 2026-09-02 “Merge commit '1ebff24f36' into flip” | — | This is the hardware source of truth. Merge-base includes `1ebff24f36` (`ci: truncate changelog…`, 2026-09-01). |
| ROCKNIX **upstream** | remote `upstream` = `ROCKNIX/distribution` | last merged = `1ebff24f36` | **`6ec91044aad1`** `HEAD` as of 2026-09-17 | Upstream has moved since the flip merge. Absorb candidates live in `1ebff24f36..6ec91044aad1`. |
| Device **wiki** | `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP` (`Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering`) **`main`** | `cf6500c` 2026-09-03 “docs: explain ROCKNIX image zip vs Specific .img” | same (`cf6500c53fb9`) | Hardware write-ups, mixer names, boot how-to. |
| **knulli** | `~/Downloads/knulli-linux/knulli-linux` `knulli-main` | `0b1fd94` 2026-08-25 “Update 0203-improve-triggers.patch” | **`064cd0900e7d`** `knulli-cfw/knulli-linux` `knulli-main` (2026-09-11 “fix-yabasanshiro-build”) | Emulator `.mk` / patches. Local clone is behind GitHub. |
| **SpruceOS** | `/home/ale/SPRUCEOS/spruceOS` | `90a10ed1a` 2026-09-11 “Hold onto your butts!” (`main`) | `origin/main` **`c104be3fd54c`**; `origin/Development` **`4732b5a46a7c`** (2026-09-11 release notes). Tags `v4.4.0` / `v4.4.1`. Also `Zetarancio/spruceOS`. | Governors, pak ports, boxart (libretro-thumbnails / PyUI), HID reconnect. Prefer **Development** for “what’s new”. |

How to ask later: “is there anything new I can absorb from knulli / ROCKNIX / Spruce / the wiki?” — diff that repo from the SHA in this table to its current tip, then only take emulator recipes from knulli, hardware from ROCKNIX+wiki.

---

## 1. Host serial (Flip debug UART)

Device console is **ttyS2** at **1500000** 8N1, 3.3 V. Host USB-UART is
**`/dev/ttyUSB0`**. Login `root`, empty password. Panel `console=tty1` is
kernel log only — Buildroot spawns one getty and it is on serial.

Scripts: `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP/test-scripts`
(`serialcon.py`, `serialbreak.py`). Do not open minicom while a capture
runs. Do **not** `tcsetattr` with `termios.B1500000` — even if Python
exposes that name (here it is the integer `1500000`), the link reads
**0 bytes**. Working method is always:

```
stty -F /dev/ttyUSB0 1500000 raw -echo -ixon -ixoff cs8 -cstopb -parenb
```

then `os.open("/dev/ttyUSB0", os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)`
keeping the speeds `stty` set. The scripts wrap that. `serialbreak.py
--no-break --log FILE` is a plain boot capture (keep the process alive;
a background `cat` inside a command substitution is reaped). Do not use
a finished-marker that also appears in the script source.

Harmless boot-chain noise: `Card did not respond to voltage select! : -110`
(u-boot `efi_mgr` probing the other MMC), `No OPTEE provided by BL2`
(BL31-only FIT).

---

## 2. Boot chain and GPT

RK3566 bootrom looks for idbloader at **sector 64** (32 KiB). Miyoo's NAND
preloader looks for u-boot in a GPT partition named **`uboot`** or at raw
**sector 16384** (8 MiB). Those coincide, so one partition satisfies both.

| GPT name   | Offset | Contents |
| --- | --- | --- |
| (raw)      | 32K    | idbloader |
| `uboot`    | 8M     | u-boot FIT (`d00dfeed`) |
| `boot`     | 12M    | **1300M** FAT32 `ZLYMEBOOT`, **legacy-bootable**: Image (embedded initramfs), dtb, overlays, extlinux, one squashfs **file** `zlyme` |
| storage    | rest   | 32MB empty exFAT seed `ZLYME` (ROCKNIX `STORAGE_SIZE`), grown + `mkfs.exfat` on first boot |

Initramfs (busybox in the kernel Image) mounts `LABEL=ZLYMEBOOT`, and
if `/storage/.update/pending/zlyme` exists on `ZLYME` it copies that
file over `/zlyme`, then loop-mounts it and `switch_root`. Keep
`ZLYME` mounted at `/storage` across that (S15 remount of a grown
exFAT was ~0.8 s). Do not pass `root=PARTLABEL=rootfs` — there is no
such partition. MMC numbering is not stable; the boot volume is the
FAT **label** `ZLYMEBOOT`. cmdline, fstab, and genimage must agree.

`extlinux.conf` last console is `ttyS2,1500000n8` so serial is `/dev/console`.
U-Boot reads `FDTOVERLAYS` **before** Linux. Do not rewrite overlays on every
`S15bootpart` boot. Settings call `zlyme-ctl apply-overlays` on change; OTA
writes them after a stock extlinux lands. Empty `FDTOVERLAYS` with defaults
(undervolt off, otg/hdmi/sd2 on) is expected.

First boot: `S13resize` keeps `/boot` mounted (squashfs loop), umounts
**storage only**, `sgdisk -e`, `parted resizepart 100%` (BLKPG), `mkfs.exfat`,
**`reboot -f`**. Do **not** `partprobe` while the boot vfat is live, and do
**not** `sed` `autoresize` in that same pass — that pair zeroed FAT1
(`DEVLOGS/firstboot-20260913.log`: u-boot still found GPT `boot` / part 2
and `extlinux.conf`, then `Invalid FAT entry` on `/Image`). Comment
`autoresize` only on a later boot that already sees `ZLYME` >600MB.
Proved 2026-09-13 (`DEVLOGS/firstboot-20260913-noprobe.log`): grow `OK`,
then three u-boot passes all `Retrieving file: /Image` (resize reboot and
a manual reboot). GPT names stay `uboot` / `boot` / `storage`, labels
`ZLYMEBOOT` / `ZLYME`. ROCKNIX `fs-resize` skips `partprobe` and reboots;
Knulli `S02resize` keeps `/boot` mounted. Do not Etcher over a grown
`ZLYME`. Backup GPT at the image's last LBA is normal until resize.

ROCKNIX / Knulli / Batocera keep the OS as a squashfs **file** on FAT
and loop-mount it from initramfs. Zlyme does the same: live file `zlyme`
on 1300M `ZLYMEBOOT`. The **pending** OTA squashfs is on `ZLYME`
(`/storage/.update/pending/zlyme`). OTA does not rewrite GPT.

OTA copies Image/dtb/overlays and `splash.anim`/`progress.anim` onto
FAT, then initramfs copies the pending squashfs over `/boot/zlyme`.
It does **not** rewrite `u-boot.itb`. The updater that was on the
device before this tree skipped the anims; Image/dtb were already
copied. New OTAs from this updater include them.
`CONFIG_BOOTDELAY=0` only lands with Etcher of `zlyme.img` (or a
UART `setenv`). `external.mk` forces that 0 after U-Boot configure
because the quartz64 defconfig reverts to 2 on re-extract.

Initramfs blits the still from the ramdisk, then loads `splash.anim`
off FAT (`/boot_root`). Anims are too big for the ramdisk. After
`switch_root` that process still has the old root, so `S12splash`
kills it and starts `/usr/sbin/zlyme-splash` from squashfs **before**
`S13resize`. Resize and OTA send SIGUSR1 (`zlyme-splash-progress`)
for the galaxy lockup. NextUI `PLAT_initVideo` `killall zlyme-splash`
so KMSDRM can take the panel. Do **not** replay the gif in SDL.

Class A may **fork** `S17sd2` only. Do **not** fork `S18zlymeupdate`:
extracting the tar then `reboot -f` after NextUI is on screen yanked
the list (2026-09-17 apply.log). Wait for S18; success never returns.
`zlyme-storage` only mounts and unmounts; it writes
`/run/zlyme/libraries` and SIGUSR1s NextUI. No mergerfs and no
`kill -9 nextui.elf` on card change.

Meter is `/tmp/boot-timing` (also copied to
`/storage/.config/zlyme/boot-timing`). Live **zlyme39** first flip
**7.6 s** (zlyme37 14.0, zlyme38 12.0). Initramfs keeps `ZLYME` mounted
so S15 is a no-op (~0.02 s). rc.late and Tools binds wait for
`nextui-first-flip`. Do not `udevtrigger` block devices in S16; S17
owns present cards.

Do not seed 35 empty Pretty dirs; prune ones that are still empty
(including a leftover `.media`). `LD_LIBRARY_PATH` is `/usr/lib`
then the card lib dir. `nextui.elf` logs to `/tmp/nextui.txt`.
With About → System logs on, session `next.txt` and per-pak `TAG.log`
live in `/storage/.logs` (initramfs also dumps `dmesg-init.txt` when
`/boot/zlyme-logs` exists). RetroArch 1.22 splits `--appendconfig` on
`|` not comma, and `input_driver = "sdl"` is SDL3 — use `sdl2`.
Fluidsynth 2.4 on this image DT_NEEDED `libSDL3.so.0`; post-build
writes a versioned stub (`board/my355/sdl3-stub.c`). Do not
`--remove-needed` that SONAME (GNU VERNEED assert). Overlaying
`/usr/lib` hides the Mali GLES bind-mounts until `S15gpudriver` runs
again. NextUI can leave DRM master; `zlyme-drm-release` does
SET_MASTER then DROP_MASTER on `/dev/dri/card0` before a pak.
AetherSX2 BIOS is `Bios/PS2`. Dolphin IPL is
`Bios/GC/{USA,EUR,JAP}/IPL.bin`. Wine Kron4ek 11 + box64:
`WINELOADER`/`WINESERVER` must be the `/usr/bin` wrappers.
InitSettings does not `sync()` the settings file or open DRM for
identity TV props. First flip happens before `loadLast` and the thumb
threads. `mount_fs` uses blkid TYPE only.

List governors after that flip are Spruce **smart**: CPU `schedutil`
408–1800, cores 0+1 online, DMC `powersave` 324, GPU `simple_ondemand`.
`zlyme-halt` ejects SD2/USB then `reboot -f` / `poweroff -f` without
umounting `/boot` or `/storage`, so those two always come up dirty.
The games card (mmcblk1) does not.

---

## 3. Writable paths (what survives reboot and OTA)

exFAT `/storage` (label `ZLYME`) is the only persistent volume. Root is
read-only squashfs. Config lives under `.config` so a backup is one
directory.

| What | Path |
| --- | --- |
| OS flags | `/storage/.config/zlyme/<name>` (`zlyme-ctl`) |
| Wi-Fi | `/storage/.config/wpa_supplicant.conf` |
| RetroArch user cfg | `/storage/.config/retroarch/retroarch.cfg` |
| RA core options | `/storage/.config/retroarch/config/<core>/` |
| MinUI / NextUI settings | `/storage/.config/nextui/shared/minuisettings.txt` |
| Per-device userdata | `/storage/.config/nextui/my355/` (logs, hooks) |
| BIOS | `/storage/Bios` on the OS card, or `$library/Bios` on SD2/USB when that volume has a Bios folder (Pico-8: `Bios/PICO/pico8_64` + `pico8.dat`) |
| Saves | `$library/Saves/<TAG>` on the same volume as the ROM (`/storage`, `/mnt/sd2`, or `/mnt/media/<label>`) |
| ROMs | `$library/Roms/<Pretty Name (TAG)>`. NextUI merges every root in `/run/zlyme/libraries` by tag. |
| Pak / boot logs | `/storage/.logs` when Settings → About → System logs is on (`logs=on`) |
| OpenSSH host keys | `/storage/.config/ssh` (copied to `/var/run/sshd` because exFAT has no mode bits) |
| Bluetooth | `/storage/.config/bluetooth.tar` (BlueZ tree lives on tmpfs `/run/bluetooth`) |
| Settings backup | `/storage/zlyme-backup.tar.gz` |
| OTA drop | `/storage/.update/zlyme-my355-*.tar` (newest mtime; the GitHub pak still names it `update.tar`) |
| Stock Tools / Emus | `/storage/Tools/my355/`, `/storage/Emus/my355/` (glob from the image; extra names survive OTA) |

There is **no** `/storage/.system`. Fonts, paks seed, and version live
under `/usr/share/nextui`. Session copies `*.pak` onto the card by
glob. Factory reset deletes `/storage/.config/nextui` and re-copies
stock pak names only.

Seed defaults (only if the flag file is **absent**): wifi/bluetooth/ssh on,
samba/syncthing off, **gpu=libmali**, refresh=60, undervolt=off, led=battery,
otg/hdmi/sd2 on, boost=off, zram=on, **logs=off**. CPU/GPU governors are not Settings
flags; each pak's `launch.sh` calls `zlyme-governor play` or `heavy`
(MENU+Y can override). NextUI on the list is still `smart`. New paks
source `zlyme-library` so `$library/Saves` and `$library/Bios` follow
the ROM. HOME/`XDG_*` stay on the OS card.

An **empty** flag file is not "off" — a full disk used to truncate flags.
`zlyme-ctl get` falls back to the default. Do not overwrite an existing
`wpa_supplicant.conf` when seeding. Seed **batteryperc=1** (session
one-shot `.zlyme-batteryperc-on` flips existing cards that had 0).

BusyBox tar has **no `-z`**. Backup/restore and OTA snapshots use
`tar -acf` / `tar -axf` (compress from the `.gz` suffix).

Settings → Backup now / Restore were tested live (create/list/extract).
Restore does not auto-reboot.

---

## 4. GPU stacks

Mali-G52 1-Core-2EE (G52L / 0x7402). Panfrost and `mali_kbase` **cannot**
share the GPU. Switching is a reboot-level change.

**Default is libmali.** Existing cards keep `/storage/.config/zlyme/gpu`.

Mesa stays in `/usr/lib` (`libEGL.so.1` → `.so.1.0.0`). The Mali blob lives
in `/usr/lib/mali` (SONAME `libmali.so.1`). Apps `dlopen` **`libEGL.so.1`**,
so bind-mount the blob onto `readlink -f` of the versioned SONAMEs
(`libEGL.so.1`, `libGLESv1_CM.so.1`, `libGLESv2.so.2`, `libgbm.so.1`).
`/proc/mounts` never shows the symlink; unmount that real path.
`ld.so.conf.d` does not work: `ldconfig` files the blob under `libmali.so.1`
whatever the symlink is called.

`S15gpudriver` runs **after** `S15bootpart` so the flag is readable. It
bind-mounts `/etc/modprobe.d/zlyme-gpu.conf` to blacklist the other kmod.
Do not autoload panfrost from `modules-load.d` or both drivers race.

Vulkan is **not** an OS-wide switch. Pick Vulkan **inside the emulator**.

- libmali: ICD `/usr/share/vulkan/icd.d/mali_icd.json` (Vulkan 1.3.276).
  `VK_ICD_FILENAMES` is set by `/etc/zlyme-gpu-env.sh` (sourced by
  `nextui-session`, `ra-run`, login shells).
- Panfrost: GLES. Buildroot **2026.02 mesa3d has no PanVK Kconfig**. There
  is no conformant PanVK on G52 anyway (Mesa docs: G610).
- PPSSPP and Flycast are built with Vulkan if the loader is present.
  Spruce Flip PPSSPP still defaults to OpenGL. `EGL_BAD_NATIVE_WINDOW`
  is a windowing path, not "missing Vulkan". A PSP `.chd` did boot
  (`PPSSPPSDL` `Booted …chd`); do not treat that toast as a hard fail.

`mali_kbase` `error -6: IRQ JOB not found` on this DTS is normal.

GPU governor sysfs is **`/sys/class/devfreq/fde60000.gpu`**. Spruce stock
"GPU" was DMC (`/sys/class/devfreq/dmc`) because 5.10 mali_kbase. DMC
follows the Smart/Performance/idle profiles (324 M vs 1056 M). There is
no DMC picker in Settings.

Contrast/saturation on this SoC is **VOP2 BCSH**, not DRM CTM (mainline
`has_ctm = false`). Stock Flip programs VP1 BCSH after composition so
every DRM client inherits it. Userspace uses TV connector properties
`brightness/contrast/saturation/hue` 0–100, identity 50. **Do not expose
contrast/saturation in NextUI on my355** — those two properties black
the DSI panel and the value is stored in `msettings.bin`, so reboot
stays black. `apply_bcsh` still writes brightness/hue identity 50 and
forces contrast/sat 50. `hasContrastSaturation()` is tg5040 only.
`zlyme-bcsh` re-applies after NextUI drops DRM master (modeset can drop
the props).

---

## 5. Audio

ALSA only, no Pulse/PipeWire. HDMI is **card 0**, codec is **`rk817ext`**
(card 1). Always resolve the card by name. Mainline mixer is
**`Playback Mux`**, not the BSP's `Playback Path`. Shared software volume
is **`FlipVolume`** on the codec card (HDMI has no hardware volume).

Sinks: `codec` (speaker/headphones via `zlyme-jackd`), `hdmi`, `bt`
(`bluealsa`). `zlyme-audio` verbs. `nextui-session` must `eval
$(zlyme-audio export)` so RetroArch inherits `ZLYME_SINK`. Jack vs
speaker is not a Settings switch — the watcher owns it.

---

## 6. Radios, SSH, services

RTL8733BU is one USB device with one firmware image for Wi-Fi and BT.
Loading the halves in the wrong order resets the chip and takes `wlan0`
with it. **Keep the `btusb` blacklist** until `S35`. Use real **kmod**:
busybox `modprobe` ignores `blacklist` unless the feature is on, and
**ignores `softdep` always**. Firmware `rtl8723fu_fw.bin` /
`rtl8723fu_config.bin` are not in linux-firmware; they come from ROCKNIX.

`S30wifi` must wait for `wpa_state=COMPLETED` before `udhcpc` or the
client lands on 169.254. `S28` starts NextUI **before** Wi-Fi/BT so the
game list is not blocked. `S16display` fires `udevadm trigger` in the
background so `wlan0` exists before `S30` without delaying the list.
Do not start BT in parallel with Wi-Fi. Do not start `S30wifi` from
`S15`. `S18zlymeupdate` is Class A and **waited** (not forked).

SSH is OpenSSH (`S50sshd`) so SFTP works. Host keys on exFAT have no
Unix mode bits; the init script copies them to `/var/run/sshd`. Empty
root password. BusyBox wget of large HTTP files stalls. Weak AP (~−85
dBm) is a few Mbit/s — copy OTA tars onto the SD instead of hoping
wget/scp will finish.

Live debug unit is `root@192.168.0.108` (`Host flip-lan` in ssh
config may still say `.156`). After an OTA the OpenSSH host key
changes — `ssh-keygen -R` that IP and `StrictHostKeyChecking=accept-new`.

Large OTA tars (~579M) over this AP are ~130 KB/s. Python
`http.server` has no Range; `curl --max-time 300` dies at ~40M. `scp`
to `/storage/.update/zlyme-my355-update.tar` finished.

Samba4 `S70samba` is the share. Overlay `S91smb` starting nmbd is a
no-op (`disable netbios = yes`). `/var/lib/samba` cannot live on
squashfs (RO) **or** on `ZLYME` (exFAT cannot `chmod 0700`
`private/msg.sock`). Image symlink is `/tmp/samba-lib`; S70 bind-mounts
tmpfs if the directory is still real. Syncthing and Samba are **off at
boot** until Settings. Settings calls the init script, not only
`zlyme-ctl set`.

---

## 7. NextUI and RetroArch

Zlyme is the OS. NextUI is the menu. Vendored LoveRetro/NextUI
`ae652648` in `package/system/nextui/src` (`src/UPSTREAM`). Package pin
is `ae652648…-zlyme39`. `PLATFORM=my355`, `SDCARD_PATH=/storage`.
PolyForm Noncommercial is fine.

`nextui.elf` writes `'$emu_pak/launch.sh' '$rom'` to `/tmp/next` and
exits. `nextui-session` evals that and restarts the menu when the
emulator exits. Emu paks `exec ra-run`. We do not ship `minarch.elf`
or `gametimectl.elf`. Settings Game (RetroAchievements + save
format) is mapped onto RetroArch by `ra-run` (`cheevos_enable` stays
on from Settings even with no WAN). Quick menu is Wifi, Bluetooth,
Settings, then Sleep. `nextval.elf` dumps minuisettings as JSON for
Apostrophe.

Paks are **bind-mounted** from squashfs when `version.txt` matches. Do
not copy Artwork Scraper onto exFAT every boot.

ROM list uses Knulli-style extensions (`rom-exts.txt`). BIOS for PS1 is
`/storage/Bios/PSXONPSP660.bin` (not under `Bios/PS`). RA
`system_directory = /storage/Bios`.

Input is SDL2 + Nintendo mapping for `retrogame_joypad` (`a:b1,b:b0`).
Physical A is east. MENU is SDL GUIDE (button **5**). The udev
autoconfig still numbers MENU as 10.

RetroArch:

- `/etc/retroarch.cfg` is `--appendconfig` on every launch (KMSDRM,
  spruce performance keys, hotkeys). **`video_driver` is not listed**
  so a user Vulkan choice in the card cfg can persist. The zlyme RGUI
  preset ships in the RetroArch package as
  `/usr/share/retroarch/assets/rgui/zlyme.cfg`. `ra-run` appends
  `/usr/share/retroarch/rgui-theme.cfg` **last** (`input_menu_swap_ok_cancel_buttons = false`)
  so a stale user cfg cannot keep the default theme. Autoconfig is
  `/usr/share/retroarch/autoconfig` (`input_a_btn=1`, `input_b_btn=0`).
- MENU (5) opens RGUI. MENU+Start is `zlyme-pak-hotkey`, not RA quit.
  Do not bind Enable Hotkey to MENU or the menu is delayed.
- First-run seed: `/usr/share/zlyme/retroarch/retroarch.cfg` copied
  once if the user cfg is missing or 0 bytes.
- MD pak is **picodrive** (spruce Flip). SMS/GG stay genesis_plus_gx.
  NES is nestopia. GBA is gpsp.
- RA 1.22 needs `liblzma.so.5` (libchdr). Image curl needs
  `libzstd.so.1`. Select `BR2_PACKAGE_XZ` and `BR2_PACKAGE_ZSTD`.
- Pico-8 is user-supplied `pico8_64` + `pico8.dat` in **`Bios/PICO`**
  (MinUI). Splore's pad mapper is the pak PID so it ungrabs on exit.
  `-home` is `.config/nextui/shared/Pico-8-native`. BBS carts go in that
  `carts/` dir, or the rom folder if it is writable. Set `SSL_CERT_FILE`.
  Private-repo OTA: optional `/storage/.config/github-token` (PAT, not
  in the image). PPSSPP memstick is `$USERDATA/.config/ppsspp` (the
  `PSP/` folder next to ISOs is the memstick tree — hide it; leftover
  ROCKNIX copies look the same).

Sleep defaults: screen **120s**, mem suspend **600s**. Session migrates
factory 60/30 and the old "write 0 every start" leftover once. A user
**Never (0)** is left alone. Wake: RK817 pwrkey, lid (`SW_LID`), volume,
or any key. Deep sleep is `echo mem` with `mem_sleep` **deep** (the
`rk808-rtc` alarm is a wake source). Test with
`echo 0 > /sys/class/rtc/rtc0/wakealarm; echo +N > wakealarm; echo mem`
over serial — SSH dies. Do **not** use `echo freeze` as a stand-in:
UART is not a wake IRQ, and a BT-sink watcher that kills RetroArch on
A2DP drop will restart the ROM. ROCKNIX `sleep.sh` **stops Bluetooth
and disables Wi-Fi before mem** so `rtl8733bu_power_suspend_late` can
cut the combo GPIO without `hci_dev_close` hanging freeze; `post`
starts them again. `zlyme-radios pre|resume` is that sequence.
`PWR_enterSleep` / `PWR_exitSleep` call it. The quick-menu **moon**
calls `PWR_sleepNow` → `PWR_deepSleep` (`BIN_PATH/suspend` then
`echo mem`). Hybrid `PWR_sleep` (screen off, wait `suspendTimeout`,
then mem) is still the power-button / autosleep path. `PWR_exitSleep`
used to restart only `S30wifi`.

ALSA default PCM reads `ZLYME_SINK` at **open**. `bluetoothctl connect`
does not write `audio.conf`. `zlyme-btsink` follows `bluealsa-cli
list-pcms` `a2dpsrc` and must **debounce** (8733bu re-enumerates for
seconds after mem). Killing the emu is how a sink change becomes
audible; it is also how a suspend looks like a ROM restart. Hold file
`/tmp/zlyme-keep-emu`. Codec occupancy `pcmC1D0p` vs a RetroArch
`pcm-io` thread with no kernel PCM is the BT vs speaker tell.

Tools that remain paks: Settings, PortMaster, Autocal, Artwork Scraper,
ScrapeGoat, Files, Moonlight, Overlays. Wi-Fi/Bluetooth/SSH/Samba/
Syncthing/GPU/display resolution/Backup/undervolt/boost/zram/OTG/SD2 live in Settings.
CPU/GPU governor pickers are gone; `zlyme-governor` owns Smart
(schedutil, cores 01, DMC 324M), Performance (1800, 0123, DMC 1056M),
optional Overclock 1992, and idle (conservative, screen off).

Settings Bluetooth abort was `getValue` asserting on an empty values
list (Generic + DeferToSubmenu). The row is a Button; empty indices
return `{}` / `""`. Scan `FAIL-BUSY` is a separate radio issue.

Do not add a uinput HID-scancode translator for stock Apostrophe Tools.
Flip joypad emits `BTN_*`. Scrapers were rebuilt against my355 `api.c`.

`PLAT_initVideo` retries kmsdrm window/renderer until layer textures
work. Do not insert a 1.2s sleep in `nextui-session` after a pak.
minui-list B/menu is exit 2/3, not a crash. Tools paks that would
otherwise restore into a `.pak` folder write `/storage` to
`/tmp/last.txt` (same as Settings).

---

## 8. OS update (OTA)

Contract:

1. Copy a tar to `/storage/.update/zlyme-my355-*.tar` (newest mtime wins)
2. Reboot

`post-image.sh` writes `zlyme-my355-YYYYMMDD-<gitdescribe>.tar` (Image,
dtb, overlays, squashfs file `zlyme`, splash/progress anims,
`extlinux.conf`, `VERSION`). The GitHub pak still queues the well-known
`zlyme-my355-update.tar` name.

`S18zlymeupdate` is **waited** (rcS does not fork it). Galaxy lockup
first (`zlyme-splash-progress on persist`). `zlyme-update boot-apply`
extracts the tar on **ZLYME** to `/storage/.update/pending/` (including
`pending/zlyme`), copies Image/dtb/overlays/anims/extlinux to `/boot`,
then reboots. It does **not** put a second squashfs on FAT. Initramfs
mounts `LABEL=ZLYME`, copies `pending/zlyme` over `/boot/zlyme`
(in-place), deletes pending, loop-mounts the live file. Config stays
on exFAT. Refuse if the new squashfs is larger than `/boot` free space
plus the live `zlyme` file.

After the new squashfs is up, **do not** run `zlyme-ctl apply-settings`
from S18. That called mergerfs while S17 held the lock (zlyme38 OTA:
splash stuck on `applying settings after OS swap`, and
`/storage/.update/reapply` stayed so every boot hung). Delete that file
on ZLYME to unstick. Reapply is rc.late, flag dropped first, gov/led/zram
only.

Proven 2026-09-13: drop the well-known name, reboot, `S18` extracts on
`ZLYME`, copies Image/dtb, `reboot -f`, initramfs `zlyme committed`,
u-boot still retrieves `/Image`. zlyme24 then zlyme25 both applied
this way. Storage and Wi-Fi survive (no GPT rewrite).

**Never `dd` a mounted rootfs.** The 2026-09-12 16:09 apply wrote
`PARTLABEL=rootfs` while it was `/`. That layout is gone. Do not bring
`dd` of a partition back.

Do **not** Etcher `zlyme.img` onto a card that already has a grown
games partition. The image rewrites GPT **and** the ZLYME exFAT. Use
the tar (or a fresh card for this layout change).

`build.sh` greps the tree for `dd … of=/dev/mmcblk`. The updater copies
kernel files onto `/boot`; the squashfs payload stays on `ZLYME` until
initramfs.

GitHub: going **public** (`Zetarancio/zlyme`). `zlyme-cache` can stay
private. Workflow `.github/workflows/build.yml` is
**`workflow_dispatch` only** — no `on.push`, no `0 4 * * *` cron.
A private cold build is ~930 runner-minutes (3×310) on 2 CPU / 8 GB;
public `ubuntu-24.04` is free and 4 CPU / 16 GB. Do not dispatch
until the repo is public. `cancel-in-progress` stays false so a
second click does not kill ccache; it still queues, so do not click
twice. Artifact upload `retention-days: 1` (handoff to the Release
job only). Secret `GH_PAT` still writes the cache repo. A successful
run publishes Release tag `zlyme-<run_id>` (latest) so Update.pak
can hit `/releases/latest`. `/usr/share/zlyme/github-repo` is
`Zetarancio/zlyme`. While private, the API 404s without a PAT in
`/storage/.config/github-token`; public `/releases/latest` does not
need that.

### How neighbours update (do not rewrite GPT)

**ROCKNIX.** Root is a squashfs **file** named `SYSTEM` on FAT `/flash`,
loop-mounted by **initramfs**. User copies `ROCKNIX-….tar` to
`/storage/.update` and reboots. Initramfs remounts `/flash` rw and
replaces KERNEL + SYSTEM *files*. GPT is untouched.

**Knulli / Batocera.** Same class. Extract `boot.tar.xz` onto FAT, often
as `knulli.update`. Next boot, initramfs `mv`s `.update` over the live
squashfs file, then loop-mounts it.

**Industry (RAUC / Mender).** A/B rootfs partitions + bootloader slot.
Handheld CFWs above do not do this. Not in scope.

**Zlyme.** Live OS is one `zlyme` file on a fixed **1300M** `ZLYMEBOOT`.
The pending squashfs is `/storage/.update/pending/zlyme` on `ZLYME`
(ROCKNIX-style: payload on storage, commit in initramfs). Initramfs is
embedded in `Image`. U-boot still only cares about GPT name `uboot` at
8M. The eMMC DTS `label = "rootfs"` is NAND, commented out, leave it.

---

## 9. DT overlays

Compiled with host `dtc -@` into `/boot/overlays/`. Composed into one
`FDTOVERLAYS` line (`zlyme-ctl apply-overlays`). Replacing that line
with only undervolt used to wipe HDMI/OTG/SD2.

| Overlay | Effect | Default |
| --- | --- | --- |
| `rk3566-undervolt-cpu-l{1,2,3}.dtbo` | `/opp-table-0` | off |
| `rk3566-disable-otg.dtbo` | lower C gadget (`usb@fd000000` + phy0 otg-port). Upper C host + 8733bu stay | OTG **on** |
| `rk3566-disable-hdmi.dtbo` | HDMI + hdmi-sound | HDMI **on** |
| `rk3566-disable-sd2.dtbo` | `/mmc@fe2c0000` (sdmmc1). Boot slot untouched | SD2 **on** |

Panel refresh 60/50/40 Hz via sysfs `640x480@Hz` after mode names in
`panel-generic-dsi`. Power profiles (not Settings pickers): Smart
schedutil 408–1800 on cores 01 + DMC 324M; Performance 1800 on 0123 +
DMC 1056M; idle conservative 408–1104 when the backlight is off.
Optional CPU boost 1992 is off unless Settings enables it.

---

## 10. Build and flash rules

- Pin: Buildroot **2026.02.3**, container Debian Trixie by tag **and
  digest**. No QEMU. Host gcc prefix is still `/flip/output/host`;
  `build.sh` bind-mounts the same tree at `/flip/output`. Do not
  byte-replace `/flip/` → `/zlyme/` in the output (it shifts ELF).
- Flags: `-mcpu=cortex-a55+crc+crypto+fp+simd+rcpc`, `-O2` globally.
- Do **not** start a second `./build.sh` on the same `output/`.
- `make <foo>_defconfig` is not reread if `.config` already exists.
  `build.sh` reconfigures when the tracked defconfig is newer. The tell
  of a skipped reconfigure is a seconds-long "build".
- Patches next to the `.mk`. Buildroot does not apply
  `package/foo/patches/`. `patch -F0` (no fuzz). Refresh hunks only.
  Harvest Knulli recipes first; replace Batocera `/userdata` with
  `/mnt/SDCARD/.userdata/shared`.
- Out-of-tree `.ko` (joypad, 8733bu, mali_kbase) must match kernel
  `this_module` size. Turning `CONFIG_DEBUG_SPINLOCK` off changed it.
  `post-build.sh` compares to panfrost. After `linux-reconfigure`,
  dirclean those driver packages. A card-local `joypad.ko` under
  `/storage` is a live workaround, not the image.
- Keep `CONFIG_DEBUG_KERNEL`. Conservative is on for idle. zram default
  algo is lz4; userspace enables **384 MiB** swap (Settings can turn it
  off). IRQ affinity pins RTL8733BU EHCI `fd880000.usb` (`ehci_hcd:usbN`,
  number moves each boot) and MMC (`dw-mci`) to CPU0. Do not pin
  `fcc00000` / `fd000000` / `fd800000`, HDMI, or GPU.
- `cfg80211` is a **module** so it can load `regulatory.db` after
  squashfs is mounted.
- `/var` is already writable via Buildroot symlinks. Do **not** mount
  a tmpfs on `/var`. Persist what must survive in `/storage`. Samba's
  `private/msg.sock` needs unix 0700, so `/var/lib/samba` → `/tmp/samba-lib`.
- Busybox `mount` cannot resolve `PARTLABEL=`; scripts use `blkid`.
- Kernel: `PREEMPT`, `HZ=250`, CMA **128MB** (`linux.config`), default
  cpufreq performance then Settings/gov. `# CONFIG_DEBUG_SPINLOCK is
  not set` is a gaming deviation from ROCKNIX's copied aarch64.conf.
  Put it back only for a lockup hunt, then rebuild OOT modules.
- DDR blob `rk3566_ddr_1056MHz_v1.23.bin` + `rk3568_bl31_v1.44.elf`.
  A card boot still uses Miyoo's NAND preloader for DDR init.

---

## 11. Hardware measurements (2026-09-10)

**RAM: 1 GiB.** DDR blob `Size=1024MB`, u-boot `DRAM: 1 GiB (total
1022 MiB)`, Linux ~976 MB after CMA. Stage 1 idled at 50 MB.

DSI panel: `panel-generic-dsi` `lanes 2, format 0, mode a03`,
rockchip-drm binds vop/dsi/hdmi, `fb0` ~2.9 s.

---

## 12. ROM folders

NextUI scans every root in `/run/zlyme/libraries` (`/storage`, `/mnt/sd2`,
USB under `/mnt/media/<label>`) for `Roms/<Pretty Name (TAG)>`. Games
lists one folder per tag; opening it concatenates matching dirs. Duplicate
basename: both rows, SD2/USB badged. Saves and Bios live on that volume.
No mergerfs and no `/storage/.roms_base`.

Box art is NextUI `{romdir}/.media/{rom stem}.png`. Do not teach NextUI
to read ES `images/` or Spruce `Imgs/`; put files in `.media`.

Multi-disc: `Game.m3u` next to `Game/` with relative CHD/CUE paths.
Launch the `.m3u`. Saturn/Amiga have no m3u on this image.

PortMaster games live in `Roms/Ports (PORTS)/`. `/roms/ports` is a
real directory on squashfs (not a symlink). PORTS.pak bind-mounts
the active library's Ports folder onto it. Do not symlink it to
OS `Roms/Ports (PORTS)` — that overlay listed every `.sh` twice.
`BR2_PACKAGE_BASH=y`. harbourmaster
ignores `CFW_NAME`/`DEVICE_NAME`. It wants quoted `NAME="…"`,
`VERSION="…"` / `OS_VERSION="…"`, and `HW_DEVICE="…"` in
`/etc/os-release` (Buildroot’s unquoted `VERSION=2026.02.3` showed
**0.0.0**). DTB model is `Miyoo Flip`, which was not in its table.
Image: `NAME="Zlyme"` `VERSION="zlyme39 (YYYY-MM-DD)"` (same short
string as Settings → version, from `version.txt` after `-zlyme` plus
`build-date.txt`) `HW_DEVICE="miyoo-flip"`. `platform.py` maps `zlyme`
to PlatformROCKNIX so first_run still uses that path. Launch HOME is
`portmaster-home` (exFAT cannot tell `PortMaster` from `portmaster`);
seed `control.txt` / `mapper.txt` under `/storage/.config/PortMaster`.
`PRETTY_NAME` stays Buildroot so About → OS is unchanged.

RetroArch is Spruce Flip: `input_driver=sdl2`, `input_joypad_driver=sdl2`,
MENU = SDL GUIDE (button 5). Enable Hotkey nul. MENU+Start is
`zlyme-pak-hotkey`. Menu driver is RGUI (ozone is not built). Keep
`SDL_GAMECONTROLLERCONFIG` from `/usr/lib/gamecontrollerdb.txt`.
Theme and Flip autoconfig live in the RetroArch package under
`/usr/share/retroarch/`.
Knulli core file is `mupen64plus-next_libretro.so`; N64.pak
`EMU_EXE` must match. PCE/VB/MAME on this image are Knulli names
`pce_fast` / `vb` / `mame078plus` with reverse symlinks for the
old NextUI `EMU_EXE` strings. Do not `tr _ -` the whole basename
(that turns `_libretro` into `-libretro`).

Pico-8 (PICO) is listed only when `pico8_64` and `pico8.dat` are
in the same directory. Search is the same as `start_pico8.sh`
(`Bios/PICO`, `Roms/Pico-8 (PICO)/`, …). Splore alone is not
enough. P8 (fake-08) is a different pak.

Initramfs paints the still on `/dev/fb0` from the ramdisk
(`splash.rgb565` / `progress.rgb565`). The loops are ZLYA files
`splash.anim` (slime, 135f @ 33 ms) and `progress.anim` (galaxy, 90f)
on FAT and `/usr/share/zlyme`, rasterized 1:1 from
`zlyme_slime_loop.gif` / `zlyme_galaxy_loop.gif`. Do not put the
anims in the ramdisk. An incremental nextui rebuild does **not**
update the stills; dirclean initramfs and `linux-rebuild` for those,
and copy the `.anim` files onto FAT (genimage / OTA / S12 seed).
`S12splash` restarts splash from squashfs after `switch_root`.
NextUI skips folder art until first-flip so it does not cover fb0.

NextUI/Settings use KMSDRM
(a plane above fbdev). While they hold DRM master, `/dev/fb0` can read
as all zeros even though the panel shows the UI. Dropping master
(close Settings/pak) can flash the leftover splash on the first return
after reboot. `PLAT_initVideo` now fills fb0 with `#050608` after KMS
is up (`1bcd537`).

Volume: `zlyme-keylidmon` is the msettings shm host (`S26keylidmon`,
before NextUI). NextUI signals it via pidfile and `killall` (the
name is 16 chars; `comm` may show `zlyme-keylidmo`). It owns
PLUS/MINUS and MENU+vol brightness while a pak runs
(`EVIOCGRAB` on `gpio-keys-volume`). Lid close is hybrid screen+radios
off; power button is `PWR_sleepNow` / `echo mem`. User proved both.

Wi-Fi OSK: `KeyboardPrompt` is `MenuItemType::Custom` with an empty
`items` list. `MenuList::draw` must still call `drawCustom`. Custom
SSID/BT rows must return from `drawFixedItem` without blitting the
name again. `performLayout` keeps start/selected; draw always layouts
against the real list rect. One pill reserved for the description
(five rows on my355). WiFi/BT `updater` skips rebuild when the scan
set is unchanged and does not rebuild while a submenu is open.

Status LED **Battery** is the auto mode (green on battery, red charging,
flash red when low). Green/Red/Off lock the colour. Keep Battery as
the default — the DT has no battery-led trigger.

---

## 13. Still open (product, not archaeology)

- GitHub: make `Zetarancio/zlyme` public, then **Run workflow** (Build
  is dispatch-only; no daily cron, no push). Artifact retention 1 day.
  Device PAT is only needed while private.
- User still needs to walk: Smash from the list, Switch Pro in a
  game after Connected, A2DP vs HDMI by ear. Next OTA must wait for
  S18 (live 2026-09-17 still forks).
- Extra compiled cores with no NextUI pak (PLAN §11).
- EasyRPG zip/dir still exit 1 over SSH.
- Live U-Boot delay still 2 until `u-boot.itb` is rewritten (OTA
  does not ship u-boot).

Resolved this pass (do not re-open):

- Class A whitelist, dbus in `rc.late` with squashfs `/etc/machine-id`
  so uuidgen does not wait for crng. Live meter: dbus 3.53–12.54,
  `nextui.elf` 26.4 s. Libraries are `/run/zlyme/libraries`, not
  mergerfs.
- N64 core name is Knulli `mupen64plus-next` (underscore pak missed
  the .so). gzdoom needs `-iwad` for `*.wad`.
- RA pad path is sdl2 + GameController (Spruce Flip). `HID_NINTENDO`
  + IMU/Accel/Gyro udev drop. Skip `bluetoothctl connect` when
  `Connected: yes` (8733bu status 0x04).
- Samba tmpfs `/var/lib/samba`. Syncthing start/stop on zlyme25.
- OTA drop-tar-and-reboot on an already-grown card (zlyme24 / zlyme25).
- First-boot resize without `partprobe` on the live vfat (`reboot -f`,
  comment `autoresize` on the next boot). Landed on `main` as `239d475`.
- OpenSSH + SFTP. Live device: `root@192.168.0.108` (empty password).
- `cfg80211=m`, 8733bu `rtw_power_mgnt=0 rtw_lps_level=0`.
- Overlays.pak `curl` CLI. PortMaster pugwash + Gravity Defied.
- PPSSPP `.chd` booted. S13/S36 live. IRQ pin `dw-mci` +
  `ehci_hcd:usbN` (fd880000) to CPU0.

---

## 14. Audio, Bluetooth store, USB host, boot (2026-09-15)

**Audio matrix (pure ALSA).** Jack is only a mux on `rk817ext`
(`zlyme-jackd`). HDMI and A2DP are `ZLYME_SINK`. Volume is `FlipVolume`.
`zlyme-btsink` polls ~1s: A2DP PCM (`bluealsa-cli` `a2dpsrc`) wins,
else HDMI **connected** and ELD `sad_count>0` → `hdmi`, else `codec`.
Kernel ELD is `sad_count<TAB>N`, not `sad_count=`. Stock squashfs
looked for `=` and stayed on `codec`; live bind of the tab parser set
`ZLYME_SINK=hdmi` on the AOC 24G1WG4 (`sad_count 1` LPCM). HDMI card
always exists on the SoC — “card present” is not the test.
`GetHDMI()` must poll sysfs. NextUI stays 640×480. KMS flash on pak
switch is unfixed. S46 runs even when Bluetooth is off.

**Bluetooth on exFAT.** BlueZ store is `/var/lib/bluetooth/<AA:BB:…>/`.
Colons are illegal on exFAT. `/run/bluetooth` is a real tmpfs dir;
`/var/lib/bluetooth` → `/run/bluetooth`. Persist with
`tar -C /run -cf /storage/.config/bluetooth.tar bluetooth` (Knulli
`knulli-bluetooth` `do_save`/`do_restore`). Do not symlink the store
onto the card. Do not add BusyBox `timeout`; `dbus-send` sets
Powered/Pairable (retry until Pairable). Agent must keep stdin open:
`start-stop-daemon` EOF killed `bluetoothctl --agent`; hold with
`tail -f /dev/null | bluetoothctl --agent=NoInputNoOutput`.
`hidp` before bluetoothd. HID pads must not `zlyme-audio set bt`.
Built-in pad stays `js0`. Live Switch Pro `98:B6:D4:58:CD:79`.
`HID_NINTENDO=m`; IMU/Accel/Gyro are not joysticks. `hid-generic` on
the Pro is zero evdev bytes. `bluetoothctl connect` on an already-live
HID drops the 8733bu link (status 0x04) — skip `Connected: yes`.
RA uses sdl2 + GameController (Spruce); leftover `bluetoothctl scan`
also drops HID. In-game after Connected is still a user test.

**Volume while a pak runs.** `zlyme-keylidmon` (`S26keylidmon`) is the
msettings shm host. NextUI STOP/CONT/TERM via pidfile and `killall`.
Do not run stock Miyoo keymon. `keymon.elf` and `zlyme-volmon` are
discarded names.

**USB-C.** Top = host EHCI `fd800000` + OHCI `fd840000`. Bottom =
charge+gadget `fcc00000` (no VBUS). Overlay **USB host (top port)**
off disables the upper EHCI+OHCI, not unused `fd000000`.

**Userdata.** `/storage/.config/nextui/shared` and `…/my355`. No S15
migrate. Backup is `tar -C /storage .config` only.

**USB / MergerFS.** `/mnt/media` is squashfs-ro; `ensure_media` must
tmpfs it before mounting a stick. Top EHCI took a Verbatim STORE N GO
exFAT `ZLYMEROM`. Merge cat was `a.iso` internal / `b.iso` SD2
lowercase `roms/` / `c.iso` USB. Duplicate names keep the OS-card file.

**Clock / WAN.** BusyBox wget has no HTTPS. `/usr/bin/wget` is a curl
wrapper. Pico-8 Splore is `wget "URL" -q -O "file"` (URL **first**);
lexaloffle 404s curl’s user-agent — speak `Wget/1.21.4`. Do not pass
`--fail` (Pico-8 looks at the file). Do not bind-mount that wrapper
over the BusyBox wget symlink (it overlays `/bin/busybox`). `S49ntp`
sets the clock from HTTP Date after Wi-Fi (live on zlyme32). First
boot clock was Sat Aug 5 2017 → TLS “not yet valid”.
This AP (TP-Link_E44F / Saponetta) often isolates clients: host ping to
`192.168.0.108` fails while serial works. First IPv4 ARP to the gateway
can sit FAILED; TCP/DNS still work once neigh completes. PSK file on the
build host is `~/Desktop/Saponetta4g.txt`.

**Boot (2026-09-16, live zlyme32).** Keep BusyBox init. Do not systemd.
`NOTES/DEVLOGS/boot-zlyme32-timing-20260916.txt`. `/proc/uptime` 277 s
when pulled. `nextui.elf` startticks/100 = **26.4 s** to the process.

| mark | s |
| --- | --- |
| kernel userspace (`Freeing unused`) | 1.36 |
| `mmc0` tuning -5, then SDR104 at 1.58 | 1.23–1.58 |
| `LABEL=ZLYMEBOOT: Can't lookup blockdev` | 1.59 |
| `rcS-start` | 3.52 |
| `S30dbus-daemon` start → done | 3.53–**12.54** |
| `random: crng init done` | **12.45** |
| `S28minui` done / `nextui-session` | 15.40 |
| `rcS-nextui-ready` | 15.72 |
| `nextui.elf` | **26.40** |

dbus-uuidgen blocked on crng (~9 s). Session `zlyme-storage merge`
(SD2 ext4 + mergerfs, five `merge` lines) sat ~11 s before
`nextui.elf`. Tree now: Class A whitelist, dbus+uuid from
`/etc/machine-id` in `rc.late`, session bind `.roms_base` only, S17
merges extras, initramfs spins on `mmcblk*p*` instead of `sleep 1`.
OTA that squashfs. Extra first-frame work (zlyme35, local rebuild
2026-09-16): skip `GFX_init` timezone/hwclock, skip `gametimectl stop_all`
on enter, `hasRoms` name-match before stat, one bind for emu paks,
no Class A `seedrng`, ALSA aplay in background. Marks:
`nextui-enter/gfx/menu/first-flip`. U-Boot `Hit any key … 2` still
needs an ITB flash.
