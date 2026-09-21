# Zlyme development guide

## Current target

Zlyme currently supports only:

```text
Miyoo Flip
device id: my355
SoC: RK3566
```

Future-device structure is documented in `DEVICE_PORTING.md`.

## Build system

Zlyme is a Buildroot external tree.

Buildroot is pinned by `build.sh`. Do not develop against Buildroot master unless a task explicitly changes the project baseline.

The build runs inside the pinned Docker environment.

Buildroot builds the target cross-toolchain. Target software is cross-compiled; do not execute target binaries through QEMU as part of normal compilation.

## Defconfigs

The Miyoo Flip configurations are device-qualified:

```text
configs/zlyme_my355_minimal_defconfig
configs/zlyme_my355_defconfig
```

`./build.sh` with no `--config` builds the minimal image. That is the bring-up/debug base.

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
./build.sh savedefconfig
./build.sh --check
./build.sh --loops
```

Do not run two builds against the same output tree simultaneously.

## Build output and caches

Keep:
- Buildroot source;
- output tree;
- download cache;
- compiler cache

as separate paths.

`storage.sh` remains a local/machine-specific convenience wrapper and should not contain repository-wide assumptions.

## Reproducibility

For packages:

- pin versions;
- prefer immutable commits/tags;
- declare dependencies;
- declare license and license files;
- provide hashes where Buildroot can verify them;
- avoid network access from build/install steps.

Do not silently upgrade dependencies.

## Package sourcing policy

For emulator/core/library recipes, first inspect established Buildroot/Batocera/Knulli packaging before writing a custom recipe.

Hardware facts do not come from Knulli merely because it has a similar SoC.

For Miyoo Flip hardware:
- working Zlyme behavior;
- the dedicated Miyoo Flip hardware research;
- the working ROCKNIX-derived hardware implementation

take precedence.

## Package layout

Current top-level package categories:

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

Miyoo Flip U-Boot/Linux hooks belong in:

```text
board/my355/board.mk
```

This is the highest-value structural change for future device support.

## Compiler policy

The current tree has deliberate Cortex-A55 and package optimization choices.

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

Current useful interface pattern:

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

Do not claim hardware validation based on compilation.

## Documentation workflow

Use:
- `ARCHITECTURE.md` for stable system design;
- `DEVICE_PORTING.md` for extension contracts;
- `OPERATIONS.md` for durable live-device/recovery facts;
- `LOGBOOK.md` for chronological engineering history;
- `research/` for alternatives and experiments;
- ADRs for major choices that future maintainers might otherwise "simplify" away.

Research records alternatives.

Architecture records decisions.

Operations records procedures and known physical-device behavior.

Logbook records history.
