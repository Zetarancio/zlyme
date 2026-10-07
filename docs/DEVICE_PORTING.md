# Device porting contract

## Status

This document defines how a future Zlyme device should be added.

It does **not** mean Zlyme currently supports more than the Miyoo Flip.

Supported:

```text
my355 — Miyoo Flip — supported
```

Everything else is hypothetical until implemented and tested on real hardware.

## Principle

A new device should be added by supplying a device implementation to existing Zlyme interfaces.

Do not add:

```c
if (device == MY355) ...
else if (device == SOMETHING) ...
```

throughout generic code.

Prefer:

```text
generic Zlyme code
        |
        v
stable interface
        |
   +----+----+
   |         |
my355     future-device
```

## Required build-time pieces

A future device normally needs:

```text
configs/zlyme_<device>_defconfig
configs/zlyme_<device>_minimal_defconfig

board/<device>/
├── board.mk
├── fsoverlay/
│   └── usr/share/zlyme/device.conf
├── linux/
├── uboot/
├── genimage.cfg
├── post-build.sh
├── post-image.sh
└── make-update-tar.sh
```

`board/my355` also has `extlinux.conf`, `zlyme-boot.conf`, `image-date.sh`, `assert-input-rootfs.sh`, `pre-update.sh`, `post-update.sh`, and the `sdl3-stub` sources. `build.sh` sources `board/my355/image-date.sh` by that literal path.

Not all devices must use the same bootloader/image layout.

## Defconfig naming

Use device-qualified names from the start:

```text
zlyme_my355_defconfig
zlyme_my355_minimal_defconfig
```

Future examples:

```text
zlyme_<device>_defconfig
zlyme_<device>_minimal_defconfig
```

Avoid restoring unqualified `zlyme_defconfig` once multiple targets exist.

## Buildroot device selection

The external `Config.in` has a Zlyme target choice with one entry, `BR2_ZLYME_DEVICE_MY355`.

This is a dispatch seam, not a promise of another target.

A defconfig explicitly selects the device.

## Board make integration

Miyoo Flip-only kernel and U-Boot hooks are in `board/my355/board.mk`. `external.mk` includes every package `.mk`, then includes `board/my355/board.mk` only when `BR2_ZLYME_DEVICE_MY355=y`. Only genuinely global package and toolchain workarounds follow.

When another device exists, add another dispatch clause.

Do not build a plugin loader in Make.

## Runtime metadata contract

Every board should install:

```text
/usr/share/zlyme/device.conf
```

The file is shell-readable and immutable in the squashfs.

For my355 (`board/my355/fsoverlay/usr/share/zlyme/device.conf`):

```sh
ZLYME_DEVICE_ID=my355
ZLYME_DEVICE_NAME='Miyoo Flip'
ZLYME_SOC=rk3566
ZLYME_DTB=rk3566-miyoo-flip.dtb
ZLYME_NEXTUI_PLATFORM=my355
ZLYME_PORTMASTER_HW_DEVICE=miyoo-flip
ZLYME_UPDATE_PREFIX=zlyme-my355
ZLYME_OS_DISK=/dev/mmcblk0
ZLYME_BOOT_DEVICE=/dev/mmcblk0p2
ZLYME_STORAGE_DEVICE=/dev/mmcblk0p3
ZLYME_BOOT_LABEL=ZLYMEBOOT
ZLYME_STORAGE_LABEL=ZLYME
```

`ZLYME_OS_DISK`, `ZLYME_BOOT_DEVICE`, and `ZLYME_STORAGE_DEVICE` are the current my355 OS card. Another board does not have to use MMC or these names. `docs/ARCHITECTURE.md` records why these nodes are stable on this board. On this board Linux `mmcblk0` and U-Boot `mmc 1` are the same `sdmmc0` controller, because pinned `rk356x-u-boot.dtsi` reserves `mmc 0` for `sdhci`.

Do not place secrets or mutable user settings here.

## Runtime command contract

Where useful, device implementations provide stable commands.

### `zlyme-audio`

Owns:
- sink discovery and selection: `codec`, `hdmi`, `bt`, and `auto` (= `codec`);
- the shared volume `FlipVolume`;
- the saved sink in `/storage/.config/audio.conf`.

Verbs: `list`, `get`, `set {auto|codec|hdmi|bt}`, `status`, `getSystemVolume`, `setSystemVolume {mute|unmute|mute-toggle|[+-]N}`, `test`, `export`.

Speaker versus headphones is not a `zlyme-audio` choice. `zlyme-jackd` follows the jack switch and owns `Playback Mux`.

Generic code must not know `rk817ext`, `Playback Mux`, or `FlipVolume`.

### `zlyme-governor`

Owns:
- CPU policy;
- GPU devfreq policy;
- DMC/memory policy where present;
- optional CPU hotplug/affinity policy.

An emulator launcher passes its system tag:

```text
zlyme-governor emu <tag>
```

`emu <tag>` applies the SpruceOS per-system CPU floor, resolved to the lowest my355 OPP at or above it, on top of the `play` profile. A tag with no Spruce floor keeps `heavy` (PS2, GC, Wii) or `play`. Other callers request a semantic profile:

```text
smart        the NextUI list (NextUI CPU_SPEED_AUTO)
play         Tools PAKs such as PortMaster, Files, and Moonlight
heavy        heavy consoles, 1104 MHz floor
idle         screen-off sleep (NextUI CPU_SPEED_POWERSAVE)
performance  heavy, or overclock when the boost flag is on
overclock    allows the 1992 MHz OPP; serial debug only
auto         alias of smart
powersave    alias of idle
```

`ZLYME_GOVERNOR` in the environment replaces the whole mode, including `emu`. `--policy <tag>` and `--resolve-floor <kHz>` print the decision without writing sysfs.

Callers must not know RK3566 sysfs paths.

The implementation is `package/system/nextui/zlyme/governor.sh`, installed by the nextui package as `/usr/sbin/zlyme-governor`. It is RK3566/my355-specific (OPP list, core hotplug, DMC rates) even though it does not live under `board/my355`. `gpudriver` (`package/system/gpudriver`) is in the same position. A second device must move or parameterize both.

### `zlyme-led`

Owns board LED behavior. Verbs: `apply`, `battery`, `green`, `red`, `amber`, `off`, `charging`, `discharging`, `poweroff`, `flash`, `watch`, `list`. `ledcontrol` is a symlink to it.

### `zlyme-halt`

Owns safe shutdown/reboot details specific to the device/storage layout. `zlyme-halt [poweroff|reboot]` is exec'd by `nextui-session`.

### `zlyme-update`

`zlyme-update` is board code (`board/my355/fsoverlay/usr/sbin/zlyme-update`). It takes the filename prefix and the DTB name from `device.conf`. On my355, the raw bootloader path also uses `ZLYME_OS_DISK` and `ZLYME_BOOT_DEVICE` from that file. Update identity is described under "Update compatibility" below.

## Frontend platform contract

The selected device defines the NextUI platform name. my355 maps to `workspace/my355`.

The hidden string `BR2_PACKAGE_NEXTUI_PLATFORM` in `Config.in` defaults to `my355` from the device choice. `nextui.mk` builds `workspace/$(BR2_PACKAGE_NEXTUI_PLATFORM)` and stops when the string is empty. `post-build.sh` checks it against `ZLYME_NEXTUI_PLATFORM` in `device.conf`.

Do not hardcode:

```make
NEXTUI_PLATFORM = my355
```

as a universal package constant.

A future device can then add its own NextUI platform directory without forking the package recipe.

Runtime code does not read the platform from `device.conf`. `nextui-session` sets `PLATFORM=my355` and `DEVICE=my355` and uses `/storage/Emus/my355` and `/storage/Tools/my355`. `rc.late` copies the NextUI log to `/storage/.config/nextui/my355/logs`. A second device must derive those from `device.conf`.

## Board overlay vs common overlay

Do not split everything into `board/common` merely for aesthetics.

Create common files only when they are truly board-independent.

A practical rule:

Keep in `board/my355/fsoverlay`:
- ALSA card/mixer policy;
- GPIO/regulator policy;
- device-specific module ordering;
- display connector details;
- device-specific governor/sysfs logic;
- joypad/lid/LED behavior;
- board-specific boot/update hooks.

Known exceptions: `zlyme-governor` ships from the nextui package and `gpudriver` from its own package, both under `package/system`. See `zlyme-governor` above.

Candidates for a future common overlay:
- generic logging helpers;
- generic persistent-state conventions;
- generic update framework after device metadata has replaced hardcoded DTB/prefix;
- generic storage-library helpers if they do not depend on the physical layout;
- generic SSH/Samba/Syncthing policy.

Do not move a file to common until its hardware assumptions have been removed and its interface is stable.

## Package selection

A future device defconfig chooses which existing packages apply.

Do not make every package conditional on every device.

For inherently Miyoo-specific packages, use an explicit dependency such as:

```text
depends on BR2_ZLYME_DEVICE_MY355
```

Packages gated on `BR2_ZLYME_DEVICE_MY355`: `zlyme-jackd`, `zlyme-keylidmon`, `zlyme-input`, `miyoo-flip-gamepad`, `rtl8733bu-power`, and `rk3568-dmc`.

Not gated: `gpudriver` and `libmali` depend only on `mali-kbase`, which depends only on the kernel. `rtl8733bu` and `rtl8723fu-firmware` are not gated either. Those are open audit items, not a decision that they are board-independent.

Generic emulator packages should normally remain independent of the device symbol.

## Update compatibility

Update artifacts must include a device identity.

The updater should verify at least:

- expected device/update prefix;
- expected DTB or equivalent boot artifact;
- root payload;
- version metadata.

Never accept another device's update because filenames partially overlap.

A full OTA is a tar that contains the squashfs member `zlyme`, the device DTB, `Image.gz`, and `VERSION`. A delta OTA carries the same boot members plus `DELTA-MANIFEST` and `zlyme.patch.zst`, and it does not also contain `zlyme`. The manifest names the device, the base squashfs hash, and the target hash and size.

What each piece checks today:

- `zlyme-update` picks only `${ZLYME_UPDATE_PREFIX}-*.tar` from `/storage/.update`. A full tar must contain the members `${ZLYME_DTB}`, `zlyme`, and `Image.gz`. A full tar has no device field. Its identity is the filename prefix plus the DTB member.
- On my355, `zlyme-update uboot` also requires the mounted boot volume to be `ZLYME_BOOT_DEVICE` on `ZLYME_OS_DISK`. Those paths are this board's OS-card identity. They are not a requirement that another device use MMC or these names.
- For a delta, `zlyme-update` requires `DEVICE=my355`. That value is a literal in the script, not `ZLYME_DEVICE_ID`.
- Settings (`github-release.py`) accepts a `release-manifest.json` only when its `device` equals `ZLYME_DEVICE_ID` from `device.conf`.
- The release scripts `scripts/zlyme_release.py` and `scripts/make-release-deltas.py` write and check the literal `my355`, and name deltas `zlyme-my355-delta-*`.
- Initramfs deletes leftover `zlyme-my355-*` tars by that literal name.

The prefix and DTB already come from device metadata. The delta `DEVICE` literal, the release-script literals, and the initramfs cleanup names are the seam a second device must parameterize from `ZLYME_DEVICE_ID` and `ZLYME_UPDATE_PREFIX`. That device must also reject a my355 full tar and a my355 delta tar. Do not add that second device until it exists.

Staging and the reboot commit are in `docs/ARCHITECTURE.md`. The operator steps are in `docs/OPERATIONS.md`.

## CI

With one device, keep CI simple.

When a second device is actually added, convert build jobs to a matrix keyed by defconfig/device.

Do not add CI matrix entries for a device that does not exist.

## Porting checklist

A new device is not "supported" until all relevant items have been tested on real hardware:

- bootloader;
- kernel/DTB;
- display first frame;
- controls;
- audio;
- suspend/resume/power;
- storage;
- updates;
- thermal policy;
- CPU/GPU governor;
- frontend lifecycle;
- RetroArch;
- representative standalones;
- USB;
- Wi-Fi/Bluetooth if present;
- repeated application exit -> frontend recovery.

Compilation alone is not device support.


## Reusable SoC/device-family drivers

Not every non-upstream driver belongs inside `board/my355`.

A driver that is genuinely reusable across RK3566/RK3568 devices may live under:

```text
package/drivers/
```

and be selected by the board defconfig/Kconfig.

Examples/candidates:
- RK3568 DMC devfreq;
- device-family radio/power modules where hardware compatibility is real.

Keep board-specific DTS, OPP/voltage policy, module ordering, and enablement in the board layer.

For a package whose implementation is intentionally SoC-family reusable, the target shape is a board `select` rather than `depends on BR2_ZLYME_DEVICE_MY355`.

`rk3568-dmc` does not follow that shape. Its `Config.in` has `depends on BR2_ZLYME_DEVICE_MY355`, its help text names the Miyoo Flip, and `configs/zlyme_my355_defconfig` enables it directly. Its OPP and SIP contract has been validated only on the Flip. A second RK356x board changes that gate when it exists.
