# Zlyme architecture

## 1. Scope

Zlyme is a Buildroot-based gaming appliance operating system.

The **only supported device is currently the Miyoo Flip**, identified inside the project as `my355`, using Rockchip RK3566 / Cortex-A55 hardware.

The repository is intentionally structured so future hardware can be added, but current code must not pretend that other devices are already supported.

The portability rule is:

> isolate Miyoo Flip implementation details; do not invent generic hardware implementations.

## 2. Major layers

```text
Buildroot
  +
Zlyme BR2_EXTERNAL
  |
  +-- configs/                  product configuration
  +-- package/                  reusable software packages
  +-- board/my355/              current hardware implementation
  +-- scripts/                  host/developer tools
  |
  v
BootROM / Rockchip loader
  v
U-Boot
  v
Linux
  v
embedded initramfs
  v
read-only Zlyme squashfs
  v
BusyBox init
  v
NextUI
  v
PAK / RetroArch / standalone / PortMaster application
```

## 3. Buildroot boundary

Zlyme is a `BR2_EXTERNAL` tree.

Upstream Buildroot is not modified. Zlyme adds packages through `Config.in` and `external.mk`, target configurations through `configs/`, and board integration through `board/`.

The global `external.mk` should remain small. It should discover packages, contain truly cross-project Buildroot workarounds, and dispatch to the selected board integration.

Miyoo Flip-only Linux and U-Boot hooks should live with `board/my355`, not accumulate in the global file.

## 4. Device boundary

### Current device

```text
device id:       my355
product:         Miyoo Flip
SoC:             Rockchip RK3566
CPU:             4x Cortex-A55
kernel DTB:      rk3566-miyoo-flip.dtb
NextUI platform: my355
```

### Build-time device contract

A supported device should eventually provide:

```text
board/<device>/
├── board.mk                 board-specific Buildroot hooks
├── fsoverlay/               hardware/runtime policy for the device
├── linux/                   kernel config, DTS, sources, patches, overlays
├── uboot/                   U-Boot DTS/patches/config integration
├── genimage.cfg             boot/storage image layout
├── post-build.sh            board-specific target validation/finalization
├── post-image.sh            board image assembly
├── make-update-tar.sh       device update artifact
└── device.conf              stable device metadata installed on target
```

Not every future board must have every file, but the board owns these responsibilities.

The current `my355` tree already owns most of them.

### Runtime device metadata

A board should install a simple shell-readable file such as:

```text
/usr/share/zlyme/device.conf
```

For `my355`, it should describe stable identity rather than dynamic state:

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

Only put values here that generic code genuinely needs.

Do not turn every hardware property into configuration data. If two devices need fundamentally different behavior, give each board its own implementation behind the same command interface.

### Runtime device command contract

Generic Zlyme/front-end code may call stable commands when the feature exists:

```text
zlyme-audio
zlyme-governor
zlyme-led
zlyme-halt
zlyme-storage
zlyme-update
zlyme-drm-release
```

For the Miyoo Flip, the implementation may know about RK817, DMC, VOP2, GPIOs, regulator overlays, and the RTL8733BU.

Generic callers should not.

A future device can provide another implementation of the same command where the semantics are truly shared.

## 5. Boot architecture

Current high-level boot path:

```text
RK3566 BootROM / Miyoo preloader
  v
U-Boot
  v
Image.gz + rk3566-miyoo-flip.dtb
  v
embedded Zlyme initramfs
  v
mount ZLYMEBOOT
  v
apply pending squashfs when needed
  v
loop-mount /boot/zlyme
  v
switch_root
  v
BusyBox init
  v
Class A boot work
  v
NextUI first frame
  v
Class B services in background
```

The first frontend frame is the meaningful boot-complete target.

Networking, Bluetooth, SSH, Samba, Syncthing, NTP, and similar optional services must not be prerequisites for that first frame.

`rcS` owns frontend-critical work. `rc.late`, launched asynchronously from `inittab`, owns non-critical work after the first-frame gate.

## 6. Image and storage model

The Miyoo Flip image currently uses:

- raw idbloader area beginning at 32 KiB;
- GPT `uboot` partition at 8 MiB;
- FAT32 `ZLYMEBOOT`;
- exFAT `ZLYME` storage partition;
- no rootfs GPT partition;
- root squashfs stored as a file named `zlyme` on `ZLYMEBOOT`.

The writable persistent filesystem is `/storage` (`ZLYME`).

The root filesystem is read-only squashfs.

Persistent configuration belongs under:

```text
/storage/.config
```

ROM/save/BIOS handling follows Zlyme's per-library-volume design rather than assuming all content lives on the OS card.

Image layout is a board concern. A future device may use another boot layout while preserving the higher-level Zlyme runtime contracts.

## 7. Update architecture

For `my355`, OTA is file-based:

```text
update tar on /storage
  v
verify/stage
  v
copy kernel/DTB/overlays to ZLYMEBOOT
  v
leave pending squashfs on ZLYME
  v
reboot
  v
initramfs replaces /boot/zlyme
```

Routine OTA does not implicitly rewrite U-Boot.

The update framework must identify artifacts by device. Generic updater logic should read device metadata for:

- update filename prefix;
- required DTB name;
- board identity.

Never allow an update for one device to be accepted by another merely because both contain a file named `zlyme`.

## 8. Graphics

The normal graphics path is compositor-free:

```text
application
  v
SDL2 KMSDRM or EGL/GBM
  v
DRM/KMS
  v
Rockchip display hardware
```

Zlyme does not run a permanent X11 server, Wayland compositor, or desktop environment.

Applications that require a window system may launch an isolated compatibility environment for the duration of that application.

For example:

```text
NextUI releases DRM
  v
temporary Weston / WestonPack
  v
Wayland and/or Xwayland client
  v
application exits
  v
temporary display stack exits
  v
NextUI reacquires DRM
```

### Miyoo Flip GPU stacks

The current board supports both:

- Mesa/Panfrost;
- vendor Mali (`mali_kbase` + libmali).

They cannot own the GPU simultaneously. Selection is reboot-level policy.

This dual-stack mechanism is a Miyoo Flip/RK3566 implementation detail, not a requirement for every future Zlyme device.

## 9. Audio

Normal audio is ALSA.

For the Miyoo Flip:

- local codec is identified by stable ALSA ID `rk817ext`;
- speaker/headphone switching is an RK817 mixer route;
- `zlyme-jackd` follows the jack evdev switch;
- HDMI is a separate PCM;
- Bluetooth audio uses BlueALSA;
- selected sink is exported through Zlyme's ALSA configuration/runtime helpers.

RK817 mixer names must remain inside the `my355` implementation.

A future board may expose the same `zlyme-audio` interface using completely different hardware.

## 10. Input, lid and handheld controls

The Miyoo Flip uses board-specific input integration:

- ROCKNIX-derived joypad driver;
- Miyoo serial controller protocol;
- lid switch;
- power key;
- volume/brightness handling;
- NextUI `my355` platform code;
- `zlyme-keylidmon` while another application owns the screen.

These are board/platform responsibilities.

Frontend and emulator launch code should consume normal Linux input/SDL interfaces rather than Miyoo-specific sysfs or GPIO knowledge whenever possible.

## 11. Frontend and PAK runtime

Zlyme is the OS. NextUI is the current frontend.

The launcher lifecycle is approximately:

```text
NextUI
  v
PAK launch.sh
  v
session releases/suspends frontend resources
  v
RetroArch / standalone / PortMaster / native application
  v
application exits
  v
session restores runtime policy
  v
NextUI restarts/resumes
```

PAK and emulator behavior should be portable across devices where possible.

Device-specific frontend integration belongs in a NextUI platform directory such as:

```text
workspace/my355/
```

The Buildroot package must not hardcode `my355` as a universal constant. Platform selection is part of the selected device configuration.

## 12. Emulator model

Zlyme deliberately ships a curated set.

Prefer one default backend per system. Multiple backends are justified only when they provide real compatibility/performance value.

The emulator packages themselves should remain device-agnostic when upstream allows it.

Device-specific tuning belongs in:

- launch/runtime profiles;
- board governor implementation;
- device-specific core/build flags only when measured.

## 13. Services

Services fall into three classes:

### Boot critical

Needed before frontend operation, such as essential display/input/storage policy.

### Deferred

Can start after first frame, such as networking, Bluetooth, SSH, NTP, Samba, Syncthing, noncritical udev triggering, and similar services.

### On demand

Should not run persistently unless enabled or requested.

The current BusyBox `rcS` / `rc.late` split is intentional.

## 14. Package boundary

`package/` should contain reusable software packages.

A package may be used only by `my355` today without being moved under a fake generic framework.

When a package is inherently board-specific, express that dependency explicitly in Kconfig or keep the hardware implementation in the board overlay.

Examples:

- `zlyme-jackd` is currently RK817/Miyoo-specific even though its package directory is under `package/system`.
- emulator recipes are generally reusable.
- `gpudriver` currently describes the RK3566 dual-Mali-stack implementation and should not be assumed universal.

## 15. Sources of truth

For Zlyme userspace/build behavior, this repository is authoritative.

For Miyoo Flip hardware/kernel research, use `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` as the distribution-independent device reference. Its hardware/firmware conclusions are authoritative for device facts; follow its evidence and uncertainty labels.

For current OS behavior, this Zlyme repository is authoritative. `Zetarancio/distribution` is an archived historical ROCKNIX implementation/evidence source only. Official `ROCKNIX/distribution`, KNULLI, and other distributions are external comparison references.

Do not embed developer-local clone paths in canonical documentation.

## Hardware source of truth

Zlyme does not attempt to duplicate the full Miyoo Flip hardware wiki.

For hardware facts, electrical constraints, DTS history, suspend research, DDR/DMC protocol, USB topology, PMIC behavior, and stock-firmware comparison, the canonical reference is:

```text
Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering
```

The maintained `Zetarancio/distribution` Flip work is a useful known-working implementation reference.

Zlyme remains authoritative for Zlyme-specific build, runtime, frontend, storage, update, and service behavior.

Important current hardware facts that affect architecture:

- standard suspend is known working;
- deep suspend is a separate BL31/SIP feature and is not required for ordinary suspend;
- DMC runtime scaling and deep-suspend configuration are independent drivers/features;
- the RK3568 DMC driver uses Rockchip's V2 SIP shared-memory/MCU/IRQ protocol;
- the upper USB host requires EHCI + OHCI and the PHY clock used by OHCI;
- both SD slots share the I/O-voltage rail;
- RK817 `SYS_CAN_SD` handling is required for correct off-state current;
- current Miyoo Flip retail hardware uses RK8600 for VDD_CPU.

These facts must not be "cleaned up" based on assumptions from another RK3566 board.

## Kernel extension policy

Classify non-upstream kernel work by scope:

```text
board-specific
SoC-family reusable
PMIC/device-family reusable
modification to existing in-tree kernel code
debug-only/historical
```

Prefer an out-of-tree Buildroot kernel-module package for a self-contained driver when:

- the kernel API supports modular operation;
- no required functionality depends on very early boot;
- the module can be self-contained;
- load ordering is explicit and testable.

Keep a kernel patch when the functionality must modify existing in-tree kernel code, bindings, core headers, or boot-critical behavior and an external module would be artificial.

For example, the current RK3568 DMC driver is already implemented with a `tristate` Kconfig and `module_platform_driver()`, so building it as `m` is a smaller step than extracting its source from the kernel patch. The DFI PM fix modifies the existing in-tree Rockchip DFI driver and remains a different problem.

Functionality validation and modularization should be separate experiments.

## 16. Architectural invariants

- only Miyoo Flip is supported today;
- future-device readiness must not add unused second-device code;
- upstream Buildroot is not modified;
- board-specific Linux/U-Boot/image policy stays with the board;
- direct DRM/KMS is the default graphics architecture;
- no permanent compositor;
- BusyBox init remains the default;
- optional networking/services do not block first frame;
- root is read-only;
- persistent state is explicit;
- update artifacts are device-specific;
- generic runtime callers use stable interfaces rather than hardware details;
- performance changes are measured;
- hardware protection is never disabled for benchmark numbers.
