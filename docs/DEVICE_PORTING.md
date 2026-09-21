# Device porting contract

## Status

This document defines how a future Zlyme device should be added.

It does **not** mean Zlyme currently supports more than the Miyoo Flip.

Current support:

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
├── linux/
├── uboot/
├── genimage.cfg
├── post-build.sh
├── post-image.sh
├── make-update-tar.sh
└── device.conf
```

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

Use a small Zlyme target choice in the external Kconfig.

For now it contains only Miyoo Flip:

```text
choice
    prompt "Zlyme target device"
    default BR2_ZLYME_DEVICE_MY355

config BR2_ZLYME_DEVICE_MY355
    bool "Miyoo Flip (my355)"

endchoice
```

This is a dispatch seam, not a promise of another target.

A defconfig explicitly selects the device.

## Board make integration

Move Miyoo Flip-only kernel/U-Boot hooks out of the global `external.mk` into:

```text
board/my355/board.mk
```

Then global `external.mk` should look conceptually like:

```make
include $(sort $(wildcard $(BR2_EXTERNAL_ZLYME_PATH)/package/*/*/*.mk))

ifeq ($(BR2_ZLYME_DEVICE_MY355),y)
include $(BR2_EXTERNAL_ZLYME_PATH)/board/my355/board.mk
endif

# only genuinely global package/toolchain workarounds below
```

When another device exists, add another dispatch clause.

Do not build a plugin loader in Make.

## Runtime metadata contract

Every board should install:

```text
/usr/share/zlyme/device.conf
```

The file is shell-readable and immutable in the squashfs.

For my355:

```sh
ZLYME_DEVICE_ID=my355
ZLYME_DEVICE_NAME='Miyoo Flip'
ZLYME_SOC=rk3566
ZLYME_DTB=rk3566-miyoo-flip.dtb
ZLYME_NEXTUI_PLATFORM=my355
ZLYME_PORTMASTER_HW_DEVICE=miyoo-flip
ZLYME_UPDATE_PREFIX=zlyme-my355
ZLYME_BOOT_LABEL=ZLYMEBOOT
ZLYME_STORAGE_LABEL=ZLYME
```

Do not place secrets or mutable user settings here.

## Runtime command contract

Where useful, device implementations provide stable commands.

### `zlyme-audio`

Owns:
- sink discovery;
- local codec routing;
- volume;
- optional HDMI/Bluetooth selection semantics.

Generic code must not know `rk817ext`, `Playback Mux`, or `FlipVolume`.

### `zlyme-governor`

Owns:
- CPU policy;
- GPU devfreq policy;
- DMC/memory policy where present;
- optional CPU hotplug/affinity policy.

Generic launchers request semantic profiles such as:

```text
smart
play
heavy
idle
```

They should not know RK3566 sysfs paths.

### `zlyme-led`

Owns board LED behavior.

### `zlyme-halt`

Owns safe shutdown/reboot details specific to the device/storage layout.

### `zlyme-update`

May have common logic, but must consume device metadata for artifact identity and required boot files.

## Frontend platform contract

The selected device defines the NextUI platform name.

Current:

```text
my355 -> workspace/my355
```

Do not hardcode:

```make
NEXTUI_PLATFORM = my355
```

as a universal package constant.

Prefer a hidden Buildroot string derived from the selected device, for example:

```text
BR2_PACKAGE_NEXTUI_PLATFORM="my355"
```

and consume that in `nextui.mk`.

A future device can then add its own NextUI platform directory without forking the package recipe.

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

Examples to audit:
- `zlyme-jackd`;
- `zlyme-keylidmon` if its implementation depends on the my355 platform;
- `gpudriver`;
- RK3566/RTL8733BU/joypad-specific driver packages.

Generic emulator packages should normally remain independent of the device symbol.

## Update compatibility

Update artifacts must include a device identity.

The updater should verify at least:

- expected device/update prefix;
- expected DTB or equivalent boot artifact;
- root payload;
- version metadata.

Never accept another device's update because filenames partially overlap.

A future format may include an explicit manifest, but do not invent one until the current updater needs it.

## CI

With one device, keep CI simple.

When a second device is actually added, convert build jobs to a matrix keyed by defconfig/device.

Do not add empty CI matrix entries now.

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

Do not mark a package as `depends on BR2_ZLYME_DEVICE_MY355` if its implementation is intentionally SoC-family reusable. Instead make the board select it.
