# Miyoo Flip operations

This document contains durable operational facts for the currently supported Zlyme device.

Current supported hardware:

```text
device id: my355
device:    Miyoo Flip
SoC:       Rockchip RK3566
```

This is a maintainer runbook, not the architecture specification.

## Serial console

The Miyoo Flip debug UART uses:

```text
ttyS2
1500000 baud
8N1
3.3 V
```

Do not depend on a particular host USB-UART device path in repository code or canonical documentation.

The reliable host setup established during bring-up uses `stty` to set 1500000 baud before opening the descriptor.

## Boot identity

Current important names:

```text
kernel DTB:     rk3566-miyoo-flip.dtb
boot label:     ZLYMEBOOT
storage label:  ZLYME
root payload:   zlyme (squashfs file on boot FAT)
```

MMC numbering is not a stable identity. Prefer labels/partition names.

## Current image layout

The my355 image uses:
- idbloader beginning at 32 KiB;
- `uboot` GPT partition at 8 MiB;
- FAT32 `ZLYMEBOOT`;
- exFAT `ZLYME`;
- no rootfs GPT partition.

The squashfs root is a file on `ZLYMEBOOT`.

## First-boot resize

The storage partition is seeded small in the image and grown on first boot.

A critical historical finding:

- do not run `partprobe` in the dangerous first-boot resize sequence while the live boot FAT is mounted;
- the proven sequence grows/reformats storage and reboots;
- protect the boot FAT from unnecessary partition-table reprobe activity.

Treat this as filesystem-integrity-sensitive code.

## Persistent state

The root filesystem is read-only.

Persistent configuration lives under:

```text
/storage/.config
```

Important classes include:
- Zlyme flags;
- Wi-Fi configuration;
- RetroArch configuration/options;
- NextUI settings;
- SSH host keys;
- Bluetooth state;
- saves/BIOS/ROM libraries;
- optional logs;
- OTA staging.

Do not introduce mutable state into squashfs paths.

## Boot classes

`rcS` is the frontend-critical path.

`rc.late` starts optional/background work after the frontend first-frame gate.

Do not move Wi-Fi, Bluetooth, SSH, NTP, Samba, Syncthing, broad udev coldplug, or similar work back onto the critical path without measuring the impact and proving a dependency.

The OTA apply step is exceptional: when an update is pending, it must not be forked in a way that allows NextUI to appear and then be abruptly rebooted underneath the user.

## GPU

The Miyoo Flip can use:
- Panfrost/Mesa;
- vendor Mali/libmali.

They cannot bind the GPU simultaneously.

Switching stacks is a reboot-level change.

Current board-specific GPU/devfreq knowledge should remain in the my355 implementation.

Do not generalize this dual-stack model into a requirement for future boards.

## Audio

Local codec ALSA ID:

```text
rk817ext
```

Speaker/headphones share the RK817 codec route.

`zlyme-jackd` follows the headphone jack and changes `Playback Mux`.

Shared software volume currently uses `FlipVolume`.

HDMI and Bluetooth are separate sinks.

Always use stable ALSA card IDs rather than assuming numeric card order.

## Wi-Fi and Bluetooth

The current hardware uses the RTL8733BU combo device.

Wi-Fi and Bluetooth share power/firmware interactions. Module/startup ordering is not arbitrary.

Do not remove the my355-specific module ordering/blacklist behavior as generic cleanup unless the hardware interaction has been revalidated.

Networking must remain non-critical for frontend startup.

## Input and lid

The Miyoo Flip input stack includes board-specific controller handling plus Linux input events for lid/power/volume behavior.

Do not hardcode `/dev/input/eventN`.

Use names/capabilities/stable interfaces.

## DRM ownership

NextUI and direct-KMS applications may own DRM master at different times.

Application launch/exit must leave DRM in a state where the next client can acquire it.

The regression check for an application-scoped display stack is:

```text
frontend -> compatibility app -> frontend -> compatibility app -> frontend
```

After the app exits, NextUI must be able to take DRM again. No temporary Weston, WestonPack, or Xwayland process should remain.

PortMaster may mount WestonPack at `/tmp/weston` for one port. MENU+START can kill that port's process group, so NextUI's session cleans the mount, including binds underneath it, before the frontend resumes. A later boot should not show a WestonPack, `seatd`, or Xwayland process left from that launch.

Wine keeps its prefix in `/storage/.config/nextui/<platform>/wine-prefix.ext4`. The card filesystem is exFAT, so the prefix is an ext4 image and is loop-mounted at `/run/zlyme-wine/prefix` only while Wine runs. Cleanup stops that prefix's wineserver, unmounts, then detaches the loop device that still points at this image. That cleanup belongs to the session, because MENU+START can kill the pak before an in-pak trap runs.

Resource cleanup is part of compatibility.

## Updates

Current OTA artifacts are my355-specific.

The updater stages payload on `/storage`, writes current boot artifacts to the boot volume, and commits the squashfs on reboot through initramfs.

Routine update does not automatically flash U-Boot.

Treat bootloader writes as a separate explicitly requested operation with strict target validation.

## Performance checks

For performance-related changes capture more than average FPS.

Useful measurements:
- first-frame boot time;
- p95/p99 frame time;
- audio underruns;
- temperature/throttling;
- CPU/GPU/DMC frequencies;
- battery/power behavior where practical.

Keep thermal protection enabled.

## Live-device truth

A source build and a device test are different states.

When documentation says something is proven on hardware, preserve the distinction between:
- built;
- booted;
- launched;
- tested;
- stress-tested.

Do not turn a newly integrated compatibility path into a supported feature merely because binaries exist.


## Hardware-wiki invariants

The Miyoo Flip hardware wiki is canonical for the following details.

Do not regress these while pruning kernel patches:

- upper USB-C host needs `usb2phy1_otg`, EHCI, OHCI, `vcc5v0_host`, and the OHCI PHY clock;
- both SD slots share `vqmmc`, so mixed 1.8 V / 3.3 V operation is not a supported assumption;
- RK817 off-state drain requires the current `SYS_CAN_SD` handling;
- VDD_CPU is RK8600 on current retail hardware;
- DMC devfreq uses the out-of-tree RK3568 V2 SIP implementation;
- standard suspend works independently of deep suspend.

Deep suspend should be validated specifically under Zlyme/NextUI rather than inheriting ROCKNIX's EmulationStation policy decision.
