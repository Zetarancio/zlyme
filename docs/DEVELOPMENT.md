# Zlyme development guide

## Target

Zlyme supports only:

```text
Miyoo Flip
device id: my355
SoC: RK3566
```

Future-device structure is documented in `DEVICE_PORTING.md`.

## Build system

Zlyme is a Buildroot external tree.

Buildroot is pinned by `build.sh`. Do not develop against Buildroot master unless a task explicitly changes the project baseline.

The build runs inside the Docker container built from `Dockerfile`. Its base image is pinned by digest. Its apt packages are not version-pinned.

ZcrapeGoat may embed ScreenScraper developer credentials. Local builds read `package/system/zcrapegoat/credentials.local` (gitignored). The official GitHub build reads the Actions secrets `SCREENSCRAPER_DEV_ID` and `SCREENSCRAPER_DEV_PASSWORD`. `build.sh` forwards those environment names into Docker and does not put the values on the command line. Do not commit or log the values. The credential-bearing compile sets `CCACHE_DISABLE=1` so the persistent CI ccache cannot store them. A build with neither source still compiles; the official GitHub build fails closed if either secret is missing.

Buildroot builds the target cross-toolchain. Target software is cross-compiled; do not execute target binaries through QEMU as part of normal compilation.

## Pinned baseline

The source column is authoritative. Update this table when a pin changes.

| Component | Version | Source |
| --- | --- | --- |
| Buildroot | `2026.02.3` | `BUILDROOT_VERSION` in `build.sh` |
| Linux | `7.0.2` | `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` in `configs/zlyme_my355_defconfig` |
| U-Boot | `2026.01`, board defconfig `quartz64-a-rk3566` | `BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE` in the defconfig |
| BL31 | `rk3568_bl31_v1.44.elf` | `BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME` in the defconfig |
| TPL | `rk3566_ddr_1056MHz_v1.23.bin` | `BR2_PACKAGE_ROCKCHIP_RKBIN_TPL_FILENAME` in the defconfig |

Both defconfigs carry the same kernel, U-Boot, and rkbin lines. The rkbin commit itself comes from the Buildroot version. TPL and BL31 must be a matching pair. On a normal card boot only BL31 from that pair runs, because the Miyoo SPI-NAND preloader has already done DDR init. The product version is the `ZLYME_VERSION` file. The NextUI pin is `NEXTUI_VERSION` (`docs/MAINTENANCE.md`).

## Defconfigs

The Miyoo Flip configurations are device-qualified:

```text
configs/zlyme_my355_minimal_defconfig
configs/zlyme_my355_defconfig
```

`./build.sh` with no `--config` builds the minimal image unless `ZLYME_DEFCONFIG` is set. That is the bring-up/debug base. `storage.sh.example` sets `ZLYME_DEFCONFIG=zlyme_my355_defconfig`.

The output tree records the defconfig that configured it in `.zlyme-defconfig`. A later run reapplies the requested defconfig when that record is missing or different, when `.config` is missing, or when the defconfig file is newer than `.config`. A `menuconfig` change is not wiped when the recorded selection already matches and the defconfig file is older than `.config`.

To change configuration, edit `configs/*_defconfig` directly, then run `build.sh` again. The edited file is newer than `.config`, so `build.sh` reapplies it. Use `menuconfig` to explore a symbol and its dependencies, then copy the line into the defconfig by hand. Do not use `savedefconfig`. `build.sh` mounts the repository read-only at `/zlyme/src`, and `BR2_DEFCONFIG` points into that mount, so it cannot write the file. Buildroot's minimal output would also drop the defconfig comments.

`./build.sh --config zlyme_my355_defconfig` is the product image: frontend, emulators, PortMaster, Wine/Box64, and the other services.

Keep shared configuration decisions synchronized deliberately. Do not blindly copy the entire full defconfig over the minimal one.

## Build commands

Canonical entry point:

```bash
./build.sh
```

Typical operations:

```bash
./build.sh --minimal
./build.sh --config <defconfig>
./build.sh menuconfig
./build.sh linux-rebuild
./build.sh <pkg>-dirclean
./build.sh --check
./build.sh --loops
./build.sh --shell
./build.sh --clean
./build.sh --rebuild-image
```

Any other make target is passed through to Buildroot. `--clean` deletes the build tree and keeps downloads and ccache. It refuses a directory that is not named `output`. `--shell` opens a shell in the build container. `--rebuild-image` rebuilds the container. A build with no make target, and every passed-through target except `*config`, writes `output/build.log`. The file is overwritten at the start of each run.

Paths come from the environment: `ZLYME_BUILDROOT`, `ZLYME_OUTPUT`, `ZLYME_DL`, `ZLYME_CCACHE`, and `ZLYME_DEFCONFIG`. The defaults are `./buildroot`, `./output`, `./dl`, `./.ccache`, and the minimal defconfig.

Do not run two builds against the same output tree simultaneously.

## Source fingerprints

Buildroot copies a local package's source once and does not notice a later edit. A build with no make target runs `refresh_compiled_package` in `build.sh` for each of these packages when it is enabled:

| Package | Fingerprinted paths |
| --- | --- |
| `nextui` | `package/system/nextui`, `package/system/zlyme-input/virtpad.h` |
| `minui-list` | `package/system/minui-list`, `package/system/nextui/nextui.mk` |
| `minui-presenter` | `package/system/minui-presenter`, `package/system/minui-list`, `package/system/nextui/nextui.mk` |
| `zcrapegoat` | `package/system/zcrapegoat` |
| `zlyme-keylidmon` | `package/system/zlyme-keylidmon`, `package/system/zlyme-input/virtpad.h`, `package/system/nextui/nextui.mk` |
| `openbor` | `package/emulators/openbor` |
| `ppsspp` | `package/emulators/ppsspp` |

When the hash of a package's listed paths changes, `build.sh` runs that package's `-dirclean` before the image build. The downloaded NextUI tree is not fingerprinted. Package-only targets do not run this refresh.

Other local packages are not fingerprinted: `zlyme-input`, `zlyme-jackd`, `miyoo-flip-gamepad`, `rk3568-dmc`, `rtl8733bu-power`, `gpudriver`, `pico8`, and `rtl8723fu-firmware`. After editing one of those, run `./build.sh <pkg>-dirclean` or `./build.sh <pkg>-rebuild` before the image build. `<pkg>-reinstall` copies the source again but can keep a previously compiled binary.

Files that a downloaded package installs from its own package directory are not fingerprinted either, such as the InputPlumber YAML and init script or the PortMaster wrappers. `<pkg>-reinstall` copies them again.

Some inputs sit outside every package fingerprint and are reapplied on every image build: `ZLYME_VERSION`, the `board/my355/*.sh` scripts, and `board/my355/fsoverlay`. Buildroot's `target-finalize` copies the overlay and reruns post-build on every build. The overlay copy does not delete. A file removed from `board/my355/fsoverlay` stays in `output/target` until `post-build.sh` removes it explicitly or the output tree is rebuilt.

The my355 post-image hook extracts the application input path from the newly
packed squashfs and compares scripts, configuration seeds, and the controller
database with source. It also rejects a hotkey or keylidmon binary with the
old physical-controller identity. A successful package build or a populated
`output/target` alone does not establish the contents of an OTA.

## Build output and caches

Keep:
- Buildroot source;
- output tree;
- download cache;
- compiler cache

as separate paths.

For machine-local paths, copy `storage.sh.example` to `storage.sh` (gitignored) and run that instead of `build.sh`. It must not contain repository-wide assumptions.

## Reproducibility

For packages:

- pin versions;
- prefer immutable commits/tags;
- declare dependencies;
- declare license and license files;
- provide hashes where Buildroot can verify them;
- avoid network access from build/install steps.

Most downloaded packages, including the emulators and libretro cores, have no `.hash` file. Add one when changing a package's version.

Do not silently upgrade dependencies.

## Package sourcing policy

The package's own upstream is the version authority. KNULLI and ROCKNIX are packaging references, not the source of truth. Compare version, dependencies, options, patches, and license before adopting anything. `docs/UPSTREAMS.md` and `docs/MAINTENANCE.md` own that procedure.

Hardware facts do not come from KNULLI merely because it has a similar SoC. For Miyoo Flip hardware the device wiki comes first. Current ROCKNIX is comparison evidence, and the archived Zetarancio/distribution fork is historical evidence. `docs/UPSTREAMS.md` owns that authority model.

## Image date

`build.sh` sets `ZLYME_IMAGE_DATE` once, at the start of a real build, to UTC `YYYY-MM-DD` when the variable is unset. The displayed OS string and the OTA stamp both come from that value. The NextUI package date in `/usr/share/nextui/build-date.txt` is package metadata and is not the OS date. An explicit override must round-trip through `board/my355/image-date.sh` as a real calendar date. `ZLYME_VERSION` stays the product name, such as `zlyme44`, with no date attached.

## Release artifacts

A local `./build.sh` writes a full OTA only. It does not write `release-manifest.json` or a delta. The GitHub release job does. A local OTA is not a release artifact. The release and delta policy and the accepted runtime SHA are in `docs/MAINTENANCE.md`.

## Build container

GitHub Actions pulls or publishes `ghcr.io/<owner>/zlyme-build:latest`. GHCR requires a lowercase repository name, so the workflow lowercases `GITHUB_REPOSITORY_OWNER` before building the image path. For this repository the path is `ghcr.io/zetarancio/zlyme-build:latest`. Login still uses `github.actor`. The `Docker image` workflow rebuilds that container when `Dockerfile` or `.github/workflows/docker-image.yml` changes.

`build.sh` reuses a local `zlyme-build` image only when its `zlyme.dockerfile` label equals the SHA-256 of `Dockerfile`. Neither workflow passes that label to `docker build`, so `build.sh` rebuilds the container in every CI build stage even after a successful GHCR pull.

## Package layout

Top-level package categories:

```text
package/
├── boot/
├── drivers/
├── emulators/
└── system/
```

Do not reorganize hundreds of packages just to prepare for hypothetical devices.

Device-specific packages may stay where they are, but should declare their device dependency when that prevents accidental use on a future board.

## Global vs board make logic

`external.mk` should contain only:

- package include/discovery;
- selected-board dispatch;
- genuinely global Buildroot workarounds.

Miyoo Flip U-Boot/Linux hooks live in:

```text
board/my355/board.mk
```

`external.mk` includes it only when `BR2_ZLYME_DEVICE_MY355=y`.

## Compiler policy

Both defconfigs build userspace at `-O3` (`BR2_OPTIMIZE_3=y`) with `BR2_TARGET_OPTIMIZATION="-pipe -fsigned-char -mcpu=cortex-a55+crc+crypto+fp+simd+rcpc"`. The kernel keeps its own `-O2`.

These packages are pinned back to `-O2` in their own `.mk` with `$(filter-out -O3,…) -O2`:

- `package/emulators/libretro-genesisplusgx/libretro-genesisplusgx.mk`;
- `package/emulators/libretro-dosbox-pure/libretro-dosbox-pure.mk`.

A new pin goes in the package `.mk` with a comment that says why.

Do not change global optimization policy as cleanup.

Performance flags must be treated as behavior, not formatting.

When changing flags:
- benchmark;
- test representative emulators;
- check binary compatibility;
- document exceptions.

## Kernel and U-Boot

Board kernel/U-Boot content belongs under the board tree.

For my355:

```text
board/my355/linux/
board/my355/uboot/
```

Keep patch ordering explicit.

Do not move board-specific kernel/U-Boot mutation back into global code after it has been isolated.

When reconfiguring the kernel, remember that out-of-tree modules may require rebuild/dirclean if the module ABI changes.

A change that touches only the board DTS, and does not change kernel source, kernel config, modules, or the root filesystem, does not need a full image or a new OTA for the experiment. The boot volume is the vfat labeled `ZLYMEBOOT`. Initramfs mounts it read-only at `/boot`. `S12bootfs` is the fallback mount and also keeps it read-only. Extlinux loads `FDT /rk3566-miyoo-flip.dtb` from that volume, so the live file is `/boot/rk3566-miyoo-flip.dtb`. Every runtime write to `/boot` goes through `zlyme-boot-write`, which remounts it read-write for one command and then back to read-only.

1. Rebuild only that DTB in the existing Buildroot kernel tree.
2. Decompile it and confirm the intended property change, and that nothing outside the intended node moved.
3. Copy it to `/tmp` on the Flip.
4. Through `zlyme-boot-write`, keep the previous file as `/boot/rk3566-miyoo-flip.dtb.bak` and copy the new one over `/boot/rk3566-miyoo-flip.dtb`.
5. Compare SHA-256 of the built file and `/boot/rk3566-miyoo-flip.dtb`.
6. Reboot.
7. Test.

```sh
./build.sh --config zlyme_my355_defconfig linux-rebuild
sha256sum output/images/rk3566-miyoo-flip.dtb
scp output/images/rk3566-miyoo-flip.dtb root@<flip-ip>:/tmp/rk3566-miyoo-flip.dtb
ssh root@<flip-ip> 'zlyme-boot-write sh -c "cp -a /boot/rk3566-miyoo-flip.dtb /boot/rk3566-miyoo-flip.dtb.bak && cp -a /tmp/rk3566-miyoo-flip.dtb /boot/rk3566-miyoo-flip.dtb" && sha256sum /boot/rk3566-miyoo-flip.dtb && reboot'
```

To undo the experiment, copy the `.bak` file back the same way.

`linux-rebuild` is the supported entry that recompiles this DTB in the existing tree and installs it to `output/images/`. It can also relink `Image`. If `Image` was not part of the experiment, do not copy it. A release still ships a full image. The DTB-only copy is an experiment, not a release.

## Image safety

Image-generation code may manipulate image files and loop devices.

Never infer that a path is safe merely because it is non-empty.

Validate destructive paths.

Do not write host `/dev/sd*`, `/dev/mmcblk*`, `/dev/nvme*`, or similar raw devices from normal build code.

Preserve the existing build safety checks.

## Shell

Target scripts should be POSIX `sh` unless Bash is necessary.

Host scripts may use Bash and should normally use:

```bash
set -euo pipefail
```

Avoid:
- `eval`;
- unquoted paths;
- arbitrary sleeps for readiness;
- backgrounding dependent work;
- silently ignoring critical failures.

## Hardware services

Prefer small daemons or scripts with narrow responsibilities.

Interface pattern:

```text
frontend / PAK / generic service
        |
        v
zlyme-* semantic command
        |
        v
board-specific sysfs / ALSA / GPIO / DRM implementation
```

Keep hardware details on the bottom side of that boundary.

## Boot-time development

Optimize for first frontend frame, not for every service becoming ready.

Classify work as:
- required before frontend;
- safe after first frame;
- on demand.

Do not add optional work to `rcS` without a demonstrated dependency.

## Validation

Before committing a Buildroot/package change, run the narrowest relevant validation.

Recommended gates:

```text
Buildroot external package/style checks
ShellCheck
affected package build
kernel/U-Boot final config assertions
full image build when relevant
real-device test when hardware behavior changed
```

Host-side tests live in `scripts/tests/`. Run one directly, for example `sh scripts/tests/test_delta_stage.sh` or `python3 scripts/tests/test_doc_links.py`. The image build also asserts on its own: `build.sh` fails when a defconfig `=y` line does not survive kconfig, `post-build.sh` checks the radio and gamepad modules and the NextUI platform, and `assert-input-rootfs.sh` checks the packed squashfs.

Do not claim hardware validation based on compilation.

## Documentation workflow

Use:
- `ARCHITECTURE.md` for stable system design;
- `DEVICE_PORTING.md` for extension contracts;
- `OPERATIONS.md` for durable live-device/recovery facts;
- `UPSTREAMS.md` for source selection and provenance;
- `MAINTENANCE.md` for the maintainer index and release policy;
- `ROADMAP.md` for phase sequencing and acceptance history;
- `LOGBOOK.md` for chronological engineering history;
- `research/` for alternatives and experiments;
- ADRs in `docs/decisions/` for major choices that future maintainers might otherwise "simplify" away.

Research records alternatives.

Architecture records decisions.

Operations records procedures and known physical-device behavior.

Logbook records history.
