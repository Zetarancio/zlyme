# ADR 0006 — One read-only root file, replaced whole before it is mounted

Status: Accepted

Date: 2026-10-04

## Context

The first OTA layout used a `rootfs` GPT partition. On 2026-09-12 an apply `dd`'d that partition while it was `/` (`docs/archive/NOTES.md`). `234b972` then pivoted to tmpfs before the `dd`. The same evening `4bf848d` removed the partition and moved the root to a squashfs file on FAT, committed by an embedded initramfs.

The archived notes record ROCKNIX, KNULLI, and Batocera using that file-on-FAT pattern. A/B root partitions with a bootloader slot were recorded as out of scope.

`board/my355/genimage.cfg` gives ZLYMEBOOT a fixed 1300M for one live `zlyme` plus kernel files, not two root copies. The pending root stays on ZLYME.

In Phase 8 a loop attached without `ro` kept the vfat writable, and a shutdown-time remount of `/boot` returned EBUSY. That remount was rejected. `37d4167` mounts ZLYMEBOOT read-only and attaches the loop with `loop,ro`.

In Phase 9 `d12503e` added delta reconstruction, and `a951706` raised the zstd `--memory` window for root-sized patches. That window turned off zstd's automatic mmap. On the `7796b98` image a root-sized decode copied the squashfs into RAM and was OOM-killed on the 1 GiB Flip. `337ccbc` added `--mmap-dict`.

## Decision

The root is a read-only squashfs file named `zlyme` on the FAT `ZLYMEBOOT` volume. The initramfs mounts that volume read-only and loop-mounts `/boot/zlyme` with `loop,ro`. Persistent state is `/storage`.

An update first stages a complete root at `/storage/.update/pending/zlyme`. A full OTA extracts it from the tar after the member checks. A delta checks the installed root's SHA-256 against the manifest base, reconstructs under `/storage/.update/reconstruct` with `zstd -d --memory=2048MB --mmap-dict --patch-from` against `/boot/zlyme`, and keeps the result only when its SHA-256 and size match the manifest.

On the next boot, before the loop exists, the initramfs copies `pending/zlyme` over `/boot/zlyme` in one read-write window and closes the volume read-only again. Runtime code does not patch, `dd`, or rewrite `/boot/zlyme`. Runtime writes to other ZLYMEBOOT files go through `zlyme-boot-write`.

There are no A/B root slots. Routine OTA does not write U-Boot. `zlyme-update uboot` is the explicit path (`ebad158`).

Artifacts are device-qualified. The update prefix and DTB name come from `/usr/share/zlyme/device.conf` (`837fff5`), and a delta manifest names its device. The installed root's SHA-256, not the version string, selects a delta.

## Consequences

There is no fallback root. That is the size trade. The initramfs removes `pending/` only after the copy and `sync` succeed, so an interrupted copy is attempted again on the next boot. That retry follows from the code. It has not been tested on hardware.

The updater refuses a root that does not fit in ZLYMEBOOT free space plus the live file.

Do not "simplify" this design:

- do not make the root or ZLYMEBOOT writable at runtime;
- do not patch `/boot/zlyme` in place or decode a delta onto it;
- do not drop `--mmap-dict` from the decoder;
- do not decode to `/tmp`, which is tmpfs in RAM;
- do not accept an artifact that is not qualified for this device.

A future board may use another layout. It still stages a complete verified root before commit and uses device-qualified artifacts.
